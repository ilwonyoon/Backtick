# CloudKit Sync Architecture

## Overview

Backtick syncs two data types across devices via CloudKit's private database:

1. **CaptureCard** (prompts) — partially implemented today in `CloudSyncEngine`
2. **ProjectDocument** (memory documents) — no sync implementation exists

This document specifies the complete sync architecture: data model mapping, sync lifecycle, conflict resolution, echo suppression, error recovery, and a phased implementation plan.

### Current State

| Capability | CaptureCard | ProjectDocument |
|---|---|---|
| Push on local change | Yes | No |
| Push on delete | Yes | No |
| Fetch on push notification | Yes | No |
| Initial full sync (push all local) | **No** | No |
| Fetch on app launch | Partial (deferred) | No |
| Fetch on foreground (didBecomeActive) | **No** | No |
| Fetch on wake from sleep | **No** | No |
| Periodic safety-net fetch | **No** | No |
| Offline queue with retry | **No** | No |
| Echo suppression | Buggy (clear-all) | N/A |

### Key Files

| File | Role |
|---|---|
| `PromptCue/Services/CloudSyncEngine.swift` | Current sync engine (CaptureCard only) |
| `PromptCue/Services/CloudSyncControlling.swift` | Protocol for sync engine |
| `PromptCue/App/AppModel.swift` | Sync integration, delegate, merge logic |
| `PromptCue/App/AppCoordinator.swift` | App lifecycle (didBecomeActive, wake) |
| `PromptCue/App/AppDelegate.swift` | Remote notification handler |
| `PromptCue/Services/ProjectDocumentStore.swift` | Memory document GRDB storage |
| `Sources/PromptCueCore/CaptureCard.swift` | Domain model |
| `Sources/PromptCueCore/ProjectDocument.swift` | Domain model |
| `PromptCue/UI/Settings/CloudSyncSettingsModel.swift` | Preferences, notifications |

---

## 1. Data Model & Record Mapping

### 1.1 Zone Strategy

**Single custom zone: `Cards`** (already exists as `CKRecordZone.ID(zoneName: "Cards")`).

Both record types live in this zone. Rationale:
- Single zone subscription covers all changes
- `CKFetchRecordZoneChangesOperation` returns all record types in one call
- Simpler change token management (one token per zone)
- No cross-zone ordering concerns

The zone name `Cards` is a legacy name. Renaming is not worth the migration cost.

### 1.2 CaptureCard Record Mapping (Existing)

**Record type:** `CaptureCard`
**Record ID:** `CKRecord.ID(recordName: card.id.uuidString, zoneID: zoneID)`

| CKRecord field | Swift type | CaptureCard field | Notes |
|---|---|---|---|
| `text` | `NSString` | `text` | Required |
| `tags` | `NSArray` ([String]) | `tags` | Tag names; empty array omitted (nil) |
| `createdAt` | `NSDate` | `createdAt` | Required |
| `lastCopiedAt` | `NSDate?` | `lastCopiedAt` | nil = not yet copied |
| `sortOrder` | `NSNumber` (Double) | `sortOrder` | Default: createdAt.timeIntervalSinceReferenceDate |
| `isPinned` | `NSNumber` (Bool) | `isPinned` | Default: false |
| `screenshot` | `CKAsset?` | `screenshotPath` | File URL for managed screenshot |

**Mapping code:** `CloudSyncEngine.applyCardFields(_:to:)` (line 430) and `captureCard(from:)` (line 474).

### 1.3 ProjectDocument Record Mapping (New)

**Record type:** `ProjectDocument`
**Record ID:** `CKRecord.ID(recordName: doc.id.uuidString, zoneID: zoneID)`

| CKRecord field | Swift type | ProjectDocument field | Notes |
|---|---|---|---|
| `project` | `NSString` | `project` | Required |
| `topic` | `NSString` | `topic` | Required |
| `documentType` | `NSString` | `documentType.rawValue` | "discussion", "decision", "plan", "reference" |
| `content` | `NSString` | `content` | Full markdown body |
| `createdAt` | `NSDate` | `createdAt` | Required |
| `updatedAt` | `NSDate` | `updatedAt` | Used for conflict resolution |
| `supersededByID` | `NSString?` | `supersededByID?.uuidString` | nil for current documents; "deleted" for soft-deleted |
| `stability` | `NSNumber` (Double) | `stability` | FSRS stability value |
| `recallCount` | `NSNumber` (Int) | `recallCount` | Number of recall events |
| `lastRecalledAt` | `NSDate?` | `lastRecalledAt` | Last recall timestamp |

