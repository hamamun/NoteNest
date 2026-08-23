import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/logging.dart';
import '../../core/time.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/checklist_matcher.dart';
import '../../data/repositories/entry_repository.dart';

/// DEC-2: exactly two export formats. Nothing else may be added here.
enum ExportFormat {
  pdf('pdf', 'PDF', '.pdf'),
  txt('txt', 'Plain text', '.txt');

  const ExportFormat(this.value, this.label, this.extension);
  final String value;
  final String label;
  final String extension;
}

class ExportPayload {
  const ExportPayload(this.fileName, this.bytes);
  final String fileName;
  final Uint8List bytes;
}

/// E-01..E-14: builds export files entirely from local data (E-14 — no
/// network involved at any point).
class ExportService {
  ExportService(this._repo);

  final EntryRepository _repo;

  /// E-05: `Title - 2026-08-23.pdf`, with unsafe characters removed.
  static String safeFileName(String title, int updatedAt, String extension) {
    var base = title.trim();
    if (base.isEmpty) base = 'Untitled';

    // Strip characters Windows and Android both dislike.
    base = base.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ');
    base = base.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Windows also rejects a trailing dot or space.
    base = base.replaceAll(RegExp(r'[. ]+$'), '');
    if (base.isEmpty) base = 'Untitled';
    if (base.length > 80) base = base.substring(0, 80).trim();

    // Reserved DOS device names.
    const reserved = {
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    };
    if (reserved.contains(base.toUpperCase())) base = '_$base';

    return '$base - ${AppTime.dateStamp(updatedAt)}$extension';
  }

  /// E-05: single item, single file.
  Future<ExportPayload> exportSingle(
    EntryBundle bundle,
    ExportFormat format,
  ) async {
    final name = safeFileName(
      bundle.entry.title,
      bundle.entry.updatedAt,
      format.extension,
    );
    final bytes = switch (format) {
      ExportFormat.txt => Uint8List.fromList(utf8.encode(buildTxt(bundle))),
      ExportFormat.pdf => await buildPdf([bundle]),
    };
    return ExportPayload(name, bytes);
  }

  /// E-06: several items become one zip containing the individual files plus
  /// an `images/` folder.
  Future<ExportPayload> exportMany(
    List<EntryBundle> bundles,
    Set<ExportFormat> formats,
  ) async {
    final archive = Archive();
    final usedNames = <String>{};

    String unique(String name) {
      var candidate = name;
      var counter = 2;
      while (usedNames.contains(candidate)) {
        final dot = name.lastIndexOf('.');
        candidate = '${name.substring(0, dot)} ($counter)${name.substring(dot)}';
        counter++;
      }
      usedNames.add(candidate);
      return candidate;
    }

    for (final bundle in bundles) {
      if (formats.contains(ExportFormat.txt)) {
        final name = unique(safeFileName(
          bundle.entry.title,
          bundle.entry.updatedAt,
          '.txt',
        ));
        final data = Uint8List.fromList(utf8.encode(buildTxt(bundle)));
        archive.addFile(ArchiveFile(name, data.length, data));
      }
      if (formats.contains(ExportFormat.pdf)) {
        final name = unique(safeFileName(
          bundle.entry.title,
          bundle.entry.updatedAt,
          '.pdf',
        ));
        final data = await buildPdf([bundle]);
        archive.addFile(ArchiveFile(name, data.length, data));
      }

      for (final image in bundle.images) {
        final file = File(image.localPath);
        if (!file.existsSync()) continue;
        final data = await file.readAsBytes();
        archive.addFile(
          ArchiveFile('images/${image.fileName}', data.length, data),
        );
      }
    }

    final encoded = ZipEncoder().encode(archive) ?? <int>[];
    return ExportPayload(
      'notenest-export-${AppTime.dateStamp(AppTime.nowMs())}.zip',
      Uint8List.fromList(encoded),
    );
  }

  // ---------------------------------------------------------------------
  // E-10 / E-11: plain text
  // ---------------------------------------------------------------------

