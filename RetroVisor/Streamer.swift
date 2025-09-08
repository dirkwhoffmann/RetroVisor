// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import ScreenCaptureKit

/* This class uses ScreenCaptureKit to record screen content and feed it into
 * the post-processor.
 */
@MainActor
protocol StreamerDelegate: AnyObject, SCStreamOutput {

    func textureRectDidChange(rect: CGRect?)
    func captureRectDidChange(rect: CGRect?)
    func streamDidStop(error: Error?)
}

@MainActor
class Streamer: NSObject, Loggable, SCStreamDelegate {

    // Recorder settings
    var settings = StreamerSettings.Preset.systemDefault.settings

    // Enables debug output to the console
    let logging: Bool = false

    // ScreenCaptureKit
    var stream: SCStream?
    var display: SCDisplay?
    var filter: SCContentFilter?
    var window: TrackingWindow?
    let videoQueue = DispatchQueue(label: "de.dirkwhoffmann.VideoQueue")
    let audioQueue = DispatchQueue(label: "de.dirkwhoffmann.AudioQueue")

    // Event receiver
    var delegate: StreamerDelegate?

    // The source rectangle covered by the effect window
    var sourceRect: CGRect?

    // The source rectangle of the screen streamer
    var captureRect: CGRect?

    // The displayed texture cutout
    var textureRect: CGRect?

    // Indicates whether the current settings require a relaunch
    private var needsRestart: Bool = false

    func normalize(rect: CGRect) -> CGRect {

        guard let display = display else { return .zero }
        return CGRect(
            x: rect.minX / CGFloat(display.width),
            y: rect.minY / CGFloat(display.height),
            width: rect.width / CGFloat(display.width),
            height: rect.height / CGFloat(display.height)
        )
    }

    func updateRects() {

        guard let window = self.window else { return }

        var newSourceRect = window.screenCoordinates
        var newCaptureRect: CGRect?
        var newTextureRect: CGRect?

        let origin = window.screen!.frame.origin
        newSourceRect = CGRect(x: newSourceRect.origin.x - origin.x,
                               y: newSourceRect.origin.y + origin.y,
                               width: newSourceRect.width,
                               height: newSourceRect.height)

        if settings.captureMode == .entire {

            // Grab the entire screen and draw a portion of the texture
            newCaptureRect = nil
            newTextureRect = normalize(rect: newSourceRect)

        } else {

            // Grab a portion of the screen and draw the entire texture
            newCaptureRect = newSourceRect
            newTextureRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        sourceRect = newSourceRect

        if textureRect != newTextureRect {

            textureRect = newTextureRect
            delegate?.textureRectDidChange(rect: newTextureRect)
        }

        if captureRect != newCaptureRect {

            captureRect = newCaptureRect
            delegate?.captureRectDidChange(rect: newCaptureRect)
            needsRestart = true
        }
    }

    static var canRecord: Bool {
        get async {
            do {
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return true
            } catch {
                return false
            }
        }
    }

    func launch() async {

        log("Launching streamer...")

        do {

            // Get the display to capture
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )

            // Match the NSWindow's screen to a SCDisplay
            guard let screen = window?.screen,
                  let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                log("Could not acquire the display ID", .warning)
                return
            }

            // Get the SCDisplay with a matching display ID
            display = content.displays.first(where: { $0.displayID == displayID })
            if display == nil {
                log("Could not find a matching display ID", .warning)
                return
            }

            // Compute the capture coordinates
            updateRects()

            // Create a content filter with the main window excluded
            let excludedApps = content.applications.filter { app in
                Bundle.main.bundleIdentifier == app.bundleIdentifier
            }
            let mainWindow = content.windows.filter { win in
                window!.windowNumber == win.windowID
            }
            filter = SCContentFilter(display: display!,
                                     excludingApplications: mainWindow.isEmpty ? excludedApps : [],
                                     exceptingWindows: mainWindow)

            // Configure the stream
            let config = SCStreamConfiguration()

            // Configure audio capture
            config.capturesAudio = true

            // Configure video capture
            let rect = captureRect ?? display!.frame
            if settings.captureMode == .cutout { config.sourceRect = rect }
            config.showsCursor = false
            config.width = Int(rect.width) * NSScreen.scaleFactor
            config.height = Int(rect.height) * NSScreen.scaleFactor
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.colorSpaceName = CGColorSpace.sRGB
            config.queueDepth = settings.queueDepth
            if let interval = settings.frameInterval { config.minimumFrameInterval = interval }

            // Create the stream
            stream = SCStream(filter: filter!, configuration: config, delegate: self)

            // Register the stream receiver
            try stream!.addStreamOutput(delegate!, type: .screen, sampleHandlerQueue: videoQueue)
            try stream!.addStreamOutput(delegate!, type: .audio, sampleHandlerQueue: audioQueue)

            try await stream!.startCapture()

            needsRestart = false

            log("Lauch completed")

        } catch {
            log("\(error)", .error)
        }
    }

    func relaunch() {

        Task { await launch() }
    }

    func relaunchIfNeeded() {

        if needsRestart { relaunch() }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {

        Task { @MainActor in delegate?.streamDidStop(error: error) }
    }
}