**Design decision: sync only current (non-superseded) documents.** The version chain (supersededByID linkage) is local-only. When a document is updated, we push the new version's record and delete the old version's record from CloudKit. Remote devices receiving the new record upsert it; the old record deletion removes any stale version.

**Soft-delete convention:** When `supersededByID == "deleted"`, the document is logically deleted. On CloudKit, we delete the CKRecord entirely rather than syncing the tombstone. Remote devices receive the deletion via `recordWithIDWasDeletedBlock`.

### 1.4 Subscription Strategy

**Current:** Single `CKRecordZoneSubscription` with ID `"card-changes"` on the `Cards` zone.

**No change needed.** Zone subscriptions cover all record types within the zone. The existing subscription will automatically deliver notifications for both `CaptureCard` and `ProjectDocument` records. The silent push (`shouldSendContentAvailable = true`) triggers `fetchRemoteChanges()`, which fetches all changed records regardless of type.

---

## 2. Sync Lifecycle

### 2.1 Lifecycle Diagram

```
App Launch
    |
    v
[CloudSyncPreferences.load() == true?]
    |                          |
   YES                        NO --> stop, no engine
    |
    v
CloudSyncEngine.setup()
    |
    +--> checkAccountStatus()
    +--> createZoneIfNeeded()
    +--> subscribeToChanges()
    |
    v
[Initial fetch mode]
    |                    |
  IMMEDIATE           DEFERRED (1.5s delay)
    |                    |
    v                    v
fetchRemoteChanges()  scheduleDeferredCloudSyncFetch()
    |
    v
[Is first sync? (serverChangeToken == nil)]
    |                    |
   YES                  NO
    |                    |
    v                    v
pushAllLocal()     (normal delta fetch)
```

### 2.2 First Enable (Initial Full Sync)

When sync is first enabled (or `serverChangeToken` is nil), we must push all local data up AND pull all remote data down.

**Sequence:**

```
1. setup() completes (zone + subscription ready)
2. fetchRemoteChanges() with nil token
   --> CloudKit returns ALL records in zone
   --> Process via delegate: merge remote into local
3. After fetch completes: pushAllLocal()
   --> Query local DB for all CaptureCards + ProjectDocuments
   --> Batch push in chunks of 400 (CKModifyRecordsOperation limit)
   --> Use savePolicy: .ifServerRecordUnchanged for first push
   --> Handle serverRecordChanged conflicts via timestamp comparison
4. Store serverChangeToken from fetch
```

**Why fetch-then-push:** Fetching first avoids creating duplicate records. After fetch, local DB has the merged state. Push only sends records that are newer locally or don't exist remotely.

**New method:** `pushAllLocalData()` on `CloudSyncEngine`

```swift
func pushAllLocalData(cards: [CaptureCard], documents: [ProjectDocument]) {
    // Chunk into batches of 400
    // For each batch: CKModifyRecordsOperation with savePolicy: .ifServerRecordUnchanged
    // On serverRecordChanged: compare timestamps, save winner
}
```

### 2.3 App Launch (Sync Already Enabled)

**Current behavior:** `startCloudSync(initialFetchMode:)` called from `AppModel.start()`. Fetches remote changes immediately or deferred.

**No change needed** for the basic flow. The fetch uses `serverChangeToken` to get only changes since last fetch.

### 2.4 Ongoing: Push on Local Change

**CaptureCard (existing):**
- `AppModel` calls `cloudSyncEngine.pushLocalChange(card:)` after save/copy/pin/edit
- `AppModel` calls `cloudSyncEngine.pushDeletion(id:)` after delete
- `AppModel` calls `cloudSyncEngine.pushBatch(cards:deletions:)` for bulk operations

**ProjectDocument (new):**
- `ProjectDocumentStore` save/update/delete operations must notify sync engine
- New methods on `CloudSyncControlling`:
  ```swift
  func pushLocalChange(document: ProjectDocument)
  func pushDocumentDeletion(id: UUID)
  func pushDocumentBatch(documents: [ProjectDocument], deletions: [UUID])
  ```

### 2.5 Fetch on Push Notification

**Current behavior:** `AppDelegate.application(_:didReceiveRemoteNotification:)` --> `AppCoordinator.handleCloudRemoteNotification()` --> `AppModel.handleCloudRemoteNotification()` --> `cloudSyncEngine.fetchRemoteChanges()`.

**No change needed.** The zone subscription delivers notifications for both record types. `fetchRemoteChanges()` already fetches all records in the zone. We just need to handle `ProjectDocument` records in `processRemoteChanges()`.

