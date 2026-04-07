import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';
import 'package:printing/printing.dart';

class PdfService {
  static Future<File> generateMonthlyReport({
    required UserProfile profile,
    required Map<int, double> otData,
    required int month,
    required int year,
  }) async {
    final pdf = pw.Document();

    // ===== বাংলা ফন্ট লোড করুন =====
    final banglaFont = await PdfGoogleFonts.hindSiliguriRegular();
    final banglaFontBold = await PdfGoogleFonts.hindSiliguriSemiBold();
    final banglaFont = pw.Font.ttf(fontData);
    final banglaFontBold = pw.Font.ttf(boldFontData);

    final months = [
      'জানুয়ারি','ফেব্রুয়ারি','মার্চ','এপ্রিল','মে','জুন',
      'জুলাই','আগস্ট','সেপ্টেম্বর','অক্টোবর','নভেম্বর','ডিসেম্বর'
    ];
    final days = ['রবি','সোম','মঙ্গল','বুধ','বৃহঃ','শুক্র','শনি'];
    final monthName = months[month];

    double totalHours = otData.values.fold(0, (a, b) => a + b);
    double otEarning = totalHours * profile.rate;
    double totalSalary = profile.basic + profile.allowance + otEarning;
    final sortedDays = otData.keys.toList()..sort();

    pw.TextStyle style(double size, {bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
          font: bold ? banglaFontBold : banglaFont,
          fontSize: size,
          color: color ?? PdfColors.black,
        );

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
                          font: banglaFontBold,
                          fontSize: 28,
                          color: PdfColors.teal,
                        )),
                    pw.Text('ওভারটাইম মাসিক রিপোর্ট',
                        style: style(13, color: PdfColors.grey600)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text('$monthName $year',
                      style: style(14, bold: true, color: PdfColors.white)),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.teal, thickness: 2),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) => [

          // প্রোফাইল
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(profile.name, style: style(18, bold: true)),
                  pw.SizedBox(height: 4),
                  pw.Text('আইডি: ${profile.idNo}', style: style(12, color: PdfColors.grey700)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('OT রেট: ৳${profile.rate}/ঘন্টা', style: style(12)),
                  pw.SizedBox(height: 4),
                  pw.Text('মূল বেতন: ৳${profile.basic}', style: style(12)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // সারসংক্ষেপ কার্ড
          pw.Row(children: [
            _summaryCard('মোট OT ঘন্টা', '${totalHours}h', PdfColors.teal700, style),
            pw.SizedBox(width: 10),
            _summaryCard('OT আয়', '৳${otEarning.toStringAsFixed(0)}', PdfColors.orange, style),
            pw.SizedBox(width: 10),
            _summaryCard('মোট বেতন', '৳${totalSalary.toStringAsFixed(0)}', PdfColors.amber700, style),
          ]),
          pw.SizedBox(height: 20),

          // দৈনিক টেবিল
          pw.Text('দৈনিক OT বিবরণ', style: style(15, bold: true)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal),
                children: [
                  _cell('তারিখ', style, bold: true, color: PdfColors.white),
                  _cell('দিন', style, bold: true, color: PdfColors.white),
                  _cell('OT ঘন্টা', style, bold: true, color: PdfColors.white),
                  _cell('আয় (৳)', style, bold: true, color: PdfColors.white),
                ],
              ),
              // Data rows
              ...sortedDays.asMap().entries.map((entry) {
                final idx = entry.key;
                final d = entry.value;
                final dow = DateTime(year, month + 1, d).weekday % 7;
                final hrs = otData[d] ?? 0;
                final bg = idx % 2 == 0 ? PdfColors.white : PdfColors.grey50;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _cell('$d $monthName', style),
                    _cell(days[dow], style),
                    _cell('${hrs}h', style, color: PdfColors.teal700),
                    _cell('৳${(hrs * profile.rate).toStringAsFixed(0)}', style),
                  ],
                );
              }).toList(),

              // Total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  _cell('মোট', style, bold: true),
                  _cell('${otData.length} দিন', style, bold: true),
                  _cell('${totalHours}h', style, bold: true, color: PdfColors.teal700),
                  _cell('৳${otEarning.toStringAsFixed(0)}', style, bold: true, color: PdfColors.teal700),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // বেতন বিবরণ
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber700, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('বেতন বিবরণ', style: style(15, bold: true)),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey300),
              _salaryRow('মূল বেতন', '৳${profile.basic.toStringAsFixed(0)}', style),
              _salaryRow('ভাতা', '৳${profile.allowance.toStringAsFixed(0)}', style),
              _salaryRow(
                'OT আয় (${totalHours}h × ৳${profile.rate})',
                '৳${otEarning.toStringAsFixed(0)}',
                style,
              ),
              pw.Divider(color: PdfColors.grey400, thickness: 1.5),
              _salaryRow(
                'মোট বেতন',
                '৳${totalSalary.toStringAsFixed(0)}',
                style,
                bold: true,
                color: PdfColors.amber800,
              ),
            ]),
          ),
          pw.SizedBox(height: 20),

          pw.Text(
            'রিপোর্ট তৈরি: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}  |  OT Diary App',
            style: style(10, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/OT_Report_${monthName}_$year.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _summaryCard(
    String label, String value, PdfColor color,
    pw.TextStyle Function(double, {bool bold, PdfColor? color}) style,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: style(10, color: PdfColors.white)),
          pw.SizedBox(height: 6),
          pw.Text(value, style: style(18, bold: true, color: PdfColors.white)),
        ]),
      ),
    );
  }

  static pw.Widget _cell(
    String text,
    pw.TextStyle Function(double, {bool bold, PdfColor? color}) style, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text, style: style(11, bold: bold, color: color)),
    );
  }

  static pw.Widget _salaryRow(
    String label, String value,
    pw.TextStyle Function(double, {bool bold, PdfColor? color}) style, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style(12, bold: bold, color: color)),
          pw.Text(value, style: style(12, bold: bold, color: color)),
        ],
      ),
    );
  }

  static Future<void> sharePdf(File pdfFile) async {
    await Printing.sharePdf(
      bytes: await pdfFile.readAsBytes(),
      filename: pdfFile.path.split('/').last,
    );
  }
}
