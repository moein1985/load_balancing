
// presentation/screens/load_balancing/widgets/pbr_form.dart
import 'package:flutter/material.dart';

class PbrForm extends StatefulWidget {
  const PbrForm({super.key});

  @override
  State<PbrForm> createState() => _PbrFormState();
}

class _PbrFormState extends State<PbrForm> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PBR Configuration',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
                'Define policies to route specific traffic through different gateways. (Coming Soon)'),
            const SizedBox(height: 24),
            // UI elements for PBR will be added here
            const Center(
              child: Text(
                'PBR configuration UI is under development.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: null, // Disabled for now
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Apply Configuration'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}