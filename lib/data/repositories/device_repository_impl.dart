// data/repositories/device_repository_impl.dart
import 'package:dartssh2/dartssh2.dart';
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
    // FIX: This method now handles the connection logic based on the type.
    if (credentials.type == ConnectionType.ssh) {
      // For SSH, we create a temporary client just to check credentials, then close it.
      // The persistent connection will be managed by the LoadBalancingBloc later.
      SSHClient? client;
      try {
        client = SSHClient(
          await SSHSocket.connect(credentials.ip, 22,
              timeout: const Duration(seconds: 10)),
          username: credentials.username,
          onPasswordRequest: () => credentials.password,
        );
        // If the line above doesn't throw an error, credentials are valid.
      } catch (e) {
        // Re-throw as a standardized ServerFailure
        if (e.toString().toLowerCase().contains('auth')) {
          throw const ServerFailure('Authentication failed.');
        } else {
          throw const ServerFailure('Could not connect to host.');
        }
      } finally {
        client?.close();
      }
    } else if (credentials.type == ConnectionType.restApi) {
      // For REST API, we use the datasource method as before.
      return await remoteDataSource.checkRestApiCredentials(credentials);
    } else {
      throw const ServerFailure('Telnet is not implemented.');
    }
  }

  // --- The methods below are no longer used in the new architecture ---
  // The LoadBalancingBloc now communicates directly with the RemoteDataSource.
  // We keep them here to satisfy the DeviceRepository interface but throw an error
  // to prevent accidental use.

  @override
  Future<List<RouterInterface>> getInterfaces(
      DeviceCredentials credentials) async {
    throw UnimplementedError(
        'This method is deprecated. Use LoadBalancingBloc instead.');
  }

  @override
  Future<String> pingGateway(
      {required DeviceCredentials credentials,
      required String ipAddress}) async {
    throw UnimplementedError(
        'This method is deprecated. Use LoadBalancingBloc instead.');
  }

  @override
  Future<String> getRoutingTable(DeviceCredentials credentials) async {
    throw UnimplementedError(
        'This method is deprecated. Use LoadBalancingBloc instead.');
  }
}