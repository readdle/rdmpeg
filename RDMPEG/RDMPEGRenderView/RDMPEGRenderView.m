//
//  RDMPEGRenderView.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 03.12.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "RDMPEGRenderView.h"
#import "RDMPEGRenderer.h"
#import "RDMPEGShaderTypes.h"
#import "RDMPEGFrames.h"
#import <Metal/Metal.h>
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRenderView ()

@property (nonatomic, readonly) NSUInteger frameWidth;
@property (nonatomic, readonly) NSUInteger frameHeight;
@property (nonatomic, readonly) id<RDMPEGRenderer> renderer;
@property (nonatomic, readonly) CAMetalLayer *metalLayer;
@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLBuffer> vertexBuffer;
@property (nonatomic, readonly) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, readonly) id<MTLCommandQueue> commandQueue;

@end



@implementation RDMPEGRenderView

#pragma mark - Overridden Class Methods

+ (Class)layerClass {
    return [CAMetalLayer class];
}

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGRenderView"];
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
                     renderer:(id<RDMPEGRenderer>)renderer
                   frameWidth:(NSUInteger)frameWidth
                  frameHeight:(NSUInteger)frameHeight
{
    self = [super initWithFrame:frame];
    
    if (nil == self) {
        return nil;
    }
    
    self.contentMode = UIViewContentModeScaleAspectFit;
    
    _renderer = renderer;
    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    
    _device = MTLCreateSystemDefaultDevice();
    
    self.metalLayer.device = self.device;
    self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalLayer.framebufferOnly = YES;
    
    [self updateVertices];
    
    id<MTLLibrary> const defaultLibrary = [self.device newDefaultLibrary];
    
    MTLRenderPipelineDescriptor * const pipelineStateDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineStateDescriptor.vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    pipelineStateDescriptor.fragmentFunction = [self.renderer newSamplingFunctionFromLibrary:defaultLibrary];
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    // TODO: SA CHECK - handle errors
    NSError *renderPipelineError = nil;
    _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&renderPipelineError];
    
    _commandQueue = [self.device newCommandQueue];
    
    return self;
}

#pragma mark - Overridden

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.metalLayer.drawableSize = CGSizeMake(CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale,
                                              CGRectGetHeight(self.bounds) * [UIScreen mainScreen].scale);
    
    [self updateVertices];
}

#pragma mark - Public Accessors

- (CAMetalLayer *)metalLayer {
    return (CAMetalLayer *)self.layer;
}

- (CGRect)videoFrame {
    return self.isAspectFillMode ? self.bounds : self.aspectFitVideoFrame;
}

- (void)setAspectFillMode:(BOOL)aspectFillMode {
    if (_aspectFillMode == aspectFillMode) {
        return;
    }
    
    _aspectFillMode = aspectFillMode;
    
    [self updateView];
}

- (void)updateView{
    [self updateVertices];
//    if (self.renderer.isValid) {
//        [self render:nil];
//    }
}

#pragma mark - Public Methods

- (void)render:(nullable RDMPEGVideoFrame *)videoFrame {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }
    
    id<CAMetalDrawable> const drawable = self.metalLayer.nextDrawable;
    
    if (nil == drawable) {
        return;
    }
    
    id<MTLCommandBuffer> const commandBuffer = [self.commandQueue commandBuffer];
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
//    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    MTLRenderPassDescriptor * const renderPassDescriptor = [MTLRenderPassDescriptor new];
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

    if(renderPassDescriptor != nil)
    {
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        MTLViewport viewport;
        viewport.originX = 0.0;
        viewport.originY = 0.0;
        viewport.width = CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale;
        viewport.height = CGRectGetHeight(self.bounds) * [UIScreen mainScreen].scale;
        viewport.znear = -1.0;
        viewport.zfar = 1.0;
        
        [renderEncoder setViewport:viewport];

        [renderEncoder setRenderPipelineState:_pipelineState];
        
        [renderEncoder setVertexBuffer:self.vertexBuffer
                                offset:0
                               atIndex:RDMPEGVertexInputIndexVertices];
        
        vector_uint2 viewportSize;
        viewportSize.x = (unsigned int)viewport.width;
        viewportSize.y = (unsigned int)viewport.height;
        
        [renderEncoder setVertexBytes:&viewportSize
                               length:sizeof(viewportSize)
                              atIndex:RDMPEGVertexInputIndexViewportSize];

        [self.renderer
         updateTexturesWithFrame:videoFrame
         device:self.device
         renderEncoder:renderEncoder];
        
        // Draw the triangles.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];

        [renderEncoder endEncoding];
    }
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void)updateVertices {
    const double xScale = CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale / self.frameWidth;
    const double yScale = CGRectGetHeight(self.bounds) * [UIScreen mainScreen].scale / self.frameHeight;
    const double minScale = MIN(xScale, yScale);
    const double maxScale = MAX(xScale, yScale);
    const double scale = self.isAspectFillMode ? maxScale : minScale;
    
    const double halfWidth = self.frameWidth / 2.0;
    const double halfHeight = self.frameHeight / 2.0;
    
    const double adjustedWidth = halfWidth * scale;
    const double adjustedHeight = halfHeight * scale;
    
    const RDMPEGVertex quadVertices[] = {
        // Pixel positions, Texture coordinates
        { {  adjustedWidth,  -adjustedHeight },  { 1.f, 1.f } },
        { { -adjustedWidth,  -adjustedHeight },  { 0.f, 1.f } },
        { { -adjustedWidth,   adjustedHeight },  { 0.f, 0.f } },

        { {  adjustedWidth,  -adjustedHeight },  { 1.f, 1.f } },
        { { -adjustedWidth,   adjustedHeight },  { 0.f, 0.f } },
        { {  adjustedWidth,   adjustedHeight },  { 1.f, 0.f } },
    };
    
    _vertexBuffer =
    [self.device
     newBufferWithBytes:quadVertices
     length:sizeof(quadVertices)
     options:MTLResourceStorageModeShared];
}

@end

NS_ASSUME_NONNULL_END
