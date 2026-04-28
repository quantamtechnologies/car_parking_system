import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

const _compactWidthBreakpoint = 600.0;

bool _isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < _compactWidthBreakpoint;

EdgeInsets _compactInsets(
  BuildContext context,
  EdgeInsetsGeometry padding, {
  double scale = 0.78,
  double minValue = 6,
}) {
  final resolved = padding.resolve(Directionality.of(context));

  double shrink(double value) {
    if (value <= 0) return 0;
    return math.max(minValue, value * scale).toDouble();
  }

  return EdgeInsets.fromLTRB(
    shrink(resolved.left),
    shrink(resolved.top),
    shrink(resolved.right),
    shrink(resolved.bottom),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
    this.color = ParkingColors.surface,
    this.gradient,
    this.borderColor = const Color(0xFF1F2D4D),
    this.shadow = const [
      BoxShadow(
          color: Color(0x40050A15), blurRadius: 28, offset: Offset(0, 16)),
    ],
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Gradient? gradient;
  final Color borderColor;
  final List<BoxShadow> shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = _isCompactWidth(context)
        ? _compactInsets(context, padding)
        : padding.resolve(Directionality.of(context));
    final decorated = Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: shadow,
      ),
      child: Padding(padding: effectivePadding, child: child),
    );

    if (onTap == null) {
      return decorated;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: decorated,
      ),
    );
  }
}

