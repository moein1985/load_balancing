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
    // FIX: Handle Telnet connections in the same way as SSH for credential checks.
    // For both SSH and Telnet, we can verify credentials by attempting to fetch interfaces.
    // If it succeeds, the credentials are valid.
    if (credentials.type == ConnectionType.ssh || credentials.type == ConnectionType.telnet) {
      try {
        // This call will be routed to the correct SSH or Telnet implementation
        // inside the remoteDataSource.
        await remoteDataSource.fetchInterfaces(credentials);
      } on ServerFailure catch (e) {
        // Re-throw the specific failure message from the data source.
        throw ServerFailure(e.message);
      } catch (e) {
        // Catch any other unexpected errors.
        throw ServerFailure(e.toString());
      }
    } else if (credentials.type == ConnectionType.restApi) {
      // REST API has its own separate check.
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
}
