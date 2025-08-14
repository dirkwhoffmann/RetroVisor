// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa
import MetalKit
import MetalPerformanceShaders

/* The current GPU pipeline consists of three stages:
 *
 * Stage 1: Main Processing
 *
 *          Applies the CRT effect shader to the input texture. This is the core
 *          rendering stage.
 *
 * Stage 2: Post-Processing (Blur Filter)
 *
 *          Applies a Gaussian-like blur during window animations (i.e., move or
 *          resize) to produce a smoother visual experience.
 *
 * Stage 3: Post-Processing (Ripple Effect)
 *
 *          Adds a water ripple effect during window drag and resize operations,
 *          enhancing visual feedback with a dynamic distortion.
 */

enum ShaderType {

    case none
    case crt
}

struct Vertex {

    var pos: SIMD4<Float>
    var tex: SIMD2<Float>
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

struct CrtUniforms {

    var ENABLE: Int32
    var BRIGHT_BOOST: Float
    var DILATION: Float
    var GAMMA_INPUT: Float
    var GAMMA_OUTPUT: Float
    var MASK_SIZE: Float
    var MASK_STAGGER: Float
    var MASK_STRENGTH: Float
    var MASK_DOT_WIDTH: Float
    var MASK_DOT_HEIGHT: Float
    var SCANLINE_BEAM_WIDTH_MAX: Float
    var SCANLINE_BEAM_WIDTH_MIN: Float
    var SCANLINE_BRIGHT_MAX: Float
    var SCANLINE_BRIGHT_MIN: Float
    var SCANLINE_CUTOFF: Float
    var SCANLINE_STRENGTH: Float
    var SHARPNESS_H: Float
    var SHARPNESS_V: Float
    var ENABLE_LANCZOS: Int32

    static let defaults = CrtUniforms(

        ENABLE: 1,
        BRIGHT_BOOST: 1.2,
        DILATION: 1.0,
        GAMMA_INPUT: 2.0,
        GAMMA_OUTPUT: 1.8,
        MASK_SIZE: 1.0,
        MASK_STAGGER: 0.0,
        MASK_STRENGTH: 0.3,
        MASK_DOT_WIDTH: 1.0,
        MASK_DOT_HEIGHT: 1.0,
        SCANLINE_BEAM_WIDTH_MAX: 1.5,
        SCANLINE_BEAM_WIDTH_MIN: 1.5,
        SCANLINE_BRIGHT_MAX: 0.65,
        SCANLINE_BRIGHT_MIN: 0.35,
        SCANLINE_CUTOFF: 1000.0,
        SCANLINE_STRENGTH: 1.0,
        SHARPNESS_H: 0.5,
        SHARPNESS_V: 1.0,
        ENABLE_LANCZOS: 1
    )
}

class MetalView: MTKView, Loggable, MTKViewDelegate {

    @IBOutlet weak var viewController: ViewController!

    // Enables debug output to the console
    let logging: Bool = false

    var trackingWindow: TrackingWindow { window! as! TrackingWindow }
    var app: AppDelegate { NSApp.delegate as! AppDelegate }
    var windowController: WindowController? { return trackingWindow.windowController as? WindowController }
    var recorder: Recorder? { return windowController?.recorder }

    var commandQueue: MTLCommandQueue!
    var pipelineState1: MTLRenderPipelineState!
    var pipelineState2: MTLRenderPipelineState!
    var vertexBuffer1: MTLBuffer!
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
    var inTexture: MTLTexture?
    var outTexture: MTLTexture?

    var time: Float = 0.0
    var zoom: Float = 1.0 { didSet { zoom = min(max(zoom, 1.0), 16.0) } }

    // var frame = 0
    var animate: Bool = false

    var intensity = Animated<Float>(0.0)

    required init(coder: NSCoder) {

        super.init(coder: coder)

        log("MetalView init")

        device = MTLCreateSystemDefaultDevice()
        guard let device = device else { return }

        delegate = self
        clearColor = MTLClearColorMake(0, 0, 0, 1)
        delegate = self
        enableSetNeedsDisplay = true
        framebufferOnly = false

        // Create a command queue
        commandQueue = device.makeCommandQueue()

        // Create a texture cache
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)

