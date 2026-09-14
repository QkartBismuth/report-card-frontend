import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:report_card/main.dart';
import 'package:report_card/models/user.dart';
import 'package:report_card/services/api_service.dart';
import 'package:report_card/services/auth_service.dart';
import 'package:report_card/services/theme_controller.dart';
import 'package:report_card/state/app_state.dart';

void main() {
  testWidgets('App starts and shows login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(api: _FakeApi(), auth: _FakeAuth());
    await state.init();
    final theme = ThemeController();

    await tester.pumpWidget(ReportCardApp(state: state, themeCtrl: theme));

    expect(find.text('Рапортичка'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}

class _FakeAuth extends AuthService {
  @override
  Future<({String token, AppUser user})?> loadSession() async => null;
}

class _FakeApi extends ApiService {
  _FakeApi() : super(baseUrl: 'http://localhost:9999');
}