### 2.6 Foreground Fetch (didBecomeActive) -- NEW

**Current gap:** `AppCoordinator` observes `NSApplication.didBecomeActiveNotification` but only calls `refreshCardsForExternalChanges()` (local DB reload) and `recheckExperimentalMCPHTTPHealth()`. It does NOT trigger a CloudKit fetch.

**Fix:** Add `cloudSyncEngine?.fetchRemoteChanges()` to the didBecomeActive handler.

```
AppCoordinator.init():
  experimentalMCPHTTPDidBecomeActiveObserver:
    ...existing code...
    + self.model.fetchRemoteChangesIfSyncEnabled()
```

**New method on AppModel:**
```swift
func fetchRemoteChangesIfSyncEnabled() {
    cloudSyncEngine?.fetchRemoteChanges()
}
```

**Throttle:** The existing `lastDidBecomeActiveWork` guard (30-second cooldown) in `AppCoordinator` prevents excessive fetching.

### 2.7 Wake Fetch -- NEW

**Current gap:** `AppCoordinator` observes `NSWorkspace.didWakeNotification` but only calls `recheckExperimentalMCPHTTPHealth()`.

**Fix:** Add cloud sync fetch to the wake handler.

```
experimentalMCPHTTPWakeObserver:
    ...existing code...
    + self.model.fetchRemoteChangesIfSyncEnabled()
```

### 2.8 Periodic Safety-Net Fetch -- NEW

A timer-based fetch every 5 minutes catches changes that may have been missed due to dropped push notifications.

**Implementation:** Add a repeating timer in `CloudSyncEngine` (or `AppModel`), started after `setup()` completes.

```swift
private var periodicFetchTimer: Timer?

private func startPeriodicFetch() {
    periodicFetchTimer = Timer.scheduledTimer(
        withTimeInterval: 300, // 5 minutes
        repeats: true
    ) { [weak self] _ in
        Task { @MainActor [weak self] in
            self?.fetchRemoteChanges()
        }
    }
    periodicFetchTimer?.tolerance = 60
}
```

### 2.9 Sync Disable

**Current behavior:** `AppModel.setSyncEnabled(false)` calls `stopCloudSyncEngine()` which sets delegate to nil, calls `stop()`, and nils the engine.

**Additional cleanup needed:**
- Cancel periodic fetch timer
- Cancel any pending offline queue retry
- Clear `recentlyPushedIDs` / echo suppression state

---

## 3. Initial Full Sync Protocol

### 3.1 Detection

The engine knows it's the first sync when `serverChangeToken == nil`. This can happen:
1. First time sync is enabled
2. After `changeTokenExpired` error (token is reset to nil)
3. After user resets sync data

### 3.2 Push All Local Data

```
pushAllLocalData(cards: [CaptureCard], documents: [ProjectDocument]):
    |
    v
  Convert to CKRecords:
    cards --> CKRecord(recordType: "CaptureCard", ...)
    documents --> CKRecord(recordType: "ProjectDocument", ...)
    |
    v
  Chunk into batches of 400 records max
    |
    v
  For each batch:
    CKModifyRecordsOperation(
        recordsToSave: batch,
        recordIDsToDelete: nil
    )
    operation.savePolicy = .ifServerRecordUnchanged
    operation.perRecordSaveBlock = { recordID, result in
        switch result {
        case .success: // OK
        case .failure(let error):
            if CKError is .serverRecordChanged:
                // Record exists on server -- resolve conflict
                resolveAndRetry(recordID, serverRecord)
            else:
                // Log and continue
        }
    }
```

### 3.3 Merge Strategy During Initial Sync

When fetching with nil token (all remote records), the existing `mergeRemoteChange(local:remote:assetURL:)` logic in `AppModel` handles merging correctly:

- **Same UUID exists locally:** Compare timestamps, pick winner (see Section 4)
- **New UUID from remote:** Insert into local DB
- **Local UUID not on remote:** Will be pushed in the subsequent pushAllLocal call

For ProjectDocuments, a new merge function is needed:

```swift
func mergeRemoteDocumentChange(
    local: ProjectDocument?,
    remote: ProjectDocument
) -> ProjectDocument {
    guard let local else { return remote }
    // Last-modified wins using updatedAt
    return local.updatedAt >= remote.updatedAt ? local : remote
}
```

### 3.4 Rate Limiting

`CKModifyRecordsOperation` has a 400-record limit per operation. For large datasets:

