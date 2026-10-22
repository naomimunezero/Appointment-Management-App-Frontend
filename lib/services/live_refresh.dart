import 'package:flutter/foundation.dart';

/// Bump this whenever a push arrives; open pages listen and refetch.
final ValueNotifier<int> liveRefresh = ValueNotifier<int>(0);