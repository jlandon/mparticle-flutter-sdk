package com.mparticle.mparticle_flutter_sdk

import android.net.Uri
import com.mparticle.MParticle

internal sealed class CustomBaseUrlValidation {
  object Absent : CustomBaseUrlValidation()
  data class Valid(val url: String) : CustomBaseUrlValidation()
  data class Invalid(val reason: String) : CustomBaseUrlValidation()
}

internal object InitializeOptionsParser {
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
    val host = Uri.parse(trimmed).host
    if (host.isNullOrEmpty()) {
      return CustomBaseUrlValidation.Invalid("customBaseUrl is not a valid https URL")
    }
    return CustomBaseUrlValidation.Valid(trimmed)
  }
}
