//
//  RDMobileFFmpegOperation.h
//  RDMPEG
//
//  Created by Artem on 24.08.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Statistics;

NS_ASSUME_NONNULL_BEGIN

typedef void(^RDMobileFFmpegOperationStatisticsBlock)(Statistics * _Nonnull statistics);
typedef void(^RDMobileFFmpegOperationResultBlock)(int result);

//to build mobile-ffmpeg:
//mobile-ffmpeg ./ios.sh --enable-lame

@interface RDMobileFFmpegOperation : NSOperation

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments
                  statisticsBlock:(RDMobileFFmpegOperationStatisticsBlock)statisticsBlock
                      resultBlock:(RDMobileFFmpegOperationResultBlock)resultBlock;

+ (BOOL)isReturnCodeCancel:(int)code;

+ (BOOL)isReturnCodeSuccess:(int)code;

@end

NS_ASSUME_NONNULL_END
