import 'dart:typed_data';

import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_detail.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/template_schema.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds the customer-facing version of a diagnostic report.
///
/// The report is generated from the same schema and data that are rendered on
/// the detail screen, so newly-added worker fields remain visible without a
/// second mobile-specific field list.
Future<Uint8List> buildDiagnosticPdf(DiagnosticReportDetail detail) async {
  final regularFont = await PdfGoogleFonts.notoSansRegular();
  final boldFont = await PdfGoogleFonts.notoSansBold();
  final images = await _loadImages(detail);
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CarCare',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Оношилгооны тайлан',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Хуудас ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          detail.templateName,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _reportTypeLabel(detail.type),
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),
        _metadataCard(detail),
        if (detail.notes != null && detail.notes!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _notesCard(detail.notes!),
        ],
        pw.SizedBox(height: 18),
        for (final section in detail.schema.sections)
          if (section.items.isNotEmpty) ...[
            pw.Text(
              section.title,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final field in _fields(section, detail.data))
                    _fieldView(field, images),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
          ],
      ],
    ),
  );

  return document.save();
}

Future<void> shareDiagnosticPdf(DiagnosticReportDetail detail) async {
  final bytes = await buildDiagnosticPdf(detail);
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'diagnostic-${_filePart(detail.vehiclePlate)}.pdf',
  );
}

class _ReportField {
  const _ReportField({required this.item, required this.label, required this.entry});

  final TemplateItem item;
  final String? label;
  final ReportEntry entry;
}

Iterable<_ReportField> _fields(TemplateSection section, ReportData data) sync* {
  for (final item in section.items) {
    final positions = item.positions;
    if (positions == null) {
      yield _ReportField(item: item, label: null, entry: data.entryFor(item.id));
      continue;
    }
    for (final position in positions) {
      yield _ReportField(
        item: item,
        label: position.label,
        entry: data.entryFor(positionedKey(item.id, position.code)),
      );
    }
  }
}

pw.Widget _metadataCard(DiagnosticReportDetail detail) {
  final vehicle = '${detail.vehicleMake} ${detail.vehicleModel}'.trim();
  final rows = <List<String>>[
    ['Машин', '$vehicle · ${detail.vehiclePlate}'],
    ['Салбар', detail.branchName],
    ['Огноо', _date(detail.createdAt)],
    if (detail.mileageAtReport != null)
      ['Гүйлт', '${detail.mileageAtReport} км'],
    if (detail.severity != null) ['Дүгнэлт', _severityLabel(detail.severity!.name)],
  ];
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final row in rows) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 78,
                child: pw.Text(
                  row[0],
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ),
              pw.Expanded(
                child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          ),
          if (row != rows.last) pw.SizedBox(height: 6),
        ],
      ],
    ),
  );
}

pw.Widget _notesCard(String notes) => pw.Container(
  padding: const pw.EdgeInsets.all(10),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: PdfColors.grey300),
    borderRadius: pw.BorderRadius.circular(8),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Тэмдэглэл',
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
    ],
  ),
);

pw.Widget _fieldView(_ReportField field, Map<String, dynamic> images) {
  final value = _valueLabel(field.item.type, field.entry.value);
  final photoProviders = [
    for (final url in field.entry.photos)
      if (images[url] != null) images[url],
  ];
  final signature = field.item.type == 'signature' && field.entry.value is String
      ? images[field.entry.value]
      : null;
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 7),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          field.label == null ? field.item.label : '${field.item.label} — ${field.label}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        if (signature != null)
          pw.Image(signature, width: 180, height: 72, fit: pw.BoxFit.contain)
        else
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        if (photoProviders.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final image in photoProviders)
                pw.Image(image, width: 76, height: 76, fit: pw.BoxFit.cover),
            ],
          ),
        ],
        if (field.entry.note != null && field.entry.note!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            'Тэмдэглэл: ${field.entry.note}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ],
    ),
  );
}

Future<Map<String, dynamic>> _loadImages(DiagnosticReportDetail detail) async {
  final urls = <String>{};
  for (final entry in detail.data.entries) {
    urls.addAll(entry.value.photos);
    if (entry.value.value is String && (entry.value.value as String).isNotEmpty) {
      final itemType = _itemTypeForKey(detail.schema, entry.key);
      if (itemType == 'signature') urls.add(entry.value.value as String);
    }
  }

  final images = <String, dynamic>{};
  for (final url in urls) {
    if (url.trim().isEmpty) continue;
    try {
      images[url] = await networkImage(url);
    } catch (_) {
      // A missing remote image should not prevent the customer from exporting
      // the rest of an otherwise complete report.
    }
  }
  return images;
}

String? _itemTypeForKey(TemplateSchema schema, String key) {
  for (final section in schema.sections) {
    for (final item in section.items) {
      if (item.id == key) return item.type;
      if (item.positions != null && key.startsWith('${item.id}@')) return item.type;
    }
  }
  return null;
}

String _valueLabel(String type, Object? value) {
  if (value == null || (value is String && value.trim().isEmpty)) return '—';
  if (type == 'signature') return 'Гарын үсэг';
  if (value is bool) return value ? 'Тийм' : 'Үгүй';
  return value.toString();
}

String _reportTypeLabel(String type) => switch (type) {
  'PRE_PURCHASE' => 'Худалдан авахын өмнөх оношилгоо',
  'SERVICE' => 'Үйлчилгээний оношилгоо',
  'INTAKE' => 'Хүлээн авах үеийн оношилгоо',
  'POST_SERVICE' => 'Үйлчилгээний дараах шалгалт',
  _ => type,
};

String _severityLabel(String severity) => switch (severity) {
  'good' => 'Хэвийн',
  'warn' => 'Анхаарах',
  'bad' => 'Солих шаардлагатай',
  _ => severity,
};

String _date(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

String _filePart(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
  return cleaned.isEmpty ? 'report' : cleaned;
}
