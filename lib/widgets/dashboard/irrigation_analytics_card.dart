import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// ============================================================
/// IRRIGATION ANALYTICS
/// ============================================================
///
/// Self-contained: listens to smartdrip/irrigation_logs by itself,
/// so no provider registration / app.dart changes are needed.
///
/// Log shape it understands:
///   { action: "AUTO ON" | "AUTO OFF" | "MANUAL ON" | "MANUAL OFF",
///     soil: number, timestamp: epoch-millis (number or digit string) }
///
/// Entries without a valid timestamp (or from before 2020, e.g. bogus
/// near-1970 stamps from failed NTP sync) are ignored.
/// ============================================================

class IrrigationAnalyticsCard extends StatefulWidget {
  /// Latest soil moisture (%), used for the next-watering estimate.
  final double currentMoisture;

  /// smartdrip/settings/lowThreshold (null if not loaded).
  final double? lowThreshold;

  final bool pumpOn;
  final bool isOnline;

  /// ASSUMPTION: pump flow rate in liters per minute. Change this to
  /// your pump's spec. Drip emitters usually deliver LESS than the
  /// pump's free-flow rate, so treat the water figure as an upper
  /// estimate.
  static const double pumpFlowLitersPerMinute = 2.0;

  const IrrigationAnalyticsCard({
    super.key,
    required this.currentMoisture,
    required this.lowThreshold,
    required this.pumpOn,
    required this.isOnline,
  });

  @override
  State<IrrigationAnalyticsCard> createState() =>
      _IrrigationAnalyticsCardState();
}

// ============================================================
// DATA MODELS
// ============================================================

class _Ev {
  final DateTime time;
  final bool isOn;
  final bool isAuto;
  final double soil;

  const _Ev(this.time, this.isOn, this.isAuto, this.soil);
}

class _Session {
  final _Ev on;
  final _Ev off;

  const _Session(this.on, this.off);

  Duration get duration => off.time.difference(on.time);
  double get gain => off.soil - on.soil;
  bool get isAuto => on.isAuto;
}

class _Analytics {
  final List<DateTime> days;
  final List<int> autoPerDay;
  final List<int> manualPerDay;
  final int auto7;
  final int manual7;
  final Duration runtime7;
  final double? avgGain;
  final Duration? avgDuration;
  final _Ev? lastOn;
  final _Ev? lastOff; // the OFF that closed lastOn (if any)
  final double? dryingRate; // % per hour

  const _Analytics({
    required this.days,
    required this.autoPerDay,
    required this.manualPerDay,
    required this.auto7,
    required this.manual7,
    required this.runtime7,
    required this.avgGain,
    required this.avgDuration,
    required this.lastOn,
    required this.lastOff,
    required this.dryingRate,
  });

  int get total7 => auto7 + manual7;
}

// ============================================================
// STATE
// ============================================================

class _IrrigationAnalyticsCardState extends State<IrrigationAnalyticsCard> {
  static const Color _autoColor = Color(0xFF43A047);
  static const Color _manualColor = Color(0xFF546E7A);
  static const Color _blue = Color(0xFF1E88E5);
  static const Color _textDark = Color(0xFF37474F);

  static const List<String> _dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  StreamSubscription<DatabaseEvent>? _sub;

  bool _loading = true;
  String? _error;
  List<_Ev> _events = [];

