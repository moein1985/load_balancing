// lib/data/datasources/pbr_parser.dart
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/route_map.dart';

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
  
  static List<AccessControlList> parseAccessLists(String config) {
    final accessLists = <AccessControlList>[];
    // Regex for Extended ACLs (protocol, src, dst, port)
    final extendedAclRegex = RegExp(r'^access-list\s+(\S+)\s+(permit|deny)\s+(\S+)\s+(host\s+\S+|\S+\s+\S+|any)\s+(host\s+\S+|\S+\s+\S+|any)(.*)');
    
    // Regex for Standard ACLs updated to only match numbers 1-99.
    final standardAclRegex = RegExp(r'^access-list\s+([1-9]\d?)\s+(permit|deny)\s+(host\s+\S+|\S+\s+\S+|any)');

    final Map<String, List<AclEntry>> allEntries = {};
    for (final line in config.split('\n')) {
      final trimmedLine = line.trim();
      final extendedMatch = extendedAclRegex.firstMatch(trimmedLine);
      final standardMatch = standardAclRegex.firstMatch(trimmedLine);

      if (extendedMatch != null) {
        final id = extendedMatch.group(1)!;
        // This is a simple fix to avoid standard ACLs being parsed as extended.
        if (int.tryParse(id) != null && int.parse(id) < 100 && extendedMatch.group(3) == 'host') {
            // Likely a mis-parsed standard ACL, let standard parser handle it.
        } else {
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
            continue; // Ensure it's not parsed again
        }
      } 
      
      if (standardMatch != null) {
        final id = standardMatch.group(1)!;
        final entry = AclEntry(
          sequence: allEntries[id]?.length ?? 0,
          permission: standardMatch.group(2)!,
          protocol: 'ip', // Standard ACLs match all IP protocols
          source: standardMatch.group(3)!,
          destination: 'any', // Destination is implicitly 'any'
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