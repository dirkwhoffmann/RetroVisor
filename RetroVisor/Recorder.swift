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

    enum VideoResolution: Int, CaseIterable {

        case custom = 0
        case hd = 1
        case fhd = 2
        case uhd = 3

        var size: NSSize {
            switch self {
            case .custom: return .zero
            case .hd:     return NSSize(width: 1280, height: 720)
            case .fhd:    return NSSize(width: 1920, height: 1080)
            case .uhd:    return NSSize(width: 3840, height: 2160)
            }
        }

        var description: String {
            switch self {
            case .custom: return "Custom"
            case .hd:     return "HD"
            case .fhd:    return "Full HD"
            case .uhd:    return "Ultra HD"
            }
        }

        static func from(size: NSSize) -> VideoResolution {
            return Self.allCases.first(where: { $0.size == size }) ?? .custom
        }
    }

    enum AudioFormat: Int {

        case none = 0
        case mpeg4AAC = 1
        case linearPCM = 2

        var audioFormatID: AudioFormatID? {
            switch self {
            case .none:      return nil
            case .mpeg4AAC:  return kAudioFormatMPEG4AAC
            case .linearPCM: return kAudioFormatLinearPCM
            }
        }
    }

    var videoType: VideoType
    var codec: VideoCodec
    var size: Shadowed<NSSize>
    var quality: Shadowed<CGFloat>  // 0.0 = lowest, 1.0 = highest
    var frameRate: Shadowed<Int>
    var bitRate: Shadowed<Int>

    var audioFormat: AudioFormat
    var audioChannels: Int
    var audioSampleRate: Shadowed<Int>
    var audioBitRate: Shadowed<Int>

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
                    size: Shadowed(NSSize(width: 1920, height: 1080)),
                    quality: Shadowed(0.9),
                    frameRate: Shadowed(60),
                    bitRate: Shadowed(8_000_000),
                    audioFormat: .mpeg4AAC,
                    audioChannels: 2,
                    audioSampleRate: Shadowed(44100),
                    audioBitRate: Shadowed(192_000)
                )
            case .youtube4k:
                return RecorderSettings(
                    videoType: .mp4,
                    codec: .h264,
                    size: Shadowed(NSSize(width: 3840, height: 2160)),
                    quality: Shadowed( 0.95),
                    frameRate: Shadowed(60),
                    bitRate: Shadowed(35_000_000),
                    audioFormat: .mpeg4AAC,
                    audioChannels: 2,
                    audioSampleRate: Shadowed(48000),
                    audioBitRate: Shadowed(256_000)
                )
            case .proResHQ:
                return RecorderSettings(
                    videoType: .mov,
                    codec: .proRes422,
                    size: Shadowed(NSSize(width: 1920, height: 1080)),
                    quality: Shadowed(1.0),
                    frameRate: Shadowed(60),
                    bitRate: Shadowed(35_000_000),
                    audioFormat: .linearPCM,
                    audioChannels: 2,
                    audioSampleRate: Shadowed(48000),
                    audioBitRate: Shadowed(256_000)
                )
            case .smallFile:
                return RecorderSettings(
                    videoType: .mp4,
                    codec: .h264,
                    size: Shadowed(NSSize(width: 1280, height: 720)),
                    quality: Shadowed(0.7),
                    frameRate: Shadowed(30),
                    bitRate: Shadowed(2_000_000),
                    audioFormat: .mpeg4AAC,
                    audioChannels: 2,
                    audioSampleRate: Shadowed(44100),
                    audioBitRate: Shadowed(128_000)
                )
            }
        }
    }

    func makeVideoSettings() -> [String: Any] {

        var settings: [String: Any] = [
            AVVideoCodecKey: codec.avCodec,
            AVVideoWidthKey: Int(size.value?.width ?? 0),
            AVVideoHeightKey: Int(size.value?.height ?? 0),
            AVVideoCompressionPropertiesKey: [
                AVVideoQualityKey: quality
            ]
        ]

        if let bitRate = bitRate.value {
            var compressionProps = settings[AVVideoCompressionPropertiesKey] as! [String: Any]
            compressionProps[AVVideoAverageBitRateKey] = bitRate
            settings[AVVideoCompressionPropertiesKey] = compressionProps
        }

        return settings
    }

    func makeAudioSettings() -> [String: Any]? {

        if audioFormat == .none { return nil }

        var audioSettings: [String: Any] = [
            AVNumberOfChannelsKey: audioChannels,
            AVFormatIDKey: audioFormat.audioFormatID!
        ]
        if let bitRate = audioBitRate.value {
            audioSettings[AVEncoderBitRateKey] = bitRate
        }
        if let audioSampleRate = audioSampleRate.value {
            audioSettings[AVSampleRateKey] = audioSampleRate
        }

        return audioSettings
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
