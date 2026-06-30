import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'pages/home/home_page.dart';
import 'providers/receipt_provider.dart';
import 'services/receipt_storage_service.dart';

/// Entry point of the SnapExpense Flutter app.
///
/// Initializes Hive, opens the receipt storage box, then renders the app
/// with the global [ReceiptProvider] wired up.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Guard against hot reload re-entering `main()` and double-opening the box.
  if (!Hive.isBoxOpen(ReceiptStorageService.boxName)) {
    await Hive.initFlutter();
  }

  final storage = ReceiptStorageService();
  await storage.initialize();

  // Surface a readable error if the box failed to open instead of letting
  // widgets hit a raw Hive exception later.
  if (!storage.isReady) {
    throw StateError(
      'ReceiptStorageService failed to open the "${ReceiptStorageService.boxName}" Hive box.',
    );
  }

  runApp(SnapExpenseApp(storage: storage));
}

/// Root widget of the application.
class SnapExpenseApp extends StatelessWidget {
  const SnapExpenseApp({super.key, required this.storage});

  final ReceiptStorageService storage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Storage is provided by value because it's already constructed and
        // its Hive box is open — Provider does NOT call `create` for `.value`.
        Provider<ReceiptStorageService>.value(value: storage),
        ChangeNotifierProvider<ReceiptProvider>(
          create: (_) => ReceiptProvider(storage: storage),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HomePage(),
      ),
    );
  }
}