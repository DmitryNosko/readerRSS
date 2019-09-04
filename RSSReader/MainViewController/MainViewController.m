//
//  MainViewController.m
//  RSSReader
//
//  Created by Dzmitry Noska on 8/26/19.
//  Copyright © 2019 Dzmitry Noska. All rights reserved.
//

#import "MainViewController.h"
#import "WebViewController.h"
#import "MainTableViewCell.h"
#import "DetailsViewController.h"
#import "FeedItem.h"
#import "RSSParser.h"
#import "MenuViewController.h"
#import "FeedResource.h"
#import "FileManager.h"
#import "ReachabilityStatusChecker.h"

@interface MainViewController () <UITableViewDataSource, UITableViewDelegate, MainTableViewCellListener, WebViewControllerListener>
@property (strong, nonatomic) UITableView* tableView;
@property (strong, nonatomic) NSMutableArray<FeedItem *>* feeds;
@property (strong, nonatomic) RSSParser* rssParser;
@property (strong, nonatomic) FeedItem* feedItem;
@property (strong, nonatomic) FeedResource* feedResource;
@property (strong, nonatomic) NSIndexPath* indexPath;//todo rename
@property (strong, nonatomic) NSMutableArray<NSString *>* readedItemsLinks;
@property (strong, nonatomic) NSMutableArray<NSString *>* readingInProgressItemsLinks;
@end

static NSString* CELL_IDENTIFIER = @"Cell";
static NSString* PATTERN_FOR_VALIDATION = @"<\/?[A-Za-z]+[^>]*>";
static NSString* URL_TO_PARSE = @"https://news.tut.by/rss/index.rss";
static NSString* FAVORITES_NEWS_FILE_NIME = @"FAVORITES1.txt";
static NSString* TUT_BY_NEWS_FILE_NAME = @"tutbyyyede";
static NSString* TXT_FORMAT_NAME = @".txt";
static NSString* READED_NEWS = @"readingCompletee.txt";//rename to readingCompleteNews
static NSString* READING_IN_PROGRESS = @"readingInProgresss.txt";

@implementation MainViewController

