// lib/data/repositories/device_repository_impl.dart
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/data/datasources/remote_datasource.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
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
    } else if (credentials.type == ConnectionType.restApi) {
      return await remoteDataSource.checkRestApiCredentials(credentials);
    }
  }

  @override
  Future<List<RouterInterface>> getInterfaces(
      DeviceCredentials credentials) async {
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
  Future<String> pingGateway(
      {required DeviceCredentials credentials,
      required String ipAddress}) async {
    try {
      return await remoteDataSource.pingGateway(credentials, ipAddress);
    } on ServerFailure catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Implementation for the new ECMP method
  @override
  Future<String> applyEcmpConfig(
      {required DeviceCredentials credentials,
      required String gateway1,
      required String gateway2}) async {
    try {
      return await remoteDataSource.applyEcmpConfig(credentials, gateway1, gateway2);
    } on ServerFailure catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}