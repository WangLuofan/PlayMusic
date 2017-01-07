#import "FeaturedAudioStreamer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CommonCrypto/CommonCrypto.h>
#import <MacErrors.h>

typedef NS_ENUM(NSUInteger, FeaturedAudioStreamerPlayMode) {
    FeaturedAudioStreamerPlayModeLocal,
    FeaturedAudioStreamerPlayModeStream,
};

typedef NS_ENUM(NSUInteger, FeaturedAudioStreamerPlayError) {
    FeaturedAudioStreamerPlayNotError,
    FeaturedAudioStreamerPlayAudioQueueError,
    FeaturedAudioStreamerPlayNetworkError,
    FeaturedAudioStreamerPlayFileOperError,
    FeaturedAudioStreamerPlayFileEOFError,
    FeaturedAudioStreamerPlayCachedError,
    FeaturedAudioStreamerPlayDataParseError,
    FeaturedAudioStreamerPlayReadStreamError,
    FeaturedAudioStreamerPlayUserStoppedError,
};

typedef struct _AudioQueueBufferRef {
    AudioQueueBufferRef internalAudioQueueBufferRef;
    Boolean isBufferUsed;
}_AudioQueueBufferRef;

#define kFeaturedAudioStreamerLocalFileScheme @"file"
#define kSizeOfAudioQueueBuffer 2048
#define kNumberOfAudioQueueBuffer 3
#define kMaxOfStreamPacketDescription 3
#define kAudioFileExtensionDefault @"mp3"
#define kAudioCachedDescFileExtensionDefault @"desc"
#define kAudioFileCacheDirectory [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Audio"]

#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"

@interface FeaturedAudioStreamerCacheSystem ()

@property(nonatomic, strong) NSFileHandle* audioDescFileHandle;
@property(nonatomic, copy) NSURL* audioPathURL;
@property(nonatomic, copy) NSArray* audioCommonFileExtensions;

@end

@implementation FeaturedAudioStreamerCacheSystem

-(instancetype)initWithAudioURL:(NSURL*)audioPathURL {
    self = [super init];
    
    if(self) {
        _audioPathURL = audioPathURL;
        _audioCommonFileExtensions = @[@"mp3", @"ogg", @"wav", @"asf" , @"aiff", @"ape"];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:kAudioFileCacheDirectory] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath:kAudioFileCacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSString* fileExt = nil;
        for (NSString* ext in _audioCommonFileExtensions) {
            if([audioPathURL.absoluteString hasSuffix:ext]) {
                fileExt = ext;
                break;
            }
        }
        
        if(_audioCachedDataFilePath == nil || _audioCachedDataFilePath.length == 0) {
            if(fileExt == nil)
                _audioCachedDataFilePath = [[FeaturedAudioStreamerCacheSystem md5:audioPathURL.absoluteString] stringByAppendingPathExtension:kAudioFileExtensionDefault];
            else
                _audioCachedDataFilePath = [[FeaturedAudioStreamerCacheSystem md5:[audioPathURL.absoluteString substringToIndex:(audioPathURL.absoluteString.length - fileExt.length - 1)]] stringByAppendingPathExtension:fileExt];
            _audioCachedDataFilePath = [kAudioFileCacheDirectory stringByAppendingPathComponent:_audioCachedDataFilePath];
        }
        _audioCachedDescFilePath = [_audioCachedDataFilePath stringByAppendingPathExtension:kAudioCachedDescFileExtensionDefault];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:_audioCachedDescFilePath])
            _audioDescFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:_audioCachedDescFilePath];
    }
    
    return self;
}

-(void)clearCurrentCache {
    if([[NSFileManager defaultManager] fileExistsAtPath:_audioCachedDataFilePath])
        [[NSFileManager defaultManager] removeItemAtPath:_audioCachedDataFilePath error:nil];
    if([[NSFileManager defaultManager] fileExistsAtPath:_audioCachedDescFilePath])
        [[NSFileManager defaultManager] removeItemAtPath:_audioCachedDescFilePath error:nil];
    return ;
}

-(void)clearAllCache {
    BOOL isDict = YES;
    if([[NSFileManager defaultManager] fileExistsAtPath:kAudioFileCacheDirectory isDirectory:&isDict])
        if(isDict == YES)
            [[NSFileManager defaultManager] removeItemAtPath:kAudioFileCacheDirectory error:nil];
    return ;
}

