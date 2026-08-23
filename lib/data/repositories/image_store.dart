import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/logging.dart';
import '../../core/ulid.dart';

/// IMG-01/IMG-02: the allow-list. Images only — never video, never documents.
class ImageValidation {
  const ImageValidation._(this.ok, this.mimeType, this.error);

  final bool ok;
  final String mimeType;
  final String? error;

  static const ImageValidation _rejectedType = ImageValidation._(
    false,
    '',
    'Only images can be added to a note. '
        'JPG, PNG and WebP are supported — no video, PDF or other files.',
  );

  static const ImageValidation _corrupt = ImageValidation._(
    false,
    '',
    'That file is not a readable image.',
  );
}

/// IMG-05/IMG-06: local image storage plus thumbnail generation.
class ImageStore {
  ImageStore();

  static const Set<String> allowedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  static const Map<String, String> _mimeByExtension = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
  };

  /// Largest edge kept for the stored original (IMG-09).
  static const int maxEdge = 2048;

  /// Card thumbnail edge (IMG-06).
  static const int thumbEdge = 480;

  Directory? _imagesDir;
  Directory? _thumbsDir;

  Future<Directory> imagesDir() async {
    if (_imagesDir != null) return _imagesDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'images'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _imagesDir = dir;
  }

  Future<Directory> thumbsDir() async {
    if (_thumbsDir != null) return _thumbsDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'thumbnails'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _thumbsDir = dir;
  }

  /// IMG-02: validates by extension AND by decoding the bytes, so a renamed
  /// `.mp4` cannot sneak through a picker filter.
  ImageValidation validate(String fileName, Uint8List bytes) {
    final ext = p.extension(fileName).toLowerCase();
    if (!allowedExtensions.contains(ext)) return ImageValidation._rejectedType;

    if (!_hasImageMagic(bytes)) return ImageValidation._corrupt;

    return ImageValidation._(true, _mimeByExtension[ext] ?? 'image/jpeg', null);
  }

  /// Checks the file signature rather than trusting the extension.
  bool _hasImageMagic(Uint8List b) {
    if (b.length < 12) return false;
    // JPEG: FF D8 FF
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true;
    // WebP: "RIFF" .... "WEBP"
    if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return true;
    }
    return false;
  }

  /// Stores [bytes] locally, downscaling when oversized, and writes a
  /// thumbnail beside it.
  Future<StoredImage?> store({
    required String originalName,
    required Uint8List bytes,
  }) async {
    final validation = validate(originalName, bytes);
    if (!validation.ok) {
      AppLog.warn('images', 'rejected $originalName: ${validation.error}');
      return null;
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      AppLog.warn('images', 'could not decode $originalName');
      return null;
    }

    final id = Ulid.generate();
    final ext = p.extension(originalName).toLowerCase() == '.png' ? '.png' : '.jpg';
    final fileName = '$id$ext';

    // IMG-09: keep the repository small; GitHub is not a photo host.
    final needsResize = decoded.width > maxEdge || decoded.height > maxEdge;
    final normalised = needsResize
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxEdge : null,
            height: decoded.height > decoded.width ? maxEdge : null,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    final encoded = ext == '.png'
        ? img.encodePng(normalised)
        : img.encodeJpg(normalised, quality: 88);

    final dir = await imagesDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(encoded, flush: true);

    // Thumbnail.
    final thumb = img.copyResize(
      normalised,
      width: normalised.width >= normalised.height ? thumbEdge : null,
      height: normalised.height > normalised.width ? thumbEdge : null,
      interpolation: img.Interpolation.average,
    );
    final thumbDir = await thumbsDir();
    final thumbFile = File(p.join(thumbDir.path, '$id.jpg'));
    await thumbFile.writeAsBytes(img.encodeJpg(thumb, quality: 78), flush: true);

    return StoredImage(
      id: id,
      fileName: fileName,
      localPath: file.path,
      thumbnailPath: thumbFile.path,
      mimeType: ext == '.png' ? 'image/png' : 'image/jpeg',
      sizeBytes: encoded.length,
      width: normalised.width,
      height: normalised.height,
    );
  }

  /// Writes bytes pulled from GitHub straight to disk (sync pull path).
  Future<String> writeRemoteImage(String fileName, Uint8List bytes) async {
    final dir = await imagesDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String?> thumbnailFor(String imageId) async {
    final dir = await thumbsDir();
    final file = File(p.join(dir.path, '$imageId.jpg'));
    return file.existsSync() ? file.path : null;
  }

  Future<void> deleteThumbnail(String imageId) async {
    try {
      final dir = await thumbsDir();
      final file = File(p.join(dir.path, '$imageId.jpg'));
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Best effort only.
    }
  }
}

class StoredImage {
  const StoredImage({
    required this.id,
    required this.fileName,
    required this.localPath,
    required this.thumbnailPath,
    required this.mimeType,
    required this.sizeBytes,
    required this.width,
    required this.height,
  });

  final String id;
  final String fileName;
  final String localPath;
  final String thumbnailPath;
  final String mimeType;
  final int sizeBytes;
  final int width;
  final int height;
}
