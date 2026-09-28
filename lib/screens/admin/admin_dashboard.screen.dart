import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import 'admin_users_screen.dart';
import 'admin_activity_logs_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadAdminData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthProvider>().logout();

              if (!context.mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Consumer<AdminProvider>(
        builder: (context, admin, child) {
          if (admin.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (admin.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      admin.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        admin.loadAdminData();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: admin.loadAdminData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // ==================================================
                // HEADER
                // ==================================================

                const Text(
                  'System Diagnostics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Real-time telemetry, user records, and irrigation event logs',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 24),

                // ==================================================
                // SUMMARY CARDS
                // ==================================================

                _buildSummaryCard(
                  context,
                  icon: Icons.people_outline,
                  title: 'Registered Users',
                  value: admin.totalUsers.toString(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AdminUsersScreen(),
                      ),
                    );
                  },
                ),

                _buildSummaryCard(
                  context,
                  icon: Icons.login,
                  title: 'Total Logins',
                  value: admin.totalLogins.toString(),
                ),

                _buildSummaryCard(
                  context,
                  icon: Icons.water_drop_outlined,
                  title: 'Irrigation Events',
                  value:
                      admin.totalIrrigationEvents.toString(),
                ),

                _buildSummaryCard(
                  context,
                  icon: Icons.history,
                  title: 'Activity Logs',
                  value:
                      admin.activityLogs.length.toString(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AdminActivityLogsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // ==================================================
                // PUMP STATUS
                // ==================================================

                _buildStatusCard(
                  context,
                  title: 'Current Pump Status',
                  value:
                      _pumpStateLabel(admin.pumpStatus),
                  caption:
                      _pumpModeLabel(admin.pumpStatus),
                  icon: Icons.water_drop_outlined,
                  accent: _pumpIsOn(admin.pumpStatus)
                      ? Colors.blue.shade600
                      : Colors.grey.shade500,
                ),

                const SizedBox(height: 12),

                // ==================================================
                // SYSTEM STATUS
                // ==================================================

                _buildStatusCard(
                  context,
                  title: 'System Status',
                  value: admin.systemStatusLabel,
                  caption:
                      _systemCaption(admin.systemStatus),
                  icon:
                      Icons.settings_input_component_outlined,
                  accent: admin.isSystemOnline
                      ? Colors.green.shade600
                      : Colors.red.shade400,
                ),

                const SizedBox(height: 12),

                // ==================================================
                // SYSTEM CONFIGURATION
                // ==================================================

                _buildSystemConfiguration(admin),

                const SizedBox(height: 24),

                // ==================================================
                // IRRIGATION SUMMARY
                // ==================================================

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Irrigation Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildMiniStat(
                                icon: Icons.autorenew,
                                label: 'Automatic',
                                value: admin
                                    .automaticIrrigationCount
                                    .toString(),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: _buildMiniStat(
                                icon:
                                    Icons.touch_app_outlined,
                                label: 'Manual',
                                value: admin
                                    .manualIrrigationCount
                                    .toString(),
                              ),
                            ),
                          ],
                        ),

                        if (admin
                                .unclassifiedIrrigationCount >
                            0) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${admin.unclassifiedIrrigationCount} event(s) could not be classified.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ==================================================
                // SOIL MOISTURE
                // ==================================================

                _buildSoilMoistureCard(admin),

                const SizedBox(height: 30),

                // ==================================================
                // ANALYTICS
                // ==================================================

                const Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'SmartDrip monitoring and activity analysis',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 16),

                // Soil
                _buildSoilMoistureChart(admin),

                const SizedBox(height: 16),

                // Pump
                _buildPumpUsageChart(admin),

                const SizedBox(height: 16),

                // Auto vs Manual
                _buildIrrigationModeChart(admin),

                const SizedBox(height: 16),

                // Events
                _buildIrrigationEventsChart(admin),

                const SizedBox(height: 16),

                // Activity
                _buildActivitySummary(admin),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==============================================================
  // SYSTEM CONFIGURATION
  // ==============================================================

  Widget _buildSystemConfiguration(
    AdminProvider admin,
  ) {
    final system = admin.systemStatus;

    if (system is! Map || system.isEmpty) {
      return const SizedBox.shrink();
    }

    final mode =
        system['mode']?.toString() ?? '—';

    final autoIrrigation =
        system['autoIrrigation'];

    final lowThreshold =
        system['lowThreshold'];

    final highThreshold =
        system['highThreshold'];

    final timestamp =
        system['timestamp'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'System Configuration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            _buildInfoRow(
              Icons.settings,
              'Mode',
              _capitalize(mode),
            ),

            _buildInfoRow(
              Icons.autorenew,
              'Auto Irrigation',
              _formatBoolean(autoIrrigation),
            ),

            _buildInfoRow(
              Icons.water_drop_outlined,
              'Low Threshold',
              lowThreshold != null
                  ? '$lowThreshold%'
                  : '—',
            ),

            _buildInfoRow(
              Icons.water_drop,
              'High Threshold',
              highThreshold != null
                  ? '$highThreshold%'
                  : '—',
            ),

            if (timestamp != null)
              _buildInfoRow(
                Icons.access_time,
                'Last Update',
                _formatTimestamp(timestamp),
              ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // SOIL MOISTURE CARD
  // ==============================================================

  Widget _buildSoilMoistureCard(
    AdminProvider admin,
  ) {
    final value =
        _soilMoistureValue(admin.sensorData);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.grass,
              size: 32,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Soil Moisture',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    value == null
                        ? 'No data'
                        : '${value.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    _soilMoistureCondition(
                      admin.sensorData,
                    ),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // SOIL MOISTURE CHART
  // ==============================================================

  Widget _buildSoilMoistureChart(
    AdminProvider admin,
  ) {
    final data = admin.soilMoistureData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Soil Moisture Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Recorded soil moisture readings',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            if (data.length < 2)
              _buildNoDataMessage(
                'Not enough soil moisture data yet.',
              )
            else
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,

                    gridData:
                        const FlGridData(show: true),

                    titlesData:
                        const FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: false,
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: false,
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: false,
                        ),
                      ),
                    ),

                    borderData:
                        FlBorderData(show: true),

                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        barWidth: 3,
                        spots: List.generate(
                          data.length,
                          (index) {
                            return FlSpot(
                              index.toDouble(),
                              _asDouble(
                                data[index]['moisture'] ??
                                    data[index]['soil'] ??
                                    data[index]['value'],
                              ),
                            );
                          },
                        ),
                        dotData:
                            const FlDotData(
                          show: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // PUMP USAGE
  // ==============================================================

  Widget _buildPumpUsageChart(
    AdminProvider admin,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Pump Usage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Recorded pump ON and OFF activities',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: _pumpMaxY(admin),

                  gridData:
                      const FlGridData(show: true),

                  borderData:
                      FlBorderData(show: false),

                  titlesData: FlTitlesData(
                    topTitles:
                        const AxisTitles(
                      sideTitles:
                          SideTitles(
                        showTitles: false,
                      ),
                    ),

                    rightTitles:
                        const AxisTitles(
                      sideTitles:
                          SideTitles(
                        showTitles: false,
                      ),
                    ),

                    leftTitles:
                        const AxisTitles(
                      sideTitles:
                          SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                      ),
                    ),

                    bottomTitles:
                        AxisTitles(
                      sideTitles:
                          SideTitles(
                        showTitles: true,
                        getTitlesWidget:
                            (value, meta) {
                          if (value == 0) {
                            return const Padding(
                              padding:
                                  EdgeInsets.only(
                                top: 8,
                              ),
                              child:
                                  Text('ON'),
                            );
                          }

                          if (value == 1) {
                            return const Padding(
                              padding:
                                  EdgeInsets.only(
                                top: 8,
                              ),
                              child:
                                  Text('OFF'),
                            );
                          }

                          return const SizedBox();
                        },
                      ),
                    ),
                  ),

                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: admin
                              .pumpOnCount
                              .toDouble(),
                          width: 40,
                          borderRadius:
                              BorderRadius.circular(
                            6,
                          ),
                        ),
                      ],
                    ),

                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: admin
                              .pumpOffCount
                              .toDouble(),
                          width: 40,
                          borderRadius:
                              BorderRadius.circular(
                            6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // AUTOMATIC VS MANUAL
  // ==============================================================

  Widget _buildIrrigationModeChart(
    AdminProvider admin,
  ) {
    final automatic =
        admin.automaticIrrigationCount;

    final manual =
        admin.manualIrrigationCount;

    final total =
        automatic + manual;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Automatic vs Manual Irrigation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Distribution of irrigation events by mode',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            if (total == 0)
              _buildNoDataMessage(
                'No irrigation mode data yet.',
              )
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 45,
                    sections: [
                      if (automatic > 0)
                        PieChartSectionData(
                          value:
                              automatic.toDouble(),
                          title:
                              '${((automatic / total) * 100).round()}%',
                          radius: 75,
                          color:
                              Colors.green.shade600,
                          titleStyle:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                      if (manual > 0)
                        PieChartSectionData(
                          value:
                              manual.toDouble(),
                          title:
                              '${((manual / total) * 100).round()}%',
                          radius: 75,
                          color:
                              Colors.orange.shade600,
                          titleStyle:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  _buildLegendItem(
                    'Automatic',
                    automatic,
                    Colors.green.shade600,
                  ),

                  const SizedBox(width: 24),

                  _buildLegendItem(
                    'Manual',
                    manual,
                    Colors.orange.shade600,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // IRRIGATION EVENTS OVER TIME
  // ==============================================================

  Widget _buildIrrigationEventsChart(
    AdminProvider admin,
  ) {
    final data =
        admin.irrigationEventsByDate;

    final entries =
        data.entries.toList();

    entries.sort(
      (a, b) =>
          a.key.compareTo(b.key),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Irrigation Events Over Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Number of irrigation events per recorded date',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            if (entries.isEmpty)
              _buildNoDataMessage(
                'No irrigation event data yet.',
              )
            else
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,

                    gridData:
                        const FlGridData(show: true),

                    titlesData:
                        FlTitlesData(
                      leftTitles:
                          const AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                        ),
                      ),

                      bottomTitles:
                          AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles: true,
                          getTitlesWidget:
                              (value, meta) {
                            final index =
                                value.toInt();

                            if (index < 0 ||
                                index >=
                                    entries
                                        .length) {
                              return const SizedBox();
                            }

                            final date =
                                entries[index]
                                    .key;

                            return Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 8,
                              ),
                              child: Text(
                                date.length >= 10
                                    ? date.substring(
                                        5,
                                      )
                                    : date,
                                style:
                                    const TextStyle(
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      topTitles:
                          const AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles: false,
                        ),
                      ),

                      rightTitles:
                          const AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles: false,
                        ),
                      ),
                    ),

                    borderData:
                        FlBorderData(show: true),

                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        barWidth: 3,
                        spots:
                            List.generate(
                          entries.length,
                          (index) {
                            return FlSpot(
                              index.toDouble(),
                              entries[index]
                                  .value
                                  .toDouble(),
                            );
                          },
                        ),
                        dotData:
                            const FlDotData(
                          show: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // USER ACTIVITY SUMMARY
  // ==============================================================

  Widget _buildActivitySummary(
    AdminProvider admin,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'User Activity Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Recorded activities performed by users',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 16),

            _buildActivityRow(
              icon:
                  Icons.person_add_outlined,
              label: 'Registrations',
              value:
                  admin.registrationCount,
            ),

            _buildActivityRow(
              icon: Icons.login,
              label: 'Logins',
              value: admin.totalLogins,
            ),

            _buildActivityRow(
              icon:
                  Icons.water_drop_outlined,
              label: 'Pump ON',
              value: admin.pumpOnCount,
            ),

            _buildActivityRow(
              icon:
                  Icons.water_drop_outlined,
              label: 'Pump OFF',
              value: admin.pumpOffCount,
            ),

            _buildActivityRow(
              icon: Icons.settings_outlined,
              label: 'Settings Changes',
              value:
                  admin.settingsChangeCount,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // SUMMARY CARD
  // ==============================================================

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 34,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      value,
                      style:
                          const TextStyle(
                        fontSize: 26,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // STATUS CARD
  // ==============================================================

  Widget _buildStatusCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    String? caption,
    Color? accent,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          size: 32,
          color: accent,
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 16,
                color: accent,
              ),
            ),

            if (caption != null &&
                caption.isNotEmpty)
              Text(
                caption,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // MINI STAT
  // ==============================================================

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 26,
          ),

          const SizedBox(height: 8),

          Text(
            label,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // LEGEND
  // ==============================================================

  Widget _buildLegendItem(
    String label,
    int value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,
            color: color,
          ),
        ),

        const SizedBox(width: 6),

        Text(
          '$label: $value',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // ACTIVITY ROW
  // ==============================================================

  Widget _buildActivityRow({
    required IconData icon,
    required String label,
    required int value,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(label),
          ),

          Text(
            value.toString(),
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // INFO ROW
  // ==============================================================

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(label),
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // NO DATA
  // ==============================================================

  Widget _buildNoDataMessage(
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 42,
            color:
                Colors.grey.shade500,
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // PUMP MAX Y
  // ==============================================================

  double _pumpMaxY(
    AdminProvider admin,
  ) {
    final max =
        admin.pumpOnCount >
                admin.pumpOffCount
            ? admin.pumpOnCount
            : admin.pumpOffCount;

    if (max == 0) {
      return 5;
    }

    return (max + 2).toDouble();
  }

  // ==============================================================
  // SAFE MAP READ
  // ==============================================================

  dynamic _read(
    dynamic source,
    String key,
  ) {
    if (source is Map) {
      return source[key];
    }

    return null;
  }

  // ==============================================================
  // DOUBLE
  // ==============================================================

  double _asDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ??
          0;
    }

    return 0;
  }

  // ==============================================================
  // PUMP ON/OFF
  // ==============================================================

  bool _pumpIsOn(
    dynamic pump,
  ) {
    if (pump == null) {
      return false;
    }

    // ----------------------------------------------------------
    // Firebase pump may be:
    //
    // pump: "OFF"
    //
    // OR
    //
    // pump:
    //   state: "OFF"
    //   mode: "auto"
    // ----------------------------------------------------------

    if (pump is String ||
        pump is num ||
        pump is bool) {
      final text =
          pump.toString().toLowerCase();

      return text == 'on' ||
          text == 'true' ||
          text == '1';
    }

    final state =
        _read(pump, 'state') ??
        _read(pump, 'status') ??
        _read(pump, 'value');

    if (state is bool) {
      return state;
    }

    final text =
        state.toString().toLowerCase();

    return text == 'on' ||
        text == 'true' ||
        text == '1';
  }

  // ==============================================================
  // PUMP STATE LABEL
  // ==============================================================

  String _pumpStateLabel(
    dynamic pump,
  ) {
    if (pump == null) {
      return 'No data';
    }

    return _pumpIsOn(pump)
        ? 'ON'
        : 'OFF';
  }

  // ==============================================================
  // PUMP MODE
  // ==============================================================

  String _pumpModeLabel(
    dynamic pump,
  ) {
    final mode =
        _read(pump, 'mode');

    if (mode == null) {
      return '';
    }

    final text =
        mode.toString();

    if (text.isEmpty) {
      return '';
    }

    return '${text[0].toUpperCase()}'
        '${text.substring(1)} mode';
  }

  // ==============================================================
  // SYSTEM CAPTION
  // ==============================================================

  String _systemCaption(
    dynamic system,
  ) {
    if (system is! Map) {
      return '';
    }

    final mode =
        system['mode'];

    if (mode == null) {
      return '';
    }

    return 'Mode: ${_capitalize(mode.toString())}';
  }

  // ==============================================================
  // SOIL VALUE
  // ==============================================================

  double? _soilMoistureValue(
    dynamic sensor,
  ) {
    final raw =
        _read(sensor, 'soil') ??
        _read(sensor, 'moisture') ??
        _read(
          sensor,
          'soilMoisture',
        ) ??
        _read(sensor, 'value');

    if (raw == null) {
      return null;
    }

    if (raw is num) {
      return raw.toDouble();
    }

    return double.tryParse(
      raw.toString(),
    );
  }

  // ==============================================================
  // SOIL CONDITION
  // ==============================================================

  String _soilMoistureCondition(
    dynamic sensor,
  ) {
    final value =
        _soilMoistureValue(sensor);

    if (value == null) {
      return 'Waiting for sensor reading';
    }

    if (value < 30) {
      return 'Dry - irrigation threshold reached';
    }

    if (value < 60) {
      return 'Adequate';
    }

    return 'Wet';
  }

  // ==============================================================
  // CAPITALIZE
  // ==============================================================

  String _capitalize(
    String text,
  ) {
    if (text.isEmpty) {
      return text;
    }

    return text[0].toUpperCase() +
        text.substring(1);
  }

  // ==============================================================
  // BOOLEAN FORMAT
  // ==============================================================

  String _formatBoolean(
    dynamic value,
  ) {
    if (value is bool) {
      return value ? 'Enabled' : 'Disabled';
    }

    final text =
        value.toString().toLowerCase();

    if (text == 'true') {
      return 'Enabled';
    }

    if (text == 'false') {
      return 'Disabled';
    }

    return value?.toString() ?? '—';
  }

  // ==============================================================
  // TIMESTAMP FORMAT
  // ==============================================================

  String _formatTimestamp(
    dynamic value,
  ) {
    DateTime? dateTime;

    if (value is int) {
      dateTime =
          DateTime.fromMillisecondsSinceEpoch(
        value,
      );
    } else if (value is num) {
      dateTime =
          DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
      );
    } else {
      final text =
          value.toString();

      final number =
          int.tryParse(text);

      if (number != null) {
        dateTime =
            DateTime.fromMillisecondsSinceEpoch(
          text.length <= 10
              ? number * 1000
              : number,
        );
      } else {
        dateTime =
            DateTime.tryParse(text);
      }
    }

    if (dateTime == null) {
      return value.toString();
    }

    return _formatDateTime(dateTime);
  }

  String _formatDateTime(
    DateTime dateTime,
  ) {
    final local =
        dateTime.toLocal();

    final hour =
        local.hour.toString().padLeft(
              2,
              '0',
            );

    final minute =
        local.minute.toString().padLeft(
              2,
              '0',
            );

    final second =
        local.second.toString().padLeft(
              2,
              '0',
            );

    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '$hour:$minute:$second';
  }
}