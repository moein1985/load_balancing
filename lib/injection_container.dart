// lib/injection_container.dart
import 'package:get_it/get_it.dart';
import 'package:load_balance/data/datasources/remote_datasource.dart';
import 'package:load_balance/data/datasources/remote_datasource_impl.dart';
import 'package:load_balance/data/repositories/device_repository_impl.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';
import 'package:load_balance/domain/usecases/apply_ecmp_config.dart';
import 'package:load_balance/domain/usecases/apply_pbr_rule.dart';
import 'package:load_balance/domain/usecases/check_credentials.dart';
import 'package:load_balance/domain/usecases/delete_pbr_rule.dart';
import 'package:load_balance/domain/usecases/edit_pbr_rule.dart';
import 'package:load_balance/domain/usecases/get_pbr_configuration.dart';
import 'package:load_balance/domain/usecases/get_router_interfaces.dart';
import 'package:load_balance/domain/usecases/get_router_routing_table.dart';
import 'package:load_balance/domain/usecases/ping_gateway.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';
import 'package:load_balance/presentation/bloc/router_connection/router_connection_bloc.dart';

// Service Locator instance
final sl = GetIt.instance;

Future<void> init() async {
  // BLoCs
  sl.registerFactory(() => RouterConnectionBloc(checkCredentials: sl()));
  sl.registerFactory(() => LoadBalancingBloc(
        getInterfaces: sl(),
        getRoutingTable: sl(),
        pingGateway: sl(),
        applyEcmpConfig: sl(),
        getPbrConfiguration: sl(),
        deletePbrRule: sl(),
      ));

  // Use Cases
  sl.registerLazySingleton(() => CheckCredentials(sl()));
  sl.registerLazySingleton(() => GetRouterInterfaces(sl()));
  sl.registerLazySingleton(() => GetRouterRoutingTable(sl()));
  sl.registerLazySingleton(() => GetPbrConfiguration(sl()));
  sl.registerLazySingleton(() => PingGateway(sl()));
  sl.registerLazySingleton(() => ApplyEcmpConfig(sl()));
  sl.registerLazySingleton(() => ApplyPbrRule(sl()));
  sl.registerLazySingleton(() => DeletePbrRule(sl()));
  sl.registerLazySingleton(() => EditPbrRule(sl()));

  // Repository
  sl.registerLazySingleton<RouterRepository>(
      () => DeviceRepositoryImpl(remoteDataSource: sl()));

  // Data Sources
  sl.registerLazySingleton<RemoteDataSource>(() => RemoteDataSourceImpl());
}