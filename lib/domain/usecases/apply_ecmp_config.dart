// lib/domain/usecases/apply_ecmp_config.dart
import 'package:fpdart/fpdart.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class ApplyEcmpConfig {
  final RouterRepository repository;

  ApplyEcmpConfig(this.repository);

  Future<Either<Failure, String>> call({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    return await repository.applyEcmpConfig(
      credentials: credentials,
      gatewaysToAdd: gatewaysToAdd,
      gatewaysToRemove: gatewaysToRemove,
    );
  }
}