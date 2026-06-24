/// Maps Dart [MparticleOptions] wire indices to mParticle Apple SDK raw values.
///
/// Kept UIKit-free so unit tests run on macOS without linking mParticle-Apple-SDK.
public enum InitializeOptionsParser {
  /// Maps Dart log level index (0–5) to `MPILogLevel` raw value.
  ///
  /// Apple SDK has no INFO level; Dart index 3 (info) maps to Debug (3).
  public static func parseLogLevelRawValue(_ index: Int) -> UInt {
    switch index {
    case 0:
      return 0 // MPILogLevelNone
    case 1:
      return 1 // MPILogLevelError
    case 2:
      return 2 // MPILogLevelWarning
    case 3, 4:
      return 3 // MPILogLevelDebug
    case 5:
      return 4 // MPILogLevelVerbose
    default:
      return 2 // MPILogLevelWarning
    }
  }

  /// Maps Dart environment index to `MPEnvironment` raw value.
  public static func parseEnvironmentRawValue(_ index: Int) -> UInt {
    switch index {
    case 1:
      return 1 // Development
    case 2:
      return 2 // Production
    default:
      return 0 // AutoDetect
    }
  }
}
