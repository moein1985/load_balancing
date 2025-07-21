//lib/domain/entities/pbr_rule.dart

import 'package:equatable/equatable.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';

class PbrRule extends Equatable {
  final String ruleName;
  final String sourceAddress;
  final String destinationAddress;
  final String protocol;
  final String destinationPort;
  final PbrActionType actionType;
  final String nextHop;
  final String egressInterface;
  final String applyToInterface;

  const PbrRule({
    required this.ruleName,
    required this.sourceAddress,
    required this.destinationAddress,
    required this.protocol,
    required this.destinationPort,
    required this.actionType,
    required this.nextHop,
    required this.egressInterface,
    required this.applyToInterface,
  });

  @override
  List<Object?> get props => [
        ruleName,
        sourceAddress,
        destinationAddress,
        protocol,
        destinationPort,
        actionType,
        nextHop,
        egressInterface,
        applyToInterface,
      ];
}