```swift
func chunkedPush(records: [CKRecord], chunkSize: Int = 400) {
    let chunks = stride(from: 0, to: records.count, by: chunkSize).map {
        Array(records[$0..<min($0 + chunkSize, records.count)])
    }
    // Execute chunks sequentially to avoid rate limiting
    for chunk in chunks {
        let operation = CKModifyRecordsOperation(recordsToSave: chunk)
        operation.savePolicy = .changedKeys
        // await completion before next chunk
    }
}
```

---

## 4. Conflict Resolution

### 4.1 CaptureCard Conflicts

**Strategy:** Last-copied wins (using `lastCopiedAt`), fallback to local wins.

**Current implementation** in `CloudSyncEngine.resolveConflict(local:remote:)` (line 402):

| local.lastCopiedAt | remote.lastCopiedAt | Winner |
|---|---|---|
| some(localDate) | some(remoteDate) | Later date wins |
| some | none | Local wins |
| none | some | Remote wins |
| none | none | Local wins |

This logic is also mirrored in `AppModel.mergeWinner(local:remote:)` (line 871) for incoming remote changes.

**No change needed** to the conflict resolution strategy.

### 4.2 ProjectDocument Conflicts

**Strategy:** Last-modified wins (using `updatedAt`).

```swift
private func resolveDocumentConflict(
    local: ProjectDocument,
    remote: ProjectDocument
) -> ProjectDocument {
    return local.updatedAt >= remote.updatedAt ? local : remote
}
```

**Edge case -- superseded documents:** If the local document has `supersededByID != nil` (meaning it was replaced by a newer version locally), the local version chain takes precedence. The current (non-superseded) local document is always the one we compare against remote.

### 4.3 Server Record Changed Errors

When `CKError.serverRecordChanged` occurs during push:

```
1. Extract serverRecord from error.serverRecord
2. Deserialize server record into domain model
3. Compare timestamps with local model
4. Apply winner's fields to serverRecord (preserving server's change tag)
5. Re-save the serverRecord
```

This pattern is already implemented for CaptureCard in `CloudSyncEngine.handleConflict(error:localCard:)` (line 383). An equivalent is needed for ProjectDocument.

---

## 5. Echo Suppression

### 5.1 Current Problem

The current echo suppression in `CloudSyncEngine` has a bug:

```swift
// Line 361-363: processRemoteChanges()
let echoIDs = recentlyPushedIDs
recentlyPushedIDs.removeAll()  // <-- BUG: clears ALL IDs on every fetch
```

**Problem:** If two pushes happen close together, the first fetch clears the IDs from the second push, causing the second push's echo to be processed as a remote change. This creates a feedback loop where changes bounce between the push path and the fetch path.

Additionally, the `recentlyPushedIDs` set has a hard cap of 500 (line 352) and clears entirely when full, which means a large batch push followed by a fetch would lose all echo suppression.

### 5.2 Fix: Time-Based Expiry

Replace `Set<UUID>` with `Dictionary<UUID, Date>` and expire entries after 30 seconds:

```swift
private var recentlyPushedTimestamps: [UUID: Date] = [:]
private static let echoSuppressionTTL: TimeInterval = 30

private func insertRecentlyPushedID(_ id: UUID) {
    pruneExpiredEchoEntries()
    recentlyPushedTimestamps[id] = Date()
}

private func pruneExpiredEchoEntries() {
    let cutoff = Date().addingTimeInterval(-Self.echoSuppressionTTL)
    recentlyPushedTimestamps = recentlyPushedTimestamps.filter { $0.value > cutoff }
}

private func isRecentlyPushed(_ id: UUID) -> Bool {
    guard let timestamp = recentlyPushedTimestamps[id] else { return false }
    return Date().timeIntervalSince(timestamp) < Self.echoSuppressionTTL
}
```

In `processRemoteChanges()`:

```swift
private func processRemoteChanges(upserted: [CKRecord], deleted: [CKRecord.ID]) {
    pruneExpiredEchoEntries()

    var changes: [SyncChange] = []

    for record in upserted {
        guard let card = captureCard(from: record) else {
            // Try ProjectDocument (see Section 7)
            continue
        }
        guard !isRecentlyPushed(card.id) else { continue }
        let assetURL = (record["screenshot"] as? CKAsset)?.fileURL
        changes.append(.upsert(card, screenshotAssetURL: assetURL))
    }

    for recordID in deleted {
        guard let uuid = UUID(uuidString: recordID.recordName) else { continue }
        guard !isRecentlyPushed(uuid) else { continue }
        changes.append(.delete(uuid))
    }

    guard !changes.isEmpty else { return }
    delegate?.cloudSync(self, didReceiveChanges: changes)
}
```

