import 'package:flutter/material.dart';

/// Tema Material 3, claro e escuro, a partir de uma única cor.
abstract final class AppTheme {
  static const _seed = Color(0xFF0067C0);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.compact,
      extensions: [StatusColors.of(brightness, scheme)],
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
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
