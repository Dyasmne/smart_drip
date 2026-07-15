import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/sensor_provider.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/charts/moisture_chart.dart';
import '../../widgets/common/custom_appbar.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7F3),
      appBar: const CustomAppBar(
        title: 'Monitoring',
        showBackButton: true,
      ),
      body: Consumer<SensorProvider>(
        builder: (context, sensorProvider, child) {
          final data = sensorProvider.currentData;

          final moisture = sensorProvider.moisture;
          final temp = data?.temperature ?? 0;
          final humidity = data?.humidity ?? 0;

          final color = AppHelpers.getMoistureColor(moisture);

          // Historical data is stored newest-first (insert(0, ...)),
          // so reverse it for the chart to plot oldest -> newest left to right.
          final chartData = sensorProvider.historicalData.reversed.toList();

          return RefreshIndicator(
            onRefresh: sensorProvider.refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [

                  // ================= MOISTURE CARD =================

                  Container(
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
                    child: Column(
                      children: [

                        Icon(
                          Icons.water_drop,
                          color: color,
                          size: 60,
                        ),

                        const SizedBox(height: 15),

                        Text(
                          "${moisture.toStringAsFixed(1)}%",
                          style: TextStyle(
                            color: color,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          sensorProvider.moistureStatus,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 20),

                        LinearProgressIndicator(
                          value: moisture / 100,
                          minHeight: 12,
                          borderRadius:
                              BorderRadius.circular(10),
                          color: color,
                          backgroundColor:
                              color.withOpacity(.15),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ================= MOISTURE TREND CHART =================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 20,
                          color: Colors.black.withOpacity(.05),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Moisture Trend",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (sensorProvider.isOnline)
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration:
                                        const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Live",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight:
                                          FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        MoistureChart(
                          data: chartData,
                          height: 200,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ================= SENSOR CARDS =================

                  Row(
                    children: [

                      Expanded(
                        child: _sensorCard(
                          icon: Icons.thermostat,
                          value:
                              "${temp.toStringAsFixed(1)}°C",
                          title: "Temperature",
                          color: Colors.orange,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _sensorCard(
                          icon: Icons.water_drop_outlined,
                          value:
                              "${humidity.toStringAsFixed(0)}%",
                          title: "Humidity",
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [

                        const Icon(
                          Icons.access_time,
                          color: Colors.blue,
                        ),

                        const SizedBox(width: 10),

                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            const Text(
                              "Last Updated",
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),

                            Text(
                              sensorProvider.lastUpdated !=
                                      null
                                  ? AppFormatters
                                      .formatRelativeTime(
                                      sensorProvider
                                          .lastUpdated!)
                                  : "Just now",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ================= GUIDE =================

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [

                        _guideRow(
                          Colors.red,
                          "Very Dry",
                          "0% - 20%",
                        ),

                        const Divider(),

                        _guideRow(
                          Colors.orange,
                          "Dry",
                          "20% - 40%",
                        ),

                        const Divider(),

                        _guideRow(
                          Colors.green,
                          "Good",
                          "40% - 70%",
                        ),

                        const Divider(),

                        _guideRow(
                          Colors.blue,
                          "Wet",
                          "70% - 100%",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sensorCard({
    required IconData icon,
    required String value,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(title),
        ],
      ),
    );
  }

  Widget _guideRow(
    Color color,
    String title,
    String range,
  ) {
    return Row(
      children: [

        CircleAvatar(
          radius: 6,
          backgroundColor: color,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            range,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}