import 'dart:convert';

/// Web JS identity mapping helpers — not [package:mparticle_flutter_sdk/src/identity/identity_helpers.dart].
///
/// Pure Dart conversions and wire-format builders for the web platform.
/// JS interop orchestration lives in `identity_web.dart`.

const identityPlatformWeb = 'web';

String? convertIntIdentityToStringIdentity(int identityType) {
  switch (identityType) {
    case 0:
      return 'other';
    case 1:
      return 'customerid';
    case 2:
      return 'facebook';
    case 3:
      return 'twitter';
    case 4:
      return 'google';
    case 5:
      return 'microsoft';
    case 6:
      return 'yahoo';
    case 7:
      return 'email';
    case 9:
      return 'facebookcustomaudienceid';
    case 10:
      return 'other2';
    case 11:
      return 'other3';
    case 12:
      return 'other4';
    case 13:
      return 'other5';
    case 14:
      return 'other6';
    case 15:
      return 'other7';
    case 16:
      return 'other8';
    case 17:
      return 'other9';
    case 18:
      return 'other10';
    case 19:
      return 'mobile_number';
    case 20:
      return 'phone_number_2';
    case 21:
      return 'phone_number_3';
    default:
      return null;
  }
}

Map<String, dynamic> createWebIdentityRequest(
    Map<dynamic, dynamic> identitiesKeyedOnType) {
  final identitiesKeyedOnString = <String, dynamic>{};
  identitiesKeyedOnType.forEach((key, value) {
    final identityIndex = key is int ? key : int.tryParse(key.toString());
    if (identityIndex == null) {
      return;
    }
    final identity = convertIntIdentityToStringIdentity(identityIndex);
    if (identity != null) {
      identitiesKeyedOnString[identity] = value;
    }
  });
  return {'userIdentities': identitiesKeyedOnString};
}

String? convertIdentityNameToStringifiedNumber(String identityName) {
  switch (identityName) {
    case 'other':
      return '0';
    case 'customerid':
      return '1';
    case 'facebook':
      return '2';
    case 'twitter':
      return '3';
    case 'google':
      return '4';
    case 'microsoft':
      return '5';
    case 'yahoo':
      return '6';
    case 'email':
      return '7';
    case 'facebookcustomaudienceid':
      return '9';
    case 'other2':
      return '10';
    case 'other3':
      return '11';
    case 'other4':
      return '12';
    case 'other5':
      return '13';
    case 'other6':
      return '14';
    case 'other7':
      return '15';
    case 'other8':
      return '16';
    case 'other9':
      return '17';
    case 'other10':
      return '18';
    case 'mobile_number':
      return '19';
    case 'phone_number_2':
      return '20';
    case 'phone_number_3':
      return '21';
    default:
      return null;
  }
}

/// Computes alias window bounds from user seen times and SDK config.
AliasWindowResult computeAliasWindow({
  required int nowMs,
  required int aliasMaxWindowDays,
  required int startTime,
  required int? endTime,
}) {
  final aliasMaxWindowInMs = aliasMaxWindowDays * 24 * 60 * 60 * 1000;
  final minFirstSeenTimeMs = nowMs - aliasMaxWindowInMs;
  var resolvedEndTime = endTime ?? nowMs;
  var resolvedStartTime = startTime;
  var warnOutsideWindow = false;

  if (resolvedStartTime < minFirstSeenTimeMs) {
    resolvedStartTime = minFirstSeenTimeMs;
    if (resolvedEndTime < resolvedStartTime) {
      warnOutsideWindow = true;
    }
  }

  return AliasWindowResult(
    startTime: resolvedStartTime,
    endTime: resolvedEndTime,
    warnOutsideWindow: warnOutsideWindow,
    aliasMaxWindowDays: aliasMaxWindowDays,
  );
}

final class AliasWindowResult {
  const AliasWindowResult({
    required this.startTime,
    required this.endTime,
    required this.warnOutsideWindow,
    required this.aliasMaxWindowDays,
  });

  final int startTime;
  final int endTime;
  final bool warnOutsideWindow;
  final int aliasMaxWindowDays;
}

