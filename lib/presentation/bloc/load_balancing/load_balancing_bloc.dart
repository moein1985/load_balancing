// lib/presentation/bloc/load_balancing/load_balancing_bloc.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
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
    on<events.PbrRuleUpserted>(_onPbrRuleUpserted);
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

  Future<void> _onFetchPbrConfiguration(
    events.FetchPbrConfigurationRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    _logDebug('Starting to fetch PBR configuration');
    emit(state.copyWith(pbrStatus: DataStatus.loading));

    // *** MODIFIED: Use credentials from the event ***
    final result = await getPbrConfiguration(event.credentials);
    result.fold(
      (failure) {
        _logDebug('Error fetching PBR config: ${failure.message}');
        emit(
          state.copyWith(
            pbrStatus: DataStatus.failure,
            pbrError: failure.message,
          ),
        );
      },
      (pbrConfig) {
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
      },
    );
  }

  Future<void> _onFetchRoutingTable(
    events.FetchRoutingTableRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    _logDebug('Starting to fetch routing table');
    emit(
      state.copyWith(
        routingTableStatus: DataStatus.loading,
        clearRoutingTable: true,
      ),
    );
    // *** MODIFIED: Use credentials from the event ***
    final result = await getRoutingTable(event.credentials);

    result.fold(
      (failure) {
        _logDebug('Error fetching routing table: ${failure.message}');
        emit(
          state.copyWith(
            routingTable: 'Error: ${failure.message}',
            routingTableStatus: DataStatus.failure,
          ),
        );
      },
      (table) {
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
      },
    );
  }

  Future<void> _onPingGateway(
    events.PingGatewayRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) return;
    final ipAddress = event.ipAddress.trim();
    if (ipAddress.isEmpty) {
      return;
    }
    if (state.pingingIp == ipAddress) return;
    _pingTimers[ipAddress]?.cancel();
    _logDebug('Starting ping for IP: $ipAddress');
    emit(state.copyWith(pingStatus: DataStatus.loading, pingingIp: ipAddress));
    final result = await pingGateway(
      credentials: state.credentials!,
      ipAddress: ipAddress,
    );
    _pingTimers[ipAddress]?.cancel();
    _pingTimers.remove(ipAddress);

    result.fold(
      (failure) {
        _logDebug('Error during ping for $ipAddress: ${failure.message}');
        final newPingResults = Map<String, String>.from(state.pingResults);
        newPingResults[ipAddress] = 'Ping Error: ${failure.message}';
        emit(
          state.copyWith(
            pingResults: newPingResults,
            pingStatus: DataStatus.failure,
            pingingIp: '',
          ),
        );
      },
      (successMessage) {
        _logDebug('Ping result for $ipAddress: $successMessage');
        final newPingResults = Map<String, String>.from(state.pingResults);
        newPingResults[ipAddress] = successMessage;
        emit(
          state.copyWith(
            pingResults: newPingResults,
            pingStatus: DataStatus.success,
            pingingIp: '',
          ),
        );
      },
    );
  }

  Future<void> _onApplyEcmpConfig(
    events.ApplyEcmpConfig event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) return;
    _logDebug('Starting to apply ECMP config');
    final initialGateways = state.initialEcmpGateways;
    final finalGateways = event.finalGateways;
    final gatewaysToAdd = finalGateways
        .where((g) => !initialGateways.contains(g))
        .toList();
    final gatewaysToRemove = initialGateways
        .where((g) => !finalGateways.contains(g))
        .toList();
    emit(state.copyWith(status: DataStatus.loading, clearSuccessMessage: true));

    final result = await applyEcmpConfig(
      credentials: state.credentials!,
      gatewaysToAdd: gatewaysToAdd,
      gatewaysToRemove: gatewaysToRemove,
    );
    result.fold(
      (failure) {
        _logDebug('Error applying ECMP config: ${failure.message}');
        emit(
          state.copyWith(
            status: DataStatus.failure,
            error: 'Failed to apply config: ${failure.message}',
          ),
        );
      },
      (successMessage) {
        _logDebug('ECMP config apply result: $successMessage');
        emit(
          state.copyWith(
            status: DataStatus.success,
            successMessage: successMessage,
          ),
        );
        add(events.FetchRoutingTableRequested(credentials: state.credentials!));
      },
    );
  }

  Future<void> _onDeletePbrRule(
    events.DeletePbrRuleRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) return;
    emit(state.copyWith(status: DataStatus.loading, clearSuccessMessage: true));

    final result = await deletePbrRule(
      credentials: state.credentials!,
      ruleToDelete: event.ruleToDelete,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(status: DataStatus.failure, error: failure.message),
      ),
      (successMessage) {
        final updatedRouteMaps = List.of(state.pbrRouteMaps)
          ..removeWhere((rule) => rule.name == event.ruleToDelete.name);
        _logDebug('Optimistically removed rule: ${event.ruleToDelete.name}');
        emit(
          state.copyWith(
            status: DataStatus.success,
            successMessage: successMessage,
            pbrRouteMaps: updatedRouteMaps,
          ),
        );
      },
    );
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
    // *** MODIFIED: Pass credentials to the event ***
    add(events.FetchRoutingTableRequested(credentials: event.credentials));
  }

  void _onClearPingResult(
    events.ClearPingResult event,
    Emitter<LoadBalancingState> emit,
  ) {
    final newPingResults = Map<String, String>.from(state.pingResults);
    newPingResults.remove(event.ipAddress);
    emit(state.copyWith(pingResults: newPingResults));
  }

  void _onPbrRuleUpserted(
    events.PbrRuleUpserted event,
    Emitter<LoadBalancingState> emit,
  ) {
    final newRule = event.newRule;
    final currentRules = List<RouteMap>.from(state.pbrRouteMaps);
    final currentAcls = List<AccessControlList>.from(state.pbrAccessLists);

    if (event.newAcl != null) {
      final aclExists = currentAcls.any((acl) => acl.id == event.newAcl!.id);
      if (!aclExists) {
        currentAcls.add(event.newAcl!);
        _logDebug('Optimistically added ACL: ${event.newAcl!.id}');
      }
    }

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
    emit(
      state.copyWith(pbrRouteMaps: currentRules, pbrAccessLists: currentAcls),
    );
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

  void _onLoadBalancingTypeSelected(
    events.LoadBalancingTypeSelected event,
    Emitter<LoadBalancingState> emit,
  ) {
    if (state.credentials == null) return;
    _logDebug('Load Balancing type selected: ${event.type}');
    emit(state.copyWith(type: event.type));

    if (event.type == LoadBalancingType.pbr &&
        state.pbrStatus == DataStatus.initial) {
      // *** MODIFIED: Pass credentials to the event ***
      add(
        events.FetchPbrConfigurationRequested(credentials: state.credentials!),
      );
    } else if (event.type == LoadBalancingType.ecmp) {
      // *** MODIFIED: Pass credentials to the event ***
      add(events.FetchRoutingTableRequested(credentials: state.credentials!));
    }
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
    final result = await getInterfaces(state.credentials!);
    result.fold(
      (failure) {
        _logDebug('Error fetching interfaces: ${failure.message}');
        emit(
          state.copyWith(
            interfacesStatus: DataStatus.failure,
            error: failure.message,
          ),
        );
      },
      (interfaces) {
        _logDebug('${interfaces.length} interfaces received');
        emit(
          state.copyWith(
            interfaces: interfaces,
            interfacesStatus: DataStatus.success,
          ),
        );
      },
    );
  }
}
