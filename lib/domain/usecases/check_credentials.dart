
// domain/usecases/check_credentials.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class CheckCredentials {
  final RouterRepository repository;

  CheckCredentials(this.repository);

  Future<void> call(LBDeviceCredentials credentials) async {
    return await repository.checkCredentials(credentials);
  }
}