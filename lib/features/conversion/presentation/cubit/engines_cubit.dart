import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/engine_availability.dart';
import '../../domain/usecases/detect_engines.dart';

class EnginesState extends Equatable {
  const EnginesState({
    this.availability = EngineAvailability.none,
    this.detected = false,
  });

  final EngineAvailability availability;

  /// A detecção já terminou?
  final bool detected;

  @override
  List<Object?> get props => [availability, detected];
}

/// Motores encontrados na máquina; um motor pode ser desativado na sessão.
class EnginesCubit extends Cubit<EnginesState> {
  EnginesCubit(this._detectEngines) : super(const EnginesState());

  final DetectEngines _detectEngines;

  Future<void> detect() async {
    final availability = await _detectEngines();
    emit(EnginesState(availability: availability, detected: true));
  }

  void disable(String engineName) {
    if (!state.availability.has(engineName)) return;
    emit(
      EnginesState(
        availability: state.availability.without(engineName),
        detected: state.detected,
      ),
    );
  }
}