class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.minHeight = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isBusy;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ParkingColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x264A35E8),
                blurRadius: 20,
                offset: Offset(0, 10)),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: Size.fromHeight(minHeight),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: enabled ? onPressed : null,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Row(
                    key: ValueKey(label),
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20),
                        const SizedBox(width: 10),
                      ],
                      Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.gradient,
    this.footer,
    this.iconColor,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Gradient? gradient;
  final Widget? footer;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final foreground = Colors.white;
    final muted = const Color(0xFF9EABC9);
    final compact = _isCompactWidth(context);

    return SurfaceCard(
      gradient: gradient,
      color: gradient == null ? const Color(0xFF101C38) : Colors.transparent,
      borderColor: gradient == null
          ? const Color(0xFF1E2B4D)
          : Colors.white.withOpacity(0.08),
      shadow: gradient == null
          ? const [
              BoxShadow(
                  color: Color(0x40050A15),
                  blurRadius: 22,
                  offset: Offset(0, 12))
            ]
          : const [
              BoxShadow(
                  color: Color(0x300F1D3C),
                  blurRadius: 26,
                  offset: Offset(0, 16))
            ],
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 122 : 134),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: gradient == null
                          ? const Color(0xFF1A294C)
                          : Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: gradient == null
                          ? (iconColor ?? const Color(0xFF7FB2FF))
                          : Colors.white,
                      size: 22,
                    ),
                  ),
                const Spacer(),
                if (gradient != null)
                  Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.9),
                    size: 20,
                  )
                else
                  Icon(
                    Icons.more_vert_rounded,
                    color: const Color(0xFFB7BDD1),
                    size: 20,
                  ),
              ],
            ),
            SizedBox(height: compact ? 14 : 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: compact
                    ? (gradient == null ? 24 : 26)
                    : (gradient == null ? 26 : 28),
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
                color: foreground,
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: 8),
              footer!,
            ] else if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 640;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667085),
                  height: 1.45,
                ),
          ),
        ],
      ],
    );

    if (trailing == null) {
      return header;
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 12),
          trailing!,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: header),
        trailing!,
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class QuickActionCard extends StatefulWidget {
  const QuickActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accentColor = ParkingColors.primary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactWidth(context);
    final background =
        _hovered ? const Color(0xFF132246) : const Color(0xFF101C38);
    final borderColor =
        _hovered ? const Color(0xFF2A3C68) : const Color(0xFF1D2B4C);
    final shadow = _hovered
        ? [
            const BoxShadow(
                color: Color(0x300F1D3C),
                blurRadius: 22,
                offset: Offset(0, 12)),
          ]
        : [
            const BoxShadow(
                color: Color(0x40050A15),
                blurRadius: 18,
                offset: Offset(0, 10)),
          ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          boxShadow: shadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(compact ? 20 : 22),
            onTap: widget.onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14, vertical: compact ? 10 : 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: compact ? 40 : 42,
                    height: compact ? 40 : 42,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(compact ? 13 : 14),
                    ),
                    child: Icon(widget.icon,
                        color: widget.accentColor, size: compact ? 20 : 22),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 12 : 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 10 : 10.5,
                        color: const Color(0xFF8F9CB9),
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CameraPreviewCard extends StatelessWidget {
  const CameraPreviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.camera_alt_rounded,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 30,
      padding: const EdgeInsets.all(18),
      gradient: const LinearGradient(
        colors: [Color(0xFF0F1C5A), Color(0xFF16307B), Color(0xFF223FA2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Colors.white.withOpacity(0.06),
      shadow: const [
        BoxShadow(
            color: Color(0x300B1630), blurRadius: 30, offset: Offset(0, 18)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B7BFF), Color(0xFF5F42F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x264A35E8),
                        blurRadius: 22,
                        offset: Offset(0, 10)),
                  ],
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    color: Colors.white, size: 42),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 58,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextButton.icon(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 24),
                    label: Text(
                      actionLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1.55,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF4D5E86),
                          Color(0xFF24315A),
                          Color(0xFF111C3D)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 64,
                      color: const Color(0xFF18224B).withOpacity(0.62),
                    ),
                  ),
                  Positioned(
                    left: -12,
                    top: 30,
                    bottom: 18,
                    child: Container(
                      width: 84,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.10),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -18,
                    top: 22,
                    bottom: 22,
                    child: Container(
                      width: 108,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.14),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 560,
                      height: 220,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1E52A2),
                            Color(0xFF0F2B68),
                            Color(0xFF0A1A3C)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(42),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x3A000000),
                              blurRadius: 20,
                              offset: Offset(0, 10)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 44,
                            right: 44,
                            top: 16,
                            child: Container(
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF214F9F),
                                    Color(0xFF132E65)
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 54,
                            right: 54,
                            top: 34,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E1B39),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Container(
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0B1733),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Container(
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0B1733),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 84,
                            right: 84,
                            top: 80,
                            child: Container(
                              height: 62,
                              decoration: BoxDecoration(
                                color: const Color(0xFF21335A),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.12)),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 118,
                            right: 118,
                            bottom: 24,
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F3E7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF9E9A8C), width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x26000000),
                                      blurRadius: 12,
                                      offset: Offset(0, 6)),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'PLATE NUMBER',
                                  style: TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 30,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 88,
                            right: 88,
                            bottom: 22,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _CameraCorner(
                                  alignment: Alignment.topLeft,
                                ),
                                _CameraCorner(
                                  alignment: Alignment.topRight,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 140,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 182,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _CameraControlButton(
                icon: Icons.flash_on_rounded,
                filled: false,
                onTap: onAction,
              ),
              const Spacer(),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ParkingColors.primaryGradient,
                  border: Border.all(color: Colors.white, width: 6),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x384A35E8),
                        blurRadius: 18,
                        offset: Offset(0, 10)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.photo_camera_rounded,
                      color: Colors.white, size: 38),
                ),
              ),
              const Spacer(),
              _CameraControlButton(
                icon: Icons.photo_library_rounded,
                filled: false,
                onTap: onAction,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CameraCorner extends StatelessWidget {
  const _CameraCorner({
    required this.alignment,
  });

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.topLeft;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: Colors.white.withOpacity(0.95), width: isLeft ? 5 : 0),
          top: BorderSide(color: Colors.white.withOpacity(0.95), width: 5),
          right: BorderSide(
              color: Colors.white.withOpacity(0.95), width: isLeft ? 0 : 5),
          bottom: BorderSide(color: Colors.white.withOpacity(0.95), width: 5),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLeft ? 12 : 0),
          topRight: Radius.circular(isLeft ? 0 : 12),
          bottomLeft: Radius.circular(isLeft ? 12 : 0),
          bottomRight: Radius.circular(isLeft ? 0 : 12),
        ),
      ),
    );
  }
}

