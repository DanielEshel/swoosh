import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:swoosh/widgets/custom_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swoosh/services/user_firestore.dart';

class LoginMethodScreen extends StatelessWidget {
  const LoginMethodScreen({super.key});

  Future<void> _googleLogin(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final cred =
          await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());

      final user = cred.user;

      if (user != null) {
        // make sure user firestore doc exists
        ensureUserDoc(user);

        navigator.pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    }
  }

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

              onPressed: () => _googleLogin(context),
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