@synthesize listenedItem = _listenedItem;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self configureNavigationBar];
    [self tableViewSetUp];
    
    self.feeds = [[NSMutableArray alloc] init];
    self.readedItemsLinks = [[FileManager sharedFileManager] readStringsFromFile:READED_NEWS];
    self.readingInProgressItemsLinks = [[FileManager sharedFileManager] readStringsFromFile:READING_IN_PROGRESS];
    
    self.feedResource = [[FeedResource alloc] initWithName:TUT_BY_NEWS_FILE_NAME url:[NSURL URLWithString:URL_TO_PARSE]];
    
    self.rssParser = [[RSSParser alloc] init];
    
    __weak MainViewController* weakSelf = self;
    self.rssParser.feedItemDownloadedHandler = ^(FeedItem *item) {
        [weakSelf performSelectorOnMainThread:@selector(addFeedItemToFeeds:) withObject:item waitUntilDone:NO];
    };
    
    if ([ReachabilityStatusChecker hasInternerConnection]) {
        [self.rssParser rssParseWithURL:[NSURL URLWithString:URL_TO_PARSE]];
    } else {
        [self showNotInternerConnectionAlert];
        self.feeds = [[FileManager sharedFileManager] readFeedItemsFile:[NSString stringWithFormat:@"%@%@", TUT_BY_NEWS_FILE_NAME, TXT_FORMAT_NAME]];
    }
    

    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(feedResourceWasAddedNotification:)
                                                 name:MenuViewControllerFeedResourceWasAddedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(feedResourceWasChosenNotification:)
                                                 name:MenuViewControllerFeedResourceWasChosenNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemsLoaded:)
                                                 name:RSSParserItemsWasLoadedNotification
                                               object:nil];
    
    //    self.rssParser.feedItemsWasDownloadedHandler = ^(NSMutableArray<FeedItem *> *items) {
    //        [weakSelf performSelector:@selector(isDatsd:) withObject:items];
    //    };
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) handlemenuToggle {
    [self.delegate handleMenuToggle];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.feeds count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MainTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER forIndexPath:indexPath];
    cell.listener = self;
    cell.titleLabel.text = [self.feeds objectAtIndex:indexPath.row].itemTitle;
    
    FeedItem* item = [self.feeds objectAtIndex:indexPath.row];
    
    //item.isReaded = [self.readingInProgressItemsLinks containsObject:item.link];
    if (item.isReaded) {
        cell.stateLabel.text = @"readind";
    }
    
    if (item.isFavorite) {
        [cell.favoritesButton setImage:[UIImage imageNamed:@"fullStar"] forState:UIControlStateNormal];
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([ReachabilityStatusChecker hasInternerConnection]) {
        FeedItem* item = [self.feeds objectAtIndex:indexPath.row];
        item.isReaded = YES;
        NSThread* thread = [[NSThread alloc] initWithBlock:^{
            //[[FileManager sharedFileManager] saveString:item.link toFile:READING_IN_PROGRESS];
            [[FileManager sharedFileManager] updateFeedItem:item atIndex:indexPath.row inFile:[NSString stringWithFormat:@"%@%@", self.feedResource.name, TXT_FORMAT_NAME]];
        }];
        [thread start];
        self.listenedItem = item;
        
        WebViewController* dvc = [[WebViewController alloc] init];
        dvc.listener = self;
        self.indexPath = indexPath;
        NSString* string = [self.feeds objectAtIndex:indexPath.row].link;
        NSString *stringForURL = [string substringWithRange:NSMakeRange(0, [string length]-6)];
        NSURL* url = [NSURL URLWithString:stringForURL];
        dvc.newsURL = url;
        [self.navigationController pushViewController:dvc animated:YES];
    } else {
        [self showNotInternerConnectionAlert];
    }
    
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 80.f;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return UITableViewAutomaticDimension;
}

- (NSString*) correctDescription:(NSString *) string {
    NSRegularExpression* regularExpression = [NSRegularExpression regularExpressionWithPattern:PATTERN_FOR_VALIDATION
                                                                                       options:NSRegularExpressionCaseInsensitive
                                                                                         error:nil];
    string = [regularExpression stringByReplacingMatchesInString:string
                                                         options:0
                                                           range:NSMakeRange(0, [string length])
                                                    withTemplate:@""];
    return string;
}

- (BOOL) hasRSSLink:(NSString*) link {
    return [[link substringWithRange:NSMakeRange(link.length - 4, 4)] isEqualToString:@".rss"];
}

#pragma mark - MainTableViewCellListener

- (void)didTapOnInfoButton:(MainTableViewCell *)infoButton {
    
    NSIndexPath* indexPath = [self.tableView indexPathForCell:infoButton];
    FeedItem* item = [self.feeds objectAtIndex:indexPath.row];
    
    DetailsViewController* dvc = [[DetailsViewController alloc] init];
    
    if ([ReachabilityStatusChecker hasInternerConnection]) {
        dvc.itemTitleString = item.itemTitle;
        dvc.itemDateString = item.pubDate;
        dvc.itemURLString = item.imageURL;
        dvc.itemDescriptionString = [self correctDescription:item.itemDescription];
        
        [self.navigationController pushViewController:dvc animated:YES];
    } else {
        dvc.itemTitleString = item.itemTitle;
        dvc.itemDescriptionString = [self correctDescription:item.itemDescription];
        
        [self.navigationController pushViewController:dvc animated:YES];
    }
    
    
}

