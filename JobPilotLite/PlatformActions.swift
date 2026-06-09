import Foundation
import CoreGraphics
import CoreText

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PlatformActions {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    static func open(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    static func writeResumeExports(text: String, title: String) -> [ResumeExportFile] {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent("JobPilotLiteResumeExports", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        return ResumeExportFormat.allCases.compactMap { format in
            let filename = "\(sanitizedFilename(title)).\(format.fileExtension)"
            let url = directory.appendingPathComponent(filename)

            do {
                switch format {
                case .txt:
                    try text.data(using: .utf8)?.write(to: url, options: .atomic)
                case .pdf:
                    try writePDF(text: text, to: url)
                case .word:
                    try writeWordRTF(text: text, to: url)
                }
                return ResumeExportFile(format: format, url: url)
            } catch {
                return nil
            }
        }
    }

    private static func sanitizedFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = value
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Resume" : String(cleaned.prefix(80))
    }

    private static func writeWordRTF(text: String, to url: URL) throws {
        #if canImport(UIKit)
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.label
            ]
        )
        #elseif canImport(AppKit)
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.labelColor
            ]
        )
        #else
        try text.data(using: .utf8)?.write(to: url, options: .atomic)
        return
        #endif

        let range = NSRange(location: 0, length: attributed.length)
        let data = try attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        try data.write(to: url, options: .atomic)
    }

    private static func writePDF(text: String, to url: URL) throws {
        #if canImport(UIKit)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 54
        let textBounds = pageBounds.insetBy(dx: margin, dy: margin)
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.label
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: url) { context in
            var range = CFRange(location: 0, length: 0)

            while range.location < attributed.length {
                context.beginPage()
                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageBounds.height)
                cgContext.scaleBy(x: 1, y: -1)

                let path = CGMutablePath()
                path.addRect(textBounds)
                let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
                CTFrameDraw(frame, cgContext)
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                cgContext.restoreGState()

                guard visibleRange.length > 0 else { break }
                range.location += visibleRange.length
            }
        }
        #else
        try text.data(using: .utf8)?.write(to: url, options: .atomic)
        #endif
    }
}
