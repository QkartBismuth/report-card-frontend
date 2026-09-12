import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import 'session_detail_screen.dart';

class DaySessionsScreen extends StatefulWidget {
  final DateTime day;
  const DaySessionsScreen({super.key, required this.day});

  @override
  State<DaySessionsScreen> createState() => _DaySessionsScreenState();
}

class _DaySessionsScreenState extends State<DaySessionsScreen> {
  List<SessionInfo> _sessions = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppState>().api;
      final sessions = await api.getSessions(
        context.read<AppState>().groupId,
        dateFrom: widget.day,
        dateTo: widget.day,
      );
      sessions.sort((a, b) => a.pairNumber.compareTo(b.pairNumber));
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd.MM.yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text('Сессии ${fmt.format(widget.day)}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _sessions.length,
                    itemBuilder: (ctx, i) {
                      final s = _sessions[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: s.confirmed
                                ? scheme.primaryContainer
                                : scheme.tertiaryContainer,
                            child: Icon(
                              s.confirmed
                                  ? Icons.verified
                                  : Icons.pending_outlined,
                              color: s.confirmed
                                  ? scheme.onPrimaryContainer
                                  : scheme.onTertiaryContainer,
                            ),
                          ),
                          title: Text(
                              'Пара ${s.pairNumber} — ${s.subjectName ?? '—'}'),
                          subtitle: Text('${fmt.format(s.date)} • ${s.groupName ?? ''}'),
                          trailing: Chip(
                            label: Text(
                              s.confirmed ? 'Подтверждена' : 'Не подтверждена',
                              style: TextStyle(
                                fontSize: 11,
                                color: s.confirmed
                                    ? scheme.onPrimaryContainer
                                    : scheme.onTertiaryContainer,
                              ),
                            ),
                            backgroundColor: s.confirmed
                                ? scheme.primaryContainer
                                : scheme.tertiaryContainer,
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SessionDetailScreen(
                                  sessionId: s.id,
                                  onChanged: _load,
                                ),
                              ),
                            );
                            if (mounted) _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}