//
//  RDMPEGRenderView.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 03.12.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>

@protocol RDMPEGTextureSampler;
@class RDMPEGVideoFrame;



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRenderView : MTKView

@property (nonatomic, readonly) CGRect videoFrame;
@property (nonatomic, readonly) CGRect aspectFitVideoFrame;
@property (nonatomic, assign, getter=isAspectFillMode) BOOL aspectFillMode;

- (instancetype)initWithFrame:(CGRect)frame
               textureSampler:(id<RDMPEGTextureSampler>)textureSampler
                   frameWidth:(NSUInteger)frameWidth
                  frameHeight:(NSUInteger)frameHeight;

- (void)render:(nullable RDMPEGVideoFrame *)videoFrame;

@end

NS_ASSUME_NONNULL_END
