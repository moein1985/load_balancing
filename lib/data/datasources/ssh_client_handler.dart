// lib/data/datasources/ssh_client_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';

class SshClientHandler {
  static const _commandTimeout = Duration(seconds: 30);
  static const _connectionTimeout = Duration(seconds: 10);
  static const _delayBetweenCommands = Duration(milliseconds: 500);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[SSH] $message');
    }
  }

  Future<SSHClient> _createSshClient(DeviceCredentials credentials) async {
    _logDebug('Creating SSH connection to ${credentials.ip}');
    try {
      final socket = await SSHSocket.connect(
        credentials.ip,
        22,
        timeout: _connectionTimeout,
      );
      final client = SSHClient(
        socket,
        username: credentials.username,
        onPasswordRequest: () => credentials.password,
      );
      _logDebug('SSH connection established');
      return client;
    } on TimeoutException {
      _logDebug('Error: SSH connection timed out');
      throw const ServerFailure(
        'Connection timed out. Please check the IP address and port.',
      );
    } on SocketException catch (e) {
      _logDebug('Error: SSH connection failed - ${e.message}');
      throw const ServerFailure(
        'Unable to connect to the device. Check the IP address and port.',
      );
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('auth')) {
        _logDebug('Error: SSH authentication failed');
        throw const ServerFailure(
          'Authentication failed. Check your username and password.',
        );
      }
      _logDebug('Error: SSH - $e');
      throw ServerFailure('SSH Error: ${e.toString()}');
    }
  }

  Future<String> _executeSshCommand(SSHClient client, String command) async {
    try {
      _logDebug('Executing SSH command: $command');
      final result = await client.run(command).timeout(_commandTimeout);
      final output = utf8.decode(result);
      _logDebug('SSH command executed, output length: ${output.length}');
      return output;
    } catch (e) {
      _logDebug('Error executing SSH command: $e');
      rethrow;
    }
  }

  Future<String> _executeSshCommandsWithShell(
    SSHClient client,
    List<String> commands,
  ) async {
    _logDebug('Starting execution of SSH commands with Shell');
    try {
      final shell = await client.shell(
        pty: SSHPtyConfig(width: 80, height: 24),
      );
      final completer = Completer<String>();
      final output = StringBuffer();
      bool isReady = false;
      int commandIndex = 0;

      void sendNextCommand() {
        if (commandIndex < commands.length) {
          final command = commands[commandIndex];
          _logDebug('Sending SSH Shell command: $command');
          shell.stdin.add(utf8.encode('$command\n'));
          commandIndex++;
        }
      }

      shell.stdout.cast<List<int>>().transform(utf8.decoder).listen((data) {
        output.write(data);
        _logDebug(
          'SSH Shell Output: ${data.replaceAll('\r\n', '\\n').replaceAll('\n', '\\n')}',
        );

        // Wait for the prompt before sending the first command
        if (!isReady && (data.contains('#') || data.contains('>'))) {
          isReady = true;
          sendNextCommand();
        }
        // After a command is sent, wait for the next prompt to send the next command
        else if (isReady && (data.contains('#') || data.contains('>'))) {
          if (commandIndex < commands.length) {
            sendNextCommand();
          } else {
            // All commands sent, close the shell and complete
            shell.close();
            if (!completer.isCompleted) {
              completer.complete(output.toString());
            }
          }
        }
      });
      shell.stderr.cast<List<int>>().transform(utf8.decoder).listen((data) {
        _logDebug('SSH Shell Error: $data');
        output.write(data);
      });
      // General timeout for the whole operation
      Timer(_commandTimeout, () {
        if (!completer.isCompleted) {
          shell.close();
          completer.completeError(
            TimeoutException('SSH Shell operation timed out', _commandTimeout),
          );
        }
      });
      return await completer.future;
    } catch (e) {
      _logDebug('Error in SSH Shell: $e');
      rethrow;
    }
  }

  Future<String> fetchInterfaces(DeviceCredentials credentials) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      final result = await _executeSshCommand(
        client,
        'show ip interface brief',
      );
      _logDebug('SSH interfaces fetched');
      return result;
    } catch (e) {
      _logDebug('Error fetching SSH interfaces: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  Future<String> fetchDetailedInterfaces(DeviceCredentials credentials) async {
    SSHClient?
    client;
    try {
      client = await _createSshClient(credentials);
      final result = await _executeSshCommand(client, 'show running-config');
      _logDebug('SSH detailed config fetched');
      return result;
    } catch (e) {
      _logDebug('Error fetching SSH detailed config: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  Future<String> getRoutingTable(DeviceCredentials credentials) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      try {
        final result = await _executeSshCommandsWithShell(client, [
          'terminal length 0',
          'show ip route',
        ]);
        _logDebug('SSH routing table fetched with Shell');
        return result;
      } catch (e) {
        _logDebug('Error in SSH Shell, trying legacy method: $e');
        await _executeSshCommand(client, 'terminal length 0');
        await Future.delayed(_delayBetweenCommands);
        final result = await _executeSshCommand(client, 'show ip route');
        _logDebug('SSH routing table fetched with legacy method');
        return result;
      }
    } catch (e) {
      _logDebug('Error fetching SSH routing table: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  Future<String> pingGateway(
    DeviceCredentials credentials,
    String ipAddress,
  ) async {
    _logDebug('Starting SSH ping for IP: $ipAddress');
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      final result = await _executeSshCommand(
        client,
        'ping $ipAddress repeat 5',
      );
      _logDebug('SSH ping result received');
      return _analyzePingResult(result);
    } finally {
      client?.close();
    }
  }

  String _analyzePingResult(String output) {
    _logDebug('Analyzing ping result');
    if (output.contains('!!!!!') ||
        output.contains('Success rate is 100') ||
        output.contains('Success rate is 80')) {
      return 'Success! Gateway is reachable.';
    } else if (output.contains('.....') ||
        output.contains('Success rate is 0')) {
      return 'Timeout. Gateway is not reachable.';
    } else if (output.toLowerCase().contains('unknown host')) {
      return 'Error: Unknown host.';
    } else if (output.toLowerCase().contains('network unreachable')) {
      return 'Error: Network unreachable.';
    }

    return 'Ping failed. Check the IP or connection.';
  }

  Future<String> applyEcmpConfig({
    required DeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    _logDebug('Applying ECMP config. ToAdd: ${gatewaysToAdd.join(", ")} - ToRemove: ${gatewaysToRemove.join(", ")}');
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      final List<String> commands = ['configure terminal'];

      // Generate commands to remove old gateways
      for (final gateway in gatewaysToRemove) {
        if (gateway.trim().isNotEmpty) {
          commands.add('no ip route 0.0.0.0 0.0.0.0 $gateway');
        }
      }

      // Generate commands to add new gateways
      for (final gateway in gatewaysToAdd) {
        if (gateway.trim().isNotEmpty) {
          commands.add('ip route 0.0.0.0 0.0.0.0 $gateway');
        }
      }
      commands.add('end');

      // Do nothing if there are no gateways to add or remove
      if (gatewaysToAdd.isEmpty && gatewaysToRemove.isEmpty) {
        _logDebug('No changes to apply for ECMP config.');
        return 'No ECMP configuration changes were needed.';
      }

      final result = await _executeSshCommandsWithShell(client, commands);
      _logDebug('ECMP config commands executed');

      if (result.toLowerCase().contains('invalid input') ||
          result.toLowerCase().contains('error')) {
        _logDebug('Error applying ECMP config: $result');
        return 'Failed to apply ECMP configuration. Router response: ${result.split('\n').lastWhere((line) => line.contains('%') || line.contains('^'), orElse: () => 'Unknown error')}';
      }

      return 'ECMP configuration applied successfully.';
    } catch (e) {
      _logDebug('Error applying ECMP config: $e');
      return 'An error occurred while applying ECMP configuration: ${e.toString()}';
    } finally {
      client?.close();
    }
  }
}