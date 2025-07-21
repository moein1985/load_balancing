// lib/presentation/screens/load_balancing/widgets/pbr_rule_form_sections.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_event.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';

// -- Section 1: Widget for identifying traffic --
class TrafficMatchCard extends StatelessWidget {
  const TrafficMatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Section 1: Identify Traffic', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Rule Name', hintText: 'e.g., Finance_Web_Traffic'),
              onChanged: (value) => context.read<PbrRuleFormBloc>().add(RuleNameChanged(value)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Source IP Address', hintText: 'e.g., 192.168.10.0/24 or "any"'),
              initialValue: 'any',
              onChanged: (value) => context.read<PbrRuleFormBloc>().add(SourceAddressChanged(value)),
            ),
            const SizedBox(height: 16),
            // TODO: Add onChanged for other text fields like Destination Address and Port
            TextFormField(
              decoration: const InputDecoration(labelText: 'Destination IP Address', hintText: 'e.g., 8.8.8.8 or "any"'),
              initialValue: 'any',
            ),
            const SizedBox(height: 16),
            BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
              buildWhen: (p, c) => p.protocol != c.protocol,
              builder: (context, state) {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Protocol'),
                  value: state.protocol,
                  items: ['any', 'tcp', 'udp', 'icmp']
                      .map((label) => DropdownMenuItem(value: label, child: Text(label.toUpperCase())))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<PbrRuleFormBloc>().add(ProtocolChanged(value));
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Destination Port (for TCP/UDP)', hintText: 'e.g., 443 or "any"'),
              initialValue: 'any',
            ),
          ],
        ),
      ),
    );
  }
}

// -- Section 2: Widget for the routing action --
class RoutingActionCard extends StatelessWidget {
  const RoutingActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
          builder: (context, state) {
            if (state.formStatus == DataStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextFormField(
                    enabled: state.actionType == PbrActionType.nextHop,
                    decoration: const InputDecoration(labelText: 'Gateway IP Address', hintText: 'e.g., 192.168.2.1'),
                    onChanged: (value) => bloc.add(NextHopChanged(value)),
                  ),
                ),
                RadioListTile<PbrActionType>(
                  title: const Text('Set Egress Interface'),
                  value: PbrActionType.interface,
                  groupValue: state.actionType,
                  onChanged: (value) => bloc.add(ActionTypeChanged(value!)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonFormField<String>(
                    value: state.egressInterface.isNotEmpty ? state.egressInterface : null,
                    decoration: const InputDecoration(labelText: 'Interface'),
                    items: interfaceItems,
                    // **تغییر اصلی در اینجا است**
                    // با null کردن onChanged، ویجت به طور خودکار غیرفعال میشود
                    onChanged: state.actionType == PbrActionType.interface
                        ? (value) {
                            if (value != null) bloc.add(EgressInterfaceChanged(value));
                          }
                        : null,
                  ),
                ),
              ],
            );
          },
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
            if (state.formStatus == DataStatus.loading) {
              return const SizedBox(height: 50); // Placeholder for loading
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