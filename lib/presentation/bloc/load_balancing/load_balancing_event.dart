// lib/presentation/bloc/load_balancing/load_balancing_event.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
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

// *** MODIFIED ***
class FetchRoutingTableRequested extends LoadBalancingEvent {
  final LBDeviceCredentials credentials;
  const FetchRoutingTableRequested({required this.credentials});

  @override
  List<Object?> get props => [credentials];
}

// *** MODIFIED ***
class FetchPbrConfigurationRequested extends LoadBalancingEvent {
  final LBDeviceCredentials credentials;
  const FetchPbrConfigurationRequested({required this.credentials});

  @override
  List<Object?> get props => [credentials];
}


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

class DeletePbrRuleRequested extends LoadBalancingEvent {
  final RouteMap ruleToDelete;
  const DeletePbrRuleRequested(this.ruleToDelete);
  @override
  List<Object> get props => [ruleToDelete];
}

class PbrRuleUpserted extends LoadBalancingEvent {
  final RouteMap newRule;
  final AccessControlList? newAcl;
  final String? oldRuleName;

  const PbrRuleUpserted({required this.newRule, this.newAcl, this.oldRuleName});

  @override
  List<Object?> get props => [newRule, newAcl, oldRuleName];
}