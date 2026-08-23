import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/services.dart';
import 'core/logging.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sync_config_repository.dart';
import 'features/sync/sync_controller.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    AppLog.error('flutter', details.exceptionAsString(), details.exception,
        details.stack);
    FlutterError.presentError(details);
  };

  final services = await Services.bootstrap();

  // Auto-sync on launch happens inside the controller, after it has confirmed
  // a token exists (G-16, SEC-13).
  await services.sync.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<Services>.value(value: services),
        ChangeNotifierProvider<SettingsRepository>.value(value: services.settings),
        ChangeNotifierProvider<SyncConfigRepository>.value(
          value: services.syncConfig,
        ),
        ChangeNotifierProvider<SyncController>.value(value: services.sync),
        ChangeNotifierProvider<AppState>(create: (_) => AppState()),
      ],
      child: const NoteNestApp(),
    ),
  );
}
