import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swoosh/services/user_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _signup(BuildContext context) async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (password != confirm) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = cred.user;

      if (user != null) {
        ensureUserDoc(user);
        navigator.pushReplacementNamed('/home');
      }

    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Signup failed (${e.code})')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Create an Account",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _signup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[900],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15),
                ),
                child: const Text("Continue"),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text("Already have an account? Login"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
