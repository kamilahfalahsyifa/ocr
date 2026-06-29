import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../providers/receipt_provider.dart';
import '../scan/scan_page.dart';

/// Home (landing) screen.
///
/// Shows the app branding and a single primary call-to-action that kicks off
/// the OCR pipeline. Tapping the button opens a bottom sheet asking the user
/// whether to capture from the camera or pick from the gallery.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// Builds the modal that lets the user pick between camera and gallery.
  Future<ImageSource?> _pickSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                subtitle: const Text('Use the camera to scan your receipt'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pick from gallery'),
                subtitle: const Text('Choose an existing image'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onScanPressed(BuildContext context) async {
    final receiptProvider = context.read<ReceiptProvider>();

    final source = await _pickSource(context);
    if (source == null) return;

    final path = await receiptProvider.pickImageFromSource(source);
    if (path == null || !context.mounted) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ScanPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 160,
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: 80,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                AppStrings.appSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.appDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _onScanPressed(context),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text(AppStrings.scanReceipt),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
