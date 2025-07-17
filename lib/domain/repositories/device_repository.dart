// lib/domain/repositories/device_repository.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

abstract class DeviceRepository {
  Future<void> checkCredentials(DeviceCredentials credentials);
  Future<List<RouterInterface>> getInterfaces(DeviceCredentials credentials);
  Future<String> getRoutingTable(DeviceCredentials credentials);
  Future<String> pingGateway({
    required DeviceCredentials credentials,
    required String ipAddress,
  });
  // New method to apply ECMP configuration
  Future<String> applyEcmpConfig({
    required DeviceCredentials credentials,
    required String gateway1,
    required String gateway2,
  });
}