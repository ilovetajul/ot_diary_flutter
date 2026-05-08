import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';

class PdfService {
  static const _months = [
    'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];
  static const _days = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ];

  static Future<File> generateMonthlyReport({
    required UserProfile profile,
    required Map<int, double> otData,
    required int month,
    required int year,
  }) async {
    final pdf = pw.Document();

    final monthName  = _months[month];
    final totalHours = otData.values.fold(0.0, (a, b) => a + b);
    final otEarning  = totalHours * profile.rate;
    final totalSal   = profile.basic + profile.allowance + otEarning;
    final sortedDays = otData.keys.toList()..sort();

    // ── Text helpers ──
    pw.TextStyle ts(double size,
        {bool bold = false, PdfColor color = PdfColors.black}) =>
        pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        );

    pw.Widget t(String text, double size,
        {bool bold = false, PdfColor color = PdfColors.black}) =>
        pw.Text(text, style: ts(size, bold: bold, color: color));

    pw.Widget cell(String text,
        {bool bold = false,
        PdfColor color = PdfColors.black,
        pw.Alignment align = pw.Alignment.centerLeft}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          alignment: align,
          child: pw.Text(text, style: ts(10.5, bold: bold, color: color)),
        );

    pw.Widget salRow(String label, String value,
        {bool bold = false, PdfColor color = PdfColors.black}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: ts(11.5, bold: bold, color: color)),
              pw.Text(value, style: ts(11.5, bold: bold, color: color)),
            ],
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),

        // ── Header ──
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('OT DIARY',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal700,
                          letterSpacing: 3,
                        )),
                    pw.SizedBox(height: 3),
                    t('Monthly Overtime Report', 12, color: PdfColors.grey700),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal700,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: t('$monthName  $year', 14,
                      bold: true, color: PdfColors.white),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.teal700, thickness: 2),
            pw.SizedBox(height: 6),
          ],
        ),

        // ── Body ──
        build: (ctx) => [

          // Profile box
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    t(profile.name, 17, bold: true),
                    pw.SizedBox(height: 4),
                    t('Employee ID : ${profile.idNo}', 12,
                        color: PdfColors.grey700),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    t('OT Rate : ${profile.rate} BDT / Hour', 12),
                    pw.SizedBox(height: 4),
                    t('Basic Salary : ${profile.basic} BDT', 12),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Summary 3 cards
          pw.Row(children: [
            _card('Total OT Hours', '$totalHours hrs',
                PdfColors.teal700),
            pw.SizedBox(width: 8),
            _card('OT Earnings',
                '${otEarning.toStringAsFixed(0)} BDT',
                PdfColors.deepOrange),
            pw.SizedBox(width: 8),
            _card('Total Salary',
                '${totalSal.toStringAsFixed(0)} BDT',
                PdfColors.amber800),
          ]),
          pw.SizedBox(height: 18),

          t('Daily OT Details', 14, bold: true),
          pw.SizedBox(height: 8),

          // Table
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.0),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FlexColumnWidth(2.0),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.teal700),
                children: [
                  cell('Date', bold: true, color: PdfColors.white),
                  cell('Day', bold: true, color: PdfColors.white),
                  cell('OT Hours', bold: true, color: PdfColors.white),
                  cell('Earnings', bold: true, color: PdfColors.white),
                ],
              ),
              // Data rows
              ...sortedDays.asMap().entries.map((e) {
                final idx = e.key;
                final d   = e.value;
                final dow = DateTime(year, month + 1, d).weekday % 7;
                final hrs = otData[d] ?? 0.0;
                final bg  = idx.isEven
                    ? PdfColors.white
                    : PdfColors.grey50;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('$d $monthName $year'),
                    cell(_days[dow]),
                    cell('$hrs hrs', color: PdfColors.teal700),
                    cell('${(hrs * profile.rate).toStringAsFixed(0)} BDT'),
                  ],
                );
              }).toList(),
              // Total row
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  cell('Total', bold: true),
                  cell('${otData.length} days', bold: true),
                  cell('$totalHours hrs',
                      bold: true, color: PdfColors.teal700),
                  cell('${otEarning.toStringAsFixed(0)} BDT',
                      bold: true, color: PdfColors.teal700),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // Salary breakdown box
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: PdfColors.amber800, width: 1.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                t('Salary Breakdown', 14, bold: true),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey300),
                salRow('Basic Salary',
                    '${profile.basic.toStringAsFixed(0)} BDT'),
                salRow('Allowance',
                    '${profile.allowance.toStringAsFixed(0)} BDT'),
                salRow(
                  'OT Earnings  ($totalHours hrs x ${profile.rate} BDT)',
                  '${otEarning.toStringAsFixed(0)} BDT',
                ),
                pw.Divider(color: PdfColors.grey400, thickness: 1),
                salRow(
                  'Total Salary',
                  '${totalSal.toStringAsFixed(0)} BDT',
                  bold: true,
                  color: PdfColors.amber900,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          t(
            'Generated : ${DateTime.now().day} / '
            '${DateTime.now().month} / ${DateTime.now().year}'
            '   |   OT Diary App',
            10,
            color: PdfColors.grey600,
          ),
        ],
      ),
    );

    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/OT_${monthName}_$year.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _card(String label, String value, PdfColor bg) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10, color: PdfColors.white)),
            pw.SizedBox(height: 5),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ],
        ),
      ),
    );
  }

  static Future<void> sharePdf(File pdfFile) async {
    await Printing.sharePdf(
      bytes:    await pdfFile.readAsBytes(),
      filename: pdfFile.path.split('/').last,
    );
  }
}
