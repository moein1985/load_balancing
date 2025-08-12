// lib/presentation/screens/load_balancing/widgets/pbr_form.dart
import 'package:flutter/material.dart';
// import 'pbr_rule_list_item.dart'; // This import is no longer needed

class PbrForm extends StatelessWidget {
  const PbrForm({super.key});

  @override
  Widget build(BuildContext context) {
    // A placeholder to show when no PBR rules are configured yet.
    // In a future version, this would be a BlocBuilder listening to a list of rules.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rule_folder_outlined,
              size: 48,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 16),
            Text(
              'No PBR rules configured',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the "Add New Rule" button to create a policy.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}