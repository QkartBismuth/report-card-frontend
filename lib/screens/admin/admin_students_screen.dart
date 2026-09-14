import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      if (!mounted) return;
      setState(() {
        _students = students;
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