// lib/core/utils/validators.dart

class FormValidators {
  // Regex for a standard IPv4 address.
  static final _ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  // Regex for an IPv4 address with a subnet mask (e.g., 192.168.1.0/24).
  static final _ipWithSubnetRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$');

  /// Validates a simple IP address (e.g., 192.168.1.1).
  /// Returns an error message string if invalid, otherwise null.
  static String? ip(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'IP address cannot be empty.';
    }
    final ip = value.trim();
    if (!_ipRegex.hasMatch(ip)) {
      return 'Invalid IP address format.';
    }
    final parts = ip.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return 'Each part must be between 0-255.';
      }
    }
    return null; // Valid
  }

  /// Validates a network address, which can be 'any', a specific IP, or a subnet.
  /// Returns an error message string if invalid, otherwise null.
  static String? networkAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address cannot be empty.';
    }
    final address = value.trim().toLowerCase();
    if (address == 'any') {
      return null; // 'any' is valid.
    }
    // Check if it's a simple IP or an IP with a subnet.
    if (_ipRegex.hasMatch(address) || _ipWithSubnetRegex.hasMatch(address)) {
      // Basic format is OK, we don't need to validate octets for this general validator.
      // A more complex version could validate the subnet mask range (0-32).
      return null;
    }
    return 'Invalid format. Use "any", an IP, or IP/subnet.';
  }

  /// Validates a port number.
  /// Returns an error message string if invalid, otherwise null.
  static String? port(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Port cannot be empty.';
    }
    final port = value.trim().toLowerCase();
    if (port == 'any') {
      return null; // 'any' is valid.
    }
    final portNum = int.tryParse(port);
    if (portNum == null) {
      return 'Must be a number or "any".';
    }
    if (portNum < 1 || portNum > 65535) {
      return 'Port must be between 1-65535.';
    }
    return null; // Valid
  }

  /// Validates that a field is not empty.
  /// Returns an error message string if empty, otherwise null.
  static String? notEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName cannot be empty.';
    }
    return null; // Valid
  }
}