// lib/presentation/bloc/pbr_rule_form/pbr_rule_form_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/core/utils/validators.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/pbr_submission.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart' show DataStatus;
import '../../../domain/entities/lb_device_credentials.dart';
import '../../../domain/usecases/apply_pbr_rule.dart';
import 'pbr_rule_form_event.dart';
import 'pbr_rule_form_state.dart';

class PbrRuleFormBloc extends Bloc<PbrRuleFormEvent, PbrRuleFormState> {
  final ApplyPbrRule applyPbrRule;
  final LBDeviceCredentials credentials;

  PbrRuleFormBloc({required this.applyPbrRule, required this.credentials})
      : super(const PbrRuleFormState()) {
    on<FormLoaded>(_onFormLoaded);
    on<AclModeChanged>(_onAclModeChanged);
    on<ExistingAclSelected>(_onExistingAclSelected);
    on<NewAclIdChanged>(_onNewAclIdChanged);
    on<NewAclEntryChanged>(_onNewAclEntryChanged);
    on<NewAclEntryAdded>(_onNewAclEntryAdded);
    on<NewAclEntryRemoved>(_onNewAclEntryRemoved);
    on<RuleNameChanged>(_onRuleNameChanged);
    on<ActionTypeChanged>(_onActionTypeChanged);
    on<NextHopChanged>(_onNextHopChanged);
    on<EgressInterfaceChanged>(
      (event, emit) => emit(state.copyWith(egressInterface: event.value)),
    );
    on<ApplyToInterfaceChanged>(
      (event, emit) => emit(state.copyWith(applyToInterface: event.value)),
    );
    on<FormSubmitted>(_onFormSubmitted);
  }

  void _onFormLoaded(FormLoaded event, Emitter<PbrRuleFormState> emit) {
    if (event.ruleId == null) {
      // Create new mode
      emit(
        state.copyWith(
          formStatus: DataStatus.success,
          availableInterfaces: event.interfaces,
          existingAcls: event.acls,
          existingRouteMaps: event.routeMaps,
          egressInterface: event.interfaces.isNotEmpty
              ? event.interfaces.first.name
              : '',
          applyToInterface: event.interfaces.isNotEmpty
              ? event.interfaces.first.name
              : '',
        ),
      );
    } else {
      // Edit mode logic
      final ruleToEdit = event.routeMaps.firstWhere(
        (rm) => rm.name == event.ruleId,
      );
      final associatedAcl = event.acls.firstWhere(
        (acl) => acl.id == ruleToEdit.entries.first.matchAclId,
        // Provide a fallback in case the ACL is missing
        orElse: () => const AccessControlList(id: 'unknown', entries: []),
      );

      final action = ruleToEdit.entries.first.action;
      final actionType = action is SetNextHopAction
          ? PbrActionType.nextHop
          : PbrActionType.interface;
      final nextHop = action is SetNextHopAction ? action.nextHops.first : '';
      final egressInterface = action is SetInterfaceAction
          ? action.interfaces.first
          : (event.interfaces.isNotEmpty ? event.interfaces.first.name : '');

      emit(
        state.copyWith(
          availableInterfaces: event.interfaces,
          existingAcls: event.acls,
          existingRouteMaps: event.routeMaps,
          ruleName: ruleToEdit.name,
          aclMode: AclSelectionMode.selectExisting,
          selectedAclId: associatedAcl.id,
          actionType: actionType,
          nextHop: nextHop,
          egressInterface: egressInterface,
          applyToInterface: ruleToEdit.appliedToInterface ?? '',
        ),
      );
    }
  }

  void _onAclModeChanged(AclModeChanged event, Emitter<PbrRuleFormState> emit) {
    emit(state.copyWith(aclMode: event.mode));
  }

  void _onExistingAclSelected(
    ExistingAclSelected event,
    Emitter<PbrRuleFormState> emit,
  ) {
    emit(state.copyWith(selectedAclId: event.aclId));
  }

