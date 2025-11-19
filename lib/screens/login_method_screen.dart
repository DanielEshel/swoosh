import 'package:flutter/material.dart';
import 'package:swoosh/widgets/custom_buttons.dart';

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
            const SizedBox(height: 30),

            // Use custom WideButton
            WideButton(
              text: "Login with Email",
              color: scheme.primaryContainer,
              onPressed: () => Navigator.pushNamed(context, '/login'),
            ),

            const SizedBox(height: 15),

            // Use your custom WideIconButton
            WideIconButton(
              text: "Continue with Google",
              icon: Icons.g_mobiledata, // or Icons.login / Icons.account_circle
              color: Theme.of(context).colorScheme.secondaryContainer,
              textColor: Theme.of(context).colorScheme.onSecondaryContainer,
              
              onPressed: () {
                // TODO: Add Google sign-in logic here
              },
            ),

            const SizedBox(height: 30),

            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: const Text("New to SWOOSH? Sign up"),
            ),
          ],
        ),
      ),
    );
  }
}
