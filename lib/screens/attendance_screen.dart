import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../marks.dart';
import '../models/session.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../widgets/student_mark_tile.dart';

class AttendanceScreen extends StatefulWidget {
  final int sessionId;
  const AttendanceScreen({super.key, required this.sessionId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  SessionDetail? _detail;
  List<Student> _students = [];
  Map<int, String> _marks = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    try {
      final detail = await api.getSessionDetail(widget.sessionId);
      final students =
          await api.getStudents(detail.session.groupId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _students = students;
        _marks = {
          for (final r in detail.records) r.studentId: r.mark,
        };
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppState>().api.updateRecords(widget.sessionId, _marks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Посещаемость сохранена')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _count(Mark m)
    => _marks.values.where((v) => v == m.value).length;

  @override
  Widget build(BuildContext context) {
    final session = _detail?.session;
    final fmt = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отметка студентов'),
        actions: [
          if (!_loading && _detail != null && !_detail!.session.confirmed)
            IconButton(
              tooltip: 'Сохранить',
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    _HeaderCard(session: session!, fmt: fmt),
                    if (session.confirmed)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          'Сессия подтверждена преподавателем. '
                          'Отметки изменять нельзя.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    _Legend(),
                    _Stats(markCounts: {
                      for (final m in Marks.all) m.label: _count(m),
                    }),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _students.length,
                        itemBuilder: (ctx, i) {
                          final st = _students[i];
                          return StudentMarkTile(
                            index: i,
                            fullName: st.fullName,
                            mark: _marks[st.id] ?? 'present',
                            onNext: session.confirmed
                                ? null
                                : () {
                                    setState(() {
                                      final current =
                                          Marks.byValue(_marks[st.id] ?? 'present');
                                      _marks[st.id] = Marks.next(current).value;
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final SessionInfo session;
  final DateFormat fmt;
  const _HeaderCard({required this.session, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.groupName ?? ''} • ${fmt.format(session.date)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Пара ${session.pairNumber} — ${session.subjectName ?? '—'}',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final m in Marks.all)
            Column(
              children: [
                Container(
                  width: 30,
                  height: 24,
                  decoration: BoxDecoration(
                    color: m.color.withValues(alpha: 0.15),
                    border: Border.all(color: m.color),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(m.label,
                      style: TextStyle(
                          color: m.color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 2),
                Text(
                  m.tooltip ?? '',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final Map<String, int> markCounts;
  const _Stats({required this.markCounts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        children: markCounts.entries
            .map((e) => Chip(
                  label: Text('${e.value}'),
                  avatar: Text(e.key),
                  visualDensity: VisualDensity.compact,
                ))
            .toList(),
      ),
    );
  }
}