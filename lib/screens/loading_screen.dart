import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  // check auth
  Future<void> _checkAuth(BuildContext context) async {
    // temp wait 2 seconds instead of auth
    await Future.delayed(const Duration(seconds: 2));

    // Once future completes, schedule navigation *after* this frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed('/welcome');
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
