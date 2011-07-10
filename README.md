## SNRLastFMEngine: A modern block-based Objective-C interface to the Last.fm API

`SNRLastFMEngine` is designed with the intent of making it a simple to integrate the Last.fm API into your Cocoa application. It uses modern block-based callbacks to allow you to call Last.fm API methods and handle the response within that same chunk of code.

## Adding SNRLastFMEngine to your project

1. Link against `Security.framework`. If you are compiling for OS X 10.7, you may also need to link against `libCommonCrypto.dylib`
2. Add the required dependencies (`JSONKit` and `EMKeychain`, see below)
3. Set the API key and API secret in `SNRLastFMEngine.h` according to your [API account info](http://www.last.fm/api/account)
4. Add the `SNRLastFMEngine` class and Last.fm away!

Read on for more information on authentication and actually using the API.
 
## Dependencies

* [JSONKit](https://github.com/johnezang/JSONKit) - Used for speedy JSON parsing of Last.fm API requests. `JSONKit` has been added as a `git` submodule. You can automatically clone the `JSONKit` repo for use with the project by running `git submodule init` and then `git submodule update`.
* [EMKeychain](http://extendmac.com/EMKeychain/) - Objective-C interface to the Mac OS X keychain that is used to store credentials. The latest version of the `EMKeychain` source is included with the project.

## Authenticating with Last.fm

Last.fm provides [two possible](http://www.last.fm/api/authentication) authentication methods that are usable for desktop applications. Ironically, the "web application" authentication method is the most convenient and easy to implement in a desktop application. That said, Last.fm doesn't condone the use of the web app authentication method for desktop apps, so use at your own discretion. Authentication isn't required for all API calls. The [Last.fm API](http://www.last.fm/api/) docs detail which methods require authentication.

**Web Authentication Method**
(demonstrated in example app)

1. Register a custom URL handler for your app
2. Call `SNRLastFMEngine`'s `+webAuthenticationURLWithCallbackURL` using application's custom handler URL (e.g. `x-com-yourapp://auth`) and open the returned URL in a `WebView` or web browser
3. In your URL handler method, parse the URL string and retrieve the token (e.g. format: `x-com-yourapp://auth/?token=xxxxxxxxxx`)
4. Call `-retrieveAndStoreSessionKeyWithToken:completionHandler:` to authorize the Last.fm engine. In the completion block, store the returned username in your application preferences.

**Desktop Authentication Method**

1. Fetch a request token from Last.fm using `SNRLastFMEngine`'s `-retrieveAuthenticationToken:` method
2. Call `+authenticationURLWithToken:` to retrieve an authentication URL
3. Open this URL in either a `WebView` or in the user's web browser, which will then prompt them to allow your application to access their account
4. Call `-retrieveAndStoreSessionKeyWithToken:completionHandler:` to authorize the Last.fm engine. In the completion block, store the returned username in your application preferences.

After authentication, you are now ready to make authenticated API calls. For subsequent launches of your app, you can just set the `username` property to the username returned during the authentication process and `SNRLastFMEngine` will automatically read the session key from the keychain and configure itself for use.

## Example Usage (making API calls)

### album.getInfo (GET)

    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"Phobia", @"album", @"Breaking Benjamin", @"artist", nil];
    [_lastFMEngine callMethod:@"album.getInfo" withParameters:parameters requireAuth:NO HTTPMethod:SNRHTTPMethodGET completionBlock:^(NSDictionary *response, NSError *error) {
        NSLog(@"%@", response);
    }];

### library.addArtist (POST)

    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"Disturbed", @"artist", nil];
    [_lastFMEngine callMethod:@"library.addArtist" withParameters:parameters requireAuth:YES HTTPMethod:SNRHTTPMethodPOST completionBlock:^(NSDictionary *response, NSError *error) {
        NSLog(@"%@", response);
    }];

By default, HTTP requests are made on the global dispatch queue. However, if you want to use your own queue you can set the `dispatchQueue` property.

## Convenience Methods

I've included a few convenience methods (namely for scrobbling) that simplify the process by letting you include the parameters in the method signature. I added these because I'm using them in my own apps, and will continue to add more convenience methods as I start to use them. Ideally, the engine should have corresponding methods for every method in the Last.fm API.

### Example: Scrobbling

    [_lastFMEngine scrobbleTrackWithName:@"Numb" album:@"Meteora" artist:@"Linkin Park" albumArtist:@"Linkin Park" trackNumber:13 duration:225 timestamp:[[NSDate date] timeIntervalSince1970] completionHandler:^(NSDictionary *scrobbles, NSError *error) {
        NSLog(@"%@", scrobbles);
    }];

## Example App 

I've included an example app with the project that demonstrates the following:

* Registering and handling a custom URL handler
* Authenticating with the Last.fm API using the web authentication method
* Retrieving the currently playing iTunes track via `ScriptingBridge` and scrobbling it to Last.fm


## iOS Compatibility

This project is being used exclusively on the Mac right now, so it hasn't been tested at all on iOS. `SNRLastFMEngine` itself doesn't use anything that isn't available on iOS and therefore should work, but `EMKeychain` is only compatible with Mac OS X so the keychain access code needs to be replaced for iOS. I hope to implement complete iOS support in the near future, but if anyone manages to do it themselves, then a pull request would be appreciated.

## Contributing

As always, I greatly appreciate any bug fixes, improvements, etc. One of the largest ways to contribute to this project would be to implement convenience methods for the rest of the Last.fm API calls. Please send me a pull request if you have anything to contribute.

## Who am I?

I'm Indragie Karunaratne, a 16 year old Mac OS X and iOS Developer from Edmonton AB, Canada. Visit [my website](http://indragie.com) to check out my work, or to get in touch with me. ([follow me](http://twitter.com/indragie) on Twitter!)

## Licensing

`SNRLastFMEngine` is licensed under the [BSD license](http://www.opensource.org/licenses/bsd-license.php).