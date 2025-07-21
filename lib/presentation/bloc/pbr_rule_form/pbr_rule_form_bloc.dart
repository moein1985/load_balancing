import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/domain/usecases/apply_pbr_rule.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';
import 'pbr_rule_form_event.dart';
import 'pbr_rule_form_state.dart';

class PbrRuleFormBloc extends Bloc<PbrRuleFormEvent, PbrRuleFormState> {
  final ApplyPbrRule applyPbrRule; 
  final DeviceCredentials credentials; 
  PbrRuleFormBloc({required this.applyPbrRule, required this.credentials}) : super(const PbrRuleFormState()) {
    on<FormLoaded>(_onFormLoaded);
    on<RuleNameChanged>((event, emit) => emit(state.copyWith(ruleName: event.value)));
    on<SourceAddressChanged>((event, emit) => emit(state.copyWith(sourceAddress: event.value)));
    on<DestinationAddressChanged>((event, emit) => emit(state.copyWith(destinationAddress: event.value)));
    on<ProtocolChanged>((event, emit) => emit(state.copyWith(protocol: event.value)));
    on<DestinationPortChanged>((event, emit) => emit(state.copyWith(destinationPort: event.value)));
    on<ActionTypeChanged>((event, emit) => emit(state.copyWith(actionType: event.value)));
    on<NextHopChanged>((event, emit) => emit(state.copyWith(nextHop: event.value)));
    on<EgressInterfaceChanged>((event, emit) => emit(state.copyWith(egressInterface: event.value)));
    on<ApplyToInterfaceChanged>((event, emit) => emit(state.copyWith(applyToInterface: event.value)));
    on<FormSubmitted>(_onFormSubmitted);
    
  }

  /// This handler is now much simpler. It just takes the pre-fetched list
  /// of interfaces and populates the state. No network call is made.
  void _onFormLoaded(FormLoaded event, Emitter<PbrRuleFormState> emit) {
    // In edit mode, we would also load the existing rule data here.
    // For now, we just populate the dropdowns.
    emit(state.copyWith(
      formStatus: DataStatus.success,
      availableInterfaces: event.interfaces,
      // Set initial values for the dropdowns with the first available interface.
      egressInterface: event.interfaces.isNotEmpty ? event.interfaces.first.name : '',
      applyToInterface: event.interfaces.isNotEmpty ? event.interfaces.first.name : '',
    ));
  }

  Future<void> _onFormSubmitted(FormSubmitted event, Emitter<PbrRuleFormState> emit) async {
    emit(state.copyWith(formStatus: DataStatus.loading));

    // TODO: اعتبارسنجی کامل فیلدها
    if (state.ruleName.isEmpty) {
      emit(state.copyWith(formStatus: DataStatus.failure, errorMessage: 'Rule Name cannot be empty.'));
      return;
    }

    final newRule = PbrRule(
      ruleName: state.ruleName,
      sourceAddress: state.sourceAddress,
      destinationAddress: state.destinationAddress,
      protocol: state.protocol,
      destinationPort: state.destinationPort,
      actionType: state.actionType,
      nextHop: state.nextHop,
      egressInterface: state.egressInterface,
      applyToInterface: state.applyToInterface,
    );

    try {
      final result = await applyPbrRule(credentials: credentials, rule: newRule);
      emit(state.copyWith(formStatus: DataStatus.success, successMessage: result));
    } catch (e) {
      emit(state.copyWith(formStatus: DataStatus.failure, errorMessage: e.toString()));
    }
  }
}