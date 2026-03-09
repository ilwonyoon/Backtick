#!/usr/bin/env swift

import CoreGraphics
import Foundation

let excludedWindowNames: Set<String> = [
    "Control Center",
    "Dock",
    "Item-0",
    "MenuBar",
    "NotificationCenter",
    "NowPlaying",
    "Search",
    "Spotlight",
    "StatusIndicator",
    "TextInputMenuAgent",
]

struct WindowGeometry {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    init?(serialized: String) {
        let components = serialized.split(separator: ",", omittingEmptySubsequences: false)
        guard components.count == 4,
              let x = Int(components[0]),
              let y = Int(components[1]),
              let width = Int(components[2]),
              let height = Int(components[3])
        else {
            return nil
        }

        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

struct WindowRow {
    let id: Int
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let onscreen: Int
    let layer: Int
    let ownerPID: Int
    let name: String

    var area: Int {
        width * height
    }

    var centerX: Int {
        x + (width / 2)
    }

    var centerY: Int {
        y + (height / 2)
    }

    var serialized: String {
        "\(id)|\(x)|\(y)|\(width)|\(height)|\(onscreen)|\(layer)|\(ownerPID)|\(name)"
    }

    func geometryDistance(to reference: WindowGeometry) -> Int {
        abs(x - reference.x)
            + abs(y - reference.y)
            + abs(width - reference.width)
            + abs(height - reference.height)
    }

    func edgeDistance(to other: WindowRow) -> Int {
        func axisDistance(minA: Int, maxA: Int, minB: Int, maxB: Int) -> Int {
            if maxA < minB {
                return minB - maxA
            }

            if maxB < minA {
                return minA - maxB
            }

            return 0
        }

        let horizontal = axisDistance(
            minA: x,
            maxA: x + width,
            minB: other.x,
            maxB: other.x + other.width
        )
        let vertical = axisDistance(
            minA: y,
            maxA: y + height,
            minB: other.y,
            maxB: other.y + other.height
        )

        return horizontal + vertical
    }

