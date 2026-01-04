// lib/pages/home_tab.dart

import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  final String btStatus;
  final bool isScanning;
  final bool isConnected;
  final String sensorDistance; // Receive data
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const HomeTab({
    super.key,
    required this.btStatus,
    required this.isScanning,
    required this.isConnected,
    required this.sensorDistance,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Swoosh Tennis Tracker',
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
                  Icon(
                    isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    size: 50,
                    color: isConnected ? Colors.blue : Colors.grey,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    btStatus,
                    style: TextStyle(
                      fontSize: 18,
                      color: isConnected ? Colors.green : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // --- NEW SENSOR DISPLAY ---
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
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          "$sensorDistance cm",
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Monospace'),
                        ),
                      ],
                    ),
                  ),
                  // --------------------------

                  const SizedBox(height: 20),

                  if (isScanning)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: isConnected ? onDisconnect : onConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isConnected ? Colors.redAccent : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      icon: Icon(isConnected ? Icons.close : Icons.search),
                      label:
                          Text(isConnected ? "Disconnect" : "Scan & Connect"),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