**Key difference:** IDs are never bulk-cleared. Each entry expires individually after 30 seconds. This prevents the race condition where a fetch clears IDs that are still needed for echo suppression of concurrent pushes.

---

## 6. Error Recovery

### 6.1 Network Offline

**Current:** Push methods check `isNetworkAvailable` and skip with an NSLog if offline. Changes are lost.

**Fix: Offline Queue**

```swift
private var offlineQueue: [OfflineOperation] = []

enum OfflineOperation {
    case pushCard(CaptureCard)
    case deleteCard(UUID)
    case pushDocument(ProjectDocument)
    case deleteDocument(UUID)
}
```

When a push is attempted while offline, append to `offlineQueue`. When network becomes available (detected via `NWPathMonitor`), drain the queue:

```swift
// In startNetworkMonitor():
monitor.pathUpdateHandler = { [weak self] path in
    Task { @MainActor [weak self] in
        let wasOffline = !(self?.isNetworkAvailable ?? true)
        self?.isNetworkAvailable = path.status == .satisfied
        if wasOffline && path.status == .satisfied {
            self?.drainOfflineQueue()
        }
    }
}
```

**Queue limit:** Cap at 1000 operations. If exceeded, drop oldest and mark for full re-sync on next launch.

### 6.2 Change Token Expired

**Current:** Handled correctly. When `CKError.changeTokenExpired` is received in `recordZoneFetchResultBlock`, the token is set to nil and `fetchRemoteChanges()` is called again (fetches all records).

**Enhancement:** After a token-expired full re-fetch, trigger `pushAllLocalData()` to ensure local-only records reach the server.

### 6.3 Rate Limited

**Current:** Handled via `retryOnTransientError()` which respects `error.retryAfterSeconds`. Max 3 retry attempts with exponential backoff.

**Enhancement:** For batch operations, add per-record error handling:

```swift
operation.perRecordSaveBlock = { [weak self] recordID, result in
    if case .failure(let error) = result,
       let ckError = error as? CKError,
       ckError.code == .requestRateLimited {
        // Re-queue this specific record for retry
        self?.requeueForRetry(recordID)
    }
}
```

### 6.4 Partial Batch Failure

When a `CKModifyRecordsOperation` partially fails:

```swift
operation.perRecordSaveBlock = { recordID, result in
    switch result {
    case .success(let record):
        successCount += 1
    case .failure(let error):
        failedRecordIDs.append(recordID)
        // Log per-record error
    }
}

operation.modifyRecordsResultBlock = { result in
    // If some records failed, retry them in a separate operation
    if !failedRecordIDs.isEmpty {
        retryFailedRecords(failedRecordIDs)
    }
}
```

### 6.5 Zone Not Found

If the zone is deleted (e.g., user reset iCloud data):

```swift
case .zoneNotFound:
    // Re-create zone, re-subscribe, push all local data
    serverChangeToken = nil
    Task {
        try await createZoneIfNeeded()
        try await subscribeToChanges()
        pushAllLocalData(...)
    }
```

---

## 7. Multi-Record-Type Fetch Handling

### 7.1 Expanded SyncChange Enum

```swift
enum SyncChange: Sendable {
    case upsertCard(CaptureCard, screenshotAssetURL: URL?)
    case deleteCard(UUID)
    case upsertDocument(ProjectDocument)
    case deleteDocument(UUID)
}
```

**Migration note:** Rename existing `.upsert` to `.upsertCard` and `.delete` to `.deleteCard`. Update all call sites in `AppModel`.

### 7.2 Record Type Routing in processRemoteChanges

```swift
private func processRemoteChanges(upserted: [CKRecord], deleted: [CKRecord.ID]) {
    pruneExpiredEchoEntries()
    var changes: [SyncChange] = []

    for record in upserted {
        let id = UUID(uuidString: record.recordID.recordName)
        guard let id, !isRecentlyPushed(id) else { continue }

        switch record.recordType {
        case Self.cardRecordType:
            guard let card = captureCard(from: record) else { continue }
            let assetURL = (record["screenshot"] as? CKAsset)?.fileURL
            changes.append(.upsertCard(card, screenshotAssetURL: assetURL))

        case Self.documentRecordType:
            guard let doc = projectDocument(from: record) else { continue }
            changes.append(.upsertDocument(doc))

        default:
            break
        }
    }

    for recordID in deleted {
        guard let uuid = UUID(uuidString: recordID.recordName) else { continue }
        guard !isRecentlyPushed(uuid) else { continue }
        // We don't know the record type for deletions, so emit both
        // The delegate will check which store contains this ID
        changes.append(.deleteCard(uuid))
        changes.append(.deleteDocument(uuid))
    }

    guard !changes.isEmpty else { return }
    delegate?.cloudSync(self, didReceiveChanges: changes)
}
```

