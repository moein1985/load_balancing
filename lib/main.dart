// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/core/router/app_router.dart';
import 'package:load_balance/data/datasources/remote_datasource.dart';
import 'package:load_balance/data/datasources/remote_datasource_impl.dart';
import 'package:load_balance/data/repositories/device_repository_impl.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';
import 'package:load_balance/domain/usecases/check_credentials.dart';
import 'package:load_balance/presentation/bloc/connection/connection_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // RepositoryProvider for the original repository structure
        RepositoryProvider<DeviceRepository>(
          create: (context) => DeviceRepositoryImpl(
            // The datasource is now also provided separately for the new BLoC
            remoteDataSource: RemoteDataSourceImpl(),
          ),
        ),
        // Provide the datasource implementation directly for the LoadBalancingBloc
        RepositoryProvider<RemoteDataSource>(
          create: (context) => RemoteDataSourceImpl(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ConnectionBloc(
              checkCredentials: CheckCredentials(
                context.read<DeviceRepository>(),
              ),
            ),
          ),
          BlocProvider(
            create: (context) => LoadBalancingBloc(
              // The BLoC now directly depends on the datasource to manage the connection
              remoteDataSource: context.read<RemoteDataSource>(),
            ),
          ),
        ],
        child: MaterialApp.router(
          title: 'Cisco Load Balancer',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.dark,
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
            ),
            segmentedButtonTheme: SegmentedButtonThemeData(
              style: ButtonStyle(
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ),
          ),
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}