//
//  OmarPrefs.h — central preference store for the OmarTweak Instagram tweak.
//  Programmer: Omar Al-Enezi (عمر العنزي).
//
//  Every feature toggle is a BOOL keyed by the constants below and persisted in
//  a private NSUserDefaults suite so the settings panel and the hooks agree.
//
#import <Foundation/Foundation.h>

// Preference keys. Kept as extern NSStrings so a typo is a link error, not a
// silently-missing toggle.
extern NSString *const OmarKeyGhostStory;        // مشاهدة القصة بشكل متخفي
extern NSString *const OmarKeyNoAutoAdvance;      // عدم الانتقال للقصة التالية تلقائيا
extern NSString *const OmarKeyStickerVideo;       // تمكين اضافة فيديو من معرض الملصقات
extern NSString *const OmarKeyGhostLive;          // مشاهدة البث بشكل متخفي
extern NSString *const OmarKeyKeepUnsent;         // ابقاء رسائل الخاص المحذوفة
extern NSString *const OmarKeyNoTyping;           // تعطيل مؤشر الكتابة
extern NSString *const OmarKeyNoScreenshotNotify; // تعطيل اشعارات لقطة الشاشة
extern NSString *const OmarKeyNoScreenshotGuard;  // تعطيل حماية لقطة الشاشة
extern NSString *const OmarKeyNoMediaReplayFlag;  // تعطيل الوسائط المعاد تشغيلها
extern NSString *const OmarKeyDownloadVoice;      // تنزيل الرسائل الصوتية
extern NSString *const OmarKeyVideoAsVoice;       // رفع فيديو كرسالة صوتية
extern NSString *const OmarKeyLinksInSafari;      // فتح الروابط في سفاري
extern NSString *const OmarKeyAppLock;            // تمكين قفل للتطبيق
extern NSString *const OmarKeyLocationSpoof;      // تغيير الموقع
extern NSString *const OmarKeyCallRecord;         // تسجيل المكالمة عبر الانستا
extern NSString *const OmarKeySaveProfilePic;     // حفظ صورة البروفايل
extern NSString *const OmarKeyMediaSave;          // تنزيل الصورة بالضغط المطوّل

// Location spoof coordinates (only meaningful when OmarKeyLocationSpoof is on).
extern NSString *const OmarKeyLocationLat;
extern NSString *const OmarKeyLocationLng;

// One-shot flag: set the first time the welcome message is shown.
extern NSString *const OmarKeyWelcomeShown;

@interface OmarPrefs : NSObject

+ (instancetype)shared;

// Generic accessors used by both the UI and the hooks.
- (BOOL)boolForKey:(NSString *)key;
- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (double)doubleForKey:(NSString *)key;
- (void)setDouble:(double)value forKey:(NSString *)key;

// Fast convenience so hot-path hooks avoid a string lookup where it matters.
- (BOOL)enabled:(NSString *)key;

@end
