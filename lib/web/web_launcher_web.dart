import 'package:flutter/material.dart';
import 'package:snappath_tray/mobile/app.dart';
import 'package:snappath_tray/windows/app.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class WebLauncher extends StatelessWidget {
  const WebLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    // Basic routing based on query params
    final uri = Uri.base;
    // Simple routing based on query param ?app=mobile or ?app=windows
    final appMode = uri.queryParameters['app'];

    if (appMode == 'mobile') {
      return const SnapPathApp();
    } else if (appMode == 'windows') {
      return const SnapTrayApp();
    }

    // Default to Mobile for now
    // Default Landing Page
    return MaterialApp(
      title: 'Snap Launcher',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Select App to Preview",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLaunchButton(
                    context,
                    "Launch Android",
                    Icons.phone_android,
                    Colors.green,
                    "mobile",
                  ),
                  const SizedBox(width: 32),
                  _buildLaunchButton(
                    context,
                    "Launch Windows",
                    Icons.desktop_windows,
                    Colors.blue,
                    "windows",
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLaunchButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    String mode,
  ) {
    return InkWell(
      onTap: () {
        // Open in new tab
        js.context.callMethod('open', [
          '${Uri.base.origin}${Uri.base.path}?app=$mode',
          '_blank',
        ]);
      },
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
