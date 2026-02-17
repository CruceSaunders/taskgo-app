import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var onTextChange: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.clear
        textView.drawsBackground = false

        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Only update if the content actually changed (avoid cursor jumps)
        if !context.coordinator.isUpdating {
            let currentRTF = textView.attributedString().rtfData()
            let newRTF = attributedText.rtfData()
            if currentRTF != newRTF {
                context.coordinator.isUpdating = true
                let selectedRanges = textView.selectedRanges
                textView.textStorage?.setAttributedString(attributedText)
                textView.selectedRanges = selectedRanges
                context.coordinator.isUpdating = false
            }
        }
    }

    // MARK: - Formatting Actions

    static func toggleBold(in textView: NSTextView?) {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let storage = textView.textStorage!
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            let manager = NSFontManager.shared
            let newFont: NSFont
            if manager.traits(of: font).contains(.boldFontMask) {
                newFont = manager.convert(font, toNotHaveTrait: .boldFontMask)
            } else {
                newFont = manager.convert(font, toHaveTrait: .boldFontMask)
            }
            storage.addAttribute(.font, value: newFont, range: attrRange)
        }
        storage.endEditing()
    }

    static func toggleItalic(in textView: NSTextView?) {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let storage = textView.textStorage!
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            let manager = NSFontManager.shared
            let newFont: NSFont
            if manager.traits(of: font).contains(.italicFontMask) {
                newFont = manager.convert(font, toNotHaveTrait: .italicFontMask)
            } else {
                newFont = manager.convert(font, toHaveTrait: .italicFontMask)
            }
            storage.addAttribute(.font, value: newFont, range: attrRange)
        }
        storage.endEditing()
    }

    static func toggleUnderline(in textView: NSTextView?) {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let storage = textView.textStorage!
        storage.beginEditing()
        var hasUnderline = false
        storage.enumerateAttribute(.underlineStyle, in: range) { value, _, _ in
            if let style = value as? Int, style != 0 { hasUnderline = true }
        }
        if hasUnderline {
            storage.removeAttribute(.underlineStyle, range: range)
        } else {
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        storage.endEditing()
    }

    static func setHeader(_ level: Int, in textView: NSTextView?) {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let size: CGFloat = level == 1 ? 20 : level == 2 ? 16 : 13
        let weight: NSFont.Weight = level <= 2 ? .bold : .regular

        let storage = textView.textStorage!
        storage.beginEditing()
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        storage.addAttribute(.font, value: font, range: range)
        storage.endEditing()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var isUpdating = false
        weak var textView: NSTextView?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.attributedText = textView.attributedString()
            parent.onTextChange?()
            isUpdating = false
        }
    }
}

// MARK: - RTF Serialization Helpers

extension NSAttributedString {
    func rtfData() -> Data? {
        try? data(from: NSRange(location: 0, length: length),
                  documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    func rtfBase64() -> String? {
        rtfData()?.base64EncodedString()
    }

    static func fromRTFBase64(_ base64: String) -> NSAttributedString? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? NSAttributedString(data: data,
                                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                                        documentAttributes: nil)
    }

    var plainText: String {
        string
    }
}
