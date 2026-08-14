//
//  OmarDiagnostics.h — a live record of which hooks attached at runtime.
//  Programmer: Omar Al-Enezi (عمر العنزي).
//
//  Because Instagram's class names drift between versions, a hook can silently
//  fail to attach when a class/selector isn't found in the installed build.
//  This collects a human-readable ✅/❌ line per hook so the settings panel can
//  show it — turning the on-device panel into our only debugging window.
//
#import <Foundation/Foundation.h>

@interface OmarDiagnostics : NSObject
+ (NSMutableArray<NSString *> *)report;      // ordered ✅/❌ lines
+ (void)log:(NSString *)line;                // append one line
@end
