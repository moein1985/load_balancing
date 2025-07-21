// lib/presentation/screens/load_balancing/widgets/pbr_form.dart
import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart'; // این import دیگر لازم نیست و حذف میشود
import 'pbr_rule_list_item.dart';

class PbrForm extends StatelessWidget {
  const PbrForm({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold حذف شد. ویجت اصلی اکنون Padding است
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          // لیست رول های PBR مثل قبل نمایش داده میشود
          PbrRuleListItem(
            ruleName: 'Finance_Web_Traffic',
            matchCondition: 'From: 192.168.10.0/24, Proto: TCP, Port: 443',
            action: 'Next-Hop: 192.168.2.1',
          ),
          SizedBox(height: 16),
          PbrRuleListItem(
            ruleName: 'CCTV_Feed_To_Server',
            matchCondition: 'From: 192.168.50.10, To: 10.0.0.5',
            action: 'Next-Hop: 10.10.10.1',
          ),
        ],
      ),
    );
  }
}