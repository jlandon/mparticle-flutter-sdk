package com.mparticle.mparticle_flutter_sdk

import com.mparticle.MParticle
import java.net.URI

internal sealed class CustomBaseUrlValidation {
  object Absent : CustomBaseUrlValidation()
  data class Valid(val url: String) : CustomBaseUrlValidation()
  data class Invalid(val reason: String) : CustomBaseUrlValidation()
}

internal object InitializeOptionsParser {
  private const val MAX_BOOTSTRAP_IDENTITIES = 10
  private const val MAX_IDENTITY_VALUE_LENGTH = 256

  fun validateBootstrapIdentities(identityMap: Map<String, String>): String? {
    if (identityMap.size > MAX_BOOTSTRAP_IDENTITIES) {
      return "bootstrapIdentityRequest exceeds maximum identity count."
    }
    val parsedKeys = mutableSetOf<Int>()
    for ((key, value) in identityMap) {
      val intKey = key.toIntOrNull()
      if (intKey == null) {
        return "bootstrapIdentityRequest contains invalid identity keys."
      }
      if (!parsedKeys.add(intKey)) {
        return "bootstrapIdentityRequest contains duplicate identity keys."
      }
      if (value.isBlank()) {
        return "bootstrapIdentityRequest contains empty values."
      }
      if (value.length > MAX_IDENTITY_VALUE_LENGTH) {
        return "bootstrapIdentityRequest value exceeds maximum length."
      }
    }
    return null
  }

  fun parseLogLevel(index: Int): MParticle.LogLevel {
    return when (index) {
      0 -> MParticle.LogLevel.NONE
      1 -> MParticle.LogLevel.ERROR
      2 -> MParticle.LogLevel.WARNING
      3 -> MParticle.LogLevel.INFO
      4 -> MParticle.LogLevel.DEBUG
      5 -> MParticle.LogLevel.VERBOSE
      else -> MParticle.LogLevel.WARNING
    }
  }

  fun parseEnvironment(index: Int): MParticle.Environment {
    return when (index) {
      1 -> MParticle.Environment.Development
      2 -> MParticle.Environment.Production
      else -> MParticle.Environment.AutoDetect
    }
  }

  fun validateCustomBaseUrl(raw: String?): CustomBaseUrlValidation {
    if (raw.isNullOrBlank()) {
      return CustomBaseUrlValidation.Absent
    }
    val trimmed = raw.trim()
    if (!trimmed.startsWith("https://", ignoreCase = true)) {
      return CustomBaseUrlValidation.Invalid("customBaseUrl must use https://")
    }
    val host = try {
      URI(trimmed).host
    } catch (_: Exception) {
      null
    }
    if (host.isNullOrEmpty()) {
      return CustomBaseUrlValidation.Invalid("customBaseUrl is not a valid https URL")
    }
    return CustomBaseUrlValidation.Valid(trimmed)
  }
}
