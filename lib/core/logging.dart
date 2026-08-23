/// SEC-08: logging that can never leak a GitHub token.
///
/// Every log line passes through [redact], which strips anything that looks
/// like a GitHub PAT (`ghp_`, `github_pat_`, `gho_`, ...) or an Authorization
/// header. Call sites are not trusted to remember the rule.
library;

import 'package:flutter/foundation.dart';

class AppLog {
  AppLog._();

  static final List<String> _ring = <String>[];
  static const int _maxLines = 300;

  static final RegExp _tokenPattern = RegExp(
    r'(gh[pousr]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,})',
  );
  static final RegExp _authHeader = RegExp(
    r'(authorization|bearer|token)\s*[:=]\s*\S+',
    caseSensitive: false,
  );

  /// Removes anything token-shaped from [message].
  static String redact(Object? message) {
    var text = '$message';
    text = text.replaceAll(_tokenPattern, '***REDACTED***');
    text = text.replaceAllMapped(
      _authHeader,
      (m) => '${m.group(1)}: ***REDACTED***',
    );
    return text;
  }

  static void info(String tag, Object? message) => _write('INFO', tag, message);
  static void warn(String tag, Object? message) => _write('WARN', tag, message);
  static void error(String tag, Object? message, [Object? err, StackTrace? st]) {
    _write('ERROR', tag, err == null ? message : '$message | $err');
    if (st != null && kDebugMode) {
      debugPrint(redact(st.toString()));
    }
  }

  static void _write(String level, String tag, Object? message) {
    final line = '[$level] $tag: ${redact(message)}';
    _ring.add(line);
    if (_ring.length > _maxLines) _ring.removeAt(0);
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  /// Recent log lines, already redacted. Surfaced in Settings > About so the
  /// user can diagnose a failing sync without digging through a console.
  static List<String> recent() => List<String>.unmodifiable(_ring);

  static void clear() => _ring.clear();
}
