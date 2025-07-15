// lib/data/datasources/remote_datasource_impl.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'remote_datasource.dart';

class RemoteDataSourceImpl implements RemoteDataSource {
  static const _commandTimeout = Duration(seconds: 15);

  /// Helper to establish a new SSH client connection for each request.
  Future<SSHClient> _createSshClient(DeviceCredentials credentials) async {
    try {
      final socket = await SSHSocket.connect(credentials.ip, 22,
          timeout: const Duration(seconds: 10));
      return SSHClient(
        socket,
        username: credentials.username,
        onPasswordRequest: () => credentials.password,
      );
    } on TimeoutException {
      throw const ServerFailure('Connection timed out.');
    } on SocketException {
      throw const ServerFailure('Could not connect to host.');
    } catch (e) {
      if (e.toString().toLowerCase().contains('auth')) {
        throw const ServerFailure('Authentication failed.');
      }
      throw ServerFailure('SSH Error: ${e.toString()}');
    }
  }

  @override
  Future<List<RouterInterface>> fetchInterfaces(
      DeviceCredentials credentials) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
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
    } finally {
      client?.close();
    }
  }

  @override
  Future<String> getRoutingTable(DeviceCredentials credentials) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      // Use the reliable interactive shell method for this multi-step command.
      final shell = await client.shell(
        pty: SSHPtyConfig(type: 'xterm', width: 120, height: 80),
      );

      final completer = Completer<String>();
      final buffer = StringBuffer();
      late StreamSubscription subscription;
      const prompt = '#';
      int promptCount = 0;

      subscription = shell.stdout.listen(
        (data) {
          final decodedString = utf8.decode(data, allowMalformed: true);
          buffer.write(decodedString);
          if (decodedString.trim().endsWith(prompt)) {
            promptCount++;
            if (promptCount == 1) {
              shell.stdin.add(utf8.encode('terminal length 0\n'));
            } else if (promptCount == 2) {
              shell.stdin.add(utf8.encode('show ip route\n'));
            } else if (promptCount == 3) {
              if (!completer.isCompleted) {
                subscription.cancel();
                final fullOutput = buffer.toString();
                final startOfOutput = fullOutput.indexOf('show ip route\r\n');
                final endOfOutput = fullOutput.lastIndexOf(prompt);
                if (startOfOutput != -1 && endOfOutput > startOfOutput) {
                  final commandAndNewlineLength = 'show ip route\r\n'.length;
                  final relevantOutput = fullOutput.substring(
                      startOfOutput + commandAndNewlineLength, endOfOutput);
                  completer.complete(relevantOutput.trim());
                } else {
                  completer.complete(fullOutput.trim());
                }
              }
            }
          }
        },
        onError: (error) =>
            !completer.isCompleted ? completer.completeError(error) : null,
        onDone: () => !completer.isCompleted
            ? completer.complete(buffer.toString().trim())
            : null,
      );

      return await completer.future.timeout(_commandTimeout);
    } finally {
      client?.close();
    }
  }

  @override
  Future<String> pingGateway(
      DeviceCredentials credentials, String ipAddress) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
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
    } finally {
      client?.close();
    }
  }

  @override
  Future<void> checkRestApiCredentials(DeviceCredentials credentials) async {
    // REST API is stateless and doesn't need the same connection management.
    final dio = Dio();
    final String basicAuth =
        'Basic ${base64Encode(utf8.encode('${credentials.username}:${credentials.password}'))}';
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return client;
    };
    try {
      await dio.get(
        'https://${credentials.ip}/restconf/data/Cisco-IOS-XE-native:native',
        options: Options(
          headers: {
            'Authorization': basicAuth,
            'Accept': 'application/yang-data+json'
          },
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ServerFailure(
            'Authentication failed. Check username and password.');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const ServerFailure(
            'Connection timed out. Check IP and that RESTCONF is enabled.');
      } else {
        throw ServerFailure(
            'RESTCONF error: ${e.message ?? 'Unknown Dio error'}');
      }
    } catch (e) {
      throw ServerFailure('An unknown error occurred: ${e.toString()}');
    }
  }
}
