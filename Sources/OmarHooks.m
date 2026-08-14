//
//  OmarHooks.m — all runtime hooks for the OmarTweak Instagram tweak.
//  Programmer: Omar Al-Enezi (عمر العنزي).
//
//  IMPORTANT: this build targets NON-jailbroken devices (sideloaded IPA), where
//  CydiaSubstrate does NOT exist. So we do NOT use Logos %hook / MSHookMessageEx.
//  Instead every hook is a pure Objective-C method swizzle via <objc/runtime.h>,
//  which relies only on libobjc — always present on iOS. No external dependency,
//  no Substrate, no crash on launch.
//
//  All swizzles are installed once, on UIApplicationDidFinishLaunching, so every
//  Instagram/FBSharedFramework class is guaranteed loaded before we touch it.
//
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <objc/runtime.h>
#import "OmarPrefs.h"
#import "OmarSettingsViewController.h"

#pragma mark - Swizzle helper

// Replace cls's instance method `sel` with `repl`, saving the original IMP into
// *store. No-op (safely) if the class or method isn't present in this IG build.
static BOOL OmarSwizzle(const char *className, SEL sel, IMP repl, void *store) {
    Class cls = objc_getClass(className);
    if (!cls) { NSLog(@"[OmarTweak] class %s not found", className); return NO; }
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { NSLog(@"[OmarTweak] %s#%@ not found", className, NSStringFromSelector(sel)); return NO; }
    *(IMP *)store = method_getImplementation(m);
    method_setImplementation(m, repl);
    return YES;
}

static BOOL OmarEnabled(NSString *key) { return [[OmarPrefs shared] enabled:key]; }

#pragma mark - Shared UI helpers

static UIWindow *OmarKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows)
            if (w.isKeyWindow) return w;
    }
    return nil;
}

static UIViewController *OmarTopViewController(void) {
    UIViewController *top = OmarKeyWindow().rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

static void OmarPresentSettings(void) {
    OmarSettingsViewController *vc = [[OmarSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [OmarTopViewController() presentViewController:nav animated:YES completion:nil];
}

static void OmarShowWelcomeIfNeeded(void) {
    OmarPrefs *prefs = [OmarPrefs shared];
    if ([prefs boolForKey:OmarKeyWelcomeShown]) return;
    [prefs setBool:YES forKey:OmarKeyWelcomeShown];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"Dev | OMAR"
                             message:@"نورت البلس ياوحش 🐺\n"
                                      "أي ميزة تبيها تعال تيليجرام.\n\n"
                                      "ولا تنسى: اضغط على زر البيت ضغطة مطولة ويفتح لك الإعدادات."
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"يا هلا" style:UIAlertActionStyleDefault handler:nil]];
        ac.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        [OmarTopViewController() presentViewController:ac animated:YES completion:nil];
    });
}

#pragma mark - Gesture target (replaces Logos %new)

// A singleton object owns the long-press action, since swizzling can't add a
// method to IGTabBarController the way Logos %new could.
@interface OmarGestureTarget : NSObject
+ (instancetype)shared;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gr;
@end
@implementation OmarGestureTarget
+ (instancetype)shared {
    static OmarGestureTarget *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [OmarGestureTarget new]; });
    return s;
}
- (void)handleLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) OmarPresentSettings();
}
@end

#pragma mark - Hook: launcher (long-press Home tab)

static void (*orig_timelineButton)(id, SEL);
static void omar_timelineButton(id self, SEL _cmd) {
    orig_timelineButton(self, _cmd);
    UIView *home = [self valueForKey:@"_timelineButton"];
    if (![home isKindOfClass:UIView.class]) return;
    for (UIGestureRecognizer *g in home.gestureRecognizers)
        if ([g.name isEqualToString:@"omarLongPress"]) return; // attach once
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[OmarGestureTarget shared]
                                                      action:@selector(handleLongPress:)];
    lp.name = @"omarLongPress";
    lp.minimumPressDuration = 1.0;
    [home addGestureRecognizer:lp];
    OmarShowWelcomeIfNeeded();
}

#pragma mark - Hook: disable typing indicator

static void (*orig_typing)(id, SEL, BOOL, id, id, NSInteger);
static void omar_typing(id self, SEL _cmd, BOOL active, id threadKey, id meta, NSInteger type) {
    if (OmarEnabled(OmarKeyNoTyping)) active = NO;
    orig_typing(self, _cmd, active, threadKey, meta, type);
}

#pragma mark - Hook: disable screenshot notifications

static void (*orig_ssLog)(id, SEL, id, BOOL, id);
static void omar_ssLog(id self, SEL _cmd, id message, BOOL isRecording, id isNudity) {
    if (OmarEnabled(OmarKeyNoScreenshotNotify)) return; // swallow the report
    orig_ssLog(self, _cmd, message, isRecording, isNudity);
}

#pragma mark - Hook: open links in Safari

static void (*orig_loadURL)(id, SEL, id);
static void omar_loadURL(id self, SEL _cmd, id url) {
    if (OmarEnabled(OmarKeyLinksInSafari)) {
        NSURL *u = [url isKindOfClass:NSURL.class] ? url
                 : [url isKindOfClass:NSString.class] ? [NSURL URLWithString:url] : nil;
        NSString *scheme = u.scheme.lowercaseString;
        if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
            [UIApplication.sharedApplication openURL:u options:@{} completionHandler:nil];
            [(UIViewController *)self dismissViewControllerAnimated:YES completion:nil];
            return;
        }
    }
    orig_loadURL(self, _cmd, url);
}

