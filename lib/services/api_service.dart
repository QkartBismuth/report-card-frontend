import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/group.dart';
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
  final String baseUrl;
  String? _token;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  void setToken(String? token) => _token = token;

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

  static String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}