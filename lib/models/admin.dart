class TeacherInfo {
  final int id;
  final String login;
  final String fullName;
  final String role;

  TeacherInfo({
    required this.id,
    required this.login,
    required this.fullName,
    required this.role,
  });

  factory TeacherInfo.fromJson(Map<String, dynamic> json) => TeacherInfo(
        id: json['id'],
        login: json['login'] ?? '',
        fullName: json['full_name'] ?? '',
        role: json['role'] ?? 'teacher',
      );
}

class AdminGroup {
  final int id;
  final String name;
  final int? year;
  final int? curatorId;
  final String? curatorName;

  AdminGroup({
    required this.id,
    required this.name,
    this.year,
    this.curatorId,
    this.curatorName,
  });

  factory AdminGroup.fromJson(Map<String, dynamic> json) => AdminGroup(
        id: json['id'],
        name: json['name'] ?? '',
        year: json['year'],
        curatorId: json['curator_id'] ?? json['teacher_id'],
        curatorName: json['curator_name'],
      );
}

class DeviceInfo {
  final int id;
  final String deviceId;
  final String? platform;
  final String? model;
  final String? manufacturer;
  final String? osVersion;
  final String? appVersion;
  final String? ip;
  final int? userId;
  final String? lastSeen;

  DeviceInfo({
    required this.id,
    required this.deviceId,
    this.platform,
    this.model,
    this.manufacturer,
    this.osVersion,
    this.appVersion,
    this.ip,
    this.userId,
    this.lastSeen,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        id: json['id'],
        deviceId: json['device_id'] ?? '',
        platform: json['platform'],
        model: json['model'],
        manufacturer: json['manufacturer'],
        osVersion: json['os_version'],
        appVersion: json['app_version'],
        ip: json['ip'],
        userId: json['user_id'],
        lastSeen: json['last_seen'],
      );
}

class ErrorInfo {
  final int id;
  final String? deviceId;
  final String? appVersion;
  final String message;
  final String? stack;
  final String? createdAt;

  ErrorInfo({
    required this.id,
    this.deviceId,
    this.appVersion,
    required this.message,
    this.stack,
    this.createdAt,
  });

  factory ErrorInfo.fromJson(Map<String, dynamic> json) => ErrorInfo(
        id: json['id'],
        deviceId: json['device_id'],
        appVersion: json['app_version'],
        message: json['message'] ?? '',
        stack: json['stack'],
        createdAt: json['created_at'],
      );
}

class ServerConfig {
  final String? serverUrl;
  final String? wifiSsid;
  final String? wifiPassword;

  ServerConfig({this.serverUrl, this.wifiSsid, this.wifiPassword});

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        serverUrl: json['server_url'],
        wifiSsid: json['wifi_ssid'],
        wifiPassword: json['wifi_password'],
      );
}

class PushConfig {
  final int version;
  final String? serverUrl;
  final String? wifiSsid;
  final String? wifiPassword;

  PushConfig({
    required this.version,
    this.serverUrl,
    this.wifiSsid,
    this.wifiPassword,
  });

  factory PushConfig.fromJson(Map<String, dynamic> json) => PushConfig(
        version: json['version'] ?? 1,
        serverUrl: json['server_url'],
        wifiSsid: json['wifi_ssid'],
        wifiPassword: json['wifi_password'],
      );
}

class RequestError {
  final String? deviceId;
  final String? appVersion;
  final String message;
  final String? stack;

  RequestError({
    this.deviceId,
    this.appVersion,
    required this.message,
    this.stack,
  });
}

class TunnelStatus {
  final bool running;
  final String? provider;
  final String? url;
  final String? error;

  TunnelStatus({required this.running, this.provider, this.url, this.error});

  factory TunnelStatus.fromJson(Map<String, dynamic> json) => TunnelStatus(
        running: json['running'] ?? false,
        provider: json['provider'],
        url: json['url'],
        error: json['error'],
      );
}