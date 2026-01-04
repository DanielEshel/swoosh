// lib/shell/app_shell.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert'; // Import for utf8 decoding
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

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  String _btStatus = "Disconnected";
  bool _isScanning = false;
  bool _isConnected = false;
  String? _deviceId;

  // New variable for sensor data
  String _sensorDistance = "--";

  // BLE UUIDs
  final Uuid _serviceUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ab");
  final Uuid _charUuidRx =
      Uuid.parse("12345678-1234-1234-1234-1234567890ac"); // Write
  final Uuid _charUuidTx =
      Uuid.parse("12345678-1234-1234-1234-1234567890ad"); // Read/Notify (New)

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _sensorSub; // Subscription for sensor data

  Future<void> scanAndConnect() async {
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
      if (device.name == "SwooshESP32") {
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

  Future<void> _connectToDevice(String deviceId) async {
    setState(() => _btStatus = "Connecting...");
    _deviceId = deviceId;

    _connSub = _ble
        .connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 6),
    )
        .listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        setState(() {
          _isConnected = true;
          _btStatus = "Connected";
        });

        // Start listening to sensor immediately after connection
        _subscribeToSensor(deviceId);
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        _disconnect();
      }
    }, onError: (e) {
      _disconnect();
    });
  }

  // LISTEN TO SENSOR DATA
  void _subscribeToSensor(String deviceId) {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: _serviceUuid,
      characteristicId: _charUuidTx,
    );

    _sensorSub = _ble.subscribeToCharacteristic(characteristic).listen((data) {
      // Decode bytes to string
      final distStr = utf8.decode(data);
      if (mounted) {
        setState(() {
          _sensorDistance = distStr;
        });
      }
    }, onError: (dynamic error) {
      // Handle error
    });
  }

  Future<void> sendServoCommand(String cmd) async {
    if (_deviceId == null) return;
    final characteristic = QualifiedCharacteristic(
      deviceId: _deviceId!,
      serviceId: _serviceUuid,
      characteristicId: _charUuidRx,
    );
    try {
      await _ble.writeCharacteristicWithResponse(
        characteristic,
        value: cmd.codeUnits,
      );
    } catch (e) {
      // print("Write error: $e");
    }
  }

  void _disconnect() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _sensorSub?.cancel(); // Cancel sensor subscription

    setState(() {
      _isConnected = false;
      _btStatus = "Disconnected";
      _deviceId = null;
      _sensorDistance = "--";
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeTab(
        btStatus: _btStatus,
        isScanning: _isScanning,
        isConnected: _isConnected,
        sensorDistance: _sensorDistance, // Pass data to UI
        onConnect: scanAndConnect,
        onDisconnect: _disconnect,
      ),
      CameraPage(
        onSendCommand: sendServoCommand,
        isConnected: _isConnected,
      ),
      const Center(
          child: Text("Analytics Page", style: TextStyle(fontSize: 22))),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("SWOOSH"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _disconnect();
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

  @override
  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _sensorSub?.cancel();
    super.dispose();
  }
}
