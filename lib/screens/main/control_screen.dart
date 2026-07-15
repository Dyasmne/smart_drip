import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../providers/irrigation_provider.dart';
import '../../providers/sensor_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/helpers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/common/custom_appbar.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/tab_header.dart';
import '../../widgets/dashboard/pump_switch.dart';

class ControlScreen extends StatefulWidget {
  final bool isTab;
  const ControlScreen({super.key, this.isTab = false});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool _hasChanges = false;
  bool _isSaving = false;

  Future<void> _updateFirebase({
    required bool pump,
    required PumpMode mode,
  }) async {
    final ref = FirebaseDatabase.instance.ref("smartdrip");

    await ref.update({
      "pump": pump ? "ON" : "OFF",
      "mode": mode == PumpMode.auto ? "auto" : "manual",
      "lastUpdated": ServerValue.timestamp,
      "source": "app",
    });
  }

  Future<void> _saveSettings(
      IrrigationProvider provider, bool pump, PumpMode mode) async {
    setState(() => _isSaving = true);

    try {
      await _updateFirebase(pump: pump, mode: mode);

      await provider.setIrrigationMode(
        mode == PumpMode.auto ? IrrigationMode.auto : IrrigationMode.manual,
      );

      if (mode == PumpMode.manual) {
        await provider.setPumpState(pump);
      }

      if (mounted) {
        AppHelpers.showSnackBar(context, "Settings synced successfully ✔");
      }

      setState(() => _hasChanges = false);
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          "Sync error: $e",
          isError: true,
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isTab
          ? null
          : const CustomAppBar(
              title: 'Control',
              showBackButton: true,
            ),
      body: Consumer2<IrrigationProvider, SensorProvider>(
        builder: (context, irrigation, sensor, _) {
          final double moisture = sensor.moisture;
          final bool isSaturated = moisture >= 90;

          final PumpMode localMode =
              irrigation.irrigationMode == IrrigationMode.auto
                  ? PumpMode.auto
                  : PumpMode.manual;

          final bool localPumpOn = irrigation.isPumpOn;

          final content = SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ================= MOISTURE CARD =================
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.moss.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop, color: AppColors.moss, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Soil Moisture",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body2.copyWith(fontSize: 12),
                            ),
                            Text(
                              AppFormatters.formatMoisture(moisture),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.dataMedium.copyWith(
                                fontSize: 18, // was raw 22
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          sensor.moistureStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.body2.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ================= PUMP SWITCH =================
                PumpSwitch(
                  isOn: localPumpOn,
                  isLoading: irrigation.isLoading,
                  isSaturated: isSaturated,
                  mode: localMode,
                  onTogglePump: (val) {
                    setState(() => _hasChanges = true);
                  },
                  onModeChanged: (mode) {
                    setState(() => _hasChanges = true);
                  },
                  onManualOverride: () {
                    setState(() => _hasChanges = true);
                  },
                  onFirebaseSync: (val) async {
                    await FirebaseDatabase.instance.ref("smartdrip").update({
                      "pump": val ? "ON" : "OFF",
                      "mode": "manual",
                    });
                  },
                ),

                const SizedBox(height: 18),

                // ================= SAVE BUTTON =================
                CustomButton(
                  label: _hasChanges ? "Save Settings" : "Saved",
                  isLoading: _isSaving,
                  onPressed: _hasChanges
                      ? () => _saveSettings(
                            irrigation,
                            localPumpOn,
                            localMode,
                          )
                      : null,
                ),

                const SizedBox(height: 10),

                // ================= QUICK TOGGLE =================
                if (localMode == PumpMode.manual)
                  CustomButton(
                    label: localPumpOn ? "Turn OFF" : "Turn ON",
                    variant: ButtonVariant.secondary,
                    onPressed: () async {
                      await irrigation.togglePump();

                      setState(() => _hasChanges = true);
                    },
                  ),
              ],
            ),
          );

          // ================= TAB MODE (bottom nav) =================
          if (widget.isTab) {
            return Column(
              children: [
                const TabHeader(title: "Control"),
                Expanded(child: content),
              ],
            );
          }

          // ================= DIRECT ROUTE (pushed screen) =================
          return content;
        },
      ),
    );
  }
}
