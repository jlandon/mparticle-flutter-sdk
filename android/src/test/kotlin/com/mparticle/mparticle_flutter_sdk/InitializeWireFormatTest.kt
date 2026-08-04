package com.mparticle.mparticle_flutter_sdk

import com.mparticle.MParticle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class InitializeWireFormatTest {
    @Test
    fun parseLogLevel_mapsDartEnumIndices() {
        assertEquals(MParticle.LogLevel.NONE, InitializeOptionsParser.parseLogLevel(0))
        assertEquals(MParticle.LogLevel.ERROR, InitializeOptionsParser.parseLogLevel(1))
        assertEquals(MParticle.LogLevel.WARNING, InitializeOptionsParser.parseLogLevel(2))
        assertEquals(MParticle.LogLevel.INFO, InitializeOptionsParser.parseLogLevel(3))
        assertEquals(MParticle.LogLevel.DEBUG, InitializeOptionsParser.parseLogLevel(4))
        assertEquals(MParticle.LogLevel.VERBOSE, InitializeOptionsParser.parseLogLevel(5))
    }

    @Test
    fun parseLogLevel_unknownIndexDefaultsToWarning() {
        assertEquals(MParticle.LogLevel.WARNING, InitializeOptionsParser.parseLogLevel(99))
    }

    @Test
    fun parseEnvironment_mapsDartEnumIndices() {
        assertEquals(MParticle.Environment.AutoDetect, InitializeOptionsParser.parseEnvironment(0))
        assertEquals(MParticle.Environment.Development, InitializeOptionsParser.parseEnvironment(1))
        assertEquals(MParticle.Environment.Production, InitializeOptionsParser.parseEnvironment(2))
    }

    @Test
    fun parseEnvironment_unknownIndexDefaultsToAutoDetect() {
        assertEquals(MParticle.Environment.AutoDetect, InitializeOptionsParser.parseEnvironment(99))
    }

    @Test
    fun validateCustomBaseUrl_acceptsValidHttpsUrl() {
        val result = InitializeOptionsParser.validateCustomBaseUrl("https://cdn.example.com")
        assertTrue(result is CustomBaseUrlValidation.Valid)
        assertEquals("https://cdn.example.com", (result as CustomBaseUrlValidation.Valid).url)
    }

    @Test
    fun validateCustomBaseUrl_absentForNullOrBlank() {
        assertTrue(InitializeOptionsParser.validateCustomBaseUrl(null) is CustomBaseUrlValidation.Absent)
        assertTrue(InitializeOptionsParser.validateCustomBaseUrl("  ") is CustomBaseUrlValidation.Absent)
    }

    @Test
    fun validateCustomBaseUrl_rejectsNonHttps() {
        val result = InitializeOptionsParser.validateCustomBaseUrl("http://insecure.example")
        assertTrue(result is CustomBaseUrlValidation.Invalid)
        assertEquals("customBaseUrl must use https://", (result as CustomBaseUrlValidation.Invalid).reason)
    }

  @Test
  fun validateCustomBaseUrl_rejectsHttpsWithoutHost() {
    val result = InitializeOptionsParser.validateCustomBaseUrl("https://")
    assertTrue(result is CustomBaseUrlValidation.Invalid)
    assertEquals(
      "customBaseUrl is not a valid https URL",
      (result as CustomBaseUrlValidation.Invalid).reason,
    )
  }

  @Test
  fun validateBootstrapIdentities_rejectsInvalidKeys() {
    val error =
        InitializeOptionsParser.validateBootstrapIdentities(mapOf("email" to "a@b.com"))
    assertEquals("bootstrapIdentityRequest contains invalid identity keys.", error)
  }

  @Test
  fun validateBootstrapIdentities_rejectsMoreThanTenIdentities() {
    val identities = (0 until 11).associate { it.toString() to "value-$it" }
    val error = InitializeOptionsParser.validateBootstrapIdentities(identities)
    assertEquals("bootstrapIdentityRequest exceeds maximum identity count.", error)
  }

  @Test
  fun validateBootstrapIdentities_rejectsValuesOver256Characters() {
    val error =
        InitializeOptionsParser.validateBootstrapIdentities(mapOf("7" to "x".repeat(257)))
    assertEquals("bootstrapIdentityRequest value exceeds maximum length.", error)
  }
}