        // Setup the vertex buffers
        updateVertexBuffers(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))

        // Load shaders from the default library
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexFunc = defaultLibrary.makeFunction(name: "vertex_main")!
        let bypassFunc = defaultLibrary.makeFunction(name: "fragment_bypass")!
        let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_crt_easymode")!
        let rippleFunc = defaultLibrary.makeFunction(name: "fragment_ripple")!

        // Create texture samplers
        nearestSampler = makeSamplerState(minFilter: .nearest, magFilter: .nearest)
        linearSampler  = makeSamplerState(minFilter: .linear,  magFilter: .linear)

        // Setup a vertex descriptor
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

        // Setup the pipelin descriptor for the bypass shader (no CRT effect)
        let pipelineDescriptor0 = MTLRenderPipelineDescriptor()
        pipelineDescriptor0.vertexFunction = vertexFunc
        pipelineDescriptor0.fragmentFunction = bypassFunc
        pipelineDescriptor0.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor0.vertexDescriptor = vertexDescriptor

        let pipelineDescriptor1 = MTLRenderPipelineDescriptor()
        pipelineDescriptor1.vertexFunction = vertexFunc
        pipelineDescriptor1.fragmentFunction = fragmentFunc
        pipelineDescriptor1.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor1.vertexDescriptor = vertexDescriptor

        // Setup the pipelin descriptor for the post-processing phase
        let pipelineDescriptor2 = MTLRenderPipelineDescriptor()
        pipelineDescriptor2.vertexFunction = vertexFunc
        pipelineDescriptor2.fragmentFunction = rippleFunc
        pipelineDescriptor2.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor2.vertexDescriptor = vertexDescriptor

        // Create the pipeline states
        do {
            pipelineState1 = try device.makeRenderPipelineState(descriptor: pipelineDescriptor1)
            pipelineState2 = try device.makeRenderPipelineState(descriptor: pipelineDescriptor2)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }

        // Enable the magnification gesture
        let magnifyRecognizer = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        addGestureRecognizer(magnifyRecognizer)

