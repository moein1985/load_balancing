// lib/domain/repositories/router_repository.dart
import 'package:fpdart/fpdart.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import '../entities/pbr_submission.dart';
import '../entities/route_map.dart';

abstract class RouterRepository {
  Future<Either<Failure, List<RouterInterface>>> checkCredentials(
      LBDeviceCredentials credentials);

  Future<Either<Failure, List<RouterInterface>>> getInterfaces(
      LBDeviceCredentials credentials);

  Future<Either<Failure, String>> getRoutingTable(
      LBDeviceCredentials credentials);

  Future<Either<Failure, String>> deletePbrRule(
      {required LBDeviceCredentials credentials,
      required RouteMap ruleToDelete});

  Future<Either<Failure, String>> getRunningConfig(
      LBDeviceCredentials credentials);

  Future<Either<Failure, String>> pingGateway({
    required LBDeviceCredentials credentials,
    required String ipAddress,
  });

  Future<Either<Failure, String>> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  });

  Future<Either<Failure, String>> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrSubmission submission,
  });
}