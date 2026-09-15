import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/admin.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/wifi_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api;
  final AuthService auth;
  final SettingsService settings;

  AppUser? user;
  String? token;
  Group? activeGroup;
  bool initialized = false;

  Timer? _pushTimer;
  int _lastConfigVersion = 0;
  bool _silentPollFailure = false;

  AppState({ApiService? api, AuthService? auth})
      : api = api ?? ApiService(),
        auth = auth ?? AuthService(),
        settings = SettingsService();

  bool get isTeacher => user?.isTeacher ?? false;
  bool get isMonitor => user?.isMonitor ?? false;
  bool get isAdmin => user?.isAdmin ?? false;
  bool get isDepartmentHead => user?.isDepartmentHead ?? false;
  Group? get group => activeGroup;
  int get groupId => activeGroup?.id ?? -1;
  String get baseUrl => api.baseUrl;
  bool get pushingActive => _pushTimer != null;

  void updateUser(AppUser u) {
    user = u;
    notifyListeners();
  }

  void setGroup(Group g) {
    activeGroup = g;
    notifyListeners();
  }

  Future<void> init() async {
    await settings.load();
    if (settings.serverUrl != null) {
      api.setBaseUrl(settings.serverUrl!);
    }
    final s = await auth.loadSession();
    if (s != null) {
      token = s.token;
      api.setToken(s.token);
      user = s.user;
      _startPushPolling();
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> login(String login, String password) async {
    final data = await api.login(login, password);
    final u = AppUser(
      id: data['user_id'],
      login: login,
      fullName: data['full_name'],
      role: data['role'],
      groupId: data['group_id'] as int?,
    );
    token = data['access_token'];
    user = u;
    api.setToken(token);
    await auth.saveSession(token!, u);
    _startPushPolling();
    unawaited(registerDevice());
    notifyListeners();
  }

  int? get boundGroupId => user?.groupId;

  Future<void> logout() async {
    _stopPushPolling();
    await auth.clear();
    token = null;
    user = null;
    activeGroup = null;
    api.setToken(null);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPushPolling();
    super.dispose();
  }

  // --------------- Device telemetry ---------------

  Future<void> registerDevice() async {
    try {
      final deviceId = await settings.getOrCreateDeviceId();
      final info = await DeviceInfoPlugin().androidInfo;
      await api.registerDevice(
        deviceId: deviceId,
        model: info.model,
        manufacturer: info.manufacturer,
        osVersion: '${info.version.release} (SDK ${info.version.sdkInt})',
        appVersion: _appVersion,
      );
    } catch (_) {}
  }

  Future<void> reportError(String message, [String? stack]) async {
    if (token == null) return;
    try {
      final deviceId = await settings.getOrCreateDeviceId();
      await api.reportError(RequestError(
        deviceId: deviceId,
        appVersion: _appVersion,
        message: message,
        stack: stack,
      ));
    } catch (_) {}
  }

  static String get _appVersion =>
      const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  // --------------- Push polling ---------------

  void _startPushPolling() {
    _pushTimer?.cancel();
    _lastConfigVersion = 0;
    _pushTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_pollPush());
    });
    unawaited(_pollPush());
  }

  void _stopPushPolling() {
    _pushTimer?.cancel();
    _pushTimer = null;
  }

  Future<void> _pollPush() async {
    if (token == null) return;
    try {
      final cfg = await api.getPushConfig();
      final changed = cfg.version != _lastConfigVersion || _silentPollFailure;
      _silentPollFailure = false;
      if (changed) {
        _lastConfigVersion = cfg.version;
        if (cfg.serverUrl != null &&
            cfg.serverUrl!.isNotEmpty &&
            cfg.serverUrl != api.baseUrl) {
          api.setBaseUrl(cfg.serverUrl!);
          await settings.saveServerUrl(cfg.serverUrl);
        }
        if (cfg.wifiSsid != null && cfg.wifiSsid!.isNotEmpty) {
          unawaited(WifiService.connectToNetwork(cfg.wifiSsid!, cfg.wifiPassword ?? ''));
        }
      }
    } catch (_) {
      _silentPollFailure = true;
    }
  }
}