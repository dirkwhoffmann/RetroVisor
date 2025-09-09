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
 * Stage 1: Cropping and Downsampling
 *
 *          Crops and downsamples the input area. The result is a scaled down
 *          version of the area beneath the effect window, which is then passed
 *          to the effect shader.
 *
 * Stage 2: Main Processing
 *
 *          Applies the CRT effect shader to the input texture. This is the core
 *          rendering stage.
 *
 * Stage 3: Post-Processing (Optional)
 *
 *          Applies a Gaussian-like blur during window animations (i.e., move or
 *          resize) to produce a smoother visual experience.
 *
 * Stage 4: Rendering
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
    var shift: SIMD2<Float>
    var zoom: Float
    var intensity: Float
    var resolution: SIMD2<Float>
    var window: SIMD2<Float>
    var center: SIMD2<Float>
    var mouse: SIMD2<Float>
    var resample: Int32
    var resampleXY: SIMD2<Float>
    var debug: Int32
    var debugMode: Int32
    var debugColor: SIMD3<Float>
    var debugXY: SIMD2<Float>
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
                                 shift: [0, 0],
                                 zoom: 1.0,
                                 intensity: 0.0,
                                 resolution: [0, 0],
                                 window: [0, 0],
                                 center: [0, 0],
                                 mouse: [0, 0],
                                 resample: 0,
                                 resampleXY: [1.0, 1.0],
                                 debug: 0,
                                 debugMode: 0,
                                 debugColor: [0.5, 0.5, 0.5],
                                 debugXY: [0.5, 1.0])

    var textureCache: CVMetalTextureCache!

    // Area of the input texture covered by the effect window
    var texRect: CGRect = .unity

    // Textures
    var src: MTLTexture?    // Source texture from the screen capturer
    var dwn: MTLTexture?    // Cropped and downsampled input texture
    var dst: MTLTexture?    // Destination texture rendered in the effect window

    // Proposed size of the destination texture (picked up in update textures)
    var dstSize: MTLSize?
    
    // Performance shaders
    var resampler: ResampleFilter!
    
    // Animation parameters
    var time: Float = 0.0
    var intensity = Animated<Float>(0.0)
    var animates: Bool { intensity.current > 0 }

    // Zooming and panning
    var shift: SIMD2<Float> = [0, 0] {
        didSet {
            shift.x = min(max(shift.x, 0.0), 1.0 - 1.0 / zoom)
            shift.y = min(max(shift.y, 0.0), 1.0 - 1.0 / zoom)
        }
    }
    var zoom: Float = 1.0 {
        didSet {
            zoom = min(max(zoom, 1.0), 16.0)
        }
    }

    // Maps a [0,1]-coordinate to the zoom/shift area
    func map(coord: SIMD2<Float>, size: NSSize = .unity) -> SIMD2<Float> {
        
        let normalized = SIMD2<Float>(coord.x / Float(size.width),
                                      coord.y / Float(size.height))
        return normalized / zoom + shift
    }
    func map(point: NSPoint, size: NSSize = .unity) -> SIMD2<Float> {
    
        return map(coord: [Float(point.x), Float(point.y)], size: size)
    }
    
    required init(coder: NSCoder) {

        super.init(coder: coder)

        delegate = self
        enableSetNeedsDisplay = true
        framebufferOnly = false
        clearColor = MTLClearColorMake(0, 0, 0, 1)
        colorPixelFormat = .bgra8Unorm
        initMetal()

        resampler = ResampleFilter()
        
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

        texRect = rect ?? .unity
    }

    /*
    func updateTextures(rect: NSRect) {

        updateTextures(width: Int(rect.width), height: Int(rect.height))
    }
*/
    // TODO: Udpate textures in draw
    /*
    func updateTextures(width: Int, height: Int) {

        let width = NSScreen.scaleFactor * width
        let height = NSScreen.scaleFactor * height

        if dst?.width != width || dst?.height != height {

            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                      width: width,
                                                                      height: height,
                                                                      mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]

            dst = device!.makeTexture(descriptor: descriptor)
        }
    }
    */
    
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

            src = CVMetalTextureGetTexture(cvTextureOut!)

            // Trigger the view to redraw
            setNeedsDisplay(bounds)

            // Pass the rendered texture to the recorder
            // TODO: DO THIS IN METAL VIEW ONCE THE TEXTURE HAS BEEN CREATED
            if dst != nil { recorder?.appendVideo(texture: dst!) }
        }
    }

    func updateTextures() {
        
        // Update the input texture if necessary
        if let src = src {
            
            let dwnWidth = Int(Float(src.width) * uniforms.resampleXY.x)
            let dwnHeight = Int(Float(src.height) * uniforms.resampleXY.y)
            
            if dwn?.width != dwnWidth || dwn?.height != dwnHeight {
                
                dwn = dst?.makeTexture(width: dwnWidth, height: dwnHeight)
            }
        }

        // Update the output texture if necessary
        if let dstSize = dstSize {
            
            if dst?.width != dstSize.width || dst?.height != dstSize.height {
                
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                          width: dstSize.width,
                                                                          height: dstSize.width,
                                                                          mipmapped: false)
                descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
                
                dst = device!.makeTexture(descriptor: descriptor)
            }
        }
    }
    
    func draw(in view: MTKView) {

        // Create or update all textures
        updateTextures()

        // Only proceed if all textures are set up
        guard let src = self.src else { return }
        guard let dwn = self.dwn else { return }
        guard var dst = self.dst else { return }

        // Make sure the streamer uses the correct coordinates
        windowController?.streamer.updateRects()

        // Advance the animation parameters
        intensity.move()
        time += 0.01

        // Get the location of the latest mouse down event
        let mouse = trackingWindow.initialMouseLocationNrm ?? .zero

        // Setup uniforms
        uniforms.time = time
        uniforms.zoom = zoom
        uniforms.shift = shift
        uniforms.intensity = intensity.current
        uniforms.resolution = [Float(src.width), Float(src.height)]
        uniforms.window = [Float(trackingWindow.liveFrame.width), Float(trackingWindow.liveFrame.height)]
        uniforms.mouse = [Float(mouse.x), Float(1.0 - mouse.y)]

        // Get the next drawable and create the command buffer
        guard let drawable = view.currentDrawable else { return }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        //
        // Pass 1: Crop and downsample the input image
        //
        
        resampler.type = ResampleFilterType(rawValue: uniforms.resample)!
        resampler.apply(commandBuffer: commandBuffer, in: src, out: dwn, rect: texRect)
 
        //
        // Stage 3: Apply the effect shader
        //

        ShaderLibrary.shared.currentShader.apply(commandBuffer: commandBuffer, in: dwn, out: dst)

        //
        // Stage 3: (Optional) in-texture blurring
        //

        if animates {

            let radius = Int(9.0 * uniforms.intensity) | 1
            let blur = MPSImageBox(device: device!, kernelWidth: radius, kernelHeight: radius)
            blur.encode(commandBuffer: commandBuffer,
                        inPlaceTexture: &dst, fallbackCopyAllocator: nil)
        }

        //
        // Stage 4: Render a full quad on the screen
        //

        guard let renderPass3 = view.currentRenderPassDescriptor else { return }
        renderPass3.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass3) {

            let sampler = animates ? ShaderLibrary.linear : ShaderLibrary.nearest

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(dwn, index: 0)
            encoder.setFragmentTexture(dst, index: 1)
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

        // Get the current mouse position and flip the y coordinate
        var location = recognizer.location(in: self)
        location.y = bounds.height - location.y
        
        // Apply the zoom effect
        let oldLocation = map(point: location, size: bounds.size)
        zoom += Float(recognizer.magnification) * 0.1
        let newLocation = map(point: location, size: bounds.size)

        // Shift the image such that the mouse points to the same pixel again
        shift += oldLocation - newLocation
    }
    
    override func scrollWheel(with event: NSEvent) {
        
        let deltaX = Float(event.scrollingDeltaX) / (2000.0 * zoom)
        let deltaY = Float(event.scrollingDeltaY) / (2000.0 * zoom)
    
        shift = [shift.x - deltaX, shift.y - deltaY]
    }
}
