import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/error_banner.dart';

/// Public lead-capture form. No authentication required.
class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key});

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _company.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(apiServiceProvider).createLead({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'company': _company.text.trim(),
        'source': 'public_form',
      });
      setState(() => _submitted = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Get in touch',
      subtitle: 'Leave your details and our sales team will reach out',
      topRightAction: TextButton.icon(
        onPressed: () => context.go('/login'),
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        icon: const Icon(Icons.lock_outline, size: 16),
        label: const Text('Team login'),
      ),
      child: _submitted ? _thankYou(context) : _form(context),
    );
  }

  Widget _thankYou(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle,
            size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('Thank you for your submission!',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Our team has received your details and will reach out to you soon.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => setState(() {
            _submitted = false;
            _formKey.currentState?.reset();
            _name.clear();
            _email.clear();
            _phone.clear();
            _company.clear();
          }),
          child: const Text('Submit another'),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 18),
          ],
          _label('Full name *'),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(hintText: 'Jane Doe'),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          _label('Email *'),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(hintText: 'jane@company.com'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Email is required';
              final ok =
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
              return ok ? null : 'Enter a valid email';
            },
          ),
          const SizedBox(height: 16),
          _label('Phone *'),
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(hintText: 'e.g. +1 555 123 4567'),
            keyboardType: TextInputType.phone,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Phone is required';
              if (!RegExp(r'^[0-9+()\-\s]{7,}$').hasMatch(value)) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _label('Company *'),
          TextFormField(
            controller: _company,
            decoration: const InputDecoration(hintText: 'Your company name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Company is required' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      );
}
