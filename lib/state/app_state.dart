import 'package:flutter/foundation.dart';

import '../models/group.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api;
  final AuthService auth;

  AppUser? user;
  String? token;
  Group? activeGroup;
  bool initialized = false;

  AppState({ApiService? api, AuthService? auth})
      : api = api ?? ApiService(),
        auth = auth ?? AuthService();

  bool get isTeacher => user?.isTeacher ?? false;
  bool get isMonitor => user?.isMonitor ?? false;
  Group? get group => activeGroup;
  int get groupId => activeGroup?.id ?? -1;

  void updateUser(AppUser u) {
    user = u;
    notifyListeners();
  }

  void setGroup(Group g) {
    activeGroup = g;
    notifyListeners();
  }

  Future<void> init() async {
    final s = await auth.loadSession();
    if (s != null) {
      token = s.token;
      api.setToken(s.token);
      user = s.user;
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
    notifyListeners();
  }

  int? get boundGroupId => user?.groupId;

  Future<void> logout() async {
    await auth.clear();
    token = null;
    user = null;
    activeGroup = null;
    api.setToken(null);
    notifyListeners();
  }
}