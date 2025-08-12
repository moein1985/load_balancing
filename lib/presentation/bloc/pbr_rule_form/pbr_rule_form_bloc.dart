// lib/presentation/bloc/pbr_rule_form/pbr_rule_form_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/core/utils/validators.dart'; // ابزار جدید را وارد می‌کنیم
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_rule.dart';
import 'package:load_balance/domain/usecases/apply_pbr_rule.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';
import 'pbr_rule_form_event.dart';
import 'pbr_rule_form_state.dart';

class PbrRuleFormBloc extends Bloc<PbrRuleFormEvent, PbrRuleFormState> {
  final ApplyPbrRule applyPbrRule;
  final LBDeviceCredentials credentials;

  PbrRuleFormBloc({required this.applyPbrRule, required this.credentials})
      : super(const PbrRuleFormState()) {
    on<FormLoaded>(_onFormLoaded);
    // تمام event handler ها برای اعتبارسنجی بازنویسی می‌شوند
    on<RuleNameChanged>(_onRuleNameChanged);
    on<SourceAddressChanged>(_onSourceAddressChanged);
    on<DestinationAddressChanged>(_onDestinationAddressChanged);
    on<ProtocolChanged>((event, emit) => emit(state.copyWith(protocol: event.value)));
    on<DestinationPortChanged>(_onDestinationPortChanged);
    on<ActionTypeChanged>(_onActionTypeChanged);
    on<NextHopChanged>(_onNextHopChanged);
    on<EgressInterfaceChanged>((event, emit) => emit(state.copyWith(egressInterface: event.value)));
    on<ApplyToInterfaceChanged>((event, emit) => emit(state.copyWith(applyToInterface: event.value)));
    on<FormSubmitted>(_onFormSubmitted);
  }

  void _onFormLoaded(FormLoaded event, Emitter<PbrRuleFormState> emit) {
    emit(state.copyWith(
      formStatus: DataStatus.success,
      availableInterfaces: event.interfaces,
      egressInterface: event.interfaces.isNotEmpty ? event.interfaces.first.name : '',
      applyToInterface: event.interfaces.isNotEmpty ? event.interfaces.first.name : '',
    ));
  }

  void _onRuleNameChanged(RuleNameChanged event, Emitter<PbrRuleFormState> emit) {
    emit(state.copyWith(
      ruleName: event.value,
      ruleNameError: FormValidators.notEmpty(event.value, 'Rule Name'),
    ));
  }

  void _onSourceAddressChanged(SourceAddressChanged event, Emitter<PbrRuleFormState> emit) {
    emit(state.copyWith(
      sourceAddress: event.value,
      sourceAddressError: FormValidators.networkAddress(event.value),
    ));
  }

  void _onDestinationAddressChanged(DestinationAddressChanged event, Emitter<PbrRuleFormState> emit) {
    emit(state.copyWith(
      destinationAddress: event.value,
      destinationAddressError: FormValidators.networkAddress(event.value),
    ));
  }

  void _onDestinationPortChanged(DestinationPortChanged event, Emitter<PbrRuleFormState> emit) {
    emit(state.copyWith(
      destinationPort: event.value,
      destinationPortError: FormValidators.port(event.value),
    ));
  }
  
  void _onActionTypeChanged(ActionTypeChanged event, Emitter<PbrRuleFormState> emit) {
    // هنگام تغییر نوع action، خطای فیلد دیگر را پاک می‌کنیم
    if (event.value == PbrActionType.nextHop) {
      emit(state.copyWith(actionType: event.value));
    } else { // interface
      emit(state.copyWith(actionType: event.value, nextHopError: null));
    }
  }

  void _onNextHopChanged(NextHopChanged event, Emitter<PbrRuleFormState> emit) {
    emit(state.copyWith(
      nextHop: event.value,
      nextHopError: FormValidators.ip(event.value),
    ));
  }

  Future<void> _onFormSubmitted(FormSubmitted event, Emitter<PbrRuleFormState> emit) async {
    // قبل از ارسال، یک بار دیگر تمام اعتبارسنجی‌ها را اجرا می‌کنیم
    final nameError = FormValidators.notEmpty(state.ruleName, 'Rule Name');
    final sourceError = FormValidators.networkAddress(state.sourceAddress);
    final destError = FormValidators.networkAddress(state.destinationAddress);
    final portError = FormValidators.port(state.destinationPort);
    final nextHopError = state.actionType == PbrActionType.nextHop ? FormValidators.ip(state.nextHop) : null;
    
    emit(state.copyWith(
      ruleNameError: nameError,
      sourceAddressError: sourceError,
      destinationAddressError: destError,
      destinationPortError: portError,
      nextHopError: nextHopError,
    ));

    // اگر فرم معتبر بود، آن را ارسال می‌کنیم
    if (state.isFormValid) {
      emit(state.copyWith(formStatus: DataStatus.loading));
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
    } else {
      emit(state.copyWith(formStatus: DataStatus.failure, errorMessage: 'Please correct the errors in the form.'));
    }
  }
}