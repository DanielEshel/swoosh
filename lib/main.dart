// firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:flutter/material.dart';
import 'screens/loading_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_method_screen.dart';
import 'screens/login_screen.dart';
import 'shell/app_shell.dart';
import 'theme.dart';
import 'screens/signup_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase initialization works on all platforms
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔐 Firebase App Check must NOT run on Web or Desktop.
  // Web: uses reCAPTCHA instead (auto handled by Firebase)
  // Desktop: not supported.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }

  runApp(const SwooshApp());
}

class SwooshApp extends StatelessWidget {
  const SwooshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swoosh',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/loading',
      routes: {
        '/loading': (context) => const LoadingScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login-method': (context) => const LoginMethodScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const AppShell(),
      },
    );
  }
}
