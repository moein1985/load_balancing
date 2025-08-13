// lib/domain/entities/pbr_submission.dart
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/route_map.dart';

/// This class represents the complete payload for creating a new PBR configuration.
/// It contains the route-map to be created and, optionally, a new access-list
/// that needs to be created first.
class PbrSubmission {
  final RouteMap routeMap;
  final AccessControlList? newAcl; // Null if using an existing ACL

  const PbrSubmission({required this.routeMap, this.newAcl});
}