#pragma mark - Hook: location spoofing

static CLLocation *OmarSpoofedLocation(void) {
    OmarPrefs *p = [OmarPrefs shared];
    return [[CLLocation alloc]
        initWithCoordinate:CLLocationCoordinate2DMake([p doubleForKey:OmarKeyLocationLat],
                                                      [p doubleForKey:OmarKeyLocationLng])
                  altitude:0 horizontalAccuracy:5 verticalAccuracy:5 timestamp:[NSDate date]];
}

static CLLocation *(*orig_location)(id, SEL);
static CLLocation *omar_location(id self, SEL _cmd) {
    if (OmarEnabled(OmarKeyLocationSpoof)) return OmarSpoofedLocation();
    return orig_location(self, _cmd);
}

static void OmarPushSpoofedTo(CLLocationManager *mgr) {
    id<CLLocationManagerDelegate> d = mgr.delegate;
    if (![d respondsToSelector:@selector(locationManager:didUpdateLocations:)]) return;
    CLLocation *loc = OmarSpoofedLocation();
    dispatch_async(dispatch_get_main_queue(), ^{ [d locationManager:mgr didUpdateLocations:@[ loc ]]; });
}

static void (*orig_startUpdating)(id, SEL);
static void omar_startUpdating(id self, SEL _cmd) {
    orig_startUpdating(self, _cmd);
    if (OmarEnabled(OmarKeyLocationSpoof)) OmarPushSpoofedTo(self);
}

static void (*orig_requestLocation)(id, SEL);
static void omar_requestLocation(id self, SEL _cmd) {
    if (OmarEnabled(OmarKeyLocationSpoof)) { OmarPushSpoofedTo(self); return; }
    orig_requestLocation(self, _cmd);
}

#pragma mark - Feature: app lock (notification-based, no hooks needed)

@interface OmarAppLock : NSObject
@property (nonatomic, strong) UIWindow *lockWindow;
@property (nonatomic, assign) BOOL authenticating;
+ (instancetype)shared;
@end

@implementation OmarAppLock
+ (instancetype)shared {
    static OmarAppLock *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [OmarAppLock new]; });
    return s;
}
- (void)lock {
    if (self.lockWindow) return;
    UIWindowScene *scene = (UIWindowScene *)OmarKeyWindow().windowScene;
    if (!scene) return;
    UIWindow *w = [[UIWindow alloc] initWithWindowScene:scene];
    w.windowLevel = UIWindowLevelAlert + 1;
    UIViewController *vc = [UIViewController new];
    UIVisualEffectView *ev = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]];
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
- (void)unlock { self.lockWindow.hidden = YES; self.lockWindow = nil; }
- (void)authenticate {
    if (self.authenticating || !self.lockWindow) return;
    self.authenticating = YES;
    LAContext *ctx = [LAContext new];
    NSError *err = nil;
    LAPolicy policy = [ctx canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&err]
        ? LAPolicyDeviceOwnerAuthentication : LAPolicyDeviceOwnerAuthenticationWithBiometrics;
    [ctx evaluatePolicy:policy localizedReason:@"افتح إنستقرام" reply:^(BOOL success, NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.authenticating = NO;
            if (success) [self unlock];
        });
    }];
}
@end

#pragma mark - Install

static void OmarInstallHooks(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;

    OmarSwizzle("IGTabBarController",
                @selector(_createAndConfigureTimelineButtonIfNeeded),
                (IMP)omar_timelineButton, &orig_timelineButton);

    OmarSwizzle("IGDirectTypingStatusService",
                @selector(updateOutgoingStatusIsActive:threadKey:threadMetadata:typingStatusType:),
                (IMP)omar_typing, &orig_typing);

    OmarSwizzle("IGDirectVisualMessageScreenshotSafetyLogger",
                @selector(logScreenshotCapturedOnMessage:isRecording:isNudity:),
                (IMP)omar_ssLog, &orig_ssLog);

    OmarSwizzle("IGWebViewController",
                @selector(loadURL:),
                (IMP)omar_loadURL, &orig_loadURL);

    OmarSwizzle("CLLocationManager", @selector(location),
                (IMP)omar_location, &orig_location);
    OmarSwizzle("CLLocationManager", @selector(startUpdatingLocation),
                (IMP)omar_startUpdating, &orig_startUpdating);
    OmarSwizzle("CLLocationManager", @selector(requestLocation),
                (IMP)omar_requestLocation, &orig_requestLocation);
}

// Diagnostic beacon (temporary): proves the dylib loaded, independent of hooks.
static void OmarShowLoadedBeacon(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"Dev | OMAR"
                             message:@"✅ الدايلب محقون ويعمل (بدون جيلبريك).\n(رسالة تشخيص مؤقتة)"
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"تمام" style:UIAlertActionStyleDefault handler:nil]];
        [OmarTopViewController() presentViewController:ac animated:YES completion:nil];
    });
}

__attribute__((constructor))
static void OmarInit(void) {
    // Constructor runs at dylib load — before the app's UI exists. Defer the
    // actual swizzling until the app finishes launching so all IG classes exist.
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        OmarInstallHooks();
    }];
    // App-lock lifecycle (Foundation notifications, no hooks required).
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        if (OmarEnabled(OmarKeyAppLock)) [[OmarAppLock shared] lock];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        if (OmarEnabled(OmarKeyAppLock)) [[OmarAppLock shared] authenticate];
    }];
    // One-time load confirmation.
    static BOOL beaconShown = NO;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        if (beaconShown) return;
        beaconShown = YES;
        OmarShowLoadedBeacon();
    }];
}
