//
//  OmarSettingsViewController.m — see header.
//  Programmer: Omar Al-Enezi (عمر العنزي).
//
#import "OmarSettingsViewController.h"
#import "OmarPrefs.h"
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

// One row = one toggle. `key` binds it to OmarPrefs; a nil key means the row is
// an action (e.g. open the location picker) handled in didSelectRow.
// OmarRowLink opens a URL; OmarRowInfo is a plain, non-interactive text row.
typedef NS_ENUM(NSInteger, OmarRowKind) { OmarRowToggle, OmarRowAction, OmarRowLink, OmarRowInfo };

@interface OmarRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *key;     // OmarPrefs key, nil for actions
@property (nonatomic, assign) OmarRowKind kind;
@property (nonatomic, copy) NSString *actionId; // for OmarRowAction rows
@property (nonatomic, copy) NSString *detail;   // subtitle (e.g. @username)
@property (nonatomic, copy) NSString *symbol;   // SF Symbol name for the icon
@property (nonatomic, copy) NSString *urlApp;   // app-scheme URL (twitter:// …)
@property (nonatomic, copy) NSString *urlWeb;   // https fallback
@end
@implementation OmarRow @end

@interface OmarSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSArray<OmarRow *> *rows;
@end
@implementation OmarSection @end

@implementation OmarSettingsViewController {
    NSArray<OmarSection *> *_sections;
}

static OmarRow *Toggle(NSString *title, NSString *key) {
    OmarRow *r = [OmarRow new];
    r.title = title; r.key = key; r.kind = OmarRowToggle;
    return r;
}
static OmarRow *Action(NSString *title, NSString *actionId) {
    OmarRow *r = [OmarRow new];
    r.title = title; r.actionId = actionId; r.kind = OmarRowAction;
    return r;
}
static OmarRow *Info(NSString *title, NSString *detail, NSString *symbol) {
    OmarRow *r = [OmarRow new];
    r.title = title; r.detail = detail; r.symbol = symbol; r.kind = OmarRowInfo;
    return r;
}
static OmarRow *Link(NSString *title, NSString *detail, NSString *symbol,
                     NSString *urlApp, NSString *urlWeb) {
    OmarRow *r = [OmarRow new];
    r.title = title; r.detail = detail; r.symbol = symbol; r.kind = OmarRowLink;
    r.urlApp = urlApp; r.urlWeb = urlWeb;
    return r;
}
static OmarSection *Section(NSString *title, NSArray<OmarRow *> *rows) {
    OmarSection *s = [OmarSection new];
    s.title = title; s.rows = rows;
    return s;
}

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        [self buildModel];
    }
    return self;
}

