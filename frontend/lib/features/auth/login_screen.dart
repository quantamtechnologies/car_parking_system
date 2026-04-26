import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/auth_controller.dart';
import '../../core/services/api_errors.dart';
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
      if (mounted) context.go(auth.isAdmin ? '/admin' : '/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Login failed: ${apiErrorMessage(e, fallback: 'Check your credentials and try again.')}')),
      );
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final isCompact =
                  constraints.maxWidth < 700 || constraints.maxHeight < 760;
              final padding = EdgeInsets.symmetric(
                horizontal: isWide ? 20 : 16,
                vertical: isCompact ? 12 : 20,
              );

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        math.max(0.0, constraints.maxHeight - padding.vertical),
                  ),
                  child: Align(
                    alignment: isWide ? Alignment.center : Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: isWide ? 1120 : 560),
                      child: isWide
                          ? _buildWideLayout(context, auth)
                          : _buildCompactLayout(context, auth),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, AuthController auth) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_parking_rounded,
                    color: Colors.white, size: 58),
                const SizedBox(height: 20),
                Text(
                  'Smart Parking POS',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Text(
                  'Production-ready parking, billing, OCR-assisted entry, and shift cash control in one touch-first interface.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9), height: 1.4),
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
        const SizedBox(width: 24),
        Expanded(
          flex: 4,
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildLoginCard(context, auth, compact: false),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context, AuthController auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLoginCard(context, auth, compact: true),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.local_parking_rounded,
                  color: Colors.white, size: 40),
              const SizedBox(height: 10),
              Text(
                'Smart Parking POS',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Production-ready parking, billing, OCR-assisted entry, and shift cash control.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context, AuthController auth,
      {required bool compact}) {
    final cardPadding = compact ? 20.0 : 28.0;
    final cardRadius = compact ? 28.0 : 30.0;
    final buttonHeight = compact ? 52.0 : 58.0;
    final inputTheme = Theme.of(context).inputDecorationTheme;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 460 : 430),
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(cardRadius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x330A1F44), blurRadius: 36, offset: Offset(0, 18))
          ],
        ),
        child: Form(
          key: _formKey,
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: inputTheme.copyWith(
                fillColor: const Color(0xFFF5F8FF),
                labelStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFD7E3F7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      const BorderSide(color: Color(0xFF2563EB), width: 1.4),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sign in',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 28 : null,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use your staff credentials to open the POS.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black54),
                ),
                SizedBox(height: compact ? 18 : 24),
                TextFormField(
                  controller: _username,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter your username',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your username'
                      : null,
                ),
                SizedBox(height: compact ? 12 : 16),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password'
                      : null,
                ),
                SizedBox(height: compact ? 18 : 24),
                GradientActionButton(
                  label: 'Login',
                  icon: Icons.lock_open_rounded,
                  isBusy: auth.loading,
                  minHeight: buttonHeight,
                  onPressed: _submit,
                ),
              ],
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
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}
