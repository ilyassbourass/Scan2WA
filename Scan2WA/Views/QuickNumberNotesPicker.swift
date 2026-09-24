import SwiftUI
import UIKit

public struct QuickNumberNotesPicker: View {
    @Binding public var notesText: String
    public var placeholder: String = "Optional details (e.g. Apt 4, COD 250 DH)"

    // Quick numbers from 1 to 30
    private let quickNumbers: [Int] = Array(1...30)

    public init(notesText: Binding<String>, placeholder: String = "Optional details (e.g. Apt 4, COD 250 DH)") {
        self._notesText = notesText
        self.placeholder = placeholder
    }

    private var currentNumber: Int? {
        let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = Int(trimmed) { return direct }
        let clean = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let parts = clean.components(separatedBy: CharacterSet(charactersIn: " -:,/"))
        if let first = parts.first, let num = Int(first) {
            return num
        }
        return nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            chipsScrollView
            textFieldView
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("PACKAGE NUMBER / NOTE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Spacer()

            if let current = currentNumber {
                stepperControls(current: current)
            }
        }
    }

    @ViewBuilder
    private func stepperControls(current: Int) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                let newNum = max(1, current - 1)
                selectNumber(newNum)
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
            }

            Text("Box #\(current)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.15))
                .cornerRadius(6)

            Button(action: {
                selectNumber(current + 1)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
            }

            Button(action: clearNumber) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
    }

    @ViewBuilder
    private var chipsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(quickNumbers, id: \.self) { num in
                    numberChip(num: num)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func numberChip(num: Int) -> some View {
        let isSelected = currentNumber == num
        Button(action: {
            let haptic = UIImpactFeedbackGenerator(style: .light)
            haptic.impactOccurred()
            if isSelected {
                clearNumber()
            } else {
                selectNumber(num)
            }
        }) {
            HStack(spacing: 2) {
                Text("\(num)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .frame(height: 32)
            .frame(minWidth: 36)
            .padding(.horizontal, 6)
            .background(isSelected ? Color(red: 0.15, green: 0.78, blue: 0.35) : Color.white.opacity(0.1))
            .foregroundColor(isSelected ? .black : .white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var textFieldView: some View {
        TextField(placeholder, text: $notesText)
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            .foregroundColor(.white)
            .font(.system(size: 14))
    }

    private func selectNumber(_ num: Int) {
        let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || Int(trimmed) != nil {
            notesText = "\(num)"
            return
        }
        if let curr = currentNumber {
            let prefix1 = "\(curr)"
            let prefix2 = "#\(curr)"
            if trimmed.hasPrefix(prefix1) {
                let remainder = trimmed.dropFirst(prefix1.count).trimmingCharacters(in: CharacterSet(charactersIn: " -:,/"))
                notesText = remainder.isEmpty ? "\(num)" : "\(num) - \(remainder)"
                return
            } else if trimmed.hasPrefix(prefix2) {
                let remainder = trimmed.dropFirst(prefix2.count).trimmingCharacters(in: CharacterSet(charactersIn: " -:,/"))
                notesText = remainder.isEmpty ? "\(num)" : "\(num) - \(remainder)"
                return
            }
        }
        notesText = "\(num) - \(trimmed)"
    }

    private func clearNumber() {
        let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        if Int(trimmed) != nil {
            notesText = ""
            return
        }
        if let curr = currentNumber {
            let prefix1 = "\(curr)"
            let prefix2 = "#\(curr)"
            if trimmed.hasPrefix(prefix1) {
                let remainder = trimmed.dropFirst(prefix1.count).trimmingCharacters(in: CharacterSet(charactersIn: " -:,/"))
                notesText = remainder
                return
            } else if trimmed.hasPrefix(prefix2) {
                let remainder = trimmed.dropFirst(prefix2.count).trimmingCharacters(in: CharacterSet(charactersIn: " -:,/"))
                notesText = remainder
                return
            }
        }
        notesText = ""
    }
}
