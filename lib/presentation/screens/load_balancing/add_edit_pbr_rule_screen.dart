// lib/presentation/screens/load_balancing/add_edit_pbr_rule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/repositories/router_repository.dart';
import 'package:load_balance/domain/usecases/apply_pbr_rule.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_event.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart' show DataStatus;
import 'widgets/pbr_rule_form_sections.dart';

class AddEditPbrRuleScreen extends StatelessWidget {
  final LBDeviceCredentials? credentials;
  final String? ruleId;

  const AddEditPbrRuleScreen({
    super.key,
    this.credentials,
    this.ruleId,
  });

  @override
  Widget build(BuildContext context) {
    final existingInterfaces = context.read<LoadBalancingBloc>().state.interfaces;

    return BlocProvider(
      create: (context) {
        final repository = context.read<RouterRepository>();
        return PbrRuleFormBloc(
          applyPbrRule: ApplyPbrRule(repository),
          credentials: credentials!,
        )..add(FormLoaded(
            interfaces: existingInterfaces,
            ruleId: ruleId,
          ));
      },
      child: BlocListener<PbrRuleFormBloc, PbrRuleFormState>(
        listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
        listener: (context, state) {
          if (state.formStatus == DataStatus.success && state.successMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ));
            Navigator.of(context).pop();
          } else if (state.formStatus == DataStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ));
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(ruleId != null ? 'Edit: $ruleId' : 'Add New PBR Rule'),
            actions: [
              // *** بهبود UX: دکمه SAVE فقط در صورت معتبر بودن فرم فعال است ***
              BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
                builder: (context, state) {
                  if (state.formStatus == DataStatus.loading) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    );
                  }
                  return TextButton(
                    // با استفاده از isFormValid دکمه را فعال/غیرفعال می‌کنیم
                    onPressed: state.isFormValid
                        ? () => context.read<PbrRuleFormBloc>().add(FormSubmitted())
                        : null,
                    child: const Text('SAVE'),
                  );
                },
              ),
            ],
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TrafficMatchCard(),
                  SizedBox(height: 16),
                  RoutingActionCard(),
                  SizedBox(height: 16),
                  ApplyInterfaceCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}