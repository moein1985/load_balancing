import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';

abstract class PbrRuleFormEvent extends Equatable {
  const PbrRuleFormEvent();
  @override
  List<Object?> get props => [];
}

/// This event is dispatched when the form opens to pass the initial data.
class FormLoaded extends PbrRuleFormEvent {
  final List<RouterInterface> interfaces; // Changed from DeviceCredentials
  final String? ruleId; // For edit mode

  const FormLoaded({required this.interfaces, this.ruleId});

  @override
  List<Object?> get props => [interfaces, ruleId];
}

/// Events for when each form field changes.
class RuleNameChanged extends PbrRuleFormEvent {
  final String value;
  const RuleNameChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class SourceAddressChanged extends PbrRuleFormEvent {
  final String value;
  const SourceAddressChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class DestinationAddressChanged extends PbrRuleFormEvent {
  final String value;
  const DestinationAddressChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class ProtocolChanged extends PbrRuleFormEvent {
  final String value;
  const ProtocolChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class DestinationPortChanged extends PbrRuleFormEvent {
  final String value;
  const DestinationPortChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class ActionTypeChanged extends PbrRuleFormEvent {
  final PbrActionType value;
  const ActionTypeChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class NextHopChanged extends PbrRuleFormEvent {
  final String value;
  const NextHopChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class EgressInterfaceChanged extends PbrRuleFormEvent {
  final String value;
  const EgressInterfaceChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class ApplyToInterfaceChanged extends PbrRuleFormEvent {
  final String value;
  const ApplyToInterfaceChanged(this.value);
  @override
  List<Object?> get props => [value];
}

/// Event for when the user presses the 'SAVE' button.
class FormSubmitted extends PbrRuleFormEvent {}