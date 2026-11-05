import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';

/// Panel de preferencias de lectura reutilizado por el lector y los ajustes.
class ReaderSettingsPanel extends ConsumerStatefulWidget {
  const ReaderSettingsPanel({
    super.key,
    this.showHeader = true,
    this.scrollable = true,
  });

  final bool showHeader;

  /// Cuando es `false`, el panel se integra en otra pantalla con scroll.
  final bool scrollable;

  @override
  ConsumerState<ReaderSettingsPanel> createState() =>
      _ReaderSettingsPanelState();
}

class _ReaderSettingsPanelState extends ConsumerState<ReaderSettingsPanel> {
  late double _fontSize;
  late double _lineHeight;
  late double _margin;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final settings = ref.read(settingsProvider);
    _fontSize = settings.readerFontSize;
    _lineHeight = settings.readerLineHeight;
    _margin = settings.readerMargin;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final children = <Widget>[
            if (widget.showHeader) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ajustes de lectura',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text('Tema', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 10),
            Row(
              children: ReaderTheme.values.map((theme) {
                final selected = settings.readerTheme == theme;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ThemeSwatch(
                      theme: theme,
                      selected: selected,
                      onTap: () => notifier.setReaderTheme(theme),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _ReaderPreview(settings: settings),
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'Tipografía',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Spacer(),
                _SegmentedToggle(
                  left: 'Serif',
                  right: 'Sans',
                  leftSelected: settings.readerSerif,
                  onChanged: (value) =>
                      notifier.setReaderType(serif: value),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SliderRow(
              label: 'Tamaño',
              value: '${_fontSize.round()}',
              slider: Slider(
                value: _fontSize,
                min: 14,
                max: 30,
                divisions: 16,
                onChanged: (value) => setState(() => _fontSize = value),
                onChangeEnd: (value) {
                  notifier.setReaderFontSize(value);
                  setState(() => _fontSize = value);
                },
              ),
            ),
            _SliderRow(
              label: 'Interlineado',
              value: _lineHeight.toStringAsFixed(2),
              slider: Slider(
                value: _lineHeight,
                min: 1.25,
                max: 2,
                divisions: 15,
                onChanged: (value) => setState(() => _lineHeight = value),
                onChangeEnd: (value) {
                  notifier.setReaderLineHeight(value);
                  setState(() => _lineHeight = value);
                },
              ),
            ),
            _SliderRow(
              label: 'Márgenes',
              value: '${_margin.round()}',
              slider: Slider(
                value: _margin,
                min: 14,
                max: 64,
                divisions: 25,
                onChanged: (value) => setState(() => _margin = value),
                onChangeEnd: (value) {
                  notifier.setReaderMargin(value);
                  setState(() => _margin = value);
                },
              ),
            ),
            SwitchListTile(
              value: settings.readerJustify,
              onChanged: (value) => notifier.setReaderJustify(value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Justificar texto'),
              subtitle: Text(
                'Alinea los dos márgenes de cada párrafo',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              activeThumbColor: palette.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'Los cambios se aplican al instante. Tu progreso se conserva '
              'aunque cambie el tamaño del texto.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
    ];

    if (!widget.scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          children: children,
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? palette.primary : palette.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w600,
                color: theme.text,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              theme.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppType.ui,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.text.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderPreview extends StatelessWidget {
  const _ReaderPreview({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = settings.readerTheme;
    final dark = ThemeData.estimateBrightnessForColor(theme.background) ==
        Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Así se verá tu lectura',
            style: TextStyle(
              fontFamily: AppType.ui,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: theme.muted,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'La noche caía despacio sobre el jardín, y las hojas '
            'parecían guardar la luz del último sol.',
            textAlign: settings.readerJustify ? TextAlign.justify : TextAlign.left,
            style: TextStyle(
              fontFamily: settings.readerSerif ? AppType.reading : AppType.ui,
              fontSize: settings.readerFontSize.clamp(14, 24),
              height: settings.readerLineHeight,
              color: theme.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.slider,
  });

  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: palette.inkSoft,
                      ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: slider,
          ),
        ],
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, left, leftSelected, () => onChanged(true)),
          _segment(context, right, !leftSelected, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? palette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppType.ui,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? palette.ink : palette.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// Abre el panel como hoja inferior.
Future<void> showReaderSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: ReaderSettingsPanel(),
    ),
  );
}

/// Pequeña ayuda visual para la pantalla de ajustes.
class ReadingAheadNote extends StatelessWidget {
  const ReadingAheadNote({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.tips_and_updates_outlined, size: 18, color: palette.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Puedes cambiar el tema y el tamaño de letra en cualquier '
            'momento desde el propio lector, tocando el centro de la página.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
