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
 * Stage 3: Rendering
 *
 *          Zooms the texture (if requested) and draws the final quad.
 *          Additonally, a water ripple effect during window drag and resize
 *          operations, enhancing visual feedback with a dynamic distortion.
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

class MetalView: MTKView, Loggable, MTKViewDelegate {

    @IBOutlet weak var viewController: ViewController!

    let logging: Bool = false

    var trackingWindow: TrackingWindow { window! as! TrackingWindow }
    var windowController: WindowController? { return trackingWindow.windowController as? WindowController }
    var recorder: Recorder? { return windowController?.recorder }

    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var renderPass: MTLRenderPassDescriptor!

    var uniforms = Uniforms.init(time: 0.0,
                                 zoom: 1.0,
                                 intensity: 0.0,
                                 resolution: [0, 0],
                                 window: [0, 0],
                                 center: [0, 0],
                                 mouse: [0, 0],
                                 texRect: [0.0, 0.0, 1.0, 1.0])

    var textureCache: CVMetalTextureCache!

    var inTexture: MTLTexture?  // Input texture from the screen capturer
    var outTexture: MTLTexture? // Effect shader output

    var time: Float = 0.0
    var zoom: Float = 1.0 { didSet { zoom = min(max(zoom, 1.0), 16.0) } }

    var intensity = Animated<Float>(0.0)
    var animates: Bool { intensity.current > 0 }

    required init(coder: NSCoder) {

        super.init(coder: coder)

        delegate = self
        enableSetNeedsDisplay = true
        framebufferOnly = false
        clearColor = MTLClearColorMake(0, 0, 0, 1)

        initMetal()

        // Enable the magnification gesture
        let magnifyRecognizer = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        addGestureRecognizer(magnifyRecognizer)
    }

    func initMetal() {

        device = ShaderLibrary.device
        guard let device = device else { return }

        // Create a command queue
        commandQueue = device.makeCommandQueue()

        // Create a texture cache
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)

        // Setup the vertex buffers
        // textureRectDidChange(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))

        // Load shaders from the default library
        let vertexFunc = ShaderLibrary.library.makeFunction(name: "vertex_main")!
        let fragmentFunc = ShaderLibrary.library.makeFunction(name: "fragment_main")!

        // Setup a vertex descriptor (single interleaved buffer)
        let vertexDescriptor = MTLVertexDescriptor()
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

        // Setup the vertex buffer (full quad)
        let vertices: [Vertex] = [
            Vertex(pos: [-1,  1, 0, 1], tex: [0, 0]),
            Vertex(pos: [-1, -1, 0, 1], tex: [0, 1]),
            Vertex(pos: [ 1,  1, 0, 1], tex: [1, 0]),
            Vertex(pos: [ 1, -1, 0, 1], tex: [1, 1])
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: vertices.count * MemoryLayout<Vertex>.stride,
                                         options: [])

        // Setup the pipelin descriptor for the post-processing phase
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // Create the pipeline states
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    func textureRectDidChange(_ rect: CGRect?) {

        if let rect = rect {

            uniforms.texRect = [ Float(rect.minX),
                                 Float(rect.minY),
                                 Float(rect.maxX),
                                 Float(rect.maxY) ]
        }
    }

    func updateTextures(rect: NSRect) {

        updateTextures(width: Int(rect.width), height: Int(rect.height))
    }

    func updateTextures(width: Int, height: Int) {

        let width = NSScreen.scaleFactor * width
        let height = NSScreen.scaleFactor * height

        // print("Creating out texture of size \(width)x\(height)")

        if outTexture?.width != width || outTexture?.height != height {

            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                      width: width,
                                                                      height: height,
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
        // Stage 1: Apply the effect shader
        //

        let rect = CGRect(x: Double(uniforms.texRect.x),
                          y: Double(uniforms.texRect.y),
                          width: Double(uniforms.texRect.z - uniforms.texRect.x),
                          height: Double(uniforms.texRect.w - uniforms.texRect.y))

        ShaderLibrary.shared.currentShader.apply(commandBuffer: commandBuffer,
                                                 in: inTexture, out: outTexture, rect: rect)

        //
        // Stage 2: (Optional) in-texture blurring
        //

        if animates {

            let radius = Int(9.0 * uniforms.intensity) | 1
            let blur = MPSImageBox(device: device!, kernelWidth: radius, kernelHeight: radius)
            blur.encode(commandBuffer: commandBuffer,
                        inPlaceTexture: &outTexture, fallbackCopyAllocator: nil)
        }

        //
        // Stage 3: Render a full quad on the screen
        //

        guard let renderPass3 = view.currentRenderPassDescriptor else { return }
        renderPass3.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass3) {

            let sampler = animates ? ShaderLibrary.linear : ShaderLibrary.nearest

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(outTexture, index: 0)
            encoder.setFragmentSamplerState(sampler, index: 0)
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