-(BOOL)isCachedFileAlreadyExists {
    return [[NSFileManager defaultManager] fileExistsAtPath:_audioCachedDataFilePath];
}

+(NSString*)md5:(NSString*)str {
    unsigned char md5[16] = {0};
    CC_MD5([str UTF8String], (unsigned int)str.length, md5);
    NSString* md5Str =  [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
                         md5[0], md5[1], md5[2], md5[3],
                         md5[4], md5[5], md5[6], md5[7],
                         md5[8], md5[9], md5[10], md5[11],
                         md5[12], md5[13], md5[14], md5[15]];
    return md5Str;
}

-(NSUInteger)queryDataBytesCachedCountByOffset:(NSUInteger)offset {
    NSUInteger cachedBytes = 0;
    NSUInteger bytesOffset = [_audioDescFileHandle seekToEndOfFile] - offset;
    NSUInteger bytesCanRead = bytesOffset > kSizeOfAudioQueueBuffer ? kSizeOfAudioQueueBuffer : bytesOffset;
    if([_audioDescFileHandle seekToEndOfFile] != offset) {
        [_audioDescFileHandle seekToFileOffset:offset];
        for(int i = 0; i != bytesCanRead; ++i) {
            NSData* fileData = [_audioDescFileHandle readDataOfLength:1];
            if((*((char*)[fileData bytes])) != 0) {
                ++cachedBytes;
                continue;
            }
            
            break;
        }
    }
    return cachedBytes;
}

-(void)finishedAudioCache {
    
    if(_audioDescFileHandle) {
        [_audioDescFileHandle closeFile];
        _audioDescFileHandle = nil;
    }
    
    return ;
}

-(void)markDataCachedWithExpectedBytes:(NSUInteger)bytes offset:(NSUInteger)offset {
    if([_audioDescFileHandle seekToEndOfFile] != offset) {
        [_audioDescFileHandle seekToFileOffset:offset];
        char* data = (char*)malloc(sizeof(char) * bytes);
        memset(data, (char)1, sizeof(char) * bytes);
        [_audioDescFileHandle writeData:[NSData dataWithBytes:data length:bytes]];
        free(data);
    }
    
    return ;
}

-(void)createOrOpenCacheRelatedFileWithFileLength:(NSUInteger)fileLength {
    NSAssert(fileLength != 0, @"The Cahce File's Length Must Greater Than 0.");
    
    if([[NSFileManager defaultManager] fileExistsAtPath:_audioCachedDataFilePath] == NO) {
        char* data = (char*)malloc(sizeof(char) * fileLength);
        memset(data, (char)0, sizeof(char) * fileLength);
        //创建缓存文件
        [[NSFileManager defaultManager] createFileAtPath:_audioCachedDataFilePath contents:[NSData dataWithBytes:data length:fileLength] attributes:@{NSFileSize : [NSNumber numberWithUnsignedInteger:fileLength]}];
        
        //如果缓存文件不存在而描述文件存在，则表示缓存文件与描述文件不匹配，重建描述文件
        if([[NSFileManager defaultManager] fileExistsAtPath:_audioCachedDescFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:_audioCachedDescFilePath error:nil];
        }
        
        [[NSFileManager defaultManager] createFileAtPath:_audioCachedDescFilePath contents:[NSData dataWithBytes:data length:fileLength] attributes:@{NSFileSize : [NSNumber numberWithUnsignedInteger:fileLength]}];
        if(_audioDescFileHandle == nil)
            _audioDescFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:_audioCachedDescFilePath];
        
        free(data);
    }

    return ;
}

@end

@interface FeaturedAudioStreamer () {
    CFReadStreamRef audioDataReadStreamRef;
    AudioFileStreamID audioFileStreamID;
    AudioQueueRef audioQueueRef;
    _AudioQueueBufferRef audioQueueBufferRef[kNumberOfAudioQueueBuffer];
    AudioStreamPacketDescription audioQueuePacketDesc[kMaxOfStreamPacketDescription];
    AudioStreamBasicDescription asbd;
    CFHTTPMessageRef httpResp;
}

@property(nonatomic, assign) FeaturedAudioStreamerPlayMode audioStreamerPlayMode;
@property(nonatomic, copy) NSURL* audioPathURL;
@property(nonatomic, strong) NSThread* audioInternalThread;

