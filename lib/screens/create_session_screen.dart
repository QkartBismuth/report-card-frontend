import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule.dart';
import '../models/session.dart';
import '../models/subject.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import 'attendance_screen.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final DateTime _date = DateTime.now();
  final Set<int> _enabledPairs = {};
  final Map<int, int?> _pairSubj = {};

  int get _groupId => context.read<AppState>().groupId;
  List<Subject> _subjects = [];
  bool _loadingSubj = true;
  bool _creating = false;
  bool _useSchedule = false;
  List<ScheduleEntry> _scheduleEntries = [];
  bool _loadingSchedule = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final items = await context.read<AppState>().api.getSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = items;
        _loadingSubj = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSubj = false;
        _error = e.message;
      });
    }
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _loadingSchedule = true;
      _error = null;
    });
    try {
      final all = await context.read<AppState>().api.getSchedule(_groupId);
      if (!mounted) return;
      final today = _date.weekday;
      final entries = all
          .where((e) => e.dayOfWeek == today && !e.cancelled)
          .toList()
        ..sort((a, b) => a.pairNumber.compareTo(b.pairNumber));
      if (entries.isEmpty) {
        setState(() {
          _loadingSchedule = false;
          _useSchedule = false;
          _scheduleEntries = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Расписание на сегодня пустое')),
        );
        return;
      }
      setState(() {
        _scheduleEntries = entries;
        _useSchedule = true;
        _loadingSchedule = false;
        _enabledPairs
          ..clear()
          ..addAll(entries.map((e) => e.pairNumber));
        for (final e in entries) {
          if (_subjects.any((s) => s.id == e.subjectId)) {
            _pairSubj[e.pairNumber] = e.subjectId;
          } else {
            _pairSubj.remove(e.pairNumber);
          }
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSchedule = false;
        _useSchedule = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSchedule = false;
        _useSchedule = false;
        _error = 'Не удалось загрузить расписание';
      });
    }
  }

  void _switchToManual() {
    _useSchedule = false;
    _enabledPairs.clear();
    for (final p in _pairSubj.keys) {
      _pairSubj.remove(p);
    }
  }

  static String? _pairTime(ScheduleEntry e) {
    final t = [
      if (e.timeStart != null && e.timeStart!.isNotEmpty) e.timeStart,
      if (e.timeEnd != null && e.timeEnd!.isNotEmpty) e.timeEnd,
    ].join('–');
    final parts = [
      if (t.isNotEmpty) t,
      if (e.teacherFullName != null && e.teacherFullName!.isNotEmpty)
        e.teacherFullName!,
      if (e.classroom != null && e.classroom!.isNotEmpty) e.classroom!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _create() async {
    final selected = _enabledPairs.where((p) => _pairSubj[p] != null).toList()
      ..sort();
    final missing = _enabledPairs.where((p) => _pairSubj[p] == null).toList()
      ..sort();
    if (missing.isNotEmpty) {
      setState(() => _error = 'Выберите предмет для пар: ${missing.join(', ')}');
      return;
    }
    if (selected.isEmpty) {
      setState(() => _error = 'Отметьте хотя бы одну пару и выберите предмет');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });

    final api = context.read<AppState>().api;
    final created = <SessionInfo>[];
    final errors = <String>[];
    for (final pair in selected) {
      try {
        created.add(await api.createSession(
          groupId: _groupId,
          date: _date,
          pairNumber: pair,
          subjectId: _pairSubj[pair],
        ));
      } on ApiException catch (e) {
        errors.add('Пара $pair: ${e.message}');
      }
    }

    if (!mounted) return;
    if (created.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AttendanceScreen(sessionId: created.first.id),
        ),
      );
      return;
    }
    setState(() {
      _creating = false;
      _error = errors.join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = context.read<AppState>().group;

    return Scaffold(
      appBar: AppBar(title: const Text('Создать сессию')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (group != null)
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.groups),
                title: Text('Группа ${group.name}'),
                subtitle: const Text('Только текущий день'),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Расписание на день',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              if (_useSchedule && _scheduleEntries.isNotEmpty)
                TextButton.icon(
                  onPressed: _loadingSchedule
                      ? null
                      : () => setState(_switchToManual),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Вручную'),
                )
              else
                TextButton.icon(
                  onPressed: _loadingSchedule ? null : _loadSchedule,
                  icon: _loadingSchedule
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_available, size: 18),
                  label: Text(_loadingSchedule ? 'Загрузка…' : 'По расписанию'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingSubj)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_subjects.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Список предметов пуст. Сначала добавьте предметы.'),
              ),
            )
          else if (_useSchedule && _scheduleEntries.isNotEmpty)
            for (final e in _scheduleEntries)
              _PairCard(
                pair: e.pairNumber,
                subtitle: _pairTime(e),
                enabled: _enabledPairs.contains(e.pairNumber),
                subjectId: _pairSubj[e.pairNumber],
                subjects: _subjects,
                onToggle: (v) => setState(() {
                  if (v) {
                    _enabledPairs.add(e.pairNumber);
                  } else {
                    _enabledPairs.remove(e.pairNumber);
                    _pairSubj[e.pairNumber] = null;
                  }
                }),
                onSubjectChanged: (id) =>
                    setState(() => _pairSubj[e.pairNumber] = id),
              )
          else
            for (final pair in [1, 2, 3, 4])
              _PairCard(
                        pair: pair,
                        enabled: _enabledPairs.contains(pair),
                        subjectId: _pairSubj[pair],
                        subjects: _subjects,
                        onToggle: (v) => setState(() {
                          if (v) {
                            _enabledPairs.add(pair);
                          } else {
                            _enabledPairs.remove(pair);
                            _pairSubj[pair] = null;
                          }
                        }),
                        onSubjectChanged: (id) =>
                            setState(() => _pairSubj[pair] = id),
                      ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadingSubj || _creating ? null : _create,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Создать и отметить студентов'),
          ),
          const SizedBox(height: 12),
          Text(
            'Будут созданы сессии только для отмеченных пар. '
            'Пары, уже существующие в этот день, будут пропущены.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PairCard extends StatelessWidget {
  final int pair;
  final String? subtitle;
  final bool enabled;
  final int? subjectId;
  final List<Subject> subjects;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int?> onSubjectChanged;
  const _PairCard({
    required this.pair,
    this.subtitle,
    required this.enabled,
    required this.subjectId,
    required this.subjects,
    required this.onToggle,
    required this.onSubjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          CheckboxListTile(
            value: enabled,
            title: Text('Пара $pair'),
            subtitle: subtitle == null ? null : Text(subtitle!),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => onToggle(v ?? false),
          ),
          if (enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Предмет',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButton<int>(
                  value: subjectId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Выберите предмет'),
                  items: subjects
                      .map((d) =>
                          DropdownMenuItem(value: d.id, child: Text(d.name)))
                      .toList(),
                  onChanged: onSubjectChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }
}