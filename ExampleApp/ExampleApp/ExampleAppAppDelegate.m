//
//  ExampleAppAppDelegate.m
//  ExampleApp
//
//  Created by Indragie Karunaratne on 10-11-24.
//  Copyright 2010 Indragie Karunaratne. All rights reserved.
//
/* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

#import "ExampleAppAppDelegate.h"
#import "SNRLastFMEngine.h"
#import "iTunes.h"
#import "INKeychainAccess.h"

static NSString* const kCustomURLScheme = @"x-com-snraudioengine-example";
static NSString* const kPrefsUsernameKey = @"username";

@interface ExampleAppAppDelegate ()
- (void)_registerCustomURLSchemeHandler;
- (void)_configureLastFMEngine;
- (void)_presentAlertForErrorWithDescription:(NSString*)description;
@end

@implementation ExampleAppAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self _registerCustomURLSchemeHandler];
    [self _configureLastFMEngine];
}

#pragma mark -
#pragma mark Config

- (void)_registerCustomURLSchemeHandler
{
    // Register for Apple Events
    NSAppleEventManager *em = [NSAppleEventManager sharedAppleEventManager];
    [em setEventHandler:self andSelector:@selector(getURL:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    // Set Sonora as the default handler
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    LSSetDefaultHandlerForURLScheme((CFStringRef)kCustomURLScheme, (CFStringRef)bundleID);
}

- (void)_configureLastFMEngine
{
    NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:kPrefsUsernameKey];
    _lastFMEngine = [[SNRLastFMEngine alloc] initWithUsername:username];
    if (!username) {
        username = @"not authenticated";
    }
    [authLabel setStringValue:[NSString stringWithFormat:@"Authenticated as: %@", username]];
}

#pragma mark -
#pragma mark URL Handler 

- (void)getURL:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *prefix = [NSString stringWithFormat:@"%@://auth/?token=", kCustomURLScheme];
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSString *token = [urlString substringFromIndex:[prefix length]];
    [_lastFMEngine retrieveAndStoreSessionKeyWithToken:token completionHandler:^(NSString *user, NSError *error) {
        if (error) { 
            NSLog(@"%@ %@", error, [error userInfo]);
        }
        [[NSUserDefaults standardUserDefaults] setObject:user forKey:kPrefsUsernameKey];
        [authLabel setStringValue:[NSString stringWithFormat:@"Authenticated as: %@", user]];
    }];
}

#pragma mark -
#pragma mark Error Handling

- (void)_presentAlertForErrorWithDescription:(NSString*)description
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
    NSError *error = [NSError errorWithDomain:@"SNRLastFMEngineError" code:0 userInfo:userInfo];
    [[NSAlert alertWithError:error] runModal];
}

#pragma mark -
#pragma mark Button Actions

- (IBAction)authenticateLastFM:(id)sender
{
    NSString *callback = [NSString stringWithFormat:@"%@://auth/", kCustomURLScheme];
    NSURL *callbackURL = [NSURL URLWithString:callback];
    [[NSWorkspace sharedWorkspace] openURL:[SNRLastFMEngine webAuthenticationURLWithCallbackURL:callbackURL]];
}

- (IBAction)scrobbleCurrentiTunesSong:(id)sender
{
    if (![_lastFMEngine isAuthenticated]) {
        [self _presentAlertForErrorWithDescription:@"Last.fm engine isn't authorized."];
        return;
    }
    iTunesApplication *itunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    iTunesTrack *currentTrack = itunes.currentTrack;
    if (!currentTrack.name) {
        [self _presentAlertForErrorWithDescription:@"Nothing is playing in iTunes."];
        return;
    }
    [_lastFMEngine scrobbleTrackWithName:currentTrack.name album:currentTrack.album artist:currentTrack.artist albumArtist:currentTrack.albumArtist trackNumber:currentTrack.trackNumber duration:currentTrack.duration timestamp:[[NSDate date] timeIntervalSince1970] completionHandler:^(NSDictionary *scrobbles, NSError *error) {
        NSLog(@"%@", scrobbles);
        if (error) {
            NSLog(@"%@ %@", error, [error userInfo]);
        } else {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Successfully scrobbled" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Scrobbled song %@ by %@ to Last.fm.", currentTrack.name, currentTrack.artist];
            [alert runModal];
        }
    }];
}
@end