@property(nonatomic, strong) NSMutableData* audioStreamData;
@property(nonatomic, strong) NSFileHandle* audioFileHandle;

@property(nonatomic, assign, readonly) BOOL isCacheEnabled;
@property(nonatomic, assign) BOOL isThreadShouldBeExit;
@property(nonatomic, assign) BOOL bDiscontinuity;
@property(nonatomic, assign) FeaturedAudioStreamerPlayState state;
@property(nonatomic, assign) BOOL isPreviousStatePlaying;
@property(nonatomic, assign) FeaturedAudioStreamerPlayError lastError;
@property(nonatomic, assign) UInt64 audioFileTotalLength;
@property(nonatomic, assign) UInt64 audioDataLength;
@property(nonatomic, assign) SInt64 audioDataOffset;
@property(nonatomic, assign) UInt64 audioPacketsTotalCount;
@property(nonatomic, assign) UInt32 audioBitRate;
@property(nonatomic, assign) UInt32 audioDataAlreadyFilledBytes;
@property(nonatomic, assign) UInt32 audioPacketAlreadyFilledCount;
@property(nonatomic, assign) NSInteger audioQueueBufferUsedIndex;

@property(nonatomic, assign) BOOL audioHasSeekRequest;
@property(nonatomic, assign) BOOL audioInternalThraedShouldBeExit;
@property(nonatomic, assign) SInt64 audioSeekOffset;
@property(nonatomic, assign) NSTimeInterval audioSeekToTime;

@property(nonatomic, strong) NSCondition* audioQueueBufferReadyCondition;

@property(nonatomic, strong) FeaturedAudioStreamerCacheSystem* cacheSystem;

@end

@implementation FeaturedAudioStreamer

-(instancetype)initWithAudioURL:(NSURL *)audioURL {
    self = [self initWithAudioURL:audioURL useCache:NO];
    return self;
}

-(instancetype)initWithAudioURL:(NSURL *)audioURL useCache:(BOOL)bUseCache {
    self = [super init];
    if(self) {
        NSAssert(audioURL != nil && audioURL.absoluteString.length != 0, @"Audio File Path or Url MUST BE Specified");
        
        _audioPathURL = audioURL;
        self.audioStreamerPlayMode = FeaturedAudioStreamerPlayModeLocal;
        if([[_audioPathURL.scheme lowercaseString] isEqualToString:kFeaturedAudioStreamerLocalFileScheme]) {
            _isCacheEnabled = NO;
        }
        else {
            _isCacheEnabled = bUseCache;
            
            if(_isCacheEnabled)
                _cacheSystem = [[FeaturedAudioStreamerCacheSystem alloc] initWithAudioURL:audioURL];
        }
        
        _bDiscontinuity = kAudioFileStreamParseFlag_Discontinuity;
        self.lastError = FeaturedAudioStreamerPlayNotError;
    }
    return self;
}

-(void)playORpause {
    OSStatus error = noErr;
    if(_state != FeaturedAudioStreamerPlayStatePlaying) {
        error = AudioQueueStart(audioQueueRef, NULL);
        self.state = FeaturedAudioStreamerPlayStatePlaying;
    }
    else {
        error = AudioQueuePause(audioQueueRef);
        self.state = FeaturedAudioStreamerPlayStatePaused;
    }
    
    if(error != noErr)
        self.lastError = FeaturedAudioStreamerPlayAudioQueueError;
    
    return ;
}

-(double)duration {
    if(_audioBitRate <=0)
        return 0;
    return (double)_audioDataLength * 8 / _audioBitRate;
}

-(double)progress {
    if(audioQueueRef != NULL) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25f, true);
        
        AudioTimeStamp timeStamp;
        OSStatus error = AudioQueueGetCurrentTime(audioQueueRef, NULL, &timeStamp, NULL);
        
//        if(error != noErr)
//            self.lastError = FeaturedAudioStreamerPlayAudioQueueError;
        
        return (double)(timeStamp.mSampleTime / asbd.mSampleRate + _audioSeekToTime);
    }
    
    return 0.0f;
}

-(void)clearCaches {
    [_cacheSystem clearAllCache];
    return ;
}

