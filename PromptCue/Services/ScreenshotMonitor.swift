import Foundation
import PromptCueCore
import UniformTypeIdentifiers

@MainActor
final class ScreenshotMonitor {
    func mostRecentScreenshot(maxAge: TimeInterval) -> ScreenshotAttachment? {
        let minimumDate = Date().addingTimeInterval(-maxAge)

        return ScreenshotDirectoryResolver.withAuthorizedDirectory { directoryURL in
            newestScreenshot(in: directoryURL, minimumDate: minimumDate)
        }
        .flatMap { $0 }
        .map { ScreenshotAttachment(path: $0.url.path) }
    }

    private func newestScreenshot(in directoryURL: URL, minimumDate: Date) -> ScreenshotMatch? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .creationDateKey,
                .contentModificationDateKey,
                .isRegularFileKey,
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        return contents
            .compactMap { screenshotMatch(for: $0, minimumDate: minimumDate) }
            .max { left, right in
                if left.matchScore == right.matchScore {
                    return left.date < right.date
                }

                return left.matchScore < right.matchScore
            }
    }

    private func screenshotMatch(for url: URL, minimumDate: Date) -> ScreenshotMatch? {
        guard isEligibleImage(url) else {
            return nil
        }

        guard let candidateDate = resourceDate(for: url), candidateDate >= minimumDate else {
            return nil
        }

        let matchScore = screenshotMatchScore(for: url)
        guard matchScore > 0 else {
            return nil
        }

        return ScreenshotMatch(url: url, date: candidateDate, matchScore: matchScore)
    }

    private func isEligibleImage(_ url: URL) -> Bool {
        let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
        guard resourceValues?.isRegularFile == true else {
            return false
        }

        let extensionType = UTType(filenameExtension: url.pathExtension)
        return extensionType?.conforms(to: .image) == true
    }

    private func screenshotMatchScore(for url: URL) -> Int {
        let filename = url.deletingPathExtension().lastPathComponent.lowercased()
        let screenshotHints = [
            "screenshot",
            "screen shot",
            "screen_shot",
            "bildschirmfoto",
            "captura de pantalla",
            "스크린샷",
        ]

        if screenshotHints.contains(where: filename.contains) {
            return 2
        }

        // The folder is explicitly user-selected, so unnamed images can still qualify.
        return 1
    }

    private func resourceDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate
    }
}

private struct ScreenshotMatch {
    let url: URL
    let date: Date
    let matchScore: Int
}
