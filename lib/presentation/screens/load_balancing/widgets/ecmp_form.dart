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
    _gatewayControllers[index].dispose();
    setState(() {
      _gatewayControllers.removeAt(index);
    });
  }

  void _applyEcmpConfig() {
    if (_formKey.currentState!.validate()) {
      final gateways = _gatewayControllers
          .map((controller) => controller.text.trim())
          .where((ip) => ip.isNotEmpty)
          .toList();
      context.read<LoadBalancingBloc>().add(
            events.ApplyEcmpConfig(finalGateways: gateways),
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
                'The app automatically detects existing gateways. Edit, add, or clear fields to update the configuration.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              BlocConsumer<LoadBalancingBloc, LoadBalancingState>(
                listenWhen: (prev, curr) => prev.initialEcmpGateways != curr.initialEcmpGateways,
                listener: (context, state) {
                  _updateControllersFromState(state.initialEcmpGateways);
                },
                buildWhen: (prev, curr) => 
                    prev.initialEcmpGateways != curr.initialEcmpGateways ||
                    prev.routingTableStatus != curr.routingTableStatus,
                builder: (context, state) {
                  if (state.routingTableStatus == DataStatus.loading && _gatewayControllers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(child: Text("Reading router configuration...")),
                    );
                  }
                  
                  return ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _gatewayControllers.length,
                    itemBuilder: (context, index) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _GatewayInputField(
                              key: ValueKey('gateway_field_$index'),
                              controller: _gatewayControllers[index],
                              label: 'Gateway ${index + 1}',
                            ),
                          ),
                          if (_gatewayControllers.length > 1)
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
                  );
                },
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
                buildWhen: (prev, curr) => prev.status != curr.status,
                builder: (context, state) {
                  if (state.status == DataStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ElevatedButton.icon(
                    onPressed: _applyEcmpConfig,
                    icon: const Icon(Icons.settings_applications),
                    label: const Text('Apply Changes'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16)
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

  void _updateControllersFromState(List<String> newGateways) {
    for (final controller in _gatewayControllers) {
      controller.dispose();
    }
    _gatewayControllers.clear();
    for (final ip in newGateways) {
      _gatewayControllers.add(TextEditingController(text: ip));
    }

    // **MODIFIED:** If the list is empty after checking the router, 
    // add one blank field to give the user a starting point.
    if (_gatewayControllers.isEmpty) {
      _gatewayControllers.add(TextEditingController());
    }

    if(mounted) {
      setState(() {});
    }
  }
}

class _GatewayInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _GatewayInputField({
    super.key,
    required this.controller,
    required this.label,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isNotEmpty && !_isValidIp(text)) {
              return 'Invalid IP address format';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: label,
            hintText: 'e.g., 192.168.1.1',
            border: const OutlineInputBorder(),
            suffixIcon: BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
              buildWhen: (prev, curr) {
                final ip = controller.text.trim();
                return prev.pingingIp == ip || curr.pingingIp == ip || prev.pingResults[ip] != curr.pingResults[ip];
              },
              builder: (context, state) {
                final ipAddress = controller.text.trim();
                final isPinging = state.pingingIp == ipAddress;
                final canPing = ipAddress.isNotEmpty && _isValidIp(ipAddress) && !isPinging;
                if (isPinging) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return IconButton(
                  icon: const Icon(Icons.network_ping),
                  tooltip: canPing ? 'Ping Gateway' : 'Enter a valid IP to ping',
                  onPressed: canPing
                      ? () {
                          context
                              .read<LoadBalancingBloc>()
                              .add(events.PingGatewayRequested(ipAddress));
                        }
                      : null,
                );
              },
            ),
          ),
        ),
        BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
           buildWhen: (prev, curr) {
                final ip = controller.text.trim();
                return prev.pingResults[ip] != curr.pingResults[ip];
              },
          builder: (context, state) {
            final ipAddress = controller.text.trim();
            final pingResult = state.pingResults[ipAddress];

            if (pingResult == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
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
            );
          },
        ),
      ],
    );
  }
}