import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../app/services.dart';
import '../../data/repositories/entry_repository.dart';
import 'export_saver.dart';
import 'export_service.dart';

/// E-04: the export chooser. It offers exactly two formats — PDF and TXT.
/// Markdown is internal storage only and must never appear here.
class ExportDialog {
  ExportDialog._();

  static Future<void> show(
    BuildContext context,
    List<EntryBundle> bundles,
  ) async {
    if (bundles.isEmpty) return;

    final selected = <ExportFormat>{ExportFormat.pdf};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          icon: const Icon(AppIcons.export),
          title: Text(
            bundles.length == 1
                ? 'Export item'
                : 'Export ${bundles.length} items',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final format in ExportFormat.values)
                CheckboxListTile(
                  value: selected.contains(format),
                  onChanged: (checked) => setDialogState(() {
                    if (checked == true) {
                      selected.add(format);
                    } else {
                      selected.remove(format);
                    }
                  }),
                  title: Text(format.label),
                  subtitle: Text(
                    format == ExportFormat.pdf
                        ? 'Formatted document with images'
                        : 'Plain text, easy to reuse anywhere',
                  ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              const SizedBox(height: 8),
              Text(
                bundles.length == 1
                    ? 'Saved as a single file.'
                    : 'Saved as one .zip containing every file, plus an '
                        'images folder.',
                style: Theme.of(builderContext).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final services = context.read<Services>();

    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing export...')),
    );

    try {
      // E-14: everything below is local. No network involved.
      final payload = (bundles.length == 1 && selected.length == 1)
          ? await services.exporter.exportSingle(bundles.first, selected.first)
          : await services.exporter.exportMany(bundles, selected);

      final path = await ExportSaver.save(payload);

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            path == null ? 'Export cancelled' : 'Exported ${payload.fileName}',
          ),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}
