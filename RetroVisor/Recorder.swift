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
class Recorder {

    var app: AppDelegate { NSApp.delegate as! AppDelegate }

    // Recorder settings
    var settings = RecorderSettings.Preset.systemDefault.settings

    // The current recording state
    var isRecording: Bool { startTime != nil }

    // AVWriter
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    private(set) var recordingRect: NSRect?
    var currentTime: CMTime?

    // Event receiver
    var delegate: RecorderDelegate?

    func startRecording(width: Int, height: Int) {

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let file = docs.appendingPathComponent("output.mov")

        startRecording(to: file, width: width, height: height)
    }

    func startRecording(to url: URL, width: Int, height: Int) {

        if isRecording { return }

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
            print("Can't start recording: \(error)")
            return
        }

        // Create settings
        var videoSettings = settings.makeVideoSettings()
        let audioSettings = settings.makeAudioSettings()

        // Add resolution parameters if not yet set
        if videoSettings[AVVideoWidthKey] == nil { videoSettings[AVVideoWidthKey] = width }
        if videoSettings[AVVideoHeightKey] == nil { videoSettings[AVVideoHeightKey] = height }

        print("VideoSettings:")
        print("\(videoSettings)")

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput!.expectsMediaDataInRealTime = true

        guard assetWriter!.canAdd(videoInput!) else {
            fatalError("Can't add input to asset writer")
        }
        assetWriter!.add(videoInput!)

        if let audioSettings = audioSettings {
            print("AudioSettings:")
            print("\(audioSettings)")
        }

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput!.expectsMediaDataInRealTime = true

        if assetWriter!.canAdd(audioInput!) {
            assetWriter!.add(audioInput!)
        } else {
            print("Cannot add audio input")
        }

        print("Creating pixel buffer adaptor")
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
        )

        startTime = CMTime()

        print("Informing the delegate")
        delegate?.recorderDidStart()
    }

    func stopRecording(completion: @escaping () -> Void) {

        print("stopRecording")

        if !isRecording { return }

        videoInput?.markAsFinished()
        assetWriter?.finishWriting {
            print("Recording finished")
            completion()
        }

        recordingRect = nil
        startTime = nil

        delegate?.recorderDidStop()
    }

    // Appends a video frame
    func appendVideo(texture: MTLTexture) {

        let status = assetWriter?.status

        app.windowController?.effectWindow?.updateOverlay(recording: status == .writing)

        if !isRecording { return }
        guard let timestamp = currentTime else { return }
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
