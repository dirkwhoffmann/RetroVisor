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

enum RecorderCommand {
    
    case start(url: URL, width: Int, height: Int, countdown: Int)
    case stop
}

@MainActor
protocol RecorderDelegate: AnyObject {

    func recorderDidStart()
    func recorderDidStop()
}

@MainActor
class Recorder: Loggable {

    // Enables debug output to the console
    nonisolated static let logging: Bool = false
    
    // Event receiver
    var delegate: RecorderDelegate?

    // Recorder settings
    var settings = RecorderSettings.Preset.systemDefault.settings

    // Command queue for controlling the recorder
    private let commands = AtomicQueue<RecorderCommand>()
    
    // The current recording state
    private(set) var recording: Bool = false

    // The current frame number
    private(set) var frame: Int = 0

    // Frame counter to skip initial frames after recording starts
    private var countdown: Int?

    private var url: URL?
    private var width: Int = 0
    private var height: Int = 0
    
    // AVWriter
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    /* Inserts a command into the command queue
     */
    func enqueue(_ cmd: RecorderCommand) {
            
        commands.push(cmd)
    }
    
    /* Appends a video frame and control the recorder state
     */
    func appendVideo(texture: MTLTexture?, timestamp: CMTime?) {
        
        // Update the recording icon
        app.windowController?.effectWindow?.onAir = recording

        // We cannot record without a texture and a timestamp
        guard let texture = texture else { return }
        guard let timestamp = timestamp else { return }

        // Process pending commands
        for cmd in commands.popAll() {
            
            log("Frame \(frame): Processing command \(cmd)")
            switch cmd {
                
            case .start(let url, let width, let height, let countdown):
                
                if recording {
                    
                    log("Frame \(frame): Cannot start a running recorder.", .warning)
                    continue
                }
                
                self.url = url
                self.width = width
                self.height = height
                self.countdown = countdown
                
            case .stop:
                
                if !recording {
                    
                    log("Frame \(frame): Cannot stop a stopped recorder.", .warning)
                    continue
                }
                
                stopRecording { }
            }
        }
        
        // Handle countdown
        if let remaining = countdown {
            
            if remaining > 0 {
                countdown = remaining - 1
            } else {
                startRecording(to: url!, timestamp: timestamp)
            }
        }

        // Exit if the recorder is in idle state
        if !recording { return }
        
        // Stop recording if the texture size did change
        if width != texture.width || height != texture.height {
            
            log("Frame \(frame): Rect has changed. Stopping the recorder...")
            enqueue(.stop)
            return
        }

        // Advance the frame counter
        frame += 1
        if frame & 63 == 0 { log("Recording frame \(frame)") }

        guard videoInput!.isReadyForMoreMediaData else {
            
            log("Frame \(frame): AVAssetWriter does not accept new input", .warning)
            return
        }
        guard let pixelBufferPool = pixelBufferAdaptor?.pixelBufferPool else {
            
            log("Frame \(frame): AVAssetWriter provides no pixelBufferPool.", .warning)
            return
        }

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
 
        guard let pixelBuffer = pixelBuffer else {
            
            log("Frame \(frame): AVAssetWriter provides no pixel buffer", .warning)
            return
        }

        // Copy the Metal texture into the pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        texture.getBytes(CVPixelBufferGetBaseAddress(pixelBuffer)!,
                         bytesPerRow: bytesPerRow,
                         from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                         mipmapLevel: 0)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        // Append the pixel buffer to the video
        pixelBufferAdaptor!.append(pixelBuffer, withPresentationTime: timestamp)
    }

    func appendAudio(buffer: CMSampleBuffer) {

        if !recording { return }
        
        if audioInput?.isReadyForMoreMediaData == true {
            audioInput!.append(buffer)
        }
    }
    
    private func startRecording(to url: URL, timestamp: CMTime) {

        log("Frame \(frame): startRecording(\(url), \(timestamp))")
        
        assert(!recording)
        
        // Remove the file if it already exists
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        do {
            assetWriter = try AVAssetWriter(outputURL: url,
                                            fileType: settings.videoType.avFileType)
        } catch {
            log("Frame \(frame): Can't start recording: \(error)", .error)
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

        assetWriter?.startWriting()
        assetWriter?.startSession(atSourceTime: timestamp)
        
        countdown = nil
        recording = true
        frame = 0

        delegate?.recorderDidStart()
    }

    private func stopRecording(completion: @Sendable @escaping () -> Void) {

        log("Frame \(frame): stopRecording")
        assert(recording)

        videoInput?.markAsFinished()
        assetWriter?.finishWriting { completion() }

        recording = false
        frame = 0

        delegate?.recorderDidStop()
    }
    
}