-(void)startInternal {
    if(_audioStreamerPlayMode == FeaturedAudioStreamerPlayModeStream) {
        if(audioDataReadStreamRef == NULL && (_state == FeaturedAudioStreamerPlayStateInitialized || _state == FeaturedAudioStreamerPlayStateSeeking)) {
            CFHTTPMessageRef httpMessage = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (__bridge CFStringRef)@"GET", (__bridge CFURLRef)_audioPathURL, kCFHTTPVersion1_1);
            
            if(_audioHasSeekRequest) {
                CFHTTPMessageSetHeaderFieldValue(httpMessage, (__bridge CFStringRef)@"Range", (__bridge CFStringRef _Nullable)([NSString stringWithFormat:@"bytes=%lld-", _audioSeekOffset]));
                @synchronized (self) {
                    _audioHasSeekRequest = NO;
                }
            }
            audioDataReadStreamRef = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, httpMessage);
            CFRelease(httpMessage);
            
            CFStreamClientContext clientContext = {0, (__bridge void*)self, NULL, NULL, NULL};
            CFReadStreamSetClient(audioDataReadStreamRef, kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventHasBytesAvailable, CFReadStreamClient_CallBack, &clientContext);
            
            if(CFReadStreamSetProperty(audioDataReadStreamRef, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false) {
                self.lastError = FeaturedAudioStreamerPlayReadStreamError;
                return ;
            }

            CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
            CFReadStreamSetProperty(audioDataReadStreamRef, kCFStreamPropertyHTTPProxy, proxySettings);
            CFRelease(proxySettings);

            if([[_audioPathURL scheme] isEqualToString:@"https"])
            {
                NSDictionary *sslSettings =
                [NSDictionary dictionaryWithObjectsAndKeys:
                 (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
                 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredCertificates,
                 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredRoots,
                 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
                 [NSNumber numberWithBool:NO], kCFStreamSSLValidatesCertificateChain,
                 [NSNull null], kCFStreamSSLPeerName,
                 nil];
                
                CFReadStreamSetProperty(audioDataReadStreamRef, kCFStreamPropertySSLSettings, (__bridge CFTypeRef)sslSettings);
            }
            
            if(CFReadStreamOpen(audioDataReadStreamRef) == false) {
                self.lastError = FeaturedAudioStreamerPlayReadStreamError;
                return ;
            }
            CFReadStreamScheduleWithRunLoop(audioDataReadStreamRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        }
    }else {
        _audioHasSeekRequest = NO;
        if(_audioFileHandle == nil) {
            NSError* error = nil;
            //若使用缓存，则打开缓存文件，否则打开本地文件
            if(_isCacheEnabled == NO)
                _audioFileHandle = [NSFileHandle fileHandleForReadingFromURL:_audioPathURL error:&error];
            else
                _audioFileHandle = [NSFileHandle fileHandleForUpdatingURL:[NSURL fileURLWithPath:_cacheSystem.audioCachedDataFilePath] error:&error];
            
            if(error != nil) {
                if(_isCacheEnabled)
                    self.audioStreamerPlayMode = FeaturedAudioStreamerPlayModeStream;
                else
                    self.lastError = FeaturedAudioStreamerPlayFileOperError;
                return ;
            }
        }
        
        NSData* audioData = nil;
        @synchronized (self) {
            if(_isCacheEnabled == YES) {
                NSUInteger bytesToRead = [_cacheSystem queryDataBytesCachedCountByOffset:_audioFileHandle.offsetInFile];
                audioData = [_audioFileHandle readDataOfLength:bytesToRead];
            }else
                audioData = [_audioFileHandle readDataOfLength:kSizeOfAudioQueueBuffer];
        }
        
        if(audioData) {
            if(audioData.length == 0) {
                if(_audioFileTotalLength == _audioFileHandle.offsetInFile)
                    self.lastError = FeaturedAudioStreamerPlayFileEOFError;
                else {
                    @synchronized (self) {
                        _audioHasSeekRequest = YES;
                        _audioSeekToTime = self.progress;
                        _audioSeekOffset = _audioFileHandle.offsetInFile;
                        _audioStreamerPlayMode = FeaturedAudioStreamerPlayModeStream;
                    }
                }
            }
            else
                [self parseAudioDataWithData:audioData];
        }
        else
            self.lastError = FeaturedAudioStreamerPlayFileOperError;
    }
    return ;
}

-(void)playInternal {
    while(_isThreadShouldBeExit == NO) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25f]];
        
        @synchronized (self) {
            if(_audioHasSeekRequest) {
                [self performSeekInternal];
            }
        }
        
        [self startInternal];
    }

    return ;
}

