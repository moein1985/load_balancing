// lib/domain/usecases/apply_pbr_rule.dart

import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';

class ApplyPbrRule {
  final DeviceRepository repository;

  ApplyPbrRule(this.repository);

  Future<String> call({
    required DeviceCredentials credentials,
    required PbrRule rule,
  }) async {
    return await repository.applyPbrRule(
      credentials: credentials,
      rule: rule,
    );
  }
}