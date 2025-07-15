// presentation/bloc/connection/connection_event.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/presentation/screens/connection/connection_screen.dart';

abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();

  @override
  List<Object?> get props => [];
}

class CheckCredentialsRequested extends ConnectionEvent {
  final String ip;
  final String username;
  final String password;
  final String? enablePassword;
  final ConnectionType type;

  const CheckCredentialsRequested({
    required this.ip,
    required this.username,
    required this.password,
    this.enablePassword,
    required this.type,
  });

  @override
  List<Object?> get props => [ip, username, password, enablePassword, type];
}
