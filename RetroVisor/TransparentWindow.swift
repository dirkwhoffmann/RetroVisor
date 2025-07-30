// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa
import ScreenCaptureKit

class TransparentWindow: NSWindow, SCStreamDelegate {

    weak var previousKeyWindow: NSWindow?
    weak var myview: Preview?

    var frozen = false
    var rect: CGRect?

    @Published private(set) var availableDisplays = [SCDisplay]()
    @Published private(set) var availableWindows = [SCWindow]()
    var stream: SCStream?
    var selectedDisplay: SCDisplay?
    var filter: SCContentFilter?
    private let videoSampleBufferQueue = DispatchQueue(label: "de.dirkwhoffmann.VideoSampleBufferQueue")

    func freeze() {

        frozen = true
        ignoresMouseEvents = true
        styleMask = [.nonactivatingPanel, .fullSizeContentView]
        backgroundColor = NSColor.gray.withAlphaComponent(0.2)
        contentView?.layer?.borderColor = NSColor.systemGray.cgColor
        contentView?.layer?.borderWidth = 1
        contentView?.layer?.cornerRadius = 10
    }

    func unfreeze() {

        frozen = false
        ignoresMouseEvents = false
        styleMask = [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel, .fullSizeContentView]
        backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2)
        contentView?.layer?.borderColor = NSColor.systemBlue.cgColor
        contentView?.layer?.borderWidth = 2
        contentView?.layer?.cornerRadius = 10
    }

    override func mouseDown(with event: NSEvent) {

        if event.clickCount == 2 {

            // Double click
            freeze()

        } else {

            // Single click
            self.performDrag(with: event)
        }
    }

    func setup() async {

        await fetchAvailableSources()
    }

    func fetchAvailableSources() async {
        do {
            // Retrieve the available screen content to capture.
            let content =
            try await SCShareableContent.excludingDesktopWindows(false,
                                                                 onScreenWindowsOnly: true)
            availableDisplays = content.displays

            /*
            let windows = filterWindows(availableContent.windows)
            if windows != availableWindows {
                availableWindows = windows
            }
            availableApps = availableContent.applications
            */
            selectedDisplay = availableDisplays.first

            if (selectedDisplay == nil) {
                fatalError("Failed to select display")
            }
            printDisplayInfo(selectedDisplay!)
            let excludedApps = content.applications.filter { app in
                Bundle.main.bundleIdentifier == app.bundleIdentifier
            }

            // Create a content filter with excluded apps.
            filter = SCContentFilter(display: selectedDisplay!,
                                     excludingApplications: excludedApps,
                                     exceptingWindows: [])

            print("Filter = \(filter!)")
            stream = SCStream(filter: filter!, configuration: streamConfiguration, delegate: self)

            print("Capture the data...")
            try stream!.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)

            print("Starting stream capture...")
            try await stream!.startCapture()


            print("I am here")

        } catch {
            print("Failed to get the shareable content: \(error.localizedDescription)")
        }
    }

    private var streamConfiguration: SCStreamConfiguration {

        let streamConfig = SCStreamConfiguration()

        // Configure audio capture.
        streamConfig.capturesAudio = false
        // streamConfig.excludesCurrentProcessAudio = isAppAudioExcluded

        // Configure the display content width and height.
        let scaleFactor = 1
        streamConfig.width = selectedDisplay!.width * scaleFactor
        streamConfig.height = selectedDisplay!.height * scaleFactor

        // Set the capture interval at 60 fps.
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        // Increase the depth of the frame queue to ensure high fps
        streamConfig.queueDepth = 5

        print("Stream resolution: \(streamConfig.width)x\(streamConfig.height)")
        return streamConfig
    }

    /*
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        print("stream callback")
    }
    */
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("didStopWithError: \(error.localizedDescription)")
        fatalError()
    }

    func printDisplayInfo(_ display: SCDisplay) {
        print("Display ID: \(display.displayID)")
        print("Resolution: \(display.width)x\(display.height)")
    }

    func updateRect()
    {
        rect = viewRectInScreenPixels(view: myview!, display: selectedDisplay!) ?? .zero
    }

    func viewRectInScreenPixels(view: NSView, display: SCDisplay) -> CGRect? {

        // View frame relative to window
        let viewFrame = view.convert(view.bounds, to: nil)

        // Window frame relative to screen (points)
        let windowFrame = frame

        // View frame in screen points
        let screenRectPoints = CGRect(
            x: windowFrame.origin.x + viewFrame.origin.x,
            y: windowFrame.origin.y + viewFrame.origin.y,
            width: viewFrame.width,
            height: viewFrame.height)

        // Convert screen points to pixels (multiply by display.scale)
        let scale = CGFloat(1.0) // display.scale
        let screenRectPixels = CGRect(
            x: screenRectPoints.origin.x * scale,
            y: screenRectPoints.origin.y * scale,
            width: screenRectPoints.width * scale,
            height: screenRectPoints.height * scale)

        return screenRectPixels
    }
}

extension TransparentWindow: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // print("🎥 Frame received at: \(Date())")
        myview!.updateImage(from: sampleBuffer, cropRectPixels: rect)
    }
}
