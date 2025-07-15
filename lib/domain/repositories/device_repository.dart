// domain/repositories/device_repository.dart
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

abstract class DeviceRepository {
  /// Checks credentials by attempting to connect to the device.
  /// Throws a [ServerFailure] if connection fails.
  Future<void> checkCredentials(DeviceCredentials credentials);

  /// Fetches the list of interfaces from the device.
  Future<List<RouterInterface>> getInterfaces(DeviceCredentials credentials);

  /// Pings a gateway IP from the device to check reachability.
  Future<String> pingGateway({
    required DeviceCredentials credentials,
    required String ipAddress,
  });

  /// Fetches the current IP routing table from the device.
  Future<String> getRoutingTable(DeviceCredentials credentials);
}