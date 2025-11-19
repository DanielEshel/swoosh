import 'package:flutter/material.dart';

class WideButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final double widthFactor;
  final double height;
  final double radius;

  const WideButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor,
    this.widthFactor = 0.8,
    this.height = 56,
    this.radius = 16,
  });

  ButtonStyle _style(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: color ?? Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: SizedBox(
        width: screenWidth * widthFactor,
        height: height,
        child: ElevatedButton(
          onPressed: onPressed,
          style: _style(context),
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
        ),
      ),
    );
  }
}

class WideIconButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final double widthFactor;
  final double height;
  final double radius;

  const WideIconButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.color,
    this.textColor,
    this.widthFactor = 0.8,
    this.height = 56,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: SizedBox(
        width: screenWidth * widthFactor,
        height: height,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Theme.of(context).colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          icon: Icon(icon, color: Colors.white, size: 20),
          label: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: textColor ?? Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ),
      ),
    );
  }
}
