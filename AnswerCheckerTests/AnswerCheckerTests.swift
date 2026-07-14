//
//  AnswerCheckerTests.swift
//  AnswerCheckerTests
//
//  Created by Joey Lin on 2025/11/28.
//

import Testing
import Foundation
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

    // MARK: 錯題記錄與統計

    @Test func evaluateReportsWrongAndSkipped() {
        let key = makeKey([1: "A", 2: "B", 3: "C", 4: "D"])
        // Q1 對、Q2 錯、Q3 缺答、Q4 對
        let sub = AnswerLogic.parseStudentSubmission("生\n1 A\n2 C\n4 D", key: key)
        let e = AnswerLogic.evaluate(submission: sub, key: key)
        #expect(e.total == 4)
        #expect(e.wrong == [2])
        #expect(e.skipped == [3])
        #expect(e.correct == 2)
    }

    @Test func upsertReplacesSameName() {
        var recs: [StudentRecord] = []
        recs = AnswerLogic.upsertRecord(recs, name: "小明", wrong: [3, 1], total: 10)
        recs = AnswerLogic.upsertRecord(recs, name: "小華", wrong: [2], total: 10)
        #expect(recs.count == 2)
        #expect(recs[0].wrong == [1, 3])   // 已排序

        // 同名重對 → 覆蓋，不新增
        recs = AnswerLogic.upsertRecord(recs, name: "小明", wrong: [5], total: 10)
        #expect(recs.count == 2)
        let ming = recs.first { $0.name == "小明" }
        #expect(ming?.wrong == [5])
    }

    @Test func rankingCountsAndSorts() {
        let recs = [
            StudentRecord(name: "A", wrong: [1, 2], total: 5),
            StudentRecord(name: "B", wrong: [2, 3], total: 5),
            StudentRecord(name: "C", wrong: [2], total: 5),
        ]
        let ranking = AnswerLogic.questionErrorRanking(recs)
        // 第2題 3 人（最多），其次第1、第3 各 1 人（同人數依題號升冪）
        #expect(ranking.first?.q == 2)
        #expect(ranking.first?.count == 3)
        #expect(ranking.map { $0.q } == [2, 1, 3])
    }

    @Test func questionErrorNamesListsWhoMissed() {
        let recs = [
            StudentRecord(name: "小明", wrong: [1, 2], total: 5),
            StudentRecord(name: "小華", wrong: [2], total: 5),
            StudentRecord(name: "小美", wrong: [], total: 5),
        ]
        let byQ = AnswerLogic.questionErrorNames(recs)
        #expect(byQ.map { $0.q } == [1, 2])           // 依題號升冪、無 Q3（無人錯）
        #expect(byQ.first { $0.q == 1 }?.names == ["小明"])
        #expect(byQ.first { $0.q == 2 }?.names == ["小明", "小華"])
    }

    @Test func questionErrorNamesUsesEnglishName() {
        let recs = [
            StudentRecord(name: "陳妤萱/Alina/高中第九回", wrong: [1], total: 5),
            StudentRecord(name: "王小明/高中第九回", wrong: [1], total: 5),   // 無英文名 → 留中文
        ]
        let byQ = AnswerLogic.questionErrorNames(recs)
        #expect(byQ.first { $0.q == 1 }?.names == ["Alina", "王小明"])
    }

    @Test func statsTextContainsSections() {
        let recs = [
            StudentRecord(name: "小明", wrong: [1, 2], total: 5),
            StudentRecord(name: "小華", wrong: [2], total: 5),
        ]
        let text = AnswerLogic.buildStatsText(setName: "第九回", records: recs)
        #expect(text.contains("已記錄：2 位"))
        #expect(text.contains("各題錯誤名單"))
        #expect(text.contains("第 2 題（2 人）：小明, 小華"))
        #expect(text.contains("每位學生錯題"))
    }

    @Test func legacyAnswerSetDecodesWithoutRecords() throws {
        // 舊版 JSON 沒有 records 欄位，需能解碼且 records 為空
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","name":"預設","choiceKey":["A","B"]}"#
        let set = try JSONDecoder().decode(AnswerSet.self, from: Data(json.utf8))
        #expect(set.name == "預設")
        #expect(set.choiceKey == ["A", "B"])
        #expect(set.records.isEmpty)
    }

    // MARK: 起始題號

    @Test func evaluateRespectsStartQuestion() {
        let key = makeKey([1: "A", 51: "B"])
        let sub = AnswerLogic.parseStudentSubmission("生\n51 B", key: key, startQuestion: 51)
        let e = AnswerLogic.evaluate(submission: sub, key: key, startQuestion: 51)
        #expect(e.total == 1)          // 只算第 51 題，Q1 被忽略
        #expect(e.wrong.isEmpty)
        #expect(e.skipped.isEmpty)
    }

    @Test func startQuestionAvoidsFalseSkipped() {
        // key 誤填了 Q1、Q2（前段殘留），以及正式的 Q51
        let key = makeKey([1: "A", 2: "B", 51: "C"])
        // 學生只答第 51 題
        let sub = AnswerLogic.parseStudentSubmission("生\n51 C", key: key, startQuestion: 51)
        let result = AnswerLogic.buildResultText(submission: sub, key: key, startQuestion: 51)
        #expect(result.contains("得分：1/1"))
        #expect(!result.contains("缺答"))   // Q1、Q2 不應被算成缺答
    }

    @Test func autoQSeededFromStartQuestion() {
        let key = makeKey([51: "A", 52: "B", 53: "C", 54: "D"])
        // 無題號行，應從起始題號 51 接續
        let sub = AnswerLogic.parseStudentSubmission("生\nABCD", key: key, startQuestion: 51)
        #expect(sub.answers[51] == "A")
        #expect(sub.answers[54] == "D")
        #expect(AnswerLogic.buildResultText(submission: sub, key: key, startQuestion: 51).contains("得分：4/4"))
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
