// lib/domain/usecases/apply_pbr_rule.dart

import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class ApplyPbrRule {
  final RouterRepository repository;

  ApplyPbrRule(this.repository);

  Future<String> call({
    required LBDeviceCredentials credentials,
    required PbrRule rule,
  }) async {
    return await repository.applyPbrRule(
      credentials: credentials,
      rule: rule,
    );
  }
}