// presentation/screens/load_balancing/widgets/ecmp_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_event.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';

class EcmpForm extends StatefulWidget {
  const EcmpForm({super.key});

  @override
  State<EcmpForm> createState() => _EcmpFormState();
}

class _EcmpFormState extends State<EcmpForm> {
  final _formKey = GlobalKey<FormState>();
  final _gateway1Controller = TextEditingController();
  final _gateway2Controller = TextEditingController();

  @override
  void dispose() {
    _gateway1Controller.dispose();
    _gateway2Controller.dispose();
    super.dispose();
  }

  void _applyEcmpConfig() {
    if (_formKey.currentState!.validate()) {
      context.read<LoadBalancingBloc>().add(
            ApplyEcmpConfig(
              gateway1: _gateway1Controller.text,
              gateway2: _gateway2Controller.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ECMP Configuration',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                  'Enter the gateway IPs for your two internet connections. Traffic will be distributed equally.'),
              const SizedBox(height: 24),
              _buildGatewayTextField(
                context: context,
                controller: _gateway1Controller,
                labelText: 'Gateway IP 1',
                hintText: 'e.g., 203.0.113.1',
              ),
              const SizedBox(height: 16),
              _buildGatewayTextField(
                context: context,
                controller: _gateway2Controller,
                labelText: 'Gateway IP 2',
                hintText: 'e.g., 198.51.100.1',
              ),
              const SizedBox(height: 32),
              BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
                builder: (context, state) {
                  if (state.status == DataStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ElevatedButton.icon(
                    onPressed: _applyEcmpConfig,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Apply Configuration'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for gateway text fields with a Test button
  Widget _buildGatewayTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    required String hintText,
  }) {
    return BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
        builder: (context, state) {
      final ip = controller.text;
      final isPinging = state.pingStatus == DataStatus.loading && state.pingingIp == ip;
      final pingResult = state.pingResults[ip];

      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          suffixIcon: isPinging
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.network_ping),
                  tooltip: 'Test Gateway Reachability',
                  onPressed: ip.isNotEmpty
                      ? () {
                          context
                              .read<LoadBalancingBloc>()
                              .add(PingGatewayRequested(ip));
                        }
                      : null,
                ),
          helperText: pingResult,
          helperStyle: TextStyle(
            color: pingResult != null && pingResult.contains('Success')
                ? Colors.green
                : Colors.orange,
          )
        ),
        keyboardType: TextInputType.number,
        validator: (value) =>
            value == null || value.isEmpty ? 'Please enter a Gateway IP' : null,
      );
    });
  }
}