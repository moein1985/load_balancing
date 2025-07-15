// presentation/bloc/connection/connection_state.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';

abstract class ConnectionState extends Equatable {
  const ConnectionState();

  @override
  List<Object> get props => [];
}

class ConnectionInitial extends ConnectionState {}

class ConnectionLoading extends ConnectionState {}

// Now holds the credentials on success to pass them to the next screen
class ConnectionSuccess extends ConnectionState {
  final DeviceCredentials credentials;
  const ConnectionSuccess(this.credentials);

  @override
  List<Object> get props => [credentials];
}

class ConnectionFailure extends ConnectionState {
  final String error;

  const ConnectionFailure(this.error);

  @override
  List<Object> get props => [error];
}