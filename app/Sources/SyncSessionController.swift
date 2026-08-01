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
    private let diagnostics: any DiagnosticsRecording
    private var task: Task<Void, Never>?

    init(
        engine: any SyncEngineControlling,
        vaultAccess: any VaultAccessProviding,
        policy: SyncSessionPolicy = SyncSessionPolicy(),
        conflictScanner: any VaultConflictScanning = VaultConflictScanner(),
        diagnostics: (any DiagnosticsRecording)? = nil,
        sleeper: @escaping Sleeper = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.engine = engine
        self.vaultAccess = vaultAccess
        self.policy = policy
        self.conflictScanner = conflictScanner
        self.diagnostics = diagnostics ?? NoOpDiagnosticsRecorder()
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
            transition(to: .acquiringVaultAccess)
            accessSession = try vaultAccess.openSession()
            try Task.checkCancellation()

            transition(to: .startingEngine)
            try engine.prepare()
            try engine.start()
            engineStarted = true
            try Task.checkCancellation()

            transition(to: .configuring)
            try engine.configurePeer(validatedProfile)
            try engine.configureFolder(validatedProfile, vaultPath: accessSession!.url.path)

            transition(to: .scanning)
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
                    transition(to: .verifyingCompletion)
                    if stableSamples >= policy.requiredStableSamples {
                        try finish(engineStarted: &engineStarted, accessSession: &accessSession)
                        let completedPhase: SyncSessionPhase = conflicts.isEmpty
                            ? .complete
                            : .completeWithConflicts
                        transition(
                            to: completedPhase,
                            outcome: conflicts.isEmpty ? .success : .successWithConflicts
                        )
                        task = nil
                        return
                    }
                } else {
                    stableSamples = 0
                    transition(to: phaseForStatus(current))
                }

                if poll + 1 < policy.maximumPolls {
                    try await sleeper(policy.pollIntervalNanoseconds)
                }
            }
            throw SyncSessionError.timedOut
        } catch is CancellationError {
            cleanup(engineStarted: &engineStarted, accessSession: &accessSession)
            transition(to: .cancelled, outcome: .cancelled)
            lastError = nil
        } catch {
            let outcome = diagnosticOutcome(for: error, phase: phase)
            cleanup(engineStarted: &engineStarted, accessSession: &accessSession)
            transition(to: .failed, outcome: outcome)
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
        transition(to: .stoppingEngine)
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

    private func transition(
        to newPhase: SyncSessionPhase,
        outcome: DiagnosticOutcome? = nil
    ) {
        guard phase != newPhase || outcome != nil else { return }
        phase = newPhase
        diagnostics.record(phase: newPhase, status: status, outcome: outcome)
    }

    private func diagnosticOutcome(
        for error: Error,
        phase: SyncSessionPhase
    ) -> DiagnosticOutcome {
        if error is SyncSessionError {
            return .timeout
        }
        if error is VaultAccessError || phase == .acquiringVaultAccess {
            return .vaultAccessFailure
        }
        if error is SyncProfileError || phase == .configuring {
            return .configurationFailure
        }
        return .engineFailure
    }
}
