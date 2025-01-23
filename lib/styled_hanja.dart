import 'package:flutter/material.dart';

class StyledHanja extends StatelessWidget {
  final String text;
  final double fontSize;
  final double strokeWidth;
  final FontWeight fontWeight;

  const StyledHanja({
    super.key,
    required this.text,
    this.fontSize = 30,
    this.strokeWidth = 2,
    this.fontWeight = FontWeight.normal,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontFamily: 'HanyangHaeseo',
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth // Border thickness
              ..color = Color(0xFFDB7890), // Border color
          ),
        ),
        // Main text
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontFamily: 'HanyangHaeseo',
            color: Color(0xFFE392A3), // Text color
          ),
        ),
      ],
    );
  }
}