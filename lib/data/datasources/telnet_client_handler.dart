// lib/data/datasources/telnet_client_handler.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:ctelnet/ctelnet.dart';

class TelnetClientHandler {
  static const _commandTimeout = Duration(seconds: 30); // افزایش timeout
  static const _connectionTimeout = Duration(seconds: 20);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[TELNET] $message');
    }
  }

  Future<String> _executeTelnetCommands(
      DeviceCredentials credentials, List<String> commands) async {
    _logDebug('شروع اجرای دستورات Telnet');

    final completer = Completer<String>();
    final outputBuffer = StringBuffer();
    CTelnetClient? client;
    StreamSubscription<Message>? subscription;

    var state = 'login';
    int commandIndex = 0;
    final allCommands = ['terminal length 0', ...commands];
    Timer? timeoutTimer;

    // تنظیم timeout timer
    timeoutTimer = Timer(_commandTimeout, () {
      _logDebug('زمان عملیات Telnet به پایان رسید');
      if (!completer.isCompleted) {
        client?.disconnect();
        completer.completeError(const ServerFailure("زمان عملیات Telnet به پایان رسید."));
      }
    });

    client = CTelnetClient(
      host: credentials.ip,
      port: 23,
      timeout: _connectionTimeout,
      onConnect: () {
        _logDebug('اتصال Telnet برقرار شد');
      },
      onDisconnect: () {
        _logDebug('اتصال Telnet قطع شد');
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(outputBuffer.toString());
        }
        subscription?.cancel();
      },
      onError: (error) {
        _logDebug('خطای Telnet: $error');
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(ServerFailure("خطای Telnet: $error"));
        }
        subscription?.cancel();
      },
    );

    void executeNextCommand() {
      if (commandIndex < allCommands.length) {
        final cmd = allCommands[commandIndex];
        _logDebug("ارسال Telnet: $cmd");
        client?.send('$cmd\n');
        commandIndex++;
      } else {
        // تأخیر کوتاه قبل از قطع اتصال
        Timer(Duration(seconds: 1), () {
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
        _logDebug("دریافت Telnet: ${receivedText.replaceAll('\r\n', ' ')}");

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
              outputBuffer.clear(); // پاک کردن بافر قبل از شروع دستورات
              executeNextCommand();
            }
            break;
          case 'enable':
            if (receivedText.toLowerCase().contains('password')) {
              client?.send('${credentials.enablePassword ?? ''}\n');
            } else if (receivedText.endsWith('#')) {
              state = 'executing';
              outputBuffer.clear(); // پاک کردن بافر قبل از شروع دستورات
              executeNextCommand();
            }
            break;
          case 'executing':
            if (receivedText.endsWith('#')) {
              if (commandIndex < allCommands.length) {
                executeNextCommand();
              } else {
                // تأخیر کوتاه قبل از قطع اتصال
                Timer(Duration(seconds: 1), () {
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
      _logDebug('خطا در اتصال Telnet: $e');
      timeoutTimer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(ServerFailure("اتصال Telnet ناموفق: $e"));
      }
    }

    return completer.future;
  }

  Future<String> _executeTelnetPing(
      DeviceCredentials credentials, String ipAddress) async {
    _logDebug('شروع ping Telnet برای IP: $ipAddress');

    final completer = Completer<String>();
    CTelnetClient? client;
    StreamSubscription<Message>? subscription;
    var state = 'login';
    final outputBuffer = StringBuffer();
    bool commandSent = false;
    Timer? timeoutTimer;

    // تنظیم timeout timer
    timeoutTimer = Timer(_commandTimeout, () {
      _logDebug('زمان ping به پایان رسید');
      if (!completer.isCompleted) {
        client?.disconnect();
        completer.complete('زمان به پایان رسید. Gateway قابل دسترسی نیست.');
      }
    });

    client = CTelnetClient(
      host: credentials.ip,
      port: 23,
      timeout: _connectionTimeout,
      onConnect: () => _logDebug('اتصال ping Telnet برقرار شد'),
      onDisconnect: () {
        _logDebug('اتصال ping Telnet قطع شد');
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          final output = outputBuffer.toString();
          final result = _analyzePingResult(output);
          completer.complete(result);
        }
        subscription?.cancel();
      },
      onError: (error) {
        _logDebug('خطای ping Telnet: $error');
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(ServerFailure("خطای ping: $error"));
        }
      },
    );

    try {
      subscription = (await client.connect())?.listen((data) {
        final receivedText = data.text;
        outputBuffer.write(receivedText);
        _logDebug("دریافت ping: ${receivedText.replaceAll('\r\n', ' ')}");

        // بررسی نتایج ping در هر پیام دریافتی
        if (receivedText.contains('!!!!!') ||
            receivedText.contains('Success rate is 100') ||
            receivedText.contains('Success rate is 80')) {
          if (!completer.isCompleted) {
            timeoutTimer?.cancel();
            completer.complete('موفق! Gateway قابل دسترسی است.');
            client?.disconnect();
            return;
          }
        } else if (receivedText.contains('.....') ||
                   receivedText.contains('Success rate is 0')) {
          if (!completer.isCompleted) {
            timeoutTimer?.cancel();
            completer.complete('زمان به پایان رسید. Gateway قابل دسترسی نیست.');
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
      _logDebug('خطا در ping Telnet: $e');
      timeoutTimer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(ServerFailure("اتصال ping ناموفق: $e"));
      }
    }

    return completer.future;
  }

  Future<String> fetchDetailedInterfaces(DeviceCredentials credentials) async {
    try {
      final result = await _executeTelnetCommands(credentials, ['show running-config']);
      _logDebug('کانفیگ تفصیلی Telnet دریافت شد');
      return result;
    } catch (e) {
      _logDebug('خطا در دریافت کانفیگ تفصیلی Telnet: $e');
      rethrow;
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

  Future<String> fetchInterfaces(DeviceCredentials credentials) async {
    try {
      final result = await _executeTelnetCommands(
          credentials, ['show ip interface brief']);
      _logDebug('Interface های Telnet دریافت شدند');
      return result;
    } catch (e) {
      _logDebug('خطا در دریافت Interface های Telnet: $e');
      rethrow;
    }
  }

  Future<String> getRoutingTable(DeviceCredentials credentials) async {
    try {
      final result = await _executeTelnetCommands(credentials, ['show ip route']);
      _logDebug('جدول مسیریابی Telnet دریافت شد');
      return result;
    } catch (e) {
      _logDebug('خطا در دریافت جدول مسیریابی Telnet: $e');
      rethrow;
    }
  }

  Future<String> pingGateway(DeviceCredentials credentials, String ipAddress) async {
    return await _executeTelnetPing(credentials, ipAddress);
  }
}
