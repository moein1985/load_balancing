// lib/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/core/utils/validators.dart';
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
  
  // -- Validation Error Messages --
  final String? ruleNameError;
  final String? sourceAddressError;
  final String? destinationAddressError;
  final String? destinationPortError;
  final String? nextHopError;
  
  final String? errorMessage; // General error
  final String? successMessage;

  const PbrRuleFormState({
    this.formStatus = DataStatus.initial,
    this.availableInterfaces = const [],
    // Fields
    this.ruleName = '',
    this.sourceAddress = 'any',
    this.destinationAddress = 'any',
    this.protocol = 'any',
    this.destinationPort = 'any',
    this.actionType = PbrActionType.nextHop,
    this.nextHop = '',
    this.egressInterface = '',
    this.applyToInterface = '',
    // Errors
    this.ruleNameError,
    this.sourceAddressError,
    this.destinationAddressError,
    this.destinationPortError,
    this.nextHopError,
    this.errorMessage,
    this.successMessage,
  });

  /// A getter to determine if the form is valid and can be submitted.
  bool get isFormValid {
    // Check if all value fields are valid according to the validators.
    final isRuleNameValid = FormValidators.notEmpty(ruleName, 'Rule Name') == null;
    final isSourceValid = FormValidators.networkAddress(sourceAddress) == null;
    final isDestinationValid = FormValidators.networkAddress(destinationAddress) == null;
    final isPortValid = FormValidators.port(destinationPort) == null;
    
    // Check action-specific fields
    bool isActionValid = true;
    if (actionType == PbrActionType.nextHop) {
      isActionValid = FormValidators.ip(nextHop) == null;
    } else { // PbrActionType.interface
      isActionValid = egressInterface.isNotEmpty;
    }
    
    // The form is valid if all individual checks pass.
    return isRuleNameValid && isSourceValid && isDestinationValid && isPortValid && isActionValid && applyToInterface.isNotEmpty;
  }

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
    String? ruleNameError,
    String? sourceAddressError,
    String? destinationAddressError,
    String? destinationPortError,
    String? nextHopError,
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
      ruleNameError: ruleNameError,
      sourceAddressError: sourceAddressError,
      destinationAddressError: destinationAddressError,
      destinationPortError: destinationPortError,
      nextHopError: nextHopError,
      errorMessage: errorMessage,
      successMessage: successMessage,
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
        ruleNameError,
        sourceAddressError,
        destinationAddressError,
        destinationPortError,
        nextHopError,
        errorMessage,
        successMessage,
      ];
}