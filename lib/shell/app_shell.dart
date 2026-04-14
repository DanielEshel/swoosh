// lib/shell/app_shell.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:swoosh/pages/pages.dart';
// Import your new BLE service
import '../services/ble_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // Bring in the new Bluetooth singleton
  final BleService _bleService = BleService();

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // Cleaned constructors! The UI components will now
      // fetch their own state from BleService.
      const HomeTab(),
      const CameraPage(),
      const Center(
          child: Text("Analytics Page", style: TextStyle(fontSize: 22))),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("SWOOSH"),
        centerTitle: true,
        actions: [
          // Global Bluetooth Status Icon
          ListenableBuilder(
            listenable: _bleService,
            builder: (context, child) {
              IconData icon;
              Color color;

              switch (_bleService.connectionState) {
                case 'connected':
                  icon = Icons.bluetooth_connected;
                  color = Colors.greenAccent;
                  break;
                case 'scanning':
                  icon = Icons.bluetooth_searching;
                  color = Colors.orange;
                  break;
                default:
                  icon = Icons.bluetooth_disabled;
                  color = Colors.grey;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(icon, color: color),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Safely disconnect hardware before logging out
              await _bleService.disconnect();

              final navigator = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              navigator.pushNamedAndRemoveUntil('/welcome', (route) => false);
            },
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: "Camera"),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics), label: "Analysis"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
