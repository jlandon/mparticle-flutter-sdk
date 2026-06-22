package com.mparticle.mparticle_flutter_sdk

import com.mparticle.MParticle

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
}
