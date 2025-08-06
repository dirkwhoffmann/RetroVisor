// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import ScreenCaptureKit

protocol ScreenRecorderDelegate : SCStreamOutput {

    func textureRectDidChange(rect: CGRect?)
    func captureRectDidChange(rect: CGRect?)
    func recorderDidStart()
}

@MainActor
class ScreenRecorder: NSObject, SCStreamDelegate
{
    var stream: SCStream?
    var display: SCDisplay?
    var filter: SCContentFilter?
    var window: TrackingWindow?
    let videoQueue = DispatchQueue(label: "de.dirkwhoffmann.VideoQueue")

    // The recorder delegate
    var delegate: ScreenRecorderDelegate?

    // The source rectangle covered by the glass window
    var sourceRect: CGRect?

    // The source rectangle of the screen recorder
    var captureRect: CGRect?

    // The displayed texture cutout
    var textureRect: CGRect?

    // In responsive mode, the entire screen is recorded
    var responsive = true { didSet { if responsive != oldValue { relaunch() } } }

    // Indicates whether the current settings require a relaunch
    var needsRestart: Bool = false

    private var scaleFactor: Int { Int(NSScreen.main?.backingScaleFactor ?? 2) }
    private var fullRect: CGRect { CGRect(x: 0, y: 0, width: display?.width ?? 0, height: display?.height ?? 0) }

    func normalize(rect: CGRect) -> CGRect {

        guard let display = display else { return .zero }
        return CGRect(
            x: rect.minX / CGFloat(display.width),
            y: rect.minY / CGFloat(display.height),
            width: rect.width / CGFloat(display.width),
            height: rect.height / CGFloat(display.height)
        )
    }

    func updateRects()
    {
        guard let window = self.window else { return }
        guard let display = self.display else { return }

        var newSourceRect = window.screenCoordinates
        var newCaptureRect: CGRect?
        var newTextureRect: CGRect?


        let origin = window.screen!.frame.origin
        newSourceRect = CGRect(x: newSourceRect.origin.x - origin.x,
                               y: newSourceRect.origin.y + origin.y,
                               width: newSourceRect.width,
                               height: newSourceRect.height)

        if responsive {

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

        if (captureRect != newCaptureRect) {

            captureRect = newCaptureRect
            delegate?.captureRectDidChange(rect: newCaptureRect)
            needsRestart = true
        }
    }

    func launch() async
    {
        print("launch")

        do {

            // Get the display to capture
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )

            // Match the NSWindow's screen to a SCDisplay
            guard let screen = window?.screen,
                  let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                print("Could not find a display ID")
                return
            }
            // print("screen frame: \(screen.frame)")

            display = content.displays.first(where: { $0.displayID == displayID })
            if display == nil {
                print("Could not find a matching display")
                return
            }
            // print("display frame: \(display!.frame)")

            // Compute the capture coordinates
            updateRects()

            // Create a content filter with the main window excluded
            let excludedApps = content.applications.filter {
                app in Bundle.main.bundleIdentifier == app.bundleIdentifier
            }
            let mainWindow = content.windows.filter {
                win in window!.windowNumber == win.windowID
            }
            filter = SCContentFilter(display: display!,
                                     excludingApplications: mainWindow.isEmpty ? excludedApps : [],
                                     exceptingWindows: mainWindow)

            // Configure the stream
            let config = SCStreamConfiguration()

            // Configure audio capture
            config.capturesAudio = false

            // Configure video capture
            let rect = captureRect ?? display!.frame
            if (!responsive) { config.sourceRect = rect }
            config.showsCursor = false
            config.width = Int(rect.width) * scaleFactor
            config.height = Int(rect.height) * scaleFactor
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.colorSpaceName = CGColorSpace.sRGB
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.queueDepth = 5

            // Create the stream
            stream = SCStream(filter: filter!, configuration: config, delegate: self)

            // Register the stream receiver
            try stream!.addStreamOutput(delegate!, type: .screen, sampleHandlerQueue: videoQueue)

            try await stream!.startCapture()

            needsRestart = false

        } catch {
            print("Error: \(error)")
        }
    }

    func relaunch()
    {
        Task { await launch() }
    }

    func relaunchIfNeeded()
    {
        if (needsRestart) { relaunch() }
    }

}
