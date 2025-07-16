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

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[REMOTE_DS] $message');
    }
  }

  @override
  Future<List<RouterInterface>> fetchInterfaces(
      DeviceCredentials credentials) async {
    _logDebug('دریافت لیست Interface ها - ${credentials.type}');
    
    String briefResult;
    String detailedResult;
    
    if (credentials.type == ConnectionType.ssh) {
      briefResult = await _sshHandler.fetchInterfaces(credentials);
      detailedResult = await _sshHandler.fetchDetailedInterfaces(credentials);
    } else {
      briefResult = await _telnetHandler.fetchInterfaces(credentials);
      detailedResult = await _telnetHandler.fetchDetailedInterfaces(credentials);
    }

    return _parseDetailedInterfaces(briefResult, detailedResult);
  }

  List<RouterInterface> _parseDetailedInterfaces(String briefResult, String detailedResult) {
    final interfaces = <RouterInterface>[];
    final briefLines = briefResult.split('\n');
    final briefRegex = RegExp(
        r'^(\S+)\s+([\d\.]+|unassigned)\s+\w+\s+\w+\s+(up|down|administratively down)');

    // ابتدا اینترفیس‌های اصلی را از brief پیدا کنیم
    final mainInterfaces = <Map<String, String>>[];
    for (final line in briefLines) {
      final match = briefRegex.firstMatch(line);
      if (match != null && match.group(2) != 'unassigned') {
        final interfaceName = match.group(1)!;
        // NVI0 را نادیده بگیر چون مجازی است
        if (!interfaceName.startsWith('NVI')) {
          mainInterfaces.add({
            'name': interfaceName,
            'primaryIp': match.group(2)!,
            'status': match.group(3)!,
          });
        }
      }
    }

    // سپس آدرس‌های ثانویه را از detailed config پیدا کنیم
    final secondaryIps = _extractSecondaryIps(detailedResult);

    // اینترفیس‌ها را بسازیم
    for (final interface in mainInterfaces) {
      final interfaceName = interface['name']!;
      final primaryIp = interface['primaryIp']!;
      final status = interface['status']!;
      
      // آدرس اصلی را اضافه کن
      interfaces.add(RouterInterface(
        name: interfaceName,
        ipAddress: primaryIp,
        status: status,
      ));
      
      // آدرس‌های ثانویه را اضافه کن
      final secondaries = secondaryIps[interfaceName] ?? [];
      for (final secondaryIp in secondaries) {
        interfaces.add(RouterInterface(
          name: '$interfaceName (Secondary)',
          ipAddress: secondaryIp,
          status: status,
        ));
      }
    }
    
    _logDebug('${interfaces.length} Interface پردازش شد');
    return interfaces;
  }

  Map<String, List<String>> _extractSecondaryIps(String configOutput) {
    final secondaryIps = <String, List<String>>{};
    final lines = configOutput.split('\n');
    String? currentInterface;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      // پیدا کردن شروع تنظیمات اینترفیس
      if (trimmedLine.startsWith('interface ')) {
        currentInterface = trimmedLine.split(' ')[1];
        secondaryIps[currentInterface] = [];
      }
      
      // پیدا کردن آدرس‌های IP ثانویه
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
    _logDebug('دریافت جدول مسیریابی - ${credentials.type}');

    String rawResult;
    
    if (credentials.type == ConnectionType.ssh) {
      rawResult = await _sshHandler.getRoutingTable(credentials);
    } else {
      rawResult = await _telnetHandler.getRoutingTable(credentials);
    }

    return _cleanRoutingTableOutput(rawResult);
  }

  String _cleanRoutingTableOutput(String rawResult) {
    _logDebug('تمیز کردن خروجی جدول مسیریابی، طول ورودی: ${rawResult.length}');

    final lines = rawResult.split('\n');
    final cleanLines = <String>[];
    bool routeStarted = false;

    for (final line in lines) {
      final trimmedLine = line.trim();
      
      // شروع جدول مسیریابی
      if (trimmedLine.startsWith('Codes:') ||
          trimmedLine.startsWith('Gateway of last resort')) {
        routeStarted = true;
      }

      // پایان جدول مسیریابی
      if (routeStarted && (trimmedLine.endsWith('#') || trimmedLine.endsWith('>'))) {
        break;
      }

      if (routeStarted && trimmedLine.isNotEmpty) {
        cleanLines.add(line);
      }
    }

    final result = cleanLines.join('\n').trim();
    _logDebug('جدول مسیریابی تمیز شد، طول: ${result.length}');
    return result;
  }

  @override
  Future<String> pingGateway(
      DeviceCredentials credentials, String ipAddress) async {
    _logDebug('شروع ping برای IP: $ipAddress - ${credentials.type}');

    if (ipAddress.trim().isEmpty) {
      return 'خطا: آدرس IP نمی‌تواند خالی باشد.';
    }

    if (!_isValidIpAddress(ipAddress.trim())) {
      return 'خطا: فرمت آدرس IP نامعتبر است.';
    }

    final cleanIp = ipAddress.trim();

    try {
      if (credentials.type == ConnectionType.ssh) {
        return await _sshHandler.pingGateway(credentials, cleanIp);
      } else {
        return await _telnetHandler.pingGateway(credentials, cleanIp);
      }
    } catch (e) {
      _logDebug('خطا در ping: $e');
      if (e is ServerFailure) {
        return 'خطا: ${e.message}';
      }
      return 'خطا در ping: ${e.toString()}';
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
    _logDebug('بررسی اعتبار REST API');
    return await _restApiHandler.checkCredentials(credentials);
  }
}
