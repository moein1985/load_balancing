// lib/presentation/bloc/pbr_rule_form/pbr_rule_form_event.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'pbr_rule_form_state.dart';

abstract class PbrRuleFormEvent extends Equatable {
  const PbrRuleFormEvent();
  @override
  List<Object?> get props => [];
}

/// Dispatched when the form opens to pass initial data.
class FormLoaded extends PbrRuleFormEvent {
  final List<RouterInterface> interfaces;
  final List<AccessControlList> acls;
  final List<RouteMap> routeMaps;
  final String? ruleId; // For edit mode

  const FormLoaded({
    required this.interfaces,
    required this.acls,
    required this.routeMaps,
    this.ruleId,
  });

  @override
  List<Object?> get props => [interfaces, acls, routeMaps, ruleId];
}

// --- ACL Management Events ---
class AclModeChanged extends PbrRuleFormEvent {
  final AclSelectionMode mode;
  const AclModeChanged(this.mode);
  @override
  List<Object> get props => [mode];
}

class ExistingAclSelected extends PbrRuleFormEvent {
  final String? aclId;
  const ExistingAclSelected(this.aclId);
  @override
  List<Object?> get props => [aclId];
}

class NewAclIdChanged extends PbrRuleFormEvent {
  final String id;
  const NewAclIdChanged(this.id);
  @override
  List<Object> get props => [id];
}

class NewAclEntryChanged extends PbrRuleFormEvent {
  final int index;
  final AclEntry entry;
  const NewAclEntryChanged(this.index, this.entry);
   @override
  List<Object> get props => [index, entry];
}

class NewAclEntryAdded extends PbrRuleFormEvent {}

class NewAclEntryRemoved extends PbrRuleFormEvent {
  final int index;
  const NewAclEntryRemoved(this.index);
  @override
  List<Object> get props => [index];
}


// --- Route-Map Management Events ---
class RuleNameChanged extends PbrRuleFormEvent {
  final String value;
  const RuleNameChanged(this.value);
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