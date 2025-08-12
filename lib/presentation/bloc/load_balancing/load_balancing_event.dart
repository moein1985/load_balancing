// lib/presentation/bloc/load_balancing/load_balancing_event.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart'; // این import را اضافه کنید
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';

abstract class LoadBalancingEvent extends Equatable {
  const LoadBalancingEvent();
  @override
  List<Object?> get props => [];
}

// ***تغییر اصلی***
// این رویداد اکنون لیست اینترفیس‌ها را هم در زمان شروع صفحه دریافت می‌کند
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