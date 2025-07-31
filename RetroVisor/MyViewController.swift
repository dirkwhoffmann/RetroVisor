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

struct Vertex {

    var pos: SIMD4<Float>              // 16 bytes
    var tex: SIMD2<Float>              // 8 bytes
    var pad: SIMD2<Float> = [0, 0]
}

class MyViewController: NSViewController, MTKViewDelegate {

    var mtkView: MTKView!
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var samplerState: MTLSamplerState!

    var textureCache: CVMetalTextureCache!
    var currentTexture: MTLTexture?
    // var timeBuffer: MTLBuffer!

    var animate: Bool = false

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

        updateTextureRect(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))

        // Load shaders from default library
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexFunc = defaultLibrary.makeFunction(name: "vertex_main")!
        let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_main")!

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest
        samplerDescriptor.mipFilter = .notMipmapped
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)

        // Setup vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()

        // Single interleaved buffer
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex

        // Positions
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        // Texture coordinates
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0

        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // Create uniforms
        // timeBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride, options: [])

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    func updateTextureRect(_ rect: CGRect) {

        /*
        let tx1 = Float(0.0)
        let tx2 = Float(1.0)
        let ty1 = Float(0.0)
        let ty2 = Float(1.0)
        */
        let tx1 = Float(rect.minX)
        let tx2 = Float(rect.maxX)
//        let ty1 = Float(1.0 - rect.maxY)
//        let ty2 = Float(1.0 - rect.minY)
        let ty1 = Float(rect.minY)
        let ty2 = Float(rect.maxY)

        let vertices: [Vertex] = [
            Vertex(pos: [-1,  1, 0, 1], tex: [tx1, ty1]),
            Vertex(pos: [-1, -1, 0, 1], tex: [tx1, ty2]),
            Vertex(pos: [ 1,  1, 0, 1], tex: [tx2, ty1]),
            Vertex(pos: [ 1, -1, 0, 1], tex: [tx2, ty2]),
        ]

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: vertices.count * MemoryLayout<Vertex>.stride,
                                         options: [])
    }

    func texture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        // let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

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

    /*
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        print("MyViewController.mouseUp \(Date())")
        if let controller = view.window?.windowController as? MyWindowController {
            Task {
                print("Heureka \(Date())")
                await controller.recorder.restart(receiver: controller)
            }
        }
    }
    */

    func update(with pixelBuffer: CVPixelBuffer) {
        // Convert pixelBuffer to Metal texture (or store it)
        self.currentTexture = texture(from: pixelBuffer)

        // Trigger view redraw
        mtkView.setNeedsDisplay(mtkView.bounds)
    }

    var time: Float = 0.0
    var center: SIMD2<Float> = SIMD2(0.5, 0.5)

    func draw(in view: MTKView) {

        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let passDescriptor = view.currentRenderPassDescriptor else { return }

        // time = animate ? time + 0.016 : 0.0
//        memcpy(timeBuffer.contents(), &time, MemoryLayout<Float>.stride)
        time += 0.01

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)!
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        // encoder.setFragmentBuffer(timeBuffer, offset: 0, index: 0)

        if let texture = currentTexture {
            encoder.setFragmentTexture(texture, index: 0)
        }

        // Pass uniforms: time and center
        encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        // encoder.setFragmentBytes(&center, length: MemoryLayout<SIMD2<Float>>.size, index: 1)


        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes if needed
    }
}
