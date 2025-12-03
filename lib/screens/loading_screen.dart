import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  Future<void> _checkAuth(BuildContext context) async {
    // Tiny pause so the spinner shows
    await Future.delayed(const Duration(seconds: 1));

    final user = FirebaseAuth.instance.currentUser;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (user != null) {
        // already logged in → go home
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // not logged in → welcome / login flow
        Navigator.of(context).pushReplacementNamed('/welcome');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _checkAuth(context),
      builder: (context, snapshot) {
        // While waiting
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("SWOOSH",
                      style: Theme.of(context).textTheme.headlineLarge),
                  SizedBox(height: 30),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          );
        }

        // We never actually render this because we navigate away,
        // but FutureBuilder requires a return value.
        return const SizedBox.shrink();
      },
    );
  }
}
