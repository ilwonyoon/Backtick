import AppKit
import SwiftUI

// MARK: - CardContextMenuItem

struct CardContextMenuItem {
    let title: String
    let shortcutHint: String?
    let systemImage: String?
    let tag: Int
    let isSeparator: Bool
    let action: () -> Void

    static func separator() -> CardContextMenuItem {
        CardContextMenuItem(
            title: "",
            shortcutHint: nil,
            systemImage: nil,
            tag: -1,
            isSeparator: true,
            action: {}
        )
    }
}

// MARK: - CardContextMenuTrigger

struct CardContextMenuTrigger: NSViewRepresentable {
    let menuItems: [CardContextMenuItem]

    func makeNSView(context: Context) -> CardContextMenuNSView {
        let view = CardContextMenuNSView()
        view.menuItems = menuItems
        return view
    }

    func updateNSView(_ nsView: CardContextMenuNSView, context: Context) {
        nsView.menuItems = menuItems
    }
}

// MARK: - CardContextMenuNSView

final class CardContextMenuNSView: NSView {
    var menuItems: [CardContextMenuItem] = []

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        for item in menuItems {
            if item.isSeparator {
                menu.addItem(.separator())
            } else {
                let menuItem = NSMenuItem(
                    title: item.title,
                    action: #selector(menuItemClicked(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.tag = item.tag

                if let shortcut = item.shortcutHint {
                    let attrTitle = NSMutableAttributedString(
                        string: item.title,
                        attributes: [
                            .font: NSFont.menuFont(ofSize: 0),
                            .foregroundColor: NSColor.labelColor
                        ]
                    )
                    attrTitle.append(NSAttributedString(
                        string: "\t\(shortcut)",
                        attributes: [
                            .font: NSFont.menuFont(ofSize: 0),
                            .foregroundColor: NSColor.secondaryLabelColor
                        ]
                    ))
                    menuItem.attributedTitle = attrTitle
                }

                if let imageName = item.systemImage {
                    menuItem.image = NSImage(
                        systemSymbolName: imageName,
                        accessibilityDescription: nil
                    )
                }

                menu.addItem(menuItem)
            }
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        menuItems.first(where: { $0.tag == sender.tag })?.action()
    }

    // Pass through hit-testing so left clicks and other gestures
    // are handled by SwiftUI as normal.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    // Only handle right-mouse events; forward everything else.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        false
    }
}
