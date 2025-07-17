// lib/data/datasources/remote_datasource.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

abstract class RemoteDataSource {
  Future<void> checkRestApiCredentials(DeviceCredentials credentials);
  Future<List<RouterInterface>> fetchInterfaces(DeviceCredentials credentials);
  Future<String> getRoutingTable(DeviceCredentials credentials);
  Future<String> pingGateway(DeviceCredentials credentials, String ipAddress);
  // New method to apply ECMP configuration
  Future<String> applyEcmpConfig(DeviceCredentials credentials, String gateway1, String gateway2);
}