-(void)setState:(FeaturedAudioStreamerPlayState)state {
    _state = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:FeaturedAudioStreamerStateChangedNotification object:nil userInfo:@{@"State" : [NSNumber numberWithInt:_state]}];
    });
    
    return ;
}

-(void)setLastError:(FeaturedAudioStreamerPlayError)lastError {
    _lastError = lastError;
    
    if(lastError == FeaturedAudioStreamerPlayNotError)
        return ;
    
    AudioQueueFlush(audioQueueRef);
    if(_lastError == FeaturedAudioStreamerPlayNetworkError) {
        [self closeReadStream];
        self.audioStreamerPlayMode = FeaturedAudioStreamerPlayModeLocal;
    }else {
        [self destroyAudioStreamer];
        _isThreadShouldBeExit = YES;
    }
    return ;
}

-(NSString *)GetLastError {
    switch (_lastError) {
        case FeaturedAudioStreamerPlayFileEOFError:
            return @"The Audio File Already Read Complete";
        case FeaturedAudioStreamerPlayNetworkError:
            return @"Please Check Your NETWORK";
        case FeaturedAudioStreamerPlayFileOperError:
            return @"Please Ensure Your Audio File is OKay";
        case FeaturedAudioStreamerPlayDataParseError:
            return @"Unrecognized Audio Data Format";
        case FeaturedAudioStreamerPlayAudioQueueError:
            return @"Audio Queue Callbacks Error";
        case FeaturedAudioStreamerPlayReadStreamError:
            return @"Audio ReadStream Error Occurs";
        default:
            break;
    }
    return nil;
}

-(BOOL)isPlaying {
    return _state == FeaturedAudioStreamerPlayStatePlaying;
}

-(BOOL)isPaused {
    return _state == FeaturedAudioStreamerPlayStatePaused;
}

-(BOOL)isWaiting {
    return _state == FeaturedAudioStreamerPlayStateWaitingForData || _state == FeaturedAudioStreamerPlayStateStopped || _state == FeaturedAudioStreamerPlayStateSeeking;
}

-(BOOL)isStopped {
    return _state == FeaturedAudioStreamerPlayStateStopped && _lastError == FeaturedAudioStreamerPlayUserStoppedError;
}

-(void)play {
    if(_audioInternalThread == nil || _audioInternalThread.isFinished == YES) {
        _audioInternalThread = nil;
        _isThreadShouldBeExit = NO;
        _state = FeaturedAudioStreamerPlayStateInitialized;
        _audioInternalThread = [[NSThread alloc] initWithTarget:self selector:@selector(playInternal) object:nil];
    }
    return _audioInternalThread.isExecuting ? [self playORpause] : [_audioInternalThread start];
}

-(void)stop {
    OSStatus error = AudioQueueStop(audioQueueRef, true);
    self.state = FeaturedAudioStreamerPlayStateStopped;
    if(error != noErr)
        self.lastError = FeaturedAudioStreamerPlayAudioQueueError;
    else
        self.lastError = FeaturedAudioStreamerPlayUserStoppedError;
    return ;
}

-(void)pause {
    [self playORpause];
    return ;
}

