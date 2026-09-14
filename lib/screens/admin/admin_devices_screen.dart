import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';

class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
  List<DeviceInfo> _devices = [];
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
      final devices = await api.getDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
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
        _error = 'Не удалось загрузить устройства';
      });
    }
  }

  Future<void> _clearAll() async {
    final api = context.read<AppState>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить список устройств?'),
        content: const Text('Записи будут удалены, устройства появятся вновь при следующем подключении.'),
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
      final n = await api.clearDevices();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Удалено устройств: $n')));
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
        title: const Text('Устройства'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Очистить',
            onPressed: _devices.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _devices.isEmpty
                  ? const Center(child: Text('Устройства ещё не подключались'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, i) {
                          final d = _devices[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(
                                  d.platform == 'ios'
                                      ? Icons.phone_iphone
                                      : Icons.smartphone,
                                ),
                              ),
                              title: Text(
                                d.model != null && d.model!.isNotEmpty
                                    ? d.model!
                                    : d.deviceId,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (d.manufacturer != null &&
                                      d.manufacturer!.isNotEmpty)
                                    Text(d.manufacturer!),
                                  if (d.osVersion != null &&
                                      d.osVersion!.isNotEmpty)
                                    Text('OS: ${d.osVersion}'),
                                  Text('IP: ${d.ip ?? '—'}'),
                                  if (d.lastSeen != null)
                                    Text('Был(а): ${_fmt(d.lastSeen!)}'),
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