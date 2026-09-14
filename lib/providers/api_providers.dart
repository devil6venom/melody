// Riverpod providers for the API layer.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/sunoh_api.dart';

/// Single shared Dio instance.
final dioProvider = Provider((_) => buildMelodyDio());

/// The typed Melody-api service.
final melodyApiProvider = Provider((ref) => MelodyApi(ref.watch(dioProvider)));
