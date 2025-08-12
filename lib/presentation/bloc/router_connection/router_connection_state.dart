// presentation/bloc/connection/router_connection_state.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart'; // این import را اضافه کنید

abstract class RouterConnectionState extends Equatable {
  const RouterConnectionState();

  @override
  List<Object> get props => [];
}

class ConnectionInitial extends RouterConnectionState {}

class ConnectionLoading extends RouterConnectionState {}

// ***تغییر اصلی***
// این کلاس اکنون لیست اینترفیس‌ها را هم به همراه اطلاعات کاربری نگه می‌دارد
class ConnectionSuccess extends RouterConnectionState {
  final LBDeviceCredentials credentials;
  final List<RouterInterface> interfaces; // این خط اضافه شده است

  const ConnectionSuccess(this.credentials, this.interfaces); // کانستراکتور آپدیت شد

  @override
  List<Object> get props => [credentials, interfaces]; // پراپرتی جدید به props اضافه شد
}

class ConnectionFailure extends RouterConnectionState {
  final String error;

  const ConnectionFailure(this.error);
  @override
  List<Object> get props => [error];
}