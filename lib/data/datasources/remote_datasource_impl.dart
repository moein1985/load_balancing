// lib/data/datasources/remote_datasource_impl.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/presentation/screens/connection/router_connection_screen.dart';
import 'package:load_balance/data/datasources/ssh_client_handler.dart';
import 'package:load_balance/data/datasources/telnet_client_handler.dart';
import 'remote_datasource.dart';

class RemoteDataSourceImpl implements RemoteDataSource {
  final SshClientHandler _sshHandler = SshClientHandler();
  final TelnetClientHandler _telnetHandler = TelnetClientHandler();

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[REMOTE_DS] $message');
    }
  }

  @override
  Future<List<RouterInterface>> fetchInterfaces(
    LBDeviceCredentials credentials,
  ) async {
    _logDebug('Fetching interface list - ${credentials.type}');
    String briefResult;
    String detailedResult;

    if (credentials.type == ConnectionType.ssh) {
      // *** راه حل نهایی: استفاده از یک جلسه SSH یکپارچه ***
      // ما از متد جدیدی در ssh_handler استفاده می‌کنیم که هر دو دستور را
      // در یک اتصال اجرا کرده و نتیجه را به صورت Map برمی‌گرداند.
      final sshResults = await _sshHandler.fetchInterfaceDataBundle(credentials);
      briefResult = sshResults['brief'] ?? '';
      detailedResult = sshResults['detailed'] ?? '';
    } else {
      briefResult = await _telnetHandler.fetchInterfaces(credentials);
      detailedResult = await _telnetHandler.fetchDetailedInterfaces(credentials);
    }

    return _parseDetailedInterfaces(briefResult, detailedResult);
  }

  List<RouterInterface> _parseDetailedInterfaces(
    String briefResult,
    String detailedResult,
  ) {
    final interfaces = <RouterInterface>[];
    final briefLines = briefResult.split('\n');
    final briefRegex = RegExp(
      r'^(\S+)\s+([\d\.]+|unassigned)\s+\w+\s+\w+\s+(up|down|administratively down)',
    );
    final mainInterfaces = <Map<String, String>>[];
    for (final line in briefLines) {
      final match = briefRegex.firstMatch(line);
      if (match != null && match.group(2) != 'unassigned') {
        final interfaceName = match.group(1)!;
        if (!interfaceName.startsWith('NVI')) {
          mainInterfaces.add({
            'name': interfaceName,
            'primaryIp': match.group(2)!,
            'status': match.group(3)!,
          });
        }
      }
    }

    final secondaryIps = _extractSecondaryIps(detailedResult);
    for (final interface in mainInterfaces) {
      final interfaceName = interface['name']!;
      final primaryIp = interface['primaryIp']!;
      final status = interface['status']!;

      interfaces.add(
        RouterInterface(
          name: interfaceName,
          ipAddress: primaryIp,
          status: status,
        ),
      );
      final secondaries = secondaryIps[interfaceName] ?? [];
      for (final secondaryIp in secondaries) {
        interfaces.add(
          RouterInterface(
            name: '$interfaceName (Secondary)',
            ipAddress: secondaryIp,
            status: status,
          ),
        );
      }
    }

    _logDebug('${interfaces.length} interfaces processed');
    return interfaces;
  }

  Map<String, List<String>> _extractSecondaryIps(String configOutput) {
    final secondaryIps = <String, List<String>>{};
    final lines = configOutput.split('\n');
    String? currentInterface;

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.startsWith('interface ')) {
        currentInterface = trimmedLine.substring('interface '.length);
        if (currentInterface.isNotEmpty) {
          secondaryIps[currentInterface] = [];
        }
        continue;
      }
      if (trimmedLine == '!') {
        currentInterface = null;
        continue;
      }
      if (currentInterface != null &&
          trimmedLine.startsWith('ip address') &&
          trimmedLine.contains('secondary')) {
        final parts = trimmedLine.split(' ');
        if (parts.length >= 4) {
          final ipAddress = parts[2];
          if (_isValidIpAddress(ipAddress)) {
            secondaryIps[currentInterface]?.add(ipAddress);
          }
        }
      }
    }
    secondaryIps.removeWhere((key, value) => value.isEmpty);
    _logDebug('Found secondary IPs: $secondaryIps');
    return secondaryIps;
  }

  @override
  Future<String> getRoutingTable(LBDeviceCredentials credentials) async {
    _logDebug('Fetching routing table - ${credentials.type}');
    String rawResult;
    if (credentials.type == ConnectionType.ssh) {
      rawResult = await _sshHandler.getRoutingTable(credentials);
    } else {
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
      if (trimmedLine.startsWith('Codes:') ||
          trimmedLine.startsWith('Gateway of last resort')) {
        routeStarted = true;
      }
      if (routeStarted &&
          (trimmedLine.endsWith('#') || trimmedLine.endsWith('>'))) {
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
    LBDeviceCredentials credentials,
    String ipAddress,
  ) async {
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
  Future<String> applyEcmpConfig({
    required LBDeviceCredentials credentials,
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
      } else {
        return await _telnetHandler.applyEcmpConfig(
          credentials: credentials,
          gatewaysToAdd: gatewaysToAdd,
          gatewaysToRemove: gatewaysToRemove,
        );
      }
    } on ServerFailure catch (e) {
      _logDebug('ServerFailure applying ECMP config: ${e.message}');
      return e.message;
    } catch (e) {
      _logDebug('Unknown error applying ECMP config: ${e.toString()}');
      return 'An unknown error occurred: ${e.toString()}';
    }
  }

  @override
  Future<String> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrRule rule,
  }) async {
    _logDebug('Applying PBR rule: ${rule.ruleName}');
    try {
      if (credentials.type == ConnectionType.ssh) {
        return await _sshHandler.applyPbrRule(
          credentials: credentials,
          rule: rule,
        );
      } else {
        return await _telnetHandler.applyPbrRule(
          credentials: credentials,
          rule: rule,
        );
      }
    } on ServerFailure catch (e) {
      return e.message;
    } catch (e) {
      return 'An unknown error occurred: ${e.toString()}';
    }
  }
}