import AppKit
import SwiftUI

struct VisualEffectBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let appearanceName: NSAppearance.Name?

    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        appearanceName: NSAppearance.Name? = nil
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.appearanceName = appearanceName
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.isEmphasized = false
        view.material = material
        view.blendingMode = blendingMode
        view.appearance = appearanceName.flatMap(NSAppearance.init(named:))
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
        nsView.isEmphasized = false
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.appearance = appearanceName.flatMap(NSAppearance.init(named:))
    }
}
