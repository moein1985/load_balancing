// lib/presentation/bloc/load_balancing/load_balancing_bloc.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/domain/usecases/apply_ecmp_config.dart';
import 'package:load_balance/domain/usecases/get_pbr_configuration.dart';
import 'package:load_balance/domain/usecases/get_router_interfaces.dart';
import 'package:load_balance/domain/usecases/get_router_routing_table.dart';
import 'package:load_balance/domain/usecases/ping_gateway.dart';
import '../../../domain/usecases/delete_pbr_rule.dart';
import 'load_balancing_event.dart' as events;
import 'load_balancing_state.dart';

class LoadBalancingBloc
    extends Bloc<events.LoadBalancingEvent, LoadBalancingState> {
  final GetRouterInterfaces getInterfaces;
  final GetRouterRoutingTable getRoutingTable;
  final PingGateway pingGateway;
  final ApplyEcmpConfig applyEcmpConfig;
  final GetPbrConfiguration getPbrConfiguration;
  final DeletePbrRule deletePbrRule;
  final Map<String, Timer> _pingTimers = {};

  LoadBalancingBloc({
    required this.getInterfaces,
    required this.getRoutingTable,
    required this.pingGateway,
    required this.applyEcmpConfig,
    required this.getPbrConfiguration,
    required this.deletePbrRule,
  }) : super(const LoadBalancingState()) {
    on<events.ScreenStarted>(_onScreenStarted);
    on<events.FetchInterfacesRequested>(_onFetchInterfaces);
    on<events.FetchRoutingTableRequested>(_onFetchRoutingTable);
    on<events.PingGatewayRequested>(_onPingGateway);
    on<events.LoadBalancingTypeSelected>(_onLoadBalancingTypeSelected);
    on<events.ApplyEcmpConfig>(_onApplyEcmpConfig);
    on<events.ClearPingResult>(_onClearPingResult);
    on<events.FetchPbrConfigurationRequested>(_onFetchPbrConfiguration);
    on<events.DeletePbrRuleRequested>(_onDeletePbrRule);
    on<events.PbrRuleUpserted>(_onPbrRuleUpserted); // ثبت کنترل‌کننده جدید
  }

  @override
  Future<void> close() {
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

  void _onPbrRuleUpserted(
    events.PbrRuleUpserted event,
    Emitter<LoadBalancingState> emit,
  ) {
    final newRule = event.newRule;
    final currentRules = List<RouteMap>.from(state.pbrRouteMaps);

    final nameToFind = event.oldRuleName ?? newRule.name;
    final index = currentRules.indexWhere((rule) => rule.name == nameToFind);

    if (index != -1) {
      currentRules[index] = newRule;
      _logDebug(
        'Optimistically updated rule: ${event.oldRuleName} -> ${newRule.name}',
      );
    } else {
      currentRules.add(newRule);
      _logDebug('Optimistically added rule: ${newRule.name}');
    }

    currentRules.sort((a, b) => a.name.compareTo(b.name));
    emit(state.copyWith(pbrRouteMaps: currentRules));
  }

  Future<void> _onFetchPbrConfiguration(
    events.FetchPbrConfigurationRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) return;
    _logDebug('Starting to fetch PBR configuration');
    emit(state.copyWith(pbrStatus: DataStatus.loading));
    try {
      final pbrConfig = await getPbrConfiguration(state.credentials!);
      _logDebug(
        'PBR config received: ${pbrConfig.routeMaps.length} route-maps found.',
      );
      emit(
        state.copyWith(
          pbrStatus: DataStatus.success,
          pbrRouteMaps: pbrConfig.routeMaps,
          pbrAccessLists: pbrConfig.accessLists,
        ),
      );
    } on ServerFailure catch (e) {
      _logDebug('Error fetching PBR config: ${e.message}');
      emit(state.copyWith(pbrStatus: DataStatus.failure, pbrError: e.message));
    } catch (e) {
      _logDebug('Unknown error fetching PBR config: $e');
      emit(
        state.copyWith(
          pbrStatus: DataStatus.failure,
          pbrError: 'An unknown error occurred while fetching PBR rules.',
        ),
      );
    }
  }

  void _onLoadBalancingTypeSelected(
    events.LoadBalancingTypeSelected event,
    Emitter<LoadBalancingState> emit,
  ) {
    _logDebug('Load Balancing type selected: ${event.type}');
    emit(state.copyWith(type: event.type));

    if (event.type == LoadBalancingType.pbr &&
        state.pbrStatus == DataStatus.initial) {
      add(events.FetchPbrConfigurationRequested());
    } else if (event.type == LoadBalancingType.ecmp) {
      add(events.FetchRoutingTableRequested());
    }
  }

  List<String> _parseEcmpGateways(String routingTable) {
    final gateways = <String>{};
    final ecmpRegex = RegExp(r'0\.0\.0\.0/0\s.*via\s+([\d\.]+)');
    final subsequentLineRegex = RegExp(r'^\s*\[\d+/\d+\]\s+via\s+([\d\.]+)');
    final lines = routingTable.split('\n');
    bool inEcmpBlock = false;
    for (final line in lines) {
      if (line.contains('0.0.0.0/0')) {
        final match = ecmpRegex.firstMatch(line);
        if (match != null) {
          gateways.add(match.group(1)!);
          inEcmpBlock = true;
          continue;
        }
      }
      if (inEcmpBlock) {
        final match = subsequentLineRegex.firstMatch(line);
        if (match != null) {
          gateways.add(match.group(1)!);
        } else if (line.trim().isNotEmpty && !line.trim().startsWith('[')) {
          inEcmpBlock = false;
        }
      }
    }
    _logDebug('Parsed ECMP gateways (Corrected): ${gateways.toList()}');
    return gateways.toList();
  }

  void _onScreenStarted(
    events.ScreenStarted event,
    Emitter<LoadBalancingState> emit,
  ) {
    _logDebug('Screen started - IP: ${event.credentials.ip}');
    emit(
      state.copyWith(
        credentials: event.credentials,
        interfaces: event.interfaces,
        interfacesStatus: DataStatus.success,
      ),
    );
    add(events.FetchRoutingTableRequested());
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
    _logDebug('Starting to fetch interfaces (manual refresh)');
    emit(state.copyWith(interfacesStatus: DataStatus.loading));
    try {
      final interfaces = await getInterfaces(state.credentials!);
      _logDebug('${interfaces.length} interfaces received');
      emit(
        state.copyWith(
          interfaces: interfaces,
          interfacesStatus: DataStatus.success,
        ),
      );
    } on ServerFailure catch (e) {
      _logDebug('Error fetching interfaces: ${e.message}');
      emit(
        state.copyWith(interfacesStatus: DataStatus.failure, error: e.message),
      );
    } catch (e) {
      _logDebug('Unknown error fetching interfaces: $e');
      emit(
        state.copyWith(
          interfacesStatus: DataStatus.failure,
          error: 'An unknown error occurred while fetching interfaces.',
        ),
      );
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
    emit(
      state.copyWith(
        routingTableStatus: DataStatus.loading,
        clearRoutingTable: true,
      ),
    );
    try {
      final table = await getRoutingTable(state.credentials!);
      final gateways = _parseEcmpGateways(table);
      _logDebug(
        'Routing table received, ${gateways.length} ECMP gateways found.',
      );

      emit(
        state.copyWith(
          routingTable: table,
          routingTableStatus: DataStatus.success,
          initialEcmpGateways: gateways,
        ),
      );
    } on ServerFailure catch (e) {
      _logDebug('Error fetching routing table: ${e.message}');
      emit(
        state.copyWith(
          routingTable: 'Error: ${e.message}',
          routingTableStatus: DataStatus.failure,
        ),
      );
    } catch (e) {
      _logDebug('Unknown error fetching routing table: $e');
      emit(
        state.copyWith(
          routingTable:
              'An unknown error occurred while fetching routing table.',
          routingTableStatus: DataStatus.failure,
        ),
      );
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
    if (ipAddress.isEmpty) {
      _logDebug('Error: Empty IP for ping');
      final newPingResults = Map<String, String>.from(state.pingResults);
      newPingResults[''] = 'Error: IP address cannot be empty.';
      emit(state.copyWith(pingResults: newPingResults));
      return;
    }
    if (state.pingingIp == ipAddress) {
      _logDebug('Ping for IP $ipAddress is already in progress');
      return;
    }
    _pingTimers[ipAddress]?.cancel();
    _logDebug('Starting ping for IP: $ipAddress');
    emit(state.copyWith(pingStatus: DataStatus.loading, pingingIp: ipAddress));
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
      emit(
        state.copyWith(
          pingResults: newPingResults,
          pingStatus: DataStatus.success,
          pingingIp: '',
        ),
      );
    } catch (e) {
      _logDebug('Error during ping for $ipAddress: $e');
      _pingTimers[ipAddress]?.cancel();
      _pingTimers.remove(ipAddress);
      final newPingResults = Map<String, String>.from(state.pingResults);
      newPingResults[ipAddress] = 'Ping Error: ${e.toString()}';
      emit(
        state.copyWith(
          pingResults: newPingResults,
          pingStatus: DataStatus.failure,
          pingingIp: '',
        ),
      );
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
    final initialGateways = state.initialEcmpGateways;
    final finalGateways = event.finalGateways;
    _logDebug('Initial Gateways: $initialGateways');
    _logDebug('Final Gateways: $finalGateways');
    final gatewaysToAdd = finalGateways
        .where((g) => !initialGateways.contains(g))
        .toList();
    final gatewaysToRemove = initialGateways
        .where((g) => !finalGateways.contains(g))
        .toList();
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

      if (result.toLowerCase().contains('fail') ||
          result.toLowerCase().contains('error')) {
        emit(state.copyWith(status: DataStatus.failure, error: result));
      } else {
        emit(
          state.copyWith(status: DataStatus.success, successMessage: result),
        );
        add(events.FetchRoutingTableRequested());
      }
    } catch (e) {
      _logDebug('Error applying ECMP config: $e');
      emit(
        state.copyWith(
          status: DataStatus.failure,
          error: 'Failed to apply config: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onDeletePbrRule(
    events.DeletePbrRuleRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) return;
    emit(state.copyWith(status: DataStatus.loading, clearSuccessMessage: true));
    try {
      final result = await deletePbrRule(
        credentials: state.credentials!,
        ruleToDelete: event.ruleToDelete,
      );

      final updatedRouteMaps = List.of(state.pbrRouteMaps)
        ..removeWhere((rule) => rule.name == event.ruleToDelete.name);
      _logDebug('Optimistically removed rule: ${event.ruleToDelete.name}');

      emit(
        state.copyWith(
          status: DataStatus.success,
          successMessage: result,
          pbrRouteMaps: updatedRouteMaps,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: DataStatus.failure, error: e.toString()));
    }
  }
}
