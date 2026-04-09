import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';

class PdfService {
  static Future<File> generateMonthlyReport({
    required UserProfile profile,
    required Map<int, double> otData,
    required int month,
    required int year,
  }) async {
    // ===== ফন্ট লোড =====
    final fontData = await rootBundle.load(
        'assets/fonts/HindSiliguri-Regular.ttf');
    final boldFontData = await rootBundle.load(
        'assets/fonts/HindSiliguri-Bold.ttf');
    final banglaFont     = pw.Font.ttf(fontData);
    final banglaFontBold = pw.Font.ttf(boldFontData);

    // ===== Global ThemeData — সব text এ বাংলা ফন্ট =====
    final theme = pw.ThemeData.withFont(
      base:        banglaFont,
      bold:        banglaFontBold,
      italic:      banglaFont,
      boldItalic:  banglaFontBold,
    );

    final pdf = pw.Document(theme: theme);

    final months = [
      'জানুয়ারি','ফেব্রুয়ারি','মার্চ','এপ্রিল','মে','জুন',
      'জুলাই','আগস্ট','সেপ্টেম্বর','অক্টোবর','নভেম্বর','ডিসেম্বর',
    ];
    final days = [
      'রবি','সোম','মঙ্গল','বুধ','বৃহঃ','শুক্র','শনি',
    ];

    final monthName  = months[month];
    final totalHours = otData.values.fold(0.0, (a, b) => a + b);
    final otEarning  = totalHours * profile.rate;
    final totalSal   = profile.basic + profile.allowance + otEarning;
    final sortedDays = otData.keys.toList()..sort();

    // ===== Helper styles =====
    pw.TextStyle ts(double size,
        {bool bold = false, PdfColor color = PdfColors.black}) {
      return pw.TextStyle(
        font:     bold ? banglaFontBold : banglaFont,
        fontSize: size,
        color:    color,
      );
    }

    // ===== Helper: text widget =====
    pw.Widget txt(String text, double size,
        {bool bold = false, PdfColor color = PdfColors.black}) {
      return pw.Text(
        text,
        style: ts(size, bold: bold, color: color),
        textDirection: pw.TextDirection.ltr,
      );
    }

    // ===== Table cell =====
    pw.Widget cell(String text,
        {bool bold = false, PdfColor color = PdfColors.black}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text,
          style: ts(10, bold: bold, color: color),
          textDirection: pw.TextDirection.ltr,
        ),
      );
    }

    // ===== Salary row =====
    pw.Widget salRow(String label, String value,
        {bool bold = false, PdfColor color = PdfColors.black}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: ts(11, bold: bold, color: color),
                textDirection: pw.TextDirection.ltr),
            pw.Text(value,
                style: ts(11, bold: bold, color: color),
                textDirection: pw.TextDirection.ltr),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        theme: theme,

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
                          fontSize: 26,
                          color: PdfColors.teal700,
                          letterSpacing: 2,
                        )),
                    pw.SizedBox(height: 2),
                    txt('ওভারটাইম মাসিক রিপোর্ট', 12,
                        color: PdfColors.grey600),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal700,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: txt('$monthName  $year', 13,
                      bold: true, color: PdfColors.white),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.teal700, thickness: 2),
            pw.SizedBox(height: 6),
          ],
        ),

        build: (context) => [

          // প্রোফাইল
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
                    txt(profile.name, 16, bold: true),
                    pw.SizedBox(height: 4),
                    txt('আইডি :  ${profile.idNo}', 11,
                        color: PdfColors.grey700),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    txt('OT রেট :  ${profile.rate} টাকা / ঘন্টা', 11),
                    pw.SizedBox(height: 4),
                    txt('মূল বেতন :  ${profile.basic} টাকা', 11),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // সারসংক্ষেপ কার্ড
          pw.Row(children: [
            _sCard('মোট OT ঘন্টা', '${totalHours} ঘন্টা',
                PdfColors.teal700, banglaFont, banglaFontBold),
            pw.SizedBox(width: 8),
            _sCard('OT আয়', '${otEarning.toStringAsFixed(0)} টাকা',
                PdfColors.deepOrange, banglaFont, banglaFontBold),
            pw.SizedBox(width: 8),
            _sCard('মোট বেতন', '${totalSal.toStringAsFixed(0)} টাকা',
                PdfColors.amber800, banglaFont, banglaFontBold),
          ]),
          pw.SizedBox(height: 18),

          txt('দৈনিক OT বিবরণ', 13, bold: true),
          pw.SizedBox(height: 6),

          // টেবিল
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FlexColumnWidth(2.0),
            },
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.teal700),
                children: [
                  cell('তারিখ', bold: true, color: PdfColors.white),
                  cell('দিন', bold: true, color: PdfColors.white),
                  cell('OT ঘন্টা', bold: true, color: PdfColors.white),
                  cell('আয় ( টাকা )', bold: true, color: PdfColors.white),
                ],
              ),
              ...sortedDays.asMap().entries.map((e) {
                final idx = e.key;
                final d   = e.value;
                final dow = DateTime(year, month + 1, d).weekday % 7;
                final hrs = otData[d] ?? 0.0;
                final bg  = idx.isEven ? PdfColors.white : PdfColors.grey50;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('$d  $monthName'),
                    cell(days[dow]),
                    cell('$hrs ঘন্টা', color: PdfColors.teal700),
                    cell('${(hrs * profile.rate).toStringAsFixed(0)} টাকা'),
                  ],
                );
              }).toList(),
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  cell('মোট', bold: true),
                  cell('${otData.length} দিন', bold: true),
                  cell('$totalHours ঘন্টা',
                      bold: true, color: PdfColors.teal700),
                  cell('${otEarning.toStringAsFixed(0)} টাকা',
                      bold: true, color: PdfColors.teal700),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // বেতন বিবরণ
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: PdfColors.amber800, width: 1.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                txt('বেতন বিবরণ', 13, bold: true),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey300),
                salRow('মূল বেতন',
                    '${profile.basic.toStringAsFixed(0)} টাকা'),
                salRow('ভাতা',
                    '${profile.allowance.toStringAsFixed(0)} টাকা'),
                salRow(
                  'OT আয়  ( $totalHours ঘন্টা  x  ${profile.rate} টাকা )',
                  '${otEarning.toStringAsFixed(0)} টাকা',
                ),
                pw.Divider(color: PdfColors.grey400, thickness: 1),
                salRow(
                  'মোট বেতন',
                  '${totalSal.toStringAsFixed(0)} টাকা',
                  bold: true,
                  color: PdfColors.amber900,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          txt(
            'রিপোর্ট তৈরি :  ${DateTime.now().day} / '
            '${DateTime.now().month} / ${DateTime.now().year}'
            '     |     OT Diary App',
            9,
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

  static pw.Widget _sCard(String label, String value, PdfColor bg,
      pw.Font font, pw.Font boldFont) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: font, fontSize: 9, color: PdfColors.white),
                textDirection: pw.TextDirection.ltr),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    font: boldFont, fontSize: 14, color: PdfColors.white),
                textDirection: pw.TextDirection.ltr),
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
