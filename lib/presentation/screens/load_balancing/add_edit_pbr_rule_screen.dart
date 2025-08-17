// lib/presentation/screens/load_balancing/add_edit_pbr_rule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/usecases/apply_pbr_rule.dart';
import 'package:load_balance/domain/usecases/edit_pbr_rule.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_event.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart'
    show DataStatus;
import 'package:load_balance/presentation/screens/load_balancing/widgets/pbr_acl_section.dart';
import 'package:load_balance/presentation/screens/load_balancing/widgets/pbr_rule_form_sections.dart';
import 'package:load_balance/injection_container.dart'; // <--- ایمپورت get_it

class AddEditPbrRuleScreen extends StatelessWidget {
  final LBDeviceCredentials? credentials;
  final String? ruleId;
  const AddEditPbrRuleScreen({super.key, this.credentials, this.ruleId});
  @override
  Widget build(BuildContext context) {
    // **تغییر اصلی:** BLoC را مستقیماً از Service Locator می‌خوانیم
    final loadBalancingState = sl<LoadBalancingBloc>().state;
    final isEditing = ruleId != null;
    return BlocProvider(
      create: (context) {
        return PbrRuleFormBloc(
          applyPbrRule: sl<ApplyPbrRule>(),
          editPbrRule: sl<EditPbrRule>(),
          credentials: credentials!,
        )..add(
          FormLoaded(
            interfaces: loadBalancingState.interfaces,
            acls: loadBalancingState.pbrAccessLists,
            routeMaps: loadBalancingState.pbrRouteMaps,
            ruleId: ruleId,
          ),
        );
      },
      child: BlocListener<PbrRuleFormBloc, PbrRuleFormState>(
        listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
        listener: (context, state) {
          if (state.formStatus == DataStatus.success &&
              state.successMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: Colors.green,
                ),
              );
            if (state.submittedRule != null) {
              Navigator.of(context).pop((
                newRule: state.submittedRule!,
                newAcl: state.submittedAcl,
              ));
            }
          } else if (state.formStatus == DataStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEditing ? 'Edit PBR Rule' : 'Add New PBR Rule'),
            actions: [
              BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
                builder: (context, state) {
                  if (state.formStatus == DataStatus.loading) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }
                  return TextButton(
                    onPressed: state.isFormValid
                        ? () => context.read<PbrRuleFormBloc>().add(
                            FormSubmitted(),
                          )
                        : null,
                    child: const Text('SAVE'),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _RuleNameCard(),
                  const SizedBox(height: 16),
                  const PbrAclSection(),
                  const SizedBox(height: 16),
                  const RoutingActionCard(),
                  const SizedBox(height: 16),
                  const ApplyInterfaceCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ... ویجت _RuleNameCard بدون تغییر باقی می‌ماند ...
class _RuleNameCard extends StatefulWidget {
  const _RuleNameCard();
  @override
  State<_RuleNameCard> createState() => _RuleNameCardState();
}

class _RuleNameCardState extends State<_RuleNameCard> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<PbrRuleFormBloc>().state.ruleName,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocListener<PbrRuleFormBloc, PbrRuleFormState>(
          listenWhen: (p, c) => p.ruleName != c.ruleName,
          listener: (context, state) {
            if (_controller.text != state.ruleName) {
              _controller.text = state.ruleName;
            }
          },
          child: BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
            buildWhen: (p, c) =>
                p.ruleNameError != c.ruleNameError ||
                p.isEditing != c.isEditing,
            builder: (context, state) {
              return TextFormField(
                controller: _controller,
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
      ),
    );
  }
}
