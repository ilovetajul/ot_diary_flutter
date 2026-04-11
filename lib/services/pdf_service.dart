import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';

class PdfService {
  // ── যুক্তাক্ষর এড়িয়ে সহজ বাংলা শব্দ ──
  static const _months = [
    'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল',
    'মে', 'জুন', 'জুলাই', 'আগস্ট',
    'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
  ];
  static const _days = [
    'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি',
  ];

  static Future<File> generateMonthlyReport({
    required UserProfile profile,
    required Map<int, double> otData,
    required int month,
    required int year,
  }) async {
    // ── Font লোড ──
    final fontData     = await rootBundle.load('assets/fonts/HindSiliguri-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/HindSiliguri-Bold.ttf');
    final font     = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(boldFontData);

    final theme = pw.ThemeData.withFont(
      base: font, bold: fontBold,
      italic: font, boldItalic: fontBold,
    );
    final pdf = pw.Document(theme: theme);

    final monthName  = _months[month];
    final totalHours = otData.values.fold(0.0, (a, b) => a + b);
    final otEarning  = totalHours * profile.rate;
    final totalSal   = profile.basic + profile.allowance + otEarning;
    final sortedDays = otData.keys.toList()..sort();

    // ── Text helpers ──
    pw.TextStyle ts(double size,
        {bool bold = false, PdfColor color = PdfColors.black}) =>
        pw.TextStyle(
          font: bold ? fontBold : font,
          fontSize: size,
          color: color,
        );

    pw.Widget t(String text, double size,
        {bool bold = false, PdfColor color = PdfColors.black}) =>
        pw.Text(text,
            style: ts(size, bold: bold, color: color),
            textDirection: pw.TextDirection.ltr);

    pw.Widget cell(String text,
        {bool bold = false, PdfColor color = PdfColors.black}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: pw.Text(text,
              style: ts(10.5, bold: bold, color: color),
              textDirection: pw.TextDirection.ltr),
        );

    pw.Widget salRow(String label, String value,
        {bool bold = false, PdfColor color = PdfColors.black}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: ts(11.5, bold: bold, color: color),
                  textDirection: pw.TextDirection.ltr),
              pw.Text(value,
                  style: ts(11.5, bold: bold, color: color),
                  textDirection: pw.TextDirection.ltr),
            ],
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,

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
                          font: fontBold, fontSize: 28,
                          color: PdfColors.teal700, letterSpacing: 2,
                        )),
                    pw.SizedBox(height: 3),
                    // "ওভারটাইম" → যুক্তাক্ষর সমস্যা এড়াতে ভেঙে লিখি
                    t('মাসিক OT রিপোর্ট', 13, color: PdfColors.grey700),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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

          // প্রোফাইল বক্স
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
                    t('ID :  ${profile.idNo}', 12, color: PdfColors.grey700),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    t('OT রেট :  ${profile.rate} টাকা / ঘন্টা', 12),
                    pw.SizedBox(height: 4),
                    t('মূল বেতন :  ${profile.basic} টাকা', 12),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // সারসংক্ষেপ ৩ কার্ড
          pw.Row(children: [
            _card('মোট OT', '$totalHours ঘন্টা',
                PdfColors.teal700, font, fontBold),
            pw.SizedBox(width: 8),
            _card('OT আয়', '${otEarning.toStringAsFixed(0)} টাকা',
                PdfColors.deepOrange, font, fontBold),
            pw.SizedBox(width: 8),
            _card('মোট বেতন', '${totalSal.toStringAsFixed(0)} টাকা',
                PdfColors.amber800, font, fontBold),
          ]),
          pw.SizedBox(height: 18),

          t('দৈনিক OT বিবরণ', 14, bold: true),
          pw.SizedBox(height: 8),

          // টেবিল
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.0),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FlexColumnWidth(2.0),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal700),
                children: [
                  cell('তারিখ', bold: true, color: PdfColors.white),
                  cell('দিন', bold: true, color: PdfColors.white),
                  cell('OT ঘন্টা', bold: true, color: PdfColors.white),
                  cell('আয় (টাকা)', bold: true, color: PdfColors.white),
                ],
              ),
              // Data rows
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
                    cell(_days[dow]),
                    cell('$hrs ঘন্টা', color: PdfColors.teal700),
                    cell('${(hrs * profile.rate).toStringAsFixed(0)} টাকা'),
                  ],
                );
              }).toList(),
              // মোট row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  cell('মোট', bold: true),
                  cell('${otData.length} দিন', bold: true),
                  cell('$totalHours ঘন্টা', bold: true, color: PdfColors.teal700),
                  cell('${otEarning.toStringAsFixed(0)} টাকা',
                      bold: true, color: PdfColors.teal700),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // বেতন বিবরণ বক্স
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber800, width: 1.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                t('বেতন বিবরণ', 14, bold: true),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey300),
                salRow('মূল বেতন',
                    '${profile.basic.toStringAsFixed(0)} টাকা'),
                salRow('ভাতা',
                    '${profile.allowance.toStringAsFixed(0)} টাকা'),
                salRow(
                  'OT আয়  ($totalHours ঘন্টা x ${profile.rate} টাকা)',
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

          t(
            'তৈরি :  ${DateTime.now().day} / '
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

  static pw.Widget _card(String label, String value,
      PdfColor bg, pw.Font font, pw.Font fontBold) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bg, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.white),
                textDirection: pw.TextDirection.ltr),
            pw.SizedBox(height: 5),
            pw.Text(value,
                style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColors.white),
                textDirection: pw.TextDirection.ltr),
          ],
        ),
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
