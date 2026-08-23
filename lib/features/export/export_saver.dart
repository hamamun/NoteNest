import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/logging.dart';
import 'export_service.dart';

/// E-13: where an export actually lands.
///
/// `FilePicker.saveFile` shows the native Save As dialog on Windows and the
/// system document picker on Android, so one code path covers both and
/// NoteNest never needs broad storage permissions (BLD-03).
class ExportSaver {
  ExportSaver._();

  /// Returns the saved path, or null when the user cancelled.
  static Future<String?> save(ExportPayload payload) async {
    try {
      final location = await FilePicker.platform.saveFile(
        dialogTitle: 'Save export',
        fileName: payload.fileName,
        bytes: payload.bytes,
      );
      if (location == null) return null;

      // On Android the picker writes the bytes itself; on desktop it only
      // returns the chosen path. Writing when needed makes both identical.
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final file = File(location);
        if (!file.existsSync() || file.lengthSync() != payload.bytes.length) {
          await file.writeAsBytes(payload.bytes, flush: true);
        }
      }
      return location;
    } catch (e) {
      AppLog.error('export', 'save failed', e);
      rethrow;
    }
  }

  /// Fallback used if the picker is unavailable: writes into the app's
  /// documents folder and returns the path so the UI can tell the user.
  static Future<String> saveToAppFolder(ExportPayload payload) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, payload.fileName));
    await file.writeAsBytes(payload.bytes, flush: true);
    return file.path;
  }
}
