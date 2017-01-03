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
                           [NSURL URLWithString:@"http://121.42.55.166:8082/javaxieyi/show!play.do?id=20161209161553742a941c7bae90f42560a2&flag=course&sid=05B9E129215141FBF24B5C8C60DFE536&ver=470"]
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
