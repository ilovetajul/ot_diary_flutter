import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import 'settings_screen.dart';
import 'chart_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile profile;
  const HomeScreen({super.key, required this.profile});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late UserProfile _profile;
  int _currentMonth = DateTime.now().month - 1;
  int _currentYear  = DateTime.now().year;
  Map<int, double> _otData = {};
  bool _saving  = false;
  bool _loading = false;
  int  _navIdx  = 0;

  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  void _clearControllers() {
    for (final c in _controllers.values) c.dispose();
    _controllers.clear();
  }

  // ─── Refresh বাটনে OT না কমার fix ───
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    // data আসার আগে _otData clear করবেন না

    final data = await DatabaseService.getMonthData(
        _currentYear, _currentMonth + 1);

    if (!mounted) return;
    _clearControllers();
    setState(() {
      _otData  = data;
      _loading = false;
    });
    _initControllers();
  }

  void _initControllers() {
    final days = DateTime(_currentYear, _currentMonth + 2, 0).day;
    for (int d = 1; d <= days; d++) {
      final hours = _otData[d] ?? 0.0;
      _controllers[d] = TextEditingController(
        text: hours > 0 ? '$hours' : '',
      );
    }
    if (mounted) setState(() {});
  }

  void _changeMonth(int dir) {
    _clearControllers();
    setState(() {
      _currentMonth += dir;
      if (_currentMonth > 11) { _currentMonth = 0; _currentYear++; }
      if (_currentMonth < 0)  { _currentMonth = 11; _currentYear--; }
      _otData = {};
    });
    _loadData();
  }

  int    get _daysInMonth => DateTime(_currentYear, _currentMonth + 2, 0).day;
  double get _totalHours  => _otData.values.fold(0, (a, b) => a + b);
  double get _otEarning   => _totalHours * _profile.rate;
  double get _totalSalary => _profile.basic + _profile.allowance + _otEarning;

  Future<void> _saveDay(int day, double hours) async {
    setState(() {
      _saving = true;
      if (hours <= 0) _otData.remove(day); else _otData[day] = hours;
    });
    await DatabaseService.saveOTDay(
        _currentYear, _currentMonth + 1, day, hours);
    if (mounted) setState(() => _saving = false);
    _showToast('☁️ সেভ হয়েছে!');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.card2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _generatePDF() async {
    try {
      _showToast('📄 PDF তৈরি হচ্ছে...');
      final file = await PdfService.generateMonthlyReport(
        profile: _profile, otData: _otData,
        month: _currentMonth, year: _currentYear,
      );
      await PdfService.sharePdf(file);
    } catch (e) {
      _showToast('❌ PDF তৈরিতে সমস্যা: $e');
    }
  }

  Future<void> _resetMonth() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('রিসেট করবেন?', style: TextStyle(color: AppColors.text)),
        content: const Text('এই মাসের সব OT ডেটা মুছে যাবে।',
            style: TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('না', style: TextStyle(color: AppColors.muted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('হ্যাঁ, মুছুন', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.resetMonth(_currentYear, _currentMonth + 1);
      _clearControllers();
      setState(() => _otData = {});
      _initControllers();
      _showToast('🗑 রিসেট হয়েছে');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_buildHome(), _buildChart(), _buildSettings()];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: pages[_navIdx],
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: _navIdx,
        onTap: (i) => setState(() => _navIdx = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.muted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Text('🏠', style: TextStyle(fontSize: 22)), label: 'হোম'),
          BottomNavigationBarItem(icon: Text('📊', style: TextStyle(fontSize: 22)), label: 'চার্ট'),
          BottomNavigationBarItem(icon: Text('⚙️', style: TextStyle(fontSize: 22)), label: 'সেটিংস'),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.bg.withOpacity(0.95),
          title: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF0097A7)]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Center(child: Text('⚡', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.accent, AppColors.gold]).createShader(b),
              child: const Text('OT DIARY',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                      letterSpacing: 3, color: Colors.white)),
            ),
          ]),
          actions: [
            if (_saving || _loading)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold.withOpacity(0.8))),
              ),
            IconButton(
              icon: const Text('📄', style: TextStyle(fontSize: 20)),
              onPressed: _generatePDF,
            ),
            IconButton(
              icon: const Text('🔄', style: TextStyle(fontSize: 18)),
              onPressed: _loadData,
            ),
          ],
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _profileHero(),
              const SizedBox(height: 14),
              _monthSelector(),
              const SizedBox(height: 14),
              _summaryCards(),
              const SizedBox(height: 14),
              _progressCard(),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('📅 দৈনিক OT এন্ট্রি',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.text2, letterSpacing: 0.5)),
                TextButton.icon(
                  onPressed: _resetMonth,
                  icon: const Text('🗑', style: TextStyle(fontSize: 13)),
                  label: const Text('রিসেট',
                      style: TextStyle(color: AppColors.red, fontSize: 12)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.red.withOpacity(0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              if (_loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ))
              else
                ...List.generate(_daysInMonth, (i) => _dayRow(i + 1)),

              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _profileHero() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.card, AppColors.card2],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(children: [
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.accent, AppColors.gold]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ))),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(width: 58, height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF0097A7)]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 15)],
              ),
              child: Center(child: Text(
                _profile.name.isNotEmpty ? _profile.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black),
              ))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_profile.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                _tag('ID: ${_profile.idNo.isNotEmpty ? _profile.idNo : "—"}'),
                _tag('${_profile.rate}/ঘন্টা', accent: true),
              ]),
            ])),
          ]),
        ),
      ]),
    );
  }

  Widget _tag(String text, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.card3, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: TextStyle(
          fontSize: 11,
          color: accent ? AppColors.accent : AppColors.text2,
          fontWeight: accent ? FontWeight.w700 : FontWeight.normal)),
    );
  }

  Widget _monthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _navBtn('‹', () => _changeMonth(-1)),
        Column(children: [
          Text(AppStrings.months[_currentMonth],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: AppColors.accent, letterSpacing: 1)),
          Text('$_currentYear সাল',
              style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
        _navBtn('›', () => _changeMonth(1)),
      ]),
    );
  }

  Widget _navBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.card2, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: Text(label,
            style: const TextStyle(fontSize: 22, color: AppColors.text)))),
    );
  }

  Widget _summaryCards() {
    return Column(children: [
      Row(children: [
        Expanded(child: _sCard('মোট OT', '${_totalHours}h', AppColors.accent)),
        const SizedBox(width: 12),
        Expanded(child: _sCard('OT আয়', '৳${_otEarning.toStringAsFixed(0)}', AppColors.orange)),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B1E35), Color(0xFF0D2237)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('💰 মোট বেতন', style: TextStyle(fontSize: 10, color: AppColors.muted,
              fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(_profile.rate > 0 ? '৳${_totalSalary.toStringAsFixed(0)}' : '৳ —',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
                  color: AppColors.gold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              _bItem('মূল বেতন', _profile.basic > 0 ? '৳${_profile.basic.toStringAsFixed(0)}' : '—'),
              _divider(),
              _bItem('ভাতা', _profile.allowance > 0 ? '৳${_profile.allowance.toStringAsFixed(0)}' : '—'),
              _divider(),
              _bItem('OT', _otEarning > 0 ? '৳${_otEarning.toStringAsFixed(0)}' : '—', accent: true),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _sCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.muted,
            fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        Text('এই মাসে', style: TextStyle(fontSize: 10, color: AppColors.muted)),
      ]),
    );
  }

  Widget _bItem(String label, String value, {bool accent = false}) {
    return Expanded(child: Column(children: [
      Text(label, style: TextStyle(fontSize: 9, color: AppColors.muted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: accent ? AppColors.accent : AppColors.text)),
    ]));
  }

  Widget _divider() => Container(width: 1, height: 28, color: AppColors.border);

  Widget _progressCard() {
    final pct = (_totalHours / 120).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('মাসিক OT লক্ষ্য (১২০ ঘন্টা)',
              style: TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600)),
          Text('${_totalHours}h / ১২০',
              style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: pct),
            builder: (_, val, __) => LinearProgressIndicator(
              value: val, minHeight: 10,
              backgroundColor: AppColors.card2,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _dayRow(int day) {
    final dow    = DateTime(_currentYear, _currentMonth + 1, day).weekday % 7;
    final isFri  = dow == 5;
    final isSat  = dow == 6;
    final hours  = _otData[day] ?? 0.0;
    final hasOT  = hours > 0;
    final today  = DateTime.now();
    final isToday = day == today.day &&
        _currentMonth == today.month - 1 &&
        _currentYear  == today.year;

    if (!_controllers.containsKey(day)) {
      _controllers[day] = TextEditingController(text: hours > 0 ? '$hours' : '');
    }
    final ctrl = _controllers[day]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: hasOT ? const Color(0xFF0C1F2E) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasOT ? AppColors.accent.withOpacity(0.3)
              : isToday ? AppColors.gold.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(width: 36,
            child: Text(day.toString().padLeft(2, '0'),
                style: TextStyle(fontFamily: 'monospace', fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hasOT ? AppColors.accent : AppColors.text2))),
          Expanded(child: Text(
            AppStrings.days[dow] + (isToday ? ' ●' : ''),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: isFri ? Colors.blue[300] : isSat ? AppColors.orange : AppColors.muted),
          )),
          SizedBox(
            width: 76,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: hasOT ? AppColors.accent : AppColors.text),
              decoration: InputDecoration(
                hintText: '০',
                hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                filled: true, fillColor: AppColors.card2,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: hasOT ? AppColors.accent.withOpacity(0.4) : AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: hasOT ? AppColors.accent.withOpacity(0.4) : AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
              ),
              // ─── onChanged: শুধু একবার ───
              onChanged: (v) {
                final val = double.tryParse(v) ?? 0;
                setState(() {
                  if (val <= 0) _otData.remove(day);
                  else _otData[day] = val;
                });
              },
              // ─── keyboard এর ✓ চাপলে save ───
              onEditingComplete: () {
                final val = _otData[day] ?? 0;
                _saveDay(day, val);
                FocusScope.of(context).unfocus();
              },
              // ─── অন্য জায়গায় ট্যাপ করলেও save ───
              onTapOutside: (_) {
                final val = _otData[day] ?? 0;
                if (val > 0) _saveDay(day, val);
                FocusScope.of(context).unfocus();
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 34,
            child: Text(
              _cumulative(day) > 0 ? '${_cumulative(day)}' : '—',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700,
                  color: _cumulative(day) == 0 ? AppColors.muted
                      : _cumulative(day) < 20 ? AppColors.text2
                      : _cumulative(day) < 50 ? AppColors.gold
                      : AppColors.orange),
              textAlign: TextAlign.right,
            )),
        ]),
      ),
    );
  }

  double _cumulative(int day) {
    double sum = 0;
    for (int d = 1; d <= day; d++) sum += _otData[d] ?? 0;
    return sum;
  }

  Widget _buildChart() => ChartScreen(
      otData: _otData, profile: _profile,
      month: _currentMonth, year: _currentYear);

  Widget _buildSettings() => SettingsScreen(
      profile: _profile,
      onProfileUpdated: (p) => setState(() => _profile = p));
}
