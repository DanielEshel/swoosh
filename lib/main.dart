import 'package:flutter/material.dart';
import 'screens/loading_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_method_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
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
        '/home': (context) => HomeScreen(),
      },
    );
  }
}
