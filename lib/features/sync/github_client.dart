import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../core/logging.dart';

/// One file as GitHub reports it.
class RemoteFile {
  const RemoteFile({
    required this.path,
    required this.sha,
    required this.size,
    this.bytes,
  });

  final String path;
  final String sha;
  final int size;
  final Uint8List? bytes;

  String get text => bytes == null ? '' : utf8.decode(bytes!, allowMalformed: true);
}

/// Result of SEC-04 Test Connection.
class ConnectionResult {
  const ConnectionResult({
    required this.ok,
    required this.message,
    this.isPrivate = false,
    this.defaultBranch,
  });

  final bool ok;
  final String message;
  final bool isPrivate;
  final String? defaultBranch;
}

class GitHubException implements Exception {
  GitHubException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  bool get isConflict => statusCode == 409 || statusCode == 422;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 403;

  @override
  String toString() => 'GitHub $statusCode: $message';
}

/// G-06: a thin, careful wrapper over the GitHub Contents API.
///
/// Two rules are enforced here rather than in the sync engine, because they
/// are too important to leave to a caller:
///   * SEC-05 the repository must be private
///   * X-11/X-12 every write carries the expected sha; no blind overwrite
class GitHubClient {
  GitHubClient({
    required this.owner,
    required this.repo,
    required this.branch,
    required String token,
    http.Client? httpClient,
  })  : _token = token,
        _http = httpClient ?? http.Client();

  final String owner;
  final String repo;
  final String branch;
  final String _token;
  final http.Client _http;

