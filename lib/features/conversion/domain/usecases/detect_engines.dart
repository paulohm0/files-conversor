import '../contracts/repositories.dart';
import '../entities/engine_availability.dart';

class DetectEngines {
  const DetectEngines(this._detector);

  final EngineDetector _detector;

  Future<EngineAvailability> call() => _detector.detect();
}
