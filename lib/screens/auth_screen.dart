import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tab;
  bool _loading = false;
  String _err = '';

  // Login
  final _loginEmail = TextEditingController();
  final _loginPass  = TextEditingController();
  bool _loginPassVisible = false;

  // Register
  final _regName  = TextEditingController();
  final _regId    = TextEditingController();
  final _regBasic = TextEditingController();
  final _regAllow = TextEditingController();
  final _regRate  = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPass  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() => _err = ''));
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose(); _loginPass.dispose();
    _regName.dispose(); _regId.dispose(); _regBasic.dispose();
    _regAllow.dispose(); _regRate.dispose(); _regEmail.dispose(); _regPass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loginEmail.text.isEmpty || _loginPass.text.isEmpty) {
      setState(() => _err = 'ইমেইল ও পাসওয়ার্ড দিন'); return;
    }
    setState(() { _loading = true; _err = ''; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmail.text.trim(), password: _loginPass.text);
      final profile = await DatabaseService.getProfile();
      if (!mounted) return;
      if (profile != null) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)));
      } else {
        setState(() => _err = 'প্রোফাইল পাওয়া যায়নি');
      }
    } on FirebaseAuthException {
      setState(() => _err = 'ইমেইল বা পাসওয়ার্ড ভুল');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_regName.text.isEmpty || _regEmail.text.isEmpty || _regPass.text.isEmpty) {
      setState(() => _err = 'সব তথ্য পূরণ করুন'); return;
    }
    if (_regPass.text.length < 6) {
      setState(() => _err = 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষর'); return;
    }
    setState(() { _loading = true; _err = ''; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _regEmail.text.trim(), password: _regPass.text);
      final profile = UserProfile(
        name: _regName.text.trim(),
        idNo: _regId.text.trim(),
        basic: double.tryParse(_regBasic.text) ?? 0,
        allowance: double.tryParse(_regAllow.text) ?? 0,
        rate: double.tryParse(_regRate.text) ?? 0,
        email: _regEmail.text.trim(),
      );
      await DatabaseService.saveProfile(profile);
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)));
    } on FirebaseAuthException catch (e) {
      setState(() => _err = e.code == 'email-already-in-use'
          ? 'এই ইমেইল আগেই ব্যবহৃত' : e.message ?? 'সমস্যা হয়েছে');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 32),
            // Logo
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFF0097A7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(
                  color: AppColors.accent.withOpacity(0.35),
                  blurRadius: 40, spreadRadius: 4,
                )],
              ),
              child: const Center(child: Text('⚡', style: TextStyle(fontSize: 44))),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [AppColors.accent, AppColors.gold],
              ).createShader(b),
              child: const Text('OT DIARY',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                    letterSpacing: 6, color: Colors.white)),
            ),
            Text('আপনার ওভারটাইম ট্র্যাকার',
              style: TextStyle(fontSize: 12, color: AppColors.muted, letterSpacing: 1)),
            const SizedBox(height: 32),

            // Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                // Tab bar
                Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF00B89C)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.black,
                    unselectedLabelColor: AppColors.muted,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    dividerColor: Colors.transparent,
                    tabs: const [Tab(text: 'লগইন'), Tab(text: 'নতুন অ্যাকাউন্ট')],
                  ),
                ),

                SizedBox(
                  height: _tab.index == 0 ? 280 : 480,
                  child: TabBarView(controller: _tab, children: [
                    // Login
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(children: [
                        _field(_loginEmail, '📧 ইমেইল', TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _passField(_loginPass, '🔒 পাসওয়ার্ড', _loginPassVisible,
                            () => setState(() => _loginPassVisible = !_loginPassVisible)),
                        const SizedBox(height: 16),
                        _submitBtn('লগইন করুন →', _login),
                      ]),
                    ),
                    // Register
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(children: [
                        _field(_regName, '👤 আপনার নাম', TextInputType.name),
                        const SizedBox(height: 10),
                        _field(_regId, '🪪 আইডি নম্বর', TextInputType.text),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _field(_regBasic, '💰 মূল বেতন', TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(child: _field(_regAllow, '🎁 ভাতা', TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(child: _field(_regRate, '⚡ OT রেট', TextInputType.number)),
                        ]),
                        const SizedBox(height: 10),
                        _field(_regEmail, '📧 ইমেইল', TextInputType.emailAddress),
                        const SizedBox(height: 10),
                        _field(_regPass, '🔒 পাসওয়ার্ড (৬+ অক্ষর)', TextInputType.visiblePassword,
                            obscure: true),
                        const SizedBox(height: 16),
                        _submitBtn('অ্যাকাউন্ট তৈরি করুন →', _register),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),

            if (_err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.red.withOpacity(0.3)),
                  ),
                  child: Text(_err,
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                    textAlign: TextAlign.center),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType type,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
        filled: true, fillColor: AppColors.card2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _passField(TextEditingController ctrl, String hint,
      bool visible, VoidCallback toggle) {
    return TextField(
      controller: ctrl, obscureText: !visible,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
        filled: true, fillColor: AppColors.card2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
              color: AppColors.muted, size: 20),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }

  Widget _submitBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF00B89C)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: AppColors.accent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0,6))],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(label,
                  style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
