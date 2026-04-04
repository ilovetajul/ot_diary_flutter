import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_theme.dart';
import '../models/user_profile.dart';

class ChartScreen extends StatelessWidget {
  final Map<int, double> otData;
  final UserProfile profile;
  final int month;
  final int year;

  const ChartScreen({super.key,
    required this.otData, required this.profile,
    required this.month, required this.year});

  @override
  Widget build(BuildContext context) {
    final days = otData.keys.toList()..sort();
    final bars = days.map((d) => BarChartGroupData(
      x: d,
      barRods: [BarChartRodData(
        toY: otData[d]!,
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.gold],
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
        ),
        width: 14, borderRadius: BorderRadius.circular(6),
      )],
    )).toList();

    final totalHours = otData.values.fold(0.0, (a, b) => a + b);
    final totalSalary = profile.basic + profile.allowance + (totalHours * profile.rate);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('${AppStrings.months[month]} চার্ট',
          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // Stats row
          Row(children: [
            _statCard('মোট ঘন্টা', '${totalHours}h', AppColors.accent),
            const SizedBox(width: 10),
            _statCard('মোট বেতন', '৳${totalSalary.toStringAsFixed(0)}', AppColors.gold),
            const SizedBox(width: 10),
            _statCard('OT দিন', '${otData.length}দিন', AppColors.orange),
          ]),
          const SizedBox(height: 20),

          // Bar Chart
          if (bars.isEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.card, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text('এই মাসে কোনো OT নেই',
                  style: TextStyle(color: AppColors.muted, fontSize: 15)),
              ),
            )
          else
            Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: BarChart(BarChartData(
                barGroups: bars,
                backgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 30,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 24,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: const TextStyle(fontSize: 9, color: AppColors.muted)),
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 10,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${group.x} তারিখ\n${rod.toY}h',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )),
            ),
          const SizedBox(height: 20),

          // Daily breakdown
          Container(
            decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('দৈনিক বিবরণ',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text2)),
                  Text('${otData.length}টি এন্ট্রি',
                    style: const TextStyle(fontSize: 12, color: AppColors.accent)),
                ]),
              ),
              const Divider(color: AppColors.border, height: 1),
              ...days.map((d) => ListTile(
                dense: true,
                title: Text('$d ${AppStrings.months[month]}',
                  style: const TextStyle(fontSize: 13, color: AppColors.text)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${otData[d]}h',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Text('৳${((otData[d]! * profile.rate)).toStringAsFixed(0)}',
                    style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                ]),
              )).toList(),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: AppColors.muted,
            fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ]),
    ));
  }
}
