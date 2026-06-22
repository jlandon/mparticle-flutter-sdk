import 'package:flutter/services.dart';
import 'package:mparticle_flutter_sdk/identity/identity_type.dart';

/// Log levels for mParticle SDK initialization.
enum MparticleLogLevel {
  none,
  error,
  warning,
  info,
  debug,
  verbose,
}

/// Environment mode for mParticle SDK initialization.
enum MparticleEnvironment {
  autoDetect,
  development,
  production,
}

/// iOS-only initialization options.
class IOSOptions {
  /// Creates iOS-specific options.
  const IOSOptions({this.roktPaymentExtension});

  /// Rokt payment extension registration options.
  final RoktPaymentExtensionOptions? roktPaymentExtension;

  Map<String, dynamic>? toJson() {
    if (roktPaymentExtension == null) {
      return null;
    }
    return {
      'roktPaymentExtension': roktPaymentExtension!.toJson(),
    };
  }
}

/// Options for registering the Rokt payment extension on iOS.
class RoktPaymentExtensionOptions {
  /// Creates Rokt payment extension options.
  const RoktPaymentExtensionOptions({
    required this.applePayMerchantId,
    this.urlScheme,
  });

  /// Apple Pay merchant identifier.
  final String applePayMerchantId;

  /// Optional URL scheme for payment flows.
  final String? urlScheme;

  Map<String, dynamic> toJson() => {
        'applePayMerchantId': applePayMerchantId,
        if (urlScheme != null) 'urlScheme': urlScheme,
      };
}

/// Configuration passed to [MparticleFlutterSdk.initialize].
class MparticleOptions {
  /// Creates mParticle initialization options.
  ///
  /// [apiKey] and [apiSecret] are required. Prefer loading credentials via
  /// `--dart-define` rather than hard-coding in source.
  MparticleOptions({
    required this.apiKey,
    required this.apiSecret,
    this.logLevel = MparticleLogLevel.warning,
    this.environment = MparticleEnvironment.autoDetect,
    this.customBaseUrl,
    this.bootstrapIdentityRequest,
    this.ios,
    Duration? initTimeout,
  }) : initTimeout =
            _clampInitTimeout(initTimeout ?? const Duration(seconds: 5));

  /// mParticle workspace API key.
  final String apiKey;

  /// mParticle workspace API secret.
  final String apiSecret;

  /// Native SDK log level. Avoid [MparticleLogLevel.verbose] in release builds.
  final MparticleLogLevel logLevel;

  /// SDK environment mode.
  final MparticleEnvironment environment;

  /// Optional custom base URL (CNAME). Must use HTTPS.
  final String? customBaseUrl;

  /// Optional identity request applied at SDK startup.
  ///
  /// Adds network latency before [runApp]. Prefer calling
  /// [Identity.identify] after startup when possible.
  final Map<IdentityType, String>? bootstrapIdentityRequest;

  /// iOS-only options (ignored on Android).
  final IOSOptions? ios;

  /// Dart-only timeout wrapping the initialize method channel call.
  final Duration initTimeout;

  static const int _maxBootstrapIdentities = 10;
  static const int _maxIdentityValueLength = 256;

  static Duration _clampInitTimeout(Duration timeout) {
    if (timeout.inSeconds < 1) {
      return const Duration(seconds: 1);
    }
    if (timeout.inSeconds > 30) {
      return const Duration(seconds: 30);
    }
    return timeout;
  }

