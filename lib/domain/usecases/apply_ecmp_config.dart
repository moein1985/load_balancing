// lib/domain/usecases/apply_ecmp_config.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';

class ApplyEcmpConfig {
  final DeviceRepository repository;

  ApplyEcmpConfig(this.repository);

  Future<String> call({
    required DeviceCredentials credentials,
    required String gateway1,
    required String gateway2,
  }) async {
    return await repository.applyEcmpConfig(
      credentials: credentials,
      gateway1: gateway1,
      gateway2: gateway2,
    );
  }
}