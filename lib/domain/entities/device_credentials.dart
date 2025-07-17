// lib/domain/entities/device_credentials.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/presentation/screens/connection/connection_screen.dart';

class DeviceCredentials extends Equatable {
  final String ip;
  final String username;
  final String password;
  final String? enablePassword;
  final ConnectionType type;
  final Duration connectionTimeout;
  final Duration commandTimeout;

  const DeviceCredentials({
    required this.ip,
    required this.username,
    required this.password,
    this.enablePassword,
    required this.type,
    this.connectionTimeout = const Duration(seconds: 10),
    this.commandTimeout = const Duration(seconds: 20),
  });

  // Data validation
  bool get isValid {
    if (ip.trim().isEmpty || username.trim().isEmpty || password.trim().isEmpty) {
      return false;
    }
    
    // IP format check
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip.trim())) {
      return false;
    }
    
    // IP range check
    final parts = ip.trim().split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return false;
      }
    }
    
    return true;
  }

  String? get validationError {
    if (ip.trim().isEmpty) return 'IP address cannot be empty';
    if (username.trim().isEmpty) return 'Username cannot be empty';
    if (password.trim().isEmpty) return 'Password cannot be empty';
    
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip.trim())) {
      return 'Invalid IP address format';
    }
    
    final parts = ip.trim().split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return 'IP address octets must be between 0-255';
      }
    }
    
    return null;
  }

  DeviceCredentials copyWith({
    String? ip,
    String? username,
    String? password,
    String? enablePassword,
    ConnectionType? type,
    Duration? connectionTimeout,
    Duration? commandTimeout,
  }) {
    return DeviceCredentials(
      ip: ip ?? this.ip,
      username: username ?? this.username,
      password: password ?? this.password,
      enablePassword: enablePassword ?? this.enablePassword,
      type: type ?? this.type,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      commandTimeout: commandTimeout ?? this.commandTimeout,
    );
  }

  @override
  List<Object?> get props => [
        ip,
        username,
        password,
        enablePassword,
        type,
        connectionTimeout,
        commandTimeout,
      ];
      
  @override
  String toString() {
    return 'DeviceCredentials(ip: $ip, username: $username, type: $type)';
  }
}