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

    // MARK: 題號範圍格式 "X-Y:answers"

    @Test func rangeNotationParsesSequentially() {
        let key = makeKey([1: "A", 2: "B", 3: "D", 4: "A"])
        let sub = AnswerLogic.parseStudentSubmission("生\n1-4:ABDA", key: key)
        #expect(sub.answers[1] == "A")
        #expect(sub.answers[2] == "B")
        #expect(sub.answers[3] == "D")
        #expect(sub.answers[4] == "A")
        let result = AnswerLogic.buildResultText(submission: sub, key: key)
        #expect(result.contains("得分：4/4"))
        #expect(result.contains("訂正：無"))
    }

    @Test func rangeNotationMidSheet() {
        let key = makeKey([11: "B", 12: "D", 13: "C", 14: "C", 15: "C", 16: "A"])
        let sub = AnswerLogic.parseStudentSubmission("生\n11-15:BDCCC", key: key)
        #expect(sub.answers[11] == "B")
        #expect(sub.answers[15] == "C")
        // 不可污染範圍外的 Q16
        #expect(sub.answers[16] == nil)
    }

    @Test func threeDigitQuestionNumber() {
        let key = makeKey([100: "A"])
        let sub = AnswerLogic.parseStudentSubmission("生\n100 A", key: key)
        #expect(sub.answers[100] == "A")
    }

    // MARK: 單題號 + 全形括號，多題單行（確認既有行為不被破壞）

    @Test func multiQuestionColonParens() {
        let key = makeKey([5: "BC", 6: "AD", 7: "BC"])
        let sub = AnswerLogic.parseStudentSubmission("生\n5:（BC）6:（AD）7:（BC）", key: key)
        #expect(sub.answers[5] == "BC")
        #expect(sub.answers[6] == "AD")
        #expect(sub.answers[7] == "BC")
        #expect(AnswerLogic.buildResultText(submission: sub, key: key).contains("得分：3/3"))
    }

    // MARK: 全形英數正規化

    @Test func fullWidthAlphanumericNormalized() {
        let key = makeKey([1: "A", 2: "B", 3: "D", 4: "A"])
        let sub = AnswerLogic.parseStudentSubmission("生\n１-４：ＡＢＤＡ", key: key)
        #expect(sub.answers[1] == "A")
        #expect(sub.answers[4] == "A")
        #expect(AnswerLogic.buildResultText(submission: sub, key: key).contains("得分：4/4"))
    }

    // MARK: 真實案例回歸 — 第九回 40 題（含複選）

    @Test func realWorldNinthRound() {
        let key = makeKey([
            1: "A", 2: "B", 3: "D", 4: "A",
            5: "BC", 6: "AD", 7: "BC", 8: "BD", 9: "AC", 10: "AD",
            11: "B", 12: "D", 13: "C", 14: "C", 15: "C",
            16: "D", 17: "C", 18: "A", 19: "A", 20: "D",
            21: "C", 22: "A", 23: "C", 24: "D", 25: "B",
            26: "A", 27: "C", 28: "D", 29: "D", 30: "C",
            31: "C", 32: "D", 33: "C", 34: "B", 35: "B",
            36: "C", 37: "A", 38: "B", 39: "B", 40: "A",
        ])
        let raw = """
        陳妤萱/Alina/高中第九回
        1-4:ABDA
        5:（BC）6:（AD）7:（BC）
        8:（BD）9:（AC）10:（AD）
        11-15:BDCCC
        16-20:DCAAD
        21-25:CACDB
        26-30:ACDDC
        31-35:CDCBB
        36-40:CABBA
        """
        let sub = AnswerLogic.parseStudentSubmission(raw, key: key)
        let result = AnswerLogic.buildResultText(submission: sub, key: key)
        #expect(result.contains("得分：40/40"))
        #expect(result.contains("訂正：無"))
        #expect(!result.contains("缺答"))
    }
}
