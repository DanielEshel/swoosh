import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "SWOOSH",
              style: Theme.of(context).textTheme.displayLarge
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login-method');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text("Get Started", style: TextStyle(color: scheme.onPrimary)),
            )
          ],
        ),
      ),
    );
  }
}
