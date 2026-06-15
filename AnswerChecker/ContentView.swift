import SwiftUI
import UIKit

// MARK: - Step2：學生解析結果
struct StudentSubmission {
    var headerLine: String = ""             // 姓名/英文名/科目
    var answers: [Int: String] = [:]        // 題號 -> "A"/"AC"
}

// MARK: - 一組具名標準答案
struct AnswerSet: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var choiceKey: [String]                 // 100 元素，index 0 = Q1
}

// MARK: - 主畫面
struct ContentView: View {
    // MARK: Steps
    @State private var step: Int = 1

    // MARK: Step1：選擇題標準答案（01-100）
    private let totalChoiceQuestions = 100
    private let cols = 10
    private var rows: Int { totalChoiceQuestions / cols } // 10

    // ✅ 永久保存（除非按清空）
    // 舊版單組 key（僅供遷移用）
    @AppStorage("AnswerChecker.choiceKeyJSON") private var choiceKeyJSON: String = ""
    // 多組答案
    @AppStorage("AnswerChecker.answerSetsJSON") private var answerSetsJSON: String = ""
    @AppStorage("AnswerChecker.selectedSetID") private var selectedSetIDString: String = ""

    @State private var answerSets: [AnswerSet] = []
    @State private var selectedSetID: UUID = UUID()
    @FocusState private var focusedChoiceIndex: Int?

    // 目前選中那組在陣列中的索引（永遠保持至少一組）
    private var selectedSetIndex: Int {
        answerSets.firstIndex(where: { $0.id == selectedSetID }) ?? 0
    }

    // 目前選中那組的標準答案（讀取用）
    private var choiceKey: [String] {
        guard answerSets.indices.contains(selectedSetIndex) else {
            return Array(repeating: "", count: totalChoiceQuestions)
        }
        return answerSets[selectedSetIndex].choiceKey
    }

    // 設定目前選中那組的某一題答案
    private func setChoiceKey(_ value: String, at index: Int) {
        guard answerSets.indices.contains(selectedSetIndex),
              answerSets[selectedSetIndex].choiceKey.indices.contains(index) else { return }
        answerSets[selectedSetIndex].choiceKey[index] = value
    }

    // MARK: Step2：學生貼上
    @State private var studentRawText: String = ""

    // MARK: Step3：輸出
    @State private var resultText: String = ""
    @State private var showCopyToast: Bool = false

    // MARK: 組別管理 UI
    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBar

                Picker("", selection: $step) {
                    Text("答案鍵").tag(1)
                    Text("作答").tag(2)
                    Text("訂正").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.top, 10)

                Divider().padding(.top, 10)

                Group {
                    if step == 1 { step1View }
                    else if step == 2 { step2View }
                    else { step3View }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay(alignment: .bottom) {
                if showCopyToast {
                    Text("已複製到剪貼簿")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 28)
                        .transition(.opacity)
                }
            }
        }
        // ✅ 啟動載入多組答案（含舊資料遷移）
        .onAppear { loadAnswerSetsIfNeeded() }
        // ✅ 任意更動自動保存
        .onChange(of: answerSets) { _, _ in persistAnswerSets() }
        .onChange(of: selectedSetID) { _, _ in selectedSetIDString = selectedSetID.uuidString }
    }
}

