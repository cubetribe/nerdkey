import Foundation
import NerdKeyKit

// MARK: - CLI argument parsing

struct CLI {
    var licenseKey: String = ""
    var baseURL: String = NerdKeyConstants.defaultBaseURL
    var accountId: String = NerdKeyConstants.accountId
    var tlsSkipVerify: Bool = true
    var stateDir: String? = nil
    var command: String = "run-proof"

    static func parse() -> CLI {
        var cli = CLI()
        var args = CommandLine.arguments.dropFirst()
        while let arg = args.first {
            args = args.dropFirst()
            switch arg {
            case "--license-key":
                cli.licenseKey = args.first ?? ""; args = args.dropFirst()
            case "--keygen-base-url":
                cli.baseURL = args.first ?? NerdKeyConstants.defaultBaseURL; args = args.dropFirst()
            case "--account-id":
                cli.accountId = args.first ?? NerdKeyConstants.accountId; args = args.dropFirst()
            case "--tls-skip-verify":
                cli.tlsSkipVerify = true
            case "--state-dir":
                cli.stateDir = args.first; args = args.dropFirst()
            case "activate", "validate", "deactivate", "run-proof":
                cli.command = arg
            default:
                if !arg.hasPrefix("--") { cli.command = arg }
            }
        }
        return cli
    }
}

// MARK: - Async run using DispatchSemaphore to bridge to sync main

let sema = DispatchSemaphore(value: 0)

let cli = CLI.parse()

Task {
    defer { sema.signal() }

    if cli.command == "run-proof" {
        await runProofSequence(cli: cli)
        return
    }

    guard !cli.licenseKey.isEmpty else {
        print("Error: --license-key is required")
        Foundation.exit(1)
    }

    let config = NerdKeyConfig(
        baseURL: cli.baseURL,
        accountId: cli.accountId,
        tlsSkipVerify: cli.tlsSkipVerify,
        appSlug: "sdk-test",
        stateDirOverride: cli.stateDir
    )

    do {
        let sdk = try NerdKey(config: config)
        switch cli.command {
        case "activate":
            let machineId = try await sdk.activate(licenseKey: cli.licenseKey)
            print("Activated. machineId=\(machineId)")
        case "validate":
            try await sdk.validateOnLaunch()
            print("Valid.")
        case "deactivate":
            try await sdk.deactivate()
            print("Deactivated.")
        default:
            print("Unknown command: \(cli.command)")
            Foundation.exit(1)
        }
    } catch {
        print("Error: \(error)")
        Foundation.exit(1)
    }
}

sema.wait()

// MARK: - Proof sequence

