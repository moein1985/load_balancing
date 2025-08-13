// lib/domain/usecases/get_pbr_configuration.dart
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

  Future<PbrConfiguration> call(LBDeviceCredentials credentials) async {
    // We get the raw config from the repository
    final config = await repository.getRunningConfig(credentials);
    
    // The use case is responsible for orchestrating the parsing
    final parsedRouteMaps = PbrParser.parseRouteMaps(config);
    final parsedAcls = PbrParser.parseAccessLists(config);
    final interfacePolicies = PbrParser.parseInterfacePolicies(config);

    // Link route-maps to the interfaces they are applied to
    final completeRouteMaps = parsedRouteMaps.map((rm) {
      String? appliedInterface;
      interfacePolicies.forEach((interface, routeMapName) {
        if (routeMapName == rm.name) {
          appliedInterface = interface;
        }
      });
      return rm.copyWith(appliedToInterface: appliedInterface);
    }).toList();

    return PbrConfiguration(
      routeMaps: completeRouteMaps,
      accessLists: parsedAcls,
    );
  }
}