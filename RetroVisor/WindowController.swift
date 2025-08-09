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

class WindowController: NSWindowController  {

    var viewController : ViewController? { return self.contentViewController as? ViewController }
    var trackingWindow : TrackingWindow? { return window as? TrackingWindow }
    var metalView : MetalView? { return viewController?.metalView }

    // The screen recorder
    var recorder = ScreenRecorder()

    // Indicates if the window is passive (click-through state)
    var isFrozen: Bool { return window?.ignoresMouseEvents ?? false }

    override func windowDidLoad() {

        print("WindowController.windowDidLoad")
        super.windowDidLoad()

        let window = self.window as! TrackingWindow

        // Setup the window
        window.hasShadow = true
        window.level = .floating
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.trackingDelegate = self
        window.makeKeyAndOrderFront(nil)
        unfreeze()

        // Setup the recorder
        recorder.delegate = self
        recorder.window = trackingWindow


        Task {
            if await ScreenRecorder.permissions {
                await recorder.launch()
            } else {
                showPermissionAlert()
            }
        }
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
        window.contentView?.layer?.borderColor = NSColor.systemGray.cgColor
        window.contentView?.layer?.borderWidth = 0
        window.contentView?.layer?.cornerRadius = 10
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

        recorder.updateRects()
        recorder.relaunchIfNeeded()
    }

    func windowDidStartDrag(_ window: TrackingWindow) {

        metalView!.intensity.target = 1.0
        metalView!.intensity.steps = 25
    }

    func windowDidStopDrag(_ window: TrackingWindow) {

        metalView!.intensity.target = 0.0
        metalView!.intensity.steps = 25

        recorder.updateRects()
        recorder.relaunchIfNeeded()

        /*
        print("window: \(window.frame)")
        print("sourceRect: \(recorder.sourceRect ?? .null)")
        print("captureRect: \(recorder.captureRect ?? .null)")
        print("textureRect: \(recorder.textureRect ?? .null)")
        */
    }

    func windowWasDoubleClicked(_ window: TrackingWindow) {

        freeze()
    }

    func windowDidChangeScreen(_ window: TrackingWindow) {

        recorder.relaunch()
    }
}

extension WindowController: ScreenRecorderDelegate {

    func textureRectDidChange(rect: CGRect?) {

        metalView?.updateVertexBuffers(rect)
    }

    func recorderDidStart() {

        print("recorderDidRestart")
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {

        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {

            // Process the pixel buffer in the Metal view
            DispatchQueue.main.async { [weak self] in

                if let vc = self?.contentViewController as? ViewController {

                    let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                    self?.recorder.currentTime = pts
                    vc.metalView.update(with: pixelBuffer)
                }
            }

            // recorder.record(buffer: buffer, pixelBuffer: pixelBuffer)
        }
    }
}
