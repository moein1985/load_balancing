// lib/domain/usecases/check_credentials.dart
import 'package:fpdart/fpdart.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class CheckCredentials {
  final RouterRepository repository;

  CheckCredentials(this.repository);

  Future<Either<Failure, List<RouterInterface>>> call(
      LBDeviceCredentials credentials) async {
    return await repository.checkCredentials(credentials);
  }
}