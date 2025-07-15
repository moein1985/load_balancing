// presentation/bloc/load_balancing/load_balancing_state.dart
import 'package:dartssh2/dartssh2.dart';
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';

enum LoadBalancingType { ecmp, pbr }

enum DataStatus { initial, loading, success, failure }

class LoadBalancingState extends Equatable {
  final DeviceCredentials? credentials;
  final SSHClient? sshClient; // Holds the active SSH client
  final LoadBalancingType type;
  final DataStatus status;
  final String error;

  final List<RouterInterface> interfaces;
  final DataStatus interfacesStatus;

  final String? routingTable;
  final DataStatus routingTableStatus;

  final Map<String, String> pingResults;
  final DataStatus pingStatus;
  final String? pingingIp;

  const LoadBalancingState({
    this.credentials,
    this.sshClient,
    this.type = LoadBalancingType.ecmp,
    this.status = DataStatus.initial,
    this.error = '',
    this.interfaces = const [],
    this.interfacesStatus = DataStatus.initial,
    this.routingTable,
    this.routingTableStatus = DataStatus.initial,
    this.pingResults = const {},
    this.pingStatus = DataStatus.initial,
    this.pingingIp,
  });

  LoadBalancingState copyWith({
    DeviceCredentials? credentials,
    SSHClient? sshClient,
    LoadBalancingType? type,
    DataStatus? status,
    String? error,
    List<RouterInterface>? interfaces,
    DataStatus? interfacesStatus,
    String? routingTable,
    DataStatus? routingTableStatus,
    Map<String, String>? pingResults,
    DataStatus? pingStatus,
    String? pingingIp,
    bool clearRoutingTable = false,
    bool clearSshClient = false,
  }) {
    return LoadBalancingState(
      credentials: credentials ?? this.credentials,
      sshClient: clearSshClient ? null : sshClient ?? this.sshClient,
      type: type ?? this.type,
      status: status ?? this.status,
      error: error ?? this.error,
      interfaces: interfaces ?? this.interfaces,
      interfacesStatus: interfacesStatus ?? this.interfacesStatus,
      routingTable:
          clearRoutingTable ? null : routingTable ?? this.routingTable,
      routingTableStatus: routingTableStatus ?? this.routingTableStatus,
      pingResults: pingResults ?? this.pingResults,
      pingStatus: pingStatus ?? this.pingStatus,
      pingingIp: pingingIp ?? this.pingingIp,
    );
  }

  @override
  List<Object?> get props => [
        credentials,
        sshClient,
        type,
        status,
        error,
        interfaces,
        interfacesStatus,
        routingTable,
        routingTableStatus,
        pingResults,
        pingStatus,
        pingingIp
      ];
}