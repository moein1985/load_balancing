// lib/domain/entities/route_map.dart
import 'package:equatable/equatable.dart';

/// Represents the action taken in a route-map entry (e.g., set next-hop).
abstract class RouteMapAction extends Equatable {
  const RouteMapAction();
  String get summary;
}

class SetNextHopAction extends RouteMapAction {
  final List<String> nextHops;
  const SetNextHopAction(this.nextHops);

  @override
  List<Object?> get props => [nextHops];

  @override
  String get summary => 'Route via Gateway(s): ${nextHops.join(', ')}';
}

class SetInterfaceAction extends RouteMapAction {
  final List<String> interfaces;
  const SetInterfaceAction(this.interfaces);

  @override
  List<Object?> get props => [interfaces];

  @override
  String get summary => 'Route via Interface(s): ${interfaces.join(', ')}';
}


/// Represents a single entry in a Route-Map (e.g., "permit 10").
class RouteMapEntry extends Equatable {
  final String permission; // permit or deny
  final int sequence;
  final String? matchAclId;
  final RouteMapAction? action;

  const RouteMapEntry({
    required this.permission,
    required this.sequence,
    this.matchAclId,
    this.action,
  });

  @override
  List<Object?> get props => [permission, sequence, matchAclId, action];
}


/// Represents a full Route-Map with its entries.
class RouteMap extends Equatable {
  final String name;
  final List<RouteMapEntry> entries;
  
  // This field will be populated after parsing interfaces.
  final String? appliedToInterface;

  const RouteMap({
    required this.name,
    required this.entries,
    this.appliedToInterface,
  });

  @override
  List<Object?> get props => [name, entries, appliedToInterface];
  
  RouteMap copyWith({String? appliedToInterface}) {
    return RouteMap(
      name: name,
      entries: entries,
      appliedToInterface: appliedToInterface ?? this.appliedToInterface,
    );
  }

  
}