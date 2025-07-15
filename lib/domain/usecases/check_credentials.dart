
// domain/usecases/check_credentials.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';

class CheckCredentials {
  final DeviceRepository repository;

  CheckCredentials(this.repository);

  Future<void> call(DeviceCredentials credentials) async {
    return await repository.checkCredentials(credentials);
  }
}