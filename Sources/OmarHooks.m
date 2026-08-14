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
#import <string.h>
#import "OmarPrefs.h"
#import "OmarSettingsViewController.h"
#import "OmarDiagnostics.h"

#pragma mark - Diagnostics

@implementation OmarDiagnostics
+ (NSMutableArray<NSString *> *)report {
    static NSMutableArray *r; static dispatch_once_t t;
    dispatch_once(&t, ^{ r = [NSMutableArray array]; });
    return r;
}
+ (void)log:(NSString *)line { [[self report] addObject:line]; }
@end

#pragma mark - Swizzle helper

// Replace cls's instance method `sel` with `repl`, saving the original IMP into
// *store. No-op (safely) if the class or method isn't present in this IG build.
// Records the outcome for the on-device diagnostics panel.
static BOOL OmarSwizzle(const char *className, SEL sel, IMP repl, void *store) {
    NSString *label = [NSString stringWithFormat:@"%s#%@", className, NSStringFromSelector(sel)];
    Class cls = objc_getClass(className);
    if (!cls) {
        [OmarDiagnostics log:[@"❌ كلاس مفقود: " stringByAppendingString:@(className)]];
        return NO;
    }
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        [OmarDiagnostics log:[@"⚠️ ميثود مفقود: " stringByAppendingString:label]];
        return NO;
    }
    *(IMP *)store = method_getImplementation(m);
    method_setImplementation(m, repl);
    [OmarDiagnostics log:[@"✅ " stringByAppendingString:label]];
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
                                      "لفتح الإعدادات: ادخل إعدادات إنستقرام وبتلقى زر \"Dev | OMAR\" فوق،\n"
                                      "أو هز الجوال في أي وقت."
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"يا هلا" style:UIAlertActionStyleDefault handler:nil]];
        ac.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        [OmarTopViewController() presentViewController:ac animated:YES completion:nil];
    });
}

#pragma mark - Action target

// A singleton owns the "open panel" action for bar buttons and gestures.
@interface OmarGestureTarget : NSObject
+ (instancetype)shared;
- (void)openSettings;
@end
@implementation OmarGestureTarget
+ (instancetype)shared {
    static OmarGestureTarget *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [OmarGestureTarget new]; });
    return s;
}
- (void)openSettings { OmarPresentSettings(); }
@end

#pragma mark - Launcher 1: "Dev | OMAR" button inside Instagram's settings

// Instagram's settings landing is server-driven (Bloks), so there is no stable
// class to inject a row into. Instead we watch every navigation push and, when
// the pushed screen looks like a settings/options page, append a "Dev | OMAR"
// button to its navigation bar. Version-independent — matches by class name.
static void (*orig_push)(id, SEL, UIViewController *, BOOL);
static void omar_push(id self, SEL _cmd, UIViewController *vc, BOOL animated) {
    orig_push(self, _cmd, vc, animated);
    if (!vc) return;
    NSString *name = NSStringFromClass(vc.class);
    if (![name containsString:@"Settings"] && ![name containsString:@"Option"]) return;
    // Delay so Instagram has already set its own bar buttons; we append to them.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSMutableArray *items = [vc.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray array];
        for (UIBarButtonItem *it in items)
            if ([it.title isEqualToString:@"Dev | OMAR"]) return; // already added
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Dev | OMAR"
            style:UIBarButtonItemStylePlain target:[OmarGestureTarget shared]
            action:@selector(openSettings)];
        [items addObject:item];
        vc.navigationItem.rightBarButtonItems = items;
    });
}

#pragma mark - Launcher 2: shake to open (safety net)

