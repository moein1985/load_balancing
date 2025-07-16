// lib/presentation/bloc/load_balancing/load_balancing_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/usecases/get_interfaces.dart';
import 'package:load_balance/domain/usecases/get_routing_table.dart';
import 'package:load_balance/domain/usecases/ping_gateway.dart';
import 'load_balancing_event.dart';
import 'load_balancing_state.dart';

class LoadBalancingBloc extends Bloc<LoadBalancingEvent, LoadBalancingState> {
  final GetInterfaces getInterfaces;
  final GetRoutingTable getRoutingTable;
  final PingGateway pingGateway;

  LoadBalancingBloc({
    required this.getInterfaces,
    required this.getRoutingTable,
    required this.pingGateway,
  }) : super(const LoadBalancingState()) {
    on<ScreenStarted>(_onScreenStarted);
    on<FetchInterfacesRequested>(_onFetchInterfaces);
    on<FetchRoutingTableRequested>(_onFetchRoutingTable);
    on<PingGatewayRequested>(_onPingGateway);
    on<LoadBalancingTypeSelected>(
      (event, emit) => emit(state.copyWith(type: event.type)),
    );
    on<ApplyEcmpConfig>(_onApplyEcmpConfig);
  }

  void _onScreenStarted(ScreenStarted event, Emitter<LoadBalancingState> emit) {
    emit(state.copyWith(credentials: event.credentials));
    add(FetchInterfacesRequested());
  }

  Future<void> _onFetchInterfaces(
    FetchInterfacesRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) return;
    emit(state.copyWith(interfacesStatus: DataStatus.loading));
    try {
      final interfaces = await getInterfaces(state.credentials!);
      emit(
        state.copyWith(
          interfaces: interfaces,
          interfacesStatus: DataStatus.success,
        ),
      );
    } on ServerFailure catch (e) {
      emit(
        state.copyWith(interfacesStatus: DataStatus.failure, error: e.message),
      );
    }
  }

  Future<void> _onFetchRoutingTable(
    FetchRoutingTableRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) return;
    emit(
      state.copyWith(
        routingTableStatus: DataStatus.loading,
        clearRoutingTable: true,
      ),
    );
    try {
      final table = await getRoutingTable(state.credentials!);
      emit(
        state.copyWith(
          routingTable: table,
          routingTableStatus: DataStatus.success,
        ),
      );
    } on ServerFailure catch (e) {
      emit(
        state.copyWith(
          routingTable: e.message,
          routingTableStatus: DataStatus.failure,
        ),
      );
    }
  }

  Future<void> _onPingGateway(
    PingGatewayRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    // The BLoC now needs to pass the credentials to the use case.
    if (state.credentials == null) return;
    emit(
      state.copyWith(
        pingStatus: DataStatus.loading,
        pingingIp: event.ipAddress,
      ),
    );
    final result = await pingGateway(
      credentials: state.credentials!,
      ipAddress: event.ipAddress,
    );
    final newPingResults = Map<String, String>.from(state.pingResults);
    newPingResults[event.ipAddress] = result;
    emit(
      state.copyWith(
        pingResults: newPingResults,
        pingStatus: DataStatus.success,
        pingingIp: '',
      ),
    );
  }

  Future<void> _onApplyEcmpConfig(
    ApplyEcmpConfig event,
    Emitter<LoadBalancingState> emit,
  ) async {
    // Logic to apply ECMP config will go here.
  }
}
