import 'package:get_it/get_it.dart';
import 'package:get_storage/get_storage.dart';

import '../features/call/data/call_repository.dart';
import '../features/call/data/rx_livekit_notify/rx.dart';
import '../features/call/data/rx_livekit_token/rx.dart';
import 'call_manager.dart';

final locator = GetIt.instance;
GetStorage get appData => locator.get<GetStorage>();

/// Setup dependency injection
void diSetup() {
  // ==================== CORE SERVICES ====================

  locator.registerSingleton<GetStorage>(GetStorage());

  // ==================== REPOSITORIES ====================

  locator.registerLazySingleton<CallRepository>(() => CallRepository());

  // ==================== RX STREAMS ====================

  locator.registerLazySingleton<LivekitTokenRx>(() => LivekitTokenRx());
  locator.registerLazySingleton<LivekitNotifyRx>(() => LivekitNotifyRx());

  // ==================== PROVIDERS ====================

  // Note: CallStateProvider is created in main.dart and passed to widgets
  // This is for accessing it elsewhere if needed

  // ==================== MANAGERS ====================

  // CallManager uses singleton pattern, but we can register for consistency
  locator.registerLazySingleton<CallManager>(() => CallManager.instance);
}

/// Get a registered dependency
T locate<T extends Object>() => locator<T>();

/// Check if dependency is registered
bool isRegistered<T extends Object>() => locator.isRegistered<T>();