  @override
  void initState() {
    super.initState();

    _sub = FirebaseDatabase.instance
        .ref('smartdrip/irrigation_logs')
        .limitToLast(300)
        .onValue
        .listen(
      (event) {
        if (!mounted) return;

        setState(() {
          _events = _parseEvents(event.snapshot.value);
          _loading = false;
          _error = null;
        });
      },
      onError: (e) {
        if (!mounted) return;

        setState(() {
          _error = e.toString();
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ============================================================
  // PARSING
  // ============================================================

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;

    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    }

    final s = v.toString();
    final n = int.tryParse(s);

    if (n != null) {
      return DateTime.fromMillisecondsSinceEpoch(n);
    }

    return DateTime.tryParse(s);
  }

  List<_Ev> _parseEvents(dynamic raw) {
    if (raw == null || raw is! Map) return [];

    final out = <_Ev>[];

    raw.forEach((key, value) {
      if (value is! Map) return;

      final time = _parseTs(value['timestamp']);

      if (time == null || time.year < 2020) return;

      final action = (value['action'] ?? '').toString().toUpperCase();

      final bool isOff = action.contains('OFF');
      final bool isOn = !isOff && action.contains('ON');

      if (!isOn && !isOff) return;

      final soil = num.tryParse((value['soil'] ?? '').toString());

      out.add(
        _Ev(
          time.toLocal(),
          isOn,
          action.startsWith('AUTO'),
          soil?.toDouble() ?? double.nan,
        ),
      );
    });

    out.sort((a, b) => a.time.compareTo(b.time));

    return out;
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  _Analytics _compute(List<_Ev> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final days = List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );

    final autoPerDay = List<int>.filled(7, 0);
    final manualPerDay = List<int>.filled(7, 0);

    // ---- sessions: an ON immediately followed by an OFF -------
    final sessions = <_Session>[];

    for (var i = 0; i < events.length - 1; i++) {
      final a = events[i];
      final b = events[i + 1];

      if (a.isOn && !b.isOn) {
        final s = _Session(a, b);

        // ignore impossible / unclosed sessions (missing OFF)
        if (!s.duration.isNegative && s.duration.inHours < 6) {
          sessions.add(s);
        }
      }
    }

    // ---- counts per day (every ON event = one irrigation) -----
    for (final e in events) {
      if (!e.isOn) continue;

      final d = DateTime(e.time.year, e.time.month, e.time.day);
      final idx = days.indexWhere((x) => x == d);

      if (idx < 0) continue;

      if (e.isAuto) {
        autoPerDay[idx]++;
      } else {
        manualPerDay[idx]++;
      }
    }

    final windowStart = days.first;

    final s7 = sessions.where((s) => !s.on.time.isBefore(windowStart)).toList();

    var runtime = Duration.zero;
    for (final s in s7) {
      runtime += s.duration;
    }

    final autoS = s7.where((s) => s.isAuto && !s.gain.isNaN).toList();

    double? avgGain;
    Duration? avgDuration;

    if (autoS.isNotEmpty) {
      avgGain =
          autoS.map((s) => s.gain).reduce((a, b) => a + b) / autoS.length;

      final totalMs = autoS
          .map((s) => s.duration.inMilliseconds)
          .reduce((a, b) => a + b);

      avgDuration = Duration(milliseconds: totalMs ~/ autoS.length);
    }

    // ---- last irrigation ----------------------------------------
    _Ev? lastOn;
    _Ev? lastOff;

    for (var i = events.length - 1; i >= 0; i--) {
      if (events[i].isOn) {
        lastOn = events[i];

        if (i + 1 < events.length && !events[i + 1].isOn) {
          lastOff = events[i + 1];
        }

        break;
      }
    }

    // ---- drying rate (% per hour) between irrigations -----------
    final rates = <double>[];

    for (var i = 0; i < sessions.length - 1; i++) {
      final a = sessions[i];
      final b = sessions[i + 1];

      final gapHours =
          b.on.time.difference(a.off.time).inMinutes / 60.0;

      final drop = a.off.soil - b.on.soil;

      if (gapHours >= 0.25 && gapHours <= 72 && drop > 0 && !drop.isNaN) {
        rates.add(drop / gapHours);
      }
    }

    double? dryingRate;

    if (rates.isNotEmpty) {
      final recent = rates.length > 5 ? rates.sublist(rates.length - 5) : rates;

      dryingRate = recent.reduce((a, b) => a + b) / recent.length;
    }

    return _Analytics(
      days: days,
      autoPerDay: autoPerDay,
      manualPerDay: manualPerDay,
      auto7: autoPerDay.reduce((a, b) => a + b),
      manual7: manualPerDay.reduce((a, b) => a + b),
      runtime7: runtime,
      avgGain: avgGain,
      avgDuration: avgDuration,
      lastOn: lastOn,
      lastOff: lastOff,
      dryingRate: dryingRate,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return _card(
        child: Text(
          "Can't load irrigation analytics.\n$_error",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    if (_events.isEmpty) {
      return _card(
        child: Column(
          children: const [
            Icon(Icons.insights, color: Colors.grey, size: 34),
            SizedBox(height: 8),
            Text(
              "No irrigation events yet",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Analytics appear after the pump runs at least once.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final a = _compute(_events);

    return Column(
      children: [
        _insightCard(a),
        const SizedBox(height: 14),
        _metricsCard(a),
        const SizedBox(height: 14),
        _weeklyCard(a),
      ],
    );
  }

  // ============================================================
  // NEXT WATERING + LAST IRRIGATION
  // ============================================================

  Widget _insightCard(_Analytics a) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Irrigation Insights",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _textDark,
            ),
          ),

          const SizedBox(height: 14),

          // ---- next watering estimate ------------------------
          _insightRow(
            icon: Icons.schedule,
            color: _blue,
            title: "Next watering (estimate)",
            value: _nextWatering(a),
          ),

          const Divider(height: 26),

          // ---- last irrigation -------------------------------
          _insightRow(
            icon: Icons.history,
            color: _autoColor,
            title: "Last irrigation",
            value: _lastIrrigationTitle(a),
            subtitle: _lastIrrigationDetail(a),
          ),
        ],
      ),
    );
  }

  Widget _insightRow({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 12.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _nextWatering(_Analytics a) {
    if (widget.pumpOn) return "Irrigating now";

    if (!widget.isOnline) return "Device offline";

    final low = widget.lowThreshold;

    if (low == null) return "Threshold not set";

    if (widget.currentMoisture <= low) return "Due now";

    final rate = a.dryingRate;

    if (rate == null || rate <= 0) {
      return "Need more irrigation cycles";
    }

    final hours = (widget.currentMoisture - low) / rate;

    return "in ~${_fmtHours(hours)}";
  }

  String _lastIrrigationTitle(_Analytics a) {
    final on = a.lastOn;

    if (on == null) return "None yet";

    return "${on.isAuto ? 'Auto' : 'Manual'} · ${_fmtWhen(on.time)}";
  }

  String? _lastIrrigationDetail(_Analytics a) {
    final on = a.lastOn;

    if (on == null) return null;

    final off = a.lastOff;

    final startSoil =
        on.soil.isNaN ? "--" : "${on.soil.toStringAsFixed(0)}%";

    if (off == null) {
      return widget.pumpOn
          ? "Started at $startSoil · still running"
          : "Started at $startSoil";
    }

    final endSoil =
        off.soil.isNaN ? "--" : "${off.soil.toStringAsFixed(0)}%";

    final dur = off.time.difference(on.time);

    if (dur.isNegative || dur.inHours >= 6) {
      return "$startSoil → $endSoil";
    }

    return "$startSoil → $endSoil · ${_fmtDuration(dur)}";
  }

  // ============================================================
  // METRICS GRID
  // ============================================================

  Widget _metricsCard(_Analytics a) {
    final minutes = a.runtime7.inSeconds / 60.0;
    final liters = minutes * IrrigationAnalyticsCard.pumpFlowLitersPerMinute;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Last 7 Days",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _textDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _metric(
                  Icons.water_drop,
                  _blue,
                  "${a.total7}",
                  "Irrigations",
                  "${a.auto7} auto · ${a.manual7} manual",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  Icons.timer,
                  const Color(0xFFFB8C00),
                  a.runtime7 == Duration.zero
                      ? "--"
                      : _fmtDuration(a.runtime7),
                  "Pump runtime",
                  "total ON time",
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _metric(
                  Icons.opacity,
                  const Color(0xFF00897B),
                  a.runtime7 == Duration.zero
                      ? "--"
                      : "~${liters.toStringAsFixed(liters < 10 ? 1 : 0)} L",
                  "Water used (est.)",
                  "at ${IrrigationAnalyticsCard.pumpFlowLitersPerMinute.toStringAsFixed(1)} L/min",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  Icons.trending_up,
                  _autoColor,
                  a.avgGain == null
                      ? "--"
                      : "+${a.avgGain!.toStringAsFixed(1)}%",
                  "Avg gain / cycle",
                  "auto irrigation",
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _metric(
                  Icons.hourglass_bottom,
                  const Color(0xFF8E24AA),
                  a.avgDuration == null ? "--" : _fmtDuration(a.avgDuration!),
                  "Avg duration",
                  "per auto cycle",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  Icons.wb_sunny,
                  const Color(0xFFE53935),
                  a.dryingRate == null
                      ? "--"
                      : "${a.dryingRate!.toStringAsFixed(1)}%/h",
                  "Drying rate",
                  "between irrigations",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(
    IconData icon,
    Color color,
    String value,
    String label,
    String hint,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Text(
            hint,
            style: const TextStyle(color: Colors.grey, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WEEKLY BAR CHART
  // ============================================================

  Widget _weeklyCard(_Analytics a) {
    const double chartHeight = 90;

    var maxCount = 1;

    for (var i = 0; i < 7; i++) {
      maxCount = math.max(maxCount, a.autoPerDay[i] + a.manualPerDay[i]);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Irrigations per Day",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _textDark,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final auto = a.autoPerDay[i];
              final manual = a.manualPerDay[i];
              final total = auto + manual;
              final isToday = a.days[i] == today;

              double h(int count) => count == 0
                  ? 0
                  : (chartHeight * count / maxCount).clamp(6.0, chartHeight);

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      total > 0 ? "$total" : "",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: chartHeight,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: total == 0
                            ? Container(
                                width: 18,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (manual > 0)
                                      Container(
                                        width: 18,
                                        height: h(manual),
                                        color: _manualColor,
                                      ),
                                    if (auto > 0)
                                      Container(
                                        width: 18,
                                        height: h(auto),
                                        color: _autoColor,
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _dayNames[a.days[i].weekday - 1],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.w500,
                        color: isToday ? _textDark : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              _legendDot(_autoColor, "Auto"),
              const SizedBox(width: 16),
              _legendDot(_manualColor, "Manual"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
        ),
      ],
    );
  }

  // ============================================================
  // FORMATTERS
  // ============================================================

  String _fmtClock(DateTime dt) {
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;

    return '$hour12:$minute $period';
  }

  String _fmtWhen(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);

    final diff = today.difference(day).inDays;

    final String label;

    if (diff == 0) {
      label = "Today";
    } else if (diff == 1) {
      label = "Yesterday";
    } else {
      label = "${_monthNames[dt.month - 1]} ${dt.day}";
    }

    return "$label, ${_fmtClock(dt)}";
  }

  String _fmtDuration(Duration d) {
    if (d.inSeconds < 60) return "${d.inSeconds} s";

    if (d.inMinutes < 60) return "${d.inMinutes} min";

    final h = d.inHours;
    final m = d.inMinutes % 60;

    return m == 0 ? "$h h" : "$h h $m min";
  }

  String _fmtHours(double hours) {
    if (hours >= 48) return "${(hours / 24).round()} days";

    if (hours >= 1) {
      final h = hours.floor();
      final m = ((hours - h) * 60).round();

      return m == 0 ? "$h h" : "$h h $m min";
    }

    return "${math.max(1, (hours * 60).round())} min";
  }

  // ============================================================
  // SHARED CARD STYLE
  // ============================================================

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      child: child,
    );
  }
}