**Deletion ambiguity:** `recordWithIDWasDeletedBlock` provides the record type as the second parameter. Use it:

```swift
operation.recordWithIDWasDeletedBlock = { recordID, recordType in
    // recordType tells us which type was deleted
    deletedRecords.append((recordID, recordType))
}
```

Then route deletions correctly:

```swift
for (recordID, recordType) in deletedRecords {
    guard let uuid = UUID(uuidString: recordID.recordName) else { continue }
    guard !isRecentlyPushed(uuid) else { continue }
    switch recordType {
    case Self.cardRecordType:
        changes.append(.deleteCard(uuid))
    case Self.documentRecordType:
        changes.append(.deleteDocument(uuid))
    default:
        break
    }
}
```

### 7.3 Expanded CloudSyncDelegate

```swift
@MainActor
protocol CloudSyncDelegate: AnyObject {
    func cloudSync(_ engine: CloudSyncEngine, didReceiveChanges changes: [SyncChange])
    func cloudSyncDidComplete(_ engine: CloudSyncEngine)
    func cloudSync(_ engine: CloudSyncEngine, didFailWithError message: String)
    func cloudSync(_ engine: CloudSyncEngine, accountStatusChanged status: CloudSyncAccountStatus)
}
```

The delegate signature stays the same -- `SyncChange` carries the type information. `AppModel` handles routing in `cloudSync(_:didReceiveChanges:)`.

### 7.4 Expanded CloudSyncControlling Protocol

```swift
@MainActor
protocol CloudSyncControlling: AnyObject {
    var delegate: CloudSyncDelegate? { get set }

    func setup() async
    func stop()
    func fetchRemoteChanges()
    func handleRemoteNotification()

    // CaptureCard operations (existing)
    func pushLocalChange(card: CaptureCard)
    func pushDeletion(id: UUID)
    func pushBatch(cards: [CaptureCard], deletions: [UUID])

    // ProjectDocument operations (new)
    func pushLocalChange(document: ProjectDocument)
    func pushDocumentDeletion(id: UUID)
    func pushDocumentBatch(documents: [ProjectDocument], deletions: [UUID])

    // Initial sync (new)
    func pushAllLocalData(cards: [CaptureCard], documents: [ProjectDocument])
}
```

---

## 8. AppModel Integration for ProjectDocument Sync

### 8.1 Document Change Notifications

`ProjectDocumentStore` does not currently notify the sync engine of changes. Two approaches:

**Option A: NotificationCenter (recommended)**

`ProjectDocumentStore` posts notifications after save/update/delete:

```swift
extension Notification.Name {
    static let projectDocumentDidChange = Notification.Name("projectDocumentDidChange")
    static let projectDocumentDidDelete = Notification.Name("projectDocumentDidDelete")
}
```

`AppModel` observes these and pushes to CloudKit:

```swift
NotificationCenter.default.addObserver(
    forName: .projectDocumentDidChange,
    object: nil,
    queue: .main
) { [weak self] notification in
    guard let doc = notification.userInfo?["document"] as? ProjectDocument else { return }
    self?.cloudSyncEngine?.pushLocalChange(document: doc)
}
```

**Option B: Direct injection** -- Pass the sync engine into `ProjectDocumentStore`. Rejected because it creates a circular dependency and violates the store's single-responsibility.

### 8.2 Applying Remote Document Changes

New method in `AppModel` (or a dedicated coordinator):

```swift
func applyRemoteDocumentChanges(_ changes: [SyncChange]) {
    for change in changes {
        switch change {
        case .upsertDocument(let remote):
            applyRemoteDocumentUpsert(remote)
        case .deleteDocument(let id):
            applyRemoteDocumentDeletion(id)
        default:
            break
        }
    }
}

private func applyRemoteDocumentUpsert(_ remote: ProjectDocument) {
    // Skip superseded documents
    guard remote.supersededByID == nil else { return }

    do {
        let local = try documentStore.currentDocument(
            project: remote.project,
            topic: remote.topic,
            documentType: remote.documentType
        )

        if let local {
            // Conflict: compare updatedAt
            guard remote.updatedAt > local.updatedAt else { return }
        }

        // Save remote version locally (bypassing normal validation for sync)
        try documentStore.upsertFromSync(remote)
    } catch {
        NSLog("CloudSync document apply failed: %@", error.localizedDescription)
    }
}
```

