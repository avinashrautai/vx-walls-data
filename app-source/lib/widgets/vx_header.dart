import 'package:flutter/material.dart';
import 'vx_brand_mark.dart';

class VXHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final bool compact;
  final Color? foregroundColor;

  const VXHeader({
    super.key,
    required this.title,
    this.trailing,
    this.compact = false,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = foregroundColor ??
        (dark ? Colors.white : const Color(0xFF17171A));
    return SizedBox(
      height: compact ? 54 : 62,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          VXBrandMark(size: compact ? 24 : 27, color: foreground),
          const SizedBox(width: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 18 : 20,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.55,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