        log("MetalView initialized")
    }

    func makeSamplerState(minFilter: MTLSamplerMinMagFilter, magFilter: MTLSamplerMinMagFilter) -> MTLSamplerState {

        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = minFilter
        descriptor.magFilter = magFilter
        descriptor.mipFilter = .notMipmapped
        return device!.makeSamplerState(descriptor: descriptor)!
    }

    func updateVertexBuffers(_ rect: CGRect?) {

        guard let rect = rect else { return }

        let tx1 = Float(rect.minX)
        let tx2 = Float(rect.maxX)
        let ty1 = Float(rect.minY)
        let ty2 = Float(rect.maxY)

        uniforms.texRect = [tx1, ty1, tx2, ty2];

        // Quad rendered in the main stage (CRT effect)
        let vertices1: [Vertex] = [
            Vertex(pos: [-1,  1, 0, 1], tex: [tx1, ty1]),
            Vertex(pos: [-1, -1, 0, 1], tex: [tx1, ty2]),
            Vertex(pos: [ 1,  1, 0, 1], tex: [tx2, ty1]),
            Vertex(pos: [ 1, -1, 0, 1], tex: [tx2, ty2]),
        ]

        // Quad rendered in the post-processing stage (drag and resize animation)
        let vertices2: [Vertex] = [
            Vertex(pos: [-1,  1, 0, 1], tex: [0, 0]),
            Vertex(pos: [-1, -1, 0, 1], tex: [0, 1]),
            Vertex(pos: [ 1,  1, 0, 1], tex: [1, 0]),
            Vertex(pos: [ 1, -1, 0, 1], tex: [1, 1]),
        ]

        vertexBuffer1 = device!.makeBuffer(bytes: vertices1,
                                           length: vertices1.count * MemoryLayout<Vertex>.stride,
                                           options: [])

        vertexBuffer2 = device!.makeBuffer(bytes: vertices2,
                                           length: vertices2.count * MemoryLayout<Vertex>.stride,
                                           options: [])

    }

    func updateTextures(rect: NSRect) {

        updateTextures(width: Int(rect.width), height: Int(rect.height))
    }

    func updateTextures(width: Int, height: Int) {

        let w = NSScreen.scaleFactor * width
        let h = NSScreen.scaleFactor * height

        if outTexture?.width != w || outTexture?.height != h {

            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                      width: w,
                                                                      height: h,
                                                                      mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
            outTexture = device!.makeTexture(descriptor: descriptor)
        }
    }

    func update(with pixelBuffer: CVPixelBuffer) {

        // Convert the CVPixelBuffer to a Metal texture
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

        if result == kCVReturnSuccess && cvTextureOut != nil {

            inTexture = CVMetalTextureGetTexture(cvTextureOut!)

            // Trigger the view to redraw
            setNeedsDisplay(bounds)

            // Pass the rendered texture to the recorder
            // TODO: DO THIS IN METAL VIEW ONCE THE TEXTURE HAS BEEN CREATED
            if outTexture != nil { recorder?.appendVideo(texture: outTexture!) }
        }
    }

    func draw(in view: MTKView) {

        guard let inTexture = self.inTexture else { return }
        guard var outTexture = self.outTexture else { return }

        windowController?.streamer.updateRects()

        // Advance the animation parameters
        intensity.move()
        time += 0.01

        // Get the location of the latest mouse down event
        let mouse = trackingWindow.initialMouseLocationNrm ?? .zero

        // Setup uniforms
        uniforms.time = time
        uniforms.zoom = zoom
        uniforms.intensity = intensity.current
        uniforms.resolution = [Float(inTexture.width), Float(inTexture.height)]
        uniforms.window = [Float(trackingWindow.liveFrame.width), Float(trackingWindow.liveFrame.height)]
        uniforms.mouse = [Float(mouse.x), Float(1.0 - mouse.y)]

        // Get the next drawable and create the command buffer
        guard let drawable = view.currentDrawable else { return }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        //
        // First pass: CRT effect
        //

        let renderPass1 = MTLRenderPassDescriptor()
        renderPass1.colorAttachments[0].texture = outTexture
        renderPass1.colorAttachments[0].loadAction = .clear
        renderPass1.colorAttachments[0].storeAction = .store
        renderPass1.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass1) {

            encoder.setRenderPipelineState(pipelineState1)
            encoder.setVertexBuffer(vertexBuffer1, offset: 0, index: 0)
            encoder.setFragmentTexture(inTexture, index: 0)
            encoder.setFragmentSamplerState(linearSampler, index: 0)
            encoder.setFragmentBytes(&uniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: 0)
            encoder.setFragmentBytes(&app.crtUniforms,
                                     length: MemoryLayout<CrtUniforms>.stride,
                                     index: 1)

            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        //
        // Second pass: In-texture blurring
        //

        if (uniforms.intensity > 0) {

            let radius = Int(9.0 * uniforms.intensity) | 1
            let blur = MPSImageBox(device: device!, kernelWidth: radius, kernelHeight: radius)
            blur.encode(commandBuffer: commandBuffer,
                        inPlaceTexture: &outTexture, fallbackCopyAllocator: nil)
        }

        //
        // Third pass: Water-ripple effect
        //

        guard let renderPass2 = view.currentRenderPassDescriptor else { return }
        renderPass2.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass2) {

            encoder.setRenderPipelineState(pipelineState2)
            encoder.setVertexBuffer(vertexBuffer2, offset: 0, index: 0)
            encoder.setFragmentTexture(outTexture, index: 0)
            encoder.setFragmentSamplerState(intensity.current > 0 ? linearSampler : nearestSampler, index: 0)

            // Pass uniforms: time and center
            encoder.setFragmentBytes(&uniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: 0)

            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }

    @objc func handleMagnify(_ recognizer: NSMagnificationGestureRecognizer) {

        zoom += Float(recognizer.magnification) * 0.1
    }
}
