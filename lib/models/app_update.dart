class AppUpdate {
  final String version;
  final String apkUrl;
  final int size;
  final String? notes;
  const AppUpdate({
    required this.version,
    required this.apkUrl,
    this.size = 0,
    this.notes,
  });

  factory AppUpdate.fromReleaseJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '')
        .replaceFirst(RegExp(r'^v'), '');
    final assets =
        (json['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    final apk = assets.isEmpty
        ? null
        : assets.firstWhere(
            (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
            orElse: () => const <String, dynamic>{},
          );
    return AppUpdate(
      version: tag,
      apkUrl: apk?['browser_download_url'] as String? ?? '',
      size: (apk?['size'] as num?)?.toInt() ?? 0,
      notes: (json['body'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['body'],
    );
  }

  bool get hasUrl => apkUrl.isNotEmpty;
}

class AppVersion {
  final int major;
  final int minor;
  final int patch;
  const AppVersion(this.major, this.minor, this.patch);

  factory AppVersion.parse(String v) {
    final parts = v.split('.').map(int.tryParse).toList();
    return AppVersion(
      parts.isNotEmpty ? parts[0]! : 0,
      parts.length > 1 ? parts[1]! : 0,
      parts.length > 2 ? parts[2]! : 0,
    );
  }

  int get _packed => (major << 16) | (minor << 8) | patch;

  bool operator >(AppVersion o) => _packed > o._packed;
  bool operator <(AppVersion o) => _packed < o._packed;
  bool operator >=(AppVersion o) => _packed >= o._packed;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && _packed == other._packed;

  @override
  int get hashCode => _packed;

  @override
  String toString() => '$major.$minor.$patch';
}
