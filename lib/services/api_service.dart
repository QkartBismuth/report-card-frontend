import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/admin.dart';
import '../models/group.dart';
import '../models/schedule.dart';
import '../models/session.dart';
import '../models/student.dart';
import '../models/subject.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  String baseUrl;
  String? _token;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  void setToken(String? token) => _token = token;

  void setBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && u != baseUrl) baseUrl = u;
  }

  Uri _uri(String path,
          [Map<String, dynamic>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final resp = http.Request(method, _uri(path, query))
        ..headers.addAll(_headers)
        ..body = body != null ? jsonEncode(body) : '';
    final streamed = await resp.send();
    final r = await http.Response.fromStream(streamed);

    final data = r.body.isEmpty ? null : _tryDecode(r.body);
    if (r.statusCode >= 400) {
      final msg = _extractError(r.body);
      throw ApiException(r.statusCode, msg);
    }
    return data;
  }

  static dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _extractError(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map && d['detail'] != null) {
        final det = d['detail'];
        if (det is List) {
          return det.map((e) => e['msg']?.toString() ?? '').join('\n');
        }
        return det.toString();
      }
    } catch (_) {}
    return 'Ошибка сервера';
  }

  // --------------- Auth ---------------

  Future<Map<String, dynamic>> login(String login, String password) async {
    final data = await _request('POST', '/auth/login',
        body: {'login': login, 'password': password});
    return data as Map<String, dynamic>;
  }

  // --------------- Groups ---------------

  Future<List<Group>> getGroups() async {
    final data = await _request('GET', '/groups');
    return (data as List)
        .map((e) => Group.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --------------- Students ---------------

  Future<List<Student>> getStudents(int groupId) async {
    final data =
        await _request('GET', '/students', query: {'group_id': '$groupId'});
    return (data as List)
        .map((e) => Student.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Student> addStudent(int groupId, String fullName) async {
    final data = await _request('POST', '/students',
        query: {'group_id': '$groupId'}, body: {'full_name': fullName});
    return Student.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteStudent(int studentId) async {
    await _request('DELETE', '/students/$studentId');
  }

  Future<Student> renameStudent(int studentId, String fullName) async {
    final data = await _request('PUT', '/students/$studentId',
        body: {'full_name': fullName});
    return Student.fromJson(data as Map<String, dynamic>);
  }

  // --------------- Subjects ---------------

  Future<List<Subject>> getSubjects() async {
    final data = await _request('GET', '/subjects');
    return (data as List)
        .map((e) => Subject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Subject> addSubject(String name) async {
    final data =
        await _request('POST', '/subjects', body: {'name': name});
    return Subject.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteSubject(int subjectId) async {
    await _request('DELETE', '/subjects/$subjectId');
  }

  // --------------- Sessions ---------------

  Future<List<SessionInfo>> getSessions(
    int groupId, {
    DateTime? dateFrom,
    DateTime? dateTo,
    bool onlyConfirmed = false,
  }) async {
    final query = <String, dynamic>{'group_id': '$groupId'};
    if (dateFrom != null) query['date_from'] = _fmtDate(dateFrom);
    if (dateTo != null) query['date_to'] = _fmtDate(dateTo);
    if (onlyConfirmed) query['only_confirmed'] = 'true';
    final data = await _request('GET', '/sessions', query: query);
    return (data as List)
        .map((e) => SessionInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionDetail> getSessionDetail(int sessionId) async {
    final data = await _request('GET', '/sessions/$sessionId');
    return SessionDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<SessionInfo> createSession({
    required int groupId,
    required DateTime date,
    required int pairNumber,
    int? subjectId,
  }) async {
    final data = await _request('POST', '/sessions', body: {
      'group_id': groupId,
      'date': _fmtDate(date),
      'pair_number': pairNumber,
      'subject_id': subjectId,
    });
    return SessionInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateRecords(int sessionId, Map<int, String> marks) async {
    final records = marks.entries
        .map((e) => {'student_id': e.key, 'mark': e.value})
        .toList();
    await _request('PUT', '/sessions/$sessionId/records',
        body: {'records': records});
  }

  Future<SessionDetail> confirmSession(int sessionId) async {
    final data = await _request('POST', '/sessions/$sessionId/confirm');
    return SessionDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<SessionDetail> unconfirmSession(int sessionId) async {
    final data = await _request('POST', '/sessions/$sessionId/unconfirm');
    return SessionDetail.fromJson(data as Map<String, dynamic>);
  }

  // --------------- Upload raport ---------------

  Future<Map<String, dynamic>> uploadRaport(File file) async {
    final request = http.MultipartRequest('POST', _uri('/upload/raport'))
      ..headers.addAll({'Authorization': 'Bearer $_token'})
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode >= 400) {
      throw ApiException(r.statusCode, _extractError(r.body));
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> applyRaport({
    required String groupName,
    int? year,
    required List<String> students,
  }) async {
    final data = await _request('POST', '/upload/raport/apply', body: {
      'group_name': groupName,
      'group_year': year,
      'students': students,
    });
    return data as Map<String, dynamic>;
  }

  // --------------- Export ---------------

  Future<String> exportSession(
    int sessionId,
    String format,
    String saveDir,
  ) async {
    final resp = await http.get(
      _uri('/export/session/$sessionId', {'fmt': format}),
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, _extractError(resp.body));
    }
    final fname = _fileName(resp.headers['content-disposition'], format);
    final file = File('$saveDir/$fname');
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }

  Future<String> exportGroup(
    int groupId, {
    required DateTime dateFrom,
    required DateTime dateTo,
    required String format,
    required String saveDir,
  }) async {
    final query = {
      'date_from': _fmtDate(dateFrom),
      'date_to': _fmtDate(dateTo),
      'fmt': format,
    };
    final resp = await http.get(_uri('/export/group/$groupId', query), headers: {
      if (_token != null) 'Authorization': 'Bearer $_token',
    });
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, _extractError(resp.body));
    }
    final fname = _fileName(resp.headers['content-disposition'], format);
    final file = File('$saveDir/$fname');
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }

  static String _fileName(String? disposition, String format) {
    final reg = RegExp("filename\\*=UTF-8''([^;]+)");
    final m = reg.firstMatch(disposition ?? '');
    if (m != null) {
      try {
        final decoded = Uri.decodeComponent(m.group(1)!);
        if (decoded.isNotEmpty) return decoded;
      } catch (_) {}
    }
    return 'raport.$format';
  }

  // --------------- Push config / telemetry ---------------

  Future<PushConfig> getPushConfig() async {
    final data = await _request('GET', '/push/config');
    return PushConfig.fromJson(data as Map<String, dynamic>);
  }

  Future<void> registerDevice({
    required String deviceId,
    String platform = 'android',
    String? model,
    String? manufacturer,
    String? osVersion,
    String? appVersion,
  }) async {
    await _request('POST', '/analytics/device', body: {
      'device_id': deviceId,
      'platform': platform,
      'model': model,
      'manufacturer': manufacturer,
      'os_version': osVersion,
      'app_version': appVersion,
    });
  }

  Future<void> reportError(RequestError error) async {
    await _request('POST', '/analytics/error', body: {
      'device_id': error.deviceId,
      'app_version': error.appVersion,
      'message': error.message,
      'stack': error.stack,
    });
  }

  // --------------- Admin: teachers ---------------

  Future<List<TeacherInfo>> getTeachers() async {
    final data = await _request('GET', '/admin/teachers');
    return (data as List)
        .map((e) => TeacherInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TeacherInfo> addTeacher({
    required String login,
    required String fullName,
    required String password,
  }) async {
    final data = await _request('POST', '/admin/teachers', body: {
      'login': login,
      'full_name': fullName,
      'password': password,
    });
    return TeacherInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<TeacherInfo> updateTeacher(
    int teacherId, {
    String? login,
    String? fullName,
    String? password,
  }) async {
    final body = <String, dynamic>{
      'login': ?login,
      'full_name': ?fullName,
      if (password != null && password.isNotEmpty) 'password': password,
    };
    final data = await _request('PATCH', '/admin/teachers/$teacherId', body: body);
    return TeacherInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteTeacher(int teacherId) async {
    await _request('DELETE', '/admin/teachers/$teacherId');
  }

  // --------------- Admin: groups / curators ---------------

  Future<AdminGroup> addGroup(String name, {int? year}) async {
    final data = await _request('POST', '/admin/groups',
        body: {'name': name, 'year': ?year});
    return AdminGroup.fromJson(data as Map<String, dynamic>);
  }

  Future<AdminGroup> updateGroup(
    int groupId, {
    String? name,
    int? year,
    int? curatorId,
    bool clearCurator = false,
  }) async {
    final body = <String, dynamic>{
      'name': ?name,
      'year': ?year,
      if (clearCurator) 'curator_id': null else 'curator_id': ?curatorId,
    };
    final data = await _request('PATCH', '/admin/groups/$groupId', body: body);
    return AdminGroup.fromJson(data as Map<String, dynamic>);
  }

  // --------------- Admin: monitors ---------------

  Future<List<MonitorInfo>> getMonitors({int? groupId}) async {
    final data = await _request('GET', '/admin/monitors',
        query: {'group_id': ?groupId?.toString()});
    return (data as List)
        .map((e) => MonitorInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MonitorInfo> createMonitor({
    required int studentId,
    required String login,
    required String password,
  }) async {
    final data = await _request('POST', '/admin/monitors', body: {
      'student_id': studentId,
      'login': login,
      'password': password,
    });
    return MonitorInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteMonitor(int monitorId) async {
    await _request('DELETE', '/admin/monitors/$monitorId');
  }

  // --------------- Admin: devices / errors ---------------

  Future<List<DeviceInfo>> getDevices() async {
    final data = await _request('GET', '/admin/devices');
    return (data as List)
        .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteDevice(int deviceId) async {
    await _request('DELETE', '/admin/devices/$deviceId');
  }

  Future<int> clearDevices() async {
    final data = await _request('DELETE', '/admin/devices');
    return (data as Map<String, dynamic>)['deleted'] ?? 0;
  }

  Future<List<ErrorInfo>> getErrors() async {
    final data = await _request('GET', '/admin/errors');
    return (data as List)
        .map((e) => ErrorInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteError(int errorId) async {
    await _request('DELETE', '/admin/errors/$errorId');
  }

  Future<int> clearErrors() async {
    final data = await _request('DELETE', '/admin/errors');
    return (data as Map<String, dynamic>)['deleted'] ?? 0;
  }

  // --------------- Admin: connection config ---------------

  Future<ServerConfig> getServerConfig() async {
    final data = await _request('GET', '/admin/config');
    return ServerConfig.fromJson(data as Map<String, dynamic>);
  }

  Future<ServerConfig> updateServerConfig({
    String? serverUrl,
    String? wifiSsid,
    String? wifiPassword,
  }) async {
    final body = <String, dynamic>{
      'server_url': ?serverUrl,
      'wifi_ssid': ?wifiSsid,
      'wifi_password': ?wifiPassword,
    };
    final data = await _request('POST', '/admin/config', body: body);
    return ServerConfig.fromJson(data as Map<String, dynamic>);
  }

  // --------------- Admin: tunnel ---------------

  Future<TunnelStatus> tunnelStatus() async {
    final data = await _request('GET', '/admin/tunnel/status');
    return TunnelStatus.fromJson(data as Map<String, dynamic>);
  }

  Future<TunnelStatus> tunnelStart(String provider, {String? token}) async {
    final data = await _request('POST', '/admin/tunnel/start',
        body: {'provider': provider, 'token': ?token});
    return TunnelStatus.fromJson(data as Map<String, dynamic>);
  }

  Future<TunnelStatus> tunnelStop() async {
    final data = await _request('POST', '/admin/tunnel/stop');
    return TunnelStatus.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> tunnelSendUrl() async {
    final data = await _request('POST', '/admin/tunnel/send-url');
    return data as Map<String, dynamic>;
  }

  // --------------- KTC (прокси через сервер) ---------------

  Future<List<KtcBranch>> getKtcBranches() async {
    final data = await _request('GET', '/ktc/branches');
    return (data as List)
        .map((e) => KtcBranch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<KtcCourse>> getKtcCourses(int branchId) async {
    final data = await _request('GET', '/ktc/courses/$branchId');
    return (data as List)
        .map((e) => KtcCourse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --------------- Расписание ---------------

  Future<List<ScheduleEntry>> getSchedule(int groupId) async {
    final data = await _request('GET', '/schedule/$groupId');
    return (data as List)
        .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setScheduleSource(int groupId,
      {int? ktcBranchId, int? ktcGroupId}) async {
    await _request('PUT', '/schedule/$groupId/source', body: {
      'ktc_branch_id': ?ktcBranchId,
      'ktc_group_id': ?ktcGroupId,
    });
  }

  Future<Map<String, dynamic>> importSchedule(int groupId,
      {int? week, bool replace = false}) async {
    final data = await _request('POST', '/schedule/$groupId/import',
        body: {'week': ?week, 'replace': replace});
    return data as Map<String, dynamic>;
  }

  Future<ScheduleEntry> addScheduleEntry(
    int groupId, {
    required int dayOfWeek,
    required int pairNumber,
    int? subjectId,
    String? subjectName,
    String? teacherName,
    String? classroom,
    bool cancelled = false,
  }) async {
    final data = await _request('POST', '/schedule/$groupId/entries', body: {
      'day_of_week': dayOfWeek,
      'pair_number': pairNumber,
      'subject_id': ?subjectId,
      'subject_name': ?subjectName,
      'teacher_name': ?teacherName,
      'classroom': ?classroom,
      'cancelled': cancelled,
    });
    return ScheduleEntry.fromJson(data as Map<String, dynamic>);
  }

  Future<ScheduleEntry> updateScheduleEntry(
    int entryId, {
    int? dayOfWeek,
    int? pairNumber,
    int? subjectId,
    String? subjectName,
    String? teacherName,
    String? classroom,
    bool? cancelled,
  }) async {
    final data = await _request('PATCH', '/schedule/$entryId', body: {
      'day_of_week': ?dayOfWeek,
      'pair_number': ?pairNumber,
      'subject_id': ?subjectId,
      'subject_name': ?subjectName,
      'teacher_name': ?teacherName,
      'classroom': ?classroom,
      'cancelled': ?cancelled,
    });
    return ScheduleEntry.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteScheduleEntry(int entryId) async {
    await _request('DELETE', '/schedule/$entryId');
  }

  Future<CreateSessionsResult> createSessionsFromSchedule(
    int groupId, {
    required DateTime date,
    String mode = 'missing',
  }) async {
    final data = await _request('POST', '/schedule/$groupId/create-sessions',
        body: {'date': _fmtDate(date), 'mode': mode});
    return CreateSessionsResult.fromJson(data as Map<String, dynamic>);
  }

  static String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}