  /// Validates options before sending to native platforms.
  void validate() {
    if (apiKey.trim().isEmpty || apiSecret.trim().isEmpty) {
      throw MparticleInitException(
        code: MparticleInitErrorCodes.invalidCredentials,
        message: 'apiKey and apiSecret must be non-empty.',
      );
    }

    if (customBaseUrl != null &&
        !customBaseUrl!.trim().toLowerCase().startsWith('https://')) {
      throw MparticleInitException(
        code: MparticleInitErrorCodes.invalidBaseUrl,
        message: 'customBaseUrl must use the https:// scheme.',
      );
    }

    final urlScheme = ios?.roktPaymentExtension?.urlScheme;
    if (urlScheme != null && !_isValidUrlScheme(urlScheme)) {
      throw MparticleInitException(
        code: MparticleInitErrorCodes.invalidOptions,
        message: 'urlScheme format is invalid.',
      );
    }

    if (bootstrapIdentityRequest != null) {
      if (bootstrapIdentityRequest!.length > _maxBootstrapIdentities) {
        throw MparticleInitException(
          code: MparticleInitErrorCodes.invalidOptions,
          message: 'bootstrapIdentityRequest exceeds maximum identity count.',
        );
      }
      for (final entry in bootstrapIdentityRequest!.entries) {
        if (entry.value.trim().isEmpty) {
          throw MparticleInitException(
            code: MparticleInitErrorCodes.invalidOptions,
            message: 'bootstrapIdentityRequest contains empty values.',
          );
        }
        if (entry.value.length > _maxIdentityValueLength) {
          throw MparticleInitException(
            code: MparticleInitErrorCodes.invalidOptions,
            message: 'bootstrapIdentityRequest value exceeds maximum length.',
          );
        }
      }
    }
  }

  static bool _isValidUrlScheme(String scheme) {
    final pattern = RegExp(r'^[a-z][a-z0-9+.-]*$');
    return pattern.hasMatch(scheme);
  }

  /// Serializes options for the native initialize method channel.
  ///
  /// Do not log the returned map — it contains credentials.
  Map<String, dynamic> toJson() {
    Map<String, String>? bootstrapIdentities;
    if (bootstrapIdentityRequest != null &&
        bootstrapIdentityRequest!.isNotEmpty) {
      bootstrapIdentities = {};
      for (final entry in bootstrapIdentityRequest!.entries) {
        bootstrapIdentities[entry.key.index.toString()] = entry.value;
      }
    }

    return {
      'apiKey': apiKey,
      'apiSecret': apiSecret,
      if (logLevel != MparticleLogLevel.warning) 'logLevel': logLevel.index,
      if (environment != MparticleEnvironment.autoDetect)
        'environment': environment.index,
      if (customBaseUrl != null) 'customBaseUrl': customBaseUrl,
      if (bootstrapIdentities != null)
        'bootstrapIdentityRequest': {'identities': bootstrapIdentities},
      if (ios != null) 'ios': ios!.toJson(),
    };
  }

  @override
  String toString() =>
      'MparticleOptions(apiKey: [REDACTED], apiSecret: [REDACTED])';
}

/// Stable error codes for initialization failures.
abstract final class MparticleInitErrorCodes {
  static const invalidCredentials = 'MP_INIT_INVALID_CREDENTIALS';
  static const alreadyStarted = 'MP_INIT_ALREADY_STARTED';
  static const invalidBaseUrl = 'MP_INIT_INVALID_BASE_URL';
  static const invalidOptions = 'MP_INIT_INVALID_OPTIONS';
  static const timeout = 'MP_INIT_TIMEOUT';
  static const unsupportedPlatform = 'MP_INIT_UNSUPPORTED_PLATFORM';
}

/// Thrown when mParticle initialization fails.
class MparticleInitException implements Exception {
  /// Creates an initialization exception with a stable [code].
  MparticleInitException({required this.code, required this.message});

  /// Stable error code matching native platform codes.
  final String code;

  /// User-facing message without credential or identity values.
  final String message;

  @override
  String toString() => 'MparticleInitException($code): $message';
}

/// Thrown when [MparticleFlutterSdk.initialize] is called with a different
/// apiKey after the SDK has already started.
class MparticleAlreadyInitializedException extends MparticleInitException {
  /// Creates an already-initialized exception.
  MparticleAlreadyInitializedException()
      : super(
          code: MparticleInitErrorCodes.alreadyStarted,
          message: 'mParticle is already initialized with a different apiKey.',
        );
}

/// Maps a [PlatformException] from the initialize channel to typed errors.
MparticleInitException mapInitExceptionFromPlatform(
    PlatformException exception) {
  final code = exception.code;
  if (code == MparticleInitErrorCodes.alreadyStarted) {
    return MparticleAlreadyInitializedException();
  }
  return MparticleInitException(
    code: code.isNotEmpty ? code : MparticleInitErrorCodes.invalidOptions,
    message: 'mParticle initialization failed.',
  );
}

/// Throws a typed initialization error mapped from [exception].
Never throwInitExceptionFromPlatform(PlatformException exception) {
  throw mapInitExceptionFromPlatform(exception);
}
