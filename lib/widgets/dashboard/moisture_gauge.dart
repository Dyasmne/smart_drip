import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';

/// Animated circular gauge showing soil moisture percentage (SmartDrip PRO)
class MoistureGauge extends StatefulWidget {
  final double moisture;
  final double size;
  final bool showLabel;

  const MoistureGauge({
    super.key,
    required this.moisture,
    this.size = 200,
    this.showLabel = true,
  });

  @override
  State<MoistureGauge> createState() => _MoistureGaugeState();
}

class _MoistureGaugeState extends State<MoistureGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  double _previousMoisture = 0;

  @override
  void initState() {
    super.initState();

    _previousMoisture = widget.moisture;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animation = Tween<double>(
      begin: 0,
      end: widget.moisture.clamp(0, 100) / 100,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(MoistureGauge oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.moisture != widget.moisture) {
      final newValue = widget.moisture.clamp(0, 100) / 100;

      _animation = Tween<double>(
        begin: _previousMoisture.clamp(0, 100) / 100,
        end: newValue,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ),
      );

      _controller
        ..reset()
        ..forward();

      _previousMoisture = widget.moisture;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value.clamp(0.0, 1.0);
        final percent = value * 100;

        final color = AppHelpers.getMoistureColor(percent);
        final icon = AppHelpers.getMoistureIcon(percent);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Gauge arc
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaugePainter(
                  value: value,
                  backgroundColor: color.withOpacity(0.12),
                  foregroundColor: color,
                  strokeWidth: widget.size * 0.07,
                ),
              ),

              // Center content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: widget.size * 0.13,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: widget.size * 0.18,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  if (widget.showLabel) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Moisture',
                      style: TextStyle(
                        fontSize: widget.size * 0.07,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for gauge arc
class _GaugePainter extends CustomPainter {
  final double value;
  final Color backgroundColor;
  final Color foregroundColor;
  final double strokeWidth;

  _GaugePainter({
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 270° arc (starts bottom-left)
    const startAngle = 3 * math.pi / 4;
    const sweepAngle = 3 * math.pi / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, bgPaint);

    // Foreground arc
    if (value > 0) {
      final fgPaint = Paint()
        ..color = foregroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * value.clamp(0.0, 1.0),
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}