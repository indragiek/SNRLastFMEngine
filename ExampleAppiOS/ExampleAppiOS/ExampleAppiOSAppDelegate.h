//
//  ExampleAppiOSAppDelegate.h
//  ExampleAppiOS
//
//  Created by Indragie Karunaratne on 11-07-10.
//  Copyright 2011 PCWiz Computer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ExampleAppiOSViewController;

@interface ExampleAppiOSAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet ExampleAppiOSViewController *viewController;

@end
