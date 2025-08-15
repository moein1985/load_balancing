// lib/data/datasources/handlers/ssh_handler.dart
import 'package:dartssh2/dartssh2.dart'; // این import را اضافه کنید
import 'package:flutter/foundation.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/pbr_submission.dart';
import 'package:load_balance/domain/entities/route_map.dart';

import 'connection_handler.dart';
import 'executors/ssh_executor.dart';

class SshHandler implements ConnectionHandler {
  final SshExecutor _executor = SshExecutor();

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[SSH Handler] $message');
    }
  }
  
  // **تغییر ۱: متد _createAndExecute برای کاهش تکرار کد**
  // این متد یک اتصال جدید ایجاد می‌کند، عملیات را اجرا کرده و اتصال را می‌بندد.
  Future<T> _createAndExecute<T>(
    LBDeviceCredentials credentials,
    Future<T> Function(SSHClient client) operation,
  ) async {
    final client = await _executor.createSshClient(credentials);
    try {
      return await operation(client);
    } finally {
      client.close();
      _logDebug('SSH client closed for single operation.');
    }
  }

  @override
  Future<Map<String, String>> fetchInterfaceDataBundle(
    LBDeviceCredentials credentials,
  ) async {
    _logDebug('Preparing interface data bundle commands');
    return _createAndExecute(credentials, (client) async {
       final commands = [
        'terminal length 0',
        'show ip interface brief',
        'show running-config',
      ];
      final results = await _executor.execute(credentials, client, commands);
      if (results.length < 3) {
        throw Exception('Failed to get all required outputs for interfaces.');
      }
      return {'brief': results[1], 'detailed': results[2]};
    });
  }

  @override
  Future<String> getRoutingTable(LBDeviceCredentials credentials) async {
    _logDebug('Preparing get routing table command');
    return _createAndExecute(credentials, (client) async {
        final commands = ['terminal length 0', 'show ip route'];
        final results = await _executor.execute(credentials, client, commands);
        return results.last;
    });
  }

  @override
  Future<String> getRunningConfig(LBDeviceCredentials credentials) async {
    _logDebug('Preparing get running-config command');
     return _createAndExecute(credentials, (client) async {
        final commands = ['terminal length 0', 'show running-config'];
        final results = await _executor.execute(credentials, client, commands);
        return results.last;
    });
  }

  @override
  Future<String> pingGateway(
    LBDeviceCredentials credentials,
    String ipAddress,
  ) async {
    _logDebug('Preparing ping command');
    return _createAndExecute(credentials, (client) async {
        final commands = ['ping $ipAddress repeat 5'];
        final results = await _executor.execute(credentials, client, commands);
        final result = results.isNotEmpty ? results.first : '';
        return _analyzePingResult(result);
    });
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

    return _createAndExecute(credentials, (client) async {
      final results = await _executor.execute(credentials, client, commands);
      final result = results.join('\n');
      if (result.toLowerCase().contains('invalid input') ||
          result.toLowerCase().contains('error')) {
        return 'Failed to apply ECMP configuration.\nRouter response: $result';
      }
      return 'ECMP configuration applied successfully.';
    });
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

    return _createAndExecute(credentials, (client) async {
        final results = await _executor.execute(credentials, client, commands);
        final result = results.join('\n');
        if (result.toLowerCase().contains('invalid input') ||
            result.toLowerCase().contains('error')) {
          return 'Failed to apply PBR configuration.\nRouter response: $result';
        }
        return 'PBR rule "${submission.routeMap.name}" applied successfully.';
    });
  }

  String _analyzePingResult(String output) {
    if (output.contains('!!!!!') ||
        output.contains('Success rate is 100') ||
        output.contains('Success rate is 80')) {
      return 'Success!\nGateway is reachable.';
    } else if (output.contains('.....') ||
        output.contains('Success rate is 0')) {
      return 'Timeout.\nGateway is not reachable.';
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
  
  // **تغییر ۲: این متد اصلی است که برای حل مشکل حذف، بازنویسی شده**
  @override
  Future<String> deletePbrRule({
    required LBDeviceCredentials credentials,
    required RouteMap ruleToDelete,
  }) async {
    _logDebug('Preparing PBR delete commands for rule: ${ruleToDelete.name}');
    
    // در اینجا ما یک اتصال ایجاد کرده و آن را باز نگه می‌داریم تا هم
    // دستورات حذف و هم دستورات بازخوانی بعدی را روی همین اتصال اجرا کنیم.
    // این کار از طریق RemoteDataSourceImpl مدیریت خواهد شد.
    return _createAndExecute(credentials, (client) async {
       final commands = <String>['configure terminal'];

      // 1. Remove policy from interface
      if (ruleToDelete.appliedToInterface != null) {
        commands.add('interface ${ruleToDelete.appliedToInterface}');
        commands.add('no ip policy route-map ${ruleToDelete.name}');
        commands.add('exit');
      }

      // 2. Remove route-map
      commands.add('no route-map ${ruleToDelete.name}');
      // 3. Remove associated ACL (assuming it's not shared)
      final aclId = ruleToDelete.entries.first.matchAclId;
      if (aclId != null) {
        commands.add('no access-list $aclId');
      }

      commands.add('end');

      final results = await _executor.execute(credentials, client, commands);
      final result = results.join('\n');
      if (result.toLowerCase().contains('invalid input') ||
          result.toLowerCase().contains('error')) {
        return 'Failed to delete PBR rule.\nRouter response: $result';
      }
      return 'PBR rule "${ruleToDelete.name}" deleted successfully.';
    });
  }
}