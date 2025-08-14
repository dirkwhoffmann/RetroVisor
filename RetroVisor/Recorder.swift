// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import AVFoundation
import ScreenCaptureKit

protocol RecorderDelegate {

    func recorderDidStart()
    func recorderDidStop()
}

@MainActor
class Recorder: Loggable {

    var app: AppDelegate { NSApp.delegate as! AppDelegate }

    // Event receiver
    var delegate: RecorderDelegate?

    // Enables debug output to the console
    let logging: Bool = false

    // Recorder settings
    var settings = RecorderSettings.Preset.systemDefault.settings

    // The current recording state
    var isRecording: Bool { countdown == 0 }

    // Time when the recorder started
    // private var startTime: CMTime?

    // The recorded screen cutout
    private(set) var recordingRect: NSRect?

    // Time stamp of the currently recorded frame
    var timestamp: CMTime?

    // Frame counter to skip initial frames after recording starts
    var countdown: Int?

    // AVWriter
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    func startRecording(width: Int, height: Int) {

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let file = docs.appendingPathComponent("output.mov")

        startRecording(to: file, width: width, height: height)
    }

    func startRecording(to url: URL, width: Int, height: Int) {

        if isRecording { return }

        log("Starting the recorder...")

        recordingRect = NSRect(x: 0, y: 0, width: width, height: height)

        let fileManager = FileManager.default

        // Remove the file if it already exists
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }

        do {
            assetWriter = try AVAssetWriter(outputURL: url,
                                            fileType: settings.videoType.avFileType)
        } catch {
            log("Can't start recording: \(error)", .error)
            return
        }

        // Create settings
        var videoSettings = settings.makeVideoSettings()
        var audioSettings = settings.makeAudioSettings()

        // Add required parameters if not yet provided
        if videoSettings?[AVVideoWidthKey] == nil { videoSettings?[AVVideoWidthKey] = width }
        if audioSettings?[AVVideoHeightKey] == nil { videoSettings?[AVVideoHeightKey] = height }
        if audioSettings?[AVSampleRateKey] == nil { audioSettings?[AVSampleRateKey] = 44100 }

        log("Video settings:\n\(videoSettings?.prettify ?? "nil")")
        log("Audio settings:\n\(audioSettings?.prettify ?? "nil")")

        // Setup video input
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput!.expectsMediaDataInRealTime = true
        guard assetWriter!.canAdd(videoInput!) else {
            fatalError("Can't add video input to asset writer")
        }
        assetWriter!.add(videoInput!)

        // Setup audio input
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput!.expectsMediaDataInRealTime = true
        guard assetWriter!.canAdd(audioInput!) else {
            fatalError("Can't add audio input to asset writer")
        }
        assetWriter!.add(audioInput!)

        // Create pixel buffer adaptor
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
        )

        countdown = 8
        delegate?.recorderDidStart()
    }

    func stopRecording(completion: @escaping () -> Void) {

        if !isRecording { return }

        log("Stopping the recorder...")

        videoInput?.markAsFinished()
        assetWriter?.finishWriting { completion() }

        recordingRect = nil
        countdown = nil

        delegate?.recorderDidStop()
    }

    // Appends a video frame
    func appendVideo(texture: MTLTexture) {

        let status = assetWriter?.status
        app.windowController?.effectWindow?.onAir = status == .writing

        if (countdown ?? 0) > 0 { countdown! -= 1 }
        if !isRecording { return }

        guard let timestamp = timestamp else { return }
        guard let assetWriter = assetWriter else { return }

        let texW = CGFloat(texture.width)
        let texH = CGFloat(texture.height)

        // Stop recording if the texture size did change
        if recordingRect!.width != texW || recordingRect!.height != texH {
            stopRecording { }
        }

        // Start the writer if this is the first frame
        if status != .writing {
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: timestamp)
        }

        guard videoInput!.isReadyForMoreMediaData else { return }

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

        pixelBufferAdaptor!.append(pixelBuffer, withPresentationTime: timestamp)
    }

    func appendAudio(buffer: CMSampleBuffer) {

        if !isRecording { return }
        // guard let time = currentTime else { return }
        if audioInput?.isReadyForMoreMediaData == true {
            audioInput!.append(buffer)
        }
    }
}
