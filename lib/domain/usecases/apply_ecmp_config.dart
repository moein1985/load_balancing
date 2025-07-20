// lib/domain/usecases/apply_ecmp_config.dart
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';

class ApplyEcmpConfig {
  final DeviceRepository repository;

  ApplyEcmpConfig(this.repository);

  /// Executes the use case to apply ECMP configuration.
  Future<String> call({
    required DeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    // Pass both lists to the repository's method
    return await repository.applyEcmpConfig(
      credentials: credentials,
      gatewaysToAdd: gatewaysToAdd,
      gatewaysToRemove: gatewaysToRemove,
    );
  }
}