import 'package:flutter_test/flutter_test.dart';
import 'package:report_card/models/app_update.dart';

void main() {
  test('AppVersion parse and compare', () {
    expect(AppVersion.parse('1.2.1') > AppVersion.parse('1.2.0'), isTrue);
    expect(AppVersion.parse('1.2.1') > AppVersion.parse('1.10.0'), isFalse);
    expect(AppVersion.parse('2.0.0') > AppVersion.parse('1.9.9'), isTrue);
    expect(AppVersion.parse('1.2.1') > AppVersion.parse('1.2.1'), isFalse);
    expect(AppVersion.parse('v1.2.1'.substring(1)) == AppVersion.parse('1.2.1'),
        isTrue);
  });

  test('AppUpdate from release JSON', () {
    final u = AppUpdate.fromReleaseJson({
      'tag_name': 'v1.3.0',
      'body': 'Исправления',
      'assets': [
        {
          'name': 'app-release.apk',
          'size': 52428800,
          'browser_download_url': 'https://example.com/app-release.apk',
        },
        {'name': 'checksums.txt'},
      ],
    });
    expect(u.version, '1.3.0');
    expect(u.apkUrl, 'https://example.com/app-release.apk');
    expect(u.size, 52428800);
    expect(u.notes, 'Исправления');
    expect(u.hasUrl, isTrue);
  });

  test('AppUpdate with no apk asset is empty', () {
    final u = AppUpdate.fromReleaseJson({
      'tag_name': 'v1.0.0',
      'assets': [{'name': 'source.zip'}],
    });
    expect(u.hasUrl, isFalse);
  });
}