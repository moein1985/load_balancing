// lib/data/datasources/remote_datasource.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

import '../../domain/entities/pbr_submission.dart';

abstract class RemoteDataSource {
  Future<List<RouterInterface>> fetchInterfaces(LBDeviceCredentials credentials);
  Future<String> getRoutingTable(LBDeviceCredentials credentials);

  /// **متد جدید:** برای دریافت کانفیگ خام از روتر.
  Future<String> fetchRunningConfig(LBDeviceCredentials credentials);

  Future<String> pingGateway(LBDeviceCredentials credentials, String ipAddress);

  Future<String> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  });
  
  Future<String> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrSubmission  submission,
  });
}