-(void)closeReadStream {
    if(audioDataReadStreamRef != NULL) {
        CFReadStreamUnscheduleFromRunLoop(audioDataReadStreamRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFReadStreamClose(audioDataReadStreamRef);
        CFRelease(audioDataReadStreamRef);
        audioDataReadStreamRef = NULL;
    }
    return ;
}

-(void)performSeekInternal {
    [self closeReadStream];
    if(_audioFileHandle != nil)
        [_audioFileHandle seekToFileOffset:(unsigned long long)_audioSeekOffset];
    
    if(audioQueueRef) {
        OSStatus error = AudioQueueStop(audioQueueRef, true);
        _isPreviousStatePlaying = YES;
        self.state = FeaturedAudioStreamerPlayStateSeeking;
        
        if(error != noErr) {
            self.lastError = FeaturedAudioStreamerPlayAudioQueueError;
            return ;
        }
    }
    
    [self startInternal];
    return ;
}

-(void)seek:(NSTimeInterval)time {
    
    //Main Thread
    @synchronized (self) {
        _audioHasSeekRequest = YES;
        if(time <= 0.0f)
            _audioSeekToTime = 0.0f;
        else if(time > self.duration)
            _audioSeekToTime = self.duration;
        else
            _audioSeekToTime = time;
        _bDiscontinuity = kAudioFileStreamParseFlag_Discontinuity;
        
        SInt64 inPacketOffset = (SInt64)(_audioPacketsTotalCount * _audioSeekToTime / self.duration);
        if(inPacketOffset >= 0 && inPacketOffset <= _audioPacketsTotalCount) {
            AudioFileStreamSeekFlags ioStreamSeekFlags;
            OSStatus error = AudioFileStreamSeek(audioFileStreamID, inPacketOffset, &_audioSeekOffset, &ioStreamSeekFlags);
            if(error != noErr)
                self.lastError = FeaturedAudioStreamerPlayDataParseError;
            self.audioStreamerPlayMode = FeaturedAudioStreamerPlayModeLocal;
        }
        
        self.state = FeaturedAudioStreamerPlayStateWaitingForData;
    }
    return ;
}

-(void)parseAudioDataWithData:(NSData*)audioData {
    OSStatus error = noErr;
    if(audioFileStreamID == NULL)
        error = AudioFileStreamOpen((__bridge void*)self, AudioFileStreamPropertyListenerProc, AudioFileStreamPacketsProc, 0, &audioFileStreamID);
    if(audioFileStreamID != NULL)
        error = AudioFileStreamParseBytes(audioFileStreamID, (UInt32)[audioData length], [audioData bytes], _bDiscontinuity);
    
    if(error != noErr)
        self.lastError = FeaturedAudioStreamerPlayDataParseError;
    return ;
}

-(void)createAudioQueue {
    OSStatus error = noErr;
    error = AudioQueueNewOutput(&asbd, AudioQueueOutput_Callback, (__bridge void*)self, NULL, NULL, 0, &audioQueueRef);
    
    for(int i = 0; i != kNumberOfAudioQueueBuffer; ++i) {
        error = AudioQueueAllocateBuffer(audioQueueRef, kSizeOfAudioQueueBuffer, &audioQueueBufferRef[i].internalAudioQueueBufferRef);
        audioQueueBufferRef[i].isBufferUsed = false;
    }
    
    if(error != noErr) {
        self.lastError = FeaturedAudioStreamerPlayAudioQueueError;
        return ;
    }
    
    if(_audioQueueBufferReadyCondition == nil)
        _audioQueueBufferReadyCondition = [[NSCondition alloc] init];
    return ;
}

-(void)destroyAudioStreamer {
    
    if(audioQueueRef != NULL) {
        AudioQueueStop(audioQueueRef, true);
        for(int i = 0; i != kNumberOfAudioQueueBuffer; ++i)
            AudioQueueFreeBuffer(audioQueueRef, audioQueueBufferRef[i].internalAudioQueueBufferRef);
        audioQueueRef = NULL;
    }
    
    if(audioFileStreamID != NULL) {
        AudioFileStreamClose(audioFileStreamID);
        audioFileStreamID = NULL;
    }
    
    if(self.audioStreamerPlayMode == FeaturedAudioStreamerPlayModeLocal) {
        [_audioFileHandle closeFile];
        _audioFileHandle = nil;
    }else {
        [self closeReadStream];
    }
    
    [_cacheSystem finishedAudioCache];
    
    _audioQueueBufferReadyCondition = nil;
    _isThreadShouldBeExit = YES;
    _audioSeekToTime = 0.0f;
    _audioSeekOffset = 0.0f;
    self.state = FeaturedAudioStreamerPlayStateStopped;
    return ;
}

#pragma mark - CFReadStreamClientCallBack
void CFReadStreamClient_CallBack(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    FeaturedAudioStreamer* audioStreamer = (__bridge FeaturedAudioStreamer*)clientCallBackInfo;
    return [audioStreamer CFReadStreamClientCallBack:type];
}

-(void)CFReadStreamClientCallBack:(CFStreamEventType)type {
    switch (type) {
        case kCFStreamEventHasBytesAvailable:
        {
            if(httpResp == NULL) {
                httpResp = (CFHTTPMessageRef)CFReadStreamCopyProperty(audioDataReadStreamRef, kCFStreamPropertyHTTPResponseHeader);
                _audioFileTotalLength = [((__bridge NSString*)CFHTTPMessageCopyHeaderFieldValue(httpResp, (__bridge CFStringRef)@"Content-Length")) integerValue];
                [_cacheSystem createOrOpenCacheRelatedFileWithFileLength:_audioFileTotalLength];
                if(_audioFileHandle == nil)
                    _audioFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:_cacheSystem.audioCachedDataFilePath];
            }
            
            UInt8 audioDataBuffer[kSizeOfAudioQueueBuffer] = {(UInt8)0};
            CFIndex readBytes = CFReadStreamRead(audioDataReadStreamRef, audioDataBuffer, kSizeOfAudioQueueBuffer);
            if(readBytes != -1) {
                NSData* audioData = [NSData dataWithBytes:audioDataBuffer length:(NSUInteger)readBytes];
                if(_isCacheEnabled && _audioFileHandle != nil) {
                    //先标记该部分字节已经下载完成
                    [_cacheSystem markDataCachedWithExpectedBytes:audioData.length offset:_audioFileHandle.offsetInFile];
                    [_audioFileHandle writeData:audioData];
                }
                if(audioData) {
                    [self parseAudioDataWithData:audioData];
                }
            }
        }
            break;
        case kCFStreamEventEndEncountered:
        {
            self.lastError = FeaturedAudioStreamerPlayFileEOFError;
        }
            break;
        case kCFStreamEventErrorOccurred:
        {
            self.lastError = FeaturedAudioStreamerPlayNetworkError;
        }
            break;
        default:
            break;
    }
    return ;
}

