// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class PermissionViewController: NSViewController  {

    @IBOutlet weak var appIcon: NSImageView!
    @IBOutlet weak var permissionIcon: NSImageView!
    @IBOutlet weak var titleText: NSTextField!
    @IBOutlet weak var captureText: NSTextField!
    @IBOutlet weak var buttonText: NSTextField!
    @IBOutlet weak var actionButton: NSButton!

    var permissionTimer: Timer?
    var canLaunch: Bool = false

    override func viewDidLoad() {

        captureText.stringValue = "🛑 Screen Capture Permissions"
        // startPermissionPolling()
    }

    func startPermissionPolling() {

        Task {
            while true {

                canLaunch = await ScreenRecorder.permissions

                if canLaunch {

                    DispatchQueue.main.async {

                        self.appIcon.image = NSImage(named: "statusOk")
                        self.titleText.stringValue = "RetroVisor is ready to run."
                        self.captureText.stringValue = "✅ Screen Capture Permissions"
                        self.buttonText.isHidden = true
                        self.actionButton.title = "Relaunch RetroVisor"
                    }

                } else {

                    self.appIcon.image = NSImage(named: "statusStop")
                    self.titleText.stringValue = "RetroVisor requires additional permissions to run."
                    self.captureText.stringValue = "🛑 Screen Capture Permissions"
                    self.buttonText.isHidden = false
                    self.actionButton.title = "Open System Preferences"

                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    @IBAction func openSystemPrefsAction(_ sender: NSButton) {

        if canLaunch {

            Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-b", Bundle.main.bundleIdentifier!])
              NSApp.terminate(self)
            NSApplication.shared.terminate(nil)

        } else {

            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
