import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ui/material_ui.dart';

class AppColors {
  static final lightMode = ValueNotifier<bool>(false);
  static Brightness get brightness => lightMode.value ? Brightness.light : Brightness.dark;
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    lightMode.value = prefs.getBool('ot_light_theme') ?? false;
  }
  static Future<void> setLight(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ot_light_theme', value);
    lightMode.value = value;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: value ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness: value ? Brightness.dark : Brightness.light,
    ));
  }

  static Color get bg => lightMode.value ? const Color(0xFFF2F6FA) : const Color(0xFF07111F);
  static Color get bg2 => lightMode.value ? const Color(0xFFFFFFFF) : const Color(0xFF0A1728);
  static Color get card => lightMode.value ? const Color(0xFFFFFFFF) : const Color(0xFF101F32);
  static Color get card2 => lightMode.value ? const Color(0xFFEAF0F5) : const Color(0xFF172A40);
  static Color get card3 => lightMode.value ? const Color(0xFFDDE7F0) : const Color(0xFF1D344D);
  static Color get accent => lightMode.value ? const Color(0xFF087D70) : const Color(0xFF55E6C1);
  static Color get orange => lightMode.value ? const Color(0xFFA14B19) : const Color(0xFFFF9B62);
  static Color get gold => lightMode.value ? const Color(0xFF896000) : const Color(0xFFFFD166);
  static Color get purple => lightMode.value ? const Color(0xFF6650B3) : const Color(0xFF9B8CFF);
  static Color get red => lightMode.value ? const Color(0xFFB32636) : const Color(0xFFFF6B75);
  static Color get green => lightMode.value ? const Color(0xFF087A55) : const Color(0xFF42D6A4);
  static Color get border => lightMode.value ? const Color(0xFFCAD7E1) : const Color(0xFF263C55);
  static Color get text => lightMode.value ? const Color(0xFF142638) : const Color(0xFFF3F7FC);
  static Color get text2 => lightMode.value ? const Color(0xFF354B61) : const Color(0xFFB0C0D1);
  static Color get muted => lightMode.value ? const Color(0xFF526B80) : const Color(0xFF7890A8);
}

class AppStrings {
  static const months = [
    'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
  ];

  static const days = [
    'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি'
  ];
}