  String buildTxt(EntryBundle bundle) {
    final buffer = StringBuffer();
    final title = bundle.entry.title.trim();
    buffer.writeln(title.isEmpty ? 'Untitled' : title);
    buffer.writeln();

    if (bundle.isChecklist) {
      // E-11: ascii checkbox marks.
      buffer.writeln(ChecklistMatcher.toTxtExport(bundle.lines));
    } else {
      buffer.writeln(bundle.entry.body);
    }

    if (bundle.images.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('---')
        ..writeln('${bundle.images.length} image'
            '${bundle.images.length == 1 ? "" : "s"} attached '
            '(included in the export folder).');
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------
  // E-07 / E-08 / E-09: PDF, generated locally
  // ---------------------------------------------------------------------

  Future<Uint8List> buildPdf(List<EntryBundle> bundles) async {
    final doc = pw.Document(title: 'NoteNest export');

    // E-14 says export must work offline, so font loading is best-effort and
    // never blocks:
    //   1. a bundled asset, if the user added one (see README — this is how
    //      you get Bengali, Hindi, Arabic or CJK text in PDFs)
    //   2. Google Fonts, when online
    //   3. the built-in Helvetica, which covers Latin text
    pw.Font? regular;
    pw.Font? bold;

    try {
      regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    } catch (_) {
      AppLog.info('export', 'using the built-in PDF font (Latin script only)');
    }

    final theme = regular != null
        ? pw.ThemeData.withFont(base: regular, bold: bold)
        : pw.ThemeData.base();

    for (final bundle in bundles) {
      final images = <pw.MemoryImage>[];
      for (final image in bundle.images.take(8)) {
        try {
          final file = File(image.localPath);
          if (file.existsSync()) {
            images.add(pw.MemoryImage(await file.readAsBytes()));
          }
        } catch (_) {
          // An unreadable image must never abort the whole export.
        }
      }

      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => [
            _pdfHeader(bundle),
            pw.SizedBox(height: 16),
            if (images.isNotEmpty) ...[
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: images
                    .map((i) => pw.Container(
                          width: 160,
                          height: 120,
                          child: pw.Image(i, fit: pw.BoxFit.cover),
                        ))
                    .toList(),
              ),
              pw.SizedBox(height: 16),
            ],
            if (bundle.isChecklist)
              ..._pdfChecklist(bundle)
            else
              pw.Text(
                bundle.entry.body,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
              ),
          ],
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _pdfHeader(EntryBundle bundle) {
    final title = bundle.entry.title.trim();
    final location = EntryLocation.parse(bundle.entry.location);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.isEmpty ? 'Untitled' : title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Text(
              'Created ${AppTime.full(bundle.entry.createdAt)}   '
              'Updated ${AppTime.full(bundle.entry.updatedAt)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        // E-07: archive/trash status when it is not a normal active item.
        if (location != EntryLocation.active) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            location == EntryLocation.archive ? 'ARCHIVED' : 'IN TRASH',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Divider(height: 1, color: PdfColors.grey400),
      ],
    );
  }

  /// E-08: checkboxes are DRAWN, not typed.
  ///
  /// Using the ballot-box characters would depend on the PDF font carrying
  /// those glyphs; with the built-in Helvetica they render as blanks. A small
  /// bordered square always works.
  List<pw.Widget> _pdfChecklist(EntryBundle bundle) {
    if (bundle.lines.isEmpty) {
      return [
        pw.Text('(empty list)',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
      ];
    }
    return bundle.lines
        .map(
          (line) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 10,
                  height: 10,
                  margin: const pw.EdgeInsets.only(top: 2, right: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(2),
                    color: line.checked ? PdfColors.grey700 : PdfColors.white,
                  ),
                  child: line.checked
                      ? pw.Center(
                          child: pw.Text(
                            'X',
                            style: pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                pw.Expanded(
                  child: pw.Text(
                    line.text,
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: line.checked ? PdfColors.grey600 : PdfColors.black,
                      decoration: line.checked
                          ? pw.TextDecoration.lineThrough
                          : pw.TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Future<List<EntryBundle>> bundlesFor(List<String> ids) =>
      _repo.entriesByIds(ids);

  @visibleForTesting
  static String debugSafeName(String title, int ms, String ext) =>
      safeFileName(title, ms, ext);
}
