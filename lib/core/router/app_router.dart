// core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/presentation/screens/load_balancing/load_balancing_screen.dart';
import 'package:load_balance/presentation/screens/connection/connection_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'connection',
        builder: (BuildContext context, GoRouterState state) {
          return const ConnectionScreen();
        },
      ),
      GoRoute(
        path: '/config',
        name: 'config',
        builder: (BuildContext context, GoRouterState state) {
          // Receive the credentials object from the previous screen
          final credentials = state.extra as DeviceCredentials;
          return LoadBalancingScreen(credentials: credentials);
        },
      ),
    ],
  );
}