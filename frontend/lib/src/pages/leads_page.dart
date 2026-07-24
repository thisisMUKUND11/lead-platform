import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state/auth.dart';
import '../widgets/status_chip.dart';

class LeadsPage extends ConsumerStatefulWidget {
  const LeadsPage({super.key});

  @override
  ConsumerState<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends ConsumerState<LeadsPage> {
  final _searchController = TextEditingController();

  LeadStatus? _status;
  int _page = 1;
  static const _limit = 20;

  bool _loading = true;
  String? _error;
  Paginated<Lead>? _data;
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      // Admins can see everyone's names for the "assigned to" column.
      if (ref.read(authControllerProvider).isAdmin && _userNames.isEmpty) {
        final users = await api.listUsers();
        _userNames = {for (final u in users) u.id: u.name};
      }
      final data = await api.listLeads(
        page: _page,
        limit: _limit,
        status: _status?.wire,
        search: _searchController.text.trim(),
      );
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetAndLoad() {
    _page = 1;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toolbar(context),
          const SizedBox(height: 16),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search name, email, company',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: _resetAndLoad,
              ),
            ),
            onSubmitted: (_) => _resetAndLoad(),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<LeadStatus?>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All statuses')),
              ...LeadStatus.values.map(
                (s) => DropdownMenuItem(value: s, child: Text(s.label)),
              ),
            ],
            onChanged: (value) {
              setState(() => _status = value);
              _resetAndLoad();
            },
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => _showNewLeadDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('New lead'),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    final data = _data;
    if (data == null || data.items.isEmpty) {
      return const Center(child: Text('No leads found.'));
    }

    final isAdmin = ref.read(authControllerProvider).isAdmin;
    final df = DateFormat('MMM d, y');

    return Column(
      children: [
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  showCheckboxColumn: false,
                  columns: [
                    const DataColumn(label: Text('Name')),
                    const DataColumn(label: Text('Company')),
                    const DataColumn(label: Text('Status')),
                    if (isAdmin) const DataColumn(label: Text('Assigned to')),
                    const DataColumn(label: Text('Updated')),
                  ],
                  rows: [
                    for (final lead in data.items)
                      DataRow(
                        onSelectChanged: (_) =>
                            context.go('/app/leads/${lead.id}'),
                        cells: [
                          DataCell(Text(lead.name)),
                          DataCell(Text(lead.company ?? '—')),
                          DataCell(StatusChip(lead.status)),
                          if (isAdmin)
                            DataCell(Text(
                              lead.assignedTo == null
                                  ? 'Unassigned'
                                  : (_userNames[lead.assignedTo] ?? '—'),
                            )),
                          DataCell(Text(df.format(lead.updatedAt.toLocal()))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _pagination(data),
      ],
    );
  }

  Widget _pagination(Paginated<Lead> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${data.total} leads · page ${data.page} of '
          '${data.totalPages == 0 ? 1 : data.totalPages}',
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: data.page > 1
              ? () {
                  _page = data.page - 1;
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: data.page < data.totalPages
              ? () {
                  _page = data.page + 1;
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Future<void> _showNewLeadDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NewLeadDialog(),
    );
    if (created ?? false) _resetAndLoad();
  }
}

class _NewLeadDialog extends ConsumerStatefulWidget {
  const _NewLeadDialog();

  @override
  ConsumerState<_NewLeadDialog> createState() => _NewLeadDialogState();
}

class _NewLeadDialogState extends ConsumerState<_NewLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _company.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiServiceProvider).createLead({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'company': _company.text.trim(),
        'phone': _phone.text.trim(),
        'source': 'manual',
      });
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
      title: const Text('New lead'),
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
              TextFormField(
                controller: _company,
                decoration: const InputDecoration(labelText: 'Company'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
