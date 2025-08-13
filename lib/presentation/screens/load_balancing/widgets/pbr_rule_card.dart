// lib/presentation/screens/load_balancing/widgets/pbr_rule_card.dart
import 'package:flutter/material.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/route_map.dart';

class PbrRuleCard extends StatelessWidget {
  final RouteMap routeMap;
  final List<AccessControlList> allAcls;

  const PbrRuleCard({
    super.key,
    required this.routeMap,
    required this.allAcls,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routeMap.name, style: textTheme.titleLarge),
                if (routeMap.appliedToInterface != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Applied to: ${routeMap.appliedToInterface}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.primary),
                    ),
                  ),
                const SizedBox(height: 16),
                ..._buildEntryWidgets(context),
              ],
            ),
          ),
          Container(
            color: colorScheme.onSurface.withAlpha(26), // Corrected from withOpacity
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Rule',
                  onPressed: () { /* TODO: Implement Edit */ },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  tooltip: 'Delete Rule',
                  onPressed: () { /* TODO: Implement Delete */ },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEntryWidgets(BuildContext context) {
    final widgets = <Widget>[];
    for (final entry in routeMap.entries) {
      final acl = allAcls.firstWhere(
        (acl) => acl.id == entry.matchAclId,
        orElse: () => const AccessControlList(id: 'Unknown', entries: []),
      );

      widgets.add(
        _buildInfoRow(
          context,
          icon: Icons.filter_alt_outlined,
          title: 'Match (#${entry.sequence}):',
          value: acl.entries.map((e) => e.summary).join('\n'),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        _buildInfoRow(
          context,
          icon: Icons.alt_route_outlined,
          title: 'Action:',
          value: entry.action?.summary ?? 'None',
        ),
      );
      widgets.add(const Divider(height: 24));
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast(); // Remove last divider
    }
    return widgets;
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
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(value, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}