import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_update.dart';

class UpdateService {
  static const String _repo = 'QkartBismuth/report-card-frontend';
  static const String _latestUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  Future<AppUpdate?> fetchLatestRelease() async {
    try {
      final resp = await http
          .get(Uri.parse(_latestUrl), headers: {
            'User-Agent': 'Raporticka/1',
            'Accept': 'application/vnd.github+json',
          })
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final u = AppUpdate.fromReleaseJson(data);
      return u.hasUrl ? u : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<String> downloadApk(
    AppUpdate u, {
    void Function(int bytesReceived, int? totalBytes)? onProgress,
  }) async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      throw Exception('Не удалось получить директорию для загрузки');
    }
    final file = File('${dir.path}/raporticka-${u.version}.apk');
    final client = http.Client();
    final req = http.Request('GET', Uri.parse(u.apkUrl));
    req.headers['User-Agent'] = 'Raporticka/1';
    final resp = await client.send(req).timeout(const Duration(minutes: 10));
    final total = resp.contentLength;
    final sink = file.openWrite();
    int received = 0;
    await for (final chunk in resp.stream) {
      received += chunk.length;
      sink.add(chunk);
      onProgress?.call(received, total);
    }
    await sink.flush();
    await sink.close();
    client.close();
    return file.path;
  }

  static Future<void> installApk(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw Exception('Не удалось открыть установщик: ${result.message}');
    }
  }
}
