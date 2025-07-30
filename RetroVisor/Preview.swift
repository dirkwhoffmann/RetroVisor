//
//  Preview.swift
//  RetroVisor
//
//  Created by Dirk Hoffmann on 30.07.25.
//
import Cocoa
import ScreenCaptureKit

class Preview: NSView {

    private var currentImage: NSImage?

    func updateImage(from sampleBuffer: CMSampleBuffer, cropRectPixels: CGRect?) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        let rect = cropRectPixels ?? CGRect(x: 0, y: 0, width: 200, height: 200)
        // let rect = CGRect(x: 100, y: 100, width: 200, height: 200)

        let imageHeight = ciImage.extent.height
        var adjustedCropRect = CGRect(
            x: rect.origin.x,
            y: imageHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height)
        adjustedCropRect = rect

        /*
        print("ciImage extent: \(ciImage.extent)")
        print("cropRect: \(rect)")
        print("adjustedCropRect: \(adjustedCropRect)")
        */
        
        let croppedImage = ciImage.cropped(to: adjustedCropRect).transformed(by: CGAffineTransform(translationX: -adjustedCropRect.origin.x,
                                                                                                   y: -adjustedCropRect.origin.y))

        // Apply Core Image filter
        let filter = CIFilter(name: "CISepiaTone")
        filter?.setValue(croppedImage, forKey: kCIInputImageKey)
        filter?.setValue(0.9, forKey: kCIInputIntensityKey)

        let outputImage = filter!.outputImage!
        let rep = NSCIImageRep(ciImage: outputImage)
        let nsImage = NSImage(size: outputImage.extent.size)
        nsImage.addRepresentation(rep)
/*
        let rep = NSCIImageRep(ciImage: croppedImage)
        let nsImage = NSImage(size: adjustedCropRect.size)
        // let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
*/

        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

        DispatchQueue.main.async {
            self.currentImage = nsImage
            self.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        currentImage?.draw(in: self.bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

}
