/// fluttersdk_telescope — Passive inspector for Flutter apps (Telescope/Pail analog).
///
/// V1 ships 5 watchers (HttpAdapter pluggable, LogWatcher auto, ExceptionWatcher
/// opt-in, MagicModelWatcher via magic, MagicCacheWatcher via magic) + an in-app
/// Flutter overlay dashboard (Alice/Talker pattern, deferred to V1.x).
///
/// Extension points:
/// - [TelescopePlugin.registerHttpAdapter] for pluggable HTTP capture (Dio,
///   package:http, Chopper, Magic's Http facade).
/// - [TelescopePlugin.registerWatcher] for additional data collectors (Magic
///   model lifecycle, Magic cache events, custom domain events).
///
/// Records are read via [TelescopeStore.recent<X>(limit)]. Live updates via
/// broadcast streams ([TelescopeStore.onHttpRecord], etc.).
library;

export 'src/adapters/dio_http_adapter.dart';
export 'src/adapters/http_adapter.dart';
export 'src/records/exception_record.dart';
export 'src/records/http_request_record.dart';
export 'src/records/log_record_entry.dart';
export 'src/records/magic_cache_record.dart';
export 'src/records/magic_model_record.dart';
export 'src/telescope_artisan_provider.dart';
export 'src/telescope_plugin.dart';
export 'src/telescope_store.dart';
export 'src/watchers/exception_watcher.dart';
export 'src/watchers/log_watcher.dart';
export 'src/watchers/watcher.dart';
