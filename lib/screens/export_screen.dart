import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../utils/day_groups.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _singleMode = true;
  String _format = 'pdf';
  DateTime? _from;
  DateTime? _to;
  SessionInfo? _selected;
  DateTime? _selectedDay;
  List<SessionInfo> _sessions = [];
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  int get _groupId => context.read<AppState>().groupId;

  bool get _isTeacher => context.read<AppState>().isTeacher;

  Future<void> _loadSessions() async {
    setState(() {
      _error = null;
    });
    try {
      final list =
          await context.read<AppState>().api.getSessions(_groupId);
      if (!mounted) return;
      setState(() {
        _sessions = list;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    }
  }

  Future<void> _pickSession() async {
    if (_sessions.isEmpty) await _loadSessions();
    if (!mounted) return;
    if (_sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессии не найдены')),
      );
      return;
    }
    final fmt = DateFormat('dd.MM.yyyy');
    if (_isTeacher) {
      final picked = await showModalBottomSheet<DateTime>(
        context: context,
        builder: (ctx) {
          final groups = groupByDay(_sessions);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Выберите день',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: groups.length,
                    itemBuilder: (ctx, i) {
                      final g = groups[i];
                      final subjects = {
                        for (final s in g.sessions)
                          if (s.subjectName != null) s.subjectName!,
                      }.toList();
                      final pairs = g.sessions
                          .map((s) => s.pairNumber)
                          .join(', ');
                      return ListTile(
                        title: Text(fmt.format(g.date)),
                        subtitle: Text(
                          subjects.isEmpty
                              ? 'Пары: $pairs'
                              : 'Пары $pairs • ${subjects.join(', ')}',
                        ),
                        trailing: g.sessions.every((s) => s.confirmed)
                            ? const Icon(Icons.verified, color: Colors.green)
                            : null,
                        onTap: () => Navigator.pop(ctx, g.date),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (picked != null) {
        setState(() {
          _selectedDay = picked;
          _selected = null;
        });
      }
      return;
    }
    final picked = await showModalBottomSheet<SessionInfo>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Выберите сессию',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sessions.length,
                itemBuilder: (ctx, i) {
                  final s = _sessions[i];
                  return ListTile(
                    title: Text(
                        'Пара ${s.pairNumber} — ${s.subjectName ?? '—'}'),
                    subtitle: Text(fmt.format(s.date)),
                    trailing: s.confirmed
                        ? const Icon(Icons.verified, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(ctx, s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _to = d);
  }

  Future<void> _download() async {
    final api = context.read<AppState>().api;
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      final dir = (await getApplicationDocumentsDirectory()).path;
      final String path;
      if (_singleMode) {
        if (_isTeacher) {
          if (_selectedDay == null) {
            throw ApiException(0, 'Выберите день');
          }
          path = await api.exportGroup(
            _groupId,
            dateFrom: _selectedDay!,
            dateTo: _selectedDay!,
            format: _format,
            saveDir: dir,
          );
        } else {
          if (_selected == null) {
            throw ApiException(0, 'Выберите сессию');
          }
          path = await api.exportSession(_selected!.id, _format, dir);
        }
      } else {
        if (_from == null || _to == null) {
          throw ApiException(0, 'Укажите период');
        }
        path = await api.exportGroup(
          _groupId,
          dateFrom: _from!,
          dateTo: _to!,
          format: _format,
          saveDir: dir,
        );
      }
      if (!mounted) return;
      final result = await OpenFilex.open(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.type == ResultType.done
                ? 'Файл сохранён и открыт'
                : 'Файл сохранён: $path',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'Ошибка: $e';
      });
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Выгрузка рапортички')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(_isTeacher ? 'Один день' : 'Одна сессия'),
                icon: const Icon(Icons.looks_one),
              ),
              ButtonSegment(
                value: false,
                label: const Text('Период'),
                icon: const Icon(Icons.date_range),
              ),
            ],
            selected: {_singleMode},
            onSelectionChanged: (s) =>
                setState(() => _singleMode = s.first),
          ),
          const SizedBox(height: 16),
if (_singleMode)
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text(
                  _isTeacher
                      ? (_selectedDay == null
                          ? 'Выберите день'
                          : fmt.format(_selectedDay!))
                      : (_selected == null
                          ? 'Выберите сессию'
                          : 'Пара ${_selected!.pairNumber} — '
                              '${_selected!.subjectName ?? '—'}'),
                ),
                subtitle: _isTeacher
                    ? const Text('Все пары выбранного дня')
                    : _selected == null
                        ? null
                        : Text(fmt.format(_selected!.date)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickSession,
              ),
            )
          else
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(_from == null
                        ? 'Дата начала'
                        : fmt.format(_from!)),
                    onTap: _pickFrom,
                  ),
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(
                        _to == null ? 'Дата окончания' : fmt.format(_to!)),
                    onTap: _pickTo,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Формат файла',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  RadioGroup<String>(
                    groupValue: _format,
                    onChanged: (v) => setState(() => _format = v!),
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          value: 'pdf',
                          title: Text('PDF'),
                          dense: true,
                        ),
                        RadioListTile<String>(
                          value: 'docx',
                          title: Text('DOCX (Word)'),
                          dense: true,
                        ),
                        RadioListTile<String>(
                          value: 'xlsx',
                          title: Text('Excel'),
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
            onPressed: _downloading ? null : _download,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: const Text('Скачать'),
          ),
        ],
      ),
    );
  }
}