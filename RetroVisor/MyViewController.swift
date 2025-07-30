// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

import Cocoa
import MetalKit

class MyViewController: NSViewController, MTKViewDelegate {

    var mtkView: MTKView!
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var samplerState: MTLSamplerState!

    var textureCache: CVMetalTextureCache!
    var currentTexture: MTLTexture?
    
    override func loadView() {
        // Create MTKView programmatically as the main view
        device = MTLCreateSystemDefaultDevice()
        mtkView = MTKView(frame: .zero, device: device)
        mtkView.clearColor = MTLClearColorMake(0, 0, 0, 1)
        mtkView.delegate = self
        mtkView.enableSetNeedsDisplay = true
        mtkView.framebufferOnly = false
        self.view = mtkView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)

        commandQueue = device.makeCommandQueue()

        // Quad vertices for fullscreen rectangle (NDC coords)
        let vertices: [Float] = [
            -1,  1, 0, 1,  // top-left
             -1, -1, 0, 1,  // bottom-left
             1,  1, 0, 1,  // top-right
             1, -1, 0, 1,  // bottom-right
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])

        // Load shaders from default library
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexFunc = defaultLibrary.makeFunction(name: "vertex_main")!
        let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_main")!

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .notMipmapped
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)

        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    func texture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

        var cvTextureOut: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(nil,
                                                               textureCache,
                                                               pixelBuffer,
                                                               nil,
                                                               .bgra8Unorm,
                                                               width,
                                                               height,
                                                               0,
                                                               &cvTextureOut)
        if result == kCVReturnSuccess, let cvTexture = cvTextureOut {
            return CVMetalTextureGetTexture(cvTexture)
        }
        return nil
    }

    // MARK: - MTKViewDelegate methods

    func update(with pixelBuffer: CVPixelBuffer) {
        // Convert pixelBuffer to Metal texture (or store it)
        self.currentTexture = texture(from: pixelBuffer)

        // Trigger view redraw
        mtkView.setNeedsDisplay(mtkView.bounds)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let passDescriptor = view.currentRenderPassDescriptor else { return }

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)!
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(currentTexture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)

        if let texture = currentTexture {
            encoder.setFragmentTexture(texture, index: 0)
        }

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes if needed
    }
}
