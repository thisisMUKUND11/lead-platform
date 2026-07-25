import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state/auth.dart';
import '../widgets/avatar.dart';
import '../widgets/loading.dart';
import '../widgets/status_chip.dart';
import '../widgets/stat_tile.dart';

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

  Map<LeadStatus, int>? _counts;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait(
        LeadStatus.values.map((s) => api.listLeads(status: s.wire, limit: 1)),
      );
      final counts = <LeadStatus, int>{};
      for (var i = 0; i < LeadStatus.values.length; i++) {
        counts[LeadStatus.values[i]] = results[i].total;
      }
      if (mounted) setState(() => _counts = counts);
    } catch (_) {
      // Stats are non-critical; ignore failures.
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.listLeads(
        page: _page,
        limit: _limit,
        status: _status?.wire,
        search: _searchController.text.trim(),
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetAndLoad() {
    _page = 1;
    _load();
  }

  int _sum(List<LeadStatus> ss) =>
      _counts == null ? 0 : ss.fold(0, (a, s) => a + (_counts![s] ?? 0));

  @override
  Widget build(BuildContext context) {
    // First entry: show a clean full-page loader instead of a bare spinner.
    if (_loading && _data == null) {
      return const AppLoader(message: 'Loading your leads…');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          const SizedBox(height: 20),
          _statRow(),
          const SizedBox(height: 20),
          _toolbar(context),
          const SizedBox(height: 16),
          _table(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leads', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              const Text(
                'Manage and track your sales pipeline',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => _showNewLeadDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('New lead'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
        ),
      ],
    );
  }

  Widget _statRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        StatTile(
          label: 'Total leads',
          value: _sum(LeadStatus.values),
          icon: Icons.people_alt_outlined,
          color: const Color(0xFF4F46E5),
          loading: _statsLoading,
        ),
        StatTile(
          label: 'In pipeline',
          value: _sum([
            LeadStatus.newLead,
            LeadStatus.contacted,
            LeadStatus.qualified,
            LeadStatus.proposal,
          ]),
          icon: Icons.trending_up,
          color: const Color(0xFF0EA5A6),
          loading: _statsLoading,
        ),
        StatTile(
          label: 'Won',
          value: _sum([LeadStatus.won]),
          icon: Icons.emoji_events_outlined,
          color: const Color(0xFF16A34A),
          loading: _statsLoading,
        ),
        StatTile(
          label: 'Lost',
          value: _sum([LeadStatus.lost]),
          icon: Icons.cancel_outlined,
          color: const Color(0xFFDC2626),
          loading: _statsLoading,
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search name, email, or company',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: _resetAndLoad,
              ),
            ),
            onSubmitted: (_) => _resetAndLoad(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _statusChip('All', null),
            ...LeadStatus.values.map((s) => _statusChip(s.label, s)),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(String label, LeadStatus? status) {
    final selected = _status == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _status = status);
        _resetAndLoad();
      },
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? Colors.white : const Color(0xFF374151),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      selectedColor: const Color(0xFF4F46E5),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF4F46E5) : const Color(0xFFD9DBE9),
      ),
    );
  }

  Widget _table(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    final data = _data;
    if (data == null || data.items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text('No leads found', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    final isAdmin = ref.read(authControllerProvider).isAdmin;
    final df = DateFormat('MMM d, y');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 90,
              ),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FC)),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                ),
                dividerThickness: 1,
                columns: [
                  const DataColumn(label: Text('LEAD')),
                  const DataColumn(label: Text('STATUS')),
                  if (isAdmin) const DataColumn(label: Text('ASSIGNED TO')),
                  const DataColumn(label: Text('UPDATED')),
                  const DataColumn(label: Text('')),
                ],
                rows: [
                  for (final lead in data.items)
                    DataRow(
                      onSelectChanged: (_) =>
                          context.go('/app/leads/${lead.id}'),
                      cells: [
                        DataCell(_leadCell(lead)),
                        DataCell(StatusChip(lead.status)),
                        if (isAdmin) DataCell(_assignedCell(lead)),
                        DataCell(Text(df.format(lead.updatedAt.toLocal()))),
                        const DataCell(
                          Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _pagination(data),
          ),
        ],
      ),
    );
  }

  Widget _leadCell(Lead lead) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(lead.name),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lead.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                lead.company?.isNotEmpty ?? false ? lead.company! : lead.email,
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _assignedCell(Lead lead) {
    if (lead.assignedTo == null) {
      return const Text('Unassigned',
          style: TextStyle(color: Color(0xFF9CA3AF)));
    }
    final name = lead.assignedToName ?? '—';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(name, size: 26),
        const SizedBox(width: 8),
        Text(name),
      ],
    );
  }

  Widget _pagination(Paginated<Lead> data) {
    return Row(
      children: [
        Text(
          'Showing ${data.items.length} of ${data.total}',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
        const Spacer(),
        Text('Page ${data.page} of ${data.totalPages == 0 ? 1 : data.totalPages}',
            style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
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
    if (created ?? false) {
      _loadStats();
      _resetAndLoad();
    }
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      alignment: Alignment.center,
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
