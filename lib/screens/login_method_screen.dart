import 'package:flutter/material.dart';

class LoginMethodScreen extends StatelessWidget {
  const LoginMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Choose your sign-in method",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
              ),
              child: Text("Login with Email"),
            ),
            SizedBox(height: 15),
            OutlinedButton(
              onPressed: () {},
              child: Text("Continue with Google"),
            ),
            SizedBox(height: 30),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: Text("New to SWOOSH? Sign up"),
            )
          ],
        ),
      ),
    );
  }
}
