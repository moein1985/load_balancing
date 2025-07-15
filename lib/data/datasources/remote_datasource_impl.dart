// data/datasources/remote_datasource_impl.dart
import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'remote_datasource.dart';

class RemoteDataSourceImpl implements RemoteDataSource {
  static const _commandTimeout = Duration(seconds: 15);

  @override
  Future<List<RouterInterface>> fetchInterfaces(SSHClient client) async {
    final result =
        await client.run('show ip interface brief').timeout(_commandTimeout);
    final decodedResult = utf8.decode(result);
    final lines = decodedResult.split('\n');
    final interfaces = <RouterInterface>[];
    final regex = RegExp(
        r'^(\S+)\s+([\d\.]+)\s+\w+\s+\w+\s+(up|down|administratively down)');

    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        interfaces.add(RouterInterface(
          name: match.group(1)!,
          ipAddress: match.group(2)!,
          status: match.group(3)!,
        ));
      }
    }
    return interfaces;
  }

  @override
  Future<String> pingGateway(SSHClient client, String ipAddress) async {
    final result =
        await client.run('ping $ipAddress repeat 2').timeout(_commandTimeout);
    final decodedResult = utf8.decode(result);
    if (decodedResult.contains('!!!')) {
      return 'Success! Gateway is reachable.';
    } else if (decodedResult.contains('...')) {
      return 'Timeout. Gateway is not reachable.';
    } else {
      return 'Ping failed. Check IP or connectivity.';
    }
  }

  @override
  Future<String> getRoutingTable(SSHClient client) async {
    // Run commands sequentially on the SAME client.
    await client.run('terminal length 0').timeout(_commandTimeout);
    final result = await client.run('show ip route').timeout(_commandTimeout);
    return utf8.decode(result);
  }
}