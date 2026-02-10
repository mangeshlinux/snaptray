import 'package:flutter/material.dart';
import 'package:snappath_tray/mobile/screens/snap_path_screen.dart';
import 'package:snappath_tray/shared/theme.dart';
import 'package:snappath_tray/shared/theme_controller.dart';
import 'package:snappath_tray/shared/auth_screen.dart';
import 'package:snappath_tray/shared/supabase_auth_service.dart';
import 'package:snappath_tray/shared/splash_screen.dart';

class SnapPathApp extends StatefulWidget {
  const SnapPathApp({super.key});

  @override
  State<SnapPathApp> createState() => _SnapPathAppState();
}

class _SnapPathAppState extends State<SnapPathApp> {
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
          title: 'SnapPath',
          theme: SnapAppTheme.lightTheme,
          darkTheme: SnapAppTheme.darkTheme,
          themeMode: mode,
          home: _isLoading
              ? const SplashScreen(appName: "SnapPath", isWindows: false)
              : (_isLoggedIn
                    ? const SnapPathScreen()
                    : AuthScreen(
                        isWindows: false,
                        onLoginSuccess: () =>
                            setState(() => _isLoggedIn = true),
                      )),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
