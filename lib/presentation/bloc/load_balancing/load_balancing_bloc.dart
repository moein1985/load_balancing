// lib/presentation/bloc/load_balancing/load_balancing_bloc.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/usecases/apply_ecmp_config.dart';
import 'package:load_balance/domain/usecases/get_interfaces.dart';
import 'package:load_balance/domain/usecases/get_routing_table.dart';
import 'package:load_balance/domain/usecases/ping_gateway.dart';
// Import the event file with a prefix to resolve the name conflict
import 'load_balancing_event.dart' as events;
import 'load_balancing_state.dart';

class LoadBalancingBloc extends Bloc<events.LoadBalancingEvent, LoadBalancingState> {
  final GetInterfaces getInterfaces;
  final GetRoutingTable getRoutingTable;
  final PingGateway pingGateway;
  final ApplyEcmpConfig applyEcmpConfig; // This is the Use Case class

  // Manage concurrent ping operations
  final Map<String, Timer> _pingTimers = {};

  LoadBalancingBloc({
    required this.getInterfaces,
    required this.getRoutingTable,
    required this.pingGateway,
    required this.applyEcmpConfig, // Injected dependency
  }) : super(const LoadBalancingState()) {
    on<events.ScreenStarted>(_onScreenStarted);
    on<events.FetchInterfacesRequested>(_onFetchInterfaces);
    on<events.FetchRoutingTableRequested>(_onFetchRoutingTable);
    on<events.PingGatewayRequested>(_onPingGateway);
    on<events.LoadBalancingTypeSelected>(_onLoadBalancingTypeSelected);
    // Use the prefixed event name here
    on<events.ApplyEcmpConfig>(_onApplyEcmpConfig);
    on<events.ClearPingResult>(_onClearPingResult);
  }

