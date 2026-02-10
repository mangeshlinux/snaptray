import 'package:flutter/material.dart';

class WebLauncher extends StatelessWidget {
  const WebLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    // This widget should never be built on non-web platforms
    // as main.dart checks kIsWeb before using it.
    return const SizedBox.shrink();
  }
}
