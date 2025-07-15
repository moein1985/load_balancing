// domain/entities/router_interface.dart
import 'package:equatable/equatable.dart';

class RouterInterface extends Equatable {
  final String name;
  final String ipAddress;
  final String status;

  const RouterInterface({
    required this.name,
    required this.ipAddress,
    required this.status,
  });

  @override
  List<Object?> get props => [name, ipAddress, status];
}