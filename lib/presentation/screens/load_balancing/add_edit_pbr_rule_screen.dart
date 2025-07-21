import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';
import 'package:load_balance/domain/repositories/device_repository.dart';
import 'package:load_balance/domain/usecases/apply_pbr_rule.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_bloc.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_event.dart';
import 'package:load_balance/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart' show DataStatus;
import 'widgets/pbr_rule_form_sections.dart';

class AddEditPbrRuleScreen extends StatelessWidget {
  final DeviceCredentials? credentials;
  final String? ruleId;

  const AddEditPbrRuleScreen({
    super.key,
    this.credentials,
    this.ruleId,
  });

  @override
  Widget build(BuildContext context) {
    // 1. لیست اینترفیس‌ها را از بلاک اصلی (که از قبل داده‌ها را دارد) می‌خوانیم
    final existingInterfaces = context.read<LoadBalancingBloc>().state.interfaces;

    return BlocProvider(
      create: (context) {
        // 2. بلاک جدید فرم را با وابستگی‌ها و داده‌های اولیه ایجاد می‌کنیم
        final repository = context.read<DeviceRepository>();
        return PbrRuleFormBloc(
          applyPbrRule: ApplyPbrRule(repository),
          credentials: credentials!,
        )..add(FormLoaded(
            interfaces: existingInterfaces,
            ruleId: ruleId,
          ));
      },
      child: BlocListener<PbrRuleFormBloc, PbrRuleFormState>(
        // 3. به نتیجه ثبت فرم گوش می‌دهیم تا عملیات مناسب را انجام دهیم
        listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
        listener: (context, state) {
          if (state.formStatus == DataStatus.success && state.successMessage != null) {
            // نمایش پیام موفقیت
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ));
            // بازگشت به صفحه قبل
            Navigator.of(context).pop();
          } else if (state.formStatus == DataStatus.failure && state.errorMessage != null) {
            // نمایش پیام خطا
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ));
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(ruleId != null ? 'Edit: $ruleId' : 'Add New PBR Rule'),
            actions: [
              // 4. دکمه SAVE به state گوش می‌دهد و رویداد ثبت را ارسال می‌کند
              BlocBuilder<PbrRuleFormBloc, PbrRuleFormState>(
                buildWhen: (p, c) => p.formStatus != c.formStatus,
                builder: (context, state) {
                  // اگر در حال ارسال بود، یک لودینگ نمایش بده
                  if (state.formStatus == DataStatus.loading) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    );
                  }
                  // در غیر این صورت دکمه را نمایش بده
                  return TextButton(
                    onPressed: () {
                      context.read<PbrRuleFormBloc>().add(FormSubmitted());
                    },
                    child: const Text('SAVE'),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  TrafficMatchCard(),
                  SizedBox(height: 16),
                  RoutingActionCard(),
                  SizedBox(height: 16),
                  ApplyInterfaceCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}