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

struct Uniforms {

    var time: Float
    var intensity: Float
    var center: SIMD2<Float>
    var mouse: SIMD2<Float>
    var texRect: SIMD4<Float>
}

class MyViewController: NSViewController, MTKViewDelegate {

    var mtkView: MTKView!
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var nearestSampler: MTLSamplerState!
    var linearSampler: MTLSamplerState!

    var uniforms = Uniforms.init(time: 0.0,
                                 intensity: 0.0,
                                 center: [0,0],
                                 mouse: [0,0],
                                 texRect: [0,0,0,0])

    var textureCache: CVMetalTextureCache!
    var currentTexture: MTLTexture?
    // var timeBuffer: MTLBuffer!

    var time: Float = 0.0
    var center: SIMD2<Float> = SIMD2(0.5, 0.5)

    var frame = 0
    var animate: Bool = false

    var intensity = Animated<Float>(0.0)

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

        // Create texture samplers
        nearestSampler = makeSamplerState(minFilter: .nearest, magFilter: .nearest)
        linearSampler  = makeSamplerState(minFilter: .linear,  magFilter: .linear)

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

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    func makeSamplerState(minFilter: MTLSamplerMinMagFilter, magFilter: MTLSamplerMinMagFilter) -> MTLSamplerState {

        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = minFilter
        descriptor.magFilter = magFilter
        descriptor.mipFilter = .notMipmapped
        return device.makeSamplerState(descriptor: descriptor)!
    }

    var trect: CGRect = .zero

    func updateTextureRect(_ rect: CGRect) {

        trect = rect
        /*
        let tx1 = Float(0.0)
        let tx2 = Float(1.0)
        let ty1 = Float(0.0)
        let ty2 = Float(1.0)
        */
        let tx1 = Float(rect.minX)
        let tx2 = Float(rect.maxX)
        let ty1 = Float(rect.minY)
        let ty2 = Float(rect.maxY)

        uniforms.texRect = [tx1, ty1, tx2, ty2];

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

    func update(with pixelBuffer: CVPixelBuffer) {
        // Convert pixelBuffer to Metal texture (or store it)
        self.currentTexture = texture(from: pixelBuffer)

        // Trigger view redraw
        mtkView.setNeedsDisplay(mtkView.bounds)
    }

    private var lastFrameTime: TimeInterval = CACurrentMediaTime()
    private let expectedFrameDuration: TimeInterval = 1.0 / 60.0  // for 60 FPS
    private let frameDropThresholdMultiplier = 1.5  // Consider frame dropped if duration > 1.5x expected

    var theFrame = CGRect.zero
    var theFrame2 = CGRect.zero

    func draw(in view: MTKView) {

        let w = view.window as! GlassWindow
        theFrame2 = w.liveFrame
        // print("liveFrame: \(w.liveFrame)")
        // print("window.frame: \(w.frame)")
        w.myWindowController!.scheduleDebouncedUpdate(frame: theFrame2)

        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let passDescriptor = view.currentRenderPassDescriptor else { return }

        intensity.move()
        // if intensity.animates { print("intensity = \(intensity.current)") }

        let mouse = w.myWindowController!.trackingWindow?.initialMouseLocationNrm ?? .zero //  normalizedMouseLocation ?? .zero
        // let trect = w.myWindowController!.textureRect ?? .zero
        let mx = trect.minX + trect.width * mouse.x
        let my = trect.maxY - trect.height * mouse.y
        // print("mx = \(mx), my = \(my)")
        time += 0.01
        frame += 1
        uniforms.time = time
        uniforms.intensity = intensity.current
        uniforms.mouse = [Float(mx), Float(my)]

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)!
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentSamplerState(intensity.current > 0 ? linearSampler : nearestSampler, index: 0)
        // encoder.setFragmentBuffer(timeBuffer, offset: 0, index: 0)

        if let texture = currentTexture {
            encoder.setFragmentTexture(texture, index: 0)
        }

        // Pass uniforms: time and center
        encoder.setFragmentBytes(&uniforms,
                                 length: MemoryLayout<Uniforms>.stride,
                                 index: 0)


        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        theFrame2 = theFrame
        theFrame = w.liveFrame
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes if needed
    }
}
