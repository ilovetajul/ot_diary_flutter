import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_theme.dart';
import '../services/database_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0)));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await DatabaseService.getProfile();
      if (!mounted) return;
      if (profile != null) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AuthScreen()));
      }
    } else {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, Color(0xFF0097A7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 40, spreadRadius: 5,
                  )],
                ),
                child: const Center(
                  child: Text('⚡', style: TextStyle(fontSize: 52)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fade,
              child: Column(children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.accent, AppColors.gold],
                  ).createShader(bounds),
                  child: const Text('OT DIARY',
                    style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900,
                      letterSpacing: 8, color: Colors.white,
                    )),
                ),
                const SizedBox(height: 8),
                Text('ওভারটাইম ট্র্যাকার',
                  style: TextStyle(fontSize: 14, color: AppColors.muted, letterSpacing: 2)),
                const SizedBox(height: 40),
                SizedBox(
                  width: 40,
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
