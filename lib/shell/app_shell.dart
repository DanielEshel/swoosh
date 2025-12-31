import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'package:swoosh/pages/pages.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // BLE client
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // BLE state
  String _btStatus = "Disconnected";
  bool _isScanning = false;
  bool _isConnected = false;
  String? _deviceId;

  // BLE UUIDs (must match ESP32 NimBLE code)
  final Uuid _serviceUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ab");
  final Uuid _charUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ac");

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;

  // ----------------------------------------------------------
  // Scan & connect to SwooshESP32
  // ----------------------------------------------------------
  Future<void> scanAndConnect() async {
    // Android runtime permissions
    if (Platform.isAndroid) {
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

    _scanSub = _ble.scanForDevices(
      withServices: [_serviceUuid],
      scanMode: ScanMode.lowLatency,
    ).listen((device) async {
      // Debug
      // print("Found: ${device.name} (${device.id})");

      if (device.name == "SwooshESP32") {
        // Stop scanning once we find the ESP
        await _scanSub?.cancel();
        setState(() => _isScanning = false);

        await _connectToDevice(device.id);
      }
    }, onError: (e) {
      setState(() {
        _btStatus = "Scan Error: $e";
        _isScanning = false;
      });
    });
  }

  // ----------------------------------------------------------
  // Connect to device by id
  // ----------------------------------------------------------
  Future<void> _connectToDevice(String deviceId) async {
    setState(() => _btStatus = "Connecting...");

    _deviceId = deviceId;

    // connectToDevice returns a stream; cancelling it triggers disconnect
    _connSub = _ble
        .connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 6),
    )
        .listen((update) {
      // print("BLE state: ${update.connectionState}");

      if (update.connectionState == DeviceConnectionState.connected) {
        setState(() {
          _isConnected = true;
          _btStatus = "Connected";
        });
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        setState(() {
          _isConnected = false;
          _btStatus = "Disconnected";
          _deviceId = null;
        });
      }
    }, onError: (e) {
      setState(() {
        _btStatus = "Connection Failed";
        _isConnected = false;
      });
    });
  }

  // ----------------------------------------------------------
  // Send servo command: "0", "1", "2", ...
  // ----------------------------------------------------------
  Future<void> sendServoCommand(String cmd) async {
    if (_deviceId == null) return;

    final characteristic = QualifiedCharacteristic(
      deviceId: _deviceId!,
      serviceId: _serviceUuid,
      characteristicId: _charUuid,
    );

    try {
      await _ble.writeCharacteristicWithResponse(
        characteristic,
        value: cmd.codeUnits,
      );
      // print("Sent command: $cmd");
    } catch (e) {
      // print("Write error: $e");
    }
  }

  // ----------------------------------------------------------
  // Disconnect (by cancelling connection stream)
  // ----------------------------------------------------------
  void _disconnect() {
    _connSub?.cancel();
    _connSub = null;

    setState(() {
      _isConnected = false;
      _btStatus = "Disconnected";
      _deviceId = null;
    });
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // 1. HOME TAB (controls BLE connection)
      HomeTab(
        btStatus: _btStatus,
        isScanning: _isScanning,
        isConnected: _isConnected,
        onConnect: scanAndConnect,
        onDisconnect: _disconnect,
      ),

      // 2. CAMERA TAB (sends servo commands over BLE)
      CameraPage(
        onSendCommand: sendServoCommand,
        isConnected: _isConnected, // <— ADD THIS
      ),

      // 3. Analytics
      const Center(
        child: Text("Analytics Page", style: TextStyle(fontSize: 22)),
      ),

      // 4. Profile
      const ProfilePage(), // 
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("SWOOSH"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _disconnect(); // drop BLE connection
              final navigator = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              navigator.pushNamedAndRemoveUntil(
                '/welcome',
                (route) => false,
              );
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

  @override
  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
