import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/logging.dart';
import 'export_service.dart';

/// E-13: where an export actually lands.
///
/// Windows gets a native Save As dialog. Android goes through the share sheet,
/// which lets the user drop the file into Drive, Downloads or anywhere else
/// without NoteNest asking for broad storage permissions (BLD-03).
class ExportSaver {
  ExportSaver._();

  static Future<String?> save(ExportPayload payload) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _saveDesktop(payload);
    }
    return _shareMobile(payload);
  }

  static Future<String?> _saveDesktop(ExportPayload payload) async {
    try {
      final location = await FilePicker.platform.saveFile(
        dialogTitle: 'Save export',
        fileName: payload.fileName,
        bytes: payload.bytes,
      );
      if (location == null) return null;

      // On some platforms file_picker writes the bytes itself; on others it
      // only returns the chosen path. Writing again is harmless and makes the
      // behaviour identical everywhere.
      final file = File(location);
      if (!file.existsSync() || file.lengthSync() != payload.bytes.length) {
        await file.writeAsBytes(payload.bytes, flush: true);
      }
      return location;
    } catch (e) {
      AppLog.error('export', 'save failed', e);
      rethrow;
    }
  }

  static Future<String?> _shareMobile(ExportPayload payload) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, payload.fileName));
    await file.writeAsBytes(payload.bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: payload.fileName,
    );
    return file.path;
  }
}
