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
    @IBOutlet weak var capturePermissonText: NSTextField!

    var permissionTimer: Timer?

    override func viewDidLoad() {

        if let icon = NSApp.applicationIconImage {
            appIcon.image = icon
            }

        startPermissionPolling()
    }

    func startPermissionPolling() {

        Task {
            while true {

                let allowed = await ScreenRecorder.permissions
                if allowed {
                    DispatchQueue.main.async {

                        self.permissionIcon.image = NSImage(named: "statusOk")
                        self.capturePermissonText.stringValue = "Permission Granted"
                    }
                    // break
                } else {

                    self.permissionIcon.image = NSImage(named: "statusStop")
                    self.capturePermissonText.stringValue = "RetroVisor needs this permission because it captures and processes your screen in real time using Apple’s ScreenCaptureKit to apply visual effects. Without screen recording access, it cannot function."

                    print("So sad, no permissions")
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    @IBAction func openSystemPrefsAction(_ sender: NSButton) {

        print("open system prefs")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
    }
}
