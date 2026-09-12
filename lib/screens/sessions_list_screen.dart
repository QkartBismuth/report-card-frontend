import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../utils/day_groups.dart';
import 'attendance_screen.dart';
import 'day_sessions_screen.dart';
import 'session_detail_screen.dart';

class SessionsListScreen extends StatefulWidget {
  const SessionsListScreen({super.key});

  @override
  State<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionsListScreenState extends State<SessionsListScreen> {
  List<SessionInfo> _sessions = [];
  bool _loading = true;
  String? _error;
  DateTime? _from;
  DateTime? _to;

  bool get _isTeacher => context.read<AppState>().isTeacher;

  Future<void> _load() async {
    final state = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await state.api.getSessions(
        state.groupId,
        dateFrom: _from,
        dateTo: _to,
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
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

  @override
  void initState() {
    super.initState();
    _load();
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

  void _open(SessionInfo s) {
    if (_isTeacher) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(
            sessionId: s.id,
            onChanged: _load,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceScreen(sessionId: s.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTeacher ? 'Сессии группы' : 'Мои сессии'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_from == null
                        ? 'С даты'
                        : 'с ${fmt.format(_from!)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.event),
                    label: Text(_to == null
                        ? 'По дату'
                        : 'по ${fmt.format(_to!)}'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Сбросить фильтр',
                  onPressed: () {
                    setState(() {
                      _from = null;
                      _to = null;
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _sessions.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Сессий не найдено.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: _isTeacher
                                ? _buildTeacherList(fmt)
                                : ListView.builder(
                                    itemCount: _sessions.length,
                                    itemBuilder: (ctx, i) {
                                      final s = _sessions[i];
                                      return _SessionCard(
                                        session: s,
                                        fmt: fmt,
                                        onTap: () => _open(s),
                                      );
                                    },
                                  ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherList(DateFormat fmt) {
    final groups = groupByDay(_sessions);
    return ListView.builder(
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
        final allConfirmed =
            g.sessions.isNotEmpty && g.sessions.every((s) => s.confirmed);
        final scheme = Theme.of(context).colorScheme;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  allConfirmed ? scheme.primaryContainer : scheme.tertiaryContainer,
              child: Icon(
                allConfirmed ? Icons.verified : Icons.pending_outlined,
                color: allConfirmed
                    ? scheme.onPrimaryContainer
                    : scheme.onTertiaryContainer,
              ),
            ),
            title: Text(fmt.format(g.date)),
            subtitle: Text(
              subjects.isEmpty
                  ? 'Пары: $pairs'
                  : 'Пары $pairs • ${subjects.join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Chip(
              label: Text(
                allConfirmed ? 'Подтверждено' : 'Ожидает',
                style: TextStyle(
                  fontSize: 11,
                  color: allConfirmed
                      ? scheme.onPrimaryContainer
                      : scheme.onTertiaryContainer,
                ),
              ),
              backgroundColor: allConfirmed
                  ? scheme.primaryContainer
                  : scheme.tertiaryContainer,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DaySessionsScreen(day: g.date),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionInfo session;
  final DateFormat fmt;
  final VoidCallback onTap;
  const _SessionCard({
    required this.session,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: session.confirmed
              ? scheme.primaryContainer
              : scheme.tertiaryContainer,
          child: Icon(
            session.confirmed ? Icons.verified : Icons.pending_outlined,
            color: session.confirmed
                ? scheme.onPrimaryContainer
                : scheme.onTertiaryContainer,
          ),
        ),
        title: Text('Пара ${session.pairNumber} — ${session.subjectName ?? '—'}'),
        subtitle: Text('${fmt.format(session.date)} • ${session.groupName ?? ''}'),
        trailing: Chip(
          label: Text(
            session.confirmed ? 'Подтверждена' : 'Не подтверждена',
            style: TextStyle(
              fontSize: 11,
              color: session.confirmed
                  ? scheme.onPrimaryContainer
                  : scheme.onTertiaryContainer,
            ),
          ),
          backgroundColor: session.confirmed
              ? scheme.primaryContainer
              : scheme.tertiaryContainer,
        ),
        onTap: onTap,
      ),
    );
  }
}