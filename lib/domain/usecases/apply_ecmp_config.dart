// lib/domain/usecases/apply_ecmp_config.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';

class ApplyEcmpConfig {
  final DeviceRepository repository;

  ApplyEcmpConfig(this.repository);

  // **MODIFIED USE CASE**
  Future<String> call({
    required DeviceCredentials credentials,
    required List<String> gateways,
  }) async {
    // Now passes a list of gateways to the repository
    return await repository.applyEcmpConfig(
      credentials: credentials,
      gateways: gateways,
    );
  }
}