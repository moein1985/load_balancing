import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart'; // for DataStatus

enum PbrActionType { nextHop, interface }

class PbrRuleFormState extends Equatable {
  // Overall form status
  final DataStatus formStatus;

  // List of interfaces to populate dropdowns
  final List<RouterInterface> availableInterfaces;

  // -- Form field values --
  final String ruleName;
  final String sourceAddress;
  final String destinationAddress;
  final String protocol;
  final String destinationPort;
  
  final PbrActionType actionType;
  final String nextHop;
  final String egressInterface;

  final String applyToInterface;
  
  final String? errorMessage;
  final String? successMessage;

  const PbrRuleFormState({
    this.formStatus = DataStatus.initial,
    this.availableInterfaces = const [],
    this.ruleName = '',
    this.sourceAddress = 'any',
    this.destinationAddress = 'any',
    this.protocol = 'any',
    this.destinationPort = 'any',
    this.actionType = PbrActionType.nextHop,
    this.nextHop = '',
    this.egressInterface = '',
    this.applyToInterface = '',
    this.errorMessage,
    this.successMessage,
  });

  PbrRuleFormState copyWith({
    DataStatus? formStatus,
    List<RouterInterface>? availableInterfaces,
    String? ruleName,
    String? sourceAddress,
    String? destinationAddress,
    String? protocol,
    String? destinationPort,
    PbrActionType? actionType,
    String? nextHop,
    String? egressInterface,
    String? applyToInterface,
    String? errorMessage,
    String? successMessage,
  }) {
    return PbrRuleFormState(
      formStatus: formStatus ?? this.formStatus,
      availableInterfaces: availableInterfaces ?? this.availableInterfaces,
      ruleName: ruleName ?? this.ruleName,
      sourceAddress: sourceAddress ?? this.sourceAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      protocol: protocol ?? this.protocol,
      destinationPort: destinationPort ?? this.destinationPort,
      actionType: actionType ?? this.actionType,
      nextHop: nextHop ?? this.nextHop,
      egressInterface: egressInterface ?? this.egressInterface,
      applyToInterface: applyToInterface ?? this.applyToInterface,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        formStatus,
        availableInterfaces,
        ruleName,
        sourceAddress,
        destinationAddress,
        protocol,
        destinationPort,
        actionType,
        nextHop,
        egressInterface,
        applyToInterface,
        errorMessage,
        successMessage,
      ];
}