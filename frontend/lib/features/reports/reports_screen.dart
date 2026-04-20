import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<DashboardMetrics> _future;
  final _query = TextEditingController();
  Map<String, dynamic>? _chatResponse;

  @override
  void initState() {
    super.initState();
    _future = context.read<SmartParkingApi>().dashboard();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_query.text.trim().isEmpty) return;
    final response = await context.read<SmartParkingApi>().chatbot(_query.text.trim());
    setState(() => _chatResponse = response);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardMetrics>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final metrics = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const SectionHeader(
              title: 'Reports and analytics',
              subtitle: 'Daily volume, revenue, peak hours, and staff performance.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoPill(label: 'Cars today', value: metrics.carsPerDay.toString()),
                _InfoPill(label: 'Revenue', value: money(metrics.revenuePerDay)),
                _InfoPill(label: 'Occupancy', value: '${metrics.occupancyRate.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Peak hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    for (final hour in metrics.peakHours)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(
                          value: (hour['total'] is num ? (hour['total'] as num).toDouble() : 0) / (metrics.carsPerDay == 0 ? 1 : metrics.carsPerDay),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chatbot assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _query,
                      decoration: const InputDecoration(labelText: 'Ask a question, like "How many cars today?"'),
                    ),
                    const SizedBox(height: 12),
                    GradientActionButton(
                      label: 'Ask',
                      icon: Icons.smart_toy_rounded,
                      onPressed: _ask,
                    ),
                    if (_chatResponse != null) ...[
                      const SizedBox(height: 12),
                      Text('Intent: ${_chatResponse!['intent']}'),
                      Text('Value: ${_chatResponse!['value'] ?? _chatResponse!['message'] ?? ''}'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

