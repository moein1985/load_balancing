// domain/usecases/get_interfaces.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class GetRouterInterfaces {
  final RouterRepository repository;

  GetRouterInterfaces(this.repository);

  Future<List<RouterInterface>> call(LBDeviceCredentials credentials) async {
    return await repository.getInterfaces(credentials);
  }
}