// lib/domain/usecases/edit_pbr_rule.dart
import 'package:fpdart/fpdart.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_submission.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class EditPbrRule {
  final RouterRepository repository;

  EditPbrRule(this.repository);

  Future<Either<Failure, String>> call({
    required LBDeviceCredentials credentials,
    required RouteMap oldRule,
    required PbrSubmission newSubmission,
  }) async {
    // 1. Delete the old rule
    final deleteResult = await repository.deletePbrRule(
      credentials: credentials,
      ruleToDelete: oldRule,
    );

    // If deletion fails, stop and return the failure
    return deleteResult.fold(
      (failure) => Left(failure),
      (_) async {
        // 2. If deletion succeeds, apply the new rule
        final applyResult = await repository.applyPbrRule(
          credentials: credentials,
          submission: newSubmission,
        );
        
        return applyResult.fold(
          (failure) => Left(failure),
          (_) => Right('Rule "${oldRule.name}" was successfully updated to "${newSubmission.routeMap.name}".')
        );
      },
    );
  }
}