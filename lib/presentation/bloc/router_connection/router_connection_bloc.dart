// lib/presentation/bloc/router_connection/router_connection_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/usecases/check_credentials.dart';
import 'package:load_balance/presentation/screens/connection/router_connection_screen.dart';
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

    // **MODIFIED: Logic to parse and default the port**
    int port;
    if (event.port.trim().isEmpty) {
      port = event.type == ConnectionType.ssh ? 22 : 23;
    } else {
      final parsedPort = int.tryParse(event.port.trim());
      if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
        emit(
          const ConnectionFailure(
            "Invalid port number. It must be between 1 and 65535.",
          ),
        );
        return;
      }
      port = parsedPort;
    }

    final credentials = LBDeviceCredentials(
      ip: event.ip,
      port: port, // **MODIFIED: Use the validated port**
      username: event.username,
      password: event.password,
      enablePassword: event.enablePassword,
      type: event.type,
    );

    final result = await checkCredentials(credentials);

    result.fold(
      (failure) => emit(ConnectionFailure(failure.message)),
      (interfaces) => emit(ConnectionSuccess(credentials, interfaces)),
    );
  }
}
