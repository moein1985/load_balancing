// lib/presentation/bloc/load_balancing/load_balancing_bloc.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
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

  // مدیریت عملیات‌های همزمان ping
  final Map<String, Timer> _pingTimers = {};

  LoadBalancingBloc({
    required this.getInterfaces,
    required this.getRoutingTable,
    required this.pingGateway,
  }) : super(const LoadBalancingState()) {
    on<ScreenStarted>(_onScreenStarted);
    on<FetchInterfacesRequested>(_onFetchInterfaces);
    on<FetchRoutingTableRequested>(_onFetchRoutingTable);
    on<PingGatewayRequested>(_onPingGateway);
    on<LoadBalancingTypeSelected>(_onLoadBalancingTypeSelected);
    on<ApplyEcmpConfig>(_onApplyEcmpConfig);
    on<ClearPingResult>(_onClearPingResult);
  }

  @override
  Future<void> close() {
    // پاکسازی تایمرها
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

  void _onScreenStarted(ScreenStarted event, Emitter<LoadBalancingState> emit) {
    _logDebug('صفحه شروع شد - IP: ${event.credentials.ip}');
    emit(state.copyWith(credentials: event.credentials));
    add(FetchInterfacesRequested());
  }

  void _onLoadBalancingTypeSelected(
    LoadBalancingTypeSelected event,
    Emitter<LoadBalancingState> emit,
  ) {
    _logDebug('نوع Load Balancing انتخاب شد: ${event.type}');
    emit(state.copyWith(type: event.type));
  }

  void _onClearPingResult(
    ClearPingResult event,
    Emitter<LoadBalancingState> emit,
  ) {
    final newPingResults = Map<String, String>.from(state.pingResults);
    newPingResults.remove(event.ipAddress);
    emit(state.copyWith(pingResults: newPingResults));
  }

  Future<void> _onFetchInterfaces(
    FetchInterfacesRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) {
      _logDebug('خطا: اعتبارنامه موجود نیست');
      return;
    }

    _logDebug('شروع دریافت Interface ها');
    emit(state.copyWith(interfacesStatus: DataStatus.loading));
    
    try {
      final interfaces = await getInterfaces(state.credentials!);
      _logDebug('${interfaces.length} Interface دریافت شد');
      
      emit(state.copyWith(
        interfaces: interfaces,
        interfacesStatus: DataStatus.success,
        error: '',
      ));
    } on ServerFailure catch (e) {
      _logDebug('خطا در دریافت Interface ها: ${e.message}');
      emit(state.copyWith(
        interfacesStatus: DataStatus.failure,
        error: e.message,
      ));
    } catch (e) {
      _logDebug('خطای ناشناخته در دریافت Interface ها: $e');
      emit(state.copyWith(
        interfacesStatus: DataStatus.failure,
        error: 'خطای ناشناخته در دریافت Interface ها',
      ));
    }
  }

  Future<void> _onFetchRoutingTable(
    FetchRoutingTableRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) {
      _logDebug('خطا: اعتبارنامه موجود نیست');
      return;
    }

    _logDebug('شروع دریافت جدول مسیریابی');
    emit(state.copyWith(
      routingTableStatus: DataStatus.loading,
      clearRoutingTable: true,
    ));
    
    try {
      final table = await getRoutingTable(state.credentials!);
      _logDebug('جدول مسیریابی دریافت شد');
      
      emit(state.copyWith(
        routingTable: table,
        routingTableStatus: DataStatus.success,
      ));
    } on ServerFailure catch (e) {
      _logDebug('خطا در دریافت جدول مسیریابی: ${e.message}');
      emit(state.copyWith(
        routingTable: 'خطا: ${e.message}',
        routingTableStatus: DataStatus.failure,
      ));
    } catch (e) {
      _logDebug('خطای ناشناخته در دریافت جدول مسیریابی: $e');
      emit(state.copyWith(
        routingTable: 'خطای ناشناخته در دریافت جدول مسیریابی',
        routingTableStatus: DataStatus.failure,
      ));
    }
  }

  Future<void> _onPingGateway(
    PingGatewayRequested event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) {
      _logDebug('خطا: اعتبارنامه موجود نیست');
      return;
    }

    final ipAddress = event.ipAddress.trim();
    
    // اعتبارسنجی IP
    if (ipAddress.isEmpty) {
      _logDebug('خطا: IP خالی برای ping');
      final newPingResults = Map<String, String>.from(state.pingResults);
      newPingResults[''] = 'خطا: آدرس IP نمی‌تواند خالی باشد';
      emit(state.copyWith(pingResults: newPingResults));
      return;
    }

    // بررسی اگر ping در حال انجام است
    if (state.pingingIp == ipAddress) {
      _logDebug('ping برای IP $ipAddress در حال انجام است');
      return;
    }

    // لغو ping قبلی اگر وجود دارد
    _pingTimers[ipAddress]?.cancel();
    
    _logDebug('شروع ping برای IP: $ipAddress');
    emit(state.copyWith(
      pingStatus: DataStatus.loading,
      pingingIp: ipAddress,
    ));

    try {
      // تنظیم تایمر برای نمایش پیشرفت
      _pingTimers[ipAddress] = Timer.periodic(
        Duration(seconds: 1),
        (timer) {
          if (!emit.isDone && state.pingingIp == ipAddress) {
            // می‌توان پیشرفت ping را نمایش داد
          }
        },
      );

      final result = await pingGateway(
        credentials: state.credentials!,
        ipAddress: ipAddress,
      );
      
      _logDebug('نتیجه ping برای $ipAddress: $result');
      
      // لغو تایمر
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
      _logDebug('خطا در ping برای $ipAddress: $e');
      
      // لغو تایمر
      _pingTimers[ipAddress]?.cancel();
      _pingTimers.remove(ipAddress);
      
      final newPingResults = Map<String, String>.from(state.pingResults);
      newPingResults[ipAddress] = 'خطا در ping: ${e.toString()}';
      
      emit(state.copyWith(
        pingResults: newPingResults,
        pingStatus: DataStatus.failure,
        pingingIp: '',
      ));
    }
  }

  Future<void> _onApplyEcmpConfig(
    ApplyEcmpConfig event,
    Emitter<LoadBalancingState> emit,
  ) async {
    if (state.credentials == null) {
      _logDebug('خطا: اعتبارنامه موجود نیست');
      return;
    }

    _logDebug('شروع اعمال تنظیمات ECMP');
    _logDebug('Gateway 1: ${event.gateway1}');
    _logDebug('Gateway 2: ${event.gateway2}');
    
    emit(state.copyWith(status: DataStatus.loading));
    
    try {
      // پیاده‌سازی اعمال تنظیمات ECMP
      // این بخش بر اساس نیازهای خاص شما پیاده‌سازی خواهد شد
      
      await Future.delayed(Duration(seconds: 2)); // شبیه‌سازی عملیات
      
      _logDebug('تنظیمات ECMP با موفقیت اعمال شد');
      emit(state.copyWith(
        status: DataStatus.success,
        error: '',
      ));
    } catch (e) {
      _logDebug('خطا در اعمال تنظیمات ECMP: $e');
      emit(state.copyWith(
        status: DataStatus.failure,
        error: 'خطا در اعمال تنظیمات: ${e.toString()}',
      ));
    }
  }
}
