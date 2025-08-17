// lib/data/repositories/device_repository_impl.dart
import 'package:fpdart/fpdart.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/data/datasources/remote_datasource.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';
import '../../domain/entities/pbr_submission.dart';
import '../../domain/entities/route_map.dart';

class DeviceRepositoryImpl implements RouterRepository {
  final RemoteDataSource remoteDataSource;
  DeviceRepositoryImpl({required this.remoteDataSource});

  /// A helper function to wrap async calls in a try-catch block
  // ignore: unintended_html_in_doc_comment
  /// and return an Either<Failure, T>.
  Future<Either<Failure, T>> _tryCatch<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Right(result);
    } on ServerFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<RouterInterface>>> checkCredentials(
    LBDeviceCredentials credentials,
  ) async {
    // Re-using getInterfaces as it's a good way to verify credentials.
    return getInterfaces(credentials);
  }

  @override
  Future<Either<Failure, List<RouterInterface>>> getInterfaces(
    LBDeviceCredentials credentials,
  ) async {
    return _tryCatch(() => remoteDataSource.fetchInterfaces(credentials));
  }

  @override
  Future<Either<Failure, String>> getRoutingTable(
    LBDeviceCredentials credentials,
  ) async {
    return _tryCatch(() => remoteDataSource.getRoutingTable(credentials));
  }

  @override
  Future<Either<Failure, String>> getRunningConfig(
    LBDeviceCredentials credentials,
  ) async {
    // The retry logic is now simpler within the try-catch helper.
    // For more complex retry, this could be expanded.
    return _tryCatch(() => remoteDataSource.fetchRunningConfig(credentials));
  }

  @override
  Future<Either<Failure, String>> pingGateway({
    required LBDeviceCredentials credentials,
    required String ipAddress,
  }) async {
    return _tryCatch(
      () => remoteDataSource.pingGateway(credentials, ipAddress),
    );
  }

  @override
  Future<Either<Failure, String>> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    return _tryCatch(
      () => remoteDataSource.applyEcmpConfig(
        credentials: credentials,
        gatewaysToAdd: gatewaysToAdd,
        gatewaysToRemove: gatewaysToRemove,
      ),
    );
  }

  @override
  Future<Either<Failure, String>> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrSubmission submission,
  }) async {
    return _tryCatch(
      () => remoteDataSource.applyPbrRule(
        credentials: credentials,
        submission: submission,
      ),
    );
  }

  @override
  Future<Either<Failure, String>> deletePbrRule({
    required LBDeviceCredentials credentials,
    required RouteMap ruleToDelete,
  }) async {
    return _tryCatch(
      () => remoteDataSource.deletePbrRule(
        credentials: credentials,
        ruleToDelete: ruleToDelete,
      ),
    );
  }
}
