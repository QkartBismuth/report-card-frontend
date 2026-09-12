import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
    final fmt = DateFormat('dd.MM.yyyy');
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
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Дата'),
              subtitle: Text(fmt.format(_date)),
              trailing: const Icon(Icons.lock_outline, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Расписание на день',
                style: TextStyle(fontWeight: FontWeight.w600)),
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
  final bool enabled;
  final int? subjectId;
  final List<Subject> subjects;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int?> onSubjectChanged;
  const _PairCard({
    required this.pair,
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