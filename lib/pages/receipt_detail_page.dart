import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../helpers/currency_formatter.dart';
import '../models/receipt_model.dart';

/// Read-only detail view for a single saved receipt.
///
/// Receives the [ReceiptModel] by value from the History page; nothing here
/// mutates state, so the back button returns cleanly to the list.
class ReceiptDetailPage extends StatelessWidget {
  const ReceiptDetailPage({super.key, required this.receipt});

  final ReceiptModel receipt;

  String _formatCreatedAt(DateTime dt) =>
      DateFormat('dd MMM yyyy · HH:mm:ss').format(dt.toLocal());

  Future<void> _exportJson(BuildContext context) async {
    final encoder = const JsonEncoder.withIndent('  ');
    final text = encoder.convert(receipt.toJson());
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Receipt JSON copied to clipboard')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = receipt.imagePath.isNotEmpty &&
        File(receipt.imagePath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Detail'),
        actions: [
          IconButton(
            tooltip: 'Export JSON',
            icon: const Icon(Icons.code_outlined),
            onPressed: () => _exportJson(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.file(File(receipt.imagePath), fit: BoxFit.cover),
                ),
              )
            else
              Container(
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            _Field(label: 'Merchant', value: receipt.merchant),
            _Field(label: 'Date', value: receipt.date),
            _Field(
              label: 'Total',
              value: CurrencyFormatter.format(receipt.total),
            ),
            _Field(label: 'Category', value: receipt.category),
            _Field(label: 'Created At', value: _formatCreatedAt(receipt.createdAt)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raw OCR Text',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      receipt.rawText.isEmpty ? '(no raw text)' : receipt.rawText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}