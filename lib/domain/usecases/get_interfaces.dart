// domain/usecases/get_interfaces.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';

class GetInterfaces {
  final DeviceRepository repository;

  GetInterfaces(this.repository);

  Future<List<RouterInterface>> call(DeviceCredentials credentials) async {
    return await repository.getInterfaces(credentials);
  }
}