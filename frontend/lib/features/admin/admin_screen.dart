import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<PricingPolicyDto> _pricingFuture;
  int? _loadedPolicyId;
  final _name = TextEditingController();
  final _baseFee = TextEditingController();
  final _hourlyRate = TextEditingController();
  final _grace = TextEditingController();
  final _penalty = TextEditingController();
  final _dailyCap = TextEditingController();
  final _specialRules = TextEditingController();
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _pricingFuture = context.read<SmartParkingApi>().currentPricing();
  }

  @override
  void dispose() {
    _name.dispose();
    _baseFee.dispose();
    _hourlyRate.dispose();
    _grace.dispose();
    _penalty.dispose();
    _dailyCap.dispose();
    _specialRules.dispose();
    super.dispose();
  }

  void _populate(PricingPolicyDto policy) {
    if (_loadedPolicyId == policy.id) return;
    _name.text = policy.name;
    _baseFee.text = policy.baseFee.toStringAsFixed(2);
    _hourlyRate.text = policy.hourlyRate.toStringAsFixed(2);
    _grace.text = policy.gracePeriodMinutes.toString();
    _penalty.text = policy.overduePenalty.toStringAsFixed(2);
    _dailyCap.text = policy.dailyMaxCap?.toStringAsFixed(2) ?? '';
    _specialRules.text = policy.specialRules.isEmpty ? '{}' : policy.specialRules.toString();
    _active = policy.isActive;
    _loadedPolicyId = policy.id;
  }

  Future<void> _save() async {
    await context.read<SmartParkingApi>().updatePricing({
      'name': _name.text.trim(),
      'base_fee': double.tryParse(_baseFee.text) ?? 0,
      'hourly_rate': double.tryParse(_hourlyRate.text) ?? 0,
      'grace_period_minutes': int.tryParse(_grace.text) ?? 0,
      'overdue_penalty': double.tryParse(_penalty.text) ?? 0,
      'daily_max_cap': _dailyCap.text.trim().isEmpty ? null : double.tryParse(_dailyCap.text),
      'special_rules': {
        'raw': _specialRules.text.trim(),
      },
      'is_active': _active,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pricing saved.')));
    setState(() {
      _loadedPolicyId = null;
      _pricingFuture = context.read<SmartParkingApi>().currentPricing();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PricingPolicyDto>(
      future: _pricingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final policy = snapshot.data!;
        _populate(policy);
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const SectionHeader(
              title: 'Admin control center',
              subtitle: 'Update pricing without code changes and keep historical sessions intact.',
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Policy name')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _baseFee, decoration: const InputDecoration(labelText: 'Base fee'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _hourlyRate, decoration: const InputDecoration(labelText: 'Hourly rate'), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _grace, decoration: const InputDecoration(labelText: 'Grace period (minutes)'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _penalty, decoration: const InputDecoration(labelText: 'Overdue penalty'), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _dailyCap, decoration: const InputDecoration(labelText: 'Daily max cap (optional)'), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(controller: _specialRules, decoration: const InputDecoration(labelText: 'Special rules JSON / notes'), maxLines: 4),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                      title: const Text('Activate this policy'),
                    ),
                    const SizedBox(height: 12),
                    GradientActionButton(
                      label: 'Save pricing',
                      icon: Icons.save_rounded,
                      onPressed: _save,
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
                    const Text('Current policy snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text('Version ${policy.version}'),
                    Text('Base fee ${money(policy.baseFee)}'),
                    Text('Hourly rate ${money(policy.hourlyRate)}'),
                    Text('Grace ${policy.gracePeriodMinutes} min'),
                    Text('Daily cap ${policy.dailyMaxCap == null ? 'None' : money(policy.dailyMaxCap!)}'),
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
