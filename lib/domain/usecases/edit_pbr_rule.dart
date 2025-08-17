// lib/domain/usecases/edit_pbr_rule.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_submission.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class EditPbrRule {
  final RouterRepository repository;

  EditPbrRule(this.repository);

  /// Executes the use case to edit a PBR rule.
  /// This is done by first deleting the old rule and then applying the new one.
  Future<String> call({
    required LBDeviceCredentials credentials,
    required RouteMap oldRule, // The original rule to be deleted
    required PbrSubmission newSubmission, // The new configuration to be applied
  }) async {
    // مرحله ۱: رول قدیمی را حذف می‌کنیم.
    await repository.deletePbrRule(
      credentials: credentials,
      ruleToDelete: oldRule,
    );

    // مرحله ۲: کانفیگ جدید را اعمال می‌کنیم.
    await repository.applyPbrRule(
      credentials: credentials,
      submission: newSubmission,
    );
    
    // **تغییر:** پیام موفقیت را ساده‌تر و واضح‌تر می‌کنیم.
    return 'Rule "${oldRule.name}" was successfully updated to "${newSubmission.routeMap.name}".';
  }
}