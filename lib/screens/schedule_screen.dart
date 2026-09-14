import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule.dart';
import '../models/subject.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late int _groupId;
  int _selectedDay = DateTime.now().weekday;
  List<ScheduleEntry> _entries = [];
  List<Subject> _subjects = [];
  bool _loading = true;
  String? _error;

  bool get _canEdit =>
      !(context.read<AppState>().isTeacher);

  @override
  void initState() {
    super.initState();
    _groupId = context.read<AppState>().groupId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AppState>().api;
    try {
      final entries = await api.getSchedule(_groupId);
      final subjects = await api.getSubjects();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _subjects = subjects;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить расписание';
      });
    }
  }

  List<ScheduleEntry> _dayEntries() => _entries
      .where((e) => e.dayOfWeek == _selectedDay)
      .toList();

  Future<void> _import() async {
    final api = context.read<AppState>().api;
    String? msg;
    try {
      final res = await api.importSchedule(_groupId);
      msg = 'Загружено пар: ${res['entries_count'] ?? 0}';
      await _load();
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        final picked = await _showSourceWizard();
        if (picked == null) return;
        await api.setScheduleSource(_groupId,
            ktcBranchId: picked.$1, ktcGroupId: picked.$2);
        final res = await api.importSchedule(_groupId);
        msg = 'Источник подключён, загружено пар: ${res['entries_count'] ?? 0}';
        await _load();
      } else {
        msg = e.message;
      }
    } catch (_) {
      msg = 'Не удалось загрузить расписание';
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<(int, int)?> _showSourceWizard() async {
    final res = await Navigator.of(context).push<(int, int, String)?>(
      MaterialPageRoute(builder: (_) => const _KtcSourceWizardScreen()),
    );
    if (res == null) return null;
    return (res.$1, res.$2);
  }

  Future<void> _createToday() async {
    final api = context.read<AppState>().api;
    final mode = await _chooseMode();
    if (mode == null) return;
    try {
      final res =
          await api.createSessionsFromSchedule(_groupId, date: DateTime.now(), mode: mode);
      if (!mounted) return;
      final skipped = res.skipped
          .map((s) => 'пара ${s['pair_number']} — ${s['reason']}')
          .join('\n');
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(res.createdCount > 0
              ? 'Создано пар: ${res.createdCount}'
              : 'Новых пар нет'),
          content: Builder(builder: (_) => SingleChildScrollView(
                child: Text(
                  res.skippedCount > 0 ? 'Пропущено:\n$skipped' : 'Все пары созданы',
                ),
              )),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ошибка создания пар')));
    }
  }

  Future<String?> _chooseMode() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Создать пары на сегодня'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('missing'),
            child: const ListTile(
              leading: Icon(Icons.add),
              title: Text('Дописать недостающие пары'),
              subtitle: Text('Существующие не трогаются'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('resync'),
            child: const ListTile(
              leading: Icon(Icons.autorenew),
              title: Text('Синхронизировать по расписанию'),
              subtitle: Text(
                  'Создать недостающие и удалить лишние неподтверждённые пары'),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditor({ScheduleEntry? entry, int? pairNumber}) {
    final day = _selectedDay;
    if (!_canEdit) return;
    showModalBottomSheet<ScheduleEntry?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EntryEditorSheet(
        entry: entry,
        day: day,
        pairNumber: pairNumber,
        subjects: _subjects,
        groupId: _groupId,
        onChanged: (e) {
          if (mounted) {
            setState(() => _entries = List.of(_entries));
          }
        },
      ),
    ).then((created) {
      if (created != null && mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dayEntries = _dayEntries();
    final daysWithEntries = {for (final e in _entries) e.dayOfWeek};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBlock(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    if (_canEdit) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _import,
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: const Text('Загрузить из КТК'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _createToday,
                                icon: const Icon(Icons.event_available),
                                label: const Text('Создать на сегодня'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: 48,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: 7,
                        itemBuilder: (ctx, i) {
                          final d = i + 1;
                          final active = d == _selectedDay;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${kDayNames[d]}${daysWithEntries.contains(d) ? ' •' : ''}'),
                              selected: active,
                              onSelected: (_) => setState(() => _selectedDay = d),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: dayEntries.isEmpty
                          ? _EmptyDay(
                              canEdit: _canEdit,
                              onAdd: _canEdit
                                  ? () => _openEditor()
                                  : null,
                              onImport: _canEdit ? _import : null,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: dayEntries.length,
                              itemBuilder: (ctx, i) => _LessonCard(
                                entry: dayEntries[i],
                                onTap: _canEdit
                                    ? () => _openEditor(entry: dayEntries[i])
                                    : null,
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Добавить пару'),
            )
          : null,
    );
  }
}

class _LessonCard extends StatelessWidget {
  final ScheduleEntry entry;
  final VoidCallback? onTap;
  const _LessonCard({required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subject = entry.subjectName ?? 'Без предмета';
    final teacher = (entry.teacherFullName ?? entry.teacherName) ?? '';
    final time =
        (entry.timeStart != null && entry.timeEnd != null) ? '${entry.timeStart}–${entry.timeEnd}' : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: entry.cancelled ? scheme.surfaceContainerHighest : null,
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${entry.pairNumber}'),
        ),
        title: Text(
          subject,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: entry.cancelled ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          [
            ?time,
            if (teacher.isNotEmpty) teacher,
            if ((entry.classroom ?? '').isNotEmpty) 'каб. ${entry.classroom}',
            if (entry.cancelled) 'Отменён',
          ].join(' · '),
        ),
        trailing: onTap != null ? const Icon(Icons.edit_outlined) : null,
        onTap: onTap,
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final bool canEdit;
  final VoidCallback? onAdd;
  final VoidCallback? onImport;
  const _EmptyDay({required this.canEdit, this.onAdd, this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('В этот день пар нет',
                style: TextStyle(fontSize: 16)),
            if (canEdit) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Загрузить расписание недели'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Добавить пару вручную'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryEditorSheet extends StatefulWidget {
  final ScheduleEntry? entry;
  final int day;
  final int? pairNumber;
  final List<Subject> subjects;
  final int groupId;
  final ValueChanged<ScheduleEntry> onChanged;
  const _EntryEditorSheet({
    required this.entry,
    required this.day,
    required this.pairNumber,
    required this.subjects,
    required this.groupId,
    required this.onChanged,
  });

  @override
  State<_EntryEditorSheet> createState() => _EntryEditorSheetState();
}

class _EntryEditorSheetState extends State<_EntryEditorSheet> {
  late final bool _isNew = widget.entry == null;
  int? _subjectId;
  final _newSubjectCtrl = TextEditingController();
  final _classroomCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _pairCtrl = TextEditingController();
  bool _cancelled = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _subjectId = e?.subjectId;
    _pairCtrl.text =
        '${e?.pairNumber ?? widget.pairNumber ?? 1}';
    _classroomCtrl.text = e?.classroom ?? '';
    _teacherCtrl.text = e?.teacherName ?? '';
    _cancelled = e?.cancelled ?? false;
  }

  @override
  void dispose() {
    _newSubjectCtrl.dispose();
    _classroomCtrl.dispose();
    _teacherCtrl.dispose();
    _pairCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = context.read<AppState>().api;
    setState(() {
      _saving = true;
      _error = null;
    });
    final pair = int.tryParse(_pairCtrl.text.trim());
    if (pair == null || pair < 1) {
      setState(() {
        _saving = false;
        _error = 'Укажите корректный номер пары';
      });
      return;
    }
    try {
      if (_subjectId == null && _newSubjectCtrl.text.trim().isEmpty) {
        setState(() {
          _saving = false;
          _error = 'Выберите или укажите предмет';
        });
        return;
      }
      final entry = widget.entry;
      if (entry == null) {
        await api.addScheduleEntry(
          widget.groupId,
          dayOfWeek: widget.day,
          pairNumber: pair,
          subjectId: _subjectId,
          subjectName: _subjectId == null ? _newSubjectCtrl.text.trim() : null,
          teacherName: _teacherCtrl.text.trim().isEmpty
              ? null
              : _teacherCtrl.text.trim(),
          classroom: _classroomCtrl.text.trim().isEmpty
              ? null
              : _classroomCtrl.text.trim(),
          cancelled: _cancelled,
        );
      } else {
        await api.updateScheduleEntry(
          entry.id,
          dayOfWeek: widget.day,
          pairNumber: pair,
          subjectId: _subjectId,
          subjectName: _subjectId == null ? _newSubjectCtrl.text.trim() : null,
          teacherName: _teacherCtrl.text.trim().isEmpty
              ? null
              : _teacherCtrl.text.trim(),
          classroom: _classroomCtrl.text.trim().isEmpty
              ? null
              : _classroomCtrl.text.trim(),
          cancelled: _cancelled,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Не удалось сохранить';
      });
    }
  }

  Future<void> _delete() async {
    final api = context.read<AppState>().api;
    final entry = widget.entry;
    if (entry == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить пару?'),
        content: Text(
            'Пара ${entry.pairNumber} (${entry.subjectName ?? ''}) будет удалена из расписания.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteScheduleEntry(entry.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canEditSubjects = _subjectId == null;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isNew ? 'Добавить пару — ${kDayNames[widget.day]}' : 'Пара ${widget.entry?.pairNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _subjectId,
              decoration: const InputDecoration(
                labelText: 'Предмет',
                border: OutlineInputBorder(),
              ),
              items: [
                ...widget.subjects.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name),
                    )),
                const DropdownMenuItem(
                  value: null,
                  child: Text('— новый предмет —'),
                ),
              ],
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            if (canEditSubjects) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _newSubjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название нового предмета',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _pairCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Номер пары',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teacherCtrl,
              decoration: const InputDecoration(
                labelText: 'Преподаватель (краткое ФИО)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _classroomCtrl,
              decoration: const InputDecoration(
                labelText: 'Кабинет',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Пара отменена'),
              value: _cancelled,
              onChanged: (v) => setState(() => _cancelled = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (!_isNew)
                  IconButton(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Удалить',
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KtcSourceWizardScreen extends StatefulWidget {
  const _KtcSourceWizardScreen();

  @override
  State<_KtcSourceWizardScreen> createState() => _KtcSourceWizardScreenState();
}

class _KtcSourceWizardScreenState extends State<_KtcSourceWizardScreen> {
  bool _loading = true;
  String? _error;
  List<KtcBranch> _branches = [];
  List<KtcCourse> _courses = [];
  int? _selectedBranchId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final api = context.read<AppState>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await api.getKtcBranches();
      if (!mounted) return;
      setState(() {
        _branches = branches;
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

  Future<void> _loadCourses(int branchId) async {
    final api = context.read<AppState>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courses = await api.getKtcCourses(branchId);
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _selectedBranchId = branchId;
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

  List<KtcGroup> get _filteredGroups {
    if (_selectedBranchId == null) return [];
    final q = _query.trim().toLowerCase();
    final all = <KtcGroup>[];
    for (final c in _courses) {
      all.addAll(c.groups);
    }
    if (q.isEmpty) return all;
    return all.where((g) => g.title.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedBranchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Выберите отделение КТК')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorBlock(message: _error!, onRetry: _loadBranches)
                : ListView.builder(
                    itemCount: _branches.length,
                    itemBuilder: (ctx, i) => ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(_branches[i].title),
                      onTap: () => _loadCourses(_branches[i].id),
                    ),
                  ),
      );
    }
    final groups = _filteredGroups;
    return Scaffold(
      appBar: AppBar(
        title: Text('Выберите группу'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _selectedBranchId = null;
            _courses = [];
          }),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск группы (например, БД.09.23.1)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : groups.isEmpty
                    ? const Center(child: Text('Группы не найдены'))
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (ctx, i) {
                          final g = groups[i];
                          return ListTile(
                            leading: const Icon(Icons.groups_outlined),
                            title: Text(g.title),
                            onTap: () => Navigator.of(context)
                                .pop((_selectedBranchId!, g.id, g.title)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}