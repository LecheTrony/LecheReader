import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import 'import_service.dart';

/// Abre el selector de archivos, muestra el progreso y el resumen final.
Future<ImportSummary?> runImportFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final progress = ValueNotifier<ImportProgress?>(null);
  final navigator = Navigator.of(context);

  showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _ImportProgressSheet(progress: progress),
  );

  ImportSummary? summary;
  Object? failure;
  try {
    summary = await ref.read(importServiceProvider).pickAndImport(
      onProgress: (value) => progress.value = value,
    );
  } catch (error) {
    failure = error;
  } finally {
    if (navigator.canPop()) navigator.pop();
    progress.dispose();
  }

  if (!context.mounted) return summary;

  if (failure != null) {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageSheet(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo importar',
        message: 'Revisa que el archivo sea válido e inténtalo de nuevo.',
        tone: context.palette.danger,
      ),
    );
    return null;
  }

  if (summary == null) return null;

  await ref.read(libraryProvider.notifier).softReload();
  await ref.read(shelvesProvider.notifier).refreshCounts();

  if (!context.mounted) return summary;

  if (summary.imported.isNotEmpty ||
      summary.duplicates.isNotEmpty ||
      summary.failed > 0) {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ImportSummarySheet(summary: summary!),
    );
  }
  return summary;
}

class _ImportProgressSheet extends StatelessWidget {
  const _ImportProgressSheet({required this.progress});

  final ValueNotifier<ImportProgress?> progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<ImportProgress?>(
          valueListenable: progress,
          builder: (context, value, _) {
            final total = value?.total ?? 0;
            final current = value?.current ?? 0;
            final fraction = total == 0 ? null : current / total;
            final name = value?.fileName ?? '';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: palette.primarySoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        color: palette.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Importando libros',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            total == 0
                                ? 'Esperando archivos…'
                                : '$current de $total',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    name.isEmpty ? 'Preparando la importación' : name,
                    key: ValueKey(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.inkSoft,
                        ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Las portadas y los metadatos se extraen automáticamente.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ImportSummarySheet extends StatelessWidget {
  const _ImportSummarySheet({required this.summary});

  final ImportSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasImported = summary.imported.isNotEmpty;
    final hasProblems = summary.duplicates.isNotEmpty || summary.failed > 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hasImported
                          ? palette.primarySoft
                          : palette.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasImported
                          ? Icons.check_rounded
                          : Icons.info_outline_rounded,
                      color: hasImported ? palette.primary : palette.inkSoft,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasImported
                              ? (summary.imported.length == 1
                                  ? 'Un libro nuevo'
                                  : '${summary.imported.length} libros nuevos')
                              : 'Sin libros nuevos',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          hasImported
                              ? 'Ya están en tu biblioteca.'
                              : 'No había nada que añadir.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasImported) ...[
                const SizedBox(height: 22),
                ...summary.imported.take(4).map(
                      (book) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(
                              book.format.icon,
                              size: 17,
                              color: palette.inkSoft,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              book.format.label,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                if (summary.imported.length > 4)
                  Text(
                    'y ${summary.imported.length - 4} más',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
              if (hasProblems) ...[
                const SizedBox(height: 18),
                const OrnamentDivider(width: 80),
                const SizedBox(height: 14),
                if (summary.duplicates.isNotEmpty)
                  _ProblemRow(
                    icon: Icons.copy_all_outlined,
                    text:
                        '${summary.duplicates.length} ya estaba(n) en la biblioteca',
                  ),
                if (summary.failed > 0)
                  _ProblemRow(
                    icon: Icons.error_outline_rounded,
                    text:
                        '${summary.failed} no se pudo(ieron) importar',
                    color: palette.danger,
                  ),
                if (summary.errors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...summary.errors.map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 30),
                      child: Text(
                        error,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: palette.danger,
                            ),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Listo'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.inkSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: tint),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tint,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageSheet extends StatelessWidget {
  const _MessageSheet({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: tone, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muestra un aviso rápido y discreto.
void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