  @override
  Future<void> close() {
    // Clean up timers
    for (final timer in _pingTimers.values) {
      timer.cancel();
    }
    _pingTimers.clear();
    return super.close();
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[LoadBalancingBloc] $message');
    }
  }

  void _onScreenStarted(events.ScreenStarted event, Emitter<LoadBalancingState> emit) {
    _logDebug('Screen started - IP: ${event.credentials.ip}');
    emit(state.copyWith(credentials: event.credentials));
    add(events.FetchInterfacesRequested());
  }

  void _onLoadBalancingTypeSelected(
    events.LoadBalancingTypeSelected event,
    Emitter<LoadBalancingState> emit,
  ) {
    _logDebug('Load Balancing type selected: ${event.type}');
    emit(state.copyWith(type: event.type));
  }

  void _onClearPingResult(
    events.ClearPingResult event,
    Emitter<LoadBalancingState> emit,
  ) {
    final newPingResults = Map<String, String>.from(state.pingResults);
    newPingResults.remove(event.ipAddress);
    emit(state.copyWith(pingResults: newPingResults));
  }

  Future<void> _onFetchInterfaces(
    events.FetchInterfacesRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) {
      _logDebug('Error: Credentials not available');
      return;
    }

    _logDebug('Starting to fetch interfaces');
    emit(state.copyWith(interfacesStatus: DataStatus.loading));
    try {
      final interfaces = await getInterfaces(state.credentials!);
      _logDebug('${interfaces.length} interfaces received');
      emit(state.copyWith(
        interfaces: interfaces,
        interfacesStatus: DataStatus.success,
      ));
    } on ServerFailure catch (e) {
      _logDebug('Error fetching interfaces: ${e.message}');
      emit(state.copyWith(
        interfacesStatus: DataStatus.failure,
        error: e.message,
      ));
    } catch (e) {
      _logDebug('Unknown error fetching interfaces: $e');
      emit(state.copyWith(
        interfacesStatus: DataStatus.failure,
        error: 'An unknown error occurred while fetching interfaces.',
      ));
    }
  }

  Future<void> _onFetchRoutingTable(
    events.FetchRoutingTableRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) {
      _logDebug('Error: Credentials not available');
      return;
    }

    _logDebug('Starting to fetch routing table');
    emit(state.copyWith(
      routingTableStatus: DataStatus.loading,
      clearRoutingTable: true,
    ));
    try {
      final table = await getRoutingTable(state.credentials!);
      _logDebug('Routing table received');
      emit(state.copyWith(
        routingTable: table,
        routingTableStatus: DataStatus.success,
      ));
    } on ServerFailure catch (e) {
      _logDebug('Error fetching routing table: ${e.message}');
      emit(state.copyWith(
        routingTable: 'Error: ${e.message}',
        routingTableStatus: DataStatus.failure,
      ));
    } catch (e) {
      _logDebug('Unknown error fetching routing table: $e');
      emit(state.copyWith(
        routingTable: 'An unknown error occurred while fetching routing table.',
        routingTableStatus: DataStatus.failure,
      ));
    }
  }

  Future<void> _onPingGateway(
    events.PingGatewayRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) {
      _logDebug('Error: Credentials not available');
      return;
    }

    final ipAddress = event.ipAddress.trim();
    
    // IP Validation
    if (ipAddress.isEmpty) {
      _logDebug('Error: Empty IP for ping');
      final newPingResults = Map<String, String>.from(state.pingResults);
      newPingResults[''] = 'Error: IP address cannot be empty.';
      emit(state.copyWith(pingResults: newPingResults));
      return;
    }

    // Check if ping is already in progress
    if (state.pingingIp == ipAddress) {
      _logDebug('Ping for IP $ipAddress is already in progress');
      return;
    }

    // Cancel previous timer if it exists
    _pingTimers[ipAddress]?.cancel();
    _logDebug('Starting ping for IP: $ipAddress');
    emit(state.copyWith(
      pingStatus: DataStatus.loading,
      pingingIp: ipAddress,
    ));
    try {
      final result = await pingGateway(
        credentials: state.credentials!,
        ipAddress: ipAddress,
      );
      _logDebug('Ping result for $ipAddress: $result');
      
      _pingTimers[ipAddress]?.cancel();
      _pingTimers.remove(ipAddress);
      
      final newPingResults = Map<String, String>.from(state.pingResults);
      newPingResults[ipAddress] = result;
      
      emit(state.copyWith(
        pingResults: newPingResults,
        pingStatus: DataStatus.success,
        pingingIp: '',
      ));
    } catch (e) {
      _logDebug('Error during ping for $ipAddress: $e');
      _pingTimers[ipAddress]?.cancel();
      _pingTimers.remove(ipAddress);
      
      final newPingResults = Map<String, String>.from(state.pingResults);
      newPingResults[ipAddress] = 'Ping Error: ${e.toString()}';
      
      emit(state.copyWith(
        pingResults: newPingResults,
        pingStatus: DataStatus.failure,
        pingingIp: '',
      ));
    }
  }

  // Updated handler for applying ECMP configuration
  Future<void> _onApplyEcmpConfig(
    // Use the prefixed event name here
    events.ApplyEcmpConfig event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) {
      _logDebug('Error: Credentials not available for applying config');
      return;
    }

    _logDebug('Starting to apply ECMP config');
    _logDebug('Gateway 1: ${event.gateway1}');
    _logDebug('Gateway 2: ${event.gateway2}');
    
    // Set loading state and clear any previous success/error messages
    emit(state.copyWith(status: DataStatus.loading, clearSuccessMessage: true));
    
    try {
      // This is the Use Case class, no prefix needed
      final result = await applyEcmpConfig(
        credentials: state.credentials!,
        gateway1: event.gateway1,
        gateway2: event.gateway2,
      );

      _logDebug('ECMP config apply result: $result');
      
      // Check result message for success or failure keywords
      if (result.toLowerCase().contains('fail') || result.toLowerCase().contains('error')) {
         emit(state.copyWith(
            status: DataStatus.failure,
            error: result,
          ));
      } else {
         emit(state.copyWith(
            status: DataStatus.success,
            successMessage: result,
          ));
      }
    } catch (e) {
      _logDebug('Error applying ECMP config: $e');
      emit(state.copyWith(
        status: DataStatus.failure,
        error: 'Failed to apply config: ${e.toString()}',
      ));
    }
  }
}