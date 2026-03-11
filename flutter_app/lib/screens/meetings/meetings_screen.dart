import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/meetings_provider.dart';
import '../../models/meeting.dart';

class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createMeeting() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _NewMeetingDialog(),
    );
    if (result != null) {
      await ref.read(meetingsProvider.notifier).createMeeting(
        title: result['title'] as String,
        meetingDate: result['date'] as String?,
        participants: result['participants'] as List<String>?,
        tags: result['tags'] as List<String>?,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(meetingsProvider);
    final notifier = ref.read(meetingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Completed')],
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _createMeeting, child: const Icon(Icons.add)),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MeetingList(meetings: notifier.upcoming, onTap: _openMeeting, onDelete: (id) => notifier.deleteMeeting(id)),
          _MeetingList(meetings: notifier.completed, onTap: _openMeeting, onDelete: (id) => notifier.deleteMeeting(id)),
        ],
      ),
    );
  }

  void _openMeeting(Meeting meeting) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MeetingDetailSheet(meeting: meeting, notifier: ref.read(meetingsProvider.notifier)),
    );
  }
}

class _MeetingList extends StatelessWidget {
  final List<Meeting> meetings;
  final Function(Meeting) onTap;
  final Function(String) onDelete;

  const _MeetingList({required this.meetings, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return const Center(child: Text('No meetings', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        return _MeetingCard(meeting: meeting, onTap: () => onTap(meeting), onDelete: () => onDelete(meeting.id));
      },
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MeetingCard({required this.meeting, required this.onTap, required this.onDelete});

  Color get _statusColor {
    switch (meeting.status) {
      case MeetingStatus.scheduled: return Colors.blue;
      case MeetingStatus.inProgress: return Colors.orange;
      case MeetingStatus.completed: return Colors.green;
      case MeetingStatus.cancelled: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(meeting.meetingDate));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: _statusColor.withOpacity(0.15), child: Icon(Icons.calendar_today, color: _statusColor, size: 20)),
        title: Text(meeting.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: const TextStyle(fontSize: 12)),
            if (meeting.participants.isNotEmpty)
              Text('${meeting.participants.length} participants', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(meeting.status.label, style: TextStyle(fontSize: 11, color: _statusColor)),
            ),
            PopupMenuButton<String>(
              itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))],
              onSelected: (v) { if (v == 'delete') onDelete(); },
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _MeetingDetailSheet extends StatefulWidget {
  final Meeting meeting;
  final MeetingsNotifier notifier;
  const _MeetingDetailSheet({required this.meeting, required this.notifier});

  @override
  State<_MeetingDetailSheet> createState() => _MeetingDetailSheetState();
}

class _MeetingDetailSheetState extends State<_MeetingDetailSheet> {
  late Meeting _meeting;

  @override
  void initState() {
    super.initState();
    _meeting = widget.meeting;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: controller,
          children: [
            Row(children: [
              Expanded(child: Text(_meeting.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              _StatusChip(status: _meeting.status),
            ]),
            const SizedBox(height: 8),
            Text(DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(DateTime.parse(_meeting.meetingDate)), style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),

            if (_meeting.participants.isNotEmpty) ...[
              const Text('Participants', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: _meeting.participants.map((p) => Chip(label: Text(p, style: const TextStyle(fontSize: 12)))).toList()),
              const SizedBox(height: 16),
            ],

            if (_meeting.agenda.isNotEmpty) ...[
              const Text('Agenda', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._meeting.agenda.asMap().entries.map((e) => CheckboxListTile(
                value: e.value.completed,
                title: Text(e.value.text),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  final newAgenda = List<AgendaItem>.from(_meeting.agenda);
                  newAgenda[e.key] = newAgenda[e.key].copyWith(completed: v ?? false);
                  setState(() => _meeting = _meeting.copyWith(agenda: newAgenda));
                  widget.notifier.updateMeeting(_meeting.id, {'agenda': newAgenda.map((a) => a.toJson()).toList()});
                },
              )),
              const SizedBox(height: 16),
            ],

            if (_meeting.aiNotes.isNotEmpty) ...[
              const Text('AI Notes', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withOpacity(0.2))), child: Text(_meeting.aiNotes)),
              const SizedBox(height: 16),
            ],

            if (_meeting.followUp.isNotEmpty) ...[
              const Text('Follow-up', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_meeting.followUp),
            ],

            const SizedBox(height: 24),
            // Status update buttons
            Text('Change Status', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: MeetingStatus.values.map((s) => ChoiceChip(
                label: Text(s.label),
                selected: _meeting.status == s,
                onSelected: (_) {
                  setState(() => _meeting = _meeting.copyWith(status: s));
                  widget.notifier.updateMeeting(_meeting.id, {'status': s.value});
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MeetingStatus status;
  const _StatusChip({required this.status});

  Color get _color {
    switch (status) {
      case MeetingStatus.scheduled: return Colors.blue;
      case MeetingStatus.inProgress: return Colors.orange;
      case MeetingStatus.completed: return Colors.green;
      case MeetingStatus.cancelled: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _color.withOpacity(0.3))),
      child: Text(status.label, style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w500)),
    );
  }
}

class _NewMeetingDialog extends StatefulWidget {
  const _NewMeetingDialog();

  @override
  State<_NewMeetingDialog> createState() => _NewMeetingDialogState();
}

class _NewMeetingDialogState extends State<_NewMeetingDialog> {
  final _titleController = TextEditingController();
  final _participantController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(hours: 1));
  final List<String> _participants = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Meeting'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'Meeting title', labelText: 'Title'), autofocus: true),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('MMM d, yyyy • h:mm a').format(_date)),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
                  if (t != null) setState(() => _date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                }
              },
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _participantController, decoration: const InputDecoration(hintText: 'Add participant'))),
              IconButton(icon: const Icon(Icons.add), onPressed: () {
                if (_participantController.text.trim().isNotEmpty) {
                  setState(() { _participants.add(_participantController.text.trim()); _participantController.clear(); });
                }
              }),
            ]),
            if (_participants.isNotEmpty) Wrap(spacing: 6, children: _participants.map((p) => Chip(label: Text(p, style: const TextStyle(fontSize: 12)), onDeleted: () => setState(() => _participants.remove(p)))).toList()),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          final title = _titleController.text.trim();
          if (title.isEmpty) return;
          Navigator.pop(context, {'title': title, 'date': _date.toIso8601String(), 'participants': _participants, 'tags': <String>[]});
        }, child: const Text('Create')),
      ],
    );
  }
}
