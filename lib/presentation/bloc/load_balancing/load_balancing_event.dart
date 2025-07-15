// presentation/bloc/load_balancing/load_balancing_event.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';

abstract class LoadBalancingEvent extends Equatable {
  const LoadBalancingEvent();
  @override
  List<Object?> get props => [];
}

// Event to initialize the screen and establish the persistent SSH connection
class ScreenStarted extends LoadBalancingEvent {
  final DeviceCredentials credentials;
  const ScreenStarted(this.credentials);
  @override
  List<Object?> get props => [credentials];
}

// Event to close the connection when the screen is disposed
class DisconnectRequested extends LoadBalancingEvent {}

class LoadBalancingTypeSelected extends LoadBalancingEvent {
  final LoadBalancingType type;
  const LoadBalancingTypeSelected(this.type);
  @override
  List<Object> get props => [type];
}

class FetchInterfacesRequested extends LoadBalancingEvent {}

class FetchRoutingTableRequested extends LoadBalancingEvent {}

class PingGatewayRequested extends LoadBalancingEvent {
  final String ipAddress;
  const PingGatewayRequested(this.ipAddress);
  @override
  List<Object?> get props => [ipAddress];
}