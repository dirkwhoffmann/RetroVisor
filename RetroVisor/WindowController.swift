// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa
import ScreenCaptureKit

class WindowController: NSWindowController, Loggable  {

    var app: AppDelegate { NSApp.delegate as! AppDelegate }
    var viewController : ViewController? { return self.contentViewController as? ViewController }
    var effectWindow : EffectWindow? { return window as? EffectWindow }
    var metalView : MetalView? { return viewController?.metalView }

    // Enables debug output to the console
    let logging: Bool = false

    // Icon bar containing the recorder icon
    var accessory: IconBarViewController?

    // Video source and sink
    var recorder: Recorder { return app.recorder }
    var streamer: Streamer { return app.streamer }

    // Indicates if the window is passive (click-through state)
    var isFrozen: Bool { return window?.ignoresMouseEvents ?? false }

    // Indicates if the window is invisible (but still active)
    var invisible: Bool = false {
        didSet {
            if invisible {
                window?.isOpaque = false
                window?.backgroundColor = .clear
                window?.isMovable = false
                window?.alphaValue = 0.0
            } else {
                window?.isOpaque = true
                window?.isMovable = true
                window?.alphaValue = 1.0
            }
        }
    }

    override func windowDidLoad() {

        super.windowDidLoad()

        let window = self.window as! EffectWindow

        // Setup the window
        window.hasShadow = true
        window.level = .floating
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.trackingDelegate = self
        window.makeKeyAndOrderFront(nil)
        unfreeze()

        // Setup the streamer
        streamer.delegate = self
        streamer.window = effectWindow

        // Setup the recorder
        recorder.delegate = self

        // Launch the streamer
        Task { await streamer.launch() }
    }

    func showPermissionAlert() {

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        This app needs screen recording permission to capture content.
        Please enable it in System Settings › Privacy & Security › Screen Recording, then restart the app.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func freeze() {

        let window = self.window as! TrackingWindow

        window.ignoresMouseEvents = true
        window.styleMask = [.titled, .nonactivatingPanel, .fullSizeContentView]
        window.contentView?.layer?.borderWidth = 0
        window.contentView?.layer?.cornerRadius = 0
    }

    func unfreeze() {

        let window = self.window as! TrackingWindow

        window.ignoresMouseEvents = false
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable,
                            .nonactivatingPanel, .fullSizeContentView]
        window.contentView?.layer?.borderColor = NSColor.systemBlue.cgColor
        window.contentView?.layer?.borderWidth = 2
        window.contentView?.layer?.cornerRadius = 10
    }
}

extension WindowController: TrackingWindowDelegate {

    func windowDidStartResize(_ window: TrackingWindow) {

        metalView!.intensity.target = 1.0
        metalView!.intensity.steps = 15
    }

    func windowDidStopResize(_ window: TrackingWindow) {

        metalView!.intensity.target = 0.0
        metalView!.intensity.steps = 15
        metalView!.updateTextures(rect: window.frame)

        streamer.updateRects()
        streamer.relaunchIfNeeded()
    }

    func windowDidStartDrag(_ window: TrackingWindow) {

        metalView!.intensity.target = 1.0
        metalView!.intensity.steps = 25
    }

    func windowDidStopDrag(_ window: TrackingWindow) {

        metalView!.intensity.target = 0.0
        metalView!.intensity.steps = 25

        streamer.updateRects()
        streamer.relaunchIfNeeded()
    }

    func windowWasDoubleClicked(_ window: TrackingWindow) {

        freeze()
    }

    func windowDidChangeScreen(_ window: TrackingWindow) {

        streamer.relaunch()
    }
}

extension WindowController: StreamerDelegate {


    func textureRectDidChange(rect: CGRect?) {

        metalView?.updateVertexBuffers(rect)
    }

    func captureRectDidChange(rect: CGRect?) {

    }

    func streamDidStop(error: Error?) {

        if let image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: nil) {
            effectWindow?.showPauseOverlay(image: image) {
                self.app.streamer.relaunch()
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {

        switch type {

        case .screen:

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }

            DispatchQueue.main.async { [weak self] in

                if let vc = self?.contentViewController as? ViewController {

                    let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                    self?.recorder.timestamp = pts
                    vc.metalView.update(with: pixelBuffer)
                }
            }

        case .audio:

            DispatchQueue.main.async { [weak self] in

                self?.recorder.appendAudio(buffer: buffer)
            }

        default:
            break
        }
    }
}

extension WindowController: RecorderDelegate {

    func recorderDidStart() {

        app.updateStatusBarMenuIcon(recording: true)
    }

    func recorderDidStop() {

        app.updateStatusBarMenuIcon(recording: false)
    }
}

