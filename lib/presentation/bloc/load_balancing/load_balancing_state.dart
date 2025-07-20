// lib/presentation/bloc/load_balancing/load_balancing_state.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

enum LoadBalancingType { ecmp, pbr }
enum DataStatus { initial, loading, success, failure }

class LoadBalancingState extends Equatable {
  // Holds the credentials to be used for each request
  final DeviceCredentials? credentials;
  final LoadBalancingType type;
  // General status for operations like applying configs
  final DataStatus status;
  final String error;
  // Specific message for successful operations
  final String? successMessage;

  final List<RouterInterface> interfaces;
  final DataStatus interfacesStatus;

  // This new property holds the list of ECMP gateways read from the router.
  final List<String> initialEcmpGateways;

  final String? routingTable;
  final DataStatus routingTableStatus;

  final Map<String, String> pingResults;
  final DataStatus pingStatus;
  final String? pingingIp;

  const LoadBalancingState({
    this.credentials,
    this.type = LoadBalancingType.ecmp,
    this.status = DataStatus.initial,
    this.error = '',
    this.successMessage,
    this.interfaces = const [],
    this.interfacesStatus = DataStatus.initial,
    this.initialEcmpGateways = const [], // Initialize as empty list
    this.routingTable,
    this.routingTableStatus = DataStatus.initial,
    this.pingResults = const {},
    this.pingStatus = DataStatus.initial,
    this.pingingIp,
  });

  LoadBalancingState copyWith({
    DeviceCredentials? credentials,
    LoadBalancingType? type,
    DataStatus? status,
    String? error,
    String? successMessage,
    bool clearSuccessMessage = false,
    List<RouterInterface>? interfaces,
    DataStatus? interfacesStatus,
    List<String>? initialEcmpGateways, // Add to copyWith
    String? routingTable,
    bool clearRoutingTable = false,
    DataStatus? routingTableStatus,
    Map<String, String>? pingResults,
    DataStatus? pingStatus,
    String? pingingIp,
  }) {
    return LoadBalancingState(
      credentials: credentials ?? this.credentials,
      type: type ?? this.type,
      status: status ?? this.status,
      // Clear error on new status, unless it's a failure status
      error: (status != null && status != DataStatus.failure) ? '' : error ?? this.error,
      // Handle clearing or setting the success message
      successMessage: clearSuccessMessage ? null : successMessage ?? this.successMessage,
      interfaces: interfaces ?? this.interfaces,
      interfacesStatus: interfacesStatus ?? this.interfacesStatus,
      initialEcmpGateways: initialEcmpGateways ?? this.initialEcmpGateways, // Add to copyWith
      routingTable: clearRoutingTable ? null : routingTable ?? this.routingTable,
      routingTableStatus: routingTableStatus ?? this.routingTableStatus,
      pingResults: pingResults ?? this.pingResults,
      pingStatus: pingStatus ?? this.pingStatus,
      pingingIp: pingingIp ?? this.pingingIp,
    );
  }

  @override
  List<Object?> get props => [
        credentials, type, status, error, successMessage, interfaces, interfacesStatus,
        initialEcmpGateways, // Add to props for Equatable
        routingTable, routingTableStatus, pingResults, pingStatus, pingingIp
      ];
}