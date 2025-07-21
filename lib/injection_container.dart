import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/data/datasources/remote_datasource_impl.dart';
import 'package:load_balance/data/repositories/device_repository_impl.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';
import 'package:load_balance/domain/usecases/apply_ecmp_config.dart';
import 'package:load_balance/domain/usecases/check_credentials.dart';
import 'package:load_balance/domain/usecases/get_interfaces.dart';
import 'package:load_balance/domain/usecases/get_routing_table.dart';
import 'package:load_balance/domain/usecases/ping_gateway.dart';
import 'package:load_balance/presentation/bloc/connection/connection_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';

class DependencyInjector extends StatelessWidget {
  final Widget child;

  const DependencyInjector({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<DeviceRepository>(
      create: (context) => DeviceRepositoryImpl(
        remoteDataSource: RemoteDataSourceImpl(),
      ),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ConnectionBloc(
              checkCredentials: CheckCredentials(context.read<DeviceRepository>()),
            ),
          ),
          BlocProvider(
            create: (context) {
              final repository = context.read<DeviceRepository>();
              return LoadBalancingBloc(
                getInterfaces: GetInterfaces(repository),
                getRoutingTable: GetRoutingTable(repository),
                pingGateway: PingGateway(repository),
                applyEcmpConfig: ApplyEcmpConfig(repository),
              );
            },
          ),
          // ** BlocProvider مربوط به PbrRuleFormBloc از اینجا حذف شد **
          // چون این BLoC در صفحه خودش ساخته میشود.
        ],
        child: child, // The MaterialApp will be passed here
      ),
    );
  }
}