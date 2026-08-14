//
//  Tweak.xm — OmarTweak for Instagram.
//  Programmer: Omar Al-Enezi (عمر العنزي).
//
//  Stage 1 wires up the launcher (long-press the Home tab → settings panel) and
//  the first live feature hook (disable outgoing typing indicator). Remaining
//  features are hooked in the same file, each gated behind its OmarPrefs key.
//
#import <UIKit/UIKit.h>
#import "Sources/OmarPrefs.h"
#import "Sources/OmarSettingsViewController.h"

#pragma mark - Helpers

// Topmost presented VC under the active foreground scene, so we can present the
// settings panel from wherever the user currently is.
static UIViewController *OmarTopViewController(void) {
    UIWindow *keyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:UIWindowScene.class]) {
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
        }
        if (keyWindow) break;
    }
    UIViewController *top = keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

static void OmarPresentSettings(void) {
    OmarSettingsViewController *vc = [[OmarSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [OmarTopViewController() presentViewController:nav animated:YES completion:nil];
}

// Shown exactly once, the first time the tweak ever runs on this install.
static void OmarShowWelcomeIfNeeded(void) {
    OmarPrefs *prefs = [OmarPrefs shared];
    if ([prefs boolForKey:OmarKeyWelcomeShown]) return;
    [prefs setBool:YES forKey:OmarKeyWelcomeShown];

    // Delay so the app's own UI has finished presenting before we pop up.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"Dev | OMAR"
                             message:@"نورت البلس ياوحش 🐺\n"
                                      "أي ميزة تبيها تعال تيليجرام.\n\n"
                                      "ولا تنسى: اضغط على زر البيت ضغطة مطولة ويفتح لك الإعدادات."
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"يا هلا" style:UIAlertActionStyleDefault
                                             handler:nil]];
        ac.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        [OmarTopViewController() presentViewController:ac animated:YES completion:nil];
    });
}

#pragma mark - Launcher: long-press the Home tab button

%hook IGTabBarController

- (void)_createAndConfigureTimelineButtonIfNeeded {
    %orig;
    // The timeline (home) button is the "home button" the user long-presses.
    // Cast to id: Logos only forward-declares IGTabBarController, so a typed
    // instance message would fail — id defers the lookup to runtime (KVC).
    UIView *homeButton = [(id)self valueForKey:@"_timelineButton"];
    if (![homeButton isKindOfClass:UIView.class]) return;

    // Attach exactly once — this method can run again on tab-bar reconfigure.
    for (UIGestureRecognizer *g in homeButton.gestureRecognizers) {
        if ([g.name isEqualToString:@"omarLongPress"]) return;
    }
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(omar_handleLongPress:)];
    lp.name = @"omarLongPress";
    lp.minimumPressDuration = 1.0; // "أكثر من ثانية"
    [homeButton addGestureRecognizer:lp];

    // Now that the tab bar exists, the app UI is up — safe to show the one-time
    // welcome message on the very first launch.
    OmarShowWelcomeIfNeeded();
}

%new
- (void)omar_handleLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) OmarPresentSettings();
}

%end

#pragma mark - Feature: disable screenshot notifications (تعطيل اشعارات لقطة الشاشة)

// The safety logger is what fires the "X took a screenshot" event for ephemeral
// DM media. Suppressing the capture log stops the other party being notified.
%hook IGDirectVisualMessageScreenshotSafetyLogger

- (void)logScreenshotCapturedOnMessage:(id)message
                           isRecording:(BOOL)isRecording
                              isNudity:(id)isNudity {
    if ([[OmarPrefs shared] enabled:OmarKeyNoScreenshotNotify]) return; // swallow
    %orig;
}

%end

#pragma mark - Feature: open links in Safari (فتح الروابط في سفاري)

// Instagram's in-app browser is IGWebViewController. When the user opts out, we
// hand the URL to the system (Safari) and dismiss the empty in-app browser.
%hook IGWebViewController

- (void)loadURL:(id)url {
    if ([[OmarPrefs shared] enabled:OmarKeyLinksInSafari]) {
        NSURL *u = [url isKindOfClass:NSURL.class] ? url
                 : [url isKindOfClass:NSString.class] ? [NSURL URLWithString:url] : nil;
        if (u && ([u.scheme.lowercaseString isEqualToString:@"http"] ||
                  [u.scheme.lowercaseString isEqualToString:@"https"])) {
            [UIApplication.sharedApplication openURL:u options:@{} completionHandler:nil];
            [(UIViewController *)self dismissViewControllerAnimated:YES completion:nil];
            return;
        }
    }
    %orig;
}

%end

#pragma mark - Feature: disable outgoing typing indicator (تعطيل مؤشر الكتابة)

%hook IGDirectTypingStatusService

- (void)updateOutgoingStatusIsActive:(BOOL)isActive
                           threadKey:(id)threadKey
                      threadMetadata:(id)threadMetadata
                     typingStatusType:(NSInteger)type {
    if ([[OmarPrefs shared] enabled:OmarKeyNoTyping]) {
        // Force the "stopped typing" path so no active-typing signal is ever sent.
        %orig(NO, threadKey, threadMetadata, type);
        return;
    }
    %orig;
}

%end