// A guaranteed fallback so the panel is always reachable while we refine the
// settings-button match. Added directly to UIWindow (not UIResponder) so we
// never disturb the global responder chain.
static void omar_motionEnded(id self, SEL _cmd, NSInteger motion, UIEvent *event) {
    if (motion == UIEventSubtypeMotionShake) OmarPresentSettings();
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

// Pull a URL out of an in-app-browser view controller by trying the property
// names Instagram/Meta browsers commonly expose. Wrapped in @try since KVC on
// an unknown key throws.
static NSURL *OmarExtractURL(id vc) {
    NSArray *keys = @[ @"url", @"URL", @"currentURL", @"initialURL",
                       @"initialURLString", @"redirectURL", @"requestURL" ];
    for (NSString *key in keys) {
        @try {
            id v = [vc valueForKey:key];
            if ([v isKindOfClass:NSURL.class]) return v;
            if ([v isKindOfClass:NSString.class]) return [NSURL URLWithString:v];
        } @catch (__unused NSException *e) {}
    }
    return nil;
}

static BOOL OmarLooksLikeBrowser(NSString *name) {
    return [name containsString:@"InAppBrowser"] || [name containsString:@"WebViewController"]
        || [name containsString:@"Browser"];
}

// Primary route: intercept the presentation of any in-app browser and hand the
// URL to Safari instead. Version-independent — matches by class-name shape.
static void (*orig_present)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void omar_present(id self, SEL _cmd, UIViewController *vc, BOOL animated, void (^completion)(void)) {
    if (OmarEnabled(OmarKeyLinksInSafari) && vc && OmarLooksLikeBrowser(NSStringFromClass(vc.class))) {
        NSURL *u = OmarExtractURL(vc);
        if ([u.scheme.lowercaseString hasPrefix:@"http"]) {
            [UIApplication.sharedApplication openURL:u options:@{} completionHandler:nil];
            if (completion) completion();
            return; // skip the in-app browser entirely
        }
    }
    orig_present(self, _cmd, vc, animated, completion);
}

// Secondary route (kept as a fallback for builds that use IGWebViewController).
static void (*orig_loadURL)(id, SEL, id);
static void omar_loadURL(id self, SEL _cmd, id url) {
    if (OmarEnabled(OmarKeyLinksInSafari)) {
        NSURL *u = [url isKindOfClass:NSURL.class] ? url
                 : [url isKindOfClass:NSString.class] ? [NSURL URLWithString:url] : nil;
        if ([u.scheme.lowercaseString hasPrefix:@"http"]) {
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

#pragma mark - Class discovery (find the real names in THIS IG build)

// Log every runtime class whose name contains one of the feature keywords, so
// we learn the exact class names used by the installed Instagram version.
static void OmarScanClasses(void) {
    const char *needles[] = {
        // Round 2 keywords — hunt the still-missing feature targets.
        "ReelViewer", "StoryViewer", "ReelViewController", "ItemSeen",
        "DirectVisualMessage", "MediaViewController", "PhotoViewController",
        "FeedItemPhoto", "ProfileImageOptions", "LiveViewer", "Reshare", NULL
    };
    unsigned int count = 0;
    Class *all = objc_copyClassList(&count);
    for (int k = 0; needles[k]; k++) {
        int hits = 0;
        [OmarDiagnostics log:[NSString stringWithFormat:@"— بحث: %s —", needles[k]]];
        for (unsigned int i = 0; i < count && hits < 6; i++) {
            const char *n = class_getName(all[i]);
            if (n && strstr(n, needles[k])) {
                [OmarDiagnostics log:[@"   • " stringByAppendingString:@(n)]];
                hits++;
            }
        }
        if (!hits) [OmarDiagnostics log:@"   (لا يوجد)"];
    }
    free(all);
}

#pragma mark - Install

static void OmarInstallHooks(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;

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

    // Open links in Safari: intercept in-app browser presentation.
    OmarSwizzle("UIViewController", @selector(presentViewController:animated:completion:),
                (IMP)omar_present, &orig_present);

    // Launcher 1: inject the "Dev | OMAR" button into settings screens.
    OmarSwizzle("UINavigationController", @selector(pushViewController:animated:),
                (IMP)omar_push, &orig_push);

    // Launcher 2: shake-to-open. Add the method directly to UIWindow so we don't
    // touch UIResponder globally. If UIWindow already defines it, swizzle instead.
    Class winCls = objc_getClass("UIWindow");
    if (winCls && !class_addMethod(winCls, @selector(motionEnded:withEvent:),
                                   (IMP)omar_motionEnded, "v@:q@")) {
        Method m = class_getInstanceMethod(winCls, @selector(motionEnded:withEvent:));
        if (m) method_setImplementation(m, (IMP)omar_motionEnded);
    }
    [OmarDiagnostics log:@"✅ الهز (shake) + زر الإعدادات"];

    // Discover the real Instagram class names in this installed version.
    OmarScanClasses();
}

__attribute__((constructor))
static void OmarInit(void) {
    // Constructor runs at dylib load — before the app's UI exists. Defer the
    // actual swizzling until the app finishes launching so all IG classes exist.
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        OmarInstallHooks();
    }];
    // On every foreground: (re)attach the launcher to the current key window and
    // install the feature swizzles. didBecomeActive fires after the UI exists,
    // so the window and all Instagram classes are guaranteed present.
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        OmarInstallHooks();
        OmarShowWelcomeIfNeeded();
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
}
