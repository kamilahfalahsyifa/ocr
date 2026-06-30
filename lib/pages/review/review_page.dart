import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../providers/receipt_provider.dart';

/// Final review screen.
///
/// Lets the user tweak the parsed fields before "saving" the receipt. On
/// save, a success dialog is shown and tapping **Done** pops all routes back
/// to the Home screen.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final TextEditingController _merchantController;
  late final TextEditingController _dateController;
  late final TextEditingController _totalController;
  late final TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    final receipt = context.read<ReceiptProvider>().receipt;
    _merchantController = TextEditingController(text: receipt?.merchant ?? '');
    _dateController = TextEditingController(text: receipt?.date ?? '');
    _totalController = TextEditingController(text: receipt?.total ?? '');
    _categoryController =
        TextEditingController(text: receipt?.category ?? '');
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _totalController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    // Push the edited text back into the provider before triggering the save
    // so the success dialog displays the latest values.
    final provider = context.read<ReceiptProvider>();
    provider.updateReceipt(
      merchant: _merchantController.text.trim(),
      date: _dateController.text.trim(),
      total: _totalController.text.trim(),
      category: _categoryController.text.trim(),
    );

    final saved = await provider.saveReceipt();
    if (!mounted) return;

    if (saved) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Receipt saved successfully')),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save receipt. Please try again.'),
          ),
        );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _SuccessDialog(
          onDone: () {
            Navigator.of(dialogContext).pop();
            // Pop the Review screen AND the Result screen underneath so the
            // user lands back on Home.
            Navigator.of(context)
              ..pop()
              ..pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.reviewTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit parsed fields',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel(label: AppStrings.merchant),
                      TextField(
                        controller: _merchantController,
                        textInputAction: TextInputAction.next,
                        decoration:
                            const InputDecoration(hintText: 'e.g. Starbucks'),
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel(label: AppStrings.date),
                      TextField(
                        controller: _dateController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'dd/MM/yyyy',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel(label: AppStrings.total),
                      TextField(
                        controller: _totalController,
                        textInputAction: TextInputAction.next,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(hintText: 'e.g. 125000'),
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel(label: AppStrings.category),
                      TextField(
                        controller: _categoryController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Food, Grocery, Fuel',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Consumer<ReceiptProvider>(
                builder: (context, provider, _) {
                  return FilledButton.icon(
                    onPressed: provider.isSaving ? null : _onSave,
                    icon: provider.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text(AppStrings.saveReceipt),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Success dialog shown after the user taps **Save Receipt**.
class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receipt = context.read<ReceiptProvider>().receipt;

    return AlertDialog(
      icon: CircleAvatar(
        radius: 28,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.check_rounded,
          color: theme.colorScheme.onPrimaryContainer,
          size: 32,
        ),
      ),
      title: const Text(
        AppStrings.successDialogTitle,
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SuccessRow(label: AppStrings.merchant, value: receipt?.merchant),
          _SuccessRow(label: AppStrings.date, value: receipt?.date),
          _SuccessRow(label: AppStrings.total, value: receipt?.total),
          _SuccessRow(label: AppStrings.category, value: receipt?.category),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: onDone,
          child: const Text(AppStrings.done),
        ),
      ],
    );
  }
}

class _SuccessRow extends StatelessWidget {
  const _SuccessRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value!.isEmpty) ? '-' : value!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}