// lib/presentation/bloc/router_connection/router_connection_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/usecases/check_credentials.dart';
import 'router_connection_event.dart';
import 'router_connection_state.dart';

class RouterConnectionBloc
    extends Bloc<RouterConnectionEvent, RouterConnectionState> {
  final CheckCredentials checkCredentials;
  RouterConnectionBloc({required this.checkCredentials})
      : super(ConnectionInitial()) {
    on<CheckCredentialsRequested>(_onCheckCredentials);
  }

  Future<void> _onCheckCredentials(
    CheckCredentialsRequested event,
    Emitter<RouterConnectionState> emit,
  ) async {
    emit(ConnectionLoading());
    
    final credentials = LBDeviceCredentials(
      ip: event.ip,
      username: event.username,
      password: event.password,
      enablePassword: event.enablePassword,
      type: event.type,
    );

    final result = await checkCredentials(credentials);

    // به جای try-catch از fold استفاده می‌کنیم
    result.fold(
      (failure) => emit(ConnectionFailure(failure.message)),
      (interfaces) => emit(ConnectionSuccess(credentials, interfaces)),
    );
  }
}