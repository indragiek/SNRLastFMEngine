//
//  SNRLastFM.m
//
//  Created by Indragie Karunaratne on 10-11-24.
//  Copyright 2010 Indragie Karunaratne. All rights reserved.
//
/* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

#import "SNRLastFMEngine.h"
#import "EMKeychainItem.h"
#import "JSONKit.h"

#import <CommonCrypto/CommonDigest.h>

#define K_ITEM_SERVICE @"Last.fm (com.indragie.SNRAudioEngine)"

#define ERROR_DOMAIN @"LastFMErrorDomain"
#define DEFAULT_ERROR_CODE 9999
#define AUTH_ROOT_URL @"http://www.last.fm/api/auth/"

@interface SNRLastFMEngine ()
- (NSString*)_methodSignatureWithParameters:(NSDictionary*)parameters;
- (NSData*)_generatePOSTBodyWithParameters:(NSDictionary*)params;
- (NSString*)_generateGETRequestURLWithParameters:(NSDictionary*)params;
- (NSError*)_errorWithDictionary:(NSDictionary*)dictionary;
- (void)_storeCredentialsWithUsername:(NSString*)username sessionKey:(NSString*)key error:(NSError**)error;
@property (nonatomic, retain) NSString *sk;
@end

@interface NSString (SNRAdditions)
- (NSString*)MD5;
- (NSString*)URLEncodedString;
@end

@implementation NSString (SNRAdditions)
- (NSString*)MD5 
{
	const char *cStr = [self UTF8String];
	unsigned char result[16];
	CC_MD5( cStr, strlen(cStr), result );
	return [[NSString stringWithFormat:
			@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
			result[0], result[1], result[2], result[3], 
			result[4], result[5], result[6], result[7],
			result[8], result[9], result[10], result[11],
			result[12], result[13], result[14], result[15]
			] lowercaseString];  
}

- (NSString*)URLEncodedString
{
    NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8);
    return [result autorelease];
}
@end

@implementation SNRLastFMEngine
@synthesize username = _username, sk = _sk;

#pragma mark -
#pragma mark Initialization

- (id)initWithUsername:(NSString*)user
{
	if ((self = [super init])) {
		self.username = user;
	}
	return self;
}

+ (id)lastFMEngine
{
	return [[[self alloc] init] autorelease];
}

+ (id)lastFMEngineWithUsername:(NSString*)user
{
	return [[[self alloc] initWithUsername:user] autorelease];
}

#pragma mark -
#pragma mark Accessors

- (void)setUsername:(NSString *)newUsername
{
	if (_username != newUsername) {
		[_username release];
		_username = [newUsername retain];
        EMGenericKeychainItem *keychainItem = [EMGenericKeychainItem genericKeychainItemForService:K_ITEM_SERVICE withUsername:_username];
        if (keychainItem) {
            NSString *key = keychainItem.password;
            if (key && (![key isEqualToString:@""])) {
                self.sk = key;
            }
        }
	}
}

- (dispatch_queue_t)dispatchQueue
{
    return _dispatchQueue;
}

- (void)setDispatchQueue:(dispatch_queue_t)dispatchQueue
{
    if (dispatchQueue != _dispatchQueue) {
        if (_dispatchQueue != NULL) {
            dispatch_release(_dispatchQueue);
        }
        _dispatchQueue = dispatchQueue;
        dispatch_retain(_dispatchQueue);
    }
}

#pragma mark -
#pragma mark Memory Management

- (void)dealloc
{
	[_username release];
	[_sk release];
    if (_dispatchQueue != NULL) {
        dispatch_release(_dispatchQueue);
    }
	[super dealloc];
}

#pragma mark -
#pragma mark Basic

- (void)callMethod:(NSString*)method withParameters:(NSDictionary*)params requireAuth:(BOOL)auth HTTPMethod:(SNRHTTPMethod)http completionBlock:(void (^)(NSDictionary *response, NSError *error))handler
{
	NSMutableDictionary *requestParameters = [NSMutableDictionary dictionaryWithDictionary:params];
	[requestParameters setObject:method forKey:@"method"];
	[requestParameters setObject:API_KEY forKey:@"api_key"];
	[requestParameters addEntriesFromDictionary:params];
	if (auth) {
		if (self.sk) { [requestParameters setObject:self.sk forKey:@"sk"]; }
		[requestParameters setObject:[self _methodSignatureWithParameters:requestParameters] forKey:@"api_sig"];
	}
    [requestParameters setObject:@"json" forKey:@"format"];
    BOOL usingGET = (http == SNRHTTPMethodGET);
    NSURL *requestURL = usingGET ? [NSURL URLWithString:[self _generateGETRequestURLWithParameters:requestParameters]] : [NSURL URLWithString:API_ROOT];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
	[request setHTTPMethod:usingGET ? @"GET" : @"POST"];
    if (!usingGET) {
        NSData *postData = [self _generatePOSTBodyWithParameters:requestParameters];
        NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
    }
	dispatch_queue_t queue = (self.dispatchQueue != NULL) ? self.dispatchQueue : dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(queue, ^{
		NSError *error = nil;
		NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:&error];
        NSDictionary *response = nil;
        if (data) {
            response = [data objectFromJSONDataWithParseOptions:JKParseOptionStrict error:&error];
            if (!error) { // Check to see if there is error information in the dictionary
                error = [self _errorWithDictionary:response];
            }
        }
		dispatch_async(dispatch_get_main_queue(), ^{
			if (handler) { handler(response, error); }
		});
	});
}

#pragma mark -
#pragma mark Authentication

#pragma mark -
#pragma mark Web Authentication

+ (NSURL*)webAuthenticationURLWithCallbackURL:(NSURL*)callback
{
    NSMutableString *URLString = [NSMutableString stringWithFormat:@"%@?api_key=%@", AUTH_ROOT_URL, API_KEY];
    if (callback) { [URLString appendFormat:@"&cb=%@", callback]; }
    return [NSURL URLWithString:URLString];
}

#pragma mark -
#pragma mark Desktop Authentication

- (void)retrieveAuthenticationToken:(void (^)(NSString *token, NSError *error))handler;
{
	__block NSError *theError = nil;
    __block __typeof__(self) blockSelf = self;
	[self callMethod:@"auth.getToken" withParameters:nil requireAuth:YES HTTPMethod:SNRHTTPMethodGET completionBlock:^(NSDictionary *response, NSError *blockError){
		theError = [blockError copy];
		NSString *token = [response valueForKey:@"token"];
		if (!token && response && !theError) { // Create an error if the token is not found
            theError = [[blockSelf _errorWithDictionary:response] retain]; 
        } 
        [theError autorelease];
		if (handler) { handler(token, theError); } // Call completion handler
	}];
}

+ (NSURL*)authenticationURLWithToken:(NSString*)token
{
	NSString *URLString = [NSString stringWithFormat:@"%@?api_key=%@&token=%@", AUTH_ROOT_URL, API_KEY, token];
	return [NSURL URLWithString:URLString];
}

#pragma mark -
#pragma mark Mobile Authentication

- (void)retrieveAndStoreSessionKeyWithUsername:(NSString*)username password:(NSString*)password completionHandler:(void (^)(NSError *error))handler;
{
    __block __typeof__(self) blockSelf = self;
    __block NSError *theError = nil;
    NSString *authToken = [[NSString stringWithFormat:@"%@%@", [username lowercaseString], [password MD5]] MD5];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:username, @"username", authToken, @"authToken", nil];
    [self callMethod:@"auth.getMobileSession" withParameters:parameters requireAuth:YES HTTPMethod:SNRHTTPMethodGET completionBlock:^(NSDictionary *response, NSError *error) {
        theError = [error copy];
        if (!theError) {
            NSDictionary *session = [response valueForKey:@"session"];
            NSString *key = [session valueForKey:@"key"];
            NSString *user = [session valueForKey:@"name"];
            [blockSelf _storeCredentialsWithUsername:user sessionKey:key error:&theError];
        }
        [theError autorelease];
        if (handler) { handler(error); }
    }];
}

#pragma mark -
#pragma mark Keychain Access

+ (BOOL)userHasStoredCredentials:(NSString*)user
{
    EMGenericKeychainItem *keychainItem = [EMGenericKeychainItem genericKeychainItemForService:K_ITEM_SERVICE withUsername:user];
    NSString *key = keychainItem.password;
	return (key && (![key isEqualToString:@""]));
}

+ (void)removeCredentialsForUser:(NSString*)user
{
    EMGenericKeychainItem *keychainItem = [EMGenericKeychainItem genericKeychainItemForService:K_ITEM_SERVICE withUsername:user];
    [keychainItem removeFromKeychain];
}


- (void)retrieveAndStoreSessionKeyWithToken:(NSString*)token completionHandler:(void (^)(NSString *user, NSError *error))handler
{
	__block NSError *theError = nil;
    __block __typeof__(self) blockSelf = self;
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:token, @"token", nil];
	[self callMethod:@"auth.getSession" withParameters:params requireAuth:YES HTTPMethod:SNRHTTPMethodGET completionBlock:^(NSDictionary *response, NSError *blockError){
		theError = [blockError copy];
        NSString *user = nil;
		if (!theError) { 
			NSDictionary *sessionDict = [response valueForKey:@"session"];
            NSString *key = [sessionDict valueForKey:@"key"]; // Parse JSON and obtain key and username
            user = [sessionDict valueForKey:@"name"];
			[blockSelf _storeCredentialsWithUsername:user sessionKey:key error:&theError];
		}
        [theError autorelease];
        if (handler) { handler(user, theError); } // Call completion handler
	}];
}

- (BOOL)isAuthenticated
{
    return (self.sk != nil);
}

#pragma mark -
#pragma mark Scrobbling

- (void)scrobbleTrackWithName:(NSString*)name album:(NSString*)album artist:(NSString*)artist albumArtist:(NSString*)albumArtist trackNumber:(NSInteger)trackNumber duration:(NSInteger)duration timestamp:(NSInteger)timestamp completionHandler:(void (^)(NSDictionary *scrobbles, NSError *error))handler
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (name) { [params setObject:name forKey:@"track"]; }
    if (album) { [params setObject:album forKey:@"album"]; }
    if (artist) { [params setObject:artist forKey:@"artist"]; }
    if (albumArtist) { [params setObject:albumArtist forKey:@"albumArtist"]; }
    if (trackNumber) { [params setObject:[NSNumber numberWithInteger:trackNumber] forKey:@"trackNumber"]; }
    if (duration) { [params setObject:[NSNumber numberWithInteger:duration] forKey:@"duration"]; }
    if (timestamp) { [params setObject:[NSNumber numberWithInteger:timestamp] forKey:@"timestamp"]; }
    [self callMethod:@"track.scrobble" withParameters:params requireAuth:YES HTTPMethod:SNRHTTPMethodPOST completionBlock:^(NSDictionary *response, NSError *blockError) {
        if (handler) { handler(response, blockError); }
    }];
}

- (void)updateNowPlayingTrackWithName:(NSString*)name album:(NSString*)album artist:(NSString*)artist albumArtist:(NSString*)albumArtist trackNumber:(NSInteger)trackNumber duration:(NSInteger)duration completionHandler:(void (^)(NSDictionary *response, NSError *error))handler
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (name) { [params setObject:name forKey:@"track"]; }
    if (album) { [params setObject:album forKey:@"album"]; }
    if (artist) { [params setObject:artist forKey:@"artist"]; }
    if (albumArtist) { [params setObject:albumArtist forKey:@"albumArtist"]; }
    if (trackNumber) { [params setObject:[NSNumber numberWithInteger:trackNumber] forKey:@"trackNumber"]; }
    if (duration) { [params setObject:[NSNumber numberWithInteger:duration] forKey:@"duration"]; }
    [self callMethod:@"track.updateNowPlaying" withParameters:params requireAuth:YES HTTPMethod:SNRHTTPMethodPOST completionBlock:^(NSDictionary *response, NSError *blockError) {
        if (handler) { handler(response, blockError); }
    }];
}

#pragma mark -
#pragma mark Private

- (NSString*)_methodSignatureWithParameters:(NSDictionary*)parameters
{
	NSArray *keys = [[parameters allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSMutableString *parameterString = [NSMutableString string];
	for (NSString *key in keys) { // Append each of the key-value pairs in alphabetical order
		[parameterString appendString:key];
		[parameterString appendString:[[parameters valueForKey:key] description]];
	}
	[parameterString appendString:API_SECRET]; // Append secret
	return [parameterString MD5]; // Create an MD5 hash
}

- (NSData*)_generatePOSTBodyWithParameters:(NSDictionary*)params
{
    NSMutableString *requestURL = [NSMutableString string];
	NSArray *keys = [params allKeys];
	for (NSString *key in keys) {
		[requestURL appendFormat:@"%@=%@&", key, [[[params valueForKey:key] description] URLEncodedString]]; // Append each key
	}
    [requestURL deleteCharactersInRange:NSMakeRange([requestURL length] - 1, 1)];
    return [requestURL dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString*)_generateGETRequestURLWithParameters:(NSDictionary*)params
{
	NSMutableString *requestURL = [NSMutableString stringWithFormat:@"%@?", API_ROOT];
	NSArray *keys = [params allKeys];
	for (NSString *key in keys) {
		[requestURL appendFormat:@"%@=%@&", key, [[[params valueForKey:key] description] URLEncodedString]]; // Append each key
	}
    [requestURL deleteCharactersInRange:NSMakeRange([requestURL length] - 1, 1)];
	return requestURL;
}

- (NSError*)_errorWithDictionary:(NSDictionary*)dictionary
{
	NSNumber *errorCode = [dictionary valueForKey:@"error"];
    if (!errorCode) { return nil; }
	NSString *message = [dictionary valueForKey:@"message"];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
	// Create an error object with the error information returned by the API
	return [NSError errorWithDomain:ERROR_DOMAIN code:[errorCode integerValue] userInfo:userInfo];
}

- (void)_storeCredentialsWithUsername:(NSString*)username sessionKey:(NSString*)key error:(NSError**)error
{
    EMGenericKeychainItem *keychainItem = [EMGenericKeychainItem genericKeychainItemForService:K_ITEM_SERVICE withUsername:username];
    if (!keychainItem) {
        keychainItem = [EMGenericKeychainItem addGenericKeychainItemForService:K_ITEM_SERVICE withUsername:username password:key];
    }
    keychainItem.password = key;
    if (!keychainItem && error) {
        NSString *message = @"Failed to save credentials to keychain."; // If the item failed to save, create an error
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, @"message", nil];
        *error = [[NSError errorWithDomain:ERROR_DOMAIN code:DEFAULT_ERROR_CODE userInfo:userInfo] retain];
    }
    self.username = username;
}


@end
