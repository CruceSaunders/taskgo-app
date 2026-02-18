import SwiftUI
import AppKit

/// Shared reference so the toolbar can talk to the text view
class RichTextEditorCoordinator: ObservableObject {
    weak var textView: NSTextView?

    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderline = false

    /// Call this whenever selection or typing attributes change
    func updateState() {
        guard let tv = textView else { return }
        let attrs: [NSAttributedString.Key: Any]

        if tv.selectedRange().length > 0 {
            attrs = tv.textStorage?.attributes(at: tv.selectedRange().location, effectiveRange: nil) ?? [:]
        } else {
            attrs = tv.typingAttributes
        }

        if let font = attrs[.font] as? NSFont {
            let traits = NSFontManager.shared.traits(of: font)
            isBold = traits.contains(.boldFontMask)
            isItalic = traits.contains(.italicFontMask)
        } else {
            isBold = false
            isItalic = false
        }

        isUnderline = ((attrs[.underlineStyle] as? Int) ?? 0) != 0
    }

    func toggleBold() {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
        let range = tv.selectedRange()

        if range.length > 0 {
            let storage = tv.textStorage!
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
                guard let font = value as? NSFont else { return }
                let mgr = NSFontManager.shared
                let newFont = mgr.traits(of: font).contains(.boldFontMask)
                    ? mgr.convert(font, toNotHaveTrait: .boldFontMask)
                    : mgr.convert(font, toHaveTrait: .boldFontMask)
                storage.addAttribute(.font, value: newFont, range: attrRange)
            }
            storage.endEditing()
            notifyChange()
        } else {
            // No selection: toggle typing attributes for next typed text
            var attrs = tv.typingAttributes
            let font = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 13)
            let mgr = NSFontManager.shared
            let newFont = mgr.traits(of: font).contains(.boldFontMask)
                ? mgr.convert(font, toNotHaveTrait: .boldFontMask)
                : mgr.convert(font, toHaveTrait: .boldFontMask)
            attrs[.font] = newFont
            tv.typingAttributes = attrs
        }
        updateState()
    }

    func toggleItalic() {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
        let range = tv.selectedRange()

        if range.length > 0 {
            let storage = tv.textStorage!
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
                guard let font = value as? NSFont else { return }
                let mgr = NSFontManager.shared
                let newFont = mgr.traits(of: font).contains(.italicFontMask)
                    ? mgr.convert(font, toNotHaveTrait: .italicFontMask)
                    : mgr.convert(font, toHaveTrait: .italicFontMask)
                storage.addAttribute(.font, value: newFont, range: attrRange)
            }
            storage.endEditing()
            notifyChange()
        } else {
            var attrs = tv.typingAttributes
            let font = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 13)
            let mgr = NSFontManager.shared
            let newFont = mgr.traits(of: font).contains(.italicFontMask)
                ? mgr.convert(font, toNotHaveTrait: .italicFontMask)
                : mgr.convert(font, toHaveTrait: .italicFontMask)
            attrs[.font] = newFont
            tv.typingAttributes = attrs
        }
        updateState()
    }

    func toggleUnderline() {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
        let range = tv.selectedRange()

        if range.length > 0 {
            let storage = tv.textStorage!
            storage.beginEditing()
            var has = false
            storage.enumerateAttribute(.underlineStyle, in: range) { val, _, _ in
                if let s = val as? Int, s != 0 { has = true }
            }
            if has {
                storage.removeAttribute(.underlineStyle, range: range)
            } else {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            storage.endEditing()
            notifyChange()
        } else {
            var attrs = tv.typingAttributes
            let current = (attrs[.underlineStyle] as? Int) ?? 0
            attrs[.underlineStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            tv.typingAttributes = attrs
        }
        updateState()
    }

    func setHeader(_ level: Int) {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
        let range = tv.selectedRange()
        let size: CGFloat = level == 1 ? 20 : level == 2 ? 16 : 13
        let weight: NSFont.Weight = level <= 2 ? .bold : .regular
        let font = NSFont.systemFont(ofSize: size, weight: weight)

        if range.length > 0 {
            let storage = tv.textStorage!
            storage.beginEditing()
            storage.addAttribute(.font, value: font, range: range)
            storage.endEditing()
            notifyChange()
        } else {
            var attrs = tv.typingAttributes
            attrs[.font] = font
            tv.typingAttributes = attrs
        }
        updateState()
    }

    private func notifyChange() {
        // Trigger the delegate's textDidChange
        guard let tv = textView else { return }
        tv.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: tv))
    }
}

struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var coordinator: RichTextEditorCoordinator
    var onTextChange: (() -> Void)?

    func makeCoordinator() -> Delegate {
        Delegate(self)
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
        textView.isFieldEditor = false

        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true

        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        // Share the text view reference with the toolbar coordinator
        DispatchQueue.main.async {
            self.coordinator.textView = textView
        }

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        // Focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if !context.coordinator.isUpdating {
            let currentRTF = textView.attributedString().rtfData()
            let newRTF = attributedText.rtfData()
            if currentRTF != newRTF {
                context.coordinator.isUpdating = true
                textView.textStorage?.setAttributedString(attributedText)
                textView.setSelectedRange(NSRange(location: attributedText.length, length: 0))
                context.coordinator.isUpdating = false
            }
        }

        // Share reference
        if coordinator.textView !== textView {
            DispatchQueue.main.async {
                self.coordinator.textView = textView
            }
        }

        // Focus
        if textView.window?.firstResponder != textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    class Delegate: NSObject, NSTextViewDelegate {
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
            isUpdating = false
            parent.coordinator.updateState()
            parent.onTextChange?()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            parent.coordinator.updateState()
        }
    }
}

// MARK: - RTF Serialization

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
