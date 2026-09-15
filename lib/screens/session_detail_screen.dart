import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../marks.dart';
import '../models/session.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import 'attendance_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  final Future<void> Function()? onChanged;
  const SessionDetailScreen({super.key, required this.sessionId, this.onChanged});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionDetail? _detail;
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
    try {
      final detail = await api.getSessionDetail(widget.sessionId);
      final students = await api.getStudents(detail.session.groupId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _students = students;
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

  Future<void> _toggleConfirm(SessionDetail detail) async {
    try {
      final api = context.read<AppState>().api;
      if (detail.session.confirmed) {
        await api.unconfirmSession(detail.session.id);
      } else {
        await api.confirmSession(detail.session.id);
      }
      await widget.onChanged?.call();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _export(String format, SessionInfo session) async {
    final api = context.read<AppState>().api;
    try {
      final dir = (await getApplicationDocumentsDirectory()).path;
      final path = await api.exportSession(session.id, format, dir);
      if (!mounted) return;
      final result = await OpenFilex.open(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.type == ResultType.done
                ? 'Файл открыт'
                : 'Файл сохранён: $path',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _showExportMenu(SessionInfo session) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Выгрузить рапортичку',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            for (final fmt in const [('pdf', 'PDF'), ('docx', 'DOCX'), ('xlsx', 'Excel')])
              ListTile(
                leading: Icon(
                  fmt.$1 == 'pdf'
                      ? Icons.picture_as_pdf
                      : fmt.$1 == 'docx'
                          ? Icons.description
                          : Icons.table_chart,
                ),
                title: Text(fmt.$2),
                onTap: () {
                  Navigator.pop(ctx);
                  _export(fmt.$1, session);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _detail?.session;
    final fmt = DateFormat('dd.MM.yyyy');
    final scheme = Theme.of(context).colorScheme;
    final isTeacher = context.read<AppState>().isTeacher;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сессия'),
        actions: [
          if (isTeacher && session != null && !session.confirmed)
            IconButton(
              tooltip: 'Изменить отметки',
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AttendanceScreen(sessionId: session.id),
                  ),
                );
                await _load();
              },
            ),
          if (_detail != null)
            IconButton(
              tooltip: 'Выгрузить',
              icon: const Icon(Icons.download),
              onPressed: () => _showExportMenu(session!),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _detail == null
                  ? const SizedBox()
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Card(
                          elevation: 0,
                          color: scheme.primaryContainer,
                          child: ListTile(
                            leading: const Icon(Icons.event),
                            title: Text(
                                '${session!.groupName ?? ''} • ${fmt.format(session.date)}'),
                            subtitle: Text(
                                'Пара ${session.pairNumber} — ${session.subjectName ?? '—'}'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          child: ListTile(
                            leading: Icon(
                              session.confirmed
                                  ? Icons.verified
                                  : Icons.pending_outlined,
                              color: session.confirmed
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            title: Text(session.confirmed
                                ? 'Подлинность подтверждена'
                                : 'Ожидает подтверждения'),
                            subtitle: session.confirmedAt != null
                                ? Text(
                                    'Подтверждено: ${
                                        DateFormat('dd.MM.yyyy HH:mm')
                                            .format(session.confirmedAt!.toLocal())}')
                                : null,
                            trailing: isTeacher
                                ? FilledButton.tonal(
                                    onPressed: () =>
                                        _toggleConfirm(_detail!),
                                    child: Text(session.confirmed
                                        ? 'Снять'
                                        : 'Подтвердить'),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Отметки студентов',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ..._buildRows(scheme),
                      ],
                    ),
    );
  }

  List<Widget> _buildRows(ColorScheme scheme) {
    final marksByStudent = {
      for (final r in _detail!.records) r.studentId: r.mark,
    };
    final commentsByStudent = {
      for (final r in _detail!.records)
        if (r.comment != null) r.studentId: r.comment!,
    };
    return _students.map((st) {
        final mark = Marks.byValue(marksByStudent[st.id] ?? 'present');
        final comment = commentsByStudent[st.id];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              ListTile(
                title: Text(st.fullName),
                trailing: Container(
                  width: 48,
                  height: 36,
                  decoration: BoxDecoration(
                    color: mark.color.withValues(alpha: 0.15),
                    border: Border.all(color: mark.color),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    mark.label,
                    style: TextStyle(
                      color: mark.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (comment != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          comment,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList();
  }
}