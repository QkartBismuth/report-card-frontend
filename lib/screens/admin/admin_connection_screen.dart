import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';

class AdminConnectionScreen extends StatefulWidget {
  const AdminConnectionScreen({super.key});

  @override
  State<AdminConnectionScreen> createState() => _AdminConnectionScreenState();
}

class _AdminConnectionScreenState extends State<AdminConnectionScreen> {
  late final TextEditingController _serverUrl;
  late final TextEditingController _wifiSsid;
  late final TextEditingController _wifiPassword;
  String _provider = 'ngrok';
  final TextEditingController _tokenCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  TunnelStatus? _tunnel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serverUrl = TextEditingController();
    _wifiSsid = TextEditingController();
    _wifiPassword = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _serverUrl.dispose();
    _wifiSsid.dispose();
    _wifiPassword.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await api.getServerConfig();
      TunnelStatus? tunnel;
      try {
        tunnel = await api.tunnelStatus();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _serverUrl.text = cfg.serverUrl ?? '';
        _wifiSsid.text = cfg.wifiSsid ?? '';
        _wifiPassword.text = cfg.wifiPassword ?? '';
        _tunnel = tunnel;
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
        _error = 'Не удалось загрузить конфигурацию';
      });
    }
  }

  Future<void> _saveConfig() async {
    final api = context.read<AppState>().api;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await api.updateServerConfig(
        serverUrl: _serverUrl.text.trim(),
        wifiSsid: _wifiSsid.text.trim(),
        wifiPassword: _wifiPassword.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Конфигурация сохранена (устройства обновят адрес за ~10 с)')));
      setState(() => _saving = false);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  Future<void> _tunnelStart() async {
    final api = context.read<AppState>().api;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final st = await api.tunnelStart(_provider,
          token: _tokenCtrl.text.trim().isEmpty
              ? null
              : _tokenCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _saving = false;
        _tunnel = st;
      });
      if (st.url != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Туннель запущен: ${st.url}'),
            duration: const Duration(seconds: 5)));
      } else if (st.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: ${st.error}')));
      }
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Не удалось запустить туннель';
      });
    }
  }

  Future<void> _tunnelStop() async {
    final api = context.read<AppState>().api;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final st = await api.tunnelStop();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _tunnel = st;
      });
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  Future<void> _tunnelSend() async {
    final api = context.read<AppState>().api;
    try {
      final r = await api.tunnelSendUrl();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r['ok'] == true
              ? 'URL туннеля разослан устройствам'
              : 'Не удалось: ${r['error']}')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = context.watch<AppState>().baseUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('Подключение и туннель')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Текущий адрес на этом устройстве',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                              const SizedBox(height: 4),
                              SelectableText(currentUrl),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _serverUrl,
                        decoration: const InputDecoration(
                          labelText: 'Адрес сервера (для всех устройств)',
                          hintText: 'http://192.168.0.10:8010',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _wifiSsid,
                        decoration: const InputDecoration(
                          labelText: 'Wi-Fi сеть (SSID)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _wifiPassword,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Пароль Wi-Fi',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saving ? null : _saveConfig,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Сохранить и разослать'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Устройства проверяют конфигурацию каждые ~10 секунд и '
                        'подключатся к новому адресу и Wi-Fi автоматически.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: 40),
                      Text(
                        'Туннель наружу (ngrok / cloudflared)',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        color: _tunnel?.running == true
                            ? Colors.green.withValues(alpha: 0.15)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                _tunnel?.running == true
                                    ? Icons.link
                                    : Icons.link_off,
                                color: _tunnel?.running == true
                                    ? Colors.green
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SelectableText(
                                  _tunnel?.running == true
                                      ? '${_tunnel?.provider ?? ''}\n${_tunnel?.url ?? 'URL пока недоступен'}'
                                      : _tunnel?.error != null &&
                                              _tunnel!.error!.isNotEmpty
                                          ? 'Остановлен (${_tunnel!.error})'
                                          : 'Туннель не запущен',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _provider,
                        decoration: const InputDecoration(
                          labelText: 'Провайдер туннеля',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'ngrok', child: Text('ngrok')),
                          DropdownMenuItem(
                              value: 'cloudflared',
                              child: Text('cloudflared (Cloudflare)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _provider = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tokenCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Токен (только для ngrok, необязательно)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _tunnelStart,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Запустить'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _tunnelStop,
                              icon: const Icon(Icons.stop),
                              label: const Text('Остановить'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _saving ? null : _tunnelSend,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Рассылать URL туннеля на устройства'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Требуются установленные на сервере программы ngrok или '
                        'cloudflared и исходящий интернет из школьной сети.',
                        style: Theme.of(context).textTheme.bodySmall,
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