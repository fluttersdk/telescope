import 'package:fluttersdk_artisan/artisan.dart';

import 'commands/telescope_clear_command.dart';
import 'commands/telescope_requests_command.dart';
import 'commands/telescope_tail_command.dart';

/// Contributes telescope:* commands to the artisan dispatcher.
class TelescopeArtisanProvider extends ArtisanServiceProvider {
  @override
  String get providerName => 'fluttersdk_telescope';

  @override
  List<ArtisanCommand> commands() => <ArtisanCommand>[
    TelescopeTailCommand(),
    TelescopeRequestsCommand(),
    TelescopeClearCommand(),
  ];
}
