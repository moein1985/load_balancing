// data/datasources/remote_datasource.dart
import 'package:dartssh2/dartssh2.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

// The interface now expects an active SSHClient for SSH operations.
abstract class RemoteDataSource {
  Future<List<RouterInterface>> fetchInterfaces(SSHClient client);
  Future<String> pingGateway(SSHClient client, String ipAddress);
  Future<String> getRoutingTable(SSHClient client);
}