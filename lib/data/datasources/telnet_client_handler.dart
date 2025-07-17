// lib/data/datasources/telnet_client_handler.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:ctelnet/ctelnet.dart';

class TelnetClientHandler {
  static const _commandTimeout = Duration(seconds: 30); // Increased timeout
  static const _connectionTimeout = Duration(seconds: 20);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[TELNET] $message');
    }
  }

  Future<String> _executeTelnetCommands(
      DeviceCredentials credentials, List<String> commands) async {
    _logDebug('Starting execution of Telnet commands');
    final completer = Completer<String>();
    final outputBuffer = StringBuffer();
    CTelnetClient? client;
    StreamSubscription<Message>? subscription;

    var state = 'login';
    int commandIndex = 0;
    // Prepend 'terminal length 0' to avoid pagination
    final allCommands = ['terminal length 0', ...commands];
    Timer? timeoutTimer;

    // Setup timeout timer for the whole operation
    timeoutTimer = Timer(_commandTimeout, () {
      _logDebug('Telnet operation timed out');
      if (!completer.isCompleted) {
        client?.disconnect();
        completer.completeError(const ServerFailure("Telnet operation timed out."));
      }
    });

    client = CTelnetClient(
      host: credentials.ip,
      port: 23,
      timeout: _connectionTimeout,
      onConnect: () {
        _logDebug('Telnet connection established');
      },
      onDisconnect: () {
        _logDebug('Telnet connection closed');
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(outputBuffer.toString());
        }
        subscription?.cancel();
      },
      onError: (error) {
        _logDebug('Telnet error: $error');
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(ServerFailure("Telnet Error: $error"));
        }
        subscription?.cancel();
      },
    );

    void executeNextCommand() {
      if (commandIndex < allCommands.length) {
        final cmd = allCommands[commandIndex];
        _logDebug("Sending Telnet: $cmd");
        client?.send('$cmd\n');
        commandIndex++;
      } else {
        // Short delay before disconnecting to ensure all output is received
        Timer(const Duration(seconds: 1), () {
          if (!completer.isCompleted) {
            client?.disconnect();
          }
        });
      }
    }

    try {
      subscription = (await client.connect())?.listen((data) {
        final receivedText = data.text.trim();
        outputBuffer.write(data.text);
        _logDebug("Telnet Received: ${receivedText.replaceAll('\r\n', ' ')}");

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
              outputBuffer.clear(); // Clear buffer before starting commands
              executeNextCommand();
            }
            break;
          case 'enable':
            if (receivedText.toLowerCase().contains('password')) {
              client?.send('${credentials.enablePassword ?? ''}\n');
            } else if (receivedText.endsWith('#')) {
              state = 'executing';
              outputBuffer.clear(); // Clear buffer before starting commands
              executeNextCommand();
            }
            break;
          case 'executing':
            if (receivedText.endsWith('#')) {
              if (commandIndex < allCommands.length) {
                executeNextCommand();
              } else {
                // Short delay before disconnecting
                Timer(const Duration(seconds: 1), () {
                  if (!completer.isCompleted) {
                    client?.disconnect();
                  }
                });
              }
            }
            break;
        }
      });
    } catch (e) {
      _logDebug('Error on Telnet connect: $e');
      timeoutTimer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(ServerFailure("Telnet connection failed: $e"));
      }
    }

    return completer.future;
  }

  Future<String> _executeTelnetPing(
      DeviceCredentials credentials, String ipAddress) async {
    _logDebug('Starting Telnet ping for IP: $ipAddress');
    final completer = Completer<String>();
    CTelnetClient? client;
    StreamSubscription<Message>? subscription;
    var state = 'login';
    final outputBuffer = StringBuffer();
    bool commandSent = false;
    Timer? timeoutTimer;

    // Setup timeout timer
    timeoutTimer = Timer(_commandTimeout, () {
      _logDebug('Ping operation timed out');
      if (!completer.isCompleted) {
        client?.disconnect();
        completer.complete('Timeout. Gateway is not reachable.');
      }
    });

    client = CTelnetClient(
      host: credentials.ip,
      port: 23,
      timeout: _connectionTimeout,
      onConnect: () => _logDebug('Telnet ping connection established'),
      onDisconnect: () {
        _logDebug('Telnet ping connection closed');
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          final output = outputBuffer.toString();
          final result = _analyzePingResult(output);
          completer.complete(result);
        }
        subscription?.cancel();
      },
      onError: (error) {
        _logDebug('Telnet ping error: $error');
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(ServerFailure("Ping error: $error"));
        }
      },
    );

    try {
      subscription = (await client.connect())?.listen((data) {
        final receivedText = data.text;
        outputBuffer.write(receivedText);
        _logDebug("Ping Received: ${receivedText.replaceAll('\r\n', ' ')}");

        // Check for ping results in every message
        if (receivedText.contains('!!!!!') ||
            receivedText.contains('Success rate is 100') ||
            receivedText.contains('Success rate is 80')) {
          if (!completer.isCompleted) {
            timeoutTimer?.cancel();
            completer.complete('Success! Gateway is reachable.');
            client?.disconnect();
            return;
          }
        } else if (receivedText.contains('.....') ||
            receivedText.contains('Success rate is 0')) {
          if (!completer.isCompleted) {
            timeoutTimer?.cancel();
            completer.complete('Timeout. Gateway is not reachable.');
            client?.disconnect();
            return;
          }
        }

        final trimmedText = receivedText.trim();
        switch (state) {
          case 'login':
            if (trimmedText.toLowerCase().contains('username')) {
              client?.send('${credentials.username}\n');
            } else if (trimmedText.toLowerCase().contains('password')) {
              client?.send('${credentials.password}\n');
            } else if (trimmedText.endsWith('>')) {
              state = 'enable';
              client?.send('enable\n');
            } else if (trimmedText.endsWith('#')) {
              state = 'executing';
              if (!commandSent) {
                client?.send('ping $ipAddress repeat 5\n');
                commandSent = true;
              }
            }
            break;
          case 'enable':
            if (trimmedText.toLowerCase().contains('password')) {
              client?.send('${credentials.enablePassword ?? ''}\n');
            } else if (trimmedText.endsWith('#')) {
              state = 'executing';
              if (!commandSent) {
                client?.send('ping $ipAddress repeat 5\n');
                commandSent = true;
              }
            }
            break;
        }
      });
    } catch (e) {
      _logDebug('Error in Telnet ping: $e');
      timeoutTimer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(ServerFailure("Ping connection failed: $e"));
      }
    }

    return completer.future;
  }

  Future<String> fetchDetailedInterfaces(DeviceCredentials credentials) async {
    try {
      final result = await _executeTelnetCommands(credentials, ['show running-config']);
      _logDebug('Telnet detailed config fetched');
      return result;
    } catch (e) {
      _logDebug('Error fetching Telnet detailed config: $e');
      rethrow;
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

  Future<String> fetchInterfaces(DeviceCredentials credentials) async {
    try {
      final result = await _executeTelnetCommands(
          credentials, ['show ip interface brief']);
      _logDebug('Telnet interfaces fetched');
      return result;
    } catch (e) {
      _logDebug('Error fetching Telnet interfaces: $e');
      rethrow;
    }
  }

  Future<String> getRoutingTable(DeviceCredentials credentials) async {
    try {
      final result = await _executeTelnetCommands(credentials, ['show ip route']);
      _logDebug('Telnet routing table fetched');
      return result;
    } catch (e) {
      _logDebug('Error fetching Telnet routing table: $e');
      rethrow;
    }
  }

  Future<String> pingGateway(DeviceCredentials credentials, String ipAddress) async {
    return await _executeTelnetPing(credentials, ipAddress);
  }
  
  // New method to apply ECMP configuration via Telnet
  Future<String> applyEcmpConfig(DeviceCredentials credentials, String gateway1, String gateway2) async {
    _logDebug('Applying ECMP config via Telnet for gateways: $gateway1, $gateway2');
    try {
       final commands = [
        'configure terminal',
        'ip route 0.0.0.0 0.0.0.0 $gateway1',
        'ip route 0.0.0.0 0.0.0.0 $gateway2',
        'end'
      ];
      // We don't need 'terminal length 0' here, as _executeTelnetCommands adds it.
      // We pass the commands directly.
      final result = await _executeTelnetCommands(credentials, commands.sublist(1));
       _logDebug('ECMP config commands sent via Telnet');

      if (result.toLowerCase().contains('invalid input') || result.toLowerCase().contains('error')) {
          _logDebug('Error applying ECMP config via Telnet: $result');
          return 'Failed to apply ECMP configuration. Router response: ${result.split('\n').lastWhere((line) => line.contains('%') || line.contains('^'), orElse: () => 'Unknown error')}';
      }

      return 'ECMP configuration applied successfully.';
    } catch (e) {
       _logDebug('Error applying ECMP config via Telnet: $e');
       return 'An error occurred while applying ECMP configuration: ${e.toString()}';
    }
  }
}