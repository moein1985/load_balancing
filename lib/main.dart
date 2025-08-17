// lib/main.dart
import 'package:flutter/material.dart';
import 'package:load_balance/core/router/app_router.dart';
import 'package:load_balance/injection_container.dart' as di;

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize dependency injection
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The DependencyInjector widget is no longer needed
    return MaterialApp.router(
      title: 'Cisco Load Balancer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0))),
        inputDecorationTheme: const InputDecorationTheme(
            border:
                OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12.0)))),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)))),
        ),
      ),
      routerConfig: AppRouter.router,
    );
  }
}