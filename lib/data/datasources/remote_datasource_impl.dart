// lib/data/datasources/remote_datasource_impl.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/presentation/screens/connection/connection_screen.dart';
import 'package:ctelnet/ctelnet.dart';
import 'remote_datasource.dart';

class RemoteDataSourceImpl implements RemoteDataSource {
  static const _commandTimeout = Duration(seconds: 20);

  // =======================================================================
  // SSH Implementation (Stable)
  // =======================================================================

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

  // =======================================================================
  // Telnet Implementation
  // =======================================================================

  /// Executes standard, non-interactive commands over Telnet.
  Future<String> _executeTelnetCommands(
      DeviceCredentials credentials, List<String> commands) async {
    final completer = Completer<String>();
    final outputBuffer = StringBuffer();
    CTelnetClient? client;
    StreamSubscription<Message>? subscription;

    var state = 'login';
    int commandIndex = 0;
    final allCommands = ['terminal length 0', ...commands];

    client = CTelnetClient(
      host: credentials.ip,
      port: 23,
      timeout: const Duration(seconds: 15),
      onConnect: () => debugPrint('[TELNET] Connected.'),
      onDisconnect: () {
        debugPrint('[TELNET] Disconnected.');
        if (!completer.isCompleted) {
          completer.complete(outputBuffer.toString());
        }
        subscription?.cancel();
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(ServerFailure("Telnet Error: $error"));
        }
        subscription?.cancel();
      },
    );

