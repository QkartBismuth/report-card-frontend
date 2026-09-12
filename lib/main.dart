import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/theme_controller.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  final theme = await ThemeController.create();
  runApp(ReportCardApp(state: state, themeCtrl: theme));
}

class ReportCardApp extends StatelessWidget {
  final AppState state;
  final ThemeController themeCtrl;
  const ReportCardApp({super.key, required this.state, required this.themeCtrl});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: themeCtrl),
      ],
      child: Consumer<ThemeController>(
        builder: (context, tc, _) {
          final baseScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2E5EAA));
          return MaterialApp(
            title: 'Рапортичка',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: baseScheme,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E5EAA),
                brightness: Brightness.dark,
                surface: tc.isOled ? Colors.black : null,
              ),
              scaffoldBackgroundColor: tc.isOled ? Colors.black : null,
              useMaterial3: true,
            ),
            themeMode: tc.themeMode,
            home: Consumer<AppState>(
              builder: (context, st, _) =>
                  st.user != null ? const HomeScreen() : const LoginScreen(),
            ),
          );
        },
      ),
    );
  }
}