func runProofSequence(cli: CLI) async {
    guard !cli.licenseKey.isEmpty else {
        print("Error: --license-key is required for run-proof")
        Foundation.exit(1)
    }

    let licenseKey = cli.licenseKey
    let baseURL = cli.baseURL

    let stateDir1 = "/tmp/nerdkey-proof-m1"
    let stateDir2 = "/tmp/nerdkey-proof-m2"
    let stateDir3 = "/tmp/nerdkey-proof-m3"

    for dir in [stateDir1, stateDir2, stateDir3] {
        try? FileManager.default.removeItem(atPath: dir)
    }

    func makeConfig(stateDir: String) -> NerdKeyConfig {
        NerdKeyConfig(
            baseURL: baseURL,
            accountId: cli.accountId,
            tlsSkipVerify: cli.tlsSkipVerify,
            appSlug: "sdk-proof",
            stateDirOverride: stateDir
        )
    }

    print("========================================")
    print("NerdKey Swift SDK Proof Sequence")
    print("License key: \(licenseKey.prefix(44))...")
    print("Base URL: \(baseURL)")
    print("========================================\n")

    // STEP 1
    print("[STEP 1] activate(licenseKey) -> machine 1")
    var machineId1 = ""
    setenv("NERDKEY_FINGERPRINT_OVERRIDE", "sdk-proof-machine-001", 1)
    do {
        let sdk = try NerdKey(config: makeConfig(stateDir: stateDir1))
        machineId1 = try await sdk.activate(licenseKey: licenseKey)
        print("  PASS: machineId=\(machineId1)\n")
    } catch {
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL: \(error)\n"); Foundation.exit(1)
    }
    unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")

    // STEP 2
    print("[STEP 2] validateOnLaunch() -> expect VALID")
    setenv("NERDKEY_FINGERPRINT_OVERRIDE", "sdk-proof-machine-001", 1)
    do {
        let sdk = try NerdKey(config: makeConfig(stateDir: stateDir1))
        try await sdk.validateOnLaunch()
        print("  PASS: valid\n")
    } catch {
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL: \(error)\n"); Foundation.exit(1)
    }
    unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")

    // STEP 3
    print("[STEP 3] activate(licenseKey) again -> idempotent success")
    setenv("NERDKEY_FINGERPRINT_OVERRIDE", "sdk-proof-machine-001", 1)
    do {
        let sdk = try NerdKey(config: makeConfig(stateDir: stateDir1))
        let machineIdAgain = try await sdk.activate(licenseKey: licenseKey)
        guard machineIdAgain == machineId1 else {
            unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
            print("  FAIL: different machineId returned: \(machineIdAgain)\n"); Foundation.exit(1)
        }
        print("  PASS: machineId=\(machineIdAgain) (same)\n")
    } catch {
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL: \(error)\n"); Foundation.exit(1)
    }
    unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")

    // STEP 4
    print("[STEP 4] activate(licenseKey) machine 2 -> success (seat 2 of 2)")
    setenv("NERDKEY_FINGERPRINT_OVERRIDE", "sdk-proof-machine-002", 1)
    var machineId2 = ""
    do {
        let sdk = try NerdKey(config: makeConfig(stateDir: stateDir2))
        machineId2 = try await sdk.activate(licenseKey: licenseKey)
        print("  PASS: machineId=\(machineId2)\n")
    } catch {
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL: \(error)\n"); Foundation.exit(1)
    }
    unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")

    // STEP 5
    print("[STEP 5] activate(licenseKey) machine 3 -> expect SeatLimitExceeded")
    setenv("NERDKEY_FINGERPRINT_OVERRIDE", "sdk-proof-machine-003", 1)
    do {
        let sdk = try NerdKey(config: makeConfig(stateDir: stateDir3))
        _ = try await sdk.activate(licenseKey: licenseKey)
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL: expected SeatLimitExceeded but activation succeeded\n"); Foundation.exit(1)
    } catch NerdKeyError.seatLimitExceeded {
        print("  PASS: SeatLimitExceeded thrown as expected\n")
    } catch {
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL: unexpected error: \(error)\n"); Foundation.exit(1)
    }
    unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")

    // STEP 6
    print("[STEP 6] deactivate() machines 1 and 2")
    setenv("NERDKEY_FINGERPRINT_OVERRIDE", "sdk-proof-machine-001", 1)
    do {
        let sdk = try NerdKey(config: makeConfig(stateDir: stateDir1))
        try await sdk.deactivate()
        print("  PASS: machine 1 deactivated")
    } catch {
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL machine 1: \(error)\n"); Foundation.exit(1)
    }
    unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")

    setenv("NERDKEY_FINGERPRINT_OVERRIDE", "sdk-proof-machine-002", 1)
    do {
        let sdk = try NerdKey(config: makeConfig(stateDir: stateDir2))
        try await sdk.deactivate()
        print("  PASS: machine 2 deactivated\n")
    } catch {
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL machine 2: \(error)\n"); Foundation.exit(1)
    }
    unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")

    // STEP 7
    print("[STEP 7] validateOnLaunch() after deactivate -> expect NotActivated")
    setenv("NERDKEY_FINGERPRINT_OVERRIDE", "sdk-proof-machine-001", 1)
    do {
        let sdk = try NerdKey(config: makeConfig(stateDir: stateDir1))
        try await sdk.validateOnLaunch()
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL: expected NotActivated but validate returned normally\n"); Foundation.exit(1)
    } catch NerdKeyError.notActivated {
        print("  PASS: NotActivated thrown as expected\n")
    } catch {
        unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")
        print("  FAIL: unexpected error: \(error)\n"); Foundation.exit(1)
    }
    unsetenv("NERDKEY_FINGERPRINT_OVERRIDE")

    print("========================================")
    print("ALL PROOF STEPS PASSED")
    print("========================================")
}
