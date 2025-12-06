import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:swoosh/pages/home_tab.dart';
import 'package:swoosh/pages/camera_page.dart'; // Ensure this matches your filename

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // 🔵 Shared Bluetooth State
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _servoCharacteristic;
  String _btStatus = "Disconnected";
  bool _isScanning = false;

  final String targetDeviceName = "ESP32_Swoosh"; // Match your ESP32 code

  // 📡 Scan & Connect Logic (Called from HomeTab)
  Future<void> scanAndConnect() async {
    // 1. Permissions
    if (Platform.isAndroid || Platform.isIOS) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }

    setState(() {
      _btStatus = "Scanning...";
      _isScanning = true;
    });

    try {
      // 2. Start Scan
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (r.device.platformName == targetDeviceName) {
            await FlutterBluePlus.stopScan();
            await _connectToDevice(r.device);
            break;
          }
        }
      });
    } catch (e) {
      setState(() {
        _btStatus = "Scan Error: $e";
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();

      // Find the Write Characteristic
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            setState(() {
              _servoCharacteristic = characteristic;
            });
          }
        }
      }

      setState(() {
        _connectedDevice = device;
        _btStatus = "Connected to ${device.platformName}";
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _btStatus = "Connection Failed";
        _isScanning = false;
      });
    }
  }

  void _disconnect() {
    _connectedDevice?.disconnect();
    setState(() {
      _connectedDevice = null;
      _servoCharacteristic = null;
      _btStatus = "Disconnected";
    });
  }

  @override
  Widget build(BuildContext context) {
    // We create the pages dynamically to pass the updated state down
    final List<Widget> pages = [
      // 1. HOME TAB (Controls the connection)
      HomeTab(
        btStatus: _btStatus,
        isScanning: _isScanning,
        isConnected: _connectedDevice != null,
        onConnect: scanAndConnect,
        onDisconnect: _disconnect,
      ),

      // 2. CAMERA TAB (Uses the connection)
      CameraPage(
        servoCharacteristic: _servoCharacteristic,
      ),

      // 3. Analytics
      const Center(
          child: Text("Analytics Page", style: TextStyle(fontSize: 22))),

      // 4. Profile
      const Center(child: Text("Profile Page", style: TextStyle(fontSize: 22))),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("SWOOSH"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _connectedDevice?.disconnect(); // Safety disconnect
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
        type: BottomNavigationBarType.fixed, // Needed for 4+ items usually
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.videocam), label: "Camera"), // Replaced Inbox
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics), label: "Analysis"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
