// lib/presentation/screens/load_balancing/widgets/ecmp_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_event.dart' as events;
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';

class EcmpForm extends StatefulWidget {
  const EcmpForm({super.key});

  @override
  State<EcmpForm> createState() => _EcmpFormState();
}

class _EcmpFormState extends State<EcmpForm> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _gatewayControllers = [];

  @override
  void initState() {
    super.initState();
    _addGatewayField();
    _addGatewayField();
  }

  @override
  void dispose() {
    for (final controller in _gatewayControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addGatewayField() {
    setState(() {
      _gatewayControllers.add(TextEditingController());
    });
  }

  void _removeGatewayField(int index) {
    setState(() {
      _gatewayControllers[index].dispose();
      _gatewayControllers.removeAt(index);
    });
  }

  bool _isValidIp(String ip) {
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) return false;
    final parts = ip.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  void _applyEcmpConfig() {
    if (_formKey.currentState!.validate()) {
      final gateways = _gatewayControllers
          .map((controller) => controller.text.trim())
          .where((ip) => ip.isNotEmpty)
          .toList();

      if (gateways.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('At least two gateways are required for ECMP.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      context.read<LoadBalancingBloc>().add(
            events.ApplyEcmpConfig(gateways: gateways),
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
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _gatewayControllers.length,
                itemBuilder: (context, index) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _GatewayInputField(
                          key: ValueKey(_gatewayControllers[index]), // Unique key for each field
                          controller: _gatewayControllers[index],
                          label: 'Gateway ${index + 1}',
                          hint: 'e.g., 192.168.${index + 1}.1',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              if (index < 2) return 'Gateway ${index + 1} is required';
                              return null;
                            }
                            if (!_isValidIp(value.trim())) {
                              return 'Invalid IP address format';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_gatewayControllers.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                          child: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            onPressed: () => _removeGatewayField(index),
                            tooltip: 'Remove Gateway',
                          ),
                        ),
                    ],
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 16),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _addGatewayField,
                icon: const Icon(Icons.add),
                label: const Text('Add Gateway'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
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

// **REFACTORED WIDGET**
class _GatewayInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;

  const _GatewayInputField({
    super.key, // Use super.key
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
  });

  static final _ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  bool _isValidIp(String ip) {
    if (ip.trim().isEmpty) return false;
    if (!_ipRegex.hasMatch(ip.trim())) return false;
    final parts = ip.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // This ValueListenableBuilder listens to the text field controller
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        // This BlocBuilder listens for ping results from the BLoC state
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
                                        .add(events.PingGatewayRequested(ipAddress));
                                  }
                                : null,
                          ),
                  ),
                ),
                if (pingResult != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: pingResult.toLowerCase().contains('success')
                          ? Colors.green.withAlpha(30)
                          : Colors.orange.withAlpha(30),
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
                        Expanded(child: Text(pingResult)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            context
                                .read<LoadBalancingBloc>()
                                .add(events.ClearPingResult(ipAddress));
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
      },
    );
  }
}