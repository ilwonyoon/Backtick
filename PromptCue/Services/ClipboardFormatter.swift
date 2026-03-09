import AppKit
import Foundation
import PromptCueCore
import UniformTypeIdentifiers

enum ClipboardFormatter {
    static func string(for cards: [CaptureCard]) -> String {
        ExportFormatter.string(for: cards)
    }

    static func copyToPasteboard(cards: [CaptureCard]) {
        let value = string(for: cards)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let items = pasteboardItems(for: cards, textPayload: value)
        if !items.isEmpty, pasteboard.writeObjects(items) {
            return
        }

        pasteboard.setString(value, forType: .string)
    }

    private static func pasteboardItems(for cards: [CaptureCard], textPayload: String) -> [NSPasteboardItem] {
        var items: [NSPasteboardItem] = []

        let textItem = NSPasteboardItem()
        textItem.setString(textPayload, forType: .string)
        items.append(textItem)

        for card in cards {
            guard let screenshotURL = card.screenshotURL else {
                continue
            }

            let imageItem = NSPasteboardItem()
            imageItem.setString(screenshotURL.absoluteString, forType: .fileURL)

            if let image = NSImage(contentsOf: screenshotURL),
               let tiffData = image.tiffRepresentation {
                imageItem.setData(tiffData, forType: .tiff)
            }

            if screenshotURL.pathExtension.lowercased() == "png",
               let pngData = try? Data(contentsOf: screenshotURL) {
                imageItem.setData(pngData, forType: .png)
            }

            items.append(imageItem)
        }

        return items
    }

    static func externalDragItemProvider(cards: [CaptureCard]) -> NSItemProvider {
        externalDragItemProvider(text: string(for: cards))
    }

    static func externalDragItemProvider(text: String) -> NSItemProvider {
        let provider = NSItemProvider(object: NSString(string: text))
        let utf8Data = Data(text.utf8)

        for type in [UTType.utf8PlainText, UTType.plainText, UTType.text] {
            provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
                completion(utf8Data, nil)
                return nil
            }
        }

        return provider
    }

    static func externalDragPasteboardItem(cards: [CaptureCard]) -> NSPasteboardItem {
        externalDragPasteboardItem(text: string(for: cards))
    }

    static func externalDragPasteboardItem(text: String) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setString(text, forType: NSPasteboard.PasteboardType(UTType.text.identifier))
        item.setString(text, forType: NSPasteboard.PasteboardType(UTType.plainText.identifier))
        item.setString(text, forType: NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier))
        return item
    }
}
