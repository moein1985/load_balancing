// lib/presentation/screens/load_balancing/load_balancing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart'; // این import را اضافه کنید
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_event.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';
import 'package:load_balance/presentation/screens/load_balancing/widgets/ecmp_form.dart';
import 'package:load_balance/presentation/screens/load_balancing/widgets/pbr_form.dart';

class LoadBalancingScreen extends StatefulWidget {
  final LBDeviceCredentials credentials;
  final List<RouterInterface> initialInterfaces; // *** این پراپرتی اضافه شده است ***

  const LoadBalancingScreen({
    super.key,
    required this.credentials,
    required this.initialInterfaces, // *** این پراپرتی اضافه شده است ***
  });

  @override
  State<LoadBalancingScreen> createState() => _LoadBalancingScreenState();
}

class _LoadBalancingScreenState extends State<LoadBalancingScreen> {
  @override
  void initState() {
    super.initState();
    // ***تغییر اصلی***
    // به جای ارسال درخواست تکراری، داده‌های اولیه را به BLoC می‌دهیم
    context.read<LoadBalancingBloc>().add(ScreenStarted(
          widget.credentials,
          widget.initialInterfaces,
        ));
  }

  @override
  Widget build(BuildContext context) {
    // ... بقیه کد این ویجت هیچ تغییری نکرده و مثل قبل باقی می‌ماند ...
    return Scaffold(
      appBar: AppBar(title: const Text('Load Balancing Configuration')),
      floatingActionButton: BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
        buildWhen: (prev, curr) => prev.type != curr.type,
        builder: (context, state) {
          if (state.type == LoadBalancingType.pbr) {
            return FloatingActionButton.extended(
              onPressed: () {
                final credentials = context
                    .read<LoadBalancingBloc>()
                    .state
                    .credentials;
                if (credentials != null) {
                  context.pushNamed('add_pbr_rule', extra: credentials);
                }
              },
              label: const Text('Add New Rule'),
              icon: const Icon(Icons.add),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: BlocListener<LoadBalancingBloc, LoadBalancingState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == DataStatus.success &&
              state.successMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: Colors.green,
                ),
              );
          } else if (state.status == DataStatus.failure &&
              state.error.isNotEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.error}'),
                  backgroundColor: Colors.red,
                ),
              );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Load Balancing Method',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
                builder: (context, state) {
                  return SegmentedButton<LoadBalancingType>(
                    segments: const <ButtonSegment<LoadBalancingType>>[
                      ButtonSegment<LoadBalancingType>(
                        value: LoadBalancingType.ecmp,
                        label: Text('ECMP'),
                        icon: Icon(Icons.alt_route),
                      ),
                      ButtonSegment<LoadBalancingType>(
                        value: LoadBalancingType.pbr,
                        label: Text('PBR'),
                        icon: Icon(Icons.rule),
                      ),
                    ],
                    selected: {state.type},
                    onSelectionChanged: (Set<LoadBalancingType> newSelection) {
                      context.read<LoadBalancingBloc>().add(
                        LoadBalancingTypeSelected(newSelection.first),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              const _RouterInfoSection(), // Widget for smart features
              const SizedBox(height: 24),
              BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
                builder: (context, state) {
                  if (state.type == LoadBalancingType.ecmp) {
                    return const EcmpForm();
                  } else {
                    return const PbrForm();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A private widget to display router info (Interfaces and Routing Table)
class _RouterInfoSection extends StatelessWidget {
  const _RouterInfoSection();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<LoadBalancingBloc>().state;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Router Information'),
        subtitle: const Text('View interfaces and routing table'),
        children: [
          _buildInterfacesInfo(context, state),
          const Divider(height: 1),
          _buildRoutingTableInfo(context, state),
        ],
      ),
    );
  }

  Widget _buildInterfacesInfo(BuildContext context, LoadBalancingState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Device Interfaces',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          if (state.interfacesStatus == DataStatus.loading)
            const Center(child: CircularProgressIndicator())
          else if (state.interfacesStatus == DataStatus.failure)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Error fetching interfaces: ${state.error}',
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (state.interfaces.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('No active interfaces found or connection failed.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Interface')),
                  DataColumn(label: Text('IP Address')),
                  DataColumn(label: Text('Status')),
                ],
                rows: state.interfaces
                    .map(
                      (iface) => DataRow(
                        cells: [
                          DataCell(Text(iface.name)),
                          DataCell(Text(iface.ipAddress)),
                          DataCell(
                            Text(
                              iface.status,
                              style: TextStyle(
                                color: iface.status == 'up'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoutingTableInfo(
    BuildContext context,
    LoadBalancingState state,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'IP Routing Table',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (state.routingTableStatus != DataStatus.loading)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Routing Table',
                  onPressed: state.credentials == null
                      ? null
                      : () {
                          context.read<LoadBalancingBloc>().add(
                                FetchRoutingTableRequested(),
                              );
                        },
                )
              else
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.routingTableStatus == DataStatus.loading &&
              state.routingTable == null)
            const Center(child: Text('Fetching...'))
          else if (state.routingTable != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black.withAlpha((255 * 0.3).round()),
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  state.routingTable!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            )
          else
            const Text('Press refresh to view the routing table.'),
        ],
      ),
    );
  }
}