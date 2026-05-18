import 'package:magic/magic.dart';

/// Minimal application configuration for the telescope Magic-stack demo.
///
/// The provider list is the smallest set that exercises every Magic adapter
/// telescope ships:
/// - [NetworkServiceProvider] powers `Http.get(...)` (MagicHttpFacadeAdapter).
/// - [DatabaseServiceProvider] + [CacheServiceProvider] satisfy magic's boot
///   contract so `Magic.init()` resolves cleanly without an external backend.
///
/// Auth / Policy / Route providers are intentionally omitted: the demo
/// dispatches synthetic events directly via `Event.dispatch(...)` and
/// `Gate.define(...)` from the home view, so a full auth/router stack is
/// not required to verify the capture surfaces.
Map<String, dynamic> get appConfig => {
      'app': {
        'name': 'Telescope Magic Demo',
        'env': 'local',
        'debug': true,
        'providers': [
          (app) => CacheServiceProvider(app),
          (app) => DatabaseServiceProvider(app),
          (app) => NetworkServiceProvider(app),
        ],
      },
    };
