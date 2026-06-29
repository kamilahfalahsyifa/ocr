import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'providers/receipt_provider.dart';
import 'pages/home/home_page.dart';

/// Entry point of the SnapExpense Flutter app.
///
/// Wires up the global [ReceiptProvider] (single source of truth for the OCR
/// pipeline) and renders the [HomePage] as the initial route.
void main() {
  runApp(const SnapExpenseApp());
}

/// Root widget of the application.
class SnapExpenseApp extends StatelessWidget {
  const SnapExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReceiptProvider>(
      create: (_) => ReceiptProvider(),
      child: MaterialApp(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HomePage(),
      ),
    );
  }
}