//
//  OmarPrefs.m — see OmarPrefs.h.
//  Programmer: Omar Al-Enezi (عمر العنزي).
//
#import "OmarPrefs.h"

NSString *const OmarKeyGhostStory        = @"omar_ghost_story";
NSString *const OmarKeyNoAutoAdvance      = @"omar_no_auto_advance";
NSString *const OmarKeyStickerVideo       = @"omar_sticker_video";
NSString *const OmarKeyGhostLive          = @"omar_ghost_live";
NSString *const OmarKeyKeepUnsent         = @"omar_keep_unsent";
NSString *const OmarKeyNoTyping           = @"omar_no_typing";
NSString *const OmarKeyNoScreenshotNotify = @"omar_no_ss_notify";
NSString *const OmarKeyNoScreenshotGuard  = @"omar_no_ss_guard";
NSString *const OmarKeyNoMediaReplayFlag  = @"omar_no_replay_flag";
NSString *const OmarKeyDownloadVoice      = @"omar_dl_voice";
NSString *const OmarKeyVideoAsVoice       = @"omar_video_as_voice";
NSString *const OmarKeyLinksInSafari      = @"omar_links_safari";
NSString *const OmarKeyAppLock            = @"omar_app_lock";
NSString *const OmarKeyLocationSpoof      = @"omar_location_spoof";
NSString *const OmarKeyCallRecord         = @"omar_call_record";
NSString *const OmarKeySaveProfilePic     = @"omar_save_pfp";
NSString *const OmarKeyMediaSave          = @"omar_media_save";

NSString *const OmarKeyLocationLat        = @"omar_location_lat";
NSString *const OmarKeyLocationLng        = @"omar_location_lng";
NSString *const OmarKeyWelcomeShown       = @"omar_welcome_shown";

// Private suite so our keys never collide with Instagram's own defaults.
static NSString *const kSuiteName = @"com.omar.igtweak";

@implementation OmarPrefs {
    NSUserDefaults *_defaults;
}

+ (instancetype)shared {
    static OmarPrefs *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:kSuiteName];
    }
    return self;
}

- (BOOL)boolForKey:(NSString *)key   { return [_defaults boolForKey:key]; }
- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [_defaults setBool:value forKey:key];
    [_defaults synchronize];
}
- (double)doubleForKey:(NSString *)key { return [_defaults doubleForKey:key]; }
- (void)setDouble:(double)value forKey:(NSString *)key {
    [_defaults setDouble:value forKey:key];
    [_defaults synchronize];
}

- (BOOL)enabled:(NSString *)key { return [_defaults boolForKey:key]; }

@end
