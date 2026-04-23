import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
    this.color = Colors.white,
    this.gradient,
    this.borderColor = const Color(0xFFE5ECF5),
    this.shadow = const [
      BoxShadow(color: Color(0x120B1630), blurRadius: 24, offset: Offset(0, 14)),
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
    final decorated = Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: shadow,
      ),
      child: Padding(padding: padding, child: child),
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
          gradient: const LinearGradient(colors: [Color(0xFF4A35E8), Color(0xFF2EC7FF)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x224A35E8), blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: Size.fromHeight(minHeight),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: enabled ? onPressed : null,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
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
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final foreground = gradient == null ? const Color(0xFF0D1530) : Colors.white;
    final muted = gradient == null ? const Color(0xFF667085) : Colors.white.withOpacity(0.84);

    return SurfaceCard(
      gradient: gradient,
      borderColor: gradient == null ? const Color(0xFFE5ECF5) : Colors.white.withOpacity(0.08),
      shadow: gradient == null
          ? const [BoxShadow(color: Color(0x0F0B1630), blurRadius: 24, offset: Offset(0, 12))]
          : const [BoxShadow(color: Color(0x260B1630), blurRadius: 26, offset: Offset(0, 16))],
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null)
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: gradient == null ? const Color(0xFFF0F4FF) : Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: gradient == null ? const Color(0xFF4A35E8) : Colors.white, size: 22),
                  ),
                const Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: gradient == null ? const Color(0xFF4A35E8) : Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = _hovered ? Colors.white : const Color(0xFFF8FAFF);
    final borderColor = _hovered ? const Color(0xFFB9C7FF) : const Color(0xFFE5ECF5);
    final shadow = _hovered
        ? [
            const BoxShadow(color: Color(0x1A4A35E8), blurRadius: 20, offset: Offset(0, 10)),
          ]
        : [
            const BoxShadow(color: Color(0x0D0B1630), blurRadius: 18, offset: Offset(0, 8)),
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: shadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: const Color(0xFF4A35E8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                      ),
                    ],
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
        colors: [Color(0xFF11162C), Color(0xFF232B58), Color(0xFF4A35E8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Colors.white.withOpacity(0.08),
      shadow: const [
        BoxShadow(color: Color(0x2B0B1630), blurRadius: 28, offset: Offset(0, 18)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(label: badgeLabel, color: Colors.white),
              const Spacer(),
              const Icon(Icons.sensors_rounded, color: Colors.white, size: 18),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          AspectRatio(
            aspectRatio: 1.32,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 18,
                    top: 18,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2EC7FF),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 18,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 102,
                          height: 102,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.10)),
                          ),
                          child: Icon(icon, color: Colors.white, size: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Camera preview ready',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Open the scanner, capture the plate, and continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.74),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GradientActionButton(
              label: actionLabel,
              icon: icon,
              onPressed: onAction,
            ),
          ),
        ],
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
            const BoxShadow(color: Color(0x1A4A35E8), blurRadius: 22, offset: Offset(0, 12)),
          ]
        : [
            const BoxShadow(color: Color(0x0D0B1630), blurRadius: 16, offset: Offset(0, 8)),
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
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        if (widget.statusLabel != null)
                          StatusBadge(label: widget.statusLabel!, color: widget.statusColor),
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
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.phoneNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF667085)),
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
                            color: widget.selected ? const Color(0xFF4A35E8) : const Color(0xFF667085),
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
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4A35E8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt preview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calculated automatically from the selected parking session.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF667085)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(paid ? Icons.verified_rounded : Icons.pending_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receiptNumber == null ? 'Waiting for confirmation' : 'Receipt $receiptNumber',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF667085)),
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
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12.5),
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
          style: const TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w600),
        ),
      );
    }

    final maxValue = points.fold<double>(0, (max, point) => math.max(max, point.value));
    final max = maxValue <= 0 ? 1.0 : maxValue;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in points)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          point.subLabel ?? '',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              width: double.infinity,
                              height: 150 * (point.value / max),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [barColor, accentColor],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          point.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF667085),
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
        );
      },
    );
  }
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
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
