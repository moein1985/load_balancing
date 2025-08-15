// lib/presentation/screens/load_balancing/widgets/pbr_rule_form_sections.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_event.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';
import '../../../bloc/load_balancing/load_balancing_state.dart';

// -- Section 2: Widget for the routing action --
class RoutingActionCard extends StatefulWidget {
  const RoutingActionCard({super.key});

  @override
  State<RoutingActionCard> createState() => _RoutingActionCardState();
}

class _RoutingActionCardState extends State<RoutingActionCard> {
  late final TextEditingController _nextHopController;

  @override
  void initState() {
    super.initState();
    _nextHopController = TextEditingController(
      text: context.read<PbrRuleFormBloc>().state.nextHop,
    );
  }

  @override
  void dispose() {
    _nextHopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocListener<PbrRuleFormBloc, PbrRuleFormState>(
          listenWhen: (p, c) => p.nextHop != c.nextHop,
          listener: (context, state) {
            if (_nextHopController.text != state.nextHop) {
              _nextHopController.text = state.nextHop;
            }
          },
          child: BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
            builder: (context, state) {
              final bloc = context.read<PbrRuleFormBloc>();
              final interfaceItems = state.availableInterfaces
                  .map((iface) => DropdownMenuItem(value: iface.name, child: Text(iface.name)))
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Section 2: Define Action', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  RadioListTile<PbrActionType>(
                    title: const Text('Set Next-Hop Gateway'),
                    value: PbrActionType.nextHop,
                    groupValue: state.actionType,
                    onChanged: (value) => bloc.add(ActionTypeChanged(value!)),
                  ),
                  RadioListTile<PbrActionType>(
                    title: const Text('Set Egress Interface'),
                    value: PbrActionType.interface,
                    groupValue: state.actionType,
                    onChanged: (value) => bloc.add(ActionTypeChanged(value!)),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: state.actionType == PbrActionType.nextHop
                        ? Padding(
                            key: const ValueKey('nextHop'),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
                               buildWhen: (p, c) => p.nextHopError != c.nextHopError,
                              builder: (context, state) {
                                return TextFormField(
                                  controller: _nextHopController,
                                  decoration: InputDecoration(
                                    labelText: 'Gateway IP Address',
                                    hintText: 'e.g., 192.168.2.1',
                                    errorText: state.nextHopError,
                                  ),
                                  onChanged: (value) => bloc.add(NextHopChanged(value)),
                                );
                              },
                            ),
                          )
                        : Padding(
                            key: const ValueKey('egressInterface'),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: DropdownButtonFormField<String>(
                              value: state.egressInterface.isNotEmpty ? state.egressInterface : null,
                              decoration: const InputDecoration(labelText: 'Interface'),
                              items: interfaceItems,
                              onChanged: (value) {
                                if (value != null) bloc.add(EgressInterfaceChanged(value));
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// -- Section 3: Widget for applying to an interface --
class ApplyInterfaceCard extends StatelessWidget {
  const ApplyInterfaceCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
          builder: (context, state) {
            if (state.formStatus == DataStatus.initial && state.availableInterfaces.isEmpty) {
              return const Center(child: Text("Loading interfaces..."));
            }

            final bloc = context.read<PbrRuleFormBloc>();
            final interfaceItems = state.availableInterfaces
                .map((iface) => DropdownMenuItem(value: iface.name, child: Text(iface.name)))
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Section 3: Apply Policy', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: state.applyToInterface.isNotEmpty ? state.applyToInterface : null,
                  decoration: const InputDecoration(
                    labelText: 'Apply to Inbound Traffic on Interface',
                    border: OutlineInputBorder(),
                  ),
                  items: interfaceItems,
                  onChanged: (value) {
                    if (value != null) bloc.add(ApplyToInterfaceChanged(value));
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}