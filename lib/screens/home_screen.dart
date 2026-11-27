import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../utils/ot_analytics.dart';
import 'chart_screen.dart';
import 'extra_tools_screen.dart';
import '../services/extra_tools.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile profile;

  const HomeScreen({
    super.key,
    required this.profile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late UserProfile _profile;

  int _currentMonth = DateTime.now().month - 1;
  int _currentYear = DateTime.now().year;
  int _navIndex = 0;

  Map<int, double> _otData = <int, double>{};
  final Map<int, TextEditingController> _controllers = <int, TextEditingController>{};
  final Set<int> _dirtyDays = <int>{};

  String? _photoPath;
  bool _saving = false;
  bool _loading = false;
  double _monthlyTarget = 120;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadPhotoPath();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPhotoPath() async {
    final path = await DatabaseService.getLocalProfilePhotoPath();
    if (!mounted) return;
    setState(() => _photoPath = path);
  }

  void _clearControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _dirtyDays.clear();
  }

  Future<void> _openExtraTools() async {
    if (_loading || _saving) return;
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ExtraToolsScreen(
      profile: _profile, year: _currentYear, month: _currentMonth + 1, data: Map.of(_otData),
    )));
    if (mounted) await _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final year = _currentYear;
    final month = _currentMonth + 1;
    final data = await DatabaseService.getMonthData(year, month);
    final target = await ExtraTools.target(year, month);
    if (!mounted || year != _currentYear || month != _currentMonth + 1) return;
    _monthlyTarget = target;
    _clearControllers();
    setState(() {
      _otData = data;
      _loading = false;
    });
    _initControllers();
    await ExtraTools.publishWidget(year, month, data);
  }

  void _initControllers() {
    final days = _daysInMonth;
    for (var day = 1; day <= days; day++) {
      final hours = _otData[day] ?? 0;
      _controllers[day] = TextEditingController(
        text: hours > 0 ? OtAnalytics.formatHours(hours) : '',
      );
    }
  }

  int get _daysInMonth =>
      DateTime(_currentYear, _currentMonth + 2, 0).day;

  double get _totalHours =>
      _otData.values.fold(0.0, (sum, value) => sum + value);

  double get _otEarning => _totalHours * _profile.rate;

  double get _totalSalary =>
      _profile.basic + _profile.allowance + _otEarning;

  int get _otDays => _otData.values.where((hours) => hours > 0).length;

  void _changeMonth(int direction) {
    if (_saving || _loading) return;
    _clearControllers();
    setState(() {
      _currentMonth += direction;
      if (_currentMonth > 11) {
        _currentMonth = 0;
        _currentYear++;
      } else if (_currentMonth < 0) {
        _currentMonth = 11;
        _currentYear--;
      }
      _otData = <int, double>{};
    });
    _loadData();
  }

  Future<void> _saveDay(int day, double hours) async {
    if (!mounted) return;

    setState(() {
      _saving = true;
      if (hours <= 0) {
        _otData.remove(day);
      } else {
        _otData[day] = hours;
      }
    });

    try {
      // DatabaseService writes to the device first and queues cloud sync.
      await DatabaseService.saveOTDay(
        _currentYear,
        _currentMonth + 1,
        day,
        hours,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      await ExtraTools.publishWidget(_currentYear, _currentMonth + 1, _otData);
      if (!mounted) return;
      _showToast(
        DatabaseService.isOnline
            ? 'OT সেভ হয়েছে'
            : 'ডিভাইসে সেভ হয়েছে — অনলাইন হলে Firebase-এ Sync হবে',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showToast('লোকাল সেভে সমস্যা হয়েছে: $error', error: true);
    }
  }

  void _commitDay(int day) {
    if (!_dirtyDays.remove(day)) return;
    final controller = _controllers[day];
    final raw = controller?.text.trim() ?? '';
    final value = raw.isEmpty ? 0.0 : double.tryParse(raw);
    if (value == null || !ExtraTools.validHours(value)) {
      if (controller != null) controller.text = (_otData[day] ?? 0) > 0 ? OtAnalytics.formatHours(_otData[day]!) : '';
      _showToast('০ থেকে ২৪ ঘণ্টার মধ্যে সঠিক সংখ্যা লিখুন।', error: true);
      return;
    }
    _saveDay(day, value);
    FocusScope.of(context).unfocus();
  }

  void _showToast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.red : AppColors.card3,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _generatePDF() async {
    try {
      _showToast('PDF তৈরি হচ্ছে...');
      final file = await PdfService.generateMonthlyReport(
        profile: _profile,
        otData: _otData,
        month: _currentMonth,
        year: _currentYear,
      );
      await PdfService.sharePdf(file);
    } catch (error) {
      _showToast('PDF তৈরি করা যায়নি: $error', error: true);
    }
  }

  Future<void> _resetMonth() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('এই মাসের OT মুছবেন?'),
        content: const Text(
          'শুধু নিশ্চিত করলে এই মাসের OT এন্ট্রি মুছে যাবে। '
          'অন্য মাসের তথ্য পরিবর্তন হবে না।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DatabaseService.resetMonth(_currentYear, _currentMonth + 1);
    _clearControllers();
    if (!mounted) return;
    setState(() => _otData = <int, double>{});
    _initControllers();
    await ExtraTools.publishWidget(_currentYear, _currentMonth + 1, _otData);
    if (mounted) _showToast('এই মাসের OT রিসেট হয়েছে');
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the global palette changes.
    final pages = <Widget>[
      _buildHome(),
      ChartScreen(
        otData: _otData,
        profile: _profile,
        month: _currentMonth,
        year: _currentYear,
      ),
      SettingsScreen(
        profile: _profile,
        onProfileUpdated: (profile) {
          setState(() => _profile = profile);
          _loadPhotoPath();
        },
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _navIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: AppColors.bg2,
        indicatorColor: AppColors.accent.withValues(alpha: 0.13),
        selectedIndex: _navIndex,
        onDestinationSelected: (index) {
          setState(() => _navIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'হোম',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'রিপোর্ট',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'সেটিংস',
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.bg,
          titleSpacing: 18,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'OT Diary',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          actions: [
            if (_saving || _loading)
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'মাসিক PDF',
              onPressed: _generatePDF,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            IconButton(
              tooltip: 'রিফ্রেশ',
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                _profileHero(),
                const SizedBox(height: 16),
                _monthSelector(),
                const SizedBox(height: 16),
                _summaryCards(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading || _saving ? null : _openExtraTools,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('ক্যালেন্ডার • দ্রুত OT • আরও সুবিধা'),
                ),
                const SizedBox(height: 16),
                _distributionCard(),
                const SizedBox(height: 16),
                _progressCard(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'দৈনিক OT এন্ট্রি',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _resetMonth,
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: const Text('মাস রিসেট'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _entryLegend(),
                const SizedBox(height: 10),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
                    ),
                  )
                else
                  ...List.generate(_daysInMonth, (index) => _dayRow(index + 1)),
                const SizedBox(height: 18),
                _syncInfoCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.lightMode.value ? const [Color(0xFFE1EDF7), Color(0xFFF7FBFF)] : const [Color(0xFF15334A), Color(0xFF102338)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _avatar(58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'স্বাগতম, ${_profile.name.isEmpty ? 'ব্যবহারকারী' : _profile.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _profile.idNo.isEmpty
                      ? 'আপনার OT হিসাব এখানে রাখুন'
                      : 'আইডি: ${_profile.idNo}',
                  style: TextStyle(
                    color: AppColors.text2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'OT Rate: ৳${OtAnalytics.formatHours(_profile.rate)}/ঘণ্টা',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_user_outlined,
            color: AppColors.accent,
            size: 21,
          ),
        ],
      ),
    );
  }

  Widget _avatar(double size) {
    final path = _photoPath;
    final hasLocalPhoto =
        path != null && File(path).existsSync();

    Widget image;
    if (hasLocalPhoto) {
      image = Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if ((_profile.photoUrl ?? '').isNotEmpty) {
      image = Image.network(
        _profile.photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(size),
      );
    } else {
      image = _avatarFallback(size);
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card3,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: image,
    );
  }

  Widget _avatarFallback(double size) {
    return Container(
      width: size,
      height: size,
      color: AppColors.card3,
      alignment: Alignment.center,
      child: Text(
        _profile.name.isEmpty ? '?' : _profile.name.substring(0, 1),
        style: TextStyle(
          color: AppColors.accent,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _monthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.text2,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  AppStrings.months[_currentMonth],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  '$_currentYear',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.text2,
          ),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'মোট OT',
                value: '${OtAnalytics.formatHours(_totalHours)} ঘণ্টা',
                icon: Icons.schedule_rounded,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                title: 'OT করেছেন',
                value: '$_otDays দিন',
                icon: Icons.event_available_rounded,
                color: AppColors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.lightMode.value ? const [Color(0xFFDDF1E8), Color(0xFFF0F8F7)] : const [Color(0xFF193D42), Color(0xFF153044)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'এই মাসের আনুমানিক OT আয়',
                    style: TextStyle(
                      color: AppColors.text2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '৳${_otEarning.toStringAsFixed(0)}',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _salaryMini('মূল বেতন', _profile.basic),
                  _verticalDivider(),
                  _salaryMini('ভাতা', _profile.allowance),
                  _verticalDivider(),
                  _salaryMini('মোট বেতন', _totalSalary),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _salaryMini(String label, double value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '৳${value.toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.border,
    );
  }

  Widget _distributionCard() {
    final groups = OtAnalytics.groupByHours(_otData);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.stacked_bar_chart_rounded,
                color: AppColors.purple,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'কত ঘণ্টা OT কত দিন করেছেন',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'একই পরিমাণ OT যেদিন করেছেন, সেগুলো একসঙ্গে দেখানো হচ্ছে।',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          if (groups.isEmpty)
            Text(
              'এই মাসে এখনো OT এন্ট্রি নেই।',
              style: TextStyle(
                color: AppColors.text2,
                fontSize: 12,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groups.map((group) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${OtAnalytics.formatHours(group.hours)} ঘণ্টা',
                        style: TextStyle(
                          color: AppColors.purple,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${group.days} দিন',
                        style: TextStyle(
                          color: AppColors.text2,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _progressCard() {
    final targetHours = _monthlyTarget;
    final progress = (_totalHours / targetHours).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'মাসিক OT অগ্রগতি',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${OtAnalytics.formatHours(_totalHours)} / ${OtAnalytics.formatHours(targetHours)} ঘণ্টা',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppColors.card2,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryLegend() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'তারিখ ও বার',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        Text(
          'OT ঘণ্টা',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        SizedBox(width: 43),
        Text(
          'মোট',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _dayRow(int day) {
    final weekday = DateTime(
      _currentYear,
      _currentMonth + 1,
      day,
    ).weekday % 7;

    final hours = _otData[day] ?? 0;
    final hasOt = hours > 0;
    final now = DateTime.now();
    final isToday = day == now.day &&
        _currentMonth == now.month - 1 &&
        _currentYear == now.year;

    final controller = _controllers.putIfAbsent(
      day,
      () => TextEditingController(
        text: hasOt ? OtAnalytics.formatHours(hours) : '',
      ),
    );

    final dayColor = weekday == 5
        ? (AppColors.lightMode.value ? const Color(0xFF285B96) : const Color(0xFF7CB7FF))
        : weekday == 6
            ? AppColors.orange
            : AppColors.text2;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: hasOt ? (AppColors.lightMode.value ? const Color(0xFFE0F2EB) : const Color(0xFF102C35)) : AppColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: hasOt
              ? AppColors.accent.withValues(alpha: 0.32)
              : isToday
                  ? AppColors.gold.withValues(alpha: 0.38)
                  : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 31,
            child: Text(
              day.toString().padLeft(2, '0'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: hasOt ? AppColors.accent : AppColors.text2,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  AppStrings.days[weekday],
                  style: TextStyle(
                    color: dayColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.circle,
                    color: AppColors.gold,
                    size: 6,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 82,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}$'),
                ),
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasOt ? AppColors.accent : AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: '০',
                suffixText: 'h',
                suffixStyle: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
                filled: true,
                fillColor: AppColors.card2,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                _dirtyDays.add(day);
                final parsed = double.tryParse(value.trim()) ?? 0;
                setState(() {
                  if (parsed <= 0) {
                    _otData.remove(day);
                  } else {
                    _otData[day] = parsed;
                  }
                });
              },
              onEditingComplete: () => _commitDay(day),
              // Emptying a previously saved value also queues a cloud delete.
              onTapOutside: (_) => _commitDay(day),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 35,
            child: Text(
              _cumulative(day) > 0
                  ? OtAnalytics.formatHours(_cumulative(day))
                  : '—',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: AppColors.text2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _cumulative(int day) {
    var total = 0.0;
    for (var index = 1; index <= day; index++) {
      total += _otData[index] ?? 0;
    }
    return total;
  }

  Widget _syncInfoCard() {
    return FutureBuilder<bool>(
      future: DatabaseService.hasPendingChanges(),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? false;
        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.card2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                pending
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined,
                color: pending ? AppColors.gold : AppColors.accent,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  pending
                      ? 'কিছু তথ্য অনলাইনে Sync হওয়ার অপেক্ষায় আছে।'
                      : 'আপনার OT তথ্য ডিভাইসে সংরক্ষিত থাকে এবং অনলাইনে Sync হয়।',
                  style: TextStyle(
                    color: AppColors.text2,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
