import 'package:flutter/material.dart';

/// Gives the green header its soft curved bottom edge (the signature
/// Q-commerce look). Used by wrapping the header `Container` in a
/// `ClipPath(clipper: CurvedHeaderClipper(), child: ...)`.
class CurvedHeaderClipper extends CustomClipper<Path> {
  const CurvedHeaderClipper({this.curveHeight = 28});

  final double curveHeight;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - curveHeight)
      ..quadraticBezierTo(
        size.width / 2,
        size.height,
        size.width,
        size.height - curveHeight,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
