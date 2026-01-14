// lib/shell/app_shell.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 1. ADD THIS IMPORT
import 'package:firebase_database/firebase_database.dart';
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

  String _sensorDistance = "--";

  final Uuid _serviceUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ab");
  final Uuid _charUuidRx = Uuid.parse("12345678-1234-1234-1234-1234567890ac");
  final Uuid _charUuidTx = Uuid.parse("12345678-1234-1234-1234-1234567890ad");

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _sensorSub;

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

        _subscribeToSensor(deviceId);
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        _disconnect();
      }
    }, onError: (e) {
      _disconnect();
    });
  }

  // ----------------------------------------------------------------------
  // 2. UPDATED SENSOR LOGIC: Upload to Firebase
  // ----------------------------------------------------------------------
  void _subscribeToSensor(String deviceId) {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: _serviceUuid,
      characteristicId: _charUuidTx,
    );

    _sensorSub = _ble.subscribeToCharacteristic(characteristic).listen((data) {
      final distStr = utf8.decode(data);

      // Update UI locally
      if (mounted) {
        setState(() {
          _sensorDistance = distStr;
        });
      }

      // Upload to Firebase Realtime Database
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Path: users/{uid}/sensor/distance
        FirebaseDatabase.instance
            .ref("users/${user.uid}/sensor/distance")
            .set(distStr);
      }
    }, onError: (dynamic error) {
      // print("Sensor error: $error");
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
    _sensorSub?.cancel();

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
        sensorDistance: _sensorDistance,
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