**New store method needed:** `ProjectDocumentStore.upsertFromSync(_ document: ProjectDocument)` that writes directly without the 200-character validation (since the remote already passed validation on the originating device).

---

## 9. Implementation Phases

### Phase 1: Fix Existing CaptureCard Sync

**Goal:** Make CaptureCard sync reliable and complete.

**Tasks:**

1. **Echo suppression fix** (`CloudSyncEngine.swift`)
   - Replace `recentlyPushedIDs: Set<UUID>` with `recentlyPushedTimestamps: [UUID: Date]`
   - Add `pruneExpiredEchoEntries()`, `isRecentlyPushed(_:)` methods
   - Update `processRemoteChanges()` to use time-based check instead of clear-all
   - Remove `maxRecentlyPushedIDs` constant
   - Files: `PromptCue/Services/CloudSyncEngine.swift`

2. **Initial full sync for CaptureCards** (`CloudSyncEngine.swift`, `AppModel.swift`)
   - Add `pushAllLocalData(cards:documents:)` to `CloudSyncControlling`
   - Implement chunked batch push (400 records per operation)
   - Detect first sync via `serverChangeToken == nil` in fetch completion
   - After first fetch completes, call `pushAllLocalData` with all local cards
   - Add `isInitialSync` flag to prevent re-triggering
   - Files: `CloudSyncEngine.swift`, `CloudSyncControlling.swift`, `AppModel.swift`

3. **Foreground fetch** (`AppCoordinator.swift`, `AppModel.swift`)
   - Add `fetchRemoteChangesIfSyncEnabled()` to `AppModel`
   - Call it from `experimentalMCPHTTPDidBecomeActiveObserver` in `AppCoordinator`
   - Respects existing 30-second `lastDidBecomeActiveWork` throttle
   - Files: `PromptCue/App/AppCoordinator.swift`, `PromptCue/App/AppModel.swift`

4. **Wake fetch** (`AppCoordinator.swift`)
   - Add `self.model.fetchRemoteChangesIfSyncEnabled()` to `experimentalMCPHTTPWakeObserver`
   - Files: `PromptCue/App/AppCoordinator.swift`

5. **Periodic safety-net fetch** (`CloudSyncEngine.swift`)
   - Add `periodicFetchTimer` (5-minute interval, 60-second tolerance)
   - Start in `setup()`, stop in `stop()`
   - Files: `PromptCue/Services/CloudSyncEngine.swift`

**Estimated scope:** ~200 lines changed across 4 files.

### Phase 2: Add ProjectDocument Sync

**Goal:** Full sync support for memory documents.

**Tasks:**

1. **Record mapping** (`CloudSyncEngine.swift`)
   - Add `static let documentRecordType = "ProjectDocument"`
   - Add `applyDocumentFields(_:to:)` method
   - Add `projectDocument(from:)` deserialization method
   - Add `newDocumentRecord(from:)` helper
   - Files: `PromptCue/Services/CloudSyncEngine.swift`

2. **Push methods** (`CloudSyncEngine.swift`, `CloudSyncControlling.swift`)
   - Add `pushLocalChange(document:)` -- single document push
   - Add `pushDocumentDeletion(id:)` -- single document deletion
   - Add `pushDocumentBatch(documents:deletions:)` -- batch operations
   - Update `CloudSyncControlling` protocol with new methods
   - Files: `CloudSyncEngine.swift`, `CloudSyncControlling.swift`

3. **Fetch routing** (`CloudSyncEngine.swift`)
   - Expand `SyncChange` enum with `.upsertDocument` and `.deleteDocument` cases
   - Update `processRemoteChanges()` to route by `record.recordType`
   - Use `recordWithIDWasDeletedBlock`'s record type parameter for deletions
   - Files: `CloudSyncEngine.swift`

4. **AppModel delegate expansion** (`AppModel.swift`)
   - Update `cloudSync(_:didReceiveChanges:)` to handle document changes
   - Add `applyRemoteDocumentChanges()` with merge logic
   - Add `mergeRemoteDocumentChange(local:remote:)` with updatedAt comparison
   - Files: `PromptCue/App/AppModel.swift`

5. **ProjectDocumentStore sync support** (`ProjectDocumentStore.swift`)
   - Add `upsertFromSync(_ document: ProjectDocument)` -- bypass validation
   - Add `deleteFromSync(id: UUID)` -- direct deletion
   - Post `Notification.Name.projectDocumentDidChange` after save/update
   - Post `Notification.Name.projectDocumentDidDelete` after delete
   - Files: `PromptCue/Services/ProjectDocumentStore.swift`

