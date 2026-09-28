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

  const ControlScreen({
    super.key,
    this.isTab = false,
  });

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // ================= GENERAL STATE =================

  bool _hasChanges = false;
  bool _isSaving = false;

  // ================= THRESHOLD SETTINGS =================

  double _lowThreshold = 30;
  double _highThreshold = 45;
  bool _autoIrrigation = true;

  // ================= PENDING PUMP MODE =================
  //
  // BUG FIX: PumpSwitch's AUTO/MANUAL chip previously called
  // onModeChanged, which only set _hasChanges = true without
  // storing which mode was picked. _saveSettings() then computed
  // "localMode" fresh from irrigation.irrigationMode (the
  // Provider's last-known value, unchanged since nothing had
  // written to Firebase yet) - so tapping AUTO/MANUAL had no
  // effect on what actually got saved; Save just re-sent whatever
  // mode was already live.
  //
  // _pendingMode now captures the user's uncommitted choice. null
  // means "no pending change, trust the Provider's current value".
  PumpMode? _pendingMode;

  // ================= INIT =================

  @override
  void initState() {
    super.initState();
    _loadThresholdSettings();
  }

  // ================= FIREBASE =================

  Future<void> _loadThresholdSettings() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref("smartdrip/settings").get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(
          snapshot.value as Map,
        );

        if (!mounted) return;

        setState(() {
          _lowThreshold = (data["lowThreshold"] ?? 30).toDouble();

          _highThreshold = (data["highThreshold"] ?? 45).toDouble();

          _autoIrrigation = data["autoIrrigation"] ?? true;
        });
      } else {
        // Create default settings if none exist yet.
        await _saveThresholdSettings();
      }
    } catch (e) {
      debugPrint(
        "Failed to load threshold settings: $e",
      );
    }
  }

  Future<void> _saveThresholdSettings() async {
    await FirebaseDatabase.instance.ref("smartdrip/settings").update({
      "lowThreshold": _lowThreshold.round(),
      "highThreshold": _highThreshold.round(),
      "autoIrrigation": _autoIrrigation,
      "lastUpdated": ServerValue.timestamp,
      "source": "app",
    });
  }

  // ================= PUMP FIREBASE =================

  Future<void> _updateFirebase({
    required bool pump,
    required PumpMode mode,
  }) async {
    final ref = FirebaseDatabase.instance.ref("smartdrip");

    await ref.update({
      "pump": {
        "state": pump ? "ON" : "OFF",
        "mode": mode == PumpMode.auto ? "auto" : "manual",
      },
      "lastUpdated": ServerValue.timestamp,
      "source": "app",
    });
  }

  // ================= SAVE ALL SETTINGS =================

  Future<void> _saveSettings(
    IrrigationProvider provider,
    bool pump,
    PumpMode mode,
  ) async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Save pump and mode
      await _updateFirebase(
        pump: pump,
        mode: mode,
      );

      // Save threshold settings
      await _saveThresholdSettings();

      // Update Provider mode
      await provider.setIrrigationMode(
        mode == PumpMode.auto ? IrrigationMode.auto : IrrigationMode.manual,
      );

      // Only manually control pump in manual mode
      if (mode == PumpMode.manual) {
        await provider.setPumpState(pump);
      }

      if (!mounted) return;

      setState(() {
        _hasChanges = false;

        // The Provider now reflects what we just saved, so drop the
        // pending override and let the UI trust the Provider again.
        _pendingMode = null;
      });

      AppHelpers.showSnackBar(
        context,
        "Settings synced successfully ✔",
      );
    } catch (e) {
      if (!mounted) return;

      AppHelpers.showSnackBar(
        context,
        "Sync error: $e",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ================= LOW THRESHOLD =================

  void _changeLowThreshold(double value) {
    setState(() {
      _lowThreshold = value;

      // Low threshold must always be lower
      // than the high threshold.
      if (_lowThreshold >= _highThreshold) {
        _lowThreshold = _highThreshold - 1;
      }

      if (_lowThreshold < 0) {
        _lowThreshold = 0;
      }

      _hasChanges = true;
    });
  }

  // ================= HIGH THRESHOLD =================

  void _changeHighThreshold(double value) {
    setState(() {
      _highThreshold = value;

      // High threshold must always be higher
      // than the low threshold.
      if (_highThreshold <= _lowThreshold) {
        _highThreshold = _lowThreshold + 1;
      }

      if (_highThreshold > 100) {
        _highThreshold = 100;
      }

      _hasChanges = true;
    });
  }

  // ================= BUILD =================

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

          final PumpMode providerMode =
              irrigation.irrigationMode == IrrigationMode.auto
                  ? PumpMode.auto
                  : PumpMode.manual;

          // Trust the user's uncommitted tap (if any) over the
          // Provider's last-synced value, so the chip and the
          // eventual Save actually reflect what was tapped.
          final PumpMode localMode = _pendingMode ?? providerMode;

          final bool localPumpOn = irrigation.isPumpOn;

          final content = SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // =====================================================
                // MOISTURE CARD
                // =====================================================

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.moss.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: AppColors.moss,
                        size: 20,
                      ),
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
                              style: AppTextStyles.body2.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              AppFormatters.formatMoisture(
                                moisture,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.dataMedium.copyWith(
                                fontSize: 18,
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
                          style: AppTextStyles.body2.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // =====================================================
                // PUMP SWITCH
                // =====================================================

                PumpSwitch(
                  isOn: localPumpOn,
                  isLoading: irrigation.isLoading,
                  isSaturated: isSaturated,
                  mode: localMode,
                  onTogglePump: (val) {
                    setState(() {
                      _hasChanges = true;
                    });
                  },
                  onModeChanged: (mode) {
                    setState(() {
                      _pendingMode = mode;
                      _hasChanges = true;
                    });
                  },
                  onManualOverride: () {
                    setState(() {
                      _pendingMode = PumpMode.manual;
                      _hasChanges = true;
                    });
                  },
                  onFirebaseSync: (val) async {
                    await FirebaseDatabase.instance
                        .ref("smartdrip/pump")
                        .update({
                      "state": val ? "ON" : "OFF",
                      "mode": "manual",
                    });

                    // The pump switch forces manual mode on the
                    // Firebase side (matches the ESP32's manual
                    // override behavior) - reflect that locally too,
                    // so the AUTO/MANUAL chip doesn't keep showing
                    // AUTO after a manual pump toggle.
                    if (mounted) {
                      setState(() {
                        _pendingMode = PumpMode.manual;
                      });
                    }
                  },
                ),

                const SizedBox(height: 18),

                // =====================================================
                // IRRIGATION THRESHOLD SETTINGS
                // =====================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.moss.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // -----------------------------
                      // HEADER
                      // -----------------------------

                      Row(
                        children: [
                          Icon(
                            Icons.tune,
                            color: AppColors.moss,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Irrigation Settings",
                              style: AppTextStyles.dataMedium.copyWith(
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "Set when automatic irrigation "
                        "should start and stop.",
                        style: AppTextStyles.body2.copyWith(
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // =================================================
                      // AUTOMATIC IRRIGATION
                      // =================================================

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          "Automatic Irrigation",
                        ),
                        subtitle: const Text(
                          "Automatically control the water pump",
                        ),
                        value: _autoIrrigation,
                        activeColor: AppColors.moss,
                        onChanged: (value) {
                          setState(() {
                            _autoIrrigation = value;

                            // Keep the pump-card AUTO/MANUAL chip in
                            // sync with this switch, since the ESP32
                            // requires BOTH smartdrip/pump/mode=="auto"
                            // AND smartdrip/settings/autoIrrigation==true
                            // before it will run automatic irrigation.
                            _pendingMode =
                                value ? PumpMode.auto : PumpMode.manual;

                            _hasChanges = true;
                          });
                        },
                      ),

                      const Divider(),

                      const SizedBox(height: 8),

                      // =================================================
                      // LOW THRESHOLD
                      // =================================================

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              "Start Irrigation",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            "${_lowThreshold.round()}%",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.moss,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "Pump turns ON when soil moisture "
                        "reaches this level.",
                        style: AppTextStyles.body2.copyWith(
                          fontSize: 11,
                        ),
                      ),

                      Slider(
                        value: _lowThreshold,
                        min: 0,
                        max: 99,
                        divisions: 99,
                        activeColor: AppColors.moss,
                        label: "${_lowThreshold.round()}%",
                        onChanged: _changeLowThreshold,
                      ),

                      const SizedBox(height: 10),

                      // =================================================
                      // HIGH THRESHOLD
                      // =================================================

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              "Stop Irrigation",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            "${_highThreshold.round()}%",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.moss,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "Pump turns OFF when soil moisture "
                        "reaches this level.",
                        style: AppTextStyles.body2.copyWith(
                          fontSize: 11,
                        ),
                      ),

                      Slider(
                        value: _highThreshold,
                        min: 1,
                        max: 100,
                        divisions: 99,
                        activeColor: AppColors.moss,
                        label: "${_highThreshold.round()}%",
                        onChanged: _changeHighThreshold,
                      ),

                      const SizedBox(height: 8),

                      // =================================================
                      // CURRENT SETTINGS INFO
                      // =================================================

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.moss.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.moss,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Pump ON below "
                                "${_lowThreshold.round()}% "
                                "and OFF at "
                                "${_highThreshold.round()}%.",
                                style: AppTextStyles.body2.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // =====================================================
                // SAVE BUTTON
                // =====================================================

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

                // =====================================================
                // QUICK TOGGLE
                // =====================================================

                if (localMode == PumpMode.manual)
                  CustomButton(
                    label: localPumpOn ? "Turn OFF" : "Turn ON",
                    variant: ButtonVariant.secondary,
                    onPressed: () async {
                      await irrigation.togglePump();

                      if (mounted) {
                        setState(() {
                          _hasChanges = true;
                        });
                      }
                    },
                  ),
              ],
            ),
          );

          // ===========================================================
          // TAB MODE
          // ===========================================================

          if (widget.isTab) {
            return Column(
              children: [
                const TabHeader(
                  title: "Control",
                ),
                Expanded(
                  child: content,
                ),
              ],
            );
          }

          // ===========================================================
          // DIRECT ROUTE
          // ===========================================================

          return content;
        },
      ),
    );
  }
}