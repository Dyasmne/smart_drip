import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Pump mode
enum PumpMode { auto, manual }

/// Pump Switch with smart irrigation features
class PumpSwitch extends StatefulWidget {
  final bool isOn;
  final bool isLoading;
  final bool isSaturated; // safety lock
  final PumpMode mode;

  final ValueChanged<bool>? onTogglePump;
  final ValueChanged<PumpMode>? onModeChanged;
  final VoidCallback? onManualOverride;
  final Future<void> Function(bool value)? onFirebaseSync;

  const PumpSwitch({
    super.key,
    required this.isOn,
    this.isLoading = false,
    this.isSaturated = false,
    this.mode = PumpMode.auto,
    this.onTogglePump,
    this.onModeChanged,
    this.onManualOverride,
    this.onFirebaseSync,
  });

  @override
  State<PumpSwitch> createState() => _PumpSwitchState();
}

class _PumpSwitchState extends State<PumpSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _waterController;

  @override
  void initState() {
    super.initState();

    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.isOn) {
      _waterController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PumpSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isOn && !_waterController.isAnimating) {
      _waterController.repeat();
    } else if (!widget.isOn) {
      _waterController.stop();
    }
  }

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
  }

  Future<void> _togglePump(bool value) async {
    if (widget.isSaturated) {
      HapticFeedback.heavyImpact();
      return; // safety lock
    }

    HapticFeedback.mediumImpact();

    widget.onTogglePump?.call(value);

    await widget.onFirebaseSync?.call(value);
  }

  void _toggleMode() {
    final newMode =
        widget.mode == PumpMode.auto ? PumpMode.manual : PumpMode.auto;

    HapticFeedback.selectionClick();
    widget.onModeChanged?.call(newMode);
  }

  void _manualOverride() {
    if (widget.isSaturated) return;

    HapticFeedback.heavyImpact();
    widget.onManualOverride?.call();

    // force manual mode
    widget.onModeChanged?.call(PumpMode.manual);
  }

  @override
  Widget build(BuildContext context) {
    final isOn = widget.isOn;
    final isBlocked = widget.isSaturated;

    return GestureDetector(
      onLongPress: _manualOverride,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16), // was 20
        decoration: BoxDecoration(
          gradient: isOn
              ? const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                )
              : LinearGradient(
                  colors: [Colors.grey.shade100, Colors.grey.shade200],
                ),
          borderRadius: BorderRadius.circular(18), // was 20
          boxShadow: [
            BoxShadow(
              color: isOn
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // WATER ANIMATION ICON
            Stack(
              alignment: Alignment.center,
              children: [
                if (isOn)
                  AnimatedBuilder(
                    animation: _waterController,
                    builder: (_, __) {
                      return Opacity(
                        opacity: 0.3,
                        child: Transform.scale(
                          scale: 1 + _waterController.value * 0.3,
                          child: Icon(
                            Icons.water_drop,
                            size: 52, // was 60
                            color: Colors.blueAccent,
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 48, // was 56
                  height: 48,
                  decoration: BoxDecoration(
                    color: isOn
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.water_drop,
                    color: isOn ? Colors.white : Colors.grey,
                    size: 24, // was 28
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // TEXT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Water Pump',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontSize: 13,
                      color: isOn ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),

                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOn ? Colors.greenAccent : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOn ? 'Running' : 'Stopped',
                        style: TextStyle(
                          fontSize: 11.5, // was 13
                          color: isOn
                              ? Colors.white.withOpacity(0.85)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // MODE INDICATOR
                  GestureDetector(
                    onTap: _toggleMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: widget.mode == PumpMode.auto
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.mode == PumpMode.auto ? "AUTO" : "MANUAL",
                        style: const TextStyle(
                          fontSize: 9.5, // was 11
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  if (isBlocked)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        "SOIL SATURATED (LOCKED)",
                        style: TextStyle(
                          fontSize: 9, // was 10
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // SWITCH
            if (widget.isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              Switch(
                value: isOn,
                onChanged: isBlocked ? null : _togglePump,
                activeColor: Colors.white,
                activeTrackColor: Colors.white.withOpacity(0.35),
              ),
          ],
        ),
      ),
    );
  }
}
