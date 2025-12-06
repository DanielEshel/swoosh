import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  final String btStatus;
  final bool isScanning;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const HomeTab({
    super.key,
    required this.btStatus,
    required this.isScanning,
    required this.isConnected,
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
          const SizedBox(height: 40),

          // 📡 Connectivity Status Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
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
                  
                  if (isScanning)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: isConnected ? onDisconnect : onConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected ? Colors.redAccent : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: Icon(isConnected ? Icons.close : Icons.search),
                      label: Text(isConnected ? "Disconnect Device" : "Find ESP32 & Connect"),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          const Text("Connect here to enable\nServo controls in the Camera tab.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey),),
        ],
      ),
    );
  }
}