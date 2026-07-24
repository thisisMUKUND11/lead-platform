import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state/auth.dart';
import '../widgets/status_chip.dart';

class LeadDetailPage extends ConsumerStatefulWidget {
  const LeadDetailPage({required this.leadId, super.key});

  final String leadId;

  @override
  ConsumerState<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends ConsumerState<LeadDetailPage> {
  final _noteController = TextEditingController();

  bool _loading = true;
  String? _error;
  Lead? _lead;
  List<LeadNote> _notes = [];
  List<Activity> _activities = [];
  List<User> _users = [];
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final lead = await api.getLead(widget.leadId);
      final notes = await api.listNotes(widget.leadId);
      final activities = await api.listActivities(widget.leadId);
      final users = ref.read(authControllerProvider).isAdmin
          ? await api.listUsers()
          : <User>[];
      setState(() {
        _lead = lead;
        _notes = notes;
        _activities = activities;
        _users = users;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _lead == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Lead not found'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/app/leads'),
              child: const Text('Back to leads'),
            ),
          ],
        ),
      );
    }

    final lead = _lead!;
    final isAdmin = ref.read(authControllerProvider).isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, lead, isAdmin),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _detailsCard(lead, isAdmin),
                  const SizedBox(height: 16),
                  _notesCard(),
                ],
              );
              final right = _activityCard();
              if (!wide) {
                return Column(children: [left, const SizedBox(height: 16), right]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: left),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Lead lead, bool isAdmin) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.go('/app/leads'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lead.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(lead.email,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        StatusChip(lead.status),
        if (isAdmin) ...[
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Delete lead',
            onPressed: _confirmDelete,
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _detailsCard(Lead lead, bool isAdmin) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _field('Company', lead.company ?? '—'),
            _field('Phone', lead.phone ?? '—'),
            _field('Source', lead.source ?? '—'),
            const Divider(height: 28),
            // Status pipeline control (members may change their own leads).
            Row(
              children: [
                const SizedBox(width: 110, child: Text('Status')),
                Expanded(
                  child: DropdownButton<LeadStatus>(
                    value: lead.status,
                    isExpanded: true,
                    onChanged: (value) {
                      if (value != null && value != lead.status) {
                        _run(() => ref
                            .read(apiServiceProvider)
                            .updateLead(lead.id, {'status': value.wire}));
                      }
                    },
                    items: LeadStatus.values
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                  ),
                ),
              ],
            ),
            // Assignment control — admin only.
            if (isAdmin)
              Row(
                children: [
                  const SizedBox(width: 110, child: Text('Assigned to')),
                  Expanded(
                    child: DropdownButton<String?>(
                      value: lead.assignedTo,
                      isExpanded: true,
                      hint: const Text('Unassigned'),
                      onChanged: (value) {
                        _run(() => ref
                            .read(apiServiceProvider)
                            .assignLead(lead.id, value));
                      },
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Unassigned')),
                        ..._users.map((u) => DropdownMenuItem(
                            value: u.id, child: Text(u.name))),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _notesCard() {
    final df = DateFormat('MMM d, y · h:mm a');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    minLines: 1,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(hintText: 'Add a note…'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _savingNote ? null : _addNote,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No notes yet.',
                    style: TextStyle(color: Colors.black54)),
              )
            else
              ..._notes.map(
                (n) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.body),
                      const SizedBox(height: 2),
                      Text(
                        '${n.authorName ?? 'Unknown'} · '
                        '${df.format(n.createdAt.toLocal())}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                      const Divider(height: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activityCard() {
    final df = DateFormat('MMM d · h:mm a');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_activities.isEmpty)
              const Text('No activity yet.',
                  style: TextStyle(color: Colors.black54))
            else
              ..._activities.map(
                (a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.black38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_activityLabel(a)),
                            Text(
                              '${a.actorName ?? 'System'} · '
                              '${df.format(a.createdAt.toLocal())}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _activityLabel(Activity a) {
    switch (a.type) {
      case 'created':
        return 'Lead created';
      case 'assigned':
        final to = a.metadata['assignedTo'];
        return to == null ? 'Unassigned' : 'Assigned to a team member';
      case 'status_changed':
        return 'Status: ${a.metadata['from']} → ${a.metadata['to']}';
      case 'note_added':
        return 'Note added';
      case 'updated':
        return 'Lead updated';
      default:
        return a.type;
    }
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    setState(() => _savingNote = true);
    await _run(() async {
      await ref.read(apiServiceProvider).addNote(widget.leadId, text);
      _noteController.clear();
    });
    if (mounted) setState(() => _savingNote = false);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete lead?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      try {
        await ref.read(apiServiceProvider).deleteLead(widget.leadId);
        if (mounted) context.go('/app/leads');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }
}
