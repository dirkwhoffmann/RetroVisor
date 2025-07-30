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

    private let videoQueue = DispatchQueue(label: "de.dirkwhoffmann.VideoQueue")

    private var streamConfiguration: SCStreamConfiguration {

        let streamConfig = SCStreamConfiguration()

        // Configure audio capture
        streamConfig.capturesAudio = false

        // Configure video capture
        streamConfig.width = display!.width
        streamConfig.height = display!.height

        // Set the capture interval at 60 fps
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        // Increase the depth of the frame queue to ensure high fps
        streamConfig.queueDepth = 5

        return streamConfig
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
}
