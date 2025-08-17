// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';
import 'package:load_balance/presentation/bloc/router_connection/router_connection_bloc.dart';
import 'package:load_balance/presentation/screens/load_balancing/add_edit_pbr_rule_screen.dart';
import 'package:load_balance/presentation/screens/load_balancing/load_balancing_screen.dart';
import 'package:load_balance/presentation/screens/connection/router_connection_screen.dart';
import 'package:load_balance/injection_container.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'connection',
        builder: (BuildContext context, GoRouterState state) {
          // BLoC مربوط به این صفحه را با get_it فراهم می‌کنیم
          return BlocProvider(
            create: (_) => sl<RouterConnectionBloc>(),
            child: const RouterConnectionScreen(),
          );
        },
      ),
      GoRoute(
        path: '/config',
        name: 'config',
        builder: (BuildContext context, GoRouterState state) {
          final data = state.extra as Map<String, dynamic>;
          final credentials = data['credentials'] as LBDeviceCredentials;
          final interfaces = data['interfaces'] as List<RouterInterface>;

          // BLoC مربوط به این صفحه را با get_it فراهم می‌کنیم
          return BlocProvider(
            create: (_) => sl<LoadBalancingBloc>(),
            child: LoadBalancingScreen(
              credentials: credentials,
              initialInterfaces: interfaces,
            ),
          );
        },
        routes: [
          GoRoute(
            path: 'add-pbr-rule',
            name: 'add_pbr_rule',
            builder: (BuildContext context, GoRouterState state) {
              final credentials = state.extra as LBDeviceCredentials?;
              // این صفحه BLoC خودش را مدیریت می‌کند، پس نیازی به Provider در اینجا نیست
              return AddEditPbrRuleScreen(credentials: credentials);
            },
          ),
          GoRoute(
            path: 'edit-pbr-rule/:ruleId',
            name: 'edit_pbr_rule',
            builder: (BuildContext context, GoRouterState state) {
              final ruleId = state.pathParameters['ruleId'];
              final credentials = state.extra as LBDeviceCredentials?;
              return AddEditPbrRuleScreen(
                credentials: credentials,
                ruleId: ruleId,
              );
            },
          ),
        ],
      ),
    ],
  );
}
