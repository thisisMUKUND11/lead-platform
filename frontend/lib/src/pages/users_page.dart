import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state/auth.dart';
import '../widgets/avatar.dart';
import '../widgets/password_field.dart';
import '../widgets/stat_tile.dart';

/// Admin-only: list team members and create new ones.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  bool _loading = true;
  String? _error;
  List<User> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await ref.read(apiServiceProvider).listUsers();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _admins => _users.where((u) => u.isAdmin).length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Team',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    const Text('Manage who can access the platform',
                        style: TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showNewUserDialog(context),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add member'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'Team members',
                value: _users.length,
                icon: Icons.groups_outlined,
                color: const Color(0xFF4F46E5),
                loading: _loading,
              ),
              StatTile(
                label: 'Admins',
                value: _admins,
                icon: Icons.shield_outlined,
                color: const Color(0xFF7C3AED),
                loading: _loading,
              ),
              StatTile(
                label: 'Members',
                value: _users.length - _admins,
                icon: Icons.person_outline,
                color: const Color(0xFF0EA5A6),
                loading: _loading,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _body(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: _users.map(_memberCard).toList(),
    );
  }

  Widget _memberCard(User u) {
    final df = DateFormat('MMM y');
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EAF3)),
      ),
      child: Row(
        children: [
          Avatar(u.name, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        u.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _roleBadge(u.isAdmin),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  u.email,
                  style:
                      const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  overflow: TextOverflow.ellipsis,
                ),
                if (u.createdAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Joined ${df.format(u.createdAt!.toLocal())}',
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 20, color: Color(0xFF6B7280)),
            tooltip: 'Edit member',
            onPressed: () => _showEditDialog(u),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(bool isAdmin) {
    final color = isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF0EA5A6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Member',
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _showNewUserDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NewUserDialog(),
    );
    if (created ?? false) _load();
  }

  Future<void> _showEditDialog(User user) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditUserDialog(user),
    );
    if (updated ?? false) _load();
  }
}

class _NewUserDialog extends ConsumerStatefulWidget {
  const _NewUserDialog();

  @override
  ConsumerState<_NewUserDialog> createState() => _NewUserDialogState();
}

class _NewUserDialogState extends ConsumerState<_NewUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'member';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiServiceProvider).createUser(
            email: _email.text.trim(),
            name: _name.text.trim(),
            password: _password.text,
            role: _role,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add team member'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Required';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
                      ? null
                      : 'Invalid email';
                },
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _password,
                labelText: 'Password * (min 6 chars)',
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'member'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Create'),
        ),
      ],
    );
  }
}

/// Admin: edit a member's name/role and reset their password.
class _EditUserDialog extends ConsumerStatefulWidget {
  const _EditUserDialog(this.user);

  final User user;

  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _password = TextEditingController();
  late String _role;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _role = widget.user.role.name;
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiServiceProvider).updateUser(
            widget.user.id,
            name: _name.text.trim(),
            role: _role,
            password: _password.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.user.name}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: widget.user.email,
                enabled: false,
                decoration:
                    const InputDecoration(labelText: 'Email (read-only)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'member'),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                labelText: 'New password (leave blank to keep)',
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  return v.length < 6 ? 'Min 6 characters' : null;
                },
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Color(0xFF9CA3AF)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Passwords are encrypted and can't be viewed. "
                      'Enter a new one to reset it.',
                      style:
                          TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
