import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'flavors.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: F.title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A6B54),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      routerConfig: AppRouter.router,
    );
  }
}
