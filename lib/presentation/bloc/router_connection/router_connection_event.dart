// lib/presentation/bloc/router_connection/router_connection_event.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/presentation/screens/connection/router_connection_screen.dart';

abstract class RouterConnectionEvent extends Equatable {
  const RouterConnectionEvent();
  @override
  List<Object?> get props => [];
}

class CheckCredentialsRequested extends RouterConnectionEvent {
  final String ip;
  final String port; // **NEW: Port added**
  final String username;
  final String password;
  final String? enablePassword;
  final ConnectionType type;

  const CheckCredentialsRequested({
    required this.ip,
    required this.port, // **NEW: Added to constructor**
    required this.username,
    required this.password,
    this.enablePassword,
    required this.type,
  });

  @override
  List<Object?> get props => [
    ip,
    port,
    username,
    password,
    enablePassword,
    type,
  ]; // **NEW: Added to props**
}
