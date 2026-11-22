import CryptoKit
import Foundation

enum MicSetup {
    private static let toneDirectory = "ep-talk"
    private static let toneNames = (0..<4).map { "\($0).wav" }
    private static let files = toneNames.map { "\(toneDirectory)/\($0)" } + ["config.json", "main.py"]
    private typealias SignalFile = (name: String, data: Data)

    struct SetupError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func isMicVolume(_ url: URL) -> Bool {
        let names = ["FX MIC DISK", "FX-MIC DISK"]
        return url.deletingLastPathComponent().resolvingSymlinksInPath().path == "/Volumes"
            && names.contains(url.lastPathComponent.uppercased())
    }

    @concurrent
    static func install(on volume: URL, from payload: URL) async throws -> String {
        try validate(volume)
        let contents = try payloadFiles(in: payload)
        if let previous = try previousInstallation(in: volume, matching: contents),
           previous.count == files.count {
            return "The signaling files are already installed. Eject the mic and use its curly cable."
        }
        let existing = try contents.filter { item in
            let target = volume.appendingPathComponent(item.name)
            guard FileManager.default.fileExists(atPath: target.path) else { return false }
            guard try Data(contentsOf: target) == item.data else {
                throw SetupError(message: "Existing \(item.name) is different. EP Talk left the mic untouched.")
            }
            return true
        }
        if existing.count == files.count { return "The signaling files are already installed. Eject the mic and use its curly cable." }
        guard existing.isEmpty else {
            throw SetupError(message: "The mic has a partial setup. Use Remove Signals, then prepare it again.")
        }

        let manager = FileManager.default
        let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                      appropriateFor: nil, create: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = support.appendingPathComponent("EP Talk/Mic Backups/\(stamp)-\(UUID().uuidString.prefix(6))")
        try manager.createDirectory(at: backup, withIntermediateDirectories: true)
        for item in try manager.contentsOfDirectory(at: volume, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            try manager.copyItem(at: item, to: backup.appendingPathComponent(item.lastPathComponent))
        }

        let signalDirectory = volume.appendingPathComponent(toneDirectory)
        let createDirectory = !manager.fileExists(atPath: signalDirectory.path)
        if createDirectory { try manager.createDirectory(at: signalDirectory, withIntermediateDirectories: false) }

        var written: [URL] = []
        do {
            for item in contents {
                let target = volume.appendingPathComponent(item.name)
                // Only write absent files. Activate the startup script last.
                try item.data.write(to: target, options: .withoutOverwriting)
                written.append(target)
                guard try Data(contentsOf: target) == item.data else {
                    throw SetupError(message: "Verification failed for \(item.name).")
                }
            }
        } catch {
            for target in written.reversed() { try? manager.removeItem(at: target) }
            if createDirectory, (try? manager.contentsOfDirectory(atPath: signalDirectory.path).isEmpty) == true {
                try? manager.removeItem(at: signalDirectory)
            }
            throw SetupError(message: "\(error.localizedDescription) A mic backup is saved in \(backup.path).")
        }
        return "Signals installed and verified. Eject the mic, unplug USB-C, replace the cover, then squeeze to power it on."
    }

    @concurrent
    static func remove(from volume: URL, payload: URL) async throws -> String {
        try validate(volume)
        let manager = FileManager.default
        let contents = try payloadFiles(in: payload)
        let expected = try previousInstallation(in: volume, matching: contents) ?? contents
        let installed = try expected.reversed().filter { item in
            let target = volume.appendingPathComponent(item.name)
            guard manager.fileExists(atPath: target.path) else { return false }
            guard try Data(contentsOf: target) == item.data else {
                throw SetupError(message: "\(item.name) has been changed. EP Talk left it in place.")
            }
            return true
        }
        var removed: [SignalFile] = []
        do {
            for item in installed {
                try manager.removeItem(at: volume.appendingPathComponent(item.name))
                removed.append(item)
            }
        } catch {
            for item in removed.reversed() {
                try? item.data.write(to: volume.appendingPathComponent(item.name), options: .withoutOverwriting)
            }
            throw error
        }
        if let firstTone = expected.first(where: { $0.name.hasSuffix(".wav") }) {
            let folder = volume.appendingPathComponent(firstTone.name).deletingLastPathComponent()
            if (try? manager.contentsOfDirectory(atPath: folder.path).isEmpty) == true {
                try? manager.removeItem(at: folder)
            }
        }
        return "Signals removed. Eject and power-cycle the mic to return to its factory behavior."
    }

    private static func payloadFiles(in payload: URL) throws -> [SignalFile] {
        try files.map { file in
            (name: file, data: try Data(contentsOf: payload.appendingPathComponent(file)))
        }
    }

    /// Identify the payload shipped in the first EP Talk build. Read the sample
    /// path only from a byte-verified script, and verify the config and every
    /// present tone before treating anything as an installed signaling file.
    private static func previousInstallation(in volume: URL, matching current: [SignalFile]) throws -> [SignalFile]? {
        let startupURL = volume.appendingPathComponent("main.py")
        guard FileManager.default.fileExists(atPath: startupURL.path) else { return nil }
        let startup = try Data(contentsOf: startupURL)
        guard SHA256.hash(data: startup).description.hasSuffix(
            "fa65770c2fc98350fd8820483d3253a5d4dd75f9e85218d5980c25ef238dbaff"
        ), let script = String(data: startup, encoding: .utf8),
           let path = script.range(of: "/fat/"),
           let suffix = script[path.upperBound...].range(of: "/%d.wav") else { return nil }

        let folder = String(script[path.upperBound..<suffix.lowerBound])
        let configURL = volume.appendingPathComponent("config.json")
        var result: [SignalFile] = []
        for (index, name) in toneNames.enumerated() {
            let relativePath = "\(folder)/\(name)"
            let url = volume.appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let data = try Data(contentsOf: url)
            guard data == current[index].data else { return nil }
            result.append((relativePath, data))
        }
        if FileManager.default.fileExists(atPath: configURL.path) {
            let config = try Data(contentsOf: configURL)
            guard SHA256.hash(data: config).description.hasSuffix(
                "ed61b0056a6165d749a51d15f8dc161aef294b2698e1cb8504fa75bb58574a7d"
            ) else { return nil }
            result.append(("config.json", config))
        }
        result.append(("main.py", startup))
        return result
    }

    private static func validate(_ volume: URL) throws {
        let manager = FileManager.default
        let isMounted = manager.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [])?
            .contains { $0.standardizedFileURL.path == volume.standardizedFileURL.path } == true
        guard isMicVolume(volume), isMounted, manager.isWritableFile(atPath: volume.path) else {
            throw SetupError(message: "Choose the writable FX MIC DISK volume from Finder.")
        }
    }
}
