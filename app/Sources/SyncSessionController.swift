import Combine
import Foundation

enum SyncSessionPhase: String, Equatable {
    case idle
    case acquiringVaultAccess
    case startingEngine
    case configuring
    case scanning
    case waitingForPeer
    case synchronizing
    case verifyingCompletion
    case stoppingEngine
    case complete
    case completeWithConflicts
    case failed
    case cancelled

    var isActive: Bool {
        switch self {
        case .acquiringVaultAccess, .startingEngine, .configuring, .scanning,
             .waitingForPeer, .synchronizing, .verifyingCompletion, .stoppingEngine:
            return true
        default:
            return false
        }
    }
}

enum SyncSessionError: LocalizedError {
    case alreadyRunning
    case timedOut

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "A sync session is already running."
        case .timedOut:
            return "The peer did not reach a verified up-to-date state before the session timed out."
        }
    }
}

struct SyncSessionPolicy {
    var maximumPolls = 180
    var pollIntervalNanoseconds: UInt64 = 1_000_000_000
    var requiredStableSamples = 2
}

@MainActor
final class SyncSessionController: ObservableObject {
    typealias Sleeper = @Sendable (UInt64) async throws -> Void

    @Published private(set) var phase: SyncSessionPhase = .idle
    @Published private(set) var status: FolderSyncStatus?
    @Published private(set) var conflicts: [String] = []
    @Published private(set) var lastError: String?

    private let engine: any SyncEngineControlling
    private let vaultAccess: any VaultAccessProviding
    private let policy: SyncSessionPolicy
    private let sleeper: Sleeper
    private let conflictScanner: any VaultConflictScanning
    private var task: Task<Void, Never>?

    init(
        engine: any SyncEngineControlling,
        vaultAccess: any VaultAccessProviding,
        policy: SyncSessionPolicy = SyncSessionPolicy(),
        conflictScanner: any VaultConflictScanning = VaultConflictScanner(),
        sleeper: @escaping Sleeper = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.engine = engine
        self.vaultAccess = vaultAccess
        self.policy = policy
        self.conflictScanner = conflictScanner
        self.sleeper = sleeper
    }

    func start(profile: SyncProfile) throws {
        guard !phase.isActive else {
            throw SyncSessionError.alreadyRunning
        }
        task = Task { [weak self] in
            await self?.run(profile: profile)
        }
    }

    func cancel() {
        task?.cancel()
    }

    func run(profile: SyncProfile) async {
        guard !phase.isActive else {
            lastError = SyncSessionError.alreadyRunning.localizedDescription
            return
        }

        var accessSession: (any VaultAccessSessionProtocol)?
        var engineStarted = false
        status = nil
        conflicts = []
        lastError = nil

        do {
            let validatedProfile = try profile.validated()
            phase = .acquiringVaultAccess
            accessSession = try vaultAccess.openSession()
            try Task.checkCancellation()

            phase = .startingEngine
            try engine.prepare()
            try engine.start()
            engineStarted = true
            try Task.checkCancellation()

            phase = .configuring
            try engine.configurePeer(validatedProfile)
            try engine.configureFolder(validatedProfile, vaultPath: accessSession!.url.path)

            phase = .scanning
            try engine.scan(folderID: validatedProfile.folderID)

            var stableSamples = 0
            for poll in 0..<policy.maximumPolls {
                try Task.checkCancellation()
                let current = try engine.folderStatus(
                    folderID: validatedProfile.folderID,
                    peerDeviceID: validatedProfile.peerDeviceID
                )
                status = current

                if current.upToDate {
                    stableSamples += 1
                    phase = .verifyingCompletion
                    if stableSamples >= policy.requiredStableSamples {
                        try finish(engineStarted: &engineStarted, accessSession: &accessSession)
                        phase = conflicts.isEmpty ? .complete : .completeWithConflicts
                        task = nil
                        return
                    }
                } else {
                    stableSamples = 0
                    phase = phaseForStatus(current)
                }

                if poll + 1 < policy.maximumPolls {
                    try await sleeper(policy.pollIntervalNanoseconds)
                }
            }
            throw SyncSessionError.timedOut
        } catch is CancellationError {
            cleanup(engineStarted: &engineStarted, accessSession: &accessSession)
            phase = .cancelled
            lastError = nil
        } catch {
            cleanup(engineStarted: &engineStarted, accessSession: &accessSession)
            phase = .failed
            lastError = error.localizedDescription
        }
        task = nil
    }

    private func phaseForStatus(_ status: FolderSyncStatus) -> SyncSessionPhase {
        if !status.peerConnected {
            return .waitingForPeer
        }
        if status.folderState.localizedCaseInsensitiveContains("scan") {
            return .scanning
        }
        return .synchronizing
    }

    private func finish(
        engineStarted: inout Bool,
        accessSession: inout (any VaultAccessSessionProtocol)?
    ) throws {
        phase = .stoppingEngine
        if engineStarted {
            try engine.stop()
            engineStarted = false
        }
        if let vaultURL = accessSession?.url {
            conflicts = try conflictScanner.conflictPaths(in: vaultURL)
        }
        accessSession?.close()
        accessSession = nil
    }

    private func cleanup(
        engineStarted: inout Bool,
        accessSession: inout (any VaultAccessSessionProtocol)?
    ) {
        if engineStarted {
            try? engine.stop()
            engineStarted = false
        }
        accessSession?.close()
        accessSession = nil
    }
}
