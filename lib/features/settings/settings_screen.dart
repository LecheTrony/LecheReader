import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_settings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../reader/widgets/reader_settings_panel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showSortSheet(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final current = ref.read(settingsProvider).librarySort;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: Text(
                    'Ordenar biblioteca',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                ...LibrarySort.values.map((sort) {
                  final selected = sort == current;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Icon(
                      sort.icon,
                      size: 20,
                      color: selected ? palette.primary : palette.inkSoft,
                    ),
                    title: Text(
                      sort.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? palette.primary : palette.ink,
                          ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_rounded,
                            size: 20, color: palette.primary)
                        : null,
                    onTap: () {
                      ref.read(settingsProvider.notifier).setLibrarySort(sort);
                      Navigator.of(sheetContext).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
          children: [
            const Eyebrow('Hazlo tuyo'),
            const SizedBox(height: 5),
            Text(
              'Ajustes',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 24),

            _SettingsSection(
              title: 'Apariencia',
              subtitle: 'El tema de la interfaz de la biblioteca.',
              child: Row(
                children: [
                  _ModeButton(
                    label: 'Sistema',
                    icon: Icons.brightness_auto_rounded,
                    selected: settings.themeMode == ThemeMode.system,
                    onTap: () => notifier.setThemeMode(ThemeMode.system),
                  ),
                  const SizedBox(width: 10),
                  _ModeButton(
                    label: 'Claro',
                    icon: Icons.light_mode_outlined,
                    selected: settings.themeMode == ThemeMode.light,
                    onTap: () => notifier.setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(width: 10),
                  _ModeButton(
                    label: 'Oscuro',
                    icon: Icons.dark_mode_outlined,
                    selected: settings.themeMode == ThemeMode.dark,
                    onTap: () => notifier.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _SettingsSection(
              title: 'Biblioteca',
              subtitle: 'Cómo se ordenan y muestran tus libros.',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      settings.librarySort.icon,
                      size: 21,
                      color: palette.inkSoft,
                    ),
                    title: const Text('Ordenar por'),
                    subtitle: Text(settings.librarySort.label),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: palette.inkSoft,
                    ),
                    onTap: () => _showSortSheet(context, ref),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Columnas',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tamaño de la cuadrícula',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          children: [0, 2, 3, 4].map((columns) {
                            final selected = settings.libraryColumns == columns;
                            return _MiniChoice(
                              label: columns == 0 ? 'Auto' : '$columns',
                              selected: selected,
                              onTap: () =>
                                  notifier.setLibraryColumns(columns),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: settings.showContinueReading,
                    onChanged: notifier.setShowContinueReading,
                    title: const Text('Continuar leyendo'),
                    subtitle: const Text(
                      'Muestra la tarjeta del libro que tienes entre manos',
                    ),
                    activeThumbColor: palette.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _SettingsSection(
              title: 'Lectura',
              subtitle:
                  'Tipografía, tema y márgenes del lector. Se guardan para '
                  'todos tus libros.',
              child: ReaderSettingsPanel(
                showHeader: false,
                scrollable: false,
              ),
            ),
            const SizedBox(height: 16),

            _SettingsSection(
              title: 'Acerca de LecheReader',
              subtitle: 'Tu biblioteca, solo tuya.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: palette.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          size: 24,
                          color: palette.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LecheReader',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Versión 1.0.0',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Un lector tranquilo para tus PDF, EPUB, cómics, TXT, FB2 '
                    'y páginas HTML. Sin cuentas, sin anuncios y sin subir tus '
                    'libros a ningún sitio.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.inkSoft,
                          height: 1.6,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: const ['PDF', 'EPUB', 'CBZ', 'TXT', 'FB2', 'HTML']
                        .map((format) => _FormatTag(label: format))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Hecho con cariño para leer despacio.',
                style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: palette.inkSoft.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.outline.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? palette.primarySoft : palette.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.primary : Colors.transparent,
              width: 1.3,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? palette.primary : palette.inkSoft,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppType.ui,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? palette.primary : palette.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChoice extends StatelessWidget {
  const _MiniChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppType.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? palette.onPrimary : palette.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _FormatTag extends StatelessWidget {
  const _FormatTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppType.ui,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: palette.inkSoft,
        ),
      ),
    );
  }
}
