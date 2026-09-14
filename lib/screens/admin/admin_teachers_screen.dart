import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  List<TeacherInfo> _teachers = [];
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
      final teachers = await api.getTeachers();
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
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
        _error = 'Не удалось загрузить преподавателей';
      });
    }
  }

  Future<void> _promptAdd() async {
    final saved = await Navigator.push<TeacherInfo>(
      context,
      MaterialPageRoute(
        builder: (_) => const _TeacherEditor(add: true),
      ),
    );
    if (saved != null) _load();
  }

  Future<void> _promptEdit(TeacherInfo t) async {
    final saved = await Navigator.push<TeacherInfo>(
      context,
      MaterialPageRoute(
        builder: (_) => _TeacherEditor(add: false, teacher: t),
      ),
    );
    if (saved != null) _load();
  }

  Future<void> _deleteTeacher(TeacherInfo t) async {
    final api = context.read<AppState>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить преподавателя?'),
        content: Text('${t.fullName} (${t.login})'),
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
      await api.deleteTeacher(t.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Преподаватель удалён')));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Преподаватели')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _teachers.isEmpty
                  ? const Center(child: Text('Преподаватели не добавлены'))
                  : ListView.builder(
                      itemCount: _teachers.length,
                      itemBuilder: (context, i) {
                        final t = _teachers[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              t.fullName.isNotEmpty ? t.fullName[0].toUpperCase() : '?',
                            ),
                          ),
                          title: Text(t.fullName),
                          subtitle: Text('Логин: ${t.login}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Изменить',
                                onPressed: () => _promptEdit(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Удалить',
                                onPressed: () => _deleteTeacher(t),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _promptAdd,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Добавить'),
      ),
    );
  }
}

class _TeacherEditor extends StatefulWidget {
  final bool add;
  final TeacherInfo? teacher;
  const _TeacherEditor({required this.add, this.teacher});

  @override
  State<_TeacherEditor> createState() => _TeacherEditorState();
}

class _TeacherEditorState extends State<_TeacherEditor> {
  late final TextEditingController _login;
  late final TextEditingController _fullName;
  late final TextEditingController _password;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _login = TextEditingController(text: widget.teacher?.login ?? '');
    _fullName = TextEditingController(text: widget.teacher?.fullName ?? '');
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _login.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = context.read<AppState>().api;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final TeacherInfo t;
      if (widget.add) {
        t = await api.addTeacher(
          login: _login.text.trim(),
          fullName: _fullName.text.trim(),
          password: _password.text,
        );
      } else {
        t = await api.updateTeacher(
          widget.teacher!.id,
          login: _login.text.trim() == widget.teacher!.login
              ? null
              : _login.text.trim(),
          fullName: _fullName.text.trim() == widget.teacher!.fullName
              ? null
              : _fullName.text.trim(),
          password: _password.text.isEmpty ? null : _password.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, t);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Не удалось сохранить';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.add ? 'Новый преподаватель' : 'Изменить преподавателя')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _fullName,
              autofocus: widget.add,
              decoration: const InputDecoration(
                labelText: 'ФИО',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _login,
              decoration: const InputDecoration(
                labelText: 'Логин',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: widget.add ? 'Пароль' : 'Новый пароль (оставьте пустым)',
                border: const OutlineInputBorder(),
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
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить'),
            ),
          ],
        ),
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