import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' show EmailAuthProvider;
import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;
  const SettingsScreen({super.key, required this.profile, required this.onProfileUpdated});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _reminderHour = 21;
  int _reminderMin  = 0;
  bool _reminderOn  = false;

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

  void _editProfile() {
    final nameCtrl  = TextEditingController(text: widget.profile.name);
    final idCtrl    = TextEditingController(text: widget.profile.idNo);
    final basicCtrl = TextEditingController(text: widget.profile.basic.toString());
    final allowCtrl = TextEditingController(text: widget.profile.allowance.toString());
    final rateCtrl  = TextEditingController(text: widget.profile.rate.toString());

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('প্রোফাইল এডিট',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accent)),
          const SizedBox(height: 20),
          _modalField(nameCtrl, '👤 নাম'),
          const SizedBox(height: 10),
          _modalField(idCtrl, '🪪 আইডি'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _modalField(basicCtrl, '💰 মূল বেতন',
                type: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _modalField(allowCtrl, '🎁 ভাতা',
                type: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _modalField(rateCtrl, '⚡ OT রেট',
                type: TextInputType.number)),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF00B89C)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  final updated = UserProfile(
                    name: nameCtrl.text.trim(),
                    idNo: idCtrl.text.trim(),
                    basic: double.tryParse(basicCtrl.text) ?? 0,
                    allowance: double.tryParse(allowCtrl.text) ?? 0,
                    rate: double.tryParse(rateCtrl.text) ?? 0,
                    email: widget.profile.email,
                  );
                  await DatabaseService.saveProfile(updated);
                  widget.onProfileUpdated(updated);
                  if (mounted) Navigator.pop(context);
                  _showToast('✅ প্রোফাইল আপডেট হয়েছে!');
                },
                child: const Text('সেভ করুন ✓',
                  style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            )),
        ]),
      ),
    );
  }

  Widget _modalField(TextEditingController ctrl, String hint,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: type,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: AppColors.muted, fontSize: 12),
        filled: true, fillColor: AppColors.card2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }

  void _setReminder() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMin),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _reminderHour = time.hour;
      _reminderMin  = time.minute;
      _reminderOn   = true;
    });

    try {
      await NotificationService.cancelReminder();
      await NotificationService.scheduleDailyReminder(
        hour:   time.hour,
        minute: time.minute,
        title:  'OT Diary রিমাইন্ডার',
        body:   'আজকের OT ঘন্টা এন্ট্রি করুন!',
      );
      _showToast('✅ রিমাইন্ডার সেট: ${time.format(context)}');
    } catch (e) {
      _showToast('❌ রিমাইন্ডার সেট করতে সমস্যা: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('⚙️ সেটিংস',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('প্রোফাইল'),
          _settingsCard([
            _tile('✏️', 'প্রোফাইল এডিট', 'নাম, বেতন, রেট পরিবর্তন',
                AppColors.accent, _editProfile),
          ]),
          const SizedBox(height: 20),

          _sectionLabel('নোটিফিকেশন'),
          _settingsCard([
            _tile('🔔', 'দৈনিক রিমাইন্ডার',
                _reminderOn
                    ? 'সেট: ${_reminderHour.toString().padLeft(2, '0')}:${_reminderMin.toString().padLeft(2, '0')}'
                    : 'এখনো সেট করা হয়নি',
                AppColors.gold, _setReminder),
            _tile('❌', 'রিমাইন্ডার বন্ধ করুন', 'নোটিফিকেশন বন্ধ করুন',
                AppColors.red, () async {
              await NotificationService.cancelReminder();
              setState(() => _reminderOn = false);
              _showToast('রিমাইন্ডার বন্ধ হয়েছে');
            }),
          ]),
          const SizedBox(height: 20),

          _sectionLabel('ক্লাউড ব্যাকআপ'),
          _settingsCard([
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Text('☁️', style: TextStyle(fontSize: 20)))),
              title: const Text('Firebase ব্যাকআপ',
                style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
              subtitle: const Text('ডেটা স্বয়ংক্রিয়ভাবে সেভ হচ্ছে',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.green.withOpacity(0.3)),
                ),
                child: const Text('✅ চালু',
                  style: TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          _sectionLabel('অ্যাকাউন্ট'),
          _settingsCard([
            _tile('🚪', 'লগআউট', 'অ্যাকাউন্ট থেকে বের হন',
                AppColors.orange, () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('লগআউট?',
                      style: TextStyle(color: AppColors.text)),
                  content: const Text('আপনি কি নিশ্চিত?',
                      style: TextStyle(color: AppColors.text2)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('না',
                            style: TextStyle(color: AppColors.muted))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('হ্যাঁ',
                            style: TextStyle(color: AppColors.red))),
                  ],
                ),
              );
              if (ok == true) {
                // OT cache মুছবেন না — শুধু session clear
                await DatabaseService.onLogout();
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (_) => false,
                );
              }
            }),
          ]),
          const SizedBox(height: 32),

          const Center(
            child: Text('OT Diary v2.0 · Made with ❤️',
              style: TextStyle(color: AppColors.muted, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4),
    child: Text(label.toUpperCase(),
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.muted)),
  );

  Widget _settingsCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: children.map((w) {
      final idx = children.indexOf(w);
      return Column(children: [
        w,
        if (idx < children.length - 1)
          const Divider(height: 1, color: AppColors.border),
      ]);
    }).toList()),
  );

  Widget _tile(String icon, String title, String sub,
      Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 20)))),
      title: Text(title,
          style: const TextStyle(
              color: AppColors.text, fontWeight: FontWeight.w600)),
      subtitle: Text(sub,
          style: TextStyle(color: AppColors.muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.muted, size: 20),
    );
  }
}
