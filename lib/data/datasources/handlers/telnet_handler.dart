// lib/data/datasources/handlers/telnet_handler.dart
import 'package:flutter/foundation.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_submission.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'connection_handler.dart';
import 'executors/telnet_executor.dart';

class TelnetHandler implements ConnectionHandler {
  final TelnetExecutor _executor = TelnetExecutor();

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[Telnet Handler] $message');
    }
  }

  @override
  Future<Map<String, String>> fetchInterfaceDataBundle(
    LBDeviceCredentials credentials,
  ) async {
    _logDebug('Preparing interface data bundle commands');
    final brief = await _executor.execute(credentials, [
      'show ip interface brief',
    ]);
    final detailed = await _executor.execute(credentials, [
      'show running-config',
    ]);
    return {'brief': brief, 'detailed': detailed};
  }

  @override
  Future<String> getRoutingTable(LBDeviceCredentials credentials) async {
    _logDebug('Preparing get routing table command');
    return await _executor.execute(credentials, ['show ip route']);
  }

  @override
  Future<String> getRunningConfig(LBDeviceCredentials credentials) async {
    _logDebug('Preparing get running-config command');
    return await _executor.execute(credentials, ['show running-config']);
  }

  @override
  Future<String> pingGateway(
    LBDeviceCredentials credentials,
    String ipAddress,
  ) async {
    _logDebug('Preparing ping command');
    final result = await _executor.executePing(credentials, ipAddress);
    return _analyzePingResult(result);
  }

  @override
  Future<String> applyEcmpConfig({
    required LBDeviceCredentials credentials,
    required List<String> gatewaysToAdd,
    required List<String> gatewaysToRemove,
  }) async {
    _logDebug('Preparing ECMP commands');
    final commands = <String>['configure terminal'];
    gatewaysToRemove
        .where((g) => g.trim().isNotEmpty)
        .forEach((g) => commands.add('no ip route 0.0.0.0 0.0.0.0 $g'));
    gatewaysToAdd
        .where((g) => g.trim().isNotEmpty)
        .forEach((g) => commands.add('ip route 0.0.0.0 0.0.0.0 $g'));
    commands.add('end');

    if (commands.length <= 2) {
      return 'No ECMP configuration changes were needed.';
    }

    final result = await _executor.execute(credentials, commands);
    if (result.toLowerCase().contains('invalid input') ||
        result.toLowerCase().contains('error')) {
      return 'Failed to apply ECMP configuration. Router response: ${result.split('\n').lastWhere((line) => line.contains('%') || line.contains('^'), orElse: () => 'Unknown error')}';
    }
    return 'ECMP configuration applied successfully.';
  }

  @override
  Future<String> applyPbrRule({
    required LBDeviceCredentials credentials,
    required PbrSubmission submission,
  }) async {
    _logDebug('Preparing PBR commands for rule: ${submission.routeMap.name}');
    final commands = <String>['configure terminal'];

    if (submission.newAcl != null) {
      commands.add('no access-list ${submission.newAcl!.id}');
      for (final entry in submission.newAcl!.entries) {
        commands.add(_buildAclEntryCommand(submission.newAcl!.id, entry));
      }
    }

    commands.add('no route-map ${submission.routeMap.name}');
    for (final entry in submission.routeMap.entries) {
      commands.add(
        'route-map ${submission.routeMap.name} ${entry.permission} ${entry.sequence}',
      );
      if (entry.matchAclId != null) {
        commands.add('match ip address ${entry.matchAclId}');
      }
      if (entry.action is SetNextHopAction) {
        final nextHops = (entry.action as SetNextHopAction).nextHops.join(' ');
        commands.add('set ip next-hop $nextHops');
      } else if (entry.action is SetInterfaceAction) {
        final interfaces = (entry.action as SetInterfaceAction).interfaces.join(
          ' ',
        );
        commands.add('set interface $interfaces');
      }
    }
    commands.add('exit');

    if (submission.routeMap.appliedToInterface != null) {
      commands.add('interface ${submission.routeMap.appliedToInterface}');
      commands.add('ip policy route-map ${submission.routeMap.name}');
    }

    commands.add('end');

    final result = await _executor.execute(credentials, commands);
    if (result.toLowerCase().contains('invalid input') ||
        result.toLowerCase().contains('error')) {
      return 'Failed to apply PBR configuration. Router response: ${result.split('\n').lastWhere((line) => line.contains('%') || line.contains('^'), orElse: () => 'Unknown error')}';
    }
    return 'PBR rule "${submission.routeMap.name}" applied successfully.';
  }

  // --- Private Helper Methods ---

  String _analyzePingResult(String output) {
    if (output.contains('!!!!!') ||
        output.contains('Success rate is 100') ||
        output.contains('Success rate is 80')) {
      return 'Success! Gateway is reachable.';
    } else if (output.contains('.....') ||
        output.contains('Success rate is 0')) {
      return 'Timeout. Gateway is not reachable.';
    }
    return 'Ping failed. Check the IP or connection.';
  }

  String _formatAclAddress(String address) {
    final trimmedAddress = address.trim();
    if (trimmedAddress.toLowerCase() == 'any') return 'any';
    if (trimmedAddress.contains(' ')) return trimmedAddress;
    return 'host $trimmedAddress';
  }

  String _buildAclEntryCommand(String aclId, AclEntry entry) {
    final source = _formatAclAddress(entry.source);
    final destination = _formatAclAddress(entry.destination);
    return 'access-list $aclId ${entry.permission} ${entry.protocol} $source $destination ${entry.portCondition ?? ''}'
        .trim();
  }

  @override
  Future<String> deletePbrRule({
    required LBDeviceCredentials credentials,
    required RouteMap ruleToDelete,
  }) async {
    _logDebug('Preparing PBR delete commands for rule: ${ruleToDelete.name}');
    final commands = <String>['configure terminal'];

    // مرحله ۱: حذف پالیسی از روی اینترفیس
    if (ruleToDelete.appliedToInterface != null) {
      commands.add('interface ${ruleToDelete.appliedToInterface}');
      commands.add('no ip policy route-map ${ruleToDelete.name}');
      commands.add('exit');
    }

    // مرحله ۲: حذف خود route-map
    commands.add('no route-map ${ruleToDelete.name}');

    // مرحله ۳: حذف access-list مرتبط (با فرض اینکه این ACL اشتراکی نیست)
    final aclId = ruleToDelete.entries.first.matchAclId;
    if (aclId != null) {
      commands.add('no access-list $aclId');
    }

    commands.add('end');

    final result = await _executor.execute(credentials, commands);
    if (result.toLowerCase().contains('invalid input') ||
        result.toLowerCase().contains('error')) {
      return 'Failed to delete PBR rule. Router response: ${result.split('\n').lastWhere((line) => line.contains('%') || line.contains('^'), orElse: () => 'Unknown error')}';
    }
    return 'PBR rule "${ruleToDelete.name}" deleted successfully.';
  }
}
