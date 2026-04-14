import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final BleService _bleService = BleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Swoosh')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your existing UI stuff here...

            // The Bluetooth Connection UI
            ListenableBuilder(
              listenable: _bleService,
              builder: (context, child) {
                return _buildConnectionStatus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    if (_bleService.connectionState == 'connected') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.bluetooth_connected, color: Colors.green),
        label: const Text('Tracker Connected'),
        onPressed: () => _bleService.disconnect(),
      );
    }

    if (_bleService.connectionState == 'scanning') {
      return const CircularProgressIndicator();
    }

    // Disconnected state
    return ElevatedButton.icon(
      icon: const Icon(Icons.bluetooth),
      label: const Text('Connect Tracker'),
      onPressed: () => _showDeviceSelectionSheet(),
    );
  }

  void _showDeviceSelectionSheet() {
    _bleService.scanForDevices();

    showModalBottomSheet(
        context: context,
        builder: (context) {
          return ListenableBuilder(
            listenable: _bleService,
            builder: (context, child) {
              final devices = _bleService.discoveredDevices.entries.toList();

              if (devices.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: Text("Scanning for Swoosh Tracker...")),
                );
              }

              return ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    title: Text(device.value), // Device Name
                    subtitle: Text(device.key), // Device ID
                    trailing: const Icon(Icons.link),
                    onTap: () {
                      _bleService.connectToDevice(device.key);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          );
        });
  }
}
