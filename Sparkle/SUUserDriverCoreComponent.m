//
//  SUUserDriverCoreComponent.m
//  Sparkle
//
//  Created by Mayur Pawashe on 3/4/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import "SUUserDriverCoreComponent.h"
#import "SUStandardUserDriverDelegate.h"
#import "SUStandardUserDriverRemoteDelegate.h"
#import "SUUserDriver.h"

#ifdef _APPKITDEFINES_H
#error This is a "core" class and should NOT import AppKit
#endif

@interface SUUserDriverCoreComponent ()

@property (nonatomic, weak, readonly) id<SUUserDriver> userDriver;

@property (nonatomic) BOOL idlesOnUpdateChecks;
@property (nonatomic) BOOL updateInProgress;

@property (nonatomic) NSTimer *checkUpdateTimer;
@property (nonatomic, copy) void (^checkForUpdatesReply)(SUUpdateCheckTimerStatus);

@property (nonatomic, copy) void (^installUpdateHandler)(SUInstallUpdateStatus);
@property (nonatomic, copy) void (^updateCheckStatusCompletion)(SUUserInitiatedCheckStatus);
@property (nonatomic, copy) void (^downloadStatusCompletion)(SUDownloadUpdateStatus);

@end

@implementation SUUserDriverCoreComponent

@synthesize userDriver = _userDriver;
@synthesize delegate = _delegate;
@synthesize idlesOnUpdateChecks = _idlesOnUpdateChecks;
@synthesize updateInProgress = _updateInProgress;
@synthesize checkUpdateTimer = _checkUpdateTimer;
@synthesize checkForUpdatesReply = _checkForUpdatesReply;
@synthesize installUpdateHandler = _installUpdateHandler;
@synthesize updateCheckStatusCompletion = _updateCheckStatusCompletion;
@synthesize downloadStatusCompletion = _downloadStatusCompletion;

#pragma mark Birth

- (instancetype)initWithUserDriver:(id<SUUserDriver>)userDriver delegate:(id<SUStandardUserDriverDelegate>)delegate
{
    self = [super init];
    if (self != nil) {
        _userDriver = userDriver;
        _delegate = delegate;
    }
    return self;
}

#pragma mark Is Update Busy?

- (void)idleOnUpdateChecks:(BOOL)shouldIdleOnUpdateChecks
{
    self.idlesOnUpdateChecks = shouldIdleOnUpdateChecks;
}

- (void)showUpdateInProgress:(BOOL)isUpdateInProgress
{
    self.updateInProgress = isUpdateInProgress;
}

#pragma mark Check Updates Timer

- (BOOL)isDelegateResponsibleForUpdateChecking
{
    BOOL result = NO;
    if ([self.delegate respondsToSelector:@selector(responsibleForInitiatingUpdateCheckForUserDriver:)]) {
        result = [self.delegate responsibleForInitiatingUpdateCheckForUserDriver:self.userDriver];
    }
    return result;
}

- (BOOL)willInitiateNextUpdateCheck
{
    return (self.checkUpdateTimer != nil);
}

- (void)checkForUpdates:(NSTimer *)__unused timer
{
    if ([self isDelegateResponsibleForUpdateChecking]) {
        if ([self.delegate respondsToSelector:@selector(initiateUpdateCheckForUserDriver:)]) {
            [self.delegate initiateUpdateCheckForUserDriver:self.userDriver];
        } else {
            NSLog(@"Error: Delegate %@ for user driver %@ must implement initiateUpdateCheckForUserDriver: because it returned YES from responsibleForInitiatingUpdateCheckForUserDriver:", self.delegate, self);
        }
    } else {
        if (self.checkForUpdatesReply != nil) {
            self.checkForUpdatesReply(SUCheckForUpdateNow);
            self.checkForUpdatesReply = nil;
        }
    }
    
    [self invalidateUpdateCheckTimer];
}

- (void)startUpdateCheckTimerWithNextTimeInterval:(NSTimeInterval)timeInterval reply:(void (^)(SUUpdateCheckTimerStatus))reply
{
    if ([self isDelegateResponsibleForUpdateChecking]) {
        reply(SUCheckForUpdateWillOccurLater);
    } else {
        self.checkForUpdatesReply = reply;
    }
    
    self.checkUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(checkForUpdates:) userInfo:nil repeats:NO];
}

- (void)invalidateUpdateCheckTimer
{
    if (self.checkUpdateTimer != nil) {
        [self.checkUpdateTimer invalidate];
        self.checkUpdateTimer = nil;
        
        if (self.checkForUpdatesReply != nil) {
            self.checkForUpdatesReply(SUCheckForUpdateWillOccurLater);
            self.checkForUpdatesReply = nil;
        }
    }
}

#pragma mark Install Updates

- (void)registerInstallUpdateHandler:(void (^)(SUInstallUpdateStatus))installUpdateHandler
{
    self.installUpdateHandler = installUpdateHandler;
}

- (void)installAndRestart
{
    if (self.installUpdateHandler != nil) {
        self.installUpdateHandler(SUInstallAndRelaunchUpdateNow);
        self.installUpdateHandler = nil;
    }
}

- (void)cancelInstallAndRestart
{
    if (self.installUpdateHandler != nil) {
        self.installUpdateHandler(SUCancelUpdateInstallation);
        self.installUpdateHandler = nil;
    }
}

#pragma mark Update Check Status

- (void)registerUpdateCheckStatusHandler:(void (^)(SUUserInitiatedCheckStatus))updateCheckStatusCompletion
{
    self.updateCheckStatusCompletion = updateCheckStatusCompletion;
}

- (void)cancelUpdateCheckStatus
{
    if (self.updateCheckStatusCompletion != nil) {
        self.updateCheckStatusCompletion(SUUserInitiatedCheckCancelled);
        self.updateCheckStatusCompletion = nil;
    }
}

- (void)completeUpdateCheckStatus
{
    if (self.updateCheckStatusCompletion != nil) {
        self.updateCheckStatusCompletion(SUUserInitiatedCheckDone);
        self.updateCheckStatusCompletion = nil;
    }
}

#pragma mark Download Status

- (void)registerDownloadStatusHandler:(void (^)(SUDownloadUpdateStatus))downloadUpdateStatusCompletion
{
    self.downloadStatusCompletion = downloadUpdateStatusCompletion;
}

- (void)cancelDownloadStatus
{
    if (self.downloadStatusCompletion != nil) {
        self.downloadStatusCompletion(SUDownloadUpdateCancelled);
        self.downloadStatusCompletion = nil;
    }
}

- (void)completeDownloadStatus
{
    if (self.downloadStatusCompletion != nil) {
        self.downloadStatusCompletion(SUDownloadUpdateDone);
        self.downloadStatusCompletion = nil;
    }
}

#pragma mark Aborting Everything

- (void)dismissUpdateInstallation
{
    // Note: self.idlesOnUpdateChecks is intentionally not touched in case this instance is re-used
    
    self.updateInProgress = NO;
    
    [self cancelUpdateCheckStatus];
    [self cancelDownloadStatus];
    [self cancelInstallAndRestart];
    [self invalidateUpdateCheckTimer];
}

- (void)invalidate
{
    // Make sure any remote handlers will not be invoked
    self.checkForUpdatesReply = nil;
    self.downloadStatusCompletion = nil;
    self.installUpdateHandler = nil;
    self.updateCheckStatusCompletion = nil;
    
    // Dismiss the installation normally
    [self dismissUpdateInstallation];
}

@end
