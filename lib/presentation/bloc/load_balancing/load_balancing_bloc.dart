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

  /// Helper method to parse gateway IPs from the 'show ip route' command output.
  /// THIS METHOD HAS BEEN CORRECTED AND MADE MORE ROBUST.
  List<String> _parseEcmpGateways(String routingTable) {
    final gateways = <String>{}; // Use a Set to handle duplicates automatically.
    
    // A more robust regex that looks for the 'via' keyword after a default route pattern.
    // This handles variations in spacing and formatting.
    final ecmpRegex = RegExp(r'0\.0\.0\.0/0\s.*via\s+([\d\.]+)');
    final subsequentLineRegex = RegExp(r'^\s*\[\d+/\d+\]\s+via\s+([\d\.]+)');

    final lines = routingTable.split('\n');
    bool inEcmpBlock = false;

    for (final line in lines) {
      if (line.contains('0.0.0.0/0')) {
        final match = ecmpRegex.firstMatch(line);
        if (match != null) {
          gateways.add(match.group(1)!);
          inEcmpBlock = true; // Once we find the first line, we enter the block
          continue; // Move to the next line
        }
      }

      // If we are in an ECMP block, check for subsequent indented lines
      if (inEcmpBlock) {
        final match = subsequentLineRegex.firstMatch(line);
        if (match != null) {
          gateways.add(match.group(1)!);
        } else if (line.trim().isNotEmpty && !line.trim().startsWith('[')) {
          // If the line is not empty and doesn't start with '[', the ECMP block has ended.
          inEcmpBlock = false;
        }
      }
    }

    _logDebug('Parsed ECMP gateways (Corrected): ${gateways.toList()}');
    return gateways.toList();
  }


  void _onScreenStarted(events.ScreenStarted event, Emitter<LoadBalancingState> emit) {
    _logDebug('Screen started - IP: ${event.credentials.ip}');
    emit(state.copyWith(credentials: event.credentials));
    // Fetch both interfaces and routing table when the screen starts.
    add(events.FetchInterfacesRequested());
    add(events.FetchRoutingTableRequested());
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
      // After fetching the table, parse it to find existing gateways.
      final gateways = _parseEcmpGateways(table);
      _logDebug('Routing table received, ${gateways.length} ECMP gateways found.');
      
      // Emit the new state with both the raw table and the parsed gateways.
      emit(state.copyWith(
        routingTable: table,
        routingTableStatus: DataStatus.success,
        initialEcmpGateways: gateways,
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

  Future<void> _onApplyEcmpConfig(
    events.ApplyEcmpConfig event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) {
      _logDebug('Error: Credentials not available for applying config');
      return;
    }

    _logDebug('Starting to apply ECMP config');
    
    // Get the initial list from the state and the final list from the UI event.
    final initialGateways = state.initialEcmpGateways;
    final finalGateways = event.finalGateways;
    _logDebug('Initial Gateways: $initialGateways');
    _logDebug('Final Gateways: $finalGateways');

    // The smart diff logic to determine what to add and what to remove.
    final gatewaysToAdd = finalGateways.where((g) => !initialGateways.contains(g)).toList();
    final gatewaysToRemove = initialGateways.where((g) => !finalGateways.contains(g)).toList();

    _logDebug('Gateways to Add: $gatewaysToAdd');
    _logDebug('Gateways to Remove: $gatewaysToRemove');

    emit(state.copyWith(status: DataStatus.loading, clearSuccessMessage: true));
    try {
      final result = await applyEcmpConfig(
        credentials: state.credentials!,
        gatewaysToAdd: gatewaysToAdd,
      gatewaysToRemove: gatewaysToRemove,
      );
      _logDebug('ECMP config apply result: $result');
      
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
         // After a successful operation, refresh the routing table to reflect the new state in the UI.
         add(events.FetchRoutingTableRequested());
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