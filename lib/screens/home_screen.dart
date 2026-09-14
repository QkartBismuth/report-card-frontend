import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update.dart';
import '../models/group.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import 'admin/admin_screen.dart';
import 'create_session_screen.dart';
import 'disciplines_screen.dart';
import 'export_screen.dart';
import 'login_screen.dart';
import 'schedule_screen.dart';
import 'sessions_list_screen.dart';
import 'students_screen.dart';
import 'upload_raport_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Group> _groups = [];
  bool _loadingGroups = true;
  String? _error;
  bool _updateDialogShown = false;
  final ValueNotifier<double> _updateProgress = ValueNotifier(0);

  Future<void> _loadGroups() async {
    final state = context.read<AppState>();
    try {
      var groups = await state.api.getGroups();
      final boundId = state.boundGroupId;
      if (boundId != null) {
        groups = groups.where((g) => g.id == boundId).toList();
      }
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loadingGroups = false;
        _error = null;
        if (state.group == null && groups.isNotEmpty) {
          state.setGroup(groups.first);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGroups = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingGroups = false;
        _error = 'Не удалось загрузить группы';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void dispose() {
    _updateProgress.dispose();
    super.dispose();
  }

  void _logout() {
    context.read<AppState>().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _checkForUpdate({bool manual = false}) async {
    if (!mounted || _updateDialogShown) return;
    try {
      final service = UpdateService();
      final current = AppVersion.parse(await service.getCurrentVersion());
      final latest = await service.fetchLatestRelease();
      if (!mounted || latest == null) return;
      if (!(AppVersion.parse(latest.version) > current)) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Установлена последняя версия')),
          );
        }
        return;
      }
      if (!manual) {
        final prefs = await SharedPreferences.getInstance();
        final skipped = prefs.getString('skip_update_version');
        if (skipped == latest.version) return;
      }
      if (!mounted) return;
      _showUpdateDialog(latest);
    } catch (_) {}
  }

  void _showUpdateDialog(AppUpdate u) {
    _updateDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Доступно обновление v${u.version}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (u.notes != null && u.notes!.trim().isNotEmpty)
                Text(u.notes!,
                    maxLines: 8, overflow: TextOverflow.ellipsis),
              if (u.size > 0) ...[
                const SizedBox(height: 8),
                Text('Размер: ${(u.size / 1048576).toStringAsFixed(1)} МБ',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _updateDialogShown = false;
              Navigator.of(ctx).pop();
              _skipUpdate(u.version);
            },
            child: const Text('Позже'),
          ),
          FilledButton.icon(
            onPressed: () {
              _updateDialogShown = false;
              Navigator.of(ctx).pop();
              _startUpdate(u);
            },
            icon: const Icon(Icons.system_update_alt),
            label: const Text('Обновить'),
          ),
        ],
      ),
    );
  }

  Future<void> _skipUpdate(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skip_update_version', version);
  }

  Future<void> _startUpdate(AppUpdate u) async {
    if (!mounted) return;
    _updateDialogShown = true;
    _updateProgress.value = 0;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Скачивание обновления'),
        content: ValueListenableBuilder<double>(
          valueListenable: _updateProgress,
          builder: (ctx, progress, _) => Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress >= 1 ? null : progress,
                ),
              ),
              const SizedBox(width: 12),
              Text(progress >= 1
                  ? '100%'
                  : '${(progress * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    );
    try {
      final path = await UpdateService().downloadApk(
        u,
        onProgress: (recv, total) {
          _updateProgress.value =
              (total != null && total > 0) ? recv / total : 1;
        },
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await UpdateService.installApk(path);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка обновления: $e')));
      }
    } finally {
      _updateDialogShown = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isTeacher = state.isTeacher;
    final isAdmin = state.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update_alt),
            tooltip: 'Проверить обновление',
            onPressed: () => _checkForUpdate(manual: true),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loadingGroups
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadGroups)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _UserCard(
                      name: state.user?.fullName ?? '',
                      role: isAdmin
                          ? 'Администратор'
                          : isTeacher
                              ? 'Преподаватель'
                              : 'Староста',
                      showRole: true,
                    ),
                    const SizedBox(height: 16),
                    _GroupSelector(
                      groups: _groups,
                      selected: state.group,
                      onChanged: (g) => context.read<AppState>().setGroup(g),
                    ),
                    const SizedBox(height: 16),
                    if (isAdmin)
                      _MenuCard(
                        icon: Icons.settings_applications_outlined,
                        title: 'Администрирование',
                        subtitle: 'Студенты, преподаватели, группы, устройства, подключение',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminScreen()),
                        ),
                      ),
                    if (isTeacher) ...[
                      _MenuCard(
                        icon: Icons.fact_check_outlined,
                        title: 'Сессии и подтверждение',
                        subtitle: 'Просмотр посещаемости, подтверждение подлинности',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SessionsListScreen()),
                        ),
                      ),
                      _MenuCard(
                        icon: Icons.calendar_month_outlined,
                        title: 'Расписание группы',
                        subtitle: 'Расписание КТК (просмотр)',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                        ),
                      ),
                      _MenuCard(
                        icon: Icons.download_outlined,
                        title: 'Выгрузить рапортичку',
                        subtitle: 'PDF / DOCX / Excel за день или период',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ExportScreen()),
                        ),
                      ),
                    ] else ...[
                      _MenuCard(
                        icon: Icons.add_circle_outline,
                        title: 'Создать сессию',
                        subtitle: 'Новая пара: дата, дисциплина, отметки',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateSessionScreen()),
                        ),
                      ),
                      _MenuCard(
                        icon: Icons.calendar_month_outlined,
                        title: 'Расписание',
                        subtitle: 'Загрузить из КТК, поправить, создать пары на сегодня',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                        ),
                      ),
                      _MenuCard(
                        icon: Icons.assignment_outlined,
                        title: 'Мои сессии',
                        subtitle: 'Список заполненных пар',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SessionsListScreen()),
                        ),
                      ),
                      _MenuCard(
                        icon: Icons.bookmark_outline,
                        title: 'Предметы',
                        subtitle: 'Каталог названий пар',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DisciplinesScreen()),
                        ),
                      ),
                      _MenuCard(
                        icon: Icons.people_outline,
                        title: 'Студенты',
                        subtitle: 'Добавить или удалить студента группы',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StudentsScreen()),
                        ),
                      ),
                      _MenuCard(
                        icon: Icons.upload_file_outlined,
                        title: 'Загрузить рапортичку',
                        subtitle: 'DOCX со списком студентов группы',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UploadRaportScreen()),
                        ),
                      ),
                    ],
                  ],
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

class _UserCard extends StatelessWidget {
  final String name;
  final String role;
  final bool showRole;
  const _UserCard({
    required this.name,
    required this.role,
    this.showRole = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: showRole ? Text('Роль: $role') : null,
      ),
    );
  }
}

class _GroupSelector extends StatelessWidget {
  final List<Group> groups;
  final Group? selected;
  final ValueChanged<Group> onChanged;
  const _GroupSelector({
    required this.groups,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Группы не найдены. Загрузите рапортичку со списком студентов.'),
        ),
      );
    }
    if (groups.length == 1) {
      return Card(
        elevation: 0,
        child: ListTile(
          leading: const Icon(Icons.groups),
          title: Text(groups.first.name),
        ),
      );
    }
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Группа',
            border: InputBorder.none,
          ),
          child: DropdownButton<Group>(
            value: selected,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: groups
                .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                .toList(),
            onChanged: (g) {
              if (g != null) onChanged(g);
            },
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}