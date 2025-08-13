// lib/domain/entities/access_control_list.dart
import 'package:equatable/equatable.dart';

/// Represents a single entry (a line) in an Access Control List.
class AclEntry extends Equatable {
  final int sequence; // Implicit sequence in the list
  final String permission; // permit or deny
  final String protocol;
  final String source;
  final String destination;
  final String? portCondition; // e.g., "eq 80"

  const AclEntry({
    required this.sequence,
    required this.permission,
    required this.protocol,
    required this.source,
    required this.destination,
    this.portCondition,
  });

  @override
  List<Object?> get props => [sequence, permission, protocol, source, destination, portCondition];

  /// Provides a human-readable summary of the match condition.
  String get summary {
    final parts = [
      '${protocol.toUpperCase()} traffic from',
      source,
      'to',
      destination,
      if (portCondition != null) 'on port ${portCondition!.replaceFirst('eq ', '')}',
    ];
    return parts.join(' ');
  }
}

/// Represents a full Access Control List (e.g., "access-list 101").
class AccessControlList extends Equatable {
  final String id;
  final List<AclEntry> entries;

  const AccessControlList({required this.id, required this.entries});

  @override
  List<Object?> get props => [id, entries];
}