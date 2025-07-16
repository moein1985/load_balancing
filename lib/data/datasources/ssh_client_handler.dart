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
    _logDebug('ایجاد اتصال SSH به ${credentials.ip}');
    
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
      
      _logDebug('اتصال SSH برقرار شد');
      return client;
    } on TimeoutException {
      _logDebug('خطا: زمان اتصال SSH به پایان رسید');
      throw const ServerFailure('زمان اتصال به پایان رسید. لطفا IP و پورت را بررسی کنید.');
    } on SocketException catch (e) {
      _logDebug('خطا: اتصال SSH ناموفق - ${e.message}');
      throw const ServerFailure('امکان اتصال به دستگاه وجود ندارد. IP و پورت را بررسی کنید.');
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('auth')) {
        _logDebug('خطا: احراز هویت SSH ناموفق');
        throw const ServerFailure('احراز هویت ناموفق. نام کاربری و رمز عبور را بررسی کنید.');
      }
      _logDebug('خطا: SSH - $e');
      throw ServerFailure('خطای SSH: ${e.toString()}');
    }
  }

  Future<String> _executeSshCommand(SSHClient client, String command) async {
    try {
      _logDebug('اجرای دستور SSH: $command');
      final result = await client.run(command).timeout(_commandTimeout);
      final output = utf8.decode(result);
      _logDebug('دستور SSH اجرا شد، طول خروجی: ${output.length}');
      return output;
    } catch (e) {
      _logDebug('خطا در اجرای دستور SSH: $e');
      rethrow;
    }
  }

  Future<String> _executeSshCommandsWithShell(SSHClient client, List<String> commands) async {
    _logDebug('شروع اجرای دستورات SSH با Shell');
    
    try {
      final shell = await client.shell(
        pty: SSHPtyConfig(
          width: 80,
          height: 24,
        ),
      );
      
      final completer = Completer<String>();
      final output = StringBuffer();
      bool isReady = false;
      int commandIndex = 0;
      
      void sendNextCommand() {
        if (commandIndex < commands.length) {
          final command = commands[commandIndex];
          _logDebug('ارسال دستور SSH Shell: $command');
          shell.stdin.add(utf8.encode('$command\n'));
          commandIndex++;
        }
      }
      
      shell.stdout.cast<List<int>>().transform(utf8.decoder).listen((data) {
        output.write(data);
        _logDebug('SSH Shell Output: ${data.replaceAll('\r\n', '\\n').replaceAll('\n', '\\n')}');
        
        if (!isReady && (data.contains('#') || data.contains('>'))) {
          isReady = true;
          sendNextCommand();
        } else if (isReady && (data.contains('#') || data.contains('>'))) {
          if (commandIndex < commands.length) {
            sendNextCommand();
          } else {
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
      
      Timer(_commandTimeout, () {
        if (!completer.isCompleted) {
          shell.close();
          completer.completeError(TimeoutException('SSH Shell timeout', _commandTimeout));
        }
      });
      
      return await completer.future;
    } catch (e) {
      _logDebug('خطا در SSH Shell: $e');
      rethrow;
    }
  }

  Future<String> fetchInterfaces(DeviceCredentials credentials) async {
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      final result = await _executeSshCommand(client, 'show ip interface brief');
      _logDebug('Interface های SSH دریافت شدند');
      return result;
    } catch (e) {
      _logDebug('خطا در دریافت Interface های SSH: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  Future<String> fetchDetailedInterfaces(DeviceCredentials credentials) async {
  SSHClient? client;
  try {
    client = await _createSshClient(credentials);
    final result = await _executeSshCommand(client, 'show running-config');
    _logDebug('کانفیگ تفصیلی SSH دریافت شد');
    return result;
  } catch (e) {
    _logDebug('خطا در دریافت کانفیگ تفصیلی SSH: $e');
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
        final result = await _executeSshCommandsWithShell(
            client, ['terminal length 0', 'show ip route']);
        _logDebug('جدول مسیریابی SSH با Shell دریافت شد');
        return result;
      } catch (e) {
        _logDebug('خطا در SSH Shell، تلاش با روش قدیمی: $e');
        await _executeSshCommand(client, 'terminal length 0');
        await Future.delayed(_delayBetweenCommands);
        final result = await _executeSshCommand(client, 'show ip route');
        _logDebug('جدول مسیریابی SSH با روش قدیمی دریافت شد');
        return result;
      }
    } catch (e) {
      _logDebug('خطا در دریافت جدول مسیریابی SSH: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  Future<String> pingGateway(DeviceCredentials credentials, String ipAddress) async {
    _logDebug('شروع ping SSH برای IP: $ipAddress');
    
    SSHClient? client;
    try {
      client = await _createSshClient(credentials);
      final result = await _executeSshCommand(client, 'ping $ipAddress repeat 5');
      
      _logDebug('نتیجه ping SSH دریافت شد');
      return _analyzePingResult(result);
    } finally {
      client?.close();
    }
  }

  String _analyzePingResult(String output) {
    _logDebug('تحلیل نتیجه ping');
    
    if (output.contains('!!!!!') || 
        output.contains('Success rate is 100') ||
        output.contains('Success rate is 80')) {
      return 'موفق! Gateway قابل دسترسی است.';
    } else if (output.contains('.....') || 
               output.contains('Success rate is 0')) {
      return 'زمان به پایان رسید. Gateway قابل دسترسی نیست.';
    } else if (output.toLowerCase().contains('unknown host')) {
      return 'خطا: Host نامعلوم است.';
    } else if (output.toLowerCase().contains('network unreachable')) {
      return 'خطا: شبکه قابل دسترسی نیست.';
    }
    
    return 'Ping ناموفق. IP یا اتصال را بررسی کنید.';
  }
}
