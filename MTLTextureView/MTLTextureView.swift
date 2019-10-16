//
//  MTLTextureView.swift
//  MTLTextureView
//
//  Created by Andrey Volodin on 05.09.2018.
//  Copyright © 2018 Andrey Volodin. All rights reserved.
//

#if targetEnvironment(simulator)
#else

import Metal
import UIKit

/** Tiny UIView subclass that acts like UIImageView. Can be used to efficiently display contents of MTLTexture. */
// TODO:
// 1. Add internal render-loop
// 2. Support automatic redrawing
@available(swift 4.2)
@available(macOS 10.11, iOS 8.0, *)
public class MTLTextureView: UIView {
    /** A texture to display. Default is nil */
    public var texture: MTLTexture? = nil
    /** The device used to create Metal objects.*/
    public let device: MTLDevice
    
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
    
    fileprivate let renderPassDescriptor = MTLRenderPassDescriptor()
    fileprivate let renderPipelineState: MTLRenderPipelineState
    fileprivate let semaphore = DispatchSemaphore(value: 2)
    
    public init(device: MTLDevice) {
        self.device = device
        self.renderPipelineState = MTLTextureView.makeRenderState(for: device)
        
        super.init(frame: .zero)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.device = MTLCreateSystemDefaultDevice()!
        self.renderPipelineState = MTLTextureView.makeRenderState(for: device)
        
        super.init(coder: aDecoder)
        commonInit()
    }
    
    fileprivate func commonInit() {
        self.layer.device = device
        self.layer.pixelFormat = .bgra8Unorm
        self.layer.framebufferOnly = true
        self.layer.isOpaque = false
        if #available(iOS 11.2, *) {
            self.layer.maximumDrawableCount = 2
        }
        
        self.renderPassDescriptor.colorAttachments[0].loadAction = .clear
        self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        self.backgroundColor = .clear
    }
    
    /** Set the size of the metal drawables when the view is resized. */
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        if autoResizeDrawable {
            var size = self.bounds.size
            size.width *= self.contentScaleFactor
            size.height *= self.contentScaleFactor
            
            self.layer.drawableSize = size
        }
    }
    
    // MARK: Drawing code
    
    /** Encodes render commands into provided command buffer. Does not call 'commit'. */
    public func draw(in commandBuffer: MTLCommandBuffer, fence: MTLFence? = nil) {
        guard let drawable = self.layer.nextDrawable()
            else { return }
        
        self.renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: self.renderPassDescriptor)
            else { return }
        
        if let f = fence {
            renderEncoder.waitForFence(f, before: .fragment)
        }
        
        if let textureToDraw = self.texture {
            renderEncoder.setRenderPipelineState(self.renderPipelineState)
            renderEncoder.setFragmentTexture(textureToDraw, index: 0)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
    }
    
    // MARK: Implementation details
    
    override public var layer: CAMetalLayer {
        return super.layer as! CAMetalLayer
    }
    
    override public class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
}

fileprivate extension MTLTextureView {
    static func makeRenderState(for device: MTLDevice) -> MTLRenderPipelineState {
        let library = try! device.makeDefaultLibrary(bundle: Bundle(for: MTLTextureView.self))
        
        let renderStateDescriptor = MTLRenderPipelineDescriptor()
        renderStateDescriptor.vertexFunction = library.makeFunction(name: "mtlTextureViewVertex")
        renderStateDescriptor.fragmentFunction = library.makeFunction(name: "mtlTextureViewFragment")
        renderStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderStateDescriptor.colorAttachments[0].isBlendingEnabled = false
        
        guard let renderState = try? device.makeRenderPipelineState(descriptor: renderStateDescriptor)
        else { fatalError("Could not initialize render state") }
        return renderState
    }
}

#endif
