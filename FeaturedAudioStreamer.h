//
//  FeaturedAudioStreamer.h
//  PlayMusic
//
//  Created by 王落凡 on 2016/12/28.
//  Copyright © 2016年 王落凡. All rights reserved.
//

#import <Foundation/Foundation.h>

#define FeaturedAudioStreamerStateChangedNotification @"FeaturedAudioStreamerStateChangedNotification"

typedef NS_ENUM(NSUInteger, FeaturedAudioStreamerPlayState) {
    FeaturedAudioStreamerPlayStateInitialized,
    FeaturedAudioStreamerPlayStatePlaying,
    FeaturedAudioStreamerPlayStateWaitingForData,
    FeaturedAudioStreamerPlayStatePaused,
    FeaturedAudioStreamerPlayStateStopped,
    FeaturedAudioStreamerPlayStateSeeking,
};

@interface FeaturedAudioStreamerCacheSystem : NSObject

@property(nonatomic, copy) NSString* audioCachedDataFilePath;
@property(nonatomic, copy) NSString* audioCachedDescFilePath;

-(NSUInteger)queryDataBytesCachedCountByOffset:(NSUInteger)offset;
-(void)createOrOpenCacheRelatedFileWithFileLength:(NSUInteger)fileLength;
-(BOOL)isCachedFileAlreadyExists;
-(void)markDataCachedWithExpectedBytes:(NSUInteger)bytes offset:(NSUInteger)offset;
-(void)finishedAudioCache;
-(void)clearCurrentCache;
-(void)clearAllCache;

@end

@interface FeaturedAudioStreamer : NSObject

@property(nonatomic, assign, readonly) double duration;
@property(nonatomic, assign, readonly) double progress;
@property(nonatomic, assign, readonly) BOOL isPlaying;
@property(nonatomic, assign, readonly) BOOL isPaused;
@property(nonatomic, assign, readonly) BOOL isStopped;
@property(nonatomic, assign, readonly) BOOL isWaiting;

-(instancetype)initWithAudioURL:(NSURL*)audioURL;
-(instancetype)initWithAudioURL:(NSURL *)audioURL useCache:(BOOL)bUseCache;

-(void)play;
-(void)pause;
-(void)stop;
-(void)seek:(NSTimeInterval)time;
-(NSString*)GetLastError;

-(void)destroyAudioStreamer;

@end
