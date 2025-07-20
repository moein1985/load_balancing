// lib/presentation/bloc/load_balancing/load_balancing_event.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';

abstract class LoadBalancingEvent extends Equatable {
  const LoadBalancingEvent();
  @override
  List<Object?> get props => [];
}

class ScreenStarted extends LoadBalancingEvent {
  final DeviceCredentials credentials;
  const ScreenStarted(this.credentials);
  @override
  List<Object?> get props => [credentials];
}

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

class ClearPingResult extends LoadBalancingEvent {
  final String ipAddress;
  const ClearPingResult(this.ipAddress);
  @override
  List<Object?> get props => [ipAddress];
}

class ApplyEcmpConfig extends LoadBalancingEvent {
  // Renamed for clarity: this is the final list of gateways from the UI.
  final List<String> finalGateways; 
  const ApplyEcmpConfig({required this.finalGateways});
  @override
  List<Object> get props => [finalGateways];
}

class ApplyPbrConfig extends LoadBalancingEvent {
  final String sourceNetwork;
  final String gateway;
  const ApplyPbrConfig({required this.sourceNetwork, required this.gateway});
  @override
  List<Object> get props => [sourceNetwork, gateway];
}