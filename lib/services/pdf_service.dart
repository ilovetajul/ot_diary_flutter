import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';
import '../app_theme.dart';

class PdfService {
  static Future<File> generateMonthlyReport({
    required UserProfile profile,
    required Map<int, double> otData,
    required int month,
    required int year,
  }) async {
    final pdf = pw.Document();
    final monthName = AppStrings.months[month];

    // Calculate totals
    double totalHours = otData.values.fold(0, (a, b) => a + b);
    double otEarning = totalHours * profile.rate;
    double totalSalary = profile.basic + profile.allowance + otEarning;

    // Sort days
    final sortedDays = otData.keys.toList()..sort();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
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
                        fontSize: 28, fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal,
                      )),
                    pw.Text('ওভারটাইম রিপোর্ট',
                      style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text('$monthName $year',
                    style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    )),
                ),
              ],
            ),
            pw.Divider(color: PdfColors.teal, thickness: 2),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) => [
          // Profile Info
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(profile.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('আইডি: ${profile.idNo}', style: const pw.TextStyle(color: PdfColors.grey)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('OT রেট: ৳${profile.rate}/ঘন্টা'),
                  pw.Text('মূল বেতন: ৳${profile.basic}'),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Summary Cards
          pw.Row(children: [
            _summaryCard('মোট OT ঘন্টা', '${totalHours}h', PdfColors.teal),
            pw.SizedBox(width: 12),
            _summaryCard('OT আয়', '৳${otEarning.toStringAsFixed(0)}', PdfColors.orange),
            pw.SizedBox(width: 12),
            _summaryCard('মোট বেতন', '৳${totalSalary.toStringAsFixed(0)}', PdfColors.amber),
          ]),
          pw.SizedBox(height: 20),

          // Day Table
          pw.Text('দৈনিক OT বিবরণ',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['তারিখ', 'দিন', 'OT ঘন্টা', 'আয় (৳)'],
            data: sortedDays.map((d) {
              final dow = DateTime(year, month + 1, d).weekday % 7;
              final hrs = otData[d] ?? 0;
              return [
                '$d $monthName',
                AppStrings.days[dow],
                '$hrs',
                '৳${(hrs * profile.rate).toStringAsFixed(0)}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            cellAlignment: pw.Alignment.center,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 20),

          // Salary Breakdown
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(children: [
              pw.Text('বেতন বিবরণ',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              _salaryRow('মূল বেতন', '৳${profile.basic}'),
              _salaryRow('ভাতা', '৳${profile.allowance}'),
              _salaryRow('OT আয় (${totalHours}h × ৳${profile.rate})', '৳${otEarning.toStringAsFixed(0)}'),
              pw.Divider(),
              _salaryRow('মোট বেতন', '৳${totalSalary.toStringAsFixed(0)}', bold: true, color: PdfColors.amber),
            ]),
          ),

          pw.SizedBox(height: 16),
          pw.Text(
            'রিপোর্ট তৈরি: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}  |  OT Diary App',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/OT_Report_${monthName}_$year.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _summaryCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(value,
            style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
    );
  }

  static pw.Widget _salaryRow(String label, String value, {bool bold = false, PdfColor? color}) {
    final style = bold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: color)
        : pw.TextStyle(color: color);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: style), pw.Text(value, style: style)],
      ),
    );
  }

  static Future<void> printReport(File pdfFile) async {
    await Printing.layoutPdf(onLayout: (_) => pdfFile.readAsBytes());
  }

  static Future<void> sharePdf(File pdfFile) async {
    await Printing.sharePdf(bytes: await pdfFile.readAsBytes(), filename: pdfFile.path.split('/').last);
  }
}
