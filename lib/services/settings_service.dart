import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _kServerUrl = 'server_url';
  static const _kDeviceId = 'device_id';

  String? serverUrl;
  String? deviceId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = prefs.getString(_kServerUrl);
    deviceId = prefs.getString(_kDeviceId);
  }

  Future<void> saveServerUrl(String? url) async {
    serverUrl = url;
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(_kServerUrl);
    } else {
      await prefs.setString(_kServerUrl, url);
    }
  }

  Future<String> getOrCreateDeviceId() async {
    if (deviceId != null) return deviceId!;
    final rng = Random();
    final id = 'dev-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}-'
        '${rng.nextInt(0xFFFFFFF).toRadixString(16)}';
    deviceId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceId, id);
    return id;
  }
}