import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:snappath_tray/mobile/app.dart';
import 'package:snappath_tray/windows/app.dart';
import 'package:snappath_tray/web/web_launcher.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snappath_tray/shared/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebLauncher();
    } else if (Platform.isWindows) {
      return const SnapTrayApp();
    } else if (Platform.isAndroid || Platform.isIOS) {
      return const SnapPathApp();
    } else {
      // Fallback for other platforms
      return const SnapPathApp();
    }
  }
}
