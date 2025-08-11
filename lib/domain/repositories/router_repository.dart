// lib/domain/repositories/device_repository.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

abstract class RouterRepository {
  Future<void> checkCredentials(LBDeviceCredentials credentials);
  Future<List<RouterInterface>> getInterfaces(LBDeviceCredentials credentials);
  Future<String> getRoutingTable(LBDeviceCredentials credentials);
  Future<String> pingGateway({
    required LBDeviceCredentials credentials,
    required String ipAddress,
  });
  
  /// Applies the ECMP configuration to the device.
  ///
  /// Takes a list of gateways to add and a list of gateways to remove.
  Future<String> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  });

    Future<String> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrRule rule,
  });
}