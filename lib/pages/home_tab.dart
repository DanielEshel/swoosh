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
    return ListenableBuilder(
      listenable: _bleService,
      builder: (context, child) {
        final bool isConnected = _bleService.connectionState == 'connected';
        final bool isScanning = _bleService.connectionState == 'scanning';

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Tennis Tracker',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Bluetooth Icon (Blue if connected, Grey if disconnected)
                      Icon(
                        isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        size: 50,
                        color: isConnected ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(height: 16),

                      // Status Text
                      Text(
                        isConnected
                            ? "Status: Connected"
                            : "Status: Disconnected",
                        style: TextStyle(
                          fontSize: 18,
                          color: isConnected ? Colors.green : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // --- SENSOR DISPLAY (Restored from previous branch) ---
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            const Text("Proximity Sensor",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              isConnected
                                  // REPLACE the static "0.0 cm" with the live variable:
                                  ? "${_bleService.currentDistance} cm"
                                  : "-- cm",
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Monospace'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Button (Red for disconnect, Blue for connect)
                      if (isScanning)
                        const CircularProgressIndicator()
                      else
                        ElevatedButton.icon(
                          onPressed: isConnected
                              ? () => _bleService.disconnect()
                              : () => _showDeviceSelectionSheet(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isConnected
                                ? Colors.redAccent
                                : Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          icon: Icon(isConnected ? Icons.close : Icons.search),
                          label: Text(
                              isConnected ? "Disconnect" : "Scan & Connect"),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeviceSelectionSheet() {
    _bleService.scanForDevices(); // Triggers the Swift CBCentralManager scan

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              padding: const EdgeInsets.all(16),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(device.value), // Device Name
                  subtitle: Text(device.key), // Device ID
                  onTap: () {
                    _bleService.connectToDevice(
                        device.key); // Triggers Swift connection logic
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
