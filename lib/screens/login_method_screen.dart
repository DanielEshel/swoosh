import 'package:flutter/material.dart';
import 'package:swoosh/widgets/custom_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swoosh/services/user_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Import this

class LoginMethodScreen extends StatelessWidget {
  const LoginMethodScreen({super.key});

  Future<void> _googleLogin(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Initialize is required in v7 (often best done in initState, but works here too)
      // await GoogleSignIn.instance.initialize(); // Optional: Uncomment if you face initialization errors

      // 2. Use authenticate() instead of signIn(
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      // 3. Check if the user cancelled the login flow (googleUser will be null)
      if (googleUser == null) {
        // The user cancelled the login, so we should stop here.
        return;
      }

      // 4. NOW you have 'googleUser' and can get the authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      // 4. Create credential (idToken is sufficient for Firebase Auth)
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        // accessToken is removed in v7 and usually not needed for Firebase login
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        ensureUserDoc(user); // Make sure this function is imported/defined
        navigator.pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } catch (e) {
      // 5. Handle cancellation (the user closed the popup)
      // In v7, cancellation usually throws a PlatformException or just a generic error depending on platform
      print('Sign in error: $e'); // Helpful for debugging
      if (e.toString().contains('canceled') ||
          e.toString().contains('cancelled')) {
        return; // User closed the window, do nothing
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Login failed')),
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
            const Text(
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
