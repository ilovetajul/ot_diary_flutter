import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/extra_tools.dart';

class ExtraToolsScreen extends StatefulWidget {
  const ExtraToolsScreen({super.key, required this.profile, required this.year, required this.month, required this.data});
  final UserProfile profile;
  final int year;
  final int month;
  final Map<int, double> data;

  @override
  State<ExtraToolsScreen> createState() => _ExtraToolsScreenState();
}

class _ExtraToolsScreenState extends State<ExtraToolsScreen> {
  late Map<int, double> _data = Map.of(widget.data);
  late int _year = widget.year;
  late int _month = widget.month;
  late int _selected = DateTime.now().year == _year && DateTime.now().month == _month ? DateTime.now().day : 1;
  late int _reportYear = _year;
  Set<String> _holidays = {};
  double _target = 120;
  bool _busy = true;
  Map<String, dynamic>? _annual;
  int get _days => DateTime(_year, _month + 1, 0).day;
  double get _total => _data.values.fold<double>(0, (s, h) => s + h);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final values = await DatabaseService.getMonthData(_year, _month);
      final holidays = await ExtraTools.holidays();
      final target = await ExtraTools.target(_year, _month);
      if (!mounted) return;
      setState(() { _data = values; _holidays = holidays; _target = target; _busy = false; });
      await ExtraTools.publishWidget(_year, _month, values);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message('তথ্য লোড হয়নি: $e');
    }
  }
  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await action(); } catch (e) { _message('কাজটি সম্পন্ন হয়নি: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _changeMonth(int delta) async {
    if (_busy) return;
    final date = DateTime(_year, _month + delta);
    setState(() { _year = date.year; _month = date.month; _selected = 1; _data = {}; _busy = true; });
    await _load();
  }
  Future<void> _save(double h) async {
    if (!ExtraTools.validHours(h)) { _message('০ থেকে ২৪ ঘণ্টার মধ্যে লিখুন।'); return; }
    if (_busy) return;
    final day = _selected;
    final previous = _data[day];
    if (previous != null && previous != h) {
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('OT পরিবর্তন করবেন?'), content: Text('$day তারিখের $previous ঘণ্টা বদলে $h ঘণ্টা হবে।'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('নিশ্চিত'))],
      ));
      if (confirmed != true || !mounted) return;
    }
    await _run(() async {
      await DatabaseService.saveOTDay(_year, _month, day, h);
      if (!mounted) return;
      setState(() { if (h == 0) { _data.remove(day); } else { _data[day] = h; } _annual = null; });
      await ExtraTools.publishWidget(_year, _month, _data);
      _message('OT ডিভাইসে সেভ হয়েছে।');
    });
  }
  Future<double?> _numberDialog(String title, double current, double max, {bool allowZero = true}) async {
    var raw = current.toString();
    return showDialog<double>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) {
      final v = double.tryParse(raw);
      final valid = v != null && v.isFinite && v <= max && (allowZero ? v >= 0 : v > 0);
      return AlertDialog(title: Text(title), content: TextFormField(initialValue: raw, autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'ঘণ্টা', helperText: 'সর্বোচ্চ $max'),
        onChanged: (value) => update(() => raw = value)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          FilledButton(onPressed: valid ? () => Navigator.pop(ctx, v) : null, child: const Text('সেভ'))]);
    }));
  }
  Future<void> _customEntry() async {
    final value = await _numberDialog('$_selected তারিখের OT', _data[_selected] ?? 0, 24);
    if (value != null && mounted) await _save(value);
  }
  Future<void> _editTarget() async {
    final value = await _numberDialog('মাসিক OT লক্ষ্য', _target, (_days * 24).toDouble(), allowZero: false);
    if (value == null || !mounted) return;
    await _run(() async {
      await ExtraTools.setTarget(_year, _month, value);
      if (mounted) setState(() => _target = value);
    });
  }
  Future<void> _toggleHoliday() async => _run(() async {
    await ExtraTools.toggleHoliday(_year, _month, _selected);
    final holidays = await ExtraTools.holidays();
    if (mounted) setState(() => _holidays = holidays);
  });
  Future<void> _backup() async => _run(() async {
    final data = await ExtraTools.snapshot();
    if (!mounted) return;
    final complete = data['complete'] == true;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(complete ? 'OT ব্যাকআপ' : 'আংশিক অফলাইন ব্যাকআপ'),
      content: Text(complete ? 'ক্লাউডে পাওয়া OT, স্থানীয় pending OT, প্রোফাইল তথ্য, লক্ষ্য ও ছুটির দিন JSON ফাইলে থাকবে। ছবির মূল ফাইল/পাসওয়ার্ড থাকবে না।' : 'ইন্টারনেট বা ক্লাউড ডেটা পাওয়া যায়নি। শুধু ডিভাইসে থাকা মাস এবং pending OT থাকবে। ফাইলটিকে পূর্ণ ব্যাকআপ ধরে নেবেন না।'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ফাইল সেভ'))]));
    if (confirmed != true) return;
    final saved = await ExtraTools.saveFile('OT_backup_${DateTime.now().millisecondsSinceEpoch}.json', 'application/json', const JsonEncoder.withIndent('  ').convert(data));
    if (saved) _message('ব্যাকআপ ফাইল সেভ হয়েছে।');
  });
  Future<void> _restore() async => _run(() async {
    final raw = await ExtraTools.pickBackup();
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid JSON backup');
    final data = ExtraTools.validatedBackup(decoded, ExtraTools.account);
    final count = data.values.fold<int>(0, (s, m) => s + m.length);
    if (!mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('নিরাপদ Restore'),
      content: Text('$count টি OT এন্ট্রি পাওয়া গেছে। কেবল অনুপস্থিত তারিখ যোগ হবে, বর্তমান OT ও প্রোফাইল বদলাবে না। ইন্টারনেট ও সম্পূর্ণ Sync প্রয়োজন।'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore'))]));
    if (ok != true) return;
    final restored = await ExtraTools.restoreMissing(decoded);
    _annual = null;
    await _load();
    _message('$restored টি অনুপস্থিত OT যোগ হয়েছে।');
  });
  Future<void> _yearly() async => _run(() async {
    final value = await ExtraTools.snapshot();
    if (mounted) setState(() => _annual = value);
  });
  Widget _section(String title, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12), ...children,
  ])));
  Widget _calendar() {
    final first = DateTime(_year, _month).weekday % 7;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cells = <Widget>[
      for (final d in ['রবি','সোম','মঙ্গল','বুধ','বৃহঃ','শুক্র','শনি']) Center(child: Text(d, style: theme.textTheme.labelSmall)),
      for (var i = 0; i < first; i++) const SizedBox.shrink(),
      for (var day = 1; day <= _days; day++)
        InkWell(borderRadius: BorderRadius.circular(8), onTap: _busy ? null : () => setState(() => _selected = day), child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: day == _selected ? scheme.primary : scheme.outlineVariant, width: day == _selected ? 2 : 1),
            color: _holidays.contains(ExtraTools.dateKey(_year, _month, day)) ? scheme.tertiaryContainer : (_data[day] ?? 0) > 0 ? scheme.primaryContainer : null),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$day', style: theme.textTheme.labelLarge),
            FittedBox(child: Text((_data[day] ?? 0) > 0 ? '${_data[day]}h' : '—', style: theme.textTheme.labelSmall)),
          ]),
        )),
    ];
    return _section('ক্যালেন্ডার ও দ্রুত OT এন্ট্রি', [
      Row(children: [IconButton(onPressed: _busy ? null : () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)), Expanded(child: Center(child: Text('${AppStrings.months[_month - 1]} $_year', style: theme.textTheme.titleMedium))), IconButton(onPressed: _busy ? null : () => _changeMonth(1), icon: const Icon(Icons.chevron_right))]),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: .85, children: cells),
      const SizedBox(height: 12), Text('নির্বাচিত: $_selected তারিখ • ${_data[_selected] ?? 0} ঘণ্টা'),
      Wrap(spacing: 8, children: [for (final h in [2, 3, 5, 7]) ActionChip(label: Text('$h ঘণ্টা'), onPressed: _busy ? null : () => _save(h.toDouble())), ActionChip(label: const Text('অন্যান্য'), onPressed: _busy ? null : _customEntry)]),
      OutlinedButton.icon(onPressed: _busy ? null : _toggleHoliday, icon: const Icon(Icons.event_available), label: Text(_holidays.contains(ExtraTools.dateKey(_year, _month, _selected)) ? 'ছুটির চিহ্ন সরান' : 'ছুটির দিন হিসেবে চিহ্নিত করুন')),
      const Text('ছুটির দিন কেবল চিহ্নিত হয়; OT বা বেতনের হিসাব স্বয়ংক্রিয়ভাবে বদলায় না।'),
    ]);
  }
  Widget _annualReport() {
    final report = _annual;
    final raw = report?['ot'];
    final rows = <double>[];
    var recordedDays = 0;
    for (var m = 1; m <= 12; m++) {
      final key = ExtraTools.monthKey(_reportYear, m);
      final days = ExtraTools.decodeDays(raw is Map ? raw[key] : null, key);
      rows.add(days.values.fold<double>(0, (sum, h) => sum + h));
      recordedDays += days.length;
    }
    final total = rows.fold<double>(0, (s, h) => s + h);
    return _section('বার্ষিক রিপোর্ট', [
      Row(children: [IconButton(onPressed: _busy ? null : () => setState(() => _reportYear--), icon: const Icon(Icons.chevron_left)), Expanded(child: Center(child: Text('$_reportYear'))), IconButton(onPressed: _busy ? null : () => setState(() => _reportYear++), icon: const Icon(Icons.chevron_right))]),
      FilledButton.tonal(onPressed: _busy ? null : _yearly, child: const Text('বার্ষিক তথ্য লোড / রিফ্রেশ')),
      if (report != null) ...[
        if (report['complete'] != true) const Text('আংশিক রিপোর্ট — শুধু স্থানীয়ভাবে পাওয়া তথ্য।'),
        Text('মোট ${total.toStringAsFixed(2)} ঘণ্টা • $recordedDays দিন • আনুমানিক OT আয় ৳${(total * widget.profile.rate).toStringAsFixed(2)}'),
        for (var i = 0; i < 12; i++) ListTile(dense: true, title: Text(AppStrings.months[i]), trailing: Text('${rows[i].toStringAsFixed(2)} h')),
        const Text('আয় বর্তমান OT রেট দিয়ে গণনা; পুরোনো মাসের প্রকৃত রেট সংরক্ষিত না থাকলে এটি আনুমানিক।'),
      ],
    ]);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('আরও সুবিধা')), body: ListView(padding: const EdgeInsets.all(12), children: [
      if (_busy) const LinearProgressIndicator(),
      _calendar(),
      _section('মাসিক লক্ষ্য', [Text('${_total.toStringAsFixed(1)} / ${_target.toStringAsFixed(1)} ঘণ্টা'), const SizedBox(height: 8), LinearProgressIndicator(value: (_total / _target).clamp(0.0, 1.0).toDouble()), OutlinedButton(onPressed: _busy ? null : _editTarget, child: const Text('লক্ষ্য পরিবর্তন'))]),
      _section('রিপোর্ট ও এক্সপোর্ট', [
        ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('বাংলা PDF রিপোর্ট'), subtitle: const Text('প্রিন্টযোগ্য বাংলা রিপোর্ট'), onTap: _busy ? null : () => _run(() => ExtraTools.bengaliPdf(_year, _month, _data, widget.profile))),
        ListTile(leading: const Icon(Icons.table_chart), title: const Text('CSV / Excel-এ খোলার উপযোগী ফাইল'), onTap: _busy ? null : () => _run(() async { final ok = await ExtraTools.saveFile('OT_${ExtraTools.monthKey(_year, _month)}.csv', 'text/csv', ExtraTools.csv(_year, _month, _data, widget.profile.rate)); if (ok) _message('CSV সেভ হয়েছে।'); })),
      ]),
      _annualReport(),
      _section('Backup ও Restore', [ListTile(leading: const Icon(Icons.save_alt), title: const Text('ব্যাকআপ সেভ করুন'), onTap: _busy ? null : _backup), ListTile(leading: const Icon(Icons.restore), title: const Text('ব্যাকআপ থেকে অনুপস্থিত OT ফিরিয়ে আনুন'), onTap: _busy ? null : _restore), const Text('ব্যাকআপে ব্যক্তিগত তথ্য থাকে। ফাইল নিরাপদ স্থানে রাখুন।')]),
      _section('অ্যাপের চেহারা', [SwitchListTile(title: const Text('Light theme'), value: AppColors.lightMode.value, onChanged: _busy ? null : (value) async { await AppColors.setLight(value); if (mounted) setState(() {}); })]),
      _section('হোম স্ক্রিন Widget', [const Text('ফোনের Home screen-এ খালি জায়গায় চাপ দিয়ে Widgets থেকে OT Diary বেছে নিন। বর্তমান মাসের OT ঘণ্টা ও দিন দেখায়; অ্যাপে তথ্য লোড বা সেভ হলে আপডেট হয়।'), OutlinedButton(onPressed: _busy ? null : () => _run(() async { final now = DateTime.now(); final data = await DatabaseService.getMonthData(now.year, now.month); final ok = await ExtraTools.publishWidget(now.year, now.month, data); _message(ok ? 'Widget আপডেট করা হয়েছে।' : 'Widget আপডেট হয়নি।'); }), child: const Text('Widget রিফ্রেশ'))]),
    ]));
  }
}