class _CameraControlButton extends StatelessWidget {
  const _CameraControlButton({
    required this.icon,
    required this.onTap,
    this.filled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? Colors.white.withOpacity(0.18)
                : Colors.white.withOpacity(0.14),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class VehicleRowCard extends StatefulWidget {
  const VehicleRowCard({
    super.key,
    required this.vehicleType,
    required this.ownerName,
    required this.phoneNumber,
    required this.plateNumber,
    this.statusLabel,
    this.statusColor = const Color(0xFF4A35E8),
    this.onTap,
    this.selected = false,
  });

  final String vehicleType;
  final String ownerName;
  final String phoneNumber;
  final String plateNumber;
  final String? statusLabel;
  final Color statusColor;
  final VoidCallback? onTap;
  final bool selected;

  @override
  State<VehicleRowCard> createState() => _VehicleRowCardState();
}

class _VehicleRowCardState extends State<VehicleRowCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final elevated = _hovered || widget.selected;
    final borderColor = widget.selected
        ? const Color(0xFFB9C7FF)
        : _hovered
            ? const Color(0xFFCAD6FF)
            : const Color(0xFFE5ECF5);
    final background = widget.selected
        ? const Color(0xFFF4F6FF)
        : _hovered
            ? Colors.white
            : Colors.white;
    final shadow = elevated
        ? [
            const BoxShadow(
                color: Color(0x1A4A35E8),
                blurRadius: 22,
                offset: Offset(0, 12)),
          ]
        : [
            const BoxShadow(
                color: Color(0x0D0B1630), blurRadius: 16, offset: Offset(0, 8)),
          ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          boxShadow: shadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.vehicleType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        if (widget.statusLabel != null)
                          StatusBadge(
                              label: widget.statusLabel!,
                              color: widget.statusColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.phoneNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF667085)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.plateNumber,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Plate number',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.selected
                                ? const Color(0xFF4A35E8)
                                : const Color(0xFF667085),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.entryTime,
    required this.exitTime,
    required this.durationLabel,
    required this.baseFee,
    required this.overdueFee,
    required this.totalDue,
    this.overdue = false,
    this.note,
  });

  final String entryTime;
  final String exitTime;
  final String durationLabel;
  final double baseFee;
  final double overdueFee;
  final double totalDue;
  final bool overdue;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final danger = overdue ? const Color(0xFFE45858) : const Color(0xFF0F4CFF);

    return SurfaceCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF4A35E8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt preview',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calculated automatically from the selected parking session.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: const Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: overdue ? 'Overdue' : 'On time',
                color: danger,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ReceiptRow(label: 'Entry time', value: entryTime),
          const SizedBox(height: 10),
          _ReceiptRow(label: 'Exit time', value: exitTime),
          const SizedBox(height: 10),
          _ReceiptRow(label: 'Total duration', value: durationLabel),
          const SizedBox(height: 10),
          _ReceiptRow(label: 'Base fee', value: money(baseFee)),
          const SizedBox(height: 10),
          _ReceiptRow(
            label: 'Overdue fee',
            value: money(overdueFee),
            valueColor: overdueFee > 0 ? danger : const Color(0xFF667085),
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(
              note!,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF4F7FF), Color(0xFFEAF3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total amount to pay',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF667085),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  money(totalDue),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0D1530),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentStatusCard extends StatelessWidget {
  const PaymentStatusCard({
    super.key,
    required this.statusLabel,
    required this.amountPaid,
    required this.amountDue,
    this.receiptNumber,
    this.method,
  });

  final String statusLabel;
  final double amountPaid;
  final double amountDue;
  final String? receiptNumber;
  final String? method;

  @override
  Widget build(BuildContext context) {
    final paid = statusLabel.toLowerCase() == 'paid';
    final color = paid ? const Color(0xFF22A06B) : const Color(0xFFF2994A);

    return SurfaceCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      color: const Color(0xFF101C38),
      borderColor: const Color(0xFF1E2B4D),
      shadow: const [
        BoxShadow(
            color: Color(0x40050A15), blurRadius: 22, offset: Offset(0, 12)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                    paid ? Icons.verified_rounded : Icons.pending_rounded,
                    color: color,
                    size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment status',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receiptNumber == null
                          ? 'Waiting for confirmation'
                          : 'Receipt $receiptNumber',
                      style: const TextStyle(
                          color: Color(0xFF9EABC9),
                          fontSize: 12.5,
                          height: 1.35),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: statusLabel, color: color),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PaymentMetric(
                  label: 'Amount paid',
                  value: money(amountPaid),
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PaymentMetric(
                  label: 'Amount due',
                  value: money(amountDue),
                  color: const Color(0xFF4A35E8),
                ),
              ),
            ],
          ),
          if (method != null) ...[
            const SizedBox(height: 12),
            Text(
              'Method: ${method!}',
              style: const TextStyle(color: Color(0xFF9EABC9), fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class ChartBarData {
  const ChartBarData({
    required this.label,
    required this.value,
    this.subLabel,
  });

  final String label;
  final double value;
  final String? subLabel;
}

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.points,
    this.barColor = const Color(0xFF4A35E8),
    this.accentColor = const Color(0xFF2EC7FF),
    this.emptyLabel = 'No data yet',
  });

  final List<ChartBarData> points;
  final Color barColor;
  final Color accentColor;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(
              color: Color(0xFF9EABC9), fontWeight: FontWeight.w600),
        ),
      );
    }

    final maxValue =
        points.fold<double>(0, (max, point) => math.max(max, point.value));
    final max = _niceChartMax(maxValue);
    final axisValues = <double>[
      max,
      max * 0.8,
      max * 0.6,
      max * 0.4,
      max * 0.2,
      0,
    ];

    return LayoutBuilder(
      builder: (context, _) {
        return SizedBox(
          height: 228,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 42,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final value in axisValues)
                        Text(
                          _compactAxisLabel(value),
                          style: const TextStyle(
                            color: Color(0xFF8D9AB8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Column(
                          children: List.generate(
                            5,
                            (index) => Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFF1E2B4D),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final point in points)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, tileConstraints) {
                                          final availableHeight =
                                              tileConstraints.maxHeight.isFinite
                                                  ? tileConstraints.maxHeight
                                                  : 150.0;
                                          final barHeight = ((availableHeight -
                                                      34) *
                                                  (point.value / max))
                                              .clamp(12.0, availableHeight - 34)
                                              .toDouble();

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 28),
                                            child: Align(
                                              alignment: Alignment.bottomCenter,
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 260),
                                                curve: Curves.easeOutCubic,
                                                width: double.infinity,
                                                height: barHeight,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      barColor,
                                                      accentColor
                                                    ],
                                                    begin:
                                                        Alignment.bottomCenter,
                                                    end: Alignment.topCenter,
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius
                                                          .vertical(
                                                    top: Radius.circular(14),
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Color(0x1A4A35E8),
                                                      blurRadius: 12,
                                                      offset: Offset(0, 6),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      point.label,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF8D9AB8),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _compactAxisLabel(double value) {
  if (value <= 0) {
    return '0';
  }
  if (value >= 1000) {
    final thousands = value / 1000;
    if ((thousands - thousands.roundToDouble()).abs() < 0.05) {
      return '${thousands.round()}K';
    }
    return '${thousands.toStringAsFixed(1)}K';
  }
  if (value >= 100) {
    return value.round().toString();
  }
  return value.toStringAsFixed(0);
}

double _niceChartMax(double value) {
  if (value <= 0) {
    return 1.0;
  }

  final exponent = (math.log(value) / math.ln10).floor();
  final magnitude = math.pow(10, exponent).toDouble();
  final normalized = value / magnitude;

  double step;
  if (normalized <= 1) {
    step = 1;
  } else if (normalized <= 2) {
    step = 2;
  } else if (normalized <= 5) {
    step = 5;
  } else {
    step = 10;
  }

  return step * magnitude;
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF0D1530),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PaymentMetric extends StatelessWidget {
  const _PaymentMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B3A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9EABC9),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class ParkingStatusBar extends StatelessWidget {
  const ParkingStatusBar({
    super.key,
    this.dark = false,
  });

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : ParkingColors.ink;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '9:41',
          style: TextStyle(
            color: foreground,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signal_cellular_alt_rounded,
                color: foreground, size: 24),
            const SizedBox(width: 6),
            Icon(Icons.wifi_rounded, color: foreground, size: 24),
            const SizedBox(width: 6),
            Container(
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                color: dark ? Colors.white : ParkingColors.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '100',
                style: TextStyle(
                  color: dark ? ParkingColors.ink : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.size = 54,
    this.iconSize = 24,
    this.badgeColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: foreground, size: iconSize),
            ),
            if (badgeColor != null)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeColor,
                    border: Border.all(color: background, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ParkingUserChip extends StatelessWidget {
  const ParkingUserChip({
    super.key,
    required this.name,
    required this.role,
    this.dark = false,
    this.compact = false,
    this.onTap,
  });

  final String name;
  final String role;
  final bool dark;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : ParkingColors.ink;
    final roleColor = dark ? const Color(0xFFB1BED9) : const Color(0xFF6D3EF7);
    final background = dark ? const Color(0xFF0F1B3A) : Colors.white;
    final borderColor =
        dark ? const Color(0xFF1E2B4D) : const Color(0xFFE8EDF7);
    final avatarSize = compact ? 42.0 : 54.0;
    final nameSize = compact ? 15.0 : 18.0;
    final roleSize = compact ? 12.0 : 13.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? Colors.white.withOpacity(0.12)
                      : const Color(0xFFEAF0FF),
                ),
                child: Icon(Icons.person_rounded,
                    color: dark ? Colors.white : ParkingColors.primary,
                    size: compact ? 24 : 30),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: nameSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role,
                      style: TextStyle(
                        color: roleColor,
                        fontSize: roleSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: textColor, size: compact ? 24 : 30),
            ],
          ),
        ),
      ),
    );
  }
}

