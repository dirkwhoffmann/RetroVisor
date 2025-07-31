// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import ScreenCaptureKit

@MainActor
class ScreenRecorder: NSObject, SCStreamDelegate
{
    var stream: SCStream?
    var display: SCDisplay?
    var filter: SCContentFilter?
    var window: NSWindow?
    
    private let videoQueue = DispatchQueue(label: "de.dirkwhoffmann.VideoQueue")

    func windowInScreenCoords() -> CGRect {

        let windowFrame = window!.frame
        let screenFrame = window!.screen?.frame ?? .zero

        // macOS hat Ursprung links unten in globalen Koordinaten (Y = 0 unten)
        return CGRect(
            x: windowFrame.origin.x,
            y: screenFrame.height - windowFrame.origin.y - windowFrame.height,
            width: windowFrame.width,
            height: windowFrame.height
        )
    }

    private var streamConfiguration: SCStreamConfiguration {

        let config = SCStreamConfiguration()

        // Configure audio capture
        config.capturesAudio = false

        // Configure video capture
        let rect = windowInScreenCoords()
        config.sourceRect = rect
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        // config.width = display!.width
        // config.height = display!.height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        // config.sourceRect = windowInScreenCoords()

        // Set the capture interval at 60 fps
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        // Increase the depth of the frame queue to ensure high fps
        config.queueDepth = 5

        return config
    }

    func setup(receiver: SCStreamOutput) async
    {
        print("setup")

        do {

            // Get the display to capture
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            display = content.displays.first

            if (display == nil) {
                fatalError("Failed to select display")
            }

            // Create a content filter with the current app excluded
            let excludedApps = content.applications.filter {
                app in Bundle.main.bundleIdentifier == app.bundleIdentifier
            }
            filter = SCContentFilter(display: display!,
                                     excludingApplications: excludedApps,
                                     exceptingWindows: [])

            // Setup the stream
            stream = SCStream(filter: filter!, configuration: streamConfiguration, delegate: self)

            // Prepare to receive streamed data
            try stream!.addStreamOutput(receiver, type: .screen, sampleHandlerQueue: videoQueue)

            print("Starting stream capture...")
            try await stream!.startCapture()

        } catch {
            print("Error: \(error)")
            return
        }
    }

    func restart(receiver: SCStreamOutput) async
    {
        print("restart")

        do {

            // Stop current stream
            try await stream?.stopCapture()

            // Get the display to capture
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            display = content.displays.first

            if (display == nil) {
                fatalError("Failed to select display")
            }

            // Create a content filter with the current app excluded
            let excludedApps = content.applications.filter {
                app in Bundle.main.bundleIdentifier == app.bundleIdentifier
            }
            filter = SCContentFilter(display: display!,
                                     excludingApplications: excludedApps,
                                     exceptingWindows: [])

            // Setup the stream with new config
            stream = SCStream(filter: filter!, configuration: streamConfiguration, delegate: self)

            // Prepare to receive streamed data
            try stream!.addStreamOutput(receiver, type: .screen, sampleHandlerQueue: videoQueue)

            print("Restarting stream capture...")
            try await stream!.startCapture()

        } catch {
            print("Error: \(error)")
            return
        }
    }

    func viewRectInScreenPixels(view: NSView) -> CGRect? {

        // View frame relative to window
        let viewFrame = view.convert(view.bounds, to: nil)

        // Window frame relative to screen (points)
        let windowFrame = view.window!.frame

        // View frame in screen points
        let screenRectPoints = CGRect(
            x: windowFrame.origin.x + viewFrame.origin.x,
            y: windowFrame.origin.y + viewFrame.origin.y,
            width: viewFrame.width,
            height: viewFrame.height)

        // Convert screen points to pixels (multiply by display.scale)
        let scalex = CGFloat(1.0) / CGFloat(display?.width ?? 1)
        let scaley = CGFloat(1.0) / CGFloat(display?.height ?? 1)

        let screenRectPixels = CGRect(
            x: screenRectPoints.origin.x * scalex,
            y: screenRectPoints.origin.y * scaley,
            width: screenRectPoints.width * scalex,
            height: screenRectPoints.height * scaley)

        return screenRectPixels
    }


}
