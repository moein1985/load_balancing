// lib/presentation/screens/load_balancing/widgets/pbr_rule_list_item.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';

class PbrRuleListItem extends StatelessWidget {
  final String ruleName;
  final String matchCondition;
  final String action;

  const PbrRuleListItem({
    super.key,
    required this.ruleName,
    required this.matchCondition,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ruleName, style: textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              icon: Icons.filter_alt_outlined,
              title: 'Match:',
              value: matchCondition,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              icon: Icons.alt_route_outlined,
              title: 'Action:',
              value: action,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Rule',
                  onPressed: () {
                    final credentials = context
                        .read<LoadBalancingBloc>()
                        .state
                        .credentials;
                    if (credentials != null) {
                      context.pushNamed(
                        'edit_pbr_rule',
                        pathParameters: {'ruleId': ruleName},
                        extra:
                            credentials, 
                      );
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                  tooltip: 'Delete Rule',
                  onPressed: () {
                    // TODO: Show delete confirmation dialog
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Expanded(child: Text(value, style: textTheme.bodyMedium)),
      ],
    );
  }
}
