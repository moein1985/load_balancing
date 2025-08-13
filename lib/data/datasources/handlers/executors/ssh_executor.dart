// lib/data/datasources/handlers/executors/ssh_executor.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';

class SshExecutor {
  static const _commandTimeout = Duration(seconds: 30);
  static const _connectionTimeout = Duration(seconds: 10);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[SSH Executor] $message');
    }
  }

  Future<SSHClient> createSshClient(LBDeviceCredentials credentials) async {
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

  Future<List<String>> execute(
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
}