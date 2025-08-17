// lib/data/datasources/pbr_parser.dart
import 'package:load_balance/domain/entities/route_map.dart';

import '../../domain/entities/access_control_list.dart';

class PbrParser {
  static List<RouteMap> parseRouteMaps(String config) {
    final routeMaps = <RouteMap>[];
    final routeMapRegex = RegExp(r'^route-map\s+(\S+)\s+(permit|deny)\s+(\d+)', multiLine: true);
    final matchRegex = RegExp(r'^\s*match ip address\s+(.*)');
    final setNextHopRegex = RegExp(r'^\s*set ip next-hop\s+(.*)');
    final setInterfaceRegex = RegExp(r'^\s*set interface\s+(.*)');

    final lines = config.split('\n');
    Map<String, List<RouteMapEntry>> allEntries = {};
    for (final line in lines) {
      final routeMapMatch = routeMapRegex.firstMatch(line);
      if (routeMapMatch != null) {
        final name = routeMapMatch.group(1)!;
        final permission = routeMapMatch.group(2)!;
        final sequence = int.parse(routeMapMatch.group(3)!);

        allEntries.putIfAbsent(name, () => []);
        
        final entryLines = _getBlock(lines, lines.indexOf(line));
        String? aclId;
        RouteMapAction? action;
        for(final entryLine in entryLines) {
           final matchAcl = matchRegex.firstMatch(entryLine);
           if (matchAcl != null) {
                aclId = matchAcl.group(1)!.trim();
           }

            final setNextHop = setNextHopRegex.firstMatch(entryLine);
            if (setNextHop != null) {
                action = SetNextHopAction(setNextHop.group(1)!.trim().split(' '));
            }

            final setInterface = setInterfaceRegex.firstMatch(entryLine);
            if (setInterface != null) {
                action = SetInterfaceAction(setInterface.group(1)!.trim().split(' '));
            }
        }
        
        allEntries[name]!.add(RouteMapEntry(
          permission: permission,
          sequence: sequence,
          matchAclId: aclId,
          action: action,
        ));
      }
    }

    allEntries.forEach((name, entries) {
       entries.sort((a, b) => a.sequence.compareTo(b.sequence));
       routeMaps.add(RouteMap(name: name, entries: entries));
    });
    return routeMaps;
  }
  
  // **این متد به طور کامل بازنویسی شده تا ساده‌تر و دقیق‌تر باشد**
  static List<AccessControlList> parseAccessLists(String config) {
    final accessLists = <AccessControlList>[];
    // Regex برای ACL های Extended: شماره، permit/deny، پروتکل، مبدا، مقصد، و پورت (اختیاری)
    final extendedAclRegex = RegExp(r'^access-list\s+(\S+)\s+(permit|deny)\s+(\S+)\s+(host\s+\S+|\S+\s+\S+|any)\s+(host\s+\S+|\S+\s+\S+|any)(.*)');
    
    // Regex برای ACL های استاندارد: شماره (1-99)، permit/deny، و مبدا
    final standardAclRegex = RegExp(r'^access-list\s+([1-9]\d?)\s+(permit|deny)\s+(host\s+\S+|\S+\s+\S+|any)');

    final Map<String, List<AclEntry>> allEntries = {};
    for (final line in config.split('\n')) {
      final trimmedLine = line.trim();
      
      // ابتدا تلاش برای تطبیق با الگوی Extended
      final extendedMatch = extendedAclRegex.firstMatch(trimmedLine);
      if (extendedMatch != null) {
        final id = extendedMatch.group(1)!;
        final portCondition = extendedMatch.group(6)?.trim();

        final entry = AclEntry(
          sequence: allEntries[id]?.length ?? 0,
          permission: extendedMatch.group(2)!,
          protocol: extendedMatch.group(3)!,
          source: extendedMatch.group(4)!,
          destination: extendedMatch.group(5)!,
          portCondition: portCondition?.isNotEmpty == true ? portCondition : null,
        );
        allEntries.putIfAbsent(id, () => []).add(entry);
        continue; // اگر Extended بود، به خط بعدی برو
      } 
      
      // اگر Extended نبود، تلاش برای تطبیق با الگوی Standard
      final standardMatch = standardAclRegex.firstMatch(trimmedLine);
      if (standardMatch != null) {
        final id = standardMatch.group(1)!;
        final entry = AclEntry(
          sequence: allEntries[id]?.length ?? 0,
          permission: standardMatch.group(2)!,
          protocol: 'ip', // پروتکل در ACL استاندارد همیشه ip است
          source: standardMatch.group(3)!,
          destination: 'any', // مقصد در ACL استاندارد همیشه any است
        );
        allEntries.putIfAbsent(id, () => []).add(entry);
      }
    }

    allEntries.forEach((id, entries) {
      accessLists.add(AccessControlList(id: id, entries: entries));
    });
    return accessLists;
  }

  static Map<String, String> parseInterfacePolicies(String config) {
    final policies = <String, String>{};
    final lines = config.split('\n');
    String? currentInterface;

    for (final line in lines) {
        if (line.startsWith('interface ')) {
            currentInterface = line.substring('interface '.length).trim();
        } else if (line.startsWith('!') && currentInterface != null) {
            currentInterface = null;
        } else if (currentInterface != null && line.trim().startsWith('ip policy route-map ')) {
            final routeMapName = line.trim().substring('ip policy route-map '.length);
            policies[currentInterface] = routeMapName;
        }
    }
    return policies;
  }

  static List<String> _getBlock(List<String> lines, int startIndex) {
      final block = <String>[];
      for (int i = startIndex + 1; i < lines.length; i++) {
          final line = lines[i];
          if (line.startsWith(' ') || line.startsWith('\t')) {
              block.add(line.trim());
          } else {
              break;
          }
      }
      return block;
  }
}