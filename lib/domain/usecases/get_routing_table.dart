// domain/usecases/get_routing_table.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';

class GetRoutingTable {
  final DeviceRepository repository;

  GetRoutingTable(this.repository);

  Future<String> call(DeviceCredentials credentials) async {
    return await repository.getRoutingTable(credentials);
  }
}
//test