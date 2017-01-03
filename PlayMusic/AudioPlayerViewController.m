//
//  ViewController.m
//  PlayMusic
//
//  Created by 王落凡 on 2016/12/28.
//  Copyright © 2016年 王落凡. All rights reserved.
//

#import "AudioPlayerViewController.h"
#import "FeaturedAudioStreamer.h"

#define PERFORMONMAINTHREAD(codes) do { \
            dispatch_async(dispatch_get_main_queue(), ^{ \
                codes \
            }); \
    }while(0)

#define PERFORMONMAINTHREADDELAY(codes, delay) do {\
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),  \dispatch_get_main_queue(), ^{ \
                codes \
            }); \
        }while(0)

@interface AudioPlayerViewController ()

@property(nonatomic, strong) FeaturedAudioStreamer* audioStreamer;
@property (weak, nonatomic) IBOutlet UIImageView *audioDiskImageView;
@property (weak, nonatomic) IBOutlet UIImageView *audioLoadingImageView;
@property (weak, nonatomic) IBOutlet UILabel *curMediaTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *tolMediaTimeLabel;
@property (weak, nonatomic) IBOutlet UISlider *audioProgressSlider;
@property (weak, nonatomic) IBOutlet UIButton *audioPlayButton;
@property (weak, nonatomic) IBOutlet UIButton *audioBackwardButton;
@property (weak, nonatomic) IBOutlet UIButton *audioForwardButton;

@property(nonatomic, strong) NSTimer* audioProgressTimer;
@property(nonatomic, strong) CADisplayLink* audioDisplayLink;

@end

@implementation AudioPlayerViewController

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    [self.navigationController.navigationBar setShadowImage:[UIImage new]];
    
    return ;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.audioStreamer = [[FeaturedAudioStreamer alloc] initWithAudioURL:self.audioPathURL useCache:YES];
    [self.audioProgressSlider setThumbImage:[UIImage imageNamed:@"audio_progress"] forState:UIControlStateNormal];
    
    CABasicAnimation* rotateAnimation = [CABasicAnimation animation];
    rotateAnimation.keyPath = @"transform.rotation";
    rotateAnimation.fromValue = [NSNumber numberWithDouble:0];
    rotateAnimation.toValue = [NSNumber numberWithDouble:M_PI * 2];
    rotateAnimation.repeatCount = HUGE_VALF;
    rotateAnimation.speed = 1.0f;
    rotateAnimation.duration = 5.0f;
    [self.audioLoadingImageView.layer addAnimation:rotateAnimation forKey:nil];
    
    self.audioDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(rotate)];
    [self.audioDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stateChanged:) name:FeaturedAudioStreamerStateChangedNotification object:nil];
    return ;
}

-(void)stateChanged:(NSNotification*)notification {
    FeaturedAudioStreamerPlayState state = (FeaturedAudioStreamerPlayState)[notification.userInfo[@"State"] unsignedIntegerValue];
    
    switch (state) {
        case FeaturedAudioStreamerPlayStatePlaying:
        {
            _audioLoadingImageView.hidden = YES;
            [_audioDisplayLink setPaused:NO];
            _audioProgressSlider.enabled = _audioBackwardButton.enabled = _audioForwardButton.enabled = YES;
        }
            break;
        case FeaturedAudioStreamerPlayStateStopped:
        {
            _audioProgressSlider.enabled = _audioBackwardButton.enabled = _audioForwardButton.enabled = NO;
            [_audioPlayButton setBackgroundImage:[UIImage imageNamed:@"audio_play_n"] forState:UIControlStateNormal];
            [_audioPlayButton setBackgroundImage:[UIImage imageNamed:@"audio_play_h"] forState:UIControlStateHighlighted];
            _audioProgressSlider.value = 0.0f;
            [_audioProgressTimer invalidate];
            _audioProgressTimer = nil;
            
            [_audioDisplayLink setPaused:YES];
        }
        case FeaturedAudioStreamerPlayStateWaitingForData:
        {
            [_audioDisplayLink setPaused:YES];
            _audioLoadingImageView.hidden = NO;
        }
            break;
        case FeaturedAudioStreamerPlayStatePaused:
        {
            [_audioDisplayLink setPaused:YES];
        }
        default:
            break;
    }
    
    return ;
}

-(void)rotate {
    CGAffineTransform transform = self.audioDiskImageView.transform;
    self.audioDiskImageView.transform = CGAffineTransformRotate(transform, M_PI / 100);
    return ;
}

-(NSString*)toMinute:(CGFloat)second {
    return [NSString stringWithFormat:@"%02d:%02d", (int)(second / 60), (int)(fmod(second, 60.0f))];
}

-(void)update {
    PERFORMONMAINTHREAD({
        if(self.audioStreamer.isPlaying) {
            self.audioProgressSlider.maximumValue = self.audioStreamer.duration;
            self.audioProgressSlider.value = self.audioStreamer.progress;
            self.curMediaTimeLabel.text = [self toMinute:self.audioProgressSlider.value];
            self.tolMediaTimeLabel.text = [self toMinute:self.audioStreamer.duration];
        }
    });
    return ;
}

- (IBAction)play:(UIButton *)sender {
    if(![self.audioStreamer isPlaying]) {
        [sender setBackgroundImage:[UIImage imageNamed:@"audio_pause_n"] forState:UIControlStateNormal];
        [sender setBackgroundImage:[UIImage imageNamed:@"audio_pause_h"] forState:UIControlStateHighlighted];
        
        if(self.audioProgressTimer == nil)
            self.audioProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(update) userInfo:nil repeats:YES];
        else
            [self.audioProgressTimer setFireDate:[NSDate date]];
        
        [self.audioStreamer play];
        
    }else {
        [sender setBackgroundImage:[UIImage imageNamed:@"audio_play_n"] forState:UIControlStateNormal];
        [sender setBackgroundImage:[UIImage imageNamed:@"audio_play_h"] forState:UIControlStateHighlighted];
        
        if(self.audioProgressTimer != nil)
            [self.audioProgressTimer setFireDate:[NSDate distantFuture]];
        
        [self.audioStreamer pause];
    }
    
    return ;
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.audioStreamer destroyAudioStreamer];
    
    [_audioProgressTimer invalidate];
    _audioProgressTimer = nil;
    
    [_audioDisplayLink invalidate];
    [_audioDisplayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    _audioDisplayLink = nil;
    return ;
}

- (IBAction)forawrd:(UIButton *)sender {
    [self.audioProgressTimer setFireDate:[NSDate distantFuture]];
    [self.audioStreamer seek:self.audioStreamer.progress + 5.0f];
    [self.audioProgressTimer setFireDate:[NSDate date]];
    
    return ;
}

- (IBAction)backward:(UIButton *)sender {
    [self.audioProgressTimer setFireDate:[NSDate distantFuture]];
    [self.audioStreamer seek:self.audioStreamer.progress - 5.0f];
    [self.audioProgressTimer setFireDate:[NSDate date]];
    
    return ;
}

//UIControlEventTouchDown
- (IBAction)sliderWillChangeValue:(UISlider *)sender {
    [self.audioProgressTimer setFireDate:[NSDate distantFuture]];
    return ;
}

//UIControlEventValueChanged
- (IBAction)sliderChangingValue:(UISlider *)sender {
    self.curMediaTimeLabel.text = [self toMinute:sender.value];
    return ;
}

//UIControlEventTouchUpInside
- (IBAction)sliderDidChangeValue:(UISlider *)sender {
    [self.audioStreamer seek:sender.value];
    [self.audioProgressTimer setFireDate:[NSDate date]];
    return ;
}

@end
