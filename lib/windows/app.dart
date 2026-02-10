import 'package:flutter/material.dart';
import 'package:snappath_tray/windows/screens/snap_tray_screen.dart';
import 'package:snappath_tray/shared/theme.dart';
import 'package:snappath_tray/shared/theme_controller.dart';
import 'package:snappath_tray/shared/auth_screen.dart';
import 'package:snappath_tray/shared/supabase_auth_service.dart';
import 'package:snappath_tray/shared/splash_screen.dart';

class SnapTrayApp extends StatefulWidget {
  const SnapTrayApp({super.key});

  @override
  State<SnapTrayApp> createState() => _SnapTrayAppState();
}

class _SnapTrayAppState extends State<SnapTrayApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for BOTH auth check and splash animation (min 2.5s)
    // Note: Supabase session is already restored by initialize() in main.dart
    final isLoggedIn = SupabaseAuthService().isLoggedIn();

    await Future.delayed(const Duration(milliseconds: 2500));

    final loggedIn = isLoggedIn;

    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          title: 'SnapTray',
          theme: SnapAppTheme.lightTheme,
          darkTheme: SnapAppTheme.darkTheme,
          themeMode: mode,
          home: _isLoading
              ? const SplashScreen(appName: "SnapTray", isWindows: true)
              : (_isLoggedIn
                    ? const SnapTrayScreen()
                    : AuthScreen(
                        isWindows: true,
                        onLoginSuccess: () =>
                            setState(() => _isLoggedIn = true),
                      )),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