// MARK: - Header
private extension ContentView {
    var headerBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("對答案小工具")
                    .font(.system(size: 26, weight: .bold))
                Text(step == 1 ? "設定標準答案" : step == 2 ? "貼上學生作答" : "查看訂正結果")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            // Step1：進入作答 / 清空
            if step == 1 {
                Button {
                    dismissKeyboard()
                    step = 2
                } label: {
                    Label("作答", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    clearStep1All()
                    dismissKeyboard()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }

            // Step2：清空貼上
            if step == 2 {
                Button {
                    studentRawText = ""
                    dismissKeyboard()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }

            // Step3：複製
            if step == 3 {
                Button {
                    UIPasteboard.general.string = resultText
                    toastCopied()
                } label: {
                    Label("複製", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }
}

// MARK: - Step1 View（選擇題標準答案）
private extension ContentView {
    var step1View: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 16
            let rowLabelWidth: CGFloat = 36
            let cellSpacing: CGFloat = (geo.size.width < 390) ? 5 : 7
            let gridAvailableWidth = geo.size.width - horizontalPadding * 2 - rowLabelWidth - 10
            let cellWidth = max(24, min(34, (gridAvailableWidth - cellSpacing * CGFloat(cols - 1)) / CGFloat(cols)))
            let cellHeight = max(36, min(44, cellWidth + 10))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // 組別列
                        answerSetBar
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 12)

                        // 進度列
                        let filled = choiceKey.filter { !$0.isEmpty }.count
                        HStack {
                            Text("標準答案")
                                .font(.title3.bold())
                            Spacer()
                            Text("\(filled) / \(totalChoiceQuestions)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(filled == totalChoiceQuestions ? Color.accentColor : .secondary)
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 12)

                        // 進度條
                        GeometryReader { bar in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor)
                                    .frame(width: bar.size.width * CGFloat(filled) / CGFloat(totalChoiceQuestions),
                                           height: 4)
                                    .animation(.easeInOut(duration: 0.2), value: filled)
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, horizontalPadding)

                        // 答案格 grid
                        ForEach(0..<rows, id: \.self) { r in
                            let startQ = 1 + r * cols
                            HStack(spacing: 8) {
                                Text(String(format: "%02d", startQ))
                                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: rowLabelWidth, alignment: .leading)

                                HStack(spacing: cellSpacing) {
                                    ForEach(0..<cols, id: \.self) { c in
                                        let idx = (startQ + c) - 1
                                        ChoiceBoxCellCompact(
                                            text: Binding(
                                                get: { choiceKey[idx] },
                                                set: { handleKeyInput(index: idx, newValue: $0) }
                                            ),
                                            width: cellWidth,
                                            height: cellHeight
                                        )
                                        .focused($focusedChoiceIndex, equals: idx)
                                        .id(idx)
                                    }
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                        }

                        Spacer().frame(height: 120)
                    }
                    .onChange(of: focusedChoiceIndex) { _, newValue in
                        if let idx = newValue {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if let idx = focusedChoiceIndex {
                            Text("Q\(String(format: "%02d", idx + 1))")
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 36)

                            Spacer()

                            ForEach(["A", "B", "C", "D"], id: \.self) { letter in
                                let isOn = choiceKey[idx].contains(letter)
                                Button {
                                    toggleLetter(letter, at: idx)
                                } label: {
                                    Text(letter)
                                        .font(.system(.body, design: .monospaced).weight(.semibold))
                                        .frame(minWidth: 32, minHeight: 28)
                                        .foregroundStyle(isOn ? Color.white : Color.primary)
                                        .background(
                                            RoundedRectangle(cornerRadius: 7)
                                                .fill(isOn ? Color.accentColor : Color(.systemGray5))
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            Button {
                                if let idx = focusedChoiceIndex { setChoiceKey("", at: idx) }
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(Color.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)

                            Button {
                                if let idx = focusedChoiceIndex {
                                    let next = idx + 1
                                    focusedChoiceIndex = next < totalChoiceQuestions ? next : nil
                                }
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: 組別列
    var answerSetBar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(answerSets) { set in
                    Button {
                        selectedSetID = set.id
                        focusedChoiceIndex = nil
                    } label: {
                        if set.id == selectedSetID {
                            Label(set.name, systemImage: "checkmark")
                        } else {
                            Text(set.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text(answerSets.indices.contains(selectedSetIndex)
                         ? answerSets[selectedSetIndex].name : "—")
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5))
                )
            }

            Spacer()

            Button {
                addAnswerSet()
            } label: {
                Image(systemName: "plus.circle.fill").font(.title3)
            }

            Menu {
                Button {
                    renameText = answerSets.indices.contains(selectedSetIndex)
                        ? answerSets[selectedSetIndex].name : ""
                    showRenameAlert = true
                } label: {
                    Label("重新命名", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("刪除這組", systemImage: "trash")
                }
                .disabled(answerSets.count <= 1)
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3)
            }
        }
        .alert("重新命名", isPresented: $showRenameAlert) {
            TextField("組別名稱", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("儲存") { renameSelectedSet(to: renameText) }
        }
        .confirmationDialog("確定刪除這組標準答案？",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("刪除", role: .destructive) { deleteSelectedSet() }
            Button("取消", role: .cancel) {}
        }
    }

    func handleKeyInput(index: Int, newValue: String) {
        let normalized = AnswerLogic.normalizeAnswer(newValue)
        let wasEmpty = choiceKey[index].isEmpty
        setChoiceKey(normalized, at: index)

        if wasEmpty, !normalized.isEmpty {
            DispatchQueue.main.async {
                let next = index + 1
                focusedChoiceIndex = (next < totalChoiceQuestions) ? next : nil
            }
        }
    }

    func toggleLetter(_ letter: String, at index: Int) {
        let current = choiceKey[index]
        if current.contains(letter) {
            setChoiceKey(AnswerLogic.normalizeAnswer(current.filter { String($0) != letter }), at: index)
        } else {
            setChoiceKey(AnswerLogic.normalizeAnswer(current + letter), at: index)
        }
    }

    // MARK: 組別管理

    /// 新增一組空白答案並選中。
    func addAnswerSet() {
        let name = "答案 \(answerSets.count + 1)"
        let set = AnswerSet(name: name,
                            choiceKey: Array(repeating: "", count: totalChoiceQuestions))
        answerSets.append(set)
        selectedSetID = set.id
        focusedChoiceIndex = nil
    }

    /// 重新命名目前選中組。
    func renameSelectedSet(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, answerSets.indices.contains(selectedSetIndex) else { return }
        answerSets[selectedSetIndex].name = trimmed
    }

    /// 刪除目前選中組；若刪到剩 0 則補一組空白。
    func deleteSelectedSet() {
        guard answerSets.indices.contains(selectedSetIndex) else { return }
        let removingIndex = selectedSetIndex
        answerSets.remove(at: removingIndex)
        if answerSets.isEmpty {
            let fresh = AnswerSet(name: "答案 1",
                                  choiceKey: Array(repeating: "", count: totalChoiceQuestions))
            answerSets = [fresh]
            selectedSetID = fresh.id
        } else {
            let newIndex = min(removingIndex, answerSets.count - 1)
            selectedSetID = answerSets[newIndex].id
        }
        focusedChoiceIndex = nil
    }

    /// ✅ 清空目前選中組的格子（保留該組，不刪除）
    func clearStep1All() {
        guard answerSets.indices.contains(selectedSetIndex) else { return }
        answerSets[selectedSetIndex].choiceKey = Array(repeating: "", count: totalChoiceQuestions)
        focusedChoiceIndex = nil
    }
}

// MARK: - Step2 View
private extension ContentView {
    var step2View: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("貼上學生作答（支援多種格式）")
                .font(.title3.bold())
                .padding(.horizontal, 14)
                .padding(.top, 10)

            // 對答案組別選擇
            HStack(spacing: 8) {
                Text("對答案組別")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("對答案組別", selection: $selectedSetID) {
                    ForEach(answerSets) { set in
                        Text(set.name).tag(set.id)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }
            .padding(.horizontal, 14)

            HStack(spacing: 10) {
                Button {
                    let key = choiceKey
                    let submission = AnswerLogic.parseStudentSubmission(studentRawText, key: key)
                    resultText = AnswerLogic.buildResultText(submission: submission, key: key)
                    step = 3
                    dismissKeyboard()
                } label: {
                    Label("產生訂正", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    studentRawText = ""
                    dismissKeyboard()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 14)

            TextEditor(text: $studentRawText)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.25))
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            Spacer()
        }
    }
}

// MARK: - Step3 View
private extension ContentView {
    var step3View: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("訂正結果")
                .font(.title3.bold())
                .padding(.horizontal, 14)
                .padding(.top, 10)

            ScrollView {
                Text(resultText.isEmpty ? "（尚未產生結果，請先到 Step2）" : resultText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.25))
            )
            .padding(.horizontal, 14)

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = resultText
                    toastCopied()
                } label: {
                    Label("複製文字", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    step = 2
                } label: {
                    Text("回 Step2")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Spacer()
        }
    }
}

// MARK: - 答案解析 / 比對純邏輯（可測試）
enum AnswerLogic {
    static let totalChoiceQuestions = 100

    static func parseStudentSubmission(_ raw: String, key: [String]) -> StudentSubmission {
        var sub = StudentSubmission()

        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        guard !lines.isEmpty else { return sub }
        sub.headerLine = lines[0]

        var autoQ = 1   // 無題號行（Gary格式）時從此接續

        for i in 1..<lines.count {
            let line = normalizeWidth(lines[i])
            if line.isEmpty { continue }

            if let (startQ, remainder) = extractLeadingNumber(line) {
                // 有題號行："01 CABCC…" 或 "1 CACCC…"
                let parsed = parseAnswerLine(startQ: startQ, remainder: remainder, key: key)
                for (q, a) in parsed where (1...totalChoiceQuestions).contains(q) {
                    sub.answers[q] = a
                }
                if let maxQ = parsed.keys.max() { autoQ = maxQ + 1 }

            } else if isAnswerOnlyLine(line) {
                // 無題號行（只含 A/B/C/D 與空格），從 autoQ 接續
                let parsed = parseAnswerLine(startQ: autoQ, remainder: line, key: key)
                for (q, a) in parsed where (1...totalChoiceQuestions).contains(q) {
                    sub.answers[q] = a
                }
                if let maxQ = parsed.keys.max() { autoQ = maxQ + 1 }
            }
            // else: 多行表頭的延續（如科目名稱）→ 跳過
        }
        return sub
    }

    /// 行首為題號（1–3 位數）時，回傳 (startQ, remainder)。
    /// 支援：
    /// - "01 CABCC…"、"1 CACCC…"、"100 A"（單一題號，題號可達 3 位數）
    /// - "1-4:ABDA"、"11-15 BDCCC"、全形冒號（題號範圍）：取起始題號，
    ///   捨棄結束題號與冒號，其餘作答交給逐題 key-guided 切字。
    static func extractLeadingNumber(_ line: String) -> (Int, String)? {
        // 題號範圍："X-Y[:]answers"——連字號支援 - – — ~ ～，冒號支援 : ：
        let rangePattern = #"^(\d{1,3})\s*[-–—~～]\s*\d{1,3}\s*[:：]?\s*(.*)$"#
        if let re = try? NSRegularExpression(pattern: rangePattern),
           let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let ns = line as NSString
            if let q = Int(ns.substring(with: m.range(at: 1))) {
                return (q, ns.substring(with: m.range(at: 2)))
            }
        }

        // 單一題號（可達 3 位數，涵蓋 Q100）
        let pattern = #"^(\d{1,3})\s*(.*)"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
        else { return nil }
        let ns = line as NSString
        guard let q = Int(ns.substring(with: m.range(at: 1))) else { return nil }
        let rest = ns.substring(with: m.range(at: 2))
        return (q, rest)
    }

    /// 全形數字 / 英文字母 → 半形（其餘字元不動）。
    /// 讓學生貼上的全形英數（如 "１-４：ＡＢＤＡ"）也能正確解析；
    /// 全形括號、冒號分別由 tokenize 忽略 / 範圍偵測處理，不需在此清除。
    static func normalizeWidth(_ s: String) -> String {
        let mapped = s.unicodeScalars.map { scalar -> Character in
            let v = scalar.value
            // 全形 ０–９ (U+FF10–FF19)、Ａ–Ｚ (U+FF21–FF3A)、ａ–ｚ (U+FF41–FF5A)
            if (0xFF10...0xFF19).contains(v) || (0xFF21...0xFF3A).contains(v) || (0xFF41...0xFF5A).contains(v),
               let half = Unicode.Scalar(v - 0xFEE0) {
                return Character(half)
            }
            return Character(scalar)
        }
        return String(mapped)
    }

    /// 整行只含 A/B/C/D（大小寫）與空格時回傳 true。
    /// 用於辨識 Gary 格式的無題號答案行；含中文/數字/標點的表頭行會回傳 false。
    static func isAnswerOnlyLine(_ line: String) -> Bool {
        return line.uppercased().allSatisfy { "ABCD ".contains($0) }
    }

    /// 以「標準答案結構」為準拆解學生作答，與起始題號 / 跳號無關。
    /// 支援：
    /// - "DDCA 5 AC 6 BC ..."（行內可用數字重設題號）
    /// - "DBCA/AC BC/BD/AC/CD/BC"（"/" 視為空白分隔）
    /// - "DBCA AC BC BD AC CD BC"
    /// - "DBCAAC BCBDACCDBC"（連續字串）
    ///
    /// 連續字母串依「該題標準答案的字母數」逐題取字：
    /// key 為單選（1 字母）→ 每題取 1 個；key 為複選（n 字母）→ 該題取 n 個；
    /// key 未填的題目預設取 1 個（最常見的單選）。
    static func parseAnswerLine(startQ: Int, remainder: String, key: [String]) -> [Int: String] {
        var result: [Int: String] = [:]
        let replaced = remainder.replacingOccurrences(of: "/", with: " ")
        let tokens = tokenizeNumberAndLetters(replaced)

        var q = startQ

        for token in tokens {
            if let num = Int(token) {
                q = num
                continue
            }

            let lettersOnly = Array(token.uppercased().filter { "ABCD".contains($0) })
            if lettersOnly.isEmpty { continue }

            var idx = 0
            while idx < lettersOnly.count {
                let need = expectedLetterCount(forQuestion: q, key: key)
                let end = min(idx + need, lettersOnly.count)
                let chunk = String(lettersOnly[idx..<end])
                result[q] = normalizeAnswer(chunk)
                q += 1
                idx = end
            }
        }

        return result
    }

    /// 某題標準答案期望的字母數；未填則預設 1。
    static func expectedLetterCount(forQuestion q: Int, key: [String]) -> Int {
        guard (1...totalChoiceQuestions).contains(q), key.indices.contains(q - 1) else { return 1 }
        let n = normalizeAnswer(key[q - 1]).count
        return max(1, n)
    }

    static func tokenizeNumberAndLetters(_ s: String) -> [String] {
        let pattern = #"(\d+|[A-Za-z]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return s.split(separator: " ").map { String($0) }
        }
        let ns = s as NSString
        let matches = regex.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
        return matches.map { ns.substring(with: $0.range) }
    }

    /// 正規化：只留 ABCD、去重、排序（"CA" -> "AC"）
    static func normalizeAnswer(_ s: String) -> String {
        let upper = s.uppercased()
        let filtered = upper.filter { "ABCD".contains($0) }
        if filtered.isEmpty { return "" }
        return String(Set(filtered).sorted())
    }

    static func buildResultText(submission: StudentSubmission, key: [String]) -> String {
        let header = submission.headerLine.isEmpty ? "（未提供姓名/科目）" : submission.headerLine

        var wrong: [Int] = []
        var skipped: [Int] = []
        var total = 0   // 有標準答案的題數

        for q in 1...totalChoiceQuestions {
            guard key.indices.contains(q - 1) else { continue }
            let answer = normalizeAnswer(key[q - 1])
            if answer.isEmpty { continue } // 標準答案未填，不計
            total += 1

            let stu = submission.answers[q] ?? ""
            if stu.isEmpty { skipped.append(q); continue }
            if normalizeAnswer(stu) != answer { wrong.append(q) }
        }

        let correct = total - wrong.count - skipped.count

        var out: [String] = []
        out.append(header)
        if total > 0 {
            out.append("得分：\(correct)/\(total)")
        }
        out.append("訂正：\(wrong.isEmpty ? "無" : wrong.map(String.init).joined(separator: ", "))")
        if !skipped.isEmpty {
            out.append("缺答：\(skipped.map(String.init).joined(separator: ", "))")
        }
        return out.joined(separator: "\n")
    }
}

// MARK: - Persistence（Step1 永久保存）
private extension ContentView {
    /// 啟動載入：優先讀多組；否則遷移舊單組；都沒有則建立一組空白。
    func loadAnswerSetsIfNeeded() {
        // 已在記憶體中（例如切換 step 後重新 onAppear）就不重載
        guard answerSets.isEmpty else { return }

        // 1) 既有多組資料
        if let loaded: [AnswerSet] = decodeJSON(answerSetsJSON, as: [AnswerSet].self),
           !loaded.isEmpty {
            answerSets = loaded.map { normalizedSet($0) }
            if let saved = UUID(uuidString: selectedSetIDString),
               answerSets.contains(where: { $0.id == saved }) {
                selectedSetID = saved
            } else {
                selectedSetID = answerSets[0].id
            }
            return
        }

        // 2) 遷移舊單組
        if let oldKey: [String] = decodeJSON(choiceKeyJSON, as: [String].self),
           oldKey.contains(where: { !$0.isEmpty }) {
            let migrated = AnswerSet(name: "預設", choiceKey: padKey(oldKey))
            answerSets = [migrated]
            selectedSetID = migrated.id
            persistAnswerSets()
            return
        }

        // 3) 全新：一組空白
        let fresh = AnswerSet(name: "答案 1",
                              choiceKey: Array(repeating: "", count: totalChoiceQuestions))
        answerSets = [fresh]
        selectedSetID = fresh.id
    }

    func persistAnswerSets() {
        answerSetsJSON = encodeJSON(answerSets) ?? ""
        selectedSetIDString = selectedSetID.uuidString
    }

    /// 確保 choiceKey 長度為 totalChoiceQuestions。
    func padKey(_ key: [String]) -> [String] {
        if key.count == totalChoiceQuestions { return key }
        var k = Array(key.prefix(totalChoiceQuestions))
        while k.count < totalChoiceQuestions { k.append("") }
        return k
    }

    func normalizedSet(_ set: AnswerSet) -> AnswerSet {
        var s = set
        s.choiceKey = padKey(s.choiceKey)
        return s
    }

    func encodeJSON<T: Encodable>(_ value: T) -> String? {
        do {
            let data = try JSONEncoder().encode(value)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func decodeJSON<T: Decodable>(_ json: String, as type: T.Type) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Helpers
private extension ContentView {
    func toastCopied() {
        withAnimation(.easeInOut(duration: 0.15)) { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) { showCopyToast = false }
        }
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Choice Cell
private struct ChoiceBoxCellCompact: View {
    @Binding var text: String
    let width: CGFloat
    let height: CGFloat

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var filled: Bool { !text.isEmpty }

    private var bgColor: Color {
        if isFocused {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.30 : 0.12)
        }
        if filled {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.10)
        }
        return colorScheme == .dark ? Color.white.opacity(0.10) : Color(.systemGray5)
    }

    var body: some View {
        TextField("", text: $text)
            .focused($isFocused)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .frame(width: width, height: height)
            .foregroundStyle(Color.primary)
            .tint(.accentColor)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(bgColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isFocused ? Color.accentColor : (filled ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.35)),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .disableAutocorrection(true)
    }
}

