// lib/data/datasources/handlers/connection_handler.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_submission.dart';

import '../../../domain/entities/route_map.dart';

/// Defines the contract for connection handlers (SSH, Telnet, etc.).
/// This ensures that the RemoteDataSource can interact with any handler
/// in a consistent way.
abstract class ConnectionHandler {
  /// Fetches a bundle of data required to build the interface list.
  /// Returns a map with 'brief' and 'detailed' config outputs.
  Future<Map<String, String>> fetchInterfaceDataBundle(
    LBDeviceCredentials credentials,
  );

  /// Fetches the raw routing table from the device.
  Future<String> getRoutingTable(LBDeviceCredentials credentials);

  /// Fetches the entire running configuration from the device.
  Future<String> getRunningConfig(LBDeviceCredentials credentials);

  /// Executes a ping command on the device.
  Future<String> pingGateway(LBDeviceCredentials credentials, String ipAddress);

  /// Applies an ECMP (Equal-Cost Multi-Path) configuration.
  Future<String> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  });

  /// Applies a PBR (Policy-Based Routing) configuration.
  Future<String> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrSubmission submission,
  });

  Future<String> deletePbrRule({
    required LBDeviceCredentials credentials,
    required RouteMap ruleToDelete,
  });
}
