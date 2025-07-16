// lib/domain/repositories/device_repository.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

abstract class DeviceRepository {
  Future<void> checkCredentials(DeviceCredentials credentials);
  Future<List<RouterInterface>> getInterfaces(DeviceCredentials credentials);
  Future<String> getRoutingTable(DeviceCredentials credentials);
  // Add the pingGateway method back to the repository interface
  Future<String> pingGateway({
    required DeviceCredentials credentials,
    required String ipAddress,
  });
}
