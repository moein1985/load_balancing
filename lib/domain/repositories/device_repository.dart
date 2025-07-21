// lib/domain/repositories/device_repository.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

abstract class DeviceRepository {
  Future<void> checkCredentials(DeviceCredentials credentials);
  Future<List<RouterInterface>> getInterfaces(DeviceCredentials credentials);
  Future<String> getRoutingTable(DeviceCredentials credentials);
  Future<String> pingGateway({
    required DeviceCredentials credentials,
    required String ipAddress,
  });
  
  /// Applies the ECMP configuration to the device.
  ///
  /// Takes a list of gateways to add and a list of gateways to remove.
  Future<String> applyEcmpConfig({
    required DeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  });

    Future<String> applyPbrRule({
    required DeviceCredentials credentials,
    required PbrRule rule,
  });
}