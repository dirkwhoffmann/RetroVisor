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

extension TrackingWindowDelegate {

    func textureRectDidChange(rect: CGRect?) {}
    func captureRectDidChange(rect: CGRect?) {}
    func recorderDidStart() {}
}

/* This class uses ScreenCaptureKit to record screen content and feed it into the post-processor.
 *
 * The recorder operates in two modes, controlled by the `responsive` flag:
 *
 *   responsive = true:
 *
 *   In this mode, the recorder captures the entire screen but renders only a portion
 *   of the texture. This approach is more resource-intensive but allows for smooth,
 *   real-time updates during window drag and resize operations. Recommended for modern systems.
 *
 *   responsive = false:
 *
 *   The recorder captures only a portion of the screen and always renders the full texture.
 *   This mode is more efficient, as ScreenCaptureKit streams only the required area.
 *   However, moving or resizing the effect window requires restarting the stream,
 *   resulting in less fluid animations compared to responsive mode.
 */

@MainActor
class ScreenRecorder: NSObject, SCStreamDelegate
{
    // Capture mode
    var responsive = true { didSet { if responsive != oldValue { relaunch() } } }

    // ScreenCaptureKit entities
    var stream: SCStream?
    var display: SCDisplay?
    var filter: SCContentFilter?
    var window: TrackingWindow?
    let videoQueue = DispatchQueue(label: "de.dirkwhoffmann.VideoQueue")

    // AVWriter
    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    var currentTime: CMTime?
    var isRecording: Bool = false

    // The recorder delegate
    var delegate: ScreenRecorderDelegate?

    // The source rectangle covered by the effect window
    var sourceRect: CGRect?

    // The source rectangle of the screen recorder
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

    func updateRects()
    {
        guard let window = self.window else { return }

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
        print("Launching the screen recorder...")

        do {

            // Get the display to capture
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )

            // Match the NSWindow's screen to a SCDisplay
            guard let screen = window?.screen,
                  let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                print("Could not acquire the display ID")
                return
            }

            // Get the SCDisplay with a matching display ID
            display = content.displays.first(where: { $0.displayID == displayID })
            if display == nil {
                print("Could not find a matching display ID")
                return
            }

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
            config.width = Int(rect.width) * NSScreen.scaleFactor
            config.height = Int(rect.height) * NSScreen.scaleFactor
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.colorSpaceName = CGColorSpace.sRGB
            config.minimumFrameInterval = CMTime(value: 1, timescale: 50)
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

    var frame = 0

    func record(buffer: CVPixelBuffer) {


    }

    func startIfNeeded(firstTimestamp: CMTime) {

        if startTime == nil {

            startTime = firstTimestamp
            assetWriter!.startWriting()
            assetWriter!.startSession(atSourceTime: firstTimestamp)
        }
    }

    func startRecording(width: Int, height: Int) {

        if isRecording { return }

        let fileManager = FileManager.default

        // Setup AVAssetWriter
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("output.mov")
        print("Recording to \(url)")
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }

        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            print("Can't start recording: \(error)")
            return
        }

        print("assetWriter = \(assetWriter.debugDescription)")
        print("Recording size = \(width) x \(height)")

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6000000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput!.expectsMediaDataInRealTime = true

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput!,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ])

        guard assetWriter!.canAdd(writerInput!) else {
            fatalError("Can't add input to asset writer")
        }
        assetWriter!.add(writerInput!)

        // Start writing session
        /*
         guard assetWriter!.startWriting() else {
         if let error = assetWriter!.error {
         throw error
         }
         fatalError("Can't write")
         }
         */
        isRecording = true
    }

    func stopRecording(completion: @escaping () -> Void) {

        writerInput?.markAsFinished()
        assetWriter?.finishWriting {
            print("Recording finished")
            completion()
        }
        isRecording = false
    }

    // Appends a video frame
    func appendVideo(texture: MTLTexture) {

        if !isRecording { return }

        guard let time = currentTime else { return }

        print("Recording frame")
        startIfNeeded(firstTimestamp: time)

        guard writerInput!.isReadyForMoreMediaData else { return }

        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferAdaptor!.pixelBufferPool!, &pb)
        guard let pixelBuffer = pb else { return }

        // Copy Metal texture into CVPixelBuffer
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        texture.getBytes(CVPixelBufferGetBaseAddress(pixelBuffer)!,
                         bytesPerRow: bytesPerRow,
                         from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                         mipmapLevel: 0)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        pixelBufferAdaptor!.append(pixelBuffer, withPresentationTime: time)
    }
}
