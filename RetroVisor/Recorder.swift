// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import ScreenCaptureKit

@MainActor
class Recorder {

    var app: AppDelegate { NSApp.delegate as! AppDelegate }

    // AVWriter
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    var currentTime: CMTime?
    var recordingRect: NSRect? {
        didSet { app.updateStatusBarMenuIcon(recording: isRecording) }
    }

    var isRecording: Bool { recordingRect != nil }

    func startIfNeeded(firstTimestamp: CMTime) {

        if startTime == nil {

            startTime = firstTimestamp
            assetWriter!.startWriting()
            assetWriter!.startSession(atSourceTime: firstTimestamp)
        }
    }

    func startRecording(width: Int, height: Int) {

        if isRecording { return }
        recordingRect = NSRect(x: 0, y: 0, width: width, height: height)

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

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6000000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoPixelAspectRatioKey: [
                        AVVideoPixelAspectRatioHorizontalSpacingKey: 1,
                        AVVideoPixelAspectRatioVerticalSpacingKey: 1
                    ]
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput!.expectsMediaDataInRealTime = true

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
        )

        guard assetWriter!.canAdd(videoInput!) else {
            fatalError("Can't add input to asset writer")
        }
        assetWriter!.add(videoInput!)

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ]

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput!.expectsMediaDataInRealTime = true

        if assetWriter!.canAdd(audioInput!) {
            assetWriter!.add(audioInput!)
        } else {
            print("Cannot add audio input")
        }
    }

    func stopRecording(completion: @escaping () -> Void) {

        videoInput?.markAsFinished()
        assetWriter?.finishWriting {
            print("Recording finished")
            completion()
        }

        recordingRect = nil
    }

    // Appends a video frame
    func appendVideo(texture: MTLTexture) {

        if !isRecording { return }
        guard let time = currentTime else { return }

        let texW = CGFloat(texture.width)
        let texH = CGFloat(texture.height)

        // Stop recording, if the texture size did change
        if recordingRect!.width != texW || recordingRect!.height != texH {
            stopRecording { }
        }

        // print("Recording frame")
        startIfNeeded(firstTimestamp: time)

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

        pixelBufferAdaptor!.append(pixelBuffer, withPresentationTime: time)
    }

    func appendAudio(buffer: CMSampleBuffer) {

        if !isRecording { return }
        // guard let time = currentTime else { return }
        if audioInput?.isReadyForMoreMediaData == true {
            audioInput!.append(buffer)
        }
    }
}
