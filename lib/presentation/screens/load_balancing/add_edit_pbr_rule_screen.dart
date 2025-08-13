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
import 'package:load_balance/presentation/screens/load_balancing/widgets/pbr_acl_section.dart';
import 'package:load_balance/presentation/screens/load_balancing/widgets/pbr_rule_form_sections.dart';

import '../../bloc/load_balancing/load_balancing_event.dart';

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
    final loadBalancingState = context.read<LoadBalancingBloc>().state;

    return BlocProvider(
      create: (context) {
        final repository = context.read<RouterRepository>();
        return PbrRuleFormBloc(
          applyPbrRule: ApplyPbrRule(repository),
          credentials: credentials!,
        )..add(FormLoaded(
            interfaces: loadBalancingState.interfaces,
            acls: loadBalancingState.pbrAccessLists,
            routeMaps: loadBalancingState.pbrRouteMaps,
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
            // After success, also refresh the list on the previous screen
            context.read<LoadBalancingBloc>().add(FetchPbrConfigurationRequested());
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
            title: Text(ruleId != null ? 'Edit PBR Rule' : 'Add New PBR Rule'),
            actions: [
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
                  // **بخش جدید برای نام قانون**
                  _RuleNameCard(),
                  SizedBox(height: 16),
                  PbrAclSection(),
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

// **ویجت جدید برای دریافت نام قانون**
class _RuleNameCard extends StatelessWidget {
  const _RuleNameCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
          buildWhen: (p, c) => p.ruleNameError != c.ruleNameError,
          builder: (context, state) {
            return TextFormField(
              decoration: InputDecoration(
                labelText: 'Rule Name (Route-Map Name)',
                hintText: 'e.g., FROM_LAN_TO_ISP2',
                errorText: state.ruleNameError,
              ),
              onChanged: (value) =>
                  context.read<PbrRuleFormBloc>().add(RuleNameChanged(value)),
            );
          },
        ),
      ),
    );
  }
}