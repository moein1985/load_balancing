// lib/domain/usecases/get_router_routing_table.dart
import 'package:fpdart/fpdart.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class GetRouterRoutingTable {
  final RouterRepository repository;

  GetRouterRoutingTable(this.repository);

  Future<Either<Failure, String>> call(LBDeviceCredentials credentials) async {
    return await repository.getRoutingTable(credentials);
  }
}