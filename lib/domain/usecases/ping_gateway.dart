// lib/domain/usecases/ping_gateway.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';

class PingGateway {
  final DeviceRepository repository;

  PingGateway(this.repository);

  // The call method now requires credentials again.
  Future<String> call({
    required DeviceCredentials credentials,
    required String ipAddress,
  }) async {
    return await repository.pingGateway(
      credentials: credentials,
      ipAddress: ipAddress,
    );
  }
}
