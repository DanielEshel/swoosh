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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(SwooshApp());
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
        '/loading': (context) => LoadingScreen(),
        '/welcome': (context) => WelcomeScreen(),
        '/login-method': (context) => LoginMethodScreen(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/home': (context) => AppShell(),
      },
    );
  }
}
