import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/theme_controller.dart';
import '../state/app_state.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().login(_loginCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Не удалось подключиться к серверу ($e)';
      });
    }
  }

  void _openThemeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _ThemeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.edit_note,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        ApiConfig.appName,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Учёт посещаемости занятий',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _loginCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Логин',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Войти'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Настройки',
                onPressed: _openThemeSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  static String _label(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.light:
        return 'Светлая';
      case AppThemeMode.dark:
        return 'Тёмная';
      case AppThemeMode.system:
        return 'Системная';
      case AppThemeMode.oled:
        return 'OLED (чёрная)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<ThemeController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Тема оформления',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioGroup<AppThemeMode>(
              groupValue: tc.mode,
              onChanged: (m) {
                tc.setMode(m ?? AppThemeMode.system);
                Navigator.pop(context);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final m in AppThemeMode.values)
                    RadioListTile<AppThemeMode>(
                      value: m,
                      title: Text(_label(m)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}