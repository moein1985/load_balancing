// lib/data/datasources/ssh_client_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';

class SshClientHandler {
  static const _commandTimeout = Duration(seconds: 30);
  static const _connectionTimeout = Duration(seconds: 10);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[SSH] $message');
    }
  }

  Future<SSHClient> _createSshClient(LBDeviceCredentials credentials) async {
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

  Future<List<String>> _executeCommandsAndGetOutputs(
    LBDeviceCredentials credentials,
    SSHClient client,
    List<String> commands,
  ) async {
    _logDebug('Executing multi-command shell for: ${commands.join(", ")}');
    final shell = await client.shell(
      pty: SSHPtyConfig(width: 120, height: 200),
    );

    final completer = Completer<List<String>>();
    final outputs = <String>[];
    var currentOutput = StringBuffer();
    int commandIndex = 0;
    var sessionState = 'connecting';
    final enablePassword = credentials.enablePassword;

    bool isPrompt(String text) {
      return RegExp(r'[>#]\s*$').hasMatch(text);
    }

    void processAndAddOutput() {
      String outputStr = currentOutput.toString();
      if (commandIndex > 0) {
        final sentCommand = commands[commandIndex - 1];
        if (outputStr.trim().startsWith(sentCommand)) {
          outputStr = outputStr.replaceFirst(sentCommand, '').trim();
        }
      }
      final promptIndex = outputStr.lastIndexOf(RegExp(r'\r\n.*[>#]\s*$'));
      if (promptIndex != -1) {
        outputStr = outputStr.substring(0, promptIndex).trim();
      }
      outputs.add(outputStr);
      currentOutput.clear();
    }

    void sendNextCommand() {
      if (commandIndex < commands.length) {
        final command = commands[commandIndex];
        _logDebug('Sending Shell Command: $command');
        shell.stdin.add(utf8.encode('$command\n'));
        commandIndex++;
      } else {
        if (!completer.isCompleted) {
          shell.close();
          completer.complete(outputs);
        }
      }
    }

    final subscription =
        shell.stdout.cast<List<int>>().transform(utf8.decoder).listen(
      (data) {
        _logDebug('RAW SSH: "$data"');
        currentOutput.write(data);
        final receivedText = currentOutput.toString().trim();

        switch (sessionState) {
          case 'connecting':
            if (isPrompt(receivedText)) {
              if (receivedText.endsWith('>')) {
                _logDebug('User prompt detected. Sending enable.');
                sessionState = 'enabling';
                currentOutput.clear();
                shell.stdin.add(utf8.encode('enable\n'));
              } else if (receivedText.endsWith('#')) {
                _logDebug('Privileged prompt detected. Starting commands.');
                sessionState = 'executing';
                currentOutput.clear();
                sendNextCommand();
              }
            }
            break;
          case 'enabling':
            if (RegExp(r'password[:]?\s*$', caseSensitive: false)
                .hasMatch(receivedText)) {
              _logDebug('Enable password prompt detected.');
              sessionState = 'sending_enable_password';
              currentOutput.clear();
              shell.stdin.add(utf8.encode('${enablePassword ?? ''}\n'));
            } else if (isPrompt(receivedText) && receivedText.endsWith('#')) {
              _logDebug('Enabled successfully (no password). Starting commands.');
              sessionState = 'executing';
              currentOutput.clear();
              sendNextCommand();
            }
            break;
          case 'sending_enable_password':
            if (isPrompt(receivedText) && receivedText.endsWith('#')) {
              _logDebug('Enabled with password. Starting commands.');
              sessionState = 'executing';
              currentOutput.clear();
              sendNextCommand();
            } else if (isPrompt(receivedText) && receivedText.endsWith('>')) {
              if (!completer.isCompleted) {
                completer.completeError(
                    const ServerFailure('Enable failed. Check password.'));
                shell.close();
              }
            }
            break;
          case 'executing':
            if (isPrompt(receivedText)) {
              processAndAddOutput();
              sendNextCommand();
            }
            break;
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          if (currentOutput.isNotEmpty) {
            processAndAddOutput();
          }
          completer.complete(outputs);
        }
      },
    );

    return completer.future.timeout(_commandTimeout);
  }

  Future<Map<String, String>> fetchInterfaceDataBundle(
    LBDeviceCredentials credentials,
  ) async {
    _logDebug('Fetching SSH interface data bundle in a single session');
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      
      final commandsToRun = [
        'terminal length 0',
        'show ip interface brief',
        'show running-config',
      ];
      
      final results = await _executeCommandsAndGetOutputs(credentials, client, commandsToRun);

      if (results.length < 3) {
        throw const ServerFailure('Failed to execute all commands for interface data.');
      }

      final briefResult = results[1];
      final detailedResult = results[2];

      _logDebug('SSH bundle fetched successfully');
      return {'brief': briefResult, 'detailed': detailedResult};
    } catch (e) {
      _logDebug('Error fetching SSH data bundle: $e');
      rethrow;
    } finally {
      client?.close();
      _logDebug('SSH bundle session closed');
    }
  }
  
  Future<String> getRoutingTable(LBDeviceCredentials credentials) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      final results = await _executeCommandsAndGetOutputs(credentials, client, [
        'terminal length 0',
        'show ip route',
      ]);
      return results.last;
    } catch (e) {
      _logDebug('Error fetching SSH routing table: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  Future<String> pingGateway(
    LBDeviceCredentials credentials,
    String ipAddress,
  ) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      final results = await _executeCommandsAndGetOutputs(
        credentials,
        client,
        ['ping $ipAddress repeat 5'],
      );
      final result = results.isNotEmpty ? results.first : '';
      return _analyzePingResult(result);
    } finally {
      client?.close();
    }
  }

  String _analyzePingResult(String output) {
    if (output.contains('!!!!!') ||
        output.contains('Success rate is 100') ||
        output.contains('Success rate is 80')) {
      return 'Success! Gateway is reachable.';
    } else if (output.contains('.....') ||
        output.contains('Success rate is 0')) {
      return 'Timeout. Gateway is not reachable.';
    }
    return 'Ping failed. Check the IP or connection.';
  }

  Future<String> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      final List<String> commands = ['configure terminal'];
      for (final g in gatewaysToRemove) {
        if (g.trim().isNotEmpty) commands.add('no ip route 0.0.0.0 0.0.0.0 $g');
      }
      for (final g in gatewaysToAdd) {
        if (g.trim().isNotEmpty) commands.add('ip route 0.0.0.0 0.0.0.0 $g');
      }
      commands.add('end');

      if (gatewaysToAdd.isEmpty && gatewaysToRemove.isEmpty) {
        return 'No ECMP configuration changes were needed.';
      }
      
      final results = await _executeCommandsAndGetOutputs(credentials, client, commands);
      final result = results.join('\n');

      if (result.toLowerCase().contains('invalid input') ||
          result.toLowerCase().contains('error')) {
        return 'Failed to apply ECMP configuration. Router response: $result';
      }
      return 'ECMP configuration applied successfully.';
    } catch (e) {
      return 'An error occurred while applying ECMP configuration: ${e.toString()}';
    } finally {
      client?.close();
    }
  }

  /// **متد اصلاح شده نهایی در این فایل**
  /// Helper function to build the correct ACL command string.
  String _buildAclCommand(PbrRule rule) {
    // Translates 'any' protocol to 'ip' for Cisco IOS.
    final protocol = rule.protocol.toLowerCase() == 'any' ? 'ip' : rule.protocol;
    
    // Handles source address (host, any, or subnet).
    String source = 'any';
    if (rule.sourceAddress.toLowerCase() != 'any') {
      // Uses the 'host' keyword for single IPs for cleaner syntax.
      // A more advanced version could convert CIDR to wildcard masks.
      source = 'host ${rule.sourceAddress}';
    }

    // Handles destination address.
    String destination = 'any';
    if (rule.destinationAddress.toLowerCase() != 'any') {
      destination = 'host ${rule.destinationAddress}';
    }

    // Appends port information only if protocol is TCP/UDP and port is not 'any'.
    String port = '';
    if ((protocol == 'tcp' || protocol == 'udp') && rule.destinationPort.toLowerCase() != 'any') {
      port = ' eq ${rule.destinationPort}';
    }
    
    return 'access-list 101 permit $protocol $source $destination$port';
  }

  Future<String> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrRule rule,
  }) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      final List<String> commands = ['configure terminal'];
      
      // *** تغییر اصلی: استفاده از متد کمکی برای ساخت دستور صحیح ***
      final aclCommand = _buildAclCommand(rule);
      commands.add(aclCommand);

      commands.add('route-map ${rule.ruleName} permit 10');
      commands.add('match ip address 101');
      if (rule.actionType == PbrActionType.nextHop) {
        commands.add('set ip next-hop ${rule.nextHop}');
      } else {
        commands.add('set interface ${rule.egressInterface}');
      }
      commands.add('exit');
      commands.add('interface ${rule.applyToInterface}');
      commands.add('ip policy route-map ${rule.ruleName}');
      commands.add('end');

      final results = await _executeCommandsAndGetOutputs(credentials, client, commands);
      final result = results.join('\n');

      if (result.toLowerCase().contains('invalid input') || result.toLowerCase().contains('error')) {
        return 'Failed to apply PBR configuration. Router response: $result';
      }
      return 'PBR rule "${rule.ruleName}" applied successfully.';
    } catch (e) {
      return 'An error occurred while applying PBR rule: ${e.toString()}';
    } finally {
      client?.close();
    }
  }
}