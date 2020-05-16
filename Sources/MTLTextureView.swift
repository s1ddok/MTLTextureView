#if !targetEnvironment(simulator)

import Metal
import UIKit
import simd

/** Tiny UIView subclass that acts like UIImageView. Can be used to efficiently display contents of MTLTexture. */
// TODO:
// 1. Add internal render-loop
// 2. Support automatic redrawing
@available(macOS 10.11, iOS 8.0, *)
public class MTLTextureView: UIView {

    // MARK: - Type Definitions

    public enum TextureContentMode {
        case resize
        case aspectFill
        case aspectFit
    }

    /** A texture to display. Default is nil */
    public var texture: MTLTexture? = nil {
        didSet {
            if let texture = self.texture,
               oldValue == nil || (texture.width != oldValue!.width || texture.height != oldValue!.height) {
                let textureSize = MTLSize(width: texture.width,
                                          height: texture.height,
                                          depth: 1)
                self.recalculateProjectionMatrix(using: textureSize)
            }
        }
    }
    /** The device used to create Metal objects.*/
    public let device: MTLDevice
    
    public var pixelFormat: MTLPixelFormat {
        get { self.layer.pixelFormat }
        set {
            self.layer.pixelFormat = newValue
            self.updateRenderPipelineState()
        }
    }
    
    public var colorSpace: CGColorSpace? {
        get { self.layer.colorspace }
        set { self.layer.colorspace = newValue }
    }
    
    /** A Boolean value that controls whether to resize the drawable as the view changes size. */
    public var autoResizeDrawable: Bool = true {
        didSet {
            if autoResizeDrawable {
                self.setNeedsLayout()
            }
        }
    }
    
    /** The current size of drawable textures. */
    public var drawableSize: CGSize {
        get { return self.layer.drawableSize }
        set { self.layer.drawableSize = newValue }
    }

    public var textureContentMode: TextureContentMode = .aspectFill {
        didSet {
            if let texture = self.texture,
               self.textureContentMode != oldValue {
                self.recalculateProjectionMatrix(using: .init(width: texture.width,
                                                              height: texture.height,
                                                              depth: 1))
            }
        }
    }
    
    private let renderPassDescriptor = MTLRenderPassDescriptor()
    private var renderPipelineState: MTLRenderPipelineState
    private let semaphore = DispatchSemaphore(value: 2)
    private var projectionMatrix = matrix_identity_float4x4

    // MARK: - Life Cycle
    
    public init(device: MTLDevice,
                pixelFormat: MTLPixelFormat = .bgra8Unorm) {
        self.device = device
        self.renderPipelineState = Self.makeRenderState(for: device,
                                                        pixelFormat: pixelFormat)
        
        super.init(frame: .zero)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.device = MTLCreateSystemDefaultDevice()!
        self.renderPipelineState = Self.makeRenderState(for: self.device,
                                                        pixelFormat: .bgra8Unorm)
        
        super.init(coder: aDecoder)
        self.commonInit()
    }

    /** Set the size of the metal drawables when the view is resized. */
    public override func layoutSubviews() {
        super.layoutSubviews()

        if self.autoResizeDrawable {
            var size = self.bounds.size
            size.width *= self.contentScaleFactor
            size.height *= self.contentScaleFactor

            self.layer.drawableSize = size
        }
    }

    override public var layer: CAMetalLayer {
        return super.layer as! CAMetalLayer
    }

    override public class var layerClass: AnyClass {
        return CAMetalLayer.self
    }

    // MARK: - Setup
    
    private func commonInit() {
        self.layer.device = self.device
        self.layer.framebufferOnly = true
        self.layer.isOpaque = false
        if #available(iOS 11.2, *) {
            self.layer.maximumDrawableCount = 2
        }
        
