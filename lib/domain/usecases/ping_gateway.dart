// lib/domain/usecases/ping_gateway.dart
import 'package:fpdart/fpdart.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class PingGateway {
  final RouterRepository repository;

  PingGateway(this.repository);

  Future<Either<Failure, String>> call({
    required LBDeviceCredentials credentials,
    required String ipAddress,
  }) async {
    return await repository.pingGateway(
      credentials: credentials,
      ipAddress: ipAddress,
    );
  }
}