Map<String, dynamic> remapGdprConsentMap(Map<dynamic, dynamic> source) {
  final result = <String, dynamic>{};
  source.forEach((purpose, value) {
    if (value is! Map) {
      return;
    }
    result[purpose.toString()] = {
      'consented': value['Consented'],
      'document': value['Document'],
      'location': value['Location'],
      'hardwareId': value['HardwareId'],
      'timestamp': value['Timestamp'],
    };
  });
  return result;
}

Map<String, dynamic> remapCcpaConsentMap(Map<dynamic, dynamic> source) {
  return {
    'consented': source['Consented'],
    'document': source['Document'],
    'location': source['Location'],
    'hardwareId': source['HardwareId'],
    'timestamp': source['Timestamp'],
  };
}

/// Builds identity MethodChannel JSON for all [httpCode] branches.
String buildIdentityResultJson({
  required int? httpCode,
  required String? mpid,
  required String? previousMpid,
  required Object? body,
  required List<Map<String, String?>>? errors,
  required String identityMethod,
  void Function(int httpCode)? onUnknownHttpCode,
}) {
  var resolvedHttpCode = httpCode;
  List<Map<String, String?>>? resolvedErrors = errors;

  switch (httpCode) {
    case 200:
      resolvedErrors = null;
      break;
    case 400:
    case 401:
    case 429:
      break;
    case -1:
    case -2:
    case -3:
    case -4:
    case -5:
      resolvedErrors = [
        {'code': httpCode.toString(), 'message': body?.toString()},
      ];
      resolvedHttpCode = null;
      break;
    default:
      if (httpCode != null && httpCode >= 500) {
        if (body is Map && body['errors'] is List) {
          resolvedErrors = (body['errors'] as List)
              .map((error) {
                if (error is Map) {
                  return {
                    'code': error['code']?.toString(),
                    'message': error['message']?.toString(),
                  };
                }
                return {'code': null, 'message': error?.toString()};
              })
              .cast<Map<String, String?>>()
              .toList();
        }
      } else if (httpCode != null) {
        onUnknownHttpCode?.call(httpCode);
      }
  }

  if (httpCode != 200) {
    resolvedErrors ??= [];
    if (resolvedErrors.isEmpty) {
      final fallbackCode =
          resolvedHttpCode?.toString() ?? httpCode?.toString() ?? 'unknown';
      resolvedErrors = [
        {
          'code': fallbackCode,
          'message': body?.toString() ?? 'Identity request failed',
        },
      ];
    }
  }

  final identityResult = <String, dynamic>{
    'mpid': mpid,
    'http_code': resolvedHttpCode,
    'platform': identityPlatformWeb,
  };

  if (httpCode == 200 && identityMethod != 'modify') {
    identityResult['previous_mpid'] = previousMpid;
  }

  if (resolvedErrors != null) {
    identityResult['errors'] = resolvedErrors;
  }

  return jsonEncode(identityResult);
}

/// Timeout identity envelope matching client error code `-1`.
String buildIdentityTimeoutJson() => buildIdentityResultJson(
      httpCode: -1,
      mpid: null,
      previousMpid: null,
      body: 'Identity callback timed out',
      errors: null,
      identityMethod: 'identify',
    );

List<Map<String, String?>> convertDartErrorList(Object? errorsValue) {
  if (errorsValue is! List) {
    return [];
  }
  return errorsValue
      .map((error) {
        if (error is Map) {
          return {
            'code': error['code']?.toString(),
            'message': error['message']?.toString(),
          };
        }
        return {'code': null, 'message': error?.toString()};
      })
      .cast<Map<String, String?>>()
      .toList();
}

Map<String, dynamic> identitiesNameMapToStringKeyMap(
  Map<dynamic, dynamic> userIdentitiesMapKeyedByIdentityName,
) {
  final userIdentitiesMapKeyedByStringifiedNumber = <String, dynamic>{};
  userIdentitiesMapKeyedByIdentityName.forEach((key, value) {
    final stringKey = convertIdentityNameToStringifiedNumber(key.toString());
    if (stringKey != null) {
      userIdentitiesMapKeyedByStringifiedNumber[stringKey] = value;
    }
  });
  return userIdentitiesMapKeyedByStringifiedNumber;
}
