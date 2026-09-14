import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

class WifiService {
  static DateTime _lastAttempt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Автоподключение к школьной сети. Защита от спама системными диалогами:
  /// попытка не чаще 1 раза в 60 секунд и только если сеть ещё не активна.
  static Future<bool> connectToNetwork(String ssid, String password) async {
    if (!ssid.startsWith('WIFI:S:')) {
      final cur = await currentSsid();
      if (cur == ssid) return true;
    }
    final now = DateTime.now();
    if (now.difference(_lastAttempt) < const Duration(seconds: 60)) {
      return false;
    }
    _lastAttempt = now;

    if (!await _ensurePermission()) return false;

    try {
      final connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: password.isEmpty ? null : password,
        security: password.isEmpty
            ? NetworkSecurity.NONE
            : NetworkSecurity.WPA,
        joinOnce: false,
        withInternet: true,
        timeoutInSeconds: 45,
      );
      return connected;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> currentSsid() async {
    try {
      return await WiFiForIoTPlugin.getSSID();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _ensurePermission() async {
    if (await Permission.location.isGranted) return true;
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<bool> isConnected() async {
    try {
      return await WiFiForIoTPlugin.isConnected();
    } catch (_) {
      return false;
    }
  }
}