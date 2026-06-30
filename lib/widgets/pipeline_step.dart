import 'package:flutter/material.dart';


class PipelineStep extends StatelessWidget {
  const PipelineStep({
    required this.icon,
    required this.label,
    required this.completed,
    this.isLast = false,
    super.key,
  });

  final String icon;

  final String label;

  final bool completed;

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
    final mutedColor = colorScheme.outline;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: completed ? activeColor : mutedColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: completed
                  ? activeColor.withValues(alpha: 0.12)
                  : colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                color: completed ? activeColor : mutedColor,
                width: 1.5,
              ),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  if (completed)
                    Icon(Icons.check_circle, color: activeColor, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}