// lib/presentation/bloc/load_balancing/load_balancing_state.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

// **تغییر ۱: این enum ها به این فایل منتقل شدند**
enum LoadBalancingType { ecmp, pbr }
enum DataStatus { initial, loading, success, failure }

class LoadBalancingState extends Equatable {
  // وضعیت کلی صفحه (مثلا برای نمایش اسنک‌بار موفقیت/شکست)
  final DataStatus status;
  final String? successMessage;
  final String error;

  final LBDeviceCredentials? credentials;
  final LoadBalancingType type;

  // وضعیت و داده‌های مربوط به Interfaces
  final DataStatus interfacesStatus;
  final List<RouterInterface> interfaces;

  // وضعیت و داده‌های مربوط به Routing Table و ECMP
  final DataStatus routingTableStatus;
  final String? routingTable;
  final List<String> initialEcmpGateways;
  final Map<String, String> pingResults;
  final DataStatus pingStatus;
  final String pingingIp;
  
  // وضعیت و داده‌های مربوط به PBR
  final DataStatus pbrStatus;
  final String pbrError;
  final List<RouteMap> pbrRouteMaps;
  final List<AccessControlList> pbrAccessLists;


  const LoadBalancingState({
    this.status = DataStatus.initial,
    this.successMessage,
    this.error = '',
    this.credentials,
    this.type = LoadBalancingType.ecmp,
    this.interfacesStatus = DataStatus.initial,
    this.interfaces = const [],
    this.routingTableStatus = DataStatus.initial,
    this.routingTable,
    this.initialEcmpGateways = const [],
    this.pingResults = const {},
    this.pingStatus = DataStatus.initial,
    this.pingingIp = '',
    this.pbrStatus = DataStatus.initial,
    this.pbrError = '',
    this.pbrRouteMaps = const [],
    this.pbrAccessLists = const [],
  });

  LoadBalancingState copyWith({
    DataStatus? status,
    String? successMessage,
    bool clearSuccessMessage = false,
    String? error,
    LBDeviceCredentials? credentials,
    LoadBalancingType? type,
    DataStatus? interfacesStatus,
    List<RouterInterface>? interfaces,
    DataStatus? routingTableStatus,
    String? routingTable,
    bool clearRoutingTable = false,
    List<String>? initialEcmpGateways,
    Map<String, String>? pingResults,
    DataStatus? pingStatus,
    String? pingingIp,
    DataStatus? pbrStatus,
    String? pbrError,
    List<RouteMap>? pbrRouteMaps,
    List<AccessControlList>? pbrAccessLists,
  }) {
    return LoadBalancingState(
      status: status ?? this.status,
      successMessage: clearSuccessMessage ? null : successMessage ?? this.successMessage,
      error: error ?? this.error,
      credentials: credentials ?? this.credentials,
      type: type ?? this.type,
      interfacesStatus: interfacesStatus ?? this.interfacesStatus,
      interfaces: interfaces ?? this.interfaces,
      routingTableStatus: routingTableStatus ?? this.routingTableStatus,
      routingTable: clearRoutingTable ? null : routingTable ?? this.routingTable,
      initialEcmpGateways: initialEcmpGateways ?? this.initialEcmpGateways,
      pingResults: pingResults ?? this.pingResults,
      pingStatus: pingStatus ?? this.pingStatus,
      pingingIp: pingingIp ?? this.pingingIp,
      pbrStatus: pbrStatus ?? this.pbrStatus,
      pbrError: pbrError ?? this.pbrError,
      pbrRouteMaps: pbrRouteMaps ?? this.pbrRouteMaps,
      pbrAccessLists: pbrAccessLists ?? this.pbrAccessLists,
    );
  }

  @override
  List<Object?> get props => [
        status,
        successMessage,
        error,
        credentials,
        type,
        interfacesStatus,
        interfaces,
        routingTableStatus,
        routingTable,
        initialEcmpGateways,
        pingResults,
        pingStatus,
        pingingIp,
        pbrStatus,
        pbrError,
        pbrRouteMaps,
        pbrAccessLists,
      ];
}