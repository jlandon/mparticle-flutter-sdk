import XCTest
import InitializeOptionsParser

final class InitializeOptionsParserTests: XCTestCase {
  func testParseLogLevel_mapsDartEnumIndices() {
    XCTAssertEqual(InitializeOptionsParser.parseLogLevelRawValue(0), 0)
    XCTAssertEqual(InitializeOptionsParser.parseLogLevelRawValue(1), 1)
    XCTAssertEqual(InitializeOptionsParser.parseLogLevelRawValue(2), 2)
    XCTAssertEqual(InitializeOptionsParser.parseLogLevelRawValue(3), 3)
    XCTAssertEqual(InitializeOptionsParser.parseLogLevelRawValue(4), 3)
    XCTAssertEqual(InitializeOptionsParser.parseLogLevelRawValue(5), 4)
  }

  func testParseLogLevel_unknownIndexDefaultsToWarning() {
    XCTAssertEqual(InitializeOptionsParser.parseLogLevelRawValue(99), 2)
  }

  func testParseEnvironment_mapsDartEnumIndices() {
    XCTAssertEqual(InitializeOptionsParser.parseEnvironmentRawValue(0), 0)
    XCTAssertEqual(InitializeOptionsParser.parseEnvironmentRawValue(1), 1)
    XCTAssertEqual(InitializeOptionsParser.parseEnvironmentRawValue(2), 2)
  }

  func testParseEnvironment_unknownIndexDefaultsToAutoDetect() {
    XCTAssertEqual(InitializeOptionsParser.parseEnvironmentRawValue(99), 0)
  }

  func testValidateBootstrapIdentities_rejectsInvalidKeys() {
    let error = InitializeOptionsParser.validateBootstrapIdentities(["email": "a@b.com"])
    XCTAssertEqual(error, "bootstrapIdentityRequest contains invalid identity keys.")
  }

  func testValidateBootstrapIdentities_rejectsMoreThanTenIdentities() {
    var identities: [String: String] = [:]
    for index in 0..<11 {
      identities[String(index)] = "value-\(index)"
    }
    let error = InitializeOptionsParser.validateBootstrapIdentities(identities)
    XCTAssertEqual(error, "bootstrapIdentityRequest exceeds maximum identity count.")
  }

  func testValidateBootstrapIdentities_rejectsValuesOver256Characters() {
    let error = InitializeOptionsParser.validateBootstrapIdentities(["7": String(repeating: "x", count: 257)])
    XCTAssertEqual(error, "bootstrapIdentityRequest value exceeds maximum length.")
  }

  func testValidateBootstrapIdentities_rejectsDuplicateIntegerKeys() {
    let error = InitializeOptionsParser.validateBootstrapIdentities(["1": "first", "01": "second"])
    XCTAssertEqual(error, "bootstrapIdentityRequest contains duplicate identity keys.")
  }
}