    func centerDistanceSquared(to other: WindowRow) -> Int {
        let dx = centerX - other.centerX
        let dy = centerY - other.centerY
        return (dx * dx) + (dy * dy)
    }
}

func loadWindows(ownerName: String, minimumWindowID: Int = 0) -> [WindowRow] {
    let info = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []

    return info.compactMap { window in
        guard (window[kCGWindowOwnerName as String] as? String) == ownerName else {
            return nil
        }

        let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
        let name = (window[kCGWindowName as String] as? String ?? "")
            .replacingOccurrences(of: "|", with: "/")

        return WindowRow(
            id: window[kCGWindowNumber as String] as? Int ?? -1,
            x: Int(bounds["X"] ?? 0),
            y: Int(bounds["Y"] ?? 0),
            width: Int(bounds["Width"] ?? 0),
            height: Int(bounds["Height"] ?? 0),
            onscreen: window[kCGWindowIsOnscreen as String] as? Int ?? 0,
            layer: window[kCGWindowLayer as String] as? Int ?? 0,
            ownerPID: window[kCGWindowOwnerPID as String] as? Int ?? -1,
            name: name
        )
    }
    .filter { $0.id > minimumWindowID }
}

func eligibleWindows(ownerName: String, minimumWindowID: Int = 0) -> [WindowRow] {
    loadWindows(ownerName: ownerName, minimumWindowID: minimumWindowID)
        .filter { window in
            window.onscreen == 1
                && window.id >= 0
                && window.width > 0
                && window.height > 0
                && !excludedWindowNames.contains(window.name)
        }
}

func findPrimaryWindow(
    ownerName: String,
    minimumWindowID: Int = 0,
    minWidth: Int,
    minHeight: Int,
    referenceGeometry: WindowGeometry? = nil
) -> WindowRow? {
    let candidates = eligibleWindows(ownerName: ownerName, minimumWindowID: minimumWindowID)
        .filter { window in
            window.width >= minWidth && window.height >= minHeight
        }

    guard !candidates.isEmpty else {
        return nil
    }

    if let referenceGeometry {
        return candidates.sorted { lhs, rhs in
            let lhsDistance = lhs.geometryDistance(to: referenceGeometry)
            let rhsDistance = rhs.geometryDistance(to: referenceGeometry)

            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            if lhs.area != rhs.area {
                return lhs.area > rhs.area
            }

            return lhs.id > rhs.id
        }
        .first
    }

    return candidates.sorted { lhs, rhs in
        if lhs.area != rhs.area {
            return lhs.area > rhs.area
        }

        return lhs.id > rhs.id
    }
    .first
}

func findMetadataWindow(
    ownerName: String,
    minimumWindowID: Int = 0,
    excluding primaryWindow: WindowRow,
    minWidth: Int,
    minHeight: Int
) -> WindowRow? {
    let candidates = eligibleWindows(ownerName: ownerName, minimumWindowID: minimumWindowID)
        .filter { window in
            window.id != primaryWindow.id
                && window.width >= minWidth
                && window.height >= minHeight
        }

    return candidates.sorted { lhs, rhs in
        let lhsLargerThanPrimary = lhs.area >= primaryWindow.area ? 1 : 0
        let rhsLargerThanPrimary = rhs.area >= primaryWindow.area ? 1 : 0
        if lhsLargerThanPrimary != rhsLargerThanPrimary {
            return lhsLargerThanPrimary < rhsLargerThanPrimary
        }

        let lhsLayerDistance = abs(lhs.layer - primaryWindow.layer)
        let rhsLayerDistance = abs(rhs.layer - primaryWindow.layer)
        if lhsLayerDistance != rhsLayerDistance {
            return lhsLayerDistance < rhsLayerDistance
        }

        let lhsEdgeDistance = lhs.edgeDistance(to: primaryWindow)
        let rhsEdgeDistance = rhs.edgeDistance(to: primaryWindow)
        if lhsEdgeDistance != rhsEdgeDistance {
            return lhsEdgeDistance < rhsEdgeDistance
        }

        let lhsCenterDistance = lhs.centerDistanceSquared(to: primaryWindow)
        let rhsCenterDistance = rhs.centerDistanceSquared(to: primaryWindow)
        if lhsCenterDistance != rhsCenterDistance {
            return lhsCenterDistance < rhsCenterDistance
        }

        if lhs.area != rhs.area {
            return lhs.area > rhs.area
        }

        return lhs.id > rhs.id
    }
    .first
}

func printUsageAndExit() -> Never {
    fputs(
        """
        Usage:
          promptcue_window_probe.swift windows <ownerName> [minimumWindowID]
          promptcue_window_probe.swift find <ownerName> <minWidth> <minHeight> [minimumWindowID] [referenceGeometry]
          promptcue_window_probe.swift pair <ownerName> <captureMinWidth> <captureMinHeight> <metadataMinWidth> <metadataMinHeight> <minimumWindowID> [referenceCaptureGeometry]
        """,
        stderr
    )
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    printUsageAndExit()
}

switch arguments[1] {
case "windows":
    let minimumWindowID = arguments.count >= 4 ? (Int(arguments[3]) ?? 0) : 0

    for window in loadWindows(ownerName: arguments[2], minimumWindowID: minimumWindowID).sorted(by: { lhs, rhs in
        if lhs.onscreen != rhs.onscreen {
            return lhs.onscreen > rhs.onscreen
        }

        if lhs.area != rhs.area {
            return lhs.area > rhs.area
        }

        return lhs.id > rhs.id
    }) {
        print(window.serialized)
    }
case "find":
    guard arguments.count >= 5 else {
        printUsageAndExit()
    }

    let minWidth = Int(arguments[3]) ?? 0
    let minHeight = Int(arguments[4]) ?? 0
    let minimumWindowID = arguments.count >= 6 ? (Int(arguments[5]) ?? 0) : 0
    let referenceGeometry: WindowGeometry?
    if arguments.count >= 7, arguments[6] != "-" {
        referenceGeometry = WindowGeometry(serialized: arguments[6])
    } else {
        referenceGeometry = nil
    }

    if let candidate = findPrimaryWindow(
        ownerName: arguments[2],
        minimumWindowID: minimumWindowID,
        minWidth: minWidth,
        minHeight: minHeight,
        referenceGeometry: referenceGeometry
    ) {
        print(candidate.serialized)
    }
case "pair":
    guard arguments.count >= 8 else {
        printUsageAndExit()
    }

    let captureMinWidth = Int(arguments[3]) ?? 0
    let captureMinHeight = Int(arguments[4]) ?? 0
    let metadataMinWidth = Int(arguments[5]) ?? 0
    let metadataMinHeight = Int(arguments[6]) ?? 0
    let minimumWindowID = Int(arguments[7]) ?? 0
    let referenceGeometry: WindowGeometry?
    if arguments.count >= 9, arguments[8] != "-" {
        referenceGeometry = WindowGeometry(serialized: arguments[8])
    } else {
        referenceGeometry = nil
    }

    guard let primaryWindow = findPrimaryWindow(
        ownerName: arguments[2],
        minimumWindowID: minimumWindowID,
        minWidth: captureMinWidth,
        minHeight: captureMinHeight,
        referenceGeometry: referenceGeometry
    ) else {
        exit(2)
    }

    guard let metadataWindow = findMetadataWindow(
        ownerName: arguments[2],
        minimumWindowID: minimumWindowID,
        excluding: primaryWindow,
        minWidth: metadataMinWidth,
        minHeight: metadataMinHeight
    ) else {
        exit(3)
    }

    let orderedPair: (capture: WindowRow, metadata: WindowRow)
    if primaryWindow.y <= metadataWindow.y {
        orderedPair = (primaryWindow, metadataWindow)
    } else {
        orderedPair = (metadataWindow, primaryWindow)
    }

    print("capture|\(orderedPair.capture.serialized)")
    print("metadata|\(orderedPair.metadata.serialized)")
default:
    printUsageAndExit()
}
