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
import UniformTypeIdentifiers

protocol RecorderDelegate {

    func recorderDidStart()
    func recorderDidStop()
}

struct RecorderSettings {

    enum VideoType: Int {

        case mov = 0
        case mp4 = 1

        var avFileType: AVFileType {
            switch self {
            case .mov: return .mov
            case .mp4: return .mp4
            }
        }

        var utType: UTType {
            switch self {
            case .mov: return .quickTimeMovie
            case .mp4: return .mpeg4Movie
            }
        }

        var fileExtension: String {
            switch self {
            case .mov: return "mov"
            case .mp4: return "mp4"
            }
        }
    }

    enum VideoCodec: Int {

        case h264 = 0
        case hevc = 1
        case proRes422 = 2
        case proRes4444 = 3

        var avCodec: AVVideoCodecType {
            switch self {
            case .h264:       return .h264
            case .hevc:       return .hevc
            case .proRes422:  return .proRes422
            case .proRes4444: return .proRes4444
            }
        }
    }

    var videoType: VideoType
    var codec: VideoCodec
    var width: Int
    var height: Int
    var quality: CGFloat  // 0.0 = lowest, 1.0 = highest
    var pixelAspectRatioH: Int
    var pixelAspectRatioV: Int
    var frameRate: Int
    var bitRate: Int? // nil = default for codec

    var includeAudio: Bool
    var audioFormatID: AudioFormatID
    var audioChannels: Int
    var audioSampleRate: Double
    var audioBitRate: Int

    enum Preset {

        case youtube1080p
        case youtube4k
        case proResHQ
        case smallFile

        var settings: RecorderSettings {

            switch self {
            case .youtube1080p:
                return RecorderSettings(
                    videoType: .mp4,
                    codec: .h264,
                    width: 1920,
                    height: 1080,
                    quality: 0.9,
                    pixelAspectRatioH: 1,
                    pixelAspectRatioV: 1,
                    frameRate: 60,
                    bitRate: 8_000_000,
                    includeAudio: true,
                    audioFormatID: kAudioFormatMPEG4AAC,
                    audioChannels: 2,
                    audioSampleRate: 44100,
                    audioBitRate: 192_000
                )
            case .youtube4k:
                return RecorderSettings(
                    videoType: .mp4,
                    codec: .h264,
                    width: 3840,
                    height: 2160,
                    quality: 0.95,
                    pixelAspectRatioH: 1,
                    pixelAspectRatioV: 1,
                    frameRate: 60,
                    bitRate: 35_000_000,
                    includeAudio: true,
                    audioFormatID: kAudioFormatMPEG4AAC,
                    audioChannels: 2,
                    audioSampleRate: 48000,
                    audioBitRate: 256_000
                )
            case .proResHQ:
                return RecorderSettings(
                    videoType: .mov,
                    codec: .proRes422,
                    width: 1920,
                    height: 1080,
                    quality: 1.0,
                    pixelAspectRatioH: 1,
                    pixelAspectRatioV: 1,
                    frameRate: 60,
                    bitRate: nil,
                    includeAudio: true,
                    audioFormatID: kAudioFormatLinearPCM,
                    audioChannels: 2,
                    audioSampleRate: 48000,
                    audioBitRate: 0
                )
            case .smallFile:
                return RecorderSettings(
                    videoType: .mp4,
                    codec: .h264,
                    width: 1280,
                    height: 720,
                    quality: 0.7,
                    pixelAspectRatioH: 1,
                    pixelAspectRatioV: 1,
                    frameRate: 30,
                    bitRate: 2_000_000,
                    includeAudio: true,
                    audioFormatID: kAudioFormatMPEG4AAC,
                    audioChannels: 2,
                    audioSampleRate: 44100,
                    audioBitRate: 128_000
                )
            }
        }
    }

    func makeVideoSettings() -> [String: Any] {

        var settings: [String: Any] = [
            AVVideoCodecKey: codec.avCodec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoQualityKey: quality
            ],
            AVVideoPixelAspectRatioKey: [
                AVVideoPixelAspectRatioHorizontalSpacingKey: pixelAspectRatioH,
                AVVideoPixelAspectRatioVerticalSpacingKey: pixelAspectRatioV
            ]
        ]

        if let bitRate = bitRate {
            var compressionProps = settings[AVVideoCompressionPropertiesKey] as! [String: Any]
            compressionProps[AVVideoAverageBitRateKey] = bitRate
            settings[AVVideoCompressionPropertiesKey] = compressionProps
        }

        return settings
    }

    func makeAudioSettings() -> [String: Any]? {
        guard includeAudio else { return nil }

        return [
            AVFormatIDKey: audioFormatID,
            AVNumberOfChannelsKey: audioChannels,
            AVSampleRateKey: audioSampleRate,
            AVEncoderBitRateKey: audioBitRate
        ]
    }
}

@MainActor
class Recorder {

    var app: AppDelegate { NSApp.delegate as! AppDelegate }

    // Recorder settings
    var settings = RecorderSettings.Preset.youtube1080p.settings

    // AVWriter
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    private(set) var recordingRect: NSRect?
    var currentTime: CMTime?

    var isRecording: Bool { recordingRect != nil }

    // Event receiver
    var delegate: RecorderDelegate?

    func startIfNeeded(firstTimestamp: CMTime) {

        if startTime == nil {

            startTime = firstTimestamp
            assetWriter!.startWriting()
            assetWriter!.startSession(atSourceTime: firstTimestamp)
        }
    }

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
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            print("Can't start recording: \(error)")
            return
        }

        let videoSettings = settings.makeVideoSettings()
        let audioSettings = settings.makeAudioSettings()

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput!.expectsMediaDataInRealTime = true

        guard assetWriter!.canAdd(videoInput!) else {
            fatalError("Can't add input to asset writer")
        }
        assetWriter!.add(videoInput!)

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput!.expectsMediaDataInRealTime = true

        if assetWriter!.canAdd(audioInput!) {
            assetWriter!.add(audioInput!)
        } else {
            print("Cannot add audio input")
        }

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
        )

        delegate?.recorderDidStart()
    }

    func stopRecording(completion: @escaping () -> Void) {

        if !isRecording { return }

        videoInput?.markAsFinished()
        assetWriter?.finishWriting {
            print("Recording finished")
            completion()
        }

        recordingRect = nil
        delegate?.recorderDidStop()
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
