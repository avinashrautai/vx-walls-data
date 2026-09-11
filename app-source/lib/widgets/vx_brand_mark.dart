import 'package:flutter/material.dart';

class VXBrandMark extends StatelessWidget {
  final double size;
  final bool? light;
  final Color? color;
  final bool compact;

  const VXBrandMark({
    super.key,
    this.size = 28,
    this.light,
    this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ??
        (light != null
            ? (light! ? Colors.white : const Color(0xFF18181B))
            : Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF18181B));

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _VXPainter(resolvedColor, compact: compact)),
    );
  }
}

class _VXPainter extends CustomPainter {
  final Color color;
  final bool compact;
  _VXPainter(this.color, {required this.compact});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * (compact ? .105 : .12)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final vRight = compact ? .47 : .52;
    final xLeft = compact ? .50 : .49;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .20)
      ..lineTo(size.width * .38, size.height * .80)
      ..lineTo(size.width * vRight, size.height * .46)
      ..moveTo(size.width * xLeft, size.height * .25)
      ..lineTo(size.width * .86, size.height * .80)
      ..moveTo(size.width * .84, size.height * .25)
      ..lineTo(size.width * .53, size.height * .70);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _VXPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.compact != compact;
}
