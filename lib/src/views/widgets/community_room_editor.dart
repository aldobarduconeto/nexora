import 'package:flutter/material.dart';

Future<String?> showCommunityRoomEditor(
  BuildContext context, {
  required bool voice,
  required Future<void> Function(String name) save,
  String? initialName,
}) {
  final form = GlobalKey<FormState>();
  final kind = voice ? 'áudio' : 'texto';
  var name = initialName ?? '';
  var saving = false;
  String? error;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(
          initialName == null ? 'Nova sala de $kind' : 'Renomear sala de $kind',
        ),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: initialName,
            autofocus: true,
            enabled: !saving,
            maxLength: voice ? 40 : 32,
            decoration: InputDecoration(
              labelText: 'Nome da sala',
              prefixText: voice ? null : '#',
              errorText: error,
            ),
            onChanged: (value) {
              name = value;
              if (error != null) update(() => error = null);
            },
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Informe o nome.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final submitted = name.trim();
                    update(() => saving = true);
                    try {
                      await save(submitted);
                      if (context.mounted) Navigator.of(context).pop(submitted);
                    } catch (failure) {
                      if (!context.mounted) return;
                      update(() {
                        saving = false;
                        error = switch (failure) {
                          ArgumentError(:final message) => message?.toString(),
                          StateError(:final message) => message,
                          _ => 'Não foi possível salvar a sala.',
                        };
                      });
                    }
                  },
            child: Text(initialName == null ? 'Criar sala' : 'Salvar nome'),
          ),
        ],
      ),
    ),
  );
}