#pragma mark - AudioFileStream_PropertyListenerProc
void AudioFileStreamPropertyListenerProc(void *inClientData, AudioFileStreamID inAudioFileStream,AudioFileStreamPropertyID inPropertyID, AudioFileStreamPropertyFlags *ioFlags) {
    FeaturedAudioStreamer* audioStreamer = (__bridge FeaturedAudioStreamer*)inClientData;
    return [audioStreamer AudioFileStreamPropertyListenerProc:inPropertyID ioFlags:ioFlags];
}

-(void)AudioFileStreamPropertyListenerProc:(AudioFileStreamPropertyID)inPropertyID ioFlags:(AudioFileStreamPropertyFlags*)ioFlags {
    @synchronized (self) {
        switch (inPropertyID) {
            case kAudioFileStreamProperty_ReadyToProducePackets:
            {
                _bDiscontinuity = YES;
                if(audioQueueRef == NULL)
                    [self createAudioQueue];
            }
                break;
            case kAudioFileStreamProperty_DataFormat:
            {
                UInt32 ioPropertySize = sizeof(asbd);
                AudioFileStreamGetProperty(audioFileStreamID, inPropertyID, &ioPropertySize, &asbd);
            }
                break;
            case kAudioFileStreamProperty_FormatList:
            {
                Boolean outWriteable;
                UInt32 formatListSize;
                AudioFileStreamGetPropertyInfo(audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
                
                AudioFormatListItem *formatList = malloc(formatListSize);
                AudioFileStreamGetProperty(audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
                
                for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem))
                {
                    AudioStreamBasicDescription pasbd = formatList[i].mASBD;
                    
                    if (pasbd.mFormatID == kAudioFormatMPEG4AAC_HE ||
                        pasbd.mFormatID == kAudioFormatMPEG4AAC_HE_V2)
                    {
                        asbd = pasbd;
                    }
                }
                free(formatList);
            }
                break;
            case kAudioFileStreamProperty_AudioDataByteCount:
            {
                UInt32 ioPropertySize = sizeof(_audioDataLength);
                AudioFileStreamGetProperty(audioFileStreamID, inPropertyID, &ioPropertySize, &_audioDataLength);
                
                _audioFileTotalLength = _audioDataLength + _audioDataOffset;
            }
                break;
            case kAudioFileStreamProperty_AudioDataPacketCount:
            {
                UInt32 ioPropertySize = sizeof(_audioPacketsTotalCount);
                AudioFileStreamGetProperty(audioFileStreamID, inPropertyID, &ioPropertySize, &_audioPacketsTotalCount);
            }
                break;
            case kAudioFileStreamProperty_DataOffset:
            {
                UInt32 ioPropertySize = sizeof(_audioDataOffset);
                AudioFileStreamGetProperty(audioFileStreamID, inPropertyID, &ioPropertySize, &_audioDataOffset);
                
                _audioFileTotalLength = _audioDataLength + _audioDataOffset;
            }
                break;
            case kAudioFileStreamProperty_BitRate:
            {
                UInt32 ioPropertySize = sizeof(_audioBitRate);
                AudioFileStreamGetProperty(audioFileStreamID, inPropertyID, &ioPropertySize, &_audioBitRate);
            }
                break;
            default:
                break;
        }
    }
    return ;
}

