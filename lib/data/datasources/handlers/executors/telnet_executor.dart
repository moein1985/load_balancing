// lib/data/datasources/handlers/executors/telnet_executor.dart
import 'dart:async';
import 'package:ctelnet/ctelnet.dart';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';

class TelnetExecutor {
  static const _commandTimeout = Duration(seconds: 30);
  static const _connectionTimeout = Duration(seconds: 20);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[Telnet Executor] $message');
    }
  }

  Future<String> execute(
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
  
  Future<String> executePing(
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
          completer.complete(output);
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

        if (receivedText.contains('!!!!!') || receivedText.contains('Success rate is')) {
          if (!completer.isCompleted) {
            timeoutTimer?.cancel();
            completer.complete(outputBuffer.toString());
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