- (void)buildModel {
    _sections = @[
        Section(@"القصص والبث", @[
            Toggle(@"مشاهدة القصة بشكل متخفي",          OmarKeyGhostStory),
            Toggle(@"عدم الانتقال للقصة التالية تلقائياً", OmarKeyNoAutoAdvance),
            Toggle(@"مشاهدة البث بشكل متخفي",            OmarKeyGhostLive),
        ]),
        Section(@"الرسائل والخاص", @[
            Toggle(@"إبقاء رسائل الخاص المحذوفة",         OmarKeyKeepUnsent),
            Toggle(@"تعطيل مؤشر الكتابة",                OmarKeyNoTyping),
            Toggle(@"تعطيل إشعارات لقطة الشاشة",          OmarKeyNoScreenshotNotify),
            Toggle(@"تعطيل حماية لقطة الشاشة",           OmarKeyNoScreenshotGuard),
            Toggle(@"تعطيل الوسائط المعاد تشغيلها",       OmarKeyNoMediaReplayFlag),
            Toggle(@"تنزيل الرسائل الصوتية",             OmarKeyDownloadVoice),
            Toggle(@"رفع فيديو كرسالة صوتية",            OmarKeyVideoAsVoice),
        ]),
        Section(@"الوسائط والمرفقات", @[
            Toggle(@"تمكين إضافة فيديو من معرض الملصقات",  OmarKeyStickerVideo),
            Toggle(@"حفظ صورة البروفايل",               OmarKeySaveProfilePic),
            Toggle(@"تسجيل المكالمة عبر الانستا",         OmarKeyCallRecord),
        ]),
        Section(@"عام", @[
            Toggle(@"فتح الروابط في سفاري",              OmarKeyLinksInSafari),
            Toggle(@"تمكين قفل للتطبيق",                OmarKeyAppLock),
            Toggle(@"تغيير الموقع",                     OmarKeyLocationSpoof),
            Action(@"تحديد إحداثيات الموقع…",            @"pick_location"),
        ]),
        Section(@"المطور", @[
            // "bird.fill" / "paperplane.fill" are built-in SF Symbols so the
            // tweak needs no bundled image assets to show recognizable icons.
            Info(@"Dev | OMAR", nil, @"person.crop.circle.fill"),
            Link(@"تويتر (X)", @"@fq_1e", @"bird.fill",
                 @"twitter://user?screen_name=fq_1e", @"https://x.com/fq_1e"),
            Link(@"تيليجرام", @"@o52lo", @"paperplane.fill",
                 @"tg://resolve?domain=o52lo", @"https://t.me/o52lo"),
        ]),
    ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Dev | OMAR";
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self action:@selector(dismissSelf)];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - Table data

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _sections.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return _sections[s].rows.count;
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return _sections[s].title;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    OmarRow *row = _sections[ip.section].rows[ip.row];
    UITableViewCellStyle style =
        (row.detail.length ? UITableViewCellStyleValue1 : UITableViewCellStyleDefault);
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:nil];
    cell.textLabel.text = row.title;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.text = row.detail;
    cell.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;

    if (row.symbol.length) {
        cell.imageView.image = [UIImage systemImageNamed:row.symbol];
        cell.imageView.tintColor = UIColor.labelColor;
    }

    switch (row.kind) {
        case OmarRowToggle: {
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [[OmarPrefs shared] boolForKey:row.key];
            objc_setAssociatedObject(sw, "omarKey", row.key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [sw addTarget:self action:@selector(switchChanged:)
                 forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
        case OmarRowAction:
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case OmarRowLink:
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case OmarRowInfo:
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    NSString *key = objc_getAssociatedObject(sw, "omarKey");
    [[OmarPrefs shared] setBool:sw.isOn forKey:key];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    OmarRow *row = _sections[ip.section].rows[ip.row];
    if (row.kind == OmarRowAction && [row.actionId isEqualToString:@"pick_location"]) {
        [self promptForCoordinates];
    } else if (row.kind == OmarRowLink) {
        [self openURLApp:row.urlApp web:row.urlWeb];
    }
}

// Prefer the native app scheme (opens the Twitter/Telegram app directly); fall
// back to the https link in Safari when the app isn't installed.
- (void)openURLApp:(NSString *)appURL web:(NSString *)webURL {
    UIApplication *app = UIApplication.sharedApplication;
    NSURL *scheme = [NSURL URLWithString:appURL];
    if (scheme && [app canOpenURL:scheme]) {
        [app openURL:scheme options:@{} completionHandler:nil];
    } else {
        [app openURL:[NSURL URLWithString:webURL] options:@{} completionHandler:nil];
    }
}

// Minimal lat/lng entry. A real map picker can replace this later; the tweak
// only needs the two numbers to feed CoreLocation.
- (void)promptForCoordinates {
    OmarPrefs *p = [OmarPrefs shared];
    UIAlertController *ac =
        [UIAlertController alertControllerWithTitle:@"تحديد الموقع"
                                            message:@"أدخل خط العرض وخط الطول"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Latitude";
        tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        double v = [p doubleForKey:OmarKeyLocationLat];
        if (v != 0) tf.text = [NSString stringWithFormat:@"%f", v];
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Longitude";
        tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        double v = [p doubleForKey:OmarKeyLocationLng];
        if (v != 0) tf.text = [NSString stringWithFormat:@"%f", v];
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [p setDouble:[ac.textFields[0].text doubleValue] forKey:OmarKeyLocationLat];
            [p setDouble:[ac.textFields[1].text doubleValue] forKey:OmarKeyLocationLng];
        }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
