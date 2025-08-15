// lib/data/repositories/device_repository_impl.dart
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/data/datasources/remote_datasource.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';
import 'package:load_balance/presentation/screens/connection/router_connection_screen.dart';

import '../../domain/entities/pbr_submission.dart';
import '../../domain/entities/route_map.dart';

class DeviceRepositoryImpl implements RouterRepository {
  final RemoteDataSource remoteDataSource;
  DeviceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<RouterInterface>> checkCredentials(
    LBDeviceCredentials credentials,
  ) async {
    // For SSH and Telnet, verifying credentials by fetching interfaces is a reliable check.
    if (credentials.type == ConnectionType.ssh ||
        credentials.type == ConnectionType.telnet) {
      try {
        return await remoteDataSource.fetchInterfaces(credentials);
      } on ServerFailure catch (e) {
        throw ServerFailure(e.message);
      } catch (e) {
        throw ServerFailure(e.toString());
      }
    }
    return [];
  }

  @override
  Future<List<RouterInterface>> getInterfaces(
    LBDeviceCredentials credentials,
  ) async {
    try {
      return await remoteDataSource.fetchInterfaces(credentials);
    } on ServerFailure catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> getRoutingTable(LBDeviceCredentials credentials) async {
    try {
      return await remoteDataSource.getRoutingTable(credentials);
    } on ServerFailure catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // **تغییر اصلی در اینجا برای حل مشکل Retry**
  @override
  Future<String> getRunningConfig(LBDeviceCredentials credentials) async {
    int retries = 1; // 1 تلاش مجدد (مجموعاً ۲ بار)
    while (true) {
      try {
        return await remoteDataSource.fetchRunningConfig(credentials);
      } on ServerFailure catch (e) {
        // فقط برای خطاهای خاص اتصال، دوباره تلاش کن
        if (e.message.toLowerCase().contains('connection closed') && retries > 0) {
          retries--;
          await Future.delayed(const Duration(milliseconds: 500)); // یک وقفه کوتاه
        } else {
          throw ServerFailure(e.message); // در غیر این صورت، خطا را برگردان
        }
      } catch (e) {
        throw ServerFailure(e.toString());
      }
    }
  }

  @override
  Future<String> pingGateway({
    required LBDeviceCredentials credentials,
    required String ipAddress,
  }) async {
    try {
      return await remoteDataSource.pingGateway(credentials, ipAddress);
    } on ServerFailure catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Future<String> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    try {
      return await remoteDataSource.applyEcmpConfig(
        credentials: credentials,
        gatewaysToAdd: gatewaysToAdd,
        gatewaysToRemove: gatewaysToRemove,
      );
    } on ServerFailure catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Future<String> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrSubmission submission,
  }) async {
    try {
      return await remoteDataSource.applyPbrRule(
        credentials: credentials,
        submission: submission,
      );
    } on ServerFailure catch (e) {
      // Re-throw to be handled by the use case/bloc
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> deletePbrRule({
    required LBDeviceCredentials credentials,
    required RouteMap ruleToDelete,
  }) async {
    try {
      return await remoteDataSource.deletePbrRule(
        credentials: credentials,
        ruleToDelete: ruleToDelete,
      );
    } on ServerFailure catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}