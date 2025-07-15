// presentation/bloc/load_balancing/load_balancing_bloc.dart
import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/data/datasources/remote_datasource.dart';
import 'load_balancing_event.dart';
import 'load_balancing_state.dart';

class LoadBalancingBloc extends Bloc<LoadBalancingEvent, LoadBalancingState> {
  final RemoteDataSource _remoteDataSource;

  LoadBalancingBloc({required RemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource,
        super(const LoadBalancingState()) {
    on<ScreenStarted>(_onScreenStarted);
    on<DisconnectRequested>(_onDisconnectRequested);
    on<FetchInterfacesRequested>(_onFetchInterfaces);
    on<FetchRoutingTableRequested>(_onFetchRoutingTable);
    on<PingGatewayRequested>(_onPingGateway);
    on<LoadBalancingTypeSelected>(
        (event, emit) => emit(state.copyWith(type: event.type)));
  }

  Future<void> _onScreenStarted(
    ScreenStarted event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.sshClient != null && !state.sshClient!.isClosed) return;

    emit(state.copyWith(
        credentials: event.credentials, interfacesStatus: DataStatus.loading));

    try {
      final socket = await SSHSocket.connect(event.credentials.ip, 22,
          timeout: const Duration(seconds: 10));

      final client = SSHClient(
        socket,
        username: event.credentials.username,
        onPasswordRequest: () => event.credentials.password,
      );

      emit(state.copyWith(sshClient: client));
      add(FetchInterfacesRequested());
    } catch (e) {
      emit(state.copyWith(
          interfacesStatus: DataStatus.failure,
          error: 'Failed to connect: ${e.toString()}'));
    }
  }

  Future<void> _onDisconnectRequested(
    DisconnectRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    state.sshClient?.close();
    emit(state.copyWith(clearSshClient: true));
    debugPrint("SSH Client disconnected.");
  }

  Future<void> _onFetchInterfaces(
    FetchInterfacesRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.sshClient == null) return;
    emit(state.copyWith(interfacesStatus: DataStatus.loading));
    try {
      final interfaces =
          await _remoteDataSource.fetchInterfaces(state.sshClient!);
      emit(state.copyWith(
          interfaces: interfaces, interfacesStatus: DataStatus.success));
    } catch (e) {
      emit(state.copyWith(
          interfacesStatus: DataStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onFetchRoutingTable(
    FetchRoutingTableRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.sshClient == null) return;
    emit(state.copyWith(
        routingTableStatus: DataStatus.loading, clearRoutingTable: true));
    try {
      final table = await _remoteDataSource.getRoutingTable(state.sshClient!);
      emit(state.copyWith(
          routingTable: table, routingTableStatus: DataStatus.success));
    } catch (e) {
      emit(state.copyWith(
          routingTable: "Error: ${e.toString()}",
          routingTableStatus: DataStatus.failure));
    }
  }

  Future<void> _onPingGateway(
    PingGatewayRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.sshClient == null) return;
    emit(state.copyWith(
        pingStatus: DataStatus.loading, pingingIp: event.ipAddress));
    try {
      final result =
          await _remoteDataSource.pingGateway(state.sshClient!, event.ipAddress);
      final newPingResults = Map<String, String>.from(state.pingResults);
      newPingResults[event.ipAddress] = result;
      emit(state.copyWith(
        pingResults: newPingResults,
        pingStatus: DataStatus.success,
        pingingIp: '',
      ));
    } catch (e) {
      final newPingResults = Map<String, String>.from(state.pingResults);
      newPingResults[event.ipAddress] = 'Error: ${e.toString()}';
      emit(state.copyWith(
        pingResults: newPingResults,
        pingStatus: DataStatus.failure,
        pingingIp: '',
      ));
    }
  }
}