        self.renderPassDescriptor.colorAttachments[0].loadAction = .clear
        self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        self.backgroundColor = .clear
    }
    
    public func updateRenderPipelineState() {
        self.renderPipelineState = Self.makeRenderState(for: self.device,
                                                        pixelFormat: self.layer.pixelFormat)
    }

    // MARK: - Helpers

    private func recalculateProjectionMatrix(using textureSize: MTLSize) {
        let drawableAspectRatio: Float = .init(self.layer.drawableSize.width)
                                       / .init(self.layer.drawableSize.height)
        let textureAspectRatio: Float = .init(textureSize.width)
                                      / .init(textureSize.height)
        let normalizationValue = drawableAspectRatio / textureAspectRatio

        var normlizedTextureWidth: Float
        var normlizedTextureHeight: Float

        switch self.textureContentMode {
        case .resize:
            normlizedTextureWidth = 1.0
            normlizedTextureHeight = 1.0
        case .aspectFill:
            normlizedTextureWidth = normalizationValue < 1.0
                                                       ? 1.0 / normalizationValue
                                                       : 1.0
            normlizedTextureHeight = normalizationValue < 1.0
                                                       ? 1.0
                                                       : normalizationValue
        case .aspectFit:
            normlizedTextureWidth = normalizationValue > 1.0
                                                       ? 1 / normalizationValue
                                                       : 1.0
            normlizedTextureHeight = normalizationValue > 1.0
                                                        ? 1.0
                                                        : normalizationValue
        }

        self.projectionMatrix[0][0] = normlizedTextureWidth
        self.projectionMatrix[1][1] = normlizedTextureHeight
    }

    private func normlizedTextureSize(from textureSize: MTLSize) -> SIMD2<Float> {
        let drawableAspectRatio: Float = .init(self.layer.drawableSize.width)
                                       / .init(self.layer.drawableSize.height)
        let textureAspectRatio: Float = .init(textureSize.width)
                                      / .init(textureSize.height)
        let normlizedTextureWidth = drawableAspectRatio < textureAspectRatio
                                  ? 1.0
                                  : drawableAspectRatio / textureAspectRatio
        let normlizedTextureHeight = drawableAspectRatio > textureAspectRatio
                                   ? 1.0
                                   : drawableAspectRatio / textureAspectRatio
        return .init(x: normlizedTextureWidth,
                     y: normlizedTextureHeight)
    }
    
    // MARK: Draw

    /// Draw a texture
    ///
    /// - Note: This method should be called on main thread only.
    ///
    /// - Parameters:
    ///   - texture: texture to draw
    ///   - additionalRenderCommands: render commands to execute after texture draw.
    ///   - commandBuffer: command buffer to put the work in.
    ///   - fence: metal fence.
    public func draw(additionalRenderCommands: ((MTLRenderCommandEncoder) -> Void)? = nil,
                     in commandBuffer: MTLCommandBuffer,
                     fence: MTLFence? = nil) {
        guard let texture = self.texture,
              let drawable = self.layer.nextDrawable()
        else { return }

        self.renderPassDescriptor.colorAttachments[0].texture = drawable.texture

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: self.renderPassDescriptor)
        else { return }

        self.draw(texture: texture,
                  in: drawable,
                  additionalRenderCommands: additionalRenderCommands,
                  using: renderEncoder,
                  fence: fence)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
    }

    private func draw(texture: MTLTexture,
                      in drawable: CAMetalDrawable,
                      additionalRenderCommands: ((MTLRenderCommandEncoder) -> Void)? = nil,
                      using renderEncoder: MTLRenderCommandEncoder,
                      fence: MTLFence? = nil) {
        if let f = fence {
            renderEncoder.waitForFence(f, before: .fragment)
        }

        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(self.renderPipelineState)

        renderEncoder.setVertexBytes(&self.projectionMatrix,
                                     length: MemoryLayout<simd_float4x4>.stride,
                                     index: 0)

        renderEncoder.setFragmentTexture(texture,
                                         index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip,
                                     vertexStart: 0,
                                     vertexCount: 4)

        additionalRenderCommands?(renderEncoder)
    }

    // MARK - Pipeline State Init

    private static func makeRenderState(for device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState {
        let library = try! device.makeDefaultLibrary(bundle: Bundle(for: Self.self))

        let renderStateDescriptor = MTLRenderPipelineDescriptor()
        renderStateDescriptor.label = "MTLTextureView"
        renderStateDescriptor.vertexFunction = library.makeFunction(name: "vertexFunction")
        renderStateDescriptor.fragmentFunction = library.makeFunction(name: "fragmentFunction")
        renderStateDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderStateDescriptor.colorAttachments[0].isBlendingEnabled = false

        guard let renderState = try? device.makeRenderPipelineState(descriptor: renderStateDescriptor)
        else { fatalError("Could not initialize render state") }
        return renderState
    }

}

#endif
