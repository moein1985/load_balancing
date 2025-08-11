// presentation/bloc/connection/connection_event.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/presentation/screens/connection/router_connection_screen.dart';

abstract class RouterConnectionEvent extends Equatable {
  const RouterConnectionEvent();

  @override
  List<Object?> get props => [];
}

class CheckCredentialsRequested extends RouterConnectionEvent {
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
