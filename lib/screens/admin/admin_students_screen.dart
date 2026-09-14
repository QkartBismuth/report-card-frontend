import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin.dart';
import '../../models/group.dart';
import '../../models/student.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';

class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen> {
  List<Group> _groups = [];
  Group? _group;
  List<Student> _students = [];
  List<MonitorInfo> _monitors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await api.getGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _group = groups.isEmpty ? null : (groups.first);
        _loading = false;
      });
      if (_group != null) await _loadStudents();
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
        _error = 'Не удалось загрузить группы';
      });
    }
  }

  Future<void> _loadStudents() async {
    final api = context.read<AppState>().api;
    if (_group == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await api.getStudents(_group!.id);
      List<MonitorInfo> monitors;
      try {
        monitors = await api.getMonitors(groupId: _group!.id);
      } catch (_) {
        monitors = [];
      }
      if (!mounted) return;
      setState(() {
        _students = students;
        _monitors = monitors;
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
        _error = 'Не удалось загрузить студентов';
      });
    }
  }

  Future<void> _addStudent(String name) async {
    final api = context.read<AppState>().api;
    try {
      await api.addStudent(_group!.id, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Студент добавлен')));
      await _loadStudents();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _promptAdd() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый студент'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ФИО'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await _addStudent(name);
  }

  Future<void> _renameStudent(Student s) async {
    final api = context.read<AppState>().api;
    final ctrl = TextEditingController(text: s.fullName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ФИО'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == s.fullName) return;
    try {
      await api.renameStudent(s.id, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ФИО обновлено')));
      await _loadStudents();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteStudent(Student s) async {
    final api = context.read<AppState>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить студента?'),
        content: Text(s.fullName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteStudent(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Студент удалён')));
      await _loadStudents();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _appointMonitor({MonitorInfo? existing}) async {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Сначала добавьте студентов в группу'),
      ));
      return;
    }
    Student dropdownValue = _students.first;
    int? newStudentId;
    final loginCtrl =
        TextEditingController(text: existing?.login ?? _slug(dropdownValue.fullName));
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null
              ? 'Назначить старосту'
              : 'Переназначить старосту'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Student>(
                    initialValue: dropdownValue,
                    decoration: const InputDecoration(
                      labelText: 'Студент',
                      border: OutlineInputBorder(),
                    ),
                    items: _students
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.fullName,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (s) {
                      setDialogState(() {
                        dropdownValue = s!;
                        newStudentId = s.id;
                        if (existing == null) {
                          loginCtrl.text = _slug(s.fullName);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: loginCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Логин',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Введите логин' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? 'Пароль'
                          : 'Новый пароль (пусто — не менять)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (existing == null && (v == null || v.isEmpty)) {
                        return 'Введите пароль';
                      }
                      return null;
                    },
                  ),
                  if (existing != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Студент меняется только при выборе другого имени.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx, true);
              },
              child: Text(existing == null ? 'Назначить' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    if (!mounted) return;

    final api = context.read<AppState>().api;
    final login = loginCtrl.text.trim();
    final password = passCtrl.text;
    try {
      if (existing == null) {
        await api.createMonitor(
          studentId: dropdownValue.id,
          login: login,
          password: password,
        );
      } else {
        await api.updateMonitor(
          existing.id,
          studentId: newStudentId,
          login: login,
          password: password,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(existing == null ? 'Староста назначен' : 'Староста обновлён'),
      ));
      await _loadStudents();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteMonitor(MonitorInfo m) async {
    final api = context.read<AppState>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить старосту?'),
        content: Text(
            '${m.fullName} (${m.login}) больше не сможет отмечать посещаемость.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteMonitor(m.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Староста удалён')));
      await _loadStudents();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static String _slug(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? 'starosta' : parts.first.toLowerCase();
  }

  Widget _monitorCard() {
    final m = _monitors.isEmpty ? null : _monitors.first;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: m == null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.star,
            color: m == null
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(m == null ? 'Староста не назначен' : m.fullName),
        subtitle: Text(
            m == null ? 'Из списка студентов группы' : 'Логин: ${m.login}'),
        trailing: m == null
            ? FilledButton.tonal(
                onPressed: _students.isEmpty ? null : () => _appointMonitor(),
                child: const Text('Назначить'),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Переназначить / изменить логин и пароль',
                    onPressed: () => _appointMonitor(existing: m),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Удалить старосту',
                    onPressed: () => _deleteMonitor(m),
                  ),
                ],
              ),
        onTap: m == null
            ? (_students.isNotEmpty ? () => _appointMonitor() : null)
            : () => _appointMonitor(existing: m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Студенты групп')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    if (_groups.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButtonFormField<Group>(
                          initialValue: _group,
                          decoration: const InputDecoration(
                            labelText: 'Группа',
                            border: OutlineInputBorder(),
                          ),
                          items: _groups
                              .map((g) =>
                                  DropdownMenuItem(value: g, child: Text(g.name)))
                              .toList(),
                          onChanged: (g) {
                            setState(() => _group = g);
                            _loadStudents();
                          },
                        ),
                      ),
                    _monitorCard(),
                    Expanded(
                      child: _students.isEmpty
                          ? const Center(
                              child: Text('В группе пока нет студентов'),
                            )
                          : ListView.builder(
                              itemCount: _students.length,
                              itemBuilder: (context, i) {
                                final s = _students[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(s.fullName.isNotEmpty
                                        ? s.fullName[0].toUpperCase()
                                        : '?'),
                                  ),
                                  title: Text(s.fullName),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Переименовать',
                                        onPressed: () => _renameStudent(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Удалить',
                                        onPressed: () => _deleteStudent(s),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _groups.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _promptAdd,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Добавить студента'),
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

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