class ParkingScreenHeader extends StatelessWidget {
  const ParkingScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.user,
    required this.onLeadingTap,
    required this.leadingIcon,
    this.dark = false,
    this.backgroundGradient,
    this.backgroundColor,
    this.leadingIconColor,
    this.leadingBackground,
    this.trailingIcon,
    this.trailingOnTap,
    this.trailingBackground,
    this.trailingIconColor,
    this.trailingBadgeColor,
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 20),
    this.titleSize = 30,
    this.subtitleSize = 15,
    this.titleColor,
    this.subtitleColor,
    this.showStatusBar = false,
    this.bottomRadius = 34,
  });

  final String title;
  final String subtitle;
  final UserProfile? user;
  final VoidCallback onLeadingTap;
  final IconData leadingIcon;
  final bool dark;
  final Gradient? backgroundGradient;
  final Color? backgroundColor;
  final Color? leadingIconColor;
  final Color? leadingBackground;
  final IconData? trailingIcon;
  final VoidCallback? trailingOnTap;
  final Color? trailingBackground;
  final Color? trailingIconColor;
  final Color? trailingBadgeColor;
  final EdgeInsetsGeometry padding;
  final double titleSize;
  final double subtitleSize;
  final Color? titleColor;
  final Color? subtitleColor;
  final bool showStatusBar;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    final titleFg = titleColor ?? (dark ? Colors.white : ParkingColors.ink);
    final subtitleFg = subtitleColor ??
        (dark ? Colors.white.withOpacity(0.80) : const Color(0xFF667085));
    final leadBg = leadingBackground ??
        (dark ? const Color(0xFF142348) : const Color(0xFFEAF0FF));
    final leadFg =
        leadingIconColor ?? (dark ? Colors.white : ParkingColors.primary);
    final trailBg = trailingBackground ??
        (dark ? const Color(0xFF142348) : const Color(0xFFEAF0FF));
    final trailFg =
        trailingIconColor ?? (dark ? Colors.white : ParkingColors.primary);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: backgroundGradient,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
            final resolved = padding.resolve(Directionality.of(context));
            final effectivePadding = narrow
                ? _compactInsets(
                    context,
                    EdgeInsets.fromLTRB(resolved.left, resolved.top,
                        resolved.right, resolved.bottom),
                    scale: 0.76,
                    minValue: 8,
                  )
                : resolved;
            final compact = narrow;
            final effectiveTitleSize = compact ? titleSize * 0.9 : titleSize;
            final effectiveSubtitleSize =
                compact ? subtitleSize * 0.9 : subtitleSize;
            final topRow = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderIconButton(
                  icon: leadingIcon,
                  onTap: onLeadingTap,
                  background: leadBg,
                  foreground: leadFg,
                  size: compact ? 48 : 54,
                  iconSize: compact ? 22 : 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleFg,
                          fontSize: effectiveTitleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: subtitleFg,
                          fontSize: effectiveSubtitleSize,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 10),
                  _HeaderIconButton(
                    icon: trailingIcon!,
                    onTap: trailingOnTap ?? () {},
                    background: trailBg,
                    foreground: trailFg,
                    badgeColor: trailingBadgeColor,
                    size: compact ? 48 : 54,
                    iconSize: compact ? 22 : 24,
                  ),
                ],
              ],
            );

            return Padding(
              padding: effectivePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showStatusBar) ParkingStatusBar(dark: dark),
                  if (showStatusBar) const SizedBox(height: 12),
                  topRow,
                  if (user != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: narrow ? constraints.maxWidth : 336),
                        child: ParkingUserChip(
                          name: user!.displayName,
                          role: user!.displayRole,
                          dark: dark,
                          compact: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ParkingBottomNavItem {
  const ParkingBottomNavItem({
    required this.path,
    required this.icon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final String label;
}

class ParkingBottomNav extends StatelessWidget {
  const ParkingBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<ParkingBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < _compactWidthBreakpoint;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5EBF5))),
        boxShadow: [
          BoxShadow(
              color: Color(0x120B1630), blurRadius: 14, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              compact ? 8 : 14, 4, compact ? 8 : 14, compact ? 6 : 8),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _ParkingBottomNavItemTile(
                    item: items[index],
                    selected: index == selectedIndex,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingBottomNavItemTile extends StatelessWidget {
  const _ParkingBottomNavItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ParkingBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? const Color(0xFF2563EB) : const Color(0xFF8B96AD);
    final compact = MediaQuery.sizeOf(context).width < _compactWidthBreakpoint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin:
              EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: 2),
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE9F1FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: foreground, size: compact ? 23 : 25),
              SizedBox(height: compact ? 5 : 6),
              Text(
                item.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 11.5 : 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: selected ? (compact ? 34 : 42) : 12,
                height: selected ? 5 : 4,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
