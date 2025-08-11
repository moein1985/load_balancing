// presentation/bloc/connection/connection_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/usecases/check_credentials.dart';
import 'router_connection_event.dart';
import 'router_connection_state.dart';

class RouterConnectionBloc extends Bloc<RouterConnectionEvent, RouterConnectionState> {
  final CheckCredentials checkCredentials;

  RouterConnectionBloc({required this.checkCredentials}) : super(ConnectionInitial()) {
    on<CheckCredentialsRequested>(_onCheckCredentials);
  }

  Future<void> _onCheckCredentials(
    CheckCredentialsRequested event,
    Emitter<RouterConnectionState> emit,
  ) async {
    emit(ConnectionLoading());
    try {
      final credentials = LBDeviceCredentials(
        ip: event.ip,
        username: event.username,
        password: event.password,
        enablePassword: event.enablePassword,
        type: event.type,
      );
      await checkCredentials(credentials);

      // Pass the credentials object in the success state
      emit(ConnectionSuccess(credentials));
    } on ServerFailure catch (e) {
      emit(ConnectionFailure(e.message));
    } catch (e) {
      emit(ConnectionFailure("An unexpected error occurred: ${e.toString()}"));
    }
  }
}