#pragma mark - AudioFileStream_PacketsProc
void AudioFileStreamPacketsProc (void *inClientData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions) {
    FeaturedAudioStreamer* audioStreamer = (__bridge FeaturedAudioStreamer*)inClientData;
    return [audioStreamer AudioFileStreamPacketsProc:inNumberBytes inNumberPackets:inNumberPackets inInputData:inInputData inPacketDescriptions:inPacketDescriptions];
}

-(void)AudioFileStreamPacketsProc:(UInt32)inNumberBytes inNumberPackets:(UInt32)inNumberPackets inInputData:(const void*)inInputData inPacketDescriptions:(AudioStreamPacketDescription*)inPacketDescriptions {
        _bDiscontinuity = NO;
        
        for(int i = 0; i != inNumberPackets; ++i) {
            if(inPacketDescriptions[i].mDataByteSize > (kSizeOfAudioQueueBuffer - _audioDataAlreadyFilledBytes)) {
                @synchronized (self) {
                    audioQueueBufferRef[_audioQueueBufferUsedIndex].internalAudioQueueBufferRef->mAudioDataByteSize = _audioDataAlreadyFilledBytes;
                    AudioQueueEnqueueBuffer(audioQueueRef, audioQueueBufferRef[_audioQueueBufferUsedIndex].internalAudioQueueBufferRef, _audioPacketAlreadyFilledCount, audioQueuePacketDesc);
                    
                    _audioDataAlreadyFilledBytes = _audioPacketAlreadyFilledCount = 0;
                    _audioQueueBufferUsedIndex = (++_audioQueueBufferUsedIndex) % kNumberOfAudioQueueBuffer;
                    
                    if(_state == FeaturedAudioStreamerPlayStateWaitingForData || _state == FeaturedAudioStreamerPlayStateInitialized || (_state == FeaturedAudioStreamerPlayStateSeeking && _isPreviousStatePlaying == YES)) {
                        [self play];
                        _isPreviousStatePlaying = NO;
                    }
                }
                
                [_audioQueueBufferReadyCondition lock];
                while(audioQueueBufferRef[_audioQueueBufferUsedIndex].isBufferUsed) {
                    [_audioQueueBufferReadyCondition wait];
                }
                [_audioQueueBufferReadyCondition unlock];
            }
            
            @synchronized (self) {
                audioQueueBufferRef[_audioQueueBufferUsedIndex].isBufferUsed = true;
                memcpy(audioQueueBufferRef[_audioQueueBufferUsedIndex].internalAudioQueueBufferRef->mAudioData + _audioDataAlreadyFilledBytes, inInputData + inPacketDescriptions[i].mStartOffset, inPacketDescriptions[i].mDataByteSize);
                audioQueuePacketDesc[_audioPacketAlreadyFilledCount] = inPacketDescriptions[i];
                audioQueuePacketDesc[_audioPacketAlreadyFilledCount].mStartOffset = _audioDataAlreadyFilledBytes;
                audioQueuePacketDesc[_audioPacketAlreadyFilledCount].mDataByteSize = inPacketDescriptions[i].mDataByteSize;
                _audioDataAlreadyFilledBytes += inPacketDescriptions[i].mDataByteSize;
                ++_audioPacketAlreadyFilledCount;
            }
        }
    return ;
}

#pragma mark - AudioQueueOutputCallback
void AudioQueueOutput_Callback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    FeaturedAudioStreamer* audioStreamer = (__bridge FeaturedAudioStreamer*)inUserData;
    return [audioStreamer AudioQueueOutputCallback:inBuffer];
}

-(void)AudioQueueOutputCallback:(AudioQueueBufferRef)inBuffer {
    [_audioQueueBufferReadyCondition lock];
    for(int i = 0 ; i != kNumberOfAudioQueueBuffer; ++i) {
        if(audioQueueBufferRef[i].internalAudioQueueBufferRef == inBuffer) {
            audioQueueBufferRef[i].isBufferUsed = false;
        }
    }
    [_audioQueueBufferReadyCondition signal];
    [_audioQueueBufferReadyCondition unlock];
    return ;
}

@end
#pragma clang diagnostic pop
