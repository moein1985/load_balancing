// lib/domain/usecases/ping_gateway.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class PingGateway {
  final RouterRepository repository;

  PingGateway(this.repository);

  // The call method requires credentials to perform the operation on the device.
  Future<String> call({
    required LBDeviceCredentials credentials,
    required String ipAddress,
  }) async {
    return await repository.pingGateway(
      credentials: credentials,
      ipAddress: ipAddress,
    );
  }
}