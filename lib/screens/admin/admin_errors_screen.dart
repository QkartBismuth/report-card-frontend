import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';

class AdminErrorsScreen extends StatefulWidget {
  const AdminErrorsScreen({super.key});

  @override
  State<AdminErrorsScreen> createState() => _AdminErrorsScreenState();
}

class _AdminErrorsScreenState extends State<AdminErrorsScreen> {
  List<ErrorInfo> _errors = [];
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
      final errors = await api.getErrors();
      if (!mounted) return;
      setState(() {
        _errors = errors;
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
        _error = 'Не удалось загрузить ошибки';
      });
    }
  }

  Future<void> _clearAll() async {
    final api = context.read<AppState>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить все ошибки?'),
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
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await api.clearErrors();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Удалено ошибок: $n')));
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
      appBar: AppBar(
        title: const Text('Ошибки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Очистить',
            onPressed: _errors.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _errors.isEmpty
                  ? const Center(child: Text('Ошибок не зарегистрировано'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _errors.length,
                        itemBuilder: (context, i) {
                          final e = _errors[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.orangeAccent,
                                child: Icon(Icons.bug_report, color: Colors.white),
                              ),
                              title: Text(
                                e.message.length > 100
                                    ? '${e.message.substring(0, 100)}...'
                                    : e.message,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (e.deviceId != null)
                                    Text('Устройство: ${e.deviceId}'),
                                  if (e.appVersion != null)
                                    Text('Версия: ${e.appVersion}'),
                                  if (e.createdAt != null)
                                    Text('Время: ${_fmt(e.createdAt!)}'),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  static String? _fmt(String raw) {
    try {
      return DateTime.parse(raw).toLocal().toString().substring(0, 19);
    } catch (_) {
      return raw;
    }
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