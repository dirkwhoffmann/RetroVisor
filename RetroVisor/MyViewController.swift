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
    var zoom: Float
    var intensity: Float
    var resolution: SIMD2<Float>
    var window: SIMD2<Float>
    var center: SIMD2<Float>
    var mouse: SIMD2<Float>
    var texRect: SIMD4<Float>
}

class MyViewController: NSViewController, MTKViewDelegate {

    var mtkView: MTKView!
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState1: MTLRenderPipelineState!
    var pipelineState2: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var vertexBuffer2: MTLBuffer!
    var nearestSampler: MTLSamplerState!
    var linearSampler: MTLSamplerState!

    var uniforms = Uniforms.init(time: 0.0,
                                 zoom: 1.0,
                                 intensity: 0.0,
                                 resolution: [0,0],
                                 window: [0,0],
                                 center: [0,0],
                                 mouse: [0,0],
                                 texRect: [0,0,0,0])

    var textureCache: CVMetalTextureCache!
    var currentTexture: MTLTexture?
    // var timeBuffer: MTLBuffer!
    var intermediateTexture: MTLTexture?

    var time: Float = 0.0
    var zoom: Float = 1.0 { didSet { zoom = min(max(zoom, 1.0), 16.0) } }
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
        // let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_main")!
        let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_crt_easymode")!
        let rippleFunc = defaultLibrary.makeFunction(name: "fragment_ripple")!

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

        // Create pipeline descriptors
        let pipelineDescriptor1 = MTLRenderPipelineDescriptor()
        pipelineDescriptor1.vertexFunction = vertexFunc
        pipelineDescriptor1.fragmentFunction = fragmentFunc
        pipelineDescriptor1.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor1.vertexDescriptor = vertexDescriptor

        let pipelineDescriptor2 = MTLRenderPipelineDescriptor()
        pipelineDescriptor2.vertexFunction = vertexFunc
        pipelineDescriptor2.fragmentFunction = rippleFunc
        pipelineDescriptor2.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor2.vertexDescriptor = vertexDescriptor

        do {
            pipelineState1 = try device.makeRenderPipelineState(descriptor: pipelineDescriptor1)
            pipelineState2 = try device.makeRenderPipelineState(descriptor: pipelineDescriptor2)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }

        setupMagnificationGesture()
    }

    func setupMagnificationGesture() {

        // guard let contentView = window?.contentView else { return }
        let magnifyRecognizer = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        view.addGestureRecognizer(magnifyRecognizer)
    }

    @objc func handleMagnify(_ recognizer: NSMagnificationGestureRecognizer) {

        zoom += Float(recognizer.magnification) * 0.1
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

        let vertices2: [Vertex] = [
            Vertex(pos: [-1,  1, 0, 1], tex: [0, 0]),
            Vertex(pos: [-1, -1, 0, 1], tex: [0, 1]),
            Vertex(pos: [ 1,  1, 0, 1], tex: [1, 0]),
            Vertex(pos: [ 1, -1, 0, 1], tex: [1, 1]),
        ]

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: vertices.count * MemoryLayout<Vertex>.stride,
                                         options: [])

        vertexBuffer2 = device.makeBuffer(bytes: vertices2,
                                         length: vertices2.count * MemoryLayout<Vertex>.stride,
                                         options: [])

    }

    func texture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

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

        let width = currentTexture!.width
        let height = currentTexture!.height

        // Create a fitting intermediate texture
        if intermediateTexture == nil ||
            intermediateTexture!.width != width ||
            intermediateTexture!.height != height {

            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                      width: width,
                                                                      height: height,
                                                                      mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
            descriptor.storageMode = .private

            intermediateTexture = device.makeTexture(descriptor: descriptor)
        }

        // Trigger view redraw
        mtkView.setNeedsDisplay(mtkView.bounds)
    }

    func makeIntermediateTexture(device: MTLDevice, width: Int, height: Int) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm             // typical color format
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.usage = [.renderTarget, .shaderRead]  // render target and readable in shaders
        textureDescriptor.storageMode = .private                 // optimized for GPU-only access

        return device.makeTexture(descriptor: textureDescriptor)
    }

    private var lastFrameTime: TimeInterval = CACurrentMediaTime()
    private let expectedFrameDuration: TimeInterval = 1.0 / 60.0  // for 60 FPS
    private let frameDropThresholdMultiplier = 1.5  // Consider frame dropped if duration > 1.5x expected

    func draw(in view: MTKView) {

        let w = view.window as! GlassWindow
        w.myWindowController!.scheduleDebouncedUpdate(frame: w.liveFrame)

        intensity.move()

        let mouse = w.myWindowController!.trackingWindow?.initialMouseLocationNrm ?? .zero //  normalizedMouseLocation ?? .zero
        time += 0.01
        frame += 1
        uniforms.time = time
        uniforms.zoom = zoom
        uniforms.intensity = intensity.current
        uniforms.resolution = [Float(intermediateTexture?.width ?? 100),Float(intermediateTexture?.height ?? 100)]
        uniforms.window = [Float(w.liveFrame.width),Float(w.liveFrame.height)]
        // print("interm: \(intermediateTexture?.width ?? 0) \(intermediateTexture?.height ?? 0)")
        // print("frame: \(w.liveFrame.width) \(w.liveFrame.height)")
        uniforms.mouse = [Float(mouse.x), Float(1.0 - mouse.y)]

        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }


        //
        // First pass
        //

        if intermediateTexture == nil {
            intermediateTexture = makeIntermediateTexture(device: device, width: Int(trect.width), height: Int(trect.height))
        }
        let ripplePassDescriptor = MTLRenderPassDescriptor()
        ripplePassDescriptor.colorAttachments[0].texture = intermediateTexture
        ripplePassDescriptor.colorAttachments[0].loadAction = .clear
        ripplePassDescriptor.colorAttachments[0].storeAction = .store
        ripplePassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        if let rippleEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: ripplePassDescriptor) {
            rippleEncoder.setRenderPipelineState(pipelineState1)
            rippleEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            rippleEncoder.setFragmentTexture(currentTexture, index: 0)
            rippleEncoder.setFragmentSamplerState(linearSampler, index: 0)
            rippleEncoder.setFragmentBytes(&uniforms,
                                           length: MemoryLayout<Uniforms>.stride,
                                           index: 0)

            rippleEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            rippleEncoder.endEncoding()
        }

        //
        // Second pass
        //

        guard let passDescriptor = view.currentRenderPassDescriptor else { return }

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)!
        encoder.setRenderPipelineState(pipelineState2)
        encoder.setVertexBuffer(vertexBuffer2, offset: 0, index: 0)
        encoder.setFragmentTexture(intermediateTexture, index: 0) // use ripple output
        encoder.setFragmentSamplerState(intensity.current > 0 ? linearSampler : nearestSampler, index: 0)

        // Pass uniforms: time and center
        encoder.setFragmentBytes(&uniforms,
                                 length: MemoryLayout<Uniforms>.stride,
                                 index: 0)


        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes if needed
    }

    @IBAction func zoomInAction(_ sender: NSMenuItem) {

        print("zoomInAction")
        zoom += 0.5
    }

    @IBAction func zoomOutAction(_ sender: NSMenuItem) {

        print("zoomOutAction")
        zoom -= 0.5
    }
}
