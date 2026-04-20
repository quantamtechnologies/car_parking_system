import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    try {
      await auth.login(_username.text.trim(), _password.text);
      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A1F44), Color(0xFF0F4CFF), Color(0xFF45C9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final split = constraints.maxWidth >= 900;
                    return Flex(
                      direction: split ? Axis.horizontal : Axis.vertical,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.local_parking_rounded, color: Colors.white, size: 58),
                                const SizedBox(height: 20),
                                Text('Smart Parking POS', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 16),
                                Text(
                                  'Production-ready parking, billing, OCR-assisted entry, and shift cash control in one touch-first interface.',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white.withOpacity(0.9), height: 1.4),
                                ),
                                const SizedBox(height: 24),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                children: const [
                                    _Chip(text: 'JWT Security'),
                                    _Chip(text: 'Cashier POS'),
                                    _Chip(text: 'ANPR Assisted'),
                                    _Chip(text: 'Railway Backend'),
                                ],
                              ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 430),
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [BoxShadow(color: Color(0x330A1F44), blurRadius: 36, offset: Offset(0, 18))],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text('Sign in', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 8),
                                    Text('Use your staff credentials to open the POS.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                                    const SizedBox(height: 24),
                                    TextFormField(
                                      controller: _username,
                                      decoration: const InputDecoration(labelText: 'Username'),
                                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter your username' : null,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _password,
                                      obscureText: _obscure,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(() => _obscure = !_obscure),
                                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                        ),
                                      ),
                                      validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
                                    ),
                                    const SizedBox(height: 24),
                                    GradientActionButton(
                                      label: 'Login',
                                      icon: Icons.lock_open_rounded,
                                      isBusy: auth.loading,
                                      onPressed: _submit,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}
