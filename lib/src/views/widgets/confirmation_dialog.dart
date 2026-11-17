import 'package:flutter/material.dart';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String description,
  required String action,
  bool isDestructive = false,
}) async {
  final isDanger = isDestructive ||
      action.toLowerCase().contains('excluir') ||
      action.toLowerCase().contains('apagar') ||
      action.toLowerCase().contains('sair') ||
      action.toLowerCase().contains('limpar');

  return await showDialog<bool>(
        context: context,
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            content: Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: isDanger
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          );
        },
      ) ??
      false;
}
