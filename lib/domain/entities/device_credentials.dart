// domain/entities/device_credentials.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/presentation/screens/connection/connection_screen.dart';

class DeviceCredentials extends Equatable {
  final String ip;
  final String username;
  final String password;
  final String? enablePassword;
  final ConnectionType type;

  const DeviceCredentials({
    required this.ip,
    required this.username,
    required this.password,
    this.enablePassword,
    required this.type,
  });

  @override
  List<Object?> get props => [ip, username, password, enablePassword, type];
}
