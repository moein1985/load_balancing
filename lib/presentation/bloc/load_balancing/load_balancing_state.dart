// lib/presentation/bloc/load_balancing/load_balancing_state.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

enum LoadBalancingType { ecmp, pbr }
enum DataStatus { initial, loading, success, failure }

class LoadBalancingState extends Equatable {
  // Holds the credentials to be used for each request
  final LBDeviceCredentials? credentials;
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

  // **فیلدهای جدید برای مدیریت PBR**
  final List<RouteMap> pbrRouteMaps;
  final List<AccessControlList> pbrAccessLists;
  final DataStatus pbrStatus;
  final String pbrError;

  const LoadBalancingState({
    this.credentials,
    this.type = LoadBalancingType.ecmp,
    this.status = DataStatus.initial,
    this.error = '',
    this.successMessage,
    this.interfaces = const [],
    this.interfacesStatus = DataStatus.initial,
    this.initialEcmpGateways = const [], 
    this.routingTable,
    this.routingTableStatus = DataStatus.initial,
    this.pingResults = const {},
    this.pingStatus = DataStatus.initial,
    this.pingingIp,
    // **مقداردهی اولیه فیلدهای جدید**
    this.pbrRouteMaps = const [],
    this.pbrAccessLists = const [],
    this.pbrStatus = DataStatus.initial,
    this.pbrError = '',
  });

  LoadBalancingState copyWith({
    LBDeviceCredentials? credentials,
    LoadBalancingType? type,
    DataStatus? status,
    String? error,
    String? successMessage,
    bool clearSuccessMessage = false,
    List<RouterInterface>? interfaces,
    DataStatus? interfacesStatus,
    List<String>? initialEcmpGateways,
    String? routingTable,
    bool clearRoutingTable = false,
    DataStatus? routingTableStatus,
    Map<String, String>? pingResults,
    DataStatus? pingStatus,
    String? pingingIp,
    // **اضافه شدن به copyWith**
    List<RouteMap>? pbrRouteMaps,
    List<AccessControlList>? pbrAccessLists,
    DataStatus? pbrStatus,
    String? pbrError,
  }) {
    return LoadBalancingState(
      credentials: credentials ?? this.credentials,
      type: type ?? this.type,
      status: status ?? this.status,
      error: (status != null && status != DataStatus.failure) ? '' : error ?? this.error,
      successMessage: clearSuccessMessage ? null : successMessage ?? this.successMessage,
      interfaces: interfaces ?? this.interfaces,
      interfacesStatus: interfacesStatus ?? this.interfacesStatus,
      initialEcmpGateways: initialEcmpGateways ?? this.initialEcmpGateways,
      routingTable: clearRoutingTable ? null : routingTable ?? this.routingTable,
      routingTableStatus: routingTableStatus ?? this.routingTableStatus,
      pingResults: pingResults ?? this.pingResults,
      pingStatus: pingStatus ?? this.pingStatus,
      pingingIp: pingingIp ?? this.pingingIp,
      // **استفاده در copyWith**
      pbrRouteMaps: pbrRouteMaps ?? this.pbrRouteMaps,
      pbrAccessLists: pbrAccessLists ?? this.pbrAccessLists,
      pbrStatus: pbrStatus ?? this.pbrStatus,
      pbrError: (pbrStatus != null && pbrStatus != DataStatus.failure) ? '' : pbrError ?? this.pbrError,
    );
  }

  @override
  List<Object?> get props => [
        credentials, type, status, error, successMessage, interfaces, interfacesStatus,
        initialEcmpGateways, routingTable, routingTableStatus, pingResults, pingStatus, pingingIp,
        // **اضافه شدن به props برای Equatable**
        pbrRouteMaps, pbrAccessLists, pbrStatus, pbrError,
      ];
}