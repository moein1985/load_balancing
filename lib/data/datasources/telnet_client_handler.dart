// lib/data/datasources/telnet_client_handler.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:ctelnet/ctelnet.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';

class TelnetClientHandler {
  static const _commandTimeout = Duration(seconds: 30); // Increased timeout
  static const _connectionTimeout = Duration(seconds: 20);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[TELNET] $message');
    }
  }

  Future<String> _executeTelnetCommands(
      LBDeviceCredentials credentials, List<String> commands) async {
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
      LBDeviceCredentials credentials, String ipAddress) async {
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

  Future<String> fetchDetailedInterfaces(LBDeviceCredentials credentials) async {
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

  Future<String> fetchInterfaces(LBDeviceCredentials credentials) async {
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

  Future<String> getRoutingTable(LBDeviceCredentials credentials) async {
    try {
      final result = await _executeTelnetCommands(credentials, ['show ip route']);
      _logDebug('Telnet routing table fetched');
      return result;
    } catch (e) {
      _logDebug('Error fetching Telnet routing table: $e');
      rethrow;
    }
  }

  Future<String> pingGateway(LBDeviceCredentials credentials, String ipAddress) async {
    return await _executeTelnetPing(credentials, ipAddress);
  }
  
  Future<String> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    _logDebug('Applying ECMP config via Telnet. ToAdd: ${gatewaysToAdd.join(", ")} - ToRemove: ${gatewaysToRemove.join(", ")}');
    try {
      // Dynamically build the list of commands
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
        _logDebug('No changes to apply for ECMP config via Telnet.');
        return 'No ECMP configuration changes were needed.';
      }

      // _executeTelnetCommands already adds 'terminal length 0'
      final result = await _executeTelnetCommands(credentials, commands);
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

    Future<String> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrRule rule,
  }) async {
    _logDebug('Applying PBR rule with Telnet: ${rule.ruleName}');
    try {
      // ساخت دستورات PBR
      final List<String> commands = ['configure terminal'];

      // 1. ساخت Access List (با شماره 101 به عنوان مثال)
      final aclCommand =
          'access-list 101 permit ${rule.protocol} ${rule.sourceAddress} any ${rule.destinationAddress} any${rule.destinationPort != 'any' ? ' eq ${rule.destinationPort}' : ''}';
      commands.add(aclCommand);

      // 2. ساخت Route Map
      commands.add('route-map ${rule.ruleName} permit 10');
      commands.add('match ip address 101');
      if (rule.actionType == PbrActionType.nextHop) {
        commands.add('set ip next-hop ${rule.nextHop}');
      } else {
        commands.add('set interface ${rule.egressInterface}');
      }
      commands.add('exit');

      // 3. اعمال Route Map به اینترفیس
      commands.add('interface ${rule.applyToInterface}');
      commands.add('ip policy route-map ${rule.ruleName}');
      commands.add('end');

      final result = await _executeTelnetCommands(credentials, commands);
      _logDebug('PBR config commands executed via Telnet');

      if (result.toLowerCase().contains('invalid input') || result.toLowerCase().contains('error')) {
        return 'Failed to apply PBR configuration. Router response: ${result.split('\n').lastWhere((line) => line.contains('%') || line.contains('^'), orElse: () => 'Unknown error')}';
      }

      return 'PBR rule "${rule.ruleName}" applied successfully.';
    } catch (e) {
      return 'An error occurred while applying PBR rule: ${e.toString()}';
    }
  }
}