//
//  OmarStandalone.xm — features that rely only on public iOS frameworks, not on
//  Instagram internals: GPS spoofing and the app passcode/Face ID lock.
//  Programmer: Omar Al-Enezi (عمر العنزي).
//
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "OmarPrefs.h"

#pragma mark - Feature: change location (تغيير الموقع)

// Build the spoofed CLLocation from the coordinates saved in the settings panel.
static CLLocation *OmarSpoofedLocation(void) {
    OmarPrefs *p = [OmarPrefs shared];
    double lat = [p doubleForKey:OmarKeyLocationLat];
    double lng = [p doubleForKey:OmarKeyLocationLng];
    return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lng)
                                         altitude:0
                               horizontalAccuracy:5
                                 verticalAccuracy:5
                                        timestamp:[NSDate date]];
}

%hook CLLocationManager

// Apps that read the location directly get the spoofed value.
- (CLLocation *)location {
    if ([[OmarPrefs shared] enabled:OmarKeyLocationSpoof]) return OmarSpoofedLocation();
    return %orig;
}

// Apps that observe updates get one pushed to their delegate on start.
- (void)startUpdatingLocation {
    %orig;
    if (![[OmarPrefs shared] enabled:OmarKeyLocationSpoof]) return;
    id<CLLocationManagerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocation *loc = OmarSpoofedLocation();
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate locationManager:self didUpdateLocations:@[ loc ]];
        });
    }
}

- (void)requestLocation {
    if ([[OmarPrefs shared] enabled:OmarKeyLocationSpoof]) {
        id<CLLocationManagerDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            CLLocation *loc = OmarSpoofedLocation();
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate locationManager:self didUpdateLocations:@[ loc ]];
            });
            return;
        }
    }
    %orig;
}

%end

#pragma mark - Feature: app lock (تمكين قفل للتطبيق)

// A dedicated overlay window covers the app whenever it returns to the
// foreground until Face ID / passcode succeeds.
@interface OmarAppLock : NSObject
@property (nonatomic, strong) UIWindow *lockWindow;
@property (nonatomic, assign) BOOL authenticating;
+ (instancetype)shared;
- (void)lock;
- (void)authenticate;
@end

@implementation OmarAppLock

+ (instancetype)shared {
    static OmarAppLock *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [OmarAppLock new]; });
    return s;
}

- (UIWindowScene *)activeScene {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) return (UIWindowScene *)scene;
    }
    return nil;
}

- (void)lock {
    if (self.lockWindow) return;
    UIWindowScene *scene = [self activeScene];
    if (!scene) return;
    UIWindow *w = [[UIWindow alloc] initWithWindowScene:scene];
    w.windowLevel = UIWindowLevelAlert + 1;
    UIViewController *vc = [UIViewController new];
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
    UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:blur];
    ev.frame = UIScreen.mainScreen.bounds;
    ev.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vc.view addSubview:ev];
    UILabel *lbl = [[UILabel alloc] initWithFrame:vc.view.bounds];
    lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.text = @"🔒 Dev | OMAR";
    lbl.textColor = UIColor.whiteColor;
    lbl.font = [UIFont boldSystemFontOfSize:22];
    [vc.view addSubview:lbl];
    w.rootViewController = vc;
    [w makeKeyAndVisible];
    self.lockWindow = w;
}

- (void)unlock {
    self.lockWindow.hidden = YES;
    self.lockWindow = nil;
}

- (void)authenticate {
    if (self.authenticating || !self.lockWindow) return;
    self.authenticating = YES;
    LAContext *ctx = [LAContext new];
    NSError *err = nil;
    LAPolicy policy = [ctx canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&err]
        ? LAPolicyDeviceOwnerAuthentication : LAPolicyDeviceOwnerAuthenticationWithBiometrics;
    [ctx evaluatePolicy:policy
        localizedReason:@"افتح إنستقرام"
                  reply:^(BOOL success, NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.authenticating = NO;
            if (success) [self unlock];
        });
    }];
}

@end

// Cover the screen the moment the app leaves the foreground so a passcode is
// required on return (and nothing sensitive shows in the app switcher).
%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        if ([[OmarPrefs shared] enabled:OmarKeyAppLock]) [[OmarAppLock shared] lock];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        if ([[OmarPrefs shared] enabled:OmarKeyAppLock]) [[OmarAppLock shared] authenticate];
    }];

    // === DIAGNOSTIC BEACON (temporary) ===
    // Runs from the constructor — a plain C initializer that needs NO substrate.
    // If this alert appears, the dylib IS injected and loading; any non-working
    // feature is then a hooking/substrate issue, not an injection one.
    static BOOL shown = NO;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        if (shown) return;
        shown = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIWindow *w = nil;
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:UIWindowScene.class]) {
                    for (UIWindow *win in ((UIWindowScene *)s).windows)
                        if (win.isKeyWindow) { w = win; break; }
                }
                if (w) break;
            }
            UIViewController *top = w.rootViewController;
            while (top.presentedViewController) top = top.presentedViewController;
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:@"Dev | OMAR"
                                 message:@"✅ الدايلب محقون ويعمل.\n(رسالة تشخيص — بنشيلها بعدين)"
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"تمام" style:UIAlertActionStyleDefault handler:nil]];
            [top presentViewController:ac animated:YES completion:nil];
        });
    }];
}