6. **AppModel observation** (`AppModel.swift`)
   - Observe `projectDocumentDidChange` and push to sync engine
   - Observe `projectDocumentDidDelete` and push deletion to sync engine
   - Files: `PromptCue/App/AppModel.swift`

7. **Include documents in initial full sync** (`AppModel.swift`)
   - Load all current (non-superseded) ProjectDocuments
   - Pass to `pushAllLocalData(cards:documents:)`
   - Files: `PromptCue/App/AppModel.swift`

**Estimated scope:** ~400 lines added across 4 files.

### Phase 3: Polish

**Goal:** Resilient sync with good UX.

**Tasks:**

1. **Offline queue** (`CloudSyncEngine.swift`)
   - Add `offlineQueue: [OfflineOperation]` array
   - Queue operations when `isNetworkAvailable == false`
   - Drain queue on network restore via `NWPathMonitor`
   - Cap at 1000 operations
   - Files: `PromptCue/Services/CloudSyncEngine.swift`

2. **Zone-not-found recovery** (`CloudSyncEngine.swift`)
   - Handle `.zoneNotFound` error in fetch
   - Re-create zone, re-subscribe, trigger full sync
   - Files: `PromptCue/Services/CloudSyncEngine.swift`

3. **Improved error reporting** (`CloudSyncSettingsModel.swift`, `AppModel.swift`)
   - Differentiate error types in UI (network, auth, rate limit, conflict)
   - Show "Syncing..." state during active operations
   - Show record counts in settings ("X prompts, Y docs synced")
   - Files: `PromptCue/UI/Settings/CloudSyncSettingsModel.swift`

4. **MemoryViewerModel refresh on sync** (`MemoryViewerModel.swift`)
   - Observe `projectDocumentDidChange` notification (from sync apply)
   - Call `refresh()` to update the Memory UI
   - Files: `PromptCue/UI/Memory/MemoryViewerModel.swift`

**Estimated scope:** ~200 lines across 4 files.

---

## 10. Open Questions & Trade-offs

### 10.1 Zone Naming

The zone is named `Cards` but will now contain `ProjectDocument` records too. Options:
- **Keep `Cards`** (recommended) -- renaming requires migrating all existing records to a new zone, which is complex and error-prone for no user-visible benefit.
- **Create a second zone `Documents`** -- doubles the subscription and token management complexity.

**Recommendation:** Keep `Cards` zone. The name is an internal implementation detail.

### 10.2 Document Content Size

ProjectDocument `content` can be large (structured markdown). CloudKit string fields have a 1MB limit per record. This is unlikely to be hit for markdown documents but should be validated:

```swift
guard content.utf8.count < 1_000_000 else {
    // Content too large for CloudKit sync
    // Log warning, skip sync for this document
    return
}
```

### 10.3 Superseded Document Chain

Only current (non-superseded) documents are synced. The version history is local-only. This means:
- Undo history does not sync across devices
- A document edited on Device A, then reverted on Device A, then edited on Device B will not have Device A's revert available on Device B

This is acceptable for the current use case. Full version chain sync would require syncing all records including superseded ones, significantly increasing storage and complexity.

### 10.4 Deletion Ambiguity

When a `CKRecord` deletion arrives and we don't know the record type, we could check both stores. However, using `recordWithIDWasDeletedBlock`'s record type parameter (available since iOS 15/macOS 12) eliminates this ambiguity entirely. Since the deployment target is macOS 14.0, this is safe.

### 10.5 Conflict Resolution Granularity

Both CaptureCard and ProjectDocument use whole-record conflict resolution (winner takes all). For documents with large `content` fields, field-level or section-level merge would be more user-friendly but dramatically more complex.

**Recommendation:** Start with whole-record last-modified-wins. If users report data loss from conflicts, consider section-level merge as a future enhancement.

### 10.6 Screenshot Asset Sync for Documents

ProjectDocuments do not have attachments. If this changes in the future, the `CKAsset` pattern from CaptureCard can be reused.

### 10.7 Recall Metadata Sync

`stability`, `recallCount`, and `lastRecalledAt` are synced as part of the ProjectDocument record. This means recall events on one device affect the vividness tier on other devices. However, recall events themselves are not independently synced -- only the resulting metadata values. If two devices recall the same document at the same time, the conflict resolution (last-updatedAt-wins) may lose one device's recall update.

**Recommendation:** Acceptable trade-off. Recall metadata is advisory, not critical. The vividness system is self-correcting (continued use on any device will naturally update stability).
