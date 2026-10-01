/// Display labels for assistant permission keys.
const Map<String, String> _permissionLabels = {
  'manage_appointments': 'Manage appointments',
  'record_outcomes': 'Record outcomes',
  'manage_action_points': 'Manage action points',
  'export_reports': 'Export reports',
};

/// Returns the human-readable label for a permission key, e.g.
/// 'manage_appointments' -> 'Manage appointments'. Falls back to the raw
/// key with underscores replaced by spaces if it isn't a known permission.
String permissionLabel(String permission) {
  return _permissionLabels[permission] ?? permission.replaceAll('_', ' ');
}

/// All permissions selectable when inviting an assistant.
const List<String> availablePermissions = [
  'manage_appointments',
  'record_outcomes',
  'manage_action_points',
  'export_reports',
];
