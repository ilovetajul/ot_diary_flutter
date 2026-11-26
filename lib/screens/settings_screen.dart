import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;

  const SettingsScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _reminderHour = 21;
  int _reminderMinute = 0;
  bool _reminderOn = false;
  bool _loadingReminder = true;
  bool _photoBusy = false;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _loadReminderStatus();
    _loadPhotoPath();
  }

  Future<void> _loadReminderStatus() async {
    final status = await NotificationService.getReminderStatus();
    if (!mounted) return;
    setState(() {
      _reminderOn = status['on'] == true;
      _reminderHour = status['hour'] as int? ?? 21;
      _reminderMinute = status['minute'] as int? ?? 0;
      _loadingReminder = false;
    });
  }

  Future<void> _loadPhotoPath() async {
    final path = await DatabaseService.getLocalProfilePhotoPath();
    if (!mounted) return;
    setState(() => _photoPath = path);
  }

  void _showToast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.red : AppColors.card3,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _avatar(double size) {
    final path = _photoPath;
    final hasLocalPhoto = path != null && File(path).existsSync();

    Widget image;
    if (hasLocalPhoto) {
      image = Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if ((widget.profile.photoUrl ?? '').isNotEmpty) {
      image = Image.network(
        widget.profile.photoUrl!,
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
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: image,
    );
  }

  Widget _avatarFallback(double size) {
    return Container(
      color: AppColors.card3,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: AppColors.accent,
        size: size * 0.55,
      ),
    );
  }

  Future<void> _choosePhoto() async {
    if (_photoBusy) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (picked == null) return;

      setState(() => _photoBusy = true);
      final localPath = await DatabaseService.saveProfilePhoto(
        File(picked.path),
      );

      if (!mounted) return;
      setState(() {
        _photoPath = localPath;
        _photoBusy = false;
      });

      // The local avatar updates immediately. Firebase Storage upload is
      // queued and retried automatically when the device reconnects.
      widget.onProfileUpdated(widget.profile);
      final pending = await DatabaseService.hasPendingChanges();
      _showToast(
        pending
            ? 'ছবি ডিভাইসে সেভ হয়েছে; ইন্টারনেট এলে Firebase-এ Sync হবে।'
            : 'প্রোফাইল ছবি আপডেট হয়েছে।',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _photoBusy = false);
      _showToast('ছবি সেভ করা যায়নি: $error', error: true);
    }
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: widget.profile.name);
    final idController = TextEditingController(text: widget.profile.idNo);
    final basicController =
        TextEditingController(text: widget.profile.basic.toString());
    final allowanceController =
        TextEditingController(text: widget.profile.allowance.toString());
    final rateController =
        TextEditingController(text: widget.profile.rate.toString());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'প্রোফাইল তথ্য পরিবর্তন',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(nameController, 'আপনার নাম'),
                    const SizedBox(height: 10),
                    _field(idController, 'আইডি নম্বর'),
                    const SizedBox(height: 10),
                    _field(
                      basicController,
                      'মূল বেতন',
                      numeric: true,
                    ),
                    const SizedBox(height: 10),
                    _field(
                      allowanceController,
                      'ভাতা',
                      numeric: true,
                    ),
                    const SizedBox(height: 10),
                    _field(
                      rateController,
                      'প্রতি ঘণ্টার OT Rate',
                      numeric: true,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final basic =
                                    double.tryParse(basicController.text);
                                final allowance =
                                    double.tryParse(allowanceController.text);
                                final rate =
                                    double.tryParse(rateController.text);

                                if (nameController.text.trim().isEmpty ||
                                    basic == null ||
                                    allowance == null ||
                                    rate == null ||
                                    basic < 0 ||
                                    allowance < 0 ||
                                    rate < 0) {
                                  _showToast(
                                    'নাম ও বেতনের সঠিক তথ্য দিন।',
                                    error: true,
                                  );
                                  return;
                                }

                                setSheetState(() => saving = true);
                                final updated = widget.profile.copyWith(
                                  name: nameController.text.trim(),
                                  idNo: idController.text.trim(),
                                  basic: basic,
                                  allowance: allowance,
                                  rate: rate,
                                );

                                try {
                                  await DatabaseService.saveProfile(updated);
                                  if (!mounted) return;
                                  widget.onProfileUpdated(updated);
                                  Navigator.pop(sheetContext);
                                  _showToast(
                                    'প্রোফাইল ডিভাইসে সেভ হয়েছে; অনলাইনে Sync হবে।',
                                  );
                                } catch (error) {
                                  setSheetState(() => saving = false);
                                  _showToast(
                                    'প্রোফাইল সেভ হয়নি: $error',
                                    error: true,
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          saving ? 'সেভ হচ্ছে...' : 'পরিবর্তন সেভ করুন',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    idController.dispose();
    basicController.dispose();
    allowanceController.dispose();
    rateController.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.muted),
      ),
    );
  }

  Future<void> _chooseReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _reminderHour,
        minute: _reminderMinute,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.accent,
                surface: AppColors.card,
              ),
        ),
        child: child!,
      ),
    );

    if (selected == null) return;

    final result = await NotificationService.scheduleDailyReminder(
      hour: selected.hour,
      minute: selected.minute,
    );

    if (!mounted) return;
    if (result == 'ok') {
      setState(() {
        _reminderHour = selected.hour;
        _reminderMinute = selected.minute;
        _reminderOn = true;
      });
      _showToast(
        'প্রতিদিন ${selected.format(context)}-এ OT রিমাইন্ডার আসবে।',
      );
    } else {
      _showToast('রিমাইন্ডার সেট করা যায়নি: $result', error: true);
    }
  }

  Future<void> _toggleReminder(bool enabled) async {
    if (enabled) {
      await _chooseReminderTime();
    } else {
      await NotificationService.cancelReminder();
      if (!mounted) return;
      setState(() => _reminderOn = false);
      _showToast('দৈনিক OT রিমাইন্ডার বন্ধ করা হয়েছে।');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('লগআউট করবেন?'),
        content: const Text(
          'এই ডিভাইসের স্থানীয় OT Cache ও Sync Queue মুছে ফেলা হবে না।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('না'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('লগআউট'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DatabaseService.onLogout();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 3, bottom: 9),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminderText = _loadingReminder
        ? 'সময়সূচি লোড হচ্ছে...'
        : _reminderOn
            ? 'প্রতিদিন ${_reminderHour.toString().padLeft(2, '0')}:'
                '${_reminderMinute.toString().padLeft(2, '0')}-এ'
            : 'এখনো সময় নির্ধারণ করা হয়নি';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'সেটিংস',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _settingsCard([
            Padding(
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  Stack(
                    children: [
                      _avatar(70),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 25,
                          height: 25,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: _photoBusy
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.bg,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  color: AppColors.bg,
                                  size: 14,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.profile.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.profile.email,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 9),
                        TextButton.icon(
                          onPressed: _photoBusy ? null : _choosePhoto,
                          icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                          label: const Text('ছবি আপলোড'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              onTap: _editProfile,
              leading: const Icon(
                Icons.edit_outlined,
                color: AppColors.accent,
              ),
              title: const Text('প্রোফাইল সম্পাদনা'),
              subtitle: const Text(
                'নাম, আইডি, বেতন ও OT Rate',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('দৈনিক OT নোটিফিকেশন'),
          _settingsCard([
            SwitchListTile.adaptive(
              value: _reminderOn,
              onChanged: _loadingReminder ? null : _toggleReminder,
              activeColor: AppColors.accent,
              title: const Text(
                'প্রতিদিনের OT রিমাইন্ডার',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                reminderText,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
              secondary: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.gold,
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              onTap: _chooseReminderTime,
              leading: const Icon(
                Icons.schedule_rounded,
                color: AppColors.accent,
              ),
              title: const Text('রিমাইন্ডারের সময় পরিবর্তন'),
              subtitle: const Text(
                '“আজকের OT কত ঘণ্টা হয়েছে? লিখে রাখুন।”',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('ডেটা ও সিঙ্ক'),
          _settingsCard([
            ListTile(
              leading: const Icon(
                Icons.cloud_sync_outlined,
                color: AppColors.accent,
              ),
              title: const Text('Offline-first সেভিং'),
              subtitle: const Text(
                'প্রথমে ফোনে সেভ হবে, ইন্টারনেট এলে Firebase-এ Sync হবে।',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
            FutureBuilder<bool>(
              future: DatabaseService.hasPendingChanges(),
              builder: (context, snapshot) {
                final pending = snapshot.data ?? false;
                return ListTile(
                  leading: Icon(
                    pending
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_done_outlined,
                    color: pending ? AppColors.gold : AppColors.green,
                  ),
                  title: const Text('Sync অবস্থা'),
                  subtitle: Text(
                    pending
                        ? 'কিছু তথ্য Sync হওয়ার অপেক্ষায় আছে'
                        : 'কোনো Pending Sync নেই',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'এখন Sync চেষ্টা করুন',
                    onPressed: () async {
                      await DatabaseService.syncPendingWrites();
                      if (!mounted) return;
                      setState(() {});
                    },
                    icon: const Icon(Icons.sync_rounded),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('অ্যাকাউন্ট'),
          _settingsCard([
            ListTile(
              onTap: _logout,
              leading: const Icon(
                Icons.logout_rounded,
                color: AppColors.red,
              ),
              title: const Text('লগআউট'),
              subtitle: const Text(
                'স্থানীয় Cache মুছে না ফেলে অ্যাকাউন্ট থেকে বের হন',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ]),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              'OT Diary · Version 2.1',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
