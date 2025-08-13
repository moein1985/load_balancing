// lib/presentation/screens/load_balancing/widgets/pbr_acl_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_event.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';
import '../../../../domain/entities/access_control_list.dart';

class PbrAclSection extends StatelessWidget {
  const PbrAclSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Section 1: Identify Traffic (Access Control List)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
              buildWhen: (p, c) => p.aclMode != c.aclMode,
              builder: (context, state) {
                return SegmentedButton<AclSelectionMode>(
                  segments: const [
                    ButtonSegment(
                      value: AclSelectionMode.createNew,
                      label: Text('Create New ACL'),
                    ),
                    ButtonSegment(
                      value: AclSelectionMode.selectExisting,
                      label: Text('Select Existing ACL'),
                    ),
                  ],
                  selected: {state.aclMode},
                  onSelectionChanged: (selection) => context
                      .read<PbrRuleFormBloc>()
                      .add(AclModeChanged(selection.first)),
                );
              },
            ),
            const SizedBox(height: 16),
            BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
              builder: (context, state) {
                if (state.aclMode == AclSelectionMode.createNew) {
                  return _CreateNewAclForm();
                } else {
                  return _SelectExistingAclForm();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateNewAclForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PbrRuleFormBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
          buildWhen: (p, c) => p.newAclIdError != c.newAclIdError,
          builder: (context, state) {
            return TextFormField(
              initialValue: state.newAclId,
              decoration: InputDecoration(
                labelText: 'New ACL Number (e.g., 101-199)',
                errorText: state.newAclIdError,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => bloc.add(NewAclIdChanged(value)),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('ACL Entries:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
          buildWhen: (p, c) => p.newAclEntries != c.newAclEntries,
          builder: (context, state) {
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.newAclEntries.length,
              itemBuilder: (context, index) {
                return _AclEntryEditor(
                  key: ValueKey('acl_entry_$index'),
                  entry: state.newAclEntries[index],
                  index: index,
                  isRemovable: state.newAclEntries.length > 1,
                );
              },
              separatorBuilder: (_, _) => const Divider(height: 24),
            );
          },
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Entry'),
          onPressed: () => bloc.add(NewAclEntryAdded()),
        ),
      ],
    );
  }
}

class _SelectExistingAclForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
      builder: (context, state) {
        if (state.existingAcls.isEmpty) {
          return const Text(
            'No existing standard or extended ACLs found on the router.',
          );
        }
        return DropdownButtonFormField<String>(
          value: state.selectedAclId,
          decoration: const InputDecoration(
            labelText: 'Select an Access Control List',
          ),
          items: state.existingAcls
              .map(
                (acl) => DropdownMenuItem(
                  value: acl.id,
                  child: Text('ACL ${acl.id} (${acl.entries.length} entries)'),
                ),
              )
              .toList(),
          onChanged: (value) =>
              context.read<PbrRuleFormBloc>().add(ExistingAclSelected(value)),
        );
      },
    );
  }
}

class _AclEntryEditor extends StatelessWidget {
  final AclEntry entry;
  final int index;
  final bool isRemovable;

  const _AclEntryEditor({
    super.key,
    required this.entry,
    required this.index,
    this.isRemovable = false,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PbrRuleFormBloc>();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Entry #${index + 1}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (isRemovable)
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                ),
                onPressed: () => bloc.add(NewAclEntryRemoved(index)),
              ),
          ],
        ),
        TextFormField(
          initialValue: entry.source,
          // **متن راهنما اصلاح شد**
          decoration: const InputDecoration(
            labelText: 'Source Address',
            hintText: 'any, 1.1.1.1, or 1.1.1.0 0.0.0.255',
          ),
          onChanged: (value) => bloc.add(
            NewAclEntryChanged(index, entry.copyWith(source: value)),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: entry.destination,
          // **متن راهنما اصلاح شد**
          decoration: const InputDecoration(
            labelText: 'Destination Address',
            hintText: 'any, 2.2.2.2, or 2.2.2.0 0.0.0.255',
          ),
          onChanged: (value) => bloc.add(
            NewAclEntryChanged(index, entry.copyWith(destination: value)),
          ),
        ),
      ],
    );
  }
}

// Helper on AclEntry entity needed for copyWith
extension AclEntryCopy on AclEntry {
  AclEntry copyWith({
    int? sequence,
    String? permission,
    String? protocol,
    String? source,
    String? destination,
    String? portCondition,
  }) {
    return AclEntry(
      sequence: sequence ?? this.sequence,
      permission: permission ?? this.permission,
      protocol: protocol ?? this.protocol,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      portCondition: portCondition ?? this.portCondition,
    );
  }
}
