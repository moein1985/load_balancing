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

  // اعتبارسنجی داده‌ها
  bool get isValid {
    if (ip.trim().isEmpty || username.trim().isEmpty || password.trim().isEmpty) {
      return false;
    }
    
    // بررسی فرمت IP
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip.trim())) {
      return false;
    }
    
    // بررسی محدوده IP
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
    if (ip.trim().isEmpty) return 'آدرس IP نمی‌تواند خالی باشد';
    if (username.trim().isEmpty) return 'نام کاربری نمی‌تواند خالی باشد';
    if (password.trim().isEmpty) return 'رمز عبور نمی‌تواند خالی باشد';
    
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip.trim())) {
      return 'فرمت آدرس IP نامعتبر است';
    }
    
    final parts = ip.trim().split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return 'آدرس IP باید در محدوده 0-255 باشد';
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
