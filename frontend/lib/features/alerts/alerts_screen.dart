import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Future<List<AlertItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<SmartParkingApi>().alerts();
  }

  Future<void> _refreshAlerts() async {
    setState(() => _future = context.read<SmartParkingApi>().alerts());
    await _future;
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'RED':
        return const Color(0xFFD92D20);
      case 'YELLOW':
        return const Color(0xFFF2994A);
      default:
        return const Color(0xFF27AE60);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshAlerts,
      child: FutureBuilder<List<AlertItem>>(
        future: _future,
        builder: (context, snapshot) {
          final alerts = snapshot.data ?? const [];
          final loading = snapshot.connectionState != ConnectionState.done;
          final errorText = snapshot.hasError ? snapshot.error.toString() : null;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              SectionHeader(
                title: 'Anomaly alerts',
                subtitle: 'Green means normal, yellow warns, red needs immediate attention.',
                trailing: TextButton.icon(
                  onPressed: _refreshAlerts,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(height: 18),
              if (loading)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (errorText != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unable to load alerts: $errorText'),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: GradientActionButton(
                            label: 'Try again',
                            icon: Icons.refresh_rounded,
                            onPressed: _refreshAlerts,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (alerts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No active alerts right now.'),
                  ),
                )
              else
                for (final alert in alerts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusBadge(label: alert.severity, color: _severityColor(alert.severity)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(alert.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(alert.description),
                                  const SizedBox(height: 6),
                                  Text('Code: ${alert.code} | Category: ${alert.category}', style: const TextStyle(color: Colors.black54)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
