import XCTest
@testable import KaiiFoodCore

final class AppLanguageTests: XCTestCase {
    func testSystemLanguageResolution() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-CN"]), .simplified)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-HK"]), .traditional)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-TW"]), .traditional)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]), .english)
    }
    func testExplicitChoiceWinsAndRawValueRoundTrips() {
        for language in [AppLanguage.english, .simplified, .traditional] {
            XCTAssertEqual(language.resolved(preferredLanguages: ["ja-JP"]), language)
            XCTAssertEqual(AppLanguage(rawValue: language.rawValue), language)
        }
    }
    func testAIResponseLanguages() {
        XCTAssertEqual(AppLanguage.english.responseLanguage, "English")
        XCTAssertEqual(AppLanguage.simplified.responseLanguage, "简体中文")
        XCTAssertEqual(AppLanguage.traditional.responseLanguage, "繁體中文")
    }
}
