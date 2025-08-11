// lib/data/datasources/remote_datasource.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

abstract class RemoteDataSource {
  Future<List<RouterInterface>> fetchInterfaces(DeviceCredentials credentials);
  Future<String> getRoutingTable(DeviceCredentials credentials);
  Future<String> pingGateway(DeviceCredentials credentials, String ipAddress);
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