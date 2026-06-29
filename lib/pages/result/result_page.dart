import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../helpers/currency_formatter.dart';
import '../../models/receipt_model.dart';
import '../../providers/receipt_provider.dart';
import '../../widgets/info_row.dart';
import '../../widgets/pipeline_step.dart';
import '../../widgets/receipt_image.dart';
import '../review/review_page.dart';

/// Result screen — shows the receipt image, the raw OCR text, and the parsed
/// fields. When Developer Mode is enabled, also renders the OCR pipeline
/// visualization at the top.
class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  Future<void> _goToReview(BuildContext context) async {
    final provider = context.read<ReceiptProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ReviewPage()),
    );
    // Wipe pipeline state so a fresh scan starts clean after the user
    // returns from the Review screen — whether they saved or not.
    provider.resetForNextScan();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    final receipt = provider.receipt;
    final theme = Theme.of(context);

    if (receipt == null) {
      // Defensive empty state — the Scan page only navigates here on success.
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.ocrResultTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.ocrResultTitle),
        actions: [
          Row(
            children: [
              Text(
                AppStrings.developerMode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Switch(
                value: provider.developerMode,
                onChanged: (_) => provider.toggleDeveloperMode(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReceiptImage(imagePath: receipt.imagePath),
              const SizedBox(height: 16),
              if (provider.developerMode) ...[
                _PipelineCard(
                  completed: provider.completedStages,
                ),
                const SizedBox(height: 16),
              ],
              _SectionCard(
                title: AppStrings.rawOcrText,
                child: SelectableText(
                  provider.rawText ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              // Developer Mode only — show the normalized text alongside the raw text.
              if (provider.developerMode) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.normalizedOcrText,
                  child: SelectableText(
                    provider.normalizedText ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ConfidenceCard(receipt: receipt),
                const SizedBox(height: 16),
                _DebugCard(receipt: receipt),
              ] else ...[
                const SizedBox(height: 16),
              ],
              _SectionCard(
                title: AppStrings.parsedResult,
                child: Column(
                  children: [
                    InfoRow(label: AppStrings.merchant, value: receipt.merchant),
                    InfoRow(label: AppStrings.date, value: receipt.date),
                    InfoRow(
                      label: AppStrings.total,
                      value: CurrencyFormatter.format(receipt.total),
                    ),
                    InfoRow(label: AppStrings.category, value: receipt.category),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _goToReview(context),
                icon: const Icon(Icons.checklist_rtl),
                label: const Text(AppStrings.reviewResult),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card with a title bar used on the Result screen.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Developer Mode visualization card.
///
/// Renders the six pipeline stages with a green checkmark for each completed
/// stage. Intended for the live demo so the audience can follow the data flow.
class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.completed});

  final Set<PipelineStage> completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = <_PipelineStepDescriptor>[
      _PipelineStepDescriptor(
        icon: '📷',
        label: 'Selected Image',
        stage: PipelineStage.imageSelected,
      ),
      _PipelineStepDescriptor(
        icon: '🔍',
        label: 'Google ML Kit OCR',
        stage: PipelineStage.ocrCompleted,
      ),
      _PipelineStepDescriptor(
        icon: '📝',
        label: 'Raw OCR Text',
        stage: PipelineStage.ocrCompleted,
      ),
      _PipelineStepDescriptor(
        icon: '⚙️',
        label: 'Receipt Parser',
        stage: PipelineStage.parsingCompleted,
      ),
      _PipelineStepDescriptor(
        icon: '📦',
        label: 'Structured Data',
        stage: PipelineStage.parsingCompleted,
      ),
      _PipelineStepDescriptor(
        icon: '✏️',
        label: 'Editable Form',
        stage: PipelineStage.reviewReady,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.pipelineTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(steps.length, (i) {
              final s = steps[i];
              return PipelineStep(
                icon: s.icon,
                label: s.label,
                completed: completed.contains(s.stage),
                isLast: i == steps.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PipelineStepDescriptor {
  const _PipelineStepDescriptor({
    required this.icon,
    required this.label,
    required this.stage,
  });

  final String icon;
  final String label;
  final PipelineStage stage;
}

/// Per-field confidence breakdown shown only when Developer Mode is on.
class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.receipt});

  final ReceiptModel receipt;

  String _percent(double v) =>
      '${(v.clamp(0.0, 1.0) * 100).round()}${AppStrings.confidencePercentSuffix}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <_ConfidenceRow>[
      _ConfidenceRow(
        label: AppStrings.merchant,
        value: receipt.confidenceFor(ReceiptModel.fieldMerchant),
      ),
      _ConfidenceRow(
        label: AppStrings.date,
        value: receipt.confidenceFor(ReceiptModel.fieldDate),
      ),
      _ConfidenceRow(
        label: AppStrings.total,
        value: receipt.confidenceFor(ReceiptModel.fieldTotal),
      ),
      _ConfidenceRow(
        label: AppStrings.category,
        value: receipt.confidenceFor(ReceiptModel.fieldCategory),
      ),
    ];

    return _SectionCard(
      title: AppStrings.confidenceTitle,
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      r.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: r.value.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 44,
                    child: Text(
                      _percent(r.value),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfidenceRow {
  const _ConfidenceRow({required this.label, required this.value});
  final String label;
  final double value;
}

/// Developer Mode card showing the parser's candidate / rejection trace.
class _DebugCard extends StatelessWidget {
  const _DebugCard({required this.receipt});

  final ReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trace = receipt.debugTrace;
    if (trace == null) {
      return const SizedBox.shrink();
    }

    Widget bulletList(String label, List<String> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  '• $s',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      );
    }

    Widget keyValue(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: value.isEmpty ? '—' : value,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      );
    }

    return _SectionCard(
      title: AppStrings.debugTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          keyValue(
            AppStrings.debugDetectedMerchant,
            trace.chosenMerchant,
          ),
          if ((trace.merchantRejectionReason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8),
              child: Text(
                'reason: ${trace.merchantRejectionReason}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          keyValue(
            AppStrings.debugDateCandidates,
            trace.dateCandidates.join(', '),
          ),
          keyValue(AppStrings.chosenDateLabel, trace.chosenDate),
          bulletList(
            AppStrings.debugTotalCandidates,
            trace.totalCandidates,
          ),
          bulletList(
            AppStrings.debugRejectedCandidates,
            trace.totalRejections,
          ),
          keyValue(
            AppStrings.debugChosenCandidate,
            trace.chosenTotal,
          ),
          if ((trace.totalRejectionReason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8),
              child: Text(
                'reason: ${trace.totalRejectionReason}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}