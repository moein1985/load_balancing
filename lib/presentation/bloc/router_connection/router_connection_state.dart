// presentation/bloc/connection/connection_state.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';

abstract class RouterConnectionState extends Equatable {
  const RouterConnectionState();

  @override
  List<Object> get props => [];
}

class ConnectionInitial extends RouterConnectionState {}

class ConnectionLoading extends RouterConnectionState {}

// Now holds the credentials on success to pass them to the next screen
class ConnectionSuccess extends RouterConnectionState {
  final LBDeviceCredentials credentials;
  const ConnectionSuccess(this.credentials);

  @override
  List<Object> get props => [credentials];
}

class ConnectionFailure extends RouterConnectionState {
  final String error;

  const ConnectionFailure(this.error);

  @override
  List<Object> get props => [error];
}