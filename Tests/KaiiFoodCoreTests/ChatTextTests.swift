import XCTest
@testable import KaiiFoodCore

final class ChatTextTests: XCTestCase {
    func testReplyWithSpacedBoldAndBullets() {
        let value = ChatText.attributed("**今日概览： **\n* **蛋白质： **132 g\n\n下一餐正常吃。")
        XCTAssertEqual(String(value.characters), "今日概览：\n• 蛋白质：132 g\n\n下一餐正常吃。")
        XCTAssertTrue(value.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }
    func testHeadingsAndChineseSurvive() {
        XCTAssertEqual(String(ChatText.attributed("### 下一餐\n- 米饭\n- 鸡蛋").characters), "下一餐\n• 米饭\n• 鸡蛋")
    }
    func testOrdinaryTextAndUnclosedMarkupSurvive() {
        let source = "2 * 3 = 6\n还在生成 **蛋白质"
        XCTAssertEqual(String(ChatText.attributed(source).characters), source)
    }
}
