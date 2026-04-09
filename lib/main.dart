import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.init();
  await NotificationService.rescheduleOnBoot();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const OTDiaryApp());
}

class OTDiaryApp extends StatelessWidget {
  const OTDiaryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OT Diary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060A14),
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xFF00E5C0),
          secondary: Color(0xFFFF6B35),
          surface:   Color(0xFF0C1422),
        ),
        textTheme: GoogleFonts.hindSiliguriTextTheme(
            ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF060A14),
          elevation:       0,
          centerTitle:     true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