  void _onNewAclIdChanged(
    NewAclIdChanged event,
    Emitter<PbrRuleFormState> emit,
  ) {
    final id = event.id;
    String? error;
    if (id.isEmpty) {
      error = 'ACL number cannot be empty.';
    } else if (int.tryParse(id) == null) {
      error = 'Must be a number.';
    } else if (state.existingAcls.any((acl) => acl.id == id)) {
      error = 'This ACL number already exists.';
    }
    emit(state.copyWith(newAclId: id, newAclIdError: error));
  }
  
  void _onNewAclEntryChanged(
    NewAclEntryChanged event,
    Emitter<PbrRuleFormState> emit,
  ) {
    final entries = List<AclEntry>.from(state.newAclEntries);
    entries[event.index] = event.entry;
    emit(state.copyWith(newAclEntries: entries));
  }

  void _onNewAclEntryAdded(
    NewAclEntryAdded event,
    Emitter<PbrRuleFormState> emit,
  ) {
    final entries = List<AclEntry>.from(state.newAclEntries);
    entries.add(
      const AclEntry(
        sequence: 1,
        permission: 'permit',
        protocol: 'ip',
        source: 'any',
        destination: 'any',
      ),
    );
    emit(state.copyWith(newAclEntries: entries));
  }

  void _onNewAclEntryRemoved(
    NewAclEntryRemoved event,
    Emitter<PbrRuleFormState> emit,
  ) {
    final entries = List<AclEntry>.from(state.newAclEntries);
    if (entries.length > 1) {
      entries.removeAt(event.index);
      emit(state.copyWith(newAclEntries: entries));
    }
  }

  void _onRuleNameChanged(
    RuleNameChanged event,
    Emitter<PbrRuleFormState> emit,
  ) {
    final name = event.value;
    String? error;
    if (name.isEmpty) {
      error = 'Rule name cannot be empty.';
    } else if (state.existingRouteMaps.any((rm) => rm.name == name)) {
      error = 'This rule name already exists.';
    }
    emit(state.copyWith(ruleName: name, ruleNameError: error));
  }

  void _onActionTypeChanged(
    ActionTypeChanged event,
    Emitter<PbrRuleFormState> emit,
  ) {
    emit(state.copyWith(actionType: event.value, nextHopError: null));
  }

  void _onNextHopChanged(NextHopChanged event, Emitter<PbrRuleFormState> emit) {
    emit(
      state.copyWith(
        nextHop: event.value,
        nextHopError: FormValidators.ip(event.value),
      ),
    );
  }

  Future<void> _onFormSubmitted(
    FormSubmitted event,
    Emitter<PbrRuleFormState> emit,
  ) async {
    if (!state.isFormValid) {
      emit(
        state.copyWith(
          formStatus: DataStatus.failure,
          errorMessage: 'Please correct the errors in the form.',
        ),
      );
      return;
    }

    emit(state.copyWith(formStatus: DataStatus.loading));
    
    AccessControlList? newAcl;
    String aclIdToMatch;

    if (state.aclMode == AclSelectionMode.createNew) {
      aclIdToMatch = state.newAclId;
      newAcl = AccessControlList(
        id: aclIdToMatch,
        entries: state.newAclEntries,
      );
    } else {
      aclIdToMatch = state.selectedAclId!;
    }

    final action = state.actionType == PbrActionType.nextHop
        ? SetNextHopAction([state.nextHop])
        : SetInterfaceAction([state.egressInterface]);
    
    // **FIX APPLIED HERE:**
    // The `appliedToInterface` now correctly uses the value from the form state.
    final routeMap = RouteMap(
      name: state.ruleName,
      appliedToInterface: state.applyToInterface,
      entries: [
        RouteMapEntry(
          permission: 'permit',
          sequence: 10,
          matchAclId: aclIdToMatch,
          action: action,
        ),
      ],
    );

    final submission = PbrSubmission(routeMap: routeMap, newAcl: newAcl);

    try {
      final result = await applyPbrRule(
        credentials: credentials,
        submission: submission,
      );
      emit(
        state.copyWith(formStatus: DataStatus.success, successMessage: result),
      );
    } catch (e) {
      emit(
        state.copyWith(
          formStatus: DataStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}