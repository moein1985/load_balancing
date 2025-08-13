// lib/domain/repositories/router_repository.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

import '../entities/pbr_submission.dart';
import '../entities/route_map.dart';

abstract class RouterRepository {
  // این متد دیگر void نیست و لیست اینترفیس‌ها را برمی‌گرداند
  Future<List<RouterInterface>> checkCredentials(LBDeviceCredentials credentials);
  Future<List<RouterInterface>> getInterfaces(LBDeviceCredentials credentials);
  Future<String> getRoutingTable(LBDeviceCredentials credentials);
  Future<String> deletePbrRule({ required LBDeviceCredentials credentials, required RouteMap ruleToDelete });
  /// **متد جدید:** تمام کانفیگ در حال اجرا را به صورت یک رشته خام برمی‌گرداند.
  Future<String> getRunningConfig(LBDeviceCredentials credentials);

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
    required PbrSubmission submission, 
  });
}