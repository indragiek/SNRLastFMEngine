//
//  ExampleAppAppDelegate.h
//  ExampleApp
//
//  Created by Indragie Karunaratne on 11-07-09.
//  Copyright 2011 PCWiz Computer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SNRLastFMEngine;
@interface ExampleAppAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
    SNRLastFMEngine *_lastFMEngine;
    IBOutlet NSTextField *authLabel;
}

@property (assign) IBOutlet NSWindow *window;
- (IBAction)authenticateLastFM:(id)sender;
- (IBAction)scrobbleCurrentiTunesSong:(id)sender;
@end
