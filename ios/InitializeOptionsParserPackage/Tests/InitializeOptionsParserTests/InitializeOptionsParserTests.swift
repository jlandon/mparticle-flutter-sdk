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
}
