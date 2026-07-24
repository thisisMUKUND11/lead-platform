import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state/auth.dart';
import '../widgets/avatar.dart';
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
  Map<String, String> _userNames = {};

  // Staged edits (committed with the Save button).
  LeadStatus? _selectedStatus;
  String? _selectedAssignee;

  bool _saving = false;
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
      final isAdmin = ref.read(authControllerProvider).isAdmin;

      // Fire all requests concurrently, then await — one round-trip instead
      // of four sequential ones (much faster, especially on a cold backend).
      final leadF = api.getLead(widget.leadId);
      final notesF = api.listNotes(widget.leadId);
      final activitiesF = api.listActivities(widget.leadId);
      final usersF = isAdmin ? api.listUsers() : Future.value(<User>[]);

      final lead = await leadF;
      final notes = await notesF;
      final activities = await activitiesF;
      final users = await usersF;

      if (!mounted) return;
      setState(() {
        _lead = lead;
        _notes = notes;
        _activities = activities;
        _users = users;
        _userNames = {for (final u in users) u.id: u.name};
        _selectedStatus = lead.status;
        _selectedAssignee = lead.assignedTo;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _dirty {
    final lead = _lead;
    if (lead == null) return false;
    final isAdmin = ref.read(authControllerProvider).isAdmin;
    final statusChanged = _selectedStatus != lead.status;
    final assigneeChanged = isAdmin && _selectedAssignee != lead.assignedTo;
    return statusChanged || assigneeChanged;
  }

  Future<void> _save() async {
    final lead = _lead;
    if (lead == null || !_dirty) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final isAdmin = ref.read(authControllerProvider).isAdmin;
      if (_selectedStatus != lead.status) {
        await api.updateLead(lead.id, {'status': _selectedStatus!.wire});
      }
      if (isAdmin && _selectedAssignee != lead.assignedTo) {
        await api.assignLead(lead.id, _selectedAssignee);
      }
      _toast('Changes saved');
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/app/leads'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to leads'),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          _headerCard(lead),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 860;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _manageCard(lead),
                  const SizedBox(height: 16),
                  _notesCard(),
                ],
              );
              final right = _activityCard();
              if (!wide) {
                return Column(
                    children: [left, const SizedBox(height: 16), right]);
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

  // ── Header ──────────────────────────────────────────────────
  Widget _headerCard(Lead lead) {
    final isAdmin = ref.read(authControllerProvider).isAdmin;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(lead.name, size: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(lead.name,
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      const SizedBox(width: 10),
                      StatusChip(lead.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 18,
                    runSpacing: 4,
                    children: [
                      _meta(Icons.email_outlined, lead.email),
                      if (lead.phone?.isNotEmpty ?? false)
                        _meta(Icons.phone_outlined, lead.phone!),
                      if (lead.company?.isNotEmpty ?? false)
                        _meta(Icons.business_outlined, lead.company!),
                      if (lead.source?.isNotEmpty ?? false)
                        _meta(Icons.campaign_outlined, lead.source!),
                    ],
                  ),
                ],
              ),
            ),
            if (isAdmin)
              IconButton(
                tooltip: 'Delete lead',
                onPressed: _confirmDelete,
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
      ],
    );
  }

  // ── Manage (status + assignee + Save) ───────────────────────
  Widget _manageCard(Lead lead) {
    final isAdmin = ref.read(authControllerProvider).isAdmin;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Manage',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (_dirty)
                  const Text('Unsaved changes',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEA580C),
                          fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            _fieldLabel('Status'),
            _dropdownBox(
              DropdownButton<LeadStatus>(
                value: _selectedStatus,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: LeadStatus.values
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 14),
              _fieldLabel('Assigned to'),
              _dropdownBox(
                DropdownButton<String?>(
                  value: _selectedAssignee,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Unassigned')),
                    ..._users.map((u) =>
                        DropdownMenuItem(value: u.id, child: Text(u.name))),
                  ],
                  onChanged: (v) => setState(() => _selectedAssignee = v),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_dirty && !_saving) ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving…' : 'Save changes'),
                  ),
                ),
                if (_dirty && !_saving) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _selectedStatus = lead.status;
                      _selectedAssignee = lead.assignedTo;
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownBox(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E4F0)),
        ),
        child: child,
      );

  Widget _fieldLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
      );

  // ── Notes ───────────────────────────────────────────────────
  Widget _notesCard() {
    final df = DateFormat('MMM d, y · h:mm a');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Notes',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                _countPill(_notes.length),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    minLines: 1,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(hintText: 'Add a note…'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _savingNote ? null : _addNote,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48)),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('No notes yet.',
                    style: TextStyle(color: Color(0xFF9CA3AF))),
              )
            else
              ..._notes.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Avatar(n.authorName ?? '?', size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.body),
                              const SizedBox(height: 2),
                              Text(
                                '${n.authorName ?? 'Unknown'} · '
                                '${df.format(n.createdAt.toLocal())}',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _countPill(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF0FB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$n',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4F46E5))),
      );

  // ── Activity timeline ───────────────────────────────────────
  Widget _activityCard() {
    final df = DateFormat('MMM d · h:mm a');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            if (_activities.isEmpty)
              const Text('No activity yet.',
                  style: TextStyle(color: Color(0xFF9CA3AF)))
            else
              ...List.generate(_activities.length, (i) {
                final a = _activities[i];
                final last = i == _activities.length - 1;
                final (icon, color) = _activityIcon(a.type);
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 16, color: color),
                          ),
                          if (!last)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: const Color(0xFFECEDF4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: last ? 0 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_activityLabel(a),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text(
                                '${a.actorName ?? 'System'} · '
                                '${df.format(a.createdAt.toLocal())}',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _activityIcon(String type) {
    switch (type) {
      case 'created':
        return (Icons.add_circle_outline, const Color(0xFF4F46E5));
      case 'assigned':
        return (Icons.person_outline, const Color(0xFF2563EB));
      case 'status_changed':
        return (Icons.swap_horiz, const Color(0xFFEA580C));
      case 'note_added':
        return (Icons.sticky_note_2_outlined, const Color(0xFF0EA5A6));
      default:
        return (Icons.edit_outlined, const Color(0xFF6B7280));
    }
  }

  String _activityLabel(Activity a) {
    switch (a.type) {
      case 'created':
        return 'Lead created';
      case 'assigned':
        final to = a.metadata['assignedTo'];
        if (to == null) return 'Unassigned';
        return 'Assigned to ${_userNames[to] ?? 'a team member'}';
      case 'status_changed':
        return 'Status changed: ${a.metadata['from']} → ${a.metadata['to']}';
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
    try {
      await ref.read(apiServiceProvider).addNote(widget.leadId, text);
      _noteController.clear();
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
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
        _toast(e.toString());
      }
    }
  }
}
