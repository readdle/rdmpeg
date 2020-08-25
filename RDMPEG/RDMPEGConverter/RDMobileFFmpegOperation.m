//
//  RDMobileFFmpegOperation.m
//  RDMPEG
//
//  Created by Artem on 24.08.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "RDMobileFFmpegOperation.h"
#import <MobileFFmpeg.h>
#import <MobileFFmpegConfig.h>
#include <libavformat/avformat.h>
#import <Log4Cocoa/Log4Cocoa.h>

@interface RDMobileFFmpegOperation()<StatisticsDelegate,LogDelegate>

@property (nonatomic,strong)NSArray<NSString *> *arguments;
@property (nonatomic,copy)RDMobileFFmpegOperationResultBlock resultBlock;
@property (nonatomic,copy)RDMobileFFmpegOperationStatisticsBlock statisticsBlock;

@end


@implementation RDMobileFFmpegOperation

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments
                  statisticsBlock:(RDMobileFFmpegOperationStatisticsBlock)statisticsBlock
                      resultBlock:(RDMobileFFmpegOperationResultBlock)resultBlock{
    NSParameterAssert(arguments);
    if(arguments == nil){
        return nil;
    }
    self = [super init];
    if(self){
        [MobileFFmpegConfig setStatisticsDelegate:self];
        [MobileFFmpegConfig setLogDelegate:self];
        [MobileFFmpegConfig enableRedirection];
        self.arguments = arguments;
        self.resultBlock = resultBlock;
        self.statisticsBlock = statisticsBlock;
    }
    return self;
}

- (void)logCallback:(long)executionId :(int)level :(NSString*)message{
    log4Debug(@"level: %@, message: %@",@(level),message);
}

- (void)statisticsCallback:(Statistics *)statistics{
    if(self.statisticsBlock){
        self.statisticsBlock(statistics);
    }
}

- (void)main {
    [MobileFFmpegConfig resetStatistics];
    int result = [MobileFFmpeg executeWithArguments:self.arguments];
    if(self.resultBlock){
        self.resultBlock(result);
    }
}

- (void)cancel{
    [super cancel];
    [MobileFFmpeg cancel];
}

+ (BOOL)isReturnCodeCancel:(int)code{
    return code == RETURN_CODE_CANCEL;
}

+ (BOOL)isReturnCodeSuccess:(int)code{
    return code == RETURN_CODE_SUCCESS;
}

@end