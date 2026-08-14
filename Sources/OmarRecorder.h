//
//  OmarRecorder.h — ReplayKit screen+audio recorder for call/screen capture.
//  Programmer: Omar Al-Enezi (عمر العنزي).
//
//  Records the Instagram screen plus app audio and the microphone, entirely on
//  device — the other party is never notified. Isolated crystal-clear capture of
//  the remote voice is not guaranteed without RTC-level hooks (jailbreak).
//
#import <Foundation/Foundation.h>

@interface OmarRecorder : NSObject
+ (instancetype)shared;
- (void)toggle;          // start if idle, stop (and show save preview) if recording
- (BOOL)isRecording;
@end
