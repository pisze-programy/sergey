import SwiftUI

struct ResponseOverlayView: View {
    let text: String
    let isLoading: Bool
    let placeholder: String?
    let onClose: () -> Void

    @State private var animatedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("Sergey")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    if text.isEmpty {
                        Text(animatedText)
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        let attrString = makeLiteAttributedString(from: text)
                        Text(attrString)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            ZStack {
                Color(NSColor.systemOrange).opacity(0.12)
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .padding(8)
        .task(id: text) {
            if text.isEmpty, let p = placeholder {
                animatedText = ""
                for char in p {
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    animatedText.append(char)
                }
            } else {
                animatedText = text
            }
        }
    }
    
    private func makeLiteAttributedString(from text: String) -> AttributedString {
        let mutableAttrString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.utf16.count)

        var italicFont: NSFont = .systemFont(ofSize: 17)
        let descriptor = NSFont.systemFont(ofSize: 17).fontDescriptor.withSymbolicTraits(.italic)
        if let font = NSFont(descriptor: descriptor, size: 17) {
            italicFont = font
        }

        let styles: [(pattern: String, font: NSFont)] = [
            ("\\*\\*(.*?)\\*\\*", .boldSystemFont(ofSize: 17)),
            ("(?<!\\*)\\*(?!\\*)(.*?)\\*(?!\\*)", italicFont)
        ]

        for style in styles {
            let regex = try! NSRegularExpression(pattern: style.pattern, options: [])
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let m = match?.range(at: 0) {
                    mutableAttrString.addAttribute(.font, value: style.font, range: m)
                }
            }
        }

        return AttributedString(mutableAttrString)
    }
}
