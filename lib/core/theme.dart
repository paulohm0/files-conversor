import 'package:flutter/material.dart';

/// Tema Material 3, claro e escuro, a partir de uma única cor.
abstract final class AppTheme {
  static const _seed = Color(0xFF0067C0);

  /// Arredondamento padrão de todos os componentes.
  static const double radius = 8;
  static final BorderRadius borderRadius = BorderRadius.circular(radius);
  static final RoundedRectangleBorder _shape =
      RoundedRectangleBorder(borderRadius: borderRadius);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.compact,
    );
    final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(_shape);
    return base.copyWith(
      extensions: [StatusColors.of(brightness, scheme)],
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(shape: buttonShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(shape: buttonShape),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(shape: buttonShape),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          textStyle: WidgetStatePropertyAll(base.textTheme.bodyMedium),
        ),
      ),
      dialogTheme: DialogThemeData(shape: _shape),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: borderRadius,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(shape: _shape),
      checkboxTheme: const CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
      ),
    );
  }
}

/// Cores de status da lista, legíveis nos dois temas.
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.done,
    required this.error,
    required this.running,
    required this.muted,
  });

  factory StatusColors.of(Brightness brightness, ColorScheme scheme) =>
      brightness == Brightness.light
          ? StatusColors(
              done: const Color(0xFF1B7F3B),
              error: scheme.error,
              running: const Color(0xFF1A5FD0),
              muted: scheme.onSurfaceVariant,
            )
          : StatusColors(
              done: const Color(0xFF7BD88F),
              error: scheme.error,
              running: const Color(0xFF8AB4F8),
              muted: scheme.onSurfaceVariant,
            );

  final Color done;
  final Color error;
  final Color running;
  final Color muted;

  @override
  StatusColors copyWith({
    Color? done,
    Color? error,
    Color? running,
    Color? muted,
  }) =>
      StatusColors(
        done: done ?? this.done,
        error: error ?? this.error,
        running: running ?? this.running,
        muted: muted ?? this.muted,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      done: Color.lerp(done, other.done, t)!,
      error: Color.lerp(error, other.error, t)!,
      running: Color.lerp(running, other.running, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

extension StatusColorsContext on BuildContext {
  StatusColors get statusColors => Theme.of(this).extension<StatusColors>()!;
}
