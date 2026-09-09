import 'package:flutter/material.dart';

enum VXPillMode { navigation, contextual }

class VXPillItem {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const VXPillItem({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
}

/// Canonical VX Pill visual language.
///
/// The Pill is intentionally independent from the application's light/dark
/// theme. It stays white and uses one restrained Fine Line treatment.
class VXPillTheme {
  static const Color background = Colors.white;
  static const Color border = Color(0xFFC9C9CE);
  static const Color iconColor = Color(0xFF17171A);
  static const Color textColor = Color(0xFF17171A);
  static const Color selectedColor = Color(0xFFF0642F);
  static const Color selectedBackground = Color(0x0FF0642F);
  static const double height = 66;
  static const double radius = 33;
  static const double borderWidth = .65;

  static const List<BoxShadow> shadows = <BoxShadow>[
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 12,
      offset: Offset(0, 5),
    ),
  ];
}

class VXPill extends StatelessWidget {
  final List<VXPillItem> items;
  final VXPillMode mode;
  final bool floating;
  final double? widthOverride;
  final int animationMode;

  const VXPill({
    super.key,
    required this.items,
    this.mode = VXPillMode.navigation,
    this.floating = true,
    this.widthOverride,
    this.animationMode = 1,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth - 24;
    final targetWidth = mode == VXPillMode.contextual ? 344.0 : 284.0;
    final minWidth = maxWidth < 220 ? maxWidth : 220.0;
    final pillWidth = widthOverride ?? maxWidth.clamp(minWidth, targetWidth).toDouble();

    final pill = Semantics(
      container: true,
      label: mode == VXPillMode.navigation ? 'Navigation' : 'Wallpaper controls',
      child: Container(
        height: VXPillTheme.height,
        width: pillWidth,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: VXPillTheme.background,
          borderRadius: BorderRadius.circular(VXPillTheme.radius),
          border: Border.all(color: VXPillTheme.border, width: VXPillTheme.borderWidth),
          boxShadow: VXPillTheme.shadows,
        ),
        child: Row(
          children: items.map((item) => Expanded(child: _Item(item: item, animationMode: animationMode))).toList(),
        ),
      ),
    );

    if (!floating) return Center(child: pill);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 22, left: 12, right: 12),
          child: pill,
        ),
      ),
    );
  }
}

class VXPillCallout extends StatelessWidget {
  final Widget child;
  final double targetX;
  final double width;

  const VXPillCallout({super.key, required this.child, required this.targetX, this.width = 275});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const pillBottomPadding = 22.0;
    const connectorHeight = 11.0;
    final maxWidth = screenWidth - 24;
    final effectiveWidth = maxWidth < 220 ? maxWidth : width.clamp(220.0, maxWidth).toDouble();
    final popupBottom = safeBottom + pillBottomPadding + VXPillTheme.height + connectorHeight;
    final minTarget = effectiveWidth / 2 + 12;
    final maxTarget = screenWidth - effectiveWidth / 2 - 12;
    final clampedTarget = targetX.clamp(minTarget, maxTarget).toDouble();
    final left = clampedTarget - effectiveWidth / 2;

    return Stack(children: [
      Positioned(
        left: left,
        bottom: popupBottom,
        width: effectiveWidth,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: VXPillTheme.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: VXPillTheme.border, width: VXPillTheme.borderWidth),
              boxShadow: VXPillTheme.shadows,
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
          ),
        ),
      ),
      Positioned(
        left: clampedTarget - 9,
        bottom: safeBottom + pillBottomPadding + VXPillTheme.height - 1,
        width: 18,
        height: connectorHeight + 2,
        child: const IgnorePointer(child: CustomPaint(painter: _CalloutConnectorPainter())),
      ),
    ]);
  }
}

class _Item extends StatelessWidget {
  final VXPillItem item;
  final int animationMode;
  const _Item({required this.item, required this.animationMode});

  @override
  Widget build(BuildContext context) {
    final color = item.selected ? VXPillTheme.selectedColor : VXPillTheme.iconColor;
    final duration = Duration(milliseconds: animationMode == 0 ? 0 : animationMode == 1 ? 180 : 300);
    return Semantics(
      button: true,
      selected: item.selected,
      label: item.label,
      hint: item.selected ? 'Selected' : 'Activate',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: animationMode == 2 ? Curves.easeInOutCubic : Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: item.selected ? VXPillTheme.selectedBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              item.iconWidget != null
                  ? AnimatedScale(
                      scale: item.selected ? 1.0 : .96,
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: SizedBox(width: 21, height: 21, child: item.iconWidget),
                    )
                  : Icon(item.icon, size: 21, color: color),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, height: 1, fontWeight: item.selected ? FontWeight.w800 : FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalloutConnectorPainter extends CustomPainter {
  const _CalloutConnectorPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(2, 0)
      ..lineTo(size.width - 2, 0)
      ..lineTo(size.width - 5, size.height)
      ..lineTo(5, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
