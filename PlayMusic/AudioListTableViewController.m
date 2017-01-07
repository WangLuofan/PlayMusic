//
//  AudioListTableViewController.m
//  PlayMusic
//
//  Created by 王落凡 on 2017/1/3.
//  Copyright © 2017年 王落凡. All rights reserved.
//

#import "AudioListTableViewController.h"
#import "AudioPlayerViewController.h"

@interface AudioListTableViewController ()

@property(nonatomic, copy) NSArray* audioPathURLs;

@end

@implementation AudioListTableViewController

-(void)viewDidLoad {
    [super viewDidLoad];
    
    self.audioPathURLs = @[[[NSBundle mainBundle] URLForResource:@"遥远的她" withExtension:@"mp3"],
                           [[NSBundle mainBundle] URLForResource:@"最佳损友" withExtension:@"mp3"],
                           [NSURL URLWithString:@"http://116.62.38.142:8082/gwxieyi/show!play.do?id=201701061004470504bd3b22d7c0e47a7f23&flag=course&sid=79D96EBF8D15DF3967C794D7C4B988EC&ver=470"]
                           ];
    
    return ;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AudioPlayerViewController* audioPlayerController = (AudioPlayerViewController*)[[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"AudioPlayerViewController"];
    audioPlayerController.audioPathURL = (NSURL*)[self.audioPathURLs objectAtIndex:indexPath.row];
    
    [self.navigationController pushViewController:audioPlayerController animated:YES];
    
    return ;
}

@end
