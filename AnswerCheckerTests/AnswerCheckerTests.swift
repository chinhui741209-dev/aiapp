//
//  AnswerCheckerTests.swift
//  AnswerCheckerTests
//
//  Created by Joey Lin on 2025/11/28.
//

import Testing
@testable import AnswerChecker

struct AnswerCheckerTests {

    // 建立一個 100 元素的 key，依 (題號:答案) 設定。
    private func makeKey(_ entries: [Int: String]) -> [String] {
        var key = Array(repeating: "", count: AnswerLogic.totalChoiceQuestions)
        for (q, a) in entries { key[q - 1] = a }
        return key
    }

    // MARK: normalizeAnswer

    @Test func normalizeSortsAndDedupes() {
        #expect(AnswerLogic.normalizeAnswer("CA") == "AC")
        #expect(AnswerLogic.normalizeAnswer("acA") == "AC")
        #expect(AnswerLogic.normalizeAnswer("xyz") == "")
    }

    // MARK: 需求1 - 連續字串非從 Q1 起算

    @Test func concatenatedStringStartingAtNon1() {
        // key Q21..Q24 = B,C,D,A（皆單選）
        let key = makeKey([21: "B", 22: "C", 23: "D", 24: "A"])
        let sub = AnswerLogic.parseStudentSubmission("王小明\n21 BCDA", key: key)
        #expect(sub.answers[21] == "B")
        #expect(sub.answers[22] == "C")
        #expect(sub.answers[23] == "D")
        #expect(sub.answers[24] == "A")

        let result = AnswerLogic.buildResultText(submission: sub, key: key)
        #expect(result.contains("得分：4/4"))
        #expect(result.contains("訂正：無"))
    }

    // MARK: 需求1 - 學生從中間題號開始（明確題號）

    @Test func numberedAnswersFromMiddle() {
        let key = makeKey([21: "B", 22: "D"])
        let sub = AnswerLogic.parseStudentSubmission("生\n21 B\n22 D", key: key)
        #expect(sub.answers[21] == "B")
        #expect(sub.answers[22] == "D")
        #expect(AnswerLogic.buildResultText(submission: sub, key: key).contains("得分：2/2"))
    }

    // MARK: 需求1 - 標準答案題號跳號

    @Test func skippedQuestionNumbersInKey() {
        // 只填 Q5、Q10
        let key = makeKey([5: "A", 10: "C"])
        // 學生答 Q5=A（對）、Q10=B（錯）
        let sub = AnswerLogic.parseStudentSubmission("生\n5 A\n10 B", key: key)
        let result = AnswerLogic.buildResultText(submission: sub, key: key)
        #expect(result.contains("得分：1/2"))
        #expect(result.contains("訂正：10"))
    }

    // MARK: 需求1 - 複選對齊

    @Test func multiAnswerAlignment() {
        // Q1 複選 "AC"、Q2 單選 "B"
        let key = makeKey([1: "AC", 2: "B"])
        let sub = AnswerLogic.parseStudentSubmission("生\n1 ACB", key: key)
        #expect(sub.answers[1] == "AC")
        #expect(sub.answers[2] == "B")
        #expect(AnswerLogic.buildResultText(submission: sub, key: key).contains("得分：2/2"))
    }

    // MARK: 缺答

    @Test func skippedAnswersReported() {
        let key = makeKey([1: "A", 2: "B", 3: "C"])
        let sub = AnswerLogic.parseStudentSubmission("生\n1 A", key: key)
        let result = AnswerLogic.buildResultText(submission: sub, key: key)
        #expect(result.contains("得分：1/3"))
        #expect(result.contains("缺答：2, 3"))
    }

    // MARK: 無題號 Gary 格式從 autoQ=1 接續

    @Test func answerOnlyLineFromStart() {
        let key = makeKey([1: "A", 2: "B", 3: "C", 4: "D"])
        let sub = AnswerLogic.parseStudentSubmission("生\nABCD", key: key)
        #expect(sub.answers[1] == "A")
        #expect(sub.answers[4] == "D")
        #expect(AnswerLogic.buildResultText(submission: sub, key: key).contains("得分：4/4"))
    }
}
