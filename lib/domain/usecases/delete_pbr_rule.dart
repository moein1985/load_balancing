// lib/domain/usecases/delete_pbr_rule.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class DeletePbrRule {
  final RouterRepository repository;

  DeletePbrRule(this.repository);

  Future<String> call({
    required LBDeviceCredentials credentials,
    required RouteMap ruleToDelete,
  }) async {
    return await repository.deletePbrRule(
      credentials: credentials,
      ruleToDelete: ruleToDelete,
    );
  }
}