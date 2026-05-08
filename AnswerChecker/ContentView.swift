import SwiftUI
import UIKit

// MARK: - Step2：學生解析結果
struct StudentSubmission {
    var headerLine: String = ""             // 姓名/英文名/科目
    var answers: [Int: String] = [:]        // 題號 -> "A"/"AC"
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
    @AppStorage("AnswerChecker.choiceKeyJSON") private var choiceKeyJSON: String = ""

    @State private var choiceKey: [String] = Array(repeating: "", count: 100)
    @FocusState private var focusedChoiceIndex: Int?

    // MARK: Step2：學生貼上
    @State private var studentRawText: String = ""

    // MARK: Step3：輸出
    @State private var resultText: String = ""
    @State private var showCopyToast: Bool = false

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
        // ✅ 啟動載入Step1
        .onAppear { loadPersistedStep1IfNeeded() }
        // ✅ Step1 任意更動自動保存
        .onChange(of: choiceKey) { _, _ in persistChoiceKey() }
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
                                if let idx = focusedChoiceIndex { choiceKey[idx] = "" }
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

    func handleKeyInput(index: Int, newValue: String) {
        let normalized = normalizeAnswer(newValue)
        let wasEmpty = choiceKey[index].isEmpty
        choiceKey[index] = normalized

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
            choiceKey[index] = normalizeAnswer(current.filter { String($0) != letter })
        } else {
            choiceKey[index] = normalizeAnswer(current + letter)
        }
    }

    /// ✅ 清空 Step1（同時清掉儲存）——只有按這個才會真的清
    func clearStep1All() {
        choiceKey = Array(repeating: "", count: totalChoiceQuestions)
        focusedChoiceIndex = nil
        choiceKeyJSON = ""
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

            HStack(spacing: 10) {
                Button {
                    let submission = parseStudentSubmission(studentRawText)
                    resultText = buildResultText(submission: submission)
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

// MARK: - Step2 Parser（支援多種格式）
private extension ContentView {
    func parseStudentSubmission(_ raw: String) -> StudentSubmission {
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
            let line = lines[i]
            if line.isEmpty { continue }

            if let (startQ, remainder) = extractLeadingNumber(line) {
                // 有題號行："01 CABCC…" 或 "1 CACCC…"
                let parsed = parseAnswerLine(startQ: startQ, remainder: remainder)
                for (q, a) in parsed where (1...totalChoiceQuestions).contains(q) {
                    sub.answers[q] = a
                }
                if let maxQ = parsed.keys.max() { autoQ = maxQ + 1 }

            } else if isAnswerOnlyLine(line) {
                // 無題號行（只含 A/B/C/D 與空格），從 autoQ 接續
                let parsed = parseAnswerLine(startQ: autoQ, remainder: line)
                for (q, a) in parsed where (1...totalChoiceQuestions).contains(q) {
                    sub.answers[q] = a
                }
                if let maxQ = parsed.keys.max() { autoQ = maxQ + 1 }
            }
            // else: 多行表頭的延續（如科目名稱）→ 跳過
        }
        return sub
    }

    /// 行首有 1–2 位數字 + 空白時，回傳 (startQ, remainder)。
    /// 支援 "01 CABCC…" 與 "1 CACCC…" 兩種格式。
    func extractLeadingNumber(_ line: String) -> (Int, String)? {
        let pattern = #"^(\d{1,2})\s*(.*)"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
        else { return nil }
        let ns = line as NSString
        guard let q = Int(ns.substring(with: m.range(at: 1))) else { return nil }
        let rest = ns.substring(with: m.range(at: 2))
        return (q, rest)
    }

    /// 整行只含 A/B/C/D（大小寫）與空格時回傳 true。
    /// 用於辨識 Gary 格式的無題號答案行；含中文/數字/標點的表頭行會回傳 false。
    func isAnswerOnlyLine(_ line: String) -> Bool {
        return line.uppercased().allSatisfy { "ABCD ".contains($0) }
    }

    /// 支援：
    /// - "DDCA 5 AC 6 BC ..."
    /// - "DBCA/AC BC/BD/AC/CD/BC"
    /// - "DBCA AC BC BD AC CD BC"
    /// - "DBCAAC BCBDACCDBC"
    func parseAnswerLine(startQ: Int, remainder: String) -> [Int: String] {
        var result: [Int: String] = [:]
        let replaced = remainder.replacingOccurrences(of: "/", with: " ")
        let tokens = tokenizeNumberAndLetters(replaced)

        var q = startQ
        var firstFourDone = false

        for token in tokens {
            if let num = Int(token) {
                q = num
                continue
            }

            let lettersOnly = token.uppercased().filter { "ABCD".contains($0) }
            if lettersOnly.isEmpty { continue }

            if lettersOnly.count == 10 {
                for ch in lettersOnly { result[q] = normalizeAnswer(String(ch)); q += 1 }
                continue
            }
            if lettersOnly.count == 5 {
                for ch in lettersOnly { result[q] = normalizeAnswer(String(ch)); q += 1 }
                continue
            }

            if startQ == 1, !firstFourDone, q == 1, lettersOnly.count >= 4 {
                let chars = Array(lettersOnly)
                for k in 0..<4 { result[q] = normalizeAnswer(String(chars[k])); q += 1 }
                firstFourDone = true

                if chars.count > 4 {
                    var idx = 4
                    while idx < chars.count {
                        if idx + 1 < chars.count {
                            let pair = String(chars[idx]) + String(chars[idx + 1])
                            result[q] = normalizeAnswer(pair)
                            q += 1
                            idx += 2
                        } else {
                            result[q] = normalizeAnswer(String(chars[idx]))
                            q += 1
                            idx += 1
                        }
                    }
                }
                continue
            }

            if lettersOnly.count == 1 {
                result[q] = normalizeAnswer(String(lettersOnly)); q += 1
            } else if lettersOnly.count <= 4 {
                result[q] = normalizeAnswer(String(lettersOnly)); q += 1
            } else {
                if lettersOnly.count % 2 == 0 {
                    let chars = Array(lettersOnly)
                    var idx = 0
                    while idx < chars.count {
                        let pair = String(chars[idx]) + String(chars[idx + 1])
                        result[q] = normalizeAnswer(pair)
                        q += 1
                        idx += 2
                    }
                } else {
                    for ch in lettersOnly { result[q] = normalizeAnswer(String(ch)); q += 1 }
                }
            }
        }

        return result
    }

    func tokenizeNumberAndLetters(_ s: String) -> [String] {
        let pattern = #"(\d+|[A-Za-z]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return s.split(separator: " ").map { String($0) }
        }
        let ns = s as NSString
        let matches = regex.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
        return matches.map { ns.substring(with: $0.range) }
    }

    /// 正規化：只留 ABCD、去重、排序（"CA" -> "AC"）
    func normalizeAnswer(_ s: String) -> String {
        let upper = s.uppercased()
        let filtered = upper.filter { "ABCD".contains($0) }
        if filtered.isEmpty { return "" }
        return String(Set(filtered).sorted())
    }
}

// MARK: - Step3 Compare + Output
private extension ContentView {
    func buildResultText(submission: StudentSubmission) -> String {
        let header = submission.headerLine.isEmpty ? "（未提供姓名/科目）" : submission.headerLine

        var wrong: [Int] = []
        var skipped: [Int] = []
        var total = 0   // 有標準答案的題數

        for q in 1...totalChoiceQuestions {
            let key = normalizeAnswer(choiceKey[q - 1])
            if key.isEmpty { continue } // 標準答案未填，不計
            total += 1

            let stu = submission.answers[q] ?? ""
            if stu.isEmpty { skipped.append(q); continue }
            if normalizeAnswer(stu) != key { wrong.append(q) }
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
    func loadPersistedStep1IfNeeded() {
        guard !choiceKey.contains(where: { !$0.isEmpty }), !choiceKeyJSON.isEmpty else { return }
        if let loaded: [String] = decodeJSON(choiceKeyJSON, as: [String].self),
           loaded.count == totalChoiceQuestions {
            choiceKey = loaded
        }
    }

    func persistChoiceKey() {
        choiceKeyJSON = encodeJSON(choiceKey) ?? ""
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

