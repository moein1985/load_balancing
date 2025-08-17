// lib/presentation/screens/load_balancing/widgets/pbr_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_event.dart' as events;
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart';
import 'package:load_balance/presentation/screens/load_balancing/widgets/pbr_rule_card.dart';

class PbrForm extends StatelessWidget {
  const PbrForm({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoadBalancingBloc, LoadBalancingState>(
      // **تغییر اصلی و مهم در این خط است**
      // ویجت اکنون هم به تغییر وضعیت و هم به تغییر لیست رول‌ها واکنش نشان می‌دهد.
      buildWhen: (prev, curr) =>
          prev.pbrStatus != curr.pbrStatus || prev.pbrRouteMaps != curr.pbrRouteMaps,
      builder: (context, state) {
        switch (state.pbrStatus) {
          case DataStatus.initial:
          case DataStatus.loading:
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching PBR rules from router...'),
                  ],
                ),
              ),
            );

          case DataStatus.failure:
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load PBR rules',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(state.pbrError, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: () {
                        context.read<LoadBalancingBloc>().add(events.FetchPbrConfigurationRequested());
                      },
                    )
                  ],
                ),
              ),
            );

          case DataStatus.success:
            if (state.pbrRouteMaps.isEmpty) {
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
            // نمایش لیست کارت‌ها
            return ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: state.pbrRouteMaps.length,
              itemBuilder: (context, index) {
                final routeMap = state.pbrRouteMaps[index];
                return PbrRuleCard(
                  routeMap: routeMap,
                  allAcls: state.pbrAccessLists,
                );
              },
            );
        }
      },
    );
  }
}