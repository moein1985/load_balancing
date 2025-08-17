// lib/domain/usecases/apply_pbr_rule.dart
import 'package:fpdart/fpdart.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_submission.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class ApplyPbrRule {
  final RouterRepository repository;

  ApplyPbrRule(this.repository);

  Future<Either<Failure, String>> call({
    required LBDeviceCredentials credentials,
    required PbrSubmission submission,
  }) async {
    return await repository.applyPbrRule(
      credentials: credentials,
      submission: submission,
    );
  }
}