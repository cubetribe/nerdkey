import Foundation
import Crypto

/// Computes a stable machine fingerprint as SHA-256 hex.
///
/// Sources by platform:
/// - macOS: IOPlatformSerialNumber (IOKit), fallback kern.uuid
/// - Linux: /etc/machine-id, fallback hostname + first MAC address
public struct MachineFingerprint {

    /// Returns the fingerprint — either from the NERDKEY_FINGERPRINT_OVERRIDE
    /// environment variable (for testing) or the real machine identifier.
    public static func current() -> String {
        if let override = ProcessInfo.processInfo.environment["NERDKEY_FINGERPRINT_OVERRIDE"],
           !override.isEmpty {
            return sha256hex(override)
        }
        let raw = rawIdentifier()
        return sha256hex(raw)
    }

    static func rawIdentifier() -> String {
        #if os(macOS)
        return macOSIdentifier()
        #elseif os(Linux)
        return linuxIdentifier()
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }

    #if os(macOS)
    private static func macOSIdentifier() -> String {
        // Try IOPlatformSerialNumber via sysctl / IOKit service
        if let serial = ioKitSerialNumber(), !serial.isEmpty, serial != "Not Specified" {
            return serial
        }
        // Fallback: kern.uuid
        return kernUUID() ?? ProcessInfo.processInfo.hostName
    }

    private static func ioKitSerialNumber() -> String? {
        // Use system_profiler via subprocess — avoids IOKit framework linkage complexity
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPHardwareDataType"]
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launch()
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Serial Number") {
                // "Serial Number (system): XXXXXXXXXX"
                let components = trimmed.components(separatedBy: ":")
                if components.count >= 2 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    private static func kernUUID() -> String? {
        var size = 0
        sysctlbyname("kern.uuid", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.uuid", &buf, &size, nil, 0)
        return String(cString: buf)
    }
    #endif

    #if os(Linux)
    private static func linuxIdentifier() -> String {
        // Try /etc/machine-id
        if let id = try? String(contentsOfFile: "/etc/machine-id", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !id.isEmpty {
            return id
        }
        // Fallback: hostname + first non-loopback MAC
        let hostname = ProcessInfo.processInfo.hostName
        let mac = firstMACAddress() ?? ""
        return "\(hostname):\(mac)"
    }

    private static func firstMACAddress() -> String? {
        guard let lines = try? String(contentsOfFile: "/proc/net/if_inet6", encoding: .utf8) else { return nil }
        // Simple approach: read from /sys/class/net/<iface>/address
        let fm = FileManager.default
        guard let ifaces = try? fm.contentsOfDirectory(atPath: "/sys/class/net") else { return nil }
        for iface in ifaces.sorted() where iface != "lo" {
            let path = "/sys/class/net/\(iface)/address"
            if let mac = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
               mac != "00:00:00:00:00:00" {
                return mac
            }
        }
        return nil
    }
    #endif

    /// SHA-256 hex of the given string.
    public static func sha256hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
