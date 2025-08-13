import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/data/datasources/remote_datasource_impl.dart';
import 'package:load_balance/data/repositories/device_repository_impl.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';
import 'package:load_balance/domain/usecases/apply_ecmp_config.dart';
import 'package:load_balance/domain/usecases/check_credentials.dart';
import 'package:load_balance/domain/usecases/delete_pbr_rule.dart';
import 'package:load_balance/domain/usecases/get_pbr_configuration.dart'; 
import 'package:load_balance/domain/usecases/get_router_interfaces.dart';
import 'package:load_balance/domain/usecases/get_router_routing_table.dart';
import 'package:load_balance/domain/usecases/ping_gateway.dart';
import 'package:load_balance/presentation/bloc/router_connection/router_connection_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';

class DependencyInjector extends StatelessWidget {
  final Widget child;
  const DependencyInjector({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<RouterRepository>(
      create: (context) => DeviceRepositoryImpl(
        remoteDataSource: RemoteDataSourceImpl(),
      ),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => RouterConnectionBloc(
              checkCredentials: CheckCredentials(context.read<RouterRepository>()),
            ),
          ),
          BlocProvider(
            create: (context) {
              final repository = context.read<RouterRepository>();
              return LoadBalancingBloc(
                getInterfaces: GetRouterInterfaces(repository),
                getRoutingTable: GetRouterRoutingTable(repository),
                pingGateway: PingGateway(repository),
                applyEcmpConfig: ApplyEcmpConfig(repository),
                // **تزریق Use Case جدید به BLoC**
                getPbrConfiguration: GetPbrConfiguration(repository),
                deletePbrRule: DeletePbrRule(repository),
              );
            },
          ),
        ],
        child: child,
      ),
    );
  }
}