  static const String _api = 'https://api.github.com';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'NoteNest/1.0',
      };

  void close() => _http.close();

  // ---------------------------------------------------------------------
  // SEC-04 / SEC-05 / SEC-06
  // ---------------------------------------------------------------------

  /// Verifies the token, the repository, its visibility and the branch.
  ///
  /// The order of checks matters: we report the most actionable problem
  /// first rather than a generic failure (SEC-04 error list).
  Future<ConnectionResult> testConnection() async {
    try {
      final repoResponse = await _http
          .get(Uri.parse('$_api/repos/$owner/$repo'), headers: _headers)
          .timeout(const Duration(seconds: 20));

      switch (repoResponse.statusCode) {
        case 401:
          return const ConnectionResult(
            ok: false,
            message: 'Invalid token. Check that you pasted the whole '
                'fine-grained personal access token.',
          );
        case 404:
          return ConnectionResult(
            ok: false,
            message: 'Repository "$owner/$repo" not found, or this token '
                'has no access to it.',
          );
        case 403:
          return const ConnectionResult(
            ok: false,
            message: 'GitHub refused the request. The token may lack '
                'permission, or you have hit the rate limit.',
          );
      }

      if (repoResponse.statusCode != 200) {
        return ConnectionResult(
          ok: false,
          message: 'GitHub returned ${repoResponse.statusCode}.',
        );
      }

      final json = jsonDecode(repoResponse.body) as Map<String, dynamic>;
      final isPrivate = json['private'] == true;
      final defaultBranch = json['default_branch'] as String?;

      // SEC-05: the single most damaging mistake this app can allow.
      if (!isPrivate) {
        return ConnectionResult(
          ok: false,
          isPrivate: false,
          defaultBranch: defaultBranch,
          message: 'This repository is public. Use a private repository.',
        );
      }

      final permissions = json['permissions'] as Map<String, dynamic>?;
      if (permissions != null && permissions['push'] != true) {
        return const ConnectionResult(
          ok: false,
          isPrivate: true,
          message: 'This token can read the repository but not write to it. '
              'Grant Contents: Read and write.',
        );
      }

      // Branch check.
      final branchResponse = await _http
          .get(
            Uri.parse('$_api/repos/$owner/$repo/branches/$branch'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));

      if (branchResponse.statusCode == 404) {
        return ConnectionResult(
          ok: false,
          isPrivate: true,
          defaultBranch: defaultBranch,
          message: 'Branch "$branch" not found. '
              '${defaultBranch != null ? 'The default branch is "$defaultBranch".' : ''}',
        );
      }
      if (branchResponse.statusCode != 200) {
        return ConnectionResult(
          ok: false,
          isPrivate: true,
          message: 'Could not read branch "$branch" '
              '(${branchResponse.statusCode}).',
        );
      }

      return ConnectionResult(
        ok: true,
        isPrivate: true,
        defaultBranch: defaultBranch,
        message: 'Connected to $owner/$repo ($branch).',
      );
    } on TimeoutException {
      return const ConnectionResult(
        ok: false,
        message: 'GitHub did not respond. Check your internet connection.',
      );
    } on SocketException catch (e) {
      // DNS failure or the network stack refused the connection.
      return ConnectionResult(
        ok: false,
        message: await _networkFailureHint(e.message),
      );
    } on http.ClientException catch (e) {
      // The http package wraps the socket error above in a ClientException.
      return ConnectionResult(
        ok: false,
        message: await _networkFailureHint(e.message),
      );
    } catch (e) {
      return ConnectionResult(
        ok: false,
        message: 'GitHub is unreachable right now. (${AppLog.redact(e)})',
      );
    }
  }

  /// Turns a DNS / socket failure into a message the user can act on.
  ///
  /// On Android, a release APK built without the INTERNET permission fails
  /// with exactly this kind of error ("failed host lookup", errno 7) while
  /// the system still reports an internet connection — see tool/setup.sh.
  /// Distinguishing "offline" from "permissionless build" turns a cryptic
  /// stack trace into the right next step.
  Future<String> _networkFailureHint(String detail) async {
    var online = false;
    try {
      final results = await Connectivity().checkConnectivity();
      online = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Connectivity plugin unavailable (e.g. unit tests): stay generic.
    }

    if (!online) {
      return 'No internet connection on this device. '
          'Turn on Wi-Fi or mobile data, then try again.';
    }

    final isAndroid = !kIsWeb && Platform.isAndroid;
    if (isAndroid) {
      return 'Your internet is on, but this phone cannot reach GitHub. '
          'In a release APK the usual cause is a missing INTERNET '
          'permission: rebuild with "bash tool/setup.sh" (or install the '
          'CI-built APK) and reinstall. If it still fails, check Private '
          'DNS, an ad-blocker, or a VPN on the phone.';
    }
    return 'Your internet is on, but GitHub could not be reached. '
        'Check your firewall, proxy, or VPN settings. '
        '(${AppLog.redact(detail)})';
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// Lists a directory. Returns an empty list when the directory does not
  /// exist yet, which is the normal state of a brand-new sync repository.
  ///
  /// G-18: the Contents API caps a directory listing at 1000 entries. Past
  /// that we fall back to the Git tree API, which returns the whole subtree
  /// in one request.
  Future<List<RemoteFile>> listDirectory(String path) async {
    final uri = Uri.parse('$_api/repos/$owner/$repo/contents/$path?ref=$branch');
    final response = await _http.get(uri, headers: _headers);

    if (response.statusCode == 404) return const [];
    if (response.statusCode != 200) {
      throw GitHubException(response.statusCode, _errorMessage(response.body));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];

    final files = decoded
        .whereType<Map<String, dynamic>>()
        .where((e) => e['type'] == 'file')
        .map(
          (e) => RemoteFile(
            path: e['path'] as String,
            sha: e['sha'] as String,
            size: (e['size'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    if (files.length >= 1000) {
      AppLog.warn('github', 'directory $path hit the 1000-file cap, '
          'falling back to the tree API');
      return _listViaTree(path);
    }
    return files;
  }

  Future<List<RemoteFile>> _listViaTree(String path) async {
    final uri = Uri.parse(
      '$_api/repos/$owner/$repo/git/trees/$branch?recursive=1',
    );
    final response = await _http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw GitHubException(response.statusCode, _errorMessage(response.body));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tree = (json['tree'] as List?) ?? const [];
    final prefix = path.endsWith('/') ? path : '$path/';

    return tree
        .whereType<Map<String, dynamic>>()
        .where((e) => e['type'] == 'blob')
        .where((e) => (e['path'] as String).startsWith(prefix))
        .map(
          (e) => RemoteFile(
            path: e['path'] as String,
            sha: e['sha'] as String,
            size: (e['size'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  /// Fetches one file. Returns null when it does not exist.
  Future<RemoteFile?> getFile(String path) async {
    final uri = Uri.parse('$_api/repos/$owner/$repo/contents/$path?ref=$branch');
    final response = await _http.get(uri, headers: _headers);

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw GitHubException(response.statusCode, _errorMessage(response.body));
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;

    Uint8List? bytes;
    final encoding = json['encoding'] as String?;
    final content = json['content'] as String?;
    if (encoding == 'base64' && content != null) {
      bytes = Uint8List.fromList(base64.decode(content.replaceAll('\n', '')));
    } else if (json['download_url'] != null) {
      // Files over 1 MB come back without inline content.
      final raw = await _http.get(
        Uri.parse(json['download_url'] as String),
        headers: _headers,
      );
      if (raw.statusCode == 200) bytes = raw.bodyBytes;
    }

    return RemoteFile(
      path: json['path'] as String? ?? path,
      sha: json['sha'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? bytes?.length ?? 0,
      bytes: bytes,
    );
  }

  // ---------------------------------------------------------------------
  // Writes — X-11/X-12: always compare-and-swap, never force
  // ---------------------------------------------------------------------

  /// Creates or updates a file. [expectedSha] must be the sha the caller
  /// last saw; passing null means "this file must not exist yet".
  ///
  /// Returns the new sha. Throws [GitHubException] with `isConflict` when the
  /// remote moved underneath us, which the sync engine turns into a conflict
  /// copy rather than an overwrite.
  Future<String> putFile({
    required String path,
    required Uint8List bytes,
    required String message,
    String? expectedSha,
  }) async {
    final uri = Uri.parse('$_api/repos/$owner/$repo/contents/$path');
    final body = <String, dynamic>{
      'message': message,
      'content': base64.encode(bytes),
      'branch': branch,
      if (expectedSha != null) 'sha': expectedSha,
    };

    final response = await _http.put(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['content'] as Map<String, dynamic>?;
      return content?['sha'] as String? ?? '';
    }

    throw GitHubException(response.statusCode, _errorMessage(response.body));
  }

  /// Deletes a file. A 404 is treated as success — the goal state is
  /// "this file does not exist", and it already does not.
  Future<void> deleteFile({
    required String path,
    required String sha,
    required String message,
  }) async {
    final uri = Uri.parse('$_api/repos/$owner/$repo/contents/$path');
    final response = await _http.delete(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'sha': sha, 'branch': branch}),
    );

    if (response.statusCode == 200 || response.statusCode == 404) return;
    throw GitHubException(response.statusCode, _errorMessage(response.body));
  }

  /// Deletes by path, resolving the sha first. Used when we know a file
  /// should go but do not have a current sha (X-07 image cleanup).
  Future<void> deleteByPath(String path, String message) async {
    final existing = await getFile(path);
    if (existing == null) return;
    await deleteFile(path: path, sha: existing.sha, message: message);
  }

  Future<String?> headCommitSha() async {
    try {
      final response = await _http.get(
        Uri.parse('$_api/repos/$owner/$repo/commits/$branch'),
        headers: _headers,
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['sha'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic> && json['message'] is String) {
        return json['message'] as String;
      }
    } catch (_) {
      // fall through
    }
    return body.length > 200 ? body.substring(0, 200) : body;
  }
}
