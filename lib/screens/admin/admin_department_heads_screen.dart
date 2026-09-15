import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';

class AdminDepartmentHeadsScreen extends StatefulWidget {
  const AdminDepartmentHeadsScreen({super.key});

  @override
  State<AdminDepartmentHeadsScreen> createState() =>
      _AdminDepartmentHeadsScreenState();
}

class _AdminDepartmentHeadsScreenState
    extends State<AdminDepartmentHeadsScreen> {
  List<DepartmentHeadInfo> _heads = [];
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
      final heads = await api.getDepartmentHeads();
      if (!mounted) return;
      setState(() {
        _heads = heads;
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
        _error = 'Не удалось загрузить завотделения';
      });
    }
  }

  Future<void> _promptAdd() async {
    final saved = await Navigator.push<DepartmentHeadInfo>(
      context,
      MaterialPageRoute(
        builder: (_) => const _HeadEditor(add: true),
      ),
    );
    if (saved != null) _load();
  }

  Future<void> _promptEdit(DepartmentHeadInfo h) async {
    final saved = await Navigator.push<DepartmentHeadInfo>(
      context,
      MaterialPageRoute(
        builder: (_) => _HeadEditor(add: false, head: h),
      ),
    );
    if (saved != null) _load();
  }

  Future<void> _deleteHead(DepartmentHeadInfo h) async {
    final api = context.read<AppState>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить завотделения?'),
        content: Text('${h.fullName} (${h.login})'),
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
      await api.deleteDepartmentHead(h.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Завотделения удалён')));
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
      appBar: AppBar(title: const Text('Завотделения')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _heads.isEmpty
                  ? const Center(child: Text('Завотделения не добавлены'))
                  : ListView.builder(
                      itemCount: _heads.length,
                      itemBuilder: (context, i) {
                        final h = _heads[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              h.fullName.isNotEmpty
                                  ? h.fullName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(h.fullName),
                          subtitle: Text('Логин: ${h.login}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Изменить',
                                onPressed: () => _promptEdit(h),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Удалить',
                                onPressed: () => _deleteHead(h),
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

class _HeadEditor extends StatefulWidget {
  final bool add;
  final DepartmentHeadInfo? head;
  const _HeadEditor({required this.add, this.head});

  @override
  State<_HeadEditor> createState() => _HeadEditorState();
}

class _HeadEditorState extends State<_HeadEditor> {
  late final TextEditingController _login;
  late final TextEditingController _fullName;
  late final TextEditingController _password;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _login = TextEditingController(text: widget.head?.login ?? '');
    _fullName = TextEditingController(text: widget.head?.fullName ?? '');
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
      final DepartmentHeadInfo h;
      if (widget.add) {
        h = await api.addDepartmentHead(
          login: _login.text.trim(),
          fullName: _fullName.text.trim(),
          password: _password.text,
        );
      } else {
        h = await api.updateDepartmentHead(
          widget.head!.id,
          login: _login.text.trim() == widget.head!.login
              ? null
              : _login.text.trim(),
          fullName: _fullName.text.trim() == widget.head!.fullName
              ? null
              : _fullName.text.trim(),
          password: _password.text.isEmpty ? null : _password.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, h);
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
      appBar: AppBar(
          title: Text(
              widget.add ? 'Новый завотделения' : 'Изменить завотделения')),
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