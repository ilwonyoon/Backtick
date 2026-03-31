#!/usr/bin/env bash

set -euo pipefail

WATCH=0
TIMEOUT_SECONDS="15"
POLL_INTERVAL_SECONDS="0.25"
REQUIRE_IMAGE=0
OUT_DIR=""

print_usage() {
  cat <<'EOF'
Usage: scripts/inspect_clipboard_image.sh [options]

Inspect the current macOS pasteboard and report whether image payloads are
present. In watch mode, the script waits for the next pasteboard change before
capturing a snapshot.

Options:
  --watch                Wait for the next pasteboard change before inspecting
  --timeout SECONDS      Watch timeout in seconds (default: 15)
  --poll SECONDS         Watch poll interval in seconds (default: 0.25)
  --out-dir PATH         Directory to save extracted clipboard payloads
  --require-image        Exit non-zero if no PNG/TIFF clipboard payload exists
  --help                 Show this help
EOF
}

fail() {
  echo "inspect_clipboard_image: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch)
      WATCH=1
      shift
      ;;
    --timeout)
      [[ $# -ge 2 ]] || fail "--timeout requires a value"
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --poll)
      [[ $# -ge 2 ]] || fail "--poll requires a value"
      POLL_INTERVAL_SECONDS="$2"
      shift 2
      ;;
    --out-dir)
      [[ $# -ge 2 ]] || fail "--out-dir requires a value"
      OUT_DIR="$2"
      shift 2
      ;;
    --require-image)
      REQUIRE_IMAGE=1
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ -z "${OUT_DIR}" ]]; then
  TIMESTAMP="$(date '+%Y%m%d-%H%M%S')-$$"
  OUT_DIR="/tmp/promptcue-debug/clipboard/${TIMESTAMP}"
fi

mkdir -p "${OUT_DIR}"
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"

swift - "${WATCH}" "${TIMEOUT_SECONDS}" "${POLL_INTERVAL_SECONDS}" "${OUT_DIR}" "${REQUIRE_IMAGE}" <<'SWIFT'
import AppKit
import Foundation

struct Config {
    let watch: Bool
    let timeoutSeconds: Double
    let pollIntervalSeconds: Double
    let outputDirectoryURL: URL
    let requireImage: Bool
}

struct Snapshot {
    let changeCount: Int
    let topLevelTypes: [String]
    let itemTypes: [[String]]
    let stringPreview: String?
    let pngData: Data?
    let tiffData: Data?
}

enum ExitCode: Int32 {
    case success = 0
    case timeout = 2
    case missingImage = 3
    case invalidArguments = 64
}

func parseConfig() -> Config? {
    guard CommandLine.arguments.count == 6,
          let watchFlag = Int(CommandLine.arguments[1]),
          let timeoutSeconds = Double(CommandLine.arguments[2]),
          let pollIntervalSeconds = Double(CommandLine.arguments[3]),
          let requireImageFlag = Int(CommandLine.arguments[5]) else {
        return nil
    }

    let outputDirectoryURL = URL(fileURLWithPath: CommandLine.arguments[4], isDirectory: true)
    return Config(
        watch: watchFlag == 1,
        timeoutSeconds: timeoutSeconds,
        pollIntervalSeconds: pollIntervalSeconds,
        outputDirectoryURL: outputDirectoryURL,
        requireImage: requireImageFlag == 1
    )
}

func snapshot(from pasteboard: NSPasteboard) -> Snapshot {
    let topLevelTypes = pasteboard.types?.map(\.rawValue) ?? []
    let itemTypes = (pasteboard.pasteboardItems ?? []).map { item in
        item.types.map(\.rawValue)
    }

    return Snapshot(
        changeCount: pasteboard.changeCount,
        topLevelTypes: topLevelTypes,
        itemTypes: itemTypes,
        stringPreview: pasteboard.string(forType: .string),
        pngData: pasteboard.data(forType: .png),
        tiffData: pasteboard.data(forType: .tiff)
    )
}

func writePayload(_ data: Data?, named fileName: String, to directoryURL: URL) -> URL? {
    guard let data else {
        return nil
    }

    let outputURL = directoryURL.appendingPathComponent(fileName)
    do {
        try data.write(to: outputURL)
        return outputURL
    } catch {
        fputs("inspect_clipboard_image: failed to write \(fileName): \(error)\n", stderr)
        return nil
    }
}

func previewString(_ value: String?) -> String {
    guard let value, !value.isEmpty else {
        return "(none)"
    }

    let singleLine = value.replacingOccurrences(of: "\n", with: "\\n")
    return String(singleLine.prefix(160))
}

guard let config = parseConfig() else {
    fputs("inspect_clipboard_image: invalid arguments\n", stderr)
    exit(ExitCode.invalidArguments.rawValue)
}

let pasteboard = NSPasteboard.general

if config.watch {
    let baseline = pasteboard.changeCount
    let deadline = Date().addingTimeInterval(config.timeoutSeconds)

    while pasteboard.changeCount == baseline {
        if Date() >= deadline {
            fputs("inspect_clipboard_image: timed out waiting for clipboard change\n", stderr)
            exit(ExitCode.timeout.rawValue)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(config.pollIntervalSeconds))
    }
}

let result = snapshot(from: pasteboard)
let pngURL = writePayload(result.pngData, named: "clipboard-image.png", to: config.outputDirectoryURL)
let tiffURL = writePayload(result.tiffData, named: "clipboard-image.tiff", to: config.outputDirectoryURL)
let hasImage = result.pngData != nil || result.tiffData != nil

print("changeCount: \(result.changeCount)")
print("topLevelTypes: \(result.topLevelTypes)")
for (index, itemTypes) in result.itemTypes.enumerated() {
    print("item[\(index)]: \(itemTypes)")
}
print("stringPreview: \(previewString(result.stringPreview))")
print("pngBytes: \(result.pngData?.count ?? 0)")
print("tiffBytes: \(result.tiffData?.count ?? 0)")
print("pngPath: \(pngURL?.path ?? "(none)")")
print("tiffPath: \(tiffURL?.path ?? "(none)")")
print("hasImage: \(hasImage ? "yes" : "no")")

if config.requireImage && !hasImage {
    exit(ExitCode.missingImage.rawValue)
}
SWIFT
