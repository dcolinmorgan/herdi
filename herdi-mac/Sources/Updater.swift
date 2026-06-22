import Foundation
import AppKit
import Observation

@Observable
final class Updater {
    static let shared = Updater()

    let currentVersion = "0.2.0"
    let repo = "dcolinmorgan/herdi"

    var latestVersion: String?
    var updateAvailable = false
    var isChecking = false
    var isUpdating = false
    var status: String?

    private var downloadURL: URL?

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        status = "Checking…"

        Task {
            defer { DispatchQueue.main.async { self.isChecking = false } }
            guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                DispatchQueue.main.async { self.status = "Check failed" }
                return
            }

            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag

            // Find DMG asset
            let assets = json["assets"] as? [[String: Any]] ?? []
            let dmgAsset = assets.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
            let dmgURL = dmgAsset?["browser_download_url"] as? String

            DispatchQueue.main.async {
                self.latestVersion = version
                self.downloadURL = dmgURL.flatMap { URL(string: $0) }
                self.updateAvailable = version != self.currentVersion && self.downloadURL != nil
                self.status = self.updateAvailable ? "v\(version) available" : "Up to date"
            }
        }
    }

    func performUpdate() {
        guard let url = downloadURL, !isUpdating else { return }
        isUpdating = true
        status = "Downloading…"

        Task {
            do {
                // Download DMG
                let (fileURL, _) = try await URLSession.shared.download(from: url)
                let dmgPath = FileManager.default.temporaryDirectory.appendingPathComponent("HerdiMac-update.dmg")
                try? FileManager.default.removeItem(at: dmgPath)
                try FileManager.default.moveItem(at: fileURL, to: dmgPath)

                DispatchQueue.main.async { self.status = "Installing…" }

                // Mount DMG, copy app, relaunch
                let mountPoint = "/Volumes/Herdi"
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                process.arguments = ["attach", dmgPath.path, "-nobrowse", "-quiet"]
                try process.run()
                process.waitUntilExit()

                let appSource = "\(mountPoint)/HerdiMac.app"
                guard let appBundle = Bundle.main.bundlePath as String?,
                      FileManager.default.fileExists(atPath: appSource) else {
                    DispatchQueue.main.async {
                        self.status = "Install failed"
                        self.isUpdating = false
                    }
                    return
                }

                // Replace app
                let appDest = appBundle
                let backup = appDest + ".bak"
                try? FileManager.default.removeItem(atPath: backup)
                try FileManager.default.moveItem(atPath: appDest, toPath: backup)
                try FileManager.default.copyItem(atPath: appSource, toPath: appDest)

                // Unmount
                let unmount = Process()
                unmount.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                unmount.arguments = ["detach", mountPoint, "-quiet"]
                try? unmount.run()
                unmount.waitUntilExit()

                // Clean up backup
                try? FileManager.default.removeItem(atPath: backup)

                DispatchQueue.main.async { self.status = "Relaunching…" }

                // Relaunch
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                task.arguments = ["-n", appDest]
                try task.run()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = "Update failed: \(error.localizedDescription)"
                    self.isUpdating = false
                }
            }
        }
    }
}