    try {
      subscription = (await client.connect())?.listen((data) {
        final receivedText = data.text.trim();
        outputBuffer.write(data.text);
        debugPrint("<< TELNET RECV: ${receivedText.replaceAll('\r\n', ' ')}");

        void executeNextCommand() {
          if (commandIndex < allCommands.length) {
            final cmd = allCommands[commandIndex];
            debugPrint(">> TELNET SEND: $cmd");
            client?.send('$cmd\n');
            commandIndex++;
          } else {
            if (!completer.isCompleted) {
              client?.disconnect();
            }
          }
        }

        switch (state) {
          case 'login':
            if (receivedText.toLowerCase().contains('username')) {
              client?.send('${credentials.username}\n');
            } else if (receivedText.toLowerCase().contains('password')) {
              client?.send('${credentials.password}\n');
            } else if (receivedText.endsWith('>')) {
              state = 'enable';
              client?.send('enable\n');
            } else if (receivedText.endsWith('#')) {
              state = 'executing';
              outputBuffer.clear();
              executeNextCommand();
            }
            break;
          case 'enable':
            if (receivedText.toLowerCase().contains('password')) {
              client?.send('${credentials.enablePassword ?? ''}\n');
            } else if (receivedText.endsWith('#')) {
              state = 'executing';
              outputBuffer.clear();
              executeNextCommand();
            }
            break;
          case 'executing':
            if (receivedText.endsWith('#')) {
              if (commandIndex < allCommands.length) {
                executeNextCommand();
              } else {
                if (!completer.isCompleted) {
                  client?.disconnect();
                }
              }
            }
            break;
        }
      });
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(ServerFailure("Telnet Connection Failed: $e"));
      }
    }

    return completer.future.timeout(_commandTimeout, onTimeout: () {
      client?.disconnect();
      throw const ServerFailure("Telnet operation timed out.");
    });
  }

  /// A specialized method to handle the interactive nature of the ping command over Telnet.
  Future<String> _executeTelnetPing(
      DeviceCredentials credentials, String ipAddress) async {
    final completer = Completer<String>();
    CTelnetClient? client;
    StreamSubscription<Message>? subscription;
    var state = 'login';

    client = CTelnetClient(
      host: credentials.ip,
      port: 23,
      timeout: const Duration(seconds: 15),
      onConnect: () => debugPrint('[PING] Connected.'),
      onDisconnect: () {
        debugPrint('[PING] Disconnected.');
        if (!completer.isCompleted) {
          // If we disconnect before getting a clear result, it's a failure.
          completer.complete('Ping failed. Check IP or connectivity.');
        }
        subscription?.cancel();
      },
      onError: (error) => !completer.isCompleted ? completer.completeError(error) : null,
    );

    try {
      subscription = (await client.connect())?.listen((data) {
        final receivedText = data.text;
        debugPrint("<< PING RECV: ${receivedText.replaceAll('\r\n', ' ')}");

        // Look for immediate success or failure indicators
        if (receivedText.contains('!!!')) {
          if (!completer.isCompleted) {
            completer.complete('Success! Gateway is reachable.');
            client?.disconnect();
          }
        } else if (receivedText.contains('...')) {
           if (!completer.isCompleted) {
            completer.complete('Timeout. Gateway is not reachable.');
            client?.disconnect();
          }
        }

        // Handle login process
        final trimmedText = receivedText.trim();
        if (state == 'login') {
          if (trimmedText.toLowerCase().contains('username')) {
            client?.send('${credentials.username}\n');
          } else if (trimmedText.toLowerCase().contains('password')) {
            client?.send('${credentials.password}\n');
          } else if (trimmedText.endsWith('>')) {
            state = 'enable';
            client?.send('enable\n');
          } else if (trimmedText.endsWith('#')) {
            state = 'executing';
            client?.send('ping $ipAddress repeat 2\n');
          }
        } else if (state == 'enable') {
           if (trimmedText.toLowerCase().contains('password')) {
            client?.send('${credentials.enablePassword ?? ''}\n');
          } else if (trimmedText.endsWith('#')) {
            state = 'executing';
            client?.send('ping $ipAddress repeat 2\n');
          }
        }
      });
    } catch (e) {
       if (!completer.isCompleted) {
          completer.completeError(ServerFailure("Ping Connection Failed: $e"));
       }
    }

    return completer.future.timeout(_commandTimeout, onTimeout: () {
      client?.disconnect();
      // If we time out without a clear success/fail, report a generic timeout.
      return 'Timeout. Gateway is not reachable.';
    });
  }

  // =======================================================================
  // Public API Methods (Now using the correct Telnet helpers)
  // =======================================================================

  @override
  Future<List<RouterInterface>> fetchInterfaces(
      DeviceCredentials credentials) async {
    String result;
    if (credentials.type == ConnectionType.ssh) {
      SSHClient? client;
      try {
        client = await _createSshClient(credentials);
        final rawResult =
            await client.run('show ip interface brief').timeout(_commandTimeout);
        result = utf8.decode(rawResult);
      } finally {
        client?.close();
      }
    } else {
      result =
          await _executeTelnetCommands(credentials, ['show ip interface brief']);
    }

    final lines = result.split('\n');
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
  Future<String> getRoutingTable(DeviceCredentials credentials) async {
    String rawResult;

    if (credentials.type == ConnectionType.ssh) {
      SSHClient? client;
      try {
        client = await _createSshClient(credentials);
        final sshRawResult = await client
            .run('terminal length 0\nshow ip route')
            .timeout(_commandTimeout);
        rawResult = utf8.decode(sshRawResult);
      } finally {
        client?.close();
      }
    } else {
      rawResult = await _executeTelnetCommands(credentials, ['show ip route']);
    }

    final startOfOutput = rawResult.indexOf('show ip route');
    final endOfOutput = rawResult.lastIndexOf(RegExp(r'\S+[>#]'));
    if (startOfOutput != -1 && endOfOutput > startOfOutput) {
      return rawResult
          .substring(startOfOutput + 'show ip route'.length, endOfOutput)
          .trim();
    }
    return rawResult;
  }

  @override
  Future<String> pingGateway(
      DeviceCredentials credentials, String ipAddress) async {
    if (credentials.type == ConnectionType.ssh) {
      SSHClient? client;
      try {
        client = await _createSshClient(credentials);
        final rawSshResult =
            await client.run('ping $ipAddress repeat 2').timeout(_commandTimeout);
        final result = utf8.decode(rawSshResult);
        if (result.contains('!!!')) return 'Success! Gateway is reachable.';
        if (result.contains('...')) return 'Timeout. Gateway is not reachable.';
        return 'Ping failed. Check IP or connectivity.';
      } finally {
        client?.close();
      }
    } else {
      // Use the new, specialized ping method for Telnet
      return await _executeTelnetPing(credentials, ipAddress);
    }
  }

  @override
  Future<void> checkRestApiCredentials(DeviceCredentials credentials) async {
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
