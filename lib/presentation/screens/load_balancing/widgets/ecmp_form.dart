// lib/presentation/screens/load_balancing/widgets/ecmp_form.dart
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
  // IP validation regex
  static final _ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  @override
  void dispose() {
    _gateway1Controller.dispose();
    _gateway2Controller.dispose();
    super.dispose();
  }

  bool _isValidIp(String ip) {
    if (!_ipRegex.hasMatch(ip)) return false;

    final parts = ip.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  void _applyEcmpConfig() {
    if (_formKey.currentState!.validate()) {
      context.read<LoadBalancingBloc>().add(
            ApplyEcmpConfig(
              gateway1: _gateway1Controller.text.trim(),
              gateway2: _gateway2Controller.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ECMP Settings',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Enter the IP addresses of your internet gateways. Traffic will be distributed equally between them.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _GatewayInputField(
                controller: _gateway1Controller,
                label: 'Gateway 1',
                hint: 'e.g., 192.168.1.1',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Gateway 1 IP address is required';
                  }
                  if (!_isValidIp(value.trim())) {
                    return 'Invalid IP address format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _GatewayInputField(
                controller: _gateway2Controller,
                label: 'Gateway 2',
                hint: 'e.g., 192.168.2.1',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Gateway 2 IP address is required';
                  }
                  if (!_isValidIp(value.trim())) {
                    return 'Invalid IP address format';
                  }
                  if (value.trim() == _gateway1Controller.text.trim()) {
                    return 'Gateway 2 cannot be the same as Gateway 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
                builder: (context, state) {
                  if (state.status == DataStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ElevatedButton.icon(
                    onPressed: _applyEcmpConfig,
                    icon: const Icon(Icons.settings),
                    label: const Text('Apply Settings'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Improved _GatewayInputField to prevent pinging with an empty IP
class _GatewayInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  const _GatewayInputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
  });
  // IP validation regex
  static final _ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  bool _isValidIp(String ip) {
    if (ip.trim().isEmpty) return false;
    if (!_ipRegex.hasMatch(ip.trim())) return false;

    final parts = ip.trim().split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
      builder: (context, state) {
        final ipAddress = controller.text.trim();
        final pingResult = state.pingResults[ipAddress];
        final isPinging = state.pingingIp == ipAddress;
        final canPing = ipAddress.isNotEmpty && _isValidIp(ipAddress) && !isPinging;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              validator: validator,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: const OutlineInputBorder(),
                suffixIcon: isPinging
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.network_ping),
                        tooltip: canPing ? 'Ping Gateway' : 'Enter a valid IP to ping',
                        onPressed: canPing
                            ? () {
                                context
                                    .read<LoadBalancingBloc>()
                                    .add(PingGatewayRequested(controller.text.trim()));
                              }
                            : null,
                      ),
              ),
              onChanged: (value) {
                // Trigger a rebuild to update the ping button's enabled state
                if (context.mounted) {
                  (context as Element).markNeedsBuild();
                }
              },
            ),
            if (pingResult != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: pingResult.toLowerCase().contains('success')
                      ? Colors.green.withAlpha((.1 * 255).round())
                      : Colors.orange.withAlpha((.1 * 255).round()),
                  border: Border.all(
                    color: pingResult.toLowerCase().contains('success')
                        ? Colors.green
                        : Colors.orange,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      pingResult.toLowerCase().contains('success')
                          ? Icons.check_circle
                          : Icons.warning,
                      size: 16,
                      color: pingResult.toLowerCase().contains('success')
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pingResult,
                        style: TextStyle(
                          fontSize: 12,
                          color: pingResult.toLowerCase().contains('success')
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        context
                            .read<LoadBalancingBloc>()
                            .add(ClearPingResult(ipAddress));
                      },
                      tooltip: 'Clear Result',
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}