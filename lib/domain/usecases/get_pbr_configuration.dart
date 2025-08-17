// lib/domain/usecases/get_pbr_configuration.dart
import 'package:fpdart/fpdart.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/data/datasources/pbr_parser.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';

class PbrConfiguration {
  final List<RouteMap> routeMaps;
  final List<AccessControlList> accessLists;

  const PbrConfiguration({required this.routeMaps, required this.accessLists});
}

class GetPbrConfiguration {
  final RouterRepository repository;

  GetPbrConfiguration(this.repository);

  Future<Either<Failure, PbrConfiguration>> call(
      LBDeviceCredentials credentials) async {
        
    final configResult = await repository.getRunningConfig(credentials);

    return configResult.fold(
      (failure) => Left(failure),
      (config) {
        try {
          final parsedRouteMaps = PbrParser.parseRouteMaps(config);
          final parsedAcls = PbrParser.parseAccessLists(config);
          final interfacePolicies = PbrParser.parseInterfacePolicies(config);

          final completeRouteMaps = parsedRouteMaps.map((rm) {
            String? appliedInterface;
            interfacePolicies.forEach((interface, routeMapName) {
              if (routeMapName == rm.name) {
                appliedInterface = interface;
              }
            });
            return rm.copyWith(appliedToInterface: appliedInterface);
          }).toList();
          
          return Right(PbrConfiguration(
            routeMaps: completeRouteMaps,
            accessLists: parsedAcls,
          ));
        } catch (e) {
          return Left(ServerFailure("Failed to parse router configuration: ${e.toString()}"));
        }
      },
    );
  }
}