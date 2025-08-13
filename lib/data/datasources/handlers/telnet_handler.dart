// lib/data/datasources/handlers/telnet_handler.dart
import 'dart:async';
import 'package:ctelnet/ctelnet.dart';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_submission.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'connection_handler.dart';

class TelnetHandler implements ConnectionHandler {
  static const _commandTimeout = Duration(seconds: 30);
  static const _connectionTimeout = Duration(seconds: 20);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[TELNET] $message');
    }
  }

  @override
  Future<Map<String, String>> fetchInterfaceDataBundle(
    LBDeviceCredentials credentials,
  ) async {
    final brief = await fetchInterfaces(credentials);
    final detailed = await fetchDetailedInterfaces(credentials);
    return {'brief': brief, 'detailed': detailed};
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

  @override
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

  @override
  Future<String> getRunningConfig(LBDeviceCredentials credentials) async {
    try {
      final result = await _executeTelnetCommands(credentials, ['show running-config']);
      _logDebug('Telnet running-config fetched');
      return result;
    } catch (e) {
      _logDebug('Error fetching Telnet running-config: $e');
      rethrow;
    }
  }

  @override
  Future<String> pingGateway(
    LBDeviceCredentials credentials,
    String ipAddress,
  ) async {
    return await _executeTelnetPing(credentials, ipAddress);
  }

  @override
  Future<String> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    _logDebug('Applying ECMP config via Telnet. ToAdd: ${gatewaysToAdd.join(", ")} - ToRemove: ${gatewaysToRemove.join(", ")}');
    try {
      final List<String> commands = ['configure terminal'];
      for (final gateway in gatewaysToRemove) {
        if (gateway.trim().isNotEmpty) {
          commands.add('no ip route 0.0.0.0 0.0.0.0 $gateway');
        }
      }
      for (final gateway in gatewaysToAdd) {
        if (gateway.trim().isNotEmpty) {
          commands.add('ip route 0.0.0.0 0.0.0.0 $gateway');
        }
      }
      commands.add('end');

      if (gatewaysToAdd.isEmpty && gatewaysToRemove.isEmpty) {
        _logDebug('No changes to apply for ECMP config via Telnet.');
        return 'No ECMP configuration changes were needed.';
      }
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

  @override
  Future<String> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrSubmission submission,
  }) async {
    _logDebug('Applying PBR rule with Telnet: ${submission.routeMap.name}');
    try {
      final List<String> commands = ['configure terminal'];

      if (submission.newAcl != null) {
        commands.add('no access-list ${submission.newAcl!.id}');
        for (final entry in submission.newAcl!.entries) {
          commands.add(_buildAclEntryCommand(submission.newAcl!.id, entry));
        }
      }

      commands.add('no route-map ${submission.routeMap.name}');
      for (final entry in submission.routeMap.entries) {
        commands.add('route-map ${submission.routeMap.name} ${entry.permission} ${entry.sequence}');
        if (entry.matchAclId != null) {
          commands.add('match ip address ${entry.matchAclId}');
        }
        if (entry.action != null) {
          if (entry.action is SetNextHopAction) {
            final nextHops = (entry.action as SetNextHopAction).nextHops.join(' ');
            commands.add('set ip next-hop $nextHops');
          } else if (entry.action is SetInterfaceAction) {
            final interfaces = (entry.action as SetInterfaceAction).interfaces.join(' ');
            commands.add('set interface $interfaces');
          }
        }
      }
      commands.add('exit');

      if (submission.routeMap.appliedToInterface != null) {
        commands.add('interface ${submission.routeMap.appliedToInterface}');
        commands.add('ip policy route-map ${submission.routeMap.name}');
      }
      
      commands.add('end');

      final result = await _executeTelnetCommands(credentials, commands);
      _logDebug('PBR config commands executed via Telnet');
      if (result.toLowerCase().contains('invalid input') || result.toLowerCase().contains('error')) {
        return 'Failed to apply PBR configuration. Router response: ${result.split('\n').lastWhere((line) => line.contains('%') || line.contains('^'), orElse: () => 'Unknown error')}';
      }

      return 'PBR rule "${submission.routeMap.name}" applied successfully.';
    } catch (e) {
      return 'An error occurred while applying PBR rule: ${e.toString()}';
    }
  }

  // --- Private Helper Methods ---

  String _formatAclAddress(String address) {
    final trimmedAddress = address.trim();
    if (trimmedAddress.toLowerCase() == 'any') {
      return 'any';
    }
    if (trimmedAddress.contains(' ')) {
      return trimmedAddress;
    }
    return 'host $trimmedAddress';
  }
  
  String _buildAclEntryCommand(String aclId, AclEntry entry) {
    final source = _formatAclAddress(entry.source);
    final destination = _formatAclAddress(entry.destination);
    return 'access-list $aclId ${entry.permission} ${entry.protocol} $source $destination ${entry.portCondition ?? ''}'.trim();
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

  Future<String> _executeTelnetCommands(
      LBDeviceCredentials credentials, List<String> commands) async {
    _logDebug('Starting execution of Telnet commands');
    final completer = Completer<String>();
    final outputBuffer = StringBuffer();
    CTelnetClient? client;
    StreamSubscription<Message>? subscription;

    var state = 'login';
    int commandIndex = 0;
    final allCommands = ['terminal length 0', ...commands];
    Timer? timeoutTimer;
    
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
}