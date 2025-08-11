// lib/data/repositories/device_repository_impl.dart
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/data/datasources/remote_datasource.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';
import 'package:load_balance/presentation/screens/connection/connection_screen.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final RemoteDataSource remoteDataSource;

  DeviceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> checkCredentials(DeviceCredentials credentials) async {
    // For SSH and Telnet, verifying credentials by fetching interfaces is a reliable check.
    if (credentials.type == ConnectionType.ssh ||
        credentials.type == ConnectionType.telnet) {
      try {
        await remoteDataSource.fetchInterfaces(credentials);
      } on ServerFailure catch (e) {
        throw ServerFailure(e.message);
      } catch (e) {
        throw ServerFailure(e.toString());
      }
    }
  }

  @override
  Future<List<RouterInterface>> getInterfaces(
    DeviceCredentials credentials,
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
  Future<String> getRoutingTable(DeviceCredentials credentials) async {
    try {
      return await remoteDataSource.getRoutingTable(credentials);
    } on ServerFailure catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Future<String> pingGateway({
    required DeviceCredentials credentials,
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
    required DeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    try {
      // Pass the call with the new parameters to the data source
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
    required DeviceCredentials credentials,
    required PbrRule rule,
  }) async {
    try {
      return await remoteDataSource.applyPbrRule(
        credentials: credentials,
        rule: rule,
      );
    } on ServerFailure catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}