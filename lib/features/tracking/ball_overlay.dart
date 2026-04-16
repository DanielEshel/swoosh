import 'package:flutter/material.dart';
import 'tracking_api.g.dart';

class BallOverlay extends StatelessWidget {
  final BallDetection? detection;

  const BallOverlay({super.key, required this.detection});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // The painter will match the size of the Stack it is placed in (the whole screen)
      size: Size.infinite,
      painter: _BallPainter(detection: detection),
    );
  }
}

class _BallPainter extends CustomPainter {
  final BallDetection? detection;

  _BallPainter({required this.detection});

  @override
  void paint(Canvas canvas, Size size) {
    if (detection == null) return;

    // 1. Setup the Paint styles
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // 2. Convert normalized (0-1) coordinates to actual screen pixels
    // Since x and y represent the center of the ball, we treat them as centerX and centerY
    final centerX = detection!.x * size.width;
    final centerY = detection!.y * size.height;
    final width = detection!.width * size.width;
    final height = detection!.height * size.height;

    // 3. Draw the bounding box centered around the coordinates
    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height,
    );
    canvas.drawRect(rect, paint);

    // 4. Draw the confidence label
    final textSpan = TextSpan(
      text: '${(detection!.confidence * 100).toStringAsFixed(1)}%',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        backgroundColor: Colors.black54,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Position the text slightly above the top-left corner of the newly centered box
    final textLeft = centerX - (width / 2);
    final textTop = centerY - (height / 2);
    textPainter.paint(canvas, Offset(textLeft, textTop - 20));
  }

  @override
  bool shouldRepaint(covariant _BallPainter oldDelegate) {
    // Only repaint if the coordinates or confidence have actually changed
    if (oldDelegate.detection == null && detection == null) return false;
    if (oldDelegate.detection == null || detection == null) return true;

    return oldDelegate.detection!.x != detection!.x ||
        oldDelegate.detection!.y != detection!.y ||
        oldDelegate.detection!.width != detection!.width ||
        oldDelegate.detection!.height != detection!.height;
  }
}
