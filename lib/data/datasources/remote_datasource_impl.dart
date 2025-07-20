// lib/data/datasources/remote_datasource_impl.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/presentation/screens/connection/connection_screen.dart';
import 'package:load_balance/data/datasources/ssh_client_handler.dart';
import 'package:load_balance/data/datasources/telnet_client_handler.dart';
import 'package:load_balance/data/datasources/restapi_client_handler.dart';
import 'remote_datasource.dart';

class RemoteDataSourceImpl implements RemoteDataSource {
  final SshClientHandler _sshHandler = SshClientHandler();
  final TelnetClientHandler _telnetHandler = TelnetClientHandler();
  final RestApiClientHandler _restApiHandler = RestApiClientHandler();

  // A short delay to prevent overwhelming the router with rapid connections.
  static const Duration _networkDelay = Duration(seconds: 2);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[REMOTE_DS] $message');
    }
  }

  @override
  Future<List<RouterInterface>> fetchInterfaces(
      DeviceCredentials credentials) async {
    _logDebug('Fetching interface list - ${credentials.type}');
    String briefResult;
    String detailedResult;

    if (credentials.type == ConnectionType.ssh) {
      briefResult = await _sshHandler.fetchInterfaces(credentials);
      detailedResult = await _sshHandler.fetchDetailedInterfaces(credentials);
    } else {
      // ADDED: Delay before Telnet operations
      await Future.delayed(_networkDelay);
      briefResult = await _telnetHandler.fetchInterfaces(credentials);
      
      await Future.delayed(_networkDelay);
      detailedResult = await _telnetHandler.fetchDetailedInterfaces(credentials);
    }

    return _parseDetailedInterfaces(briefResult, detailedResult);
  }

  List<RouterInterface> _parseDetailedInterfaces(String briefResult, String detailedResult) {
    final interfaces = <RouterInterface>[];
    final briefLines = briefResult.split('\n');
    final briefRegex = RegExp(
        r'^(\S+)\s+([\d\.]+|unassigned)\s+\w+\s+\w+\s+(up|down|administratively down)');
    // First, find the main interfaces from the brief output
    final mainInterfaces = <Map<String, String>>[];
    for (final line in briefLines) {
      final match = briefRegex.firstMatch(line);
      if (match != null && match.group(2) != 'unassigned') {
        final interfaceName = match.group(1)!;
        // Ignore NVI0 as it's a virtual interface
        if (!interfaceName.startsWith('NVI')) {
          mainInterfaces.add({
            'name': interfaceName,
            'primaryIp': match.group(2)!,
            'status': match.group(3)!,
          });
        }
      }
    }

    // Then, find secondary addresses from the detailed config
    final secondaryIps = _extractSecondaryIps(detailedResult);
    // Build the final interface list
    for (final interface in mainInterfaces) {
      final interfaceName = interface['name']!;
      final primaryIp = interface['primaryIp']!;
      final status = interface['status']!;

      // Add the primary address
      interfaces.add(RouterInterface(
        name: interfaceName,
        ipAddress: primaryIp,
        status: status,
      ));
      // Add any secondary addresses
      final secondaries = secondaryIps[interfaceName] ?? [];
      for (final secondaryIp in secondaries) {
        interfaces.add(RouterInterface(
          name: '$interfaceName (Secondary)',
          ipAddress: secondaryIp,
          status: status,
        ));
      }
    }

    _logDebug('${interfaces.length} interfaces processed');
    return interfaces;
  }

  Map<String, List<String>> _extractSecondaryIps(String configOutput) {
    final secondaryIps = <String, List<String>>{};
    final lines = configOutput.split('\n');
    String?
    currentInterface;

    for (final line in lines) {
      final trimmedLine = line.trim();
      // Find the start of an interface configuration
      if (trimmedLine.startsWith('interface ')) {
        currentInterface = trimmedLine.split(' ')[1];
        secondaryIps[currentInterface] = [];
      }

      // Find secondary IP addresses
      if (currentInterface != null && trimmedLine.contains('ip address') && trimmedLine.contains('secondary')) {
        final parts = trimmedLine.split(' ');
        if (parts.length >= 4) {
          final ipAddress = parts[2];
          if (_isValidIpAddress(ipAddress)) {
            secondaryIps[currentInterface]!.add(ipAddress);
          }
        }
      }
    }

    return secondaryIps;
  }

  @override
  Future<String> getRoutingTable(DeviceCredentials credentials) async {
    _logDebug('Fetching routing table - ${credentials.type}');

    String rawResult;
    if (credentials.type == ConnectionType.ssh) {
      rawResult = await _sshHandler.getRoutingTable(credentials);
    } else {
      // ADDED: Delay before Telnet operations
      await Future.delayed(_networkDelay);
      rawResult = await _telnetHandler.getRoutingTable(credentials);
    }

    return _cleanRoutingTableOutput(rawResult);
  }

  String _cleanRoutingTableOutput(String rawResult) {
    _logDebug('Cleaning routing table output, input length: ${rawResult.length}');
    final lines = rawResult.split('\n');
    final cleanLines = <String>[];
    bool routeStarted = false;
    for (final line in lines) {
      final trimmedLine = line.trim();
      // Start of the routing table
      if (trimmedLine.startsWith('Codes:') ||
          trimmedLine.startsWith('Gateway of last resort')) {
        routeStarted = true;
      }

      // End of the routing table (prompt)
      if (routeStarted && (trimmedLine.endsWith('#') || trimmedLine.endsWith('>'))) {
        break;
      }

      if (routeStarted && trimmedLine.isNotEmpty) {
        cleanLines.add(line);
      }
    }

    final result = cleanLines.join('\n').trim();
    _logDebug('Routing table cleaned, length: ${result.length}');
    return result;
  }

  @override
  Future<String> pingGateway(
      DeviceCredentials credentials, String ipAddress) async {
    _logDebug('Starting ping for IP: $ipAddress - ${credentials.type}');
    if (ipAddress.trim().isEmpty) {
      return 'Error: IP address cannot be empty.';
    }

    if (!_isValidIpAddress(ipAddress.trim())) {
      return 'Error: Invalid IP address format.';
    }

    final cleanIp = ipAddress.trim();

    try {
      if (credentials.type == ConnectionType.ssh) {
        return await _sshHandler.pingGateway(credentials, cleanIp);
      } else {
        // ADDED: Delay before Telnet operations
        await Future.delayed(_networkDelay);
        return await _telnetHandler.pingGateway(credentials, cleanIp);
      }
    } catch (e) {
      _logDebug('Error in ping: $e');
      if (e is ServerFailure) {
        return 'Error: ${e.message}';
      }
      return 'Error in ping: ${e.toString()}';
    }
  }

  bool _isValidIpAddress(String ip) {
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) return false;
    final parts = ip.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  @override
  Future<void> checkRestApiCredentials(DeviceCredentials credentials) async {
    _logDebug('Checking REST API credentials');
    return await _restApiHandler.checkCredentials(credentials);
  }

  @override
  Future<String> applyEcmpConfig({
    required DeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    _logDebug('Applying ECMP config - ${credentials.type}');
    try {
      if (credentials.type == ConnectionType.ssh) {
        return await _sshHandler.applyEcmpConfig(
          credentials: credentials,
          gatewaysToAdd: gatewaysToAdd,
          gatewaysToRemove: gatewaysToRemove,
        );
      } else if (credentials.type == ConnectionType.telnet) {
        // ADDED: Delay before Telnet operations
        await Future.delayed(_networkDelay);
        return await _telnetHandler.applyEcmpConfig(
          credentials: credentials,
          gatewaysToAdd: gatewaysToAdd,
          gatewaysToRemove: gatewaysToRemove,
        );
      } else {
        return 'Configuration via REST API is not yet supported.';
      }
    } on ServerFailure catch (e) {
      _logDebug('ServerFailure applying ECMP config: ${e.message}');
      return e.message;
    } catch (e) {
      _logDebug('Unknown error applying ECMP config: ${e.toString()}');
      return 'An unknown error occurred: ${e.toString()}';
    }
  }
}