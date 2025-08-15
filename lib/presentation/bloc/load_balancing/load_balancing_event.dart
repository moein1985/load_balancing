// lib/presentation/bloc/load_balancing/load_balancing_event.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';

import '../../../domain/entities/route_map.dart';

abstract class LoadBalancingEvent extends Equatable {
  const LoadBalancingEvent();
  @override
  List<Object?> get props => [];
}

class ScreenStarted extends LoadBalancingEvent {
  final LBDeviceCredentials credentials;
  final List<RouterInterface> interfaces;

  const ScreenStarted(this.credentials, this.interfaces);
  @override
  List<Object?> get props => [credentials, interfaces];
}

class LoadBalancingTypeSelected extends LoadBalancingEvent {
  final LoadBalancingType type;
  const LoadBalancingTypeSelected(this.type);
  @override
  List<Object> get props => [type];
}

class FetchInterfacesRequested extends LoadBalancingEvent {}

class FetchRoutingTableRequested extends LoadBalancingEvent {}

/// **رویداد جدید برای درخواست اطلاعات PBR**
class FetchPbrConfigurationRequested extends LoadBalancingEvent {}

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

class DeletePbrRuleRequested extends LoadBalancingEvent {
  final RouteMap ruleToDelete;
  const DeletePbrRuleRequested(this.ruleToDelete);
  @override
  List<Object> get props => [ruleToDelete];
}

// Event for optimistic UI update after a rule is created/edited.
class PbrRuleUpserted extends LoadBalancingEvent {
  final RouteMap rule;
  const PbrRuleUpserted(this.rule);
  @override
  List<Object> get props => [rule];
}