import 'package:flutter/material.dart';

import 'admin_connection_screen.dart';
import 'admin_devices_screen.dart';
import 'admin_errors_screen.dart';
import 'admin_groups_screen.dart';
import 'admin_students_screen.dart';
import 'admin_teachers_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Администрирование')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminCard(
            icon: Icons.people_outline,
            title: 'Студенты групп',
            subtitle: 'Просмотр, добавление, переименование и удаление',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminStudentsScreen()),
            ),
          ),
          _AdminCard(
            icon: Icons.badge_outlined,
            title: 'Преподаватели',
            subtitle: 'Учётные записи преподавателей и кураторов',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminTeachersScreen()),
            ),
          ),
          _AdminCard(
            icon: Icons.groups_outlined,
            title: 'Группы и кураторы',
            subtitle: 'Создание групп, назначение куратора',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminGroupsScreen()),
            ),
          ),
          _AdminCard(
            icon: Icons.smartphone_outlined,
            title: 'Устройства',
            subtitle: 'Список подключённых устройств, их параметры',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDevicesScreen()),
            ),
          ),
          _AdminCard(
            icon: Icons.bug_report_outlined,
            title: 'Ошибки',
            subtitle: 'Отчёты об ошибках с устройств',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminErrorsScreen()),
            ),
          ),
          _AdminCard(
            icon: Icons.wifi_tethering_outlined,
            title: 'Подключение и туннель',
            subtitle: 'Адрес сервера, Wi-Fi, туннель наружу',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminConnectionScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _AdminCard({
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