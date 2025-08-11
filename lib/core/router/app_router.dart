// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/presentation/screens/load_balancing/add_edit_pbr_rule_screen.dart';
import 'package:load_balance/presentation/screens/load_balancing/load_balancing_screen.dart';
import 'package:load_balance/presentation/screens/connection/router_connection_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'connection',
        builder: (BuildContext context, GoRouterState state) {
          return const RouterConnectionScreen();
        },
      ),
      GoRoute(
        path: '/config',
        name: 'config',
        builder: (BuildContext context, GoRouterState state) {
          // این بخش بدون تغییر باقی میماند
          final credentials = state.extra as LBDeviceCredentials;
          return LoadBalancingScreen(credentials: credentials);
        },
        routes: [
          GoRoute(
            path: 'add-pbr-rule',
            name: 'add_pbr_rule',
            builder: (BuildContext context, GoRouterState state) {
              // **تغییر اصلی:** حالا extra را برای این صفحه هم میخوانیم
              final credentials = state.extra as LBDeviceCredentials?;
              return AddEditPbrRuleScreen(credentials: credentials);
            },
          ),
          GoRoute(
            path: 'edit-pbr-rule/:ruleId',
            name: 'edit_pbr_rule',
            builder: (BuildContext context, GoRouterState state) {
              final ruleId = state.pathParameters['ruleId'];
              final credentials = state.extra as LBDeviceCredentials?;
              return AddEditPbrRuleScreen(credentials: credentials, ruleId: ruleId);
            },
          ),
        ],
      ),
    ],
  );
}