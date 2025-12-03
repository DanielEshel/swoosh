import 'package:flutter/material.dart';
import 'camera_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Example of future live data variables
  double? liveBallSpeed;
  int? rallyCount;
  bool isTracking = false;

  @override
  void initState() {
    super.initState();
    // TODO: connect to streams, timers, sensors later
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Swoosh Tennis Tracker',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // Example of live data UI (safe even if null)
          if (liveBallSpeed != null)
            Text(
              'Speed: ${liveBallSpeed!.toStringAsFixed(1)} mph',
              style: const TextStyle(fontSize: 20),
            )
          else
            const Text(
              'Speed: --',
              style: TextStyle(fontSize: 20),
            ),

          const SizedBox(height: 12),

          if (rallyCount != null)
            Text(
              'Rally count: $rallyCount',
              style: const TextStyle(fontSize: 18),
            ),

          const SizedBox(height: 30),

          ElevatedButton.icon(
            onPressed: () async {
              setState(() => isTracking = true);
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CameraPage(),
                ),
              );
              setState(() => isTracking = false);
            },
            icon: const Icon(Icons.videocam),
            label: Text(isTracking
                ? 'Tracking...'
                : 'Open Camera & Track Ball'),
          ),
        ],
      ),
    );
  }
}
