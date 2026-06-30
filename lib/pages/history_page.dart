import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../helpers/currency_formatter.dart';
import '../models/receipt_model.dart';
import '../services/receipt_storage_service.dart';
import 'receipt_detail_page.dart';

/// History page — lists every receipt saved on this device, newest first.
///
/// Subscribes to [ReceiptStorageService.changes] so it rebuilds automatically
/// when a save or delete happens from any screen (including the Review page).
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final ReceiptStorageService _storage;
  StreamSubscription<void>? _changesSub;

  @override
  void initState() {
    super.initState();
    _storage = context.read<ReceiptStorageService>();
    _changesSub = _storage.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    super.dispose();
  }

  Future<void> _confirmDelete(ReceiptModel receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete receipt?'),
          content: Text('Remove ${receipt.merchant} from your history?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _storage.deleteReceipt(receipt.createdAt.toIso8601String());
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipts = _storage.getReceiptsSync();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Receipts'),
        actions: [
          if (receipts.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear all receipts?'),
                    content: const Text(
                      'This will remove every saved receipt. The action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _storage.clearReceipts();
                }
              },
            ),
        ],
      ),
      body: receipts.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: receipts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final receipt = receipts[index];
                return Dismissible(
                  key: ValueKey(receipt.createdAt.toIso8601String()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: theme.colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    await _confirmDelete(receipt);
                    // Returning `false` keeps the item in the list — the
                    // stream listener will rebuild without it.
                    return false;
                  },
                  child: _ReceiptTile(receipt: receipt),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No receipts saved yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Save Receipt" on the Review screen to keep a copy here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.receipt});

  final ReceiptModel receipt;

  String _formatDate(DateTime dt) =>
      DateFormat('dd MMM yyyy · HH:mm').format(dt.toLocal());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = receipt.imagePath.isNotEmpty &&
        File(receipt.imagePath).existsSync();

    return ListTile(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReceiptDetailPage(receipt: receipt),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: hasImage
              ? Image.file(File(receipt.imagePath), fit: BoxFit.cover)
              : Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.receipt_long,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
      title: Text(
        receipt.merchant.isEmpty ? 'Unknown Merchant' : receipt.merchant,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(receipt.date.isEmpty ? '—' : receipt.date),
          Text(
            receipt.category.isEmpty ? '—' : receipt.category,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            CurrencyFormatter.format(receipt.total),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _formatDate(receipt.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}