- (void)didTapOnFavoritesButton:(MainTableViewCell *) favoritesButton {
    
    NSIndexPath* indexPath = [self.tableView indexPathForCell:favoritesButton];
    FeedItem* item = [self.feeds objectAtIndex:indexPath.row];
    if (!item.isFavorite) {
        item.isFavorite = YES;
        [[FileManager sharedFileManager] saveFeedItem:item toFileWithName:FAVORITES_NEWS_FILE_NIME];
        [favoritesButton.favoritesButton setImage:[UIImage imageNamed:@"fullStar"] forState:UIControlStateNormal];
    } else {
        item.isFavorite = NO;
        [[FileManager sharedFileManager] removeFeedItem:item fromFile:FAVORITES_NEWS_FILE_NIME];
        [favoritesButton.favoritesButton setImage:[UIImage imageNamed:@"clearStar"] forState:UIControlStateNormal];
    }
    
}

#pragma mark - MainTableViewCellListener

- (void)didTapOnDoneButton:(UIBarButtonItem *)doneButton {
    
    NSThread* thread = [[NSThread alloc] initWithBlock:^{
        [[FileManager sharedFileManager] saveString:self.listenedItem.link toFile:READED_NEWS];
        [[FileManager sharedFileManager] removeFeedItem:self.listenedItem fromFile:[NSString stringWithFormat:@"%@%@", self.feedResource.name, TXT_FORMAT_NAME]];
    }];
    [thread start];
    [self.readedItemsLinks addObject:self.listenedItem.link];
    [self.feeds removeObjectAtIndex:self.indexPath.row];
    [self.tableView deleteRowsAtIndexPaths:@[self.indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView reloadData];
}

#pragma mark - ViewControllerSetUp

- (void) tableViewSetUp {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    [self.tableView registerClass:[MainTableViewCell class] forCellReuseIdentifier:CELL_IDENTIFIER];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [UIView new];
    [self.view addSubview:self.tableView];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
                                              [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
                                              [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
                                              [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
                                              ]];
}

- (void) configureNavigationBar {
    self.navigationController.navigationBar.tintColor = [UIColor darkGrayColor];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    self.navigationItem.title = @"RSS Reader";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(handlemenuToggle)];
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];
}

#pragma mark - Shake gesture

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    __weak MainViewController* weakSelf = self;
    self.rssParser.feedItemDownloadedHandler = ^(FeedItem *item) {
        [weakSelf performSelectorOnMainThread:@selector(addFeedItemToFeeds:) withObject:item waitUntilDone:NO];
    };
    [self.rssParser rssParseWithURL:[NSURL URLWithString:URL_TO_PARSE]];
}

#pragma mark - Notifications

- (void) feedResourceWasAddedNotification:(NSNotification*) notification {
    [self.feeds removeAllObjects];
    self.feedItem = nil;
    self.rssParser = [[RSSParser alloc] init];
    self.feedResource = [notification.userInfo objectForKey:@"resource"];
    __weak MainViewController* weakSelf = self;
    self.rssParser.feedItemDownloadedHandler = ^(FeedItem *item) {
        [weakSelf performSelectorOnMainThread:@selector(addFeedItemToFeeds:) withObject:item waitUntilDone:NO];
    };
    
    [self.rssParser rssParseWithURL:self.feedResource.url];
}

- (void) feedResourceWasChosenNotification:(NSNotification*) notification {

    FeedResource* resource = [notification.userInfo objectForKey:@"resource"];
    NSString* str = [NSString stringWithFormat:@"%@%@", resource.name, TXT_FORMAT_NAME];
    NSMutableArray<FeedItem*>* items = [[FileManager sharedFileManager] readFeedItemsFile:str];
    self.feeds = items;
    [self.tableView reloadData];
}

- (void) addFeedItemToFeeds:(FeedItem* ) item {
    if (item) {
        if (![self.readedItemsLinks containsObject:item.link]) {
            [self.feeds addObject:item];
            [self.tableView reloadData];
        }
    }
}

- (void) itemsLoaded:(NSNotification *) notification {
    [[FileManager sharedFileManager] createAndSaveFeedItems:self.feeds toFileWithName:[NSString stringWithFormat:@"%@%@", self.feedResource.name, TXT_FORMAT_NAME]];
}

- (void) showNotInternerConnectionAlert {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                          message:@"Check your internet connection"
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

