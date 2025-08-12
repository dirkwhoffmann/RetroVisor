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

struct StreamerSettings {

    enum CaptureMode: Int {

        case entire = 0
        case cutout = 1

        var help: String {

            switch self {
            case .entire: return
                "The streamer captures the entire screen but renders only a portion of the " +
                "texture. This approach is more resource-intensive but allows for smooth " +
                "real-time updates during window drag and resize operations. Recommended " +
                "for modern systems."

            case .cutout: return
                "The streamer captures only a portion of the screen and always renders the" +
                "full texture. This mode is more efficient, as ScreenCaptureKit streams " +
                "only the required area. However, moving or resizing the effect window " +
                "requires restarting the stream, resulting in less fluid animations " +
                "compared to responsive mode."
            }
        }
    }

    enum FpsMode: Int {

        case automatic = 0
        case fullThrottle = 1
        case custom = 2

        var help: String {

            switch self {
            case .automatic: return
                "Help text for automatic mode."

            case .fullThrottle: return
                "Help text for full throttle."

            case .custom: return
                "Help text for custom FPS."
            }
        }
    }

    var fpsMode: FpsMode
    var fps: Int
    var queueDepth: Int
    var captureMode: CaptureMode

    enum Preset {

        case systemDefault

        var settings: StreamerSettings {

            switch self {

            case .systemDefault:
                return StreamerSettings(fpsMode: .automatic,
                                        fps: 60,
                                        queueDepth: 3,
                                        captureMode: .entire
                )
            }
        }
    }
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

        case systemDefault
        case youtube1080p
        case youtube4k
        case proResHQ
        case smallFile

        var settings: RecorderSettings {

            switch self {

            case .systemDefault:
                return RecorderSettings(
                    videoType: .mov,
                    codec: .h264,
                    size: Shadowed(.zero, shadowed: true),
                    quality: Shadowed(0.9, shadowed: true),
                    frameRate: Shadowed(60, shadowed: true),
                    bitRate: Shadowed(6_000_000, shadowed: true),
                    audioFormat: .mpeg4AAC,
                    audioChannels: 2,
                    audioSampleRate: Shadowed(44_100),
                    audioBitRate: Shadowed(128_000)
                )
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

        var compressionProps: [String: Any] = [:]

        if let quality = quality.value {
            compressionProps[AVVideoQualityKey] = quality
        }
        if let bitRate = bitRate.value {
            compressionProps[AVVideoAverageBitRateKey] = bitRate
        }
        var settings: [String: Any] = [
            AVVideoCodecKey: codec.avCodec,
            AVVideoCompressionPropertiesKey: compressionProps
        ]
        if let resolution = size.value {
            settings[AVVideoWidthKey] = resolution.width
            settings[AVVideoHeightKey] = resolution.height
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
