import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';

class AdminGroupsScreen extends StatefulWidget {
  const AdminGroupsScreen({super.key});

  @override
  State<AdminGroupsScreen> createState() => _AdminGroupsScreenState();
}

class _AdminGroupsScreenState extends State<AdminGroupsScreen> {
  List<AdminGroup> _groups = [];
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
      final groups = await api.getGroups();
      final teachers = await api.getTeachers();
      if (!mounted) return;
      setState(() {
        _groups = groups
            .map((g) => AdminGroup(
                  id: g.id,
                  name: g.name,
                  year: g.year,
                  curatorId: g.curatorId,
                  curatorName: g.curatorName,
                ))
            .toList();
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
        _error = 'Не удалось загрузить группы';
      });
    }
  }

  Future<void> _createGroup() async {
    final api = context.read<AppState>().api;
    final nameCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая группа'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Название группы'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: yearCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Год (необязательно)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (created != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final year = int.tryParse(yearCtrl.text.trim());
    try {
      await api.addGroup(name, year: year);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Группа создана')));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editGroup(AdminGroup g) async {
    final api = context.read<AppState>().api;
    TextEditingController? nameCtrl;
    TextEditingController? yearCtrl;
    final result = await showDialog<({String? name, int? year, int? curatorId, bool clear})>(
      context: context,
      builder: (ctx) {
        nameCtrl = TextEditingController(text: g.name);
        yearCtrl = TextEditingController(text: g.year?.toString() ?? '');
        var curatorId = g.curatorId;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Изменить группу'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Название группы'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Год'),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int?>(
                    initialValue: curatorId,
                    decoration: const InputDecoration(
                      labelText: 'Куратор',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('— без куратора —'),
                      ),
                      for (final t in _teachers)
                        DropdownMenuItem<int?>(
                          value: t.id,
                          child: Text(t.fullName),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() => curatorId = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  (
                    name: nameCtrl!.text.trim(),
                    year: int.tryParse(yearCtrl!.text.trim()),
                    curatorId: curatorId,
                    clear: false,
                  ),
                ),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    try {
      await api.updateGroup(
        g.id,
        name: result.name == g.name ? null : result.name,
        year: result.year ?? g.year,
        curatorId: result.curatorId,
        clearCurator: result.curatorId == null && g.curatorId != null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Группа обновлена')));
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
      appBar: AppBar(title: const Text('Группы и кураторы')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _groups.isEmpty
                  ? const Center(child: Text('Группы ещё не созданы'))
                  : ListView.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, i) {
                        final g = _groups[i];
                        final curIdx = _teachers.indexWhere(
                            (t) => t.id == g.curatorId);
                        final curator =
                            curIdx >= 0 ? _teachers[curIdx] : null;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            title: Text(g.name,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              g.year != null ? 'Год: ${g.year}' : '',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(
                                    curator?.fullName ?? 'Нет куратора',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: curator == null
                                          ? Theme.of(context).disabledColor
                                          : null,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Изменить',
                                  onPressed: () => _editGroup(g),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Создать группу'),
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