# OmarTweak — خارطة الطريق (Instagram)

المبرمج: عمر العنزي. الحقن على تطبيق `com.burbn.instagram`.

## ✅ منفّذ في الكود (جاهز للبناء)
- **اللانشر**: ضغط مطوّل (>1s) على زر الهوم → لوحة إعدادات. `IGTabBarController._createAndConfigureTimelineButtonIfNeeded` + `_timelineButton`.
- **لوحة الإعدادات + خانة المطور**: `OmarSettingsViewController` (Dev | OMAR، تويتر fq_1e، تيليجرام o52lo).
- **رسالة الترحيب** لأول مرة.
- **تعطيل مؤشر الكتابة**: `IGDirectTypingStatusService -updateOutgoingStatusIsActive:...`.
- **تعطيل إشعارات لقطة الشاشة**: `IGDirectVisualMessageScreenshotSafetyLogger -logScreenshotCapturedOnMessage:...`.
- **فتح الروابط في سفاري**: `IGWebViewController -loadURL:`.
- **تغيير الموقع**: `CLLocationManager` (getter + delegate push) — API قياسي.
- **تمكين قفل التطبيق**: `LocalAuthentication` + نافذة تغطية — API قياسي.

> ملاحظة صدق: الخطافات الداخلية لإنستقرام أعلاه مبنية على تواقيع الهيدرات، لكنها
> تحتاج **تأكيد سلوكها على جهاز حقيقي**. الاثنان الأخيران (الموقع/القفل) قياسيان.

## 🔜 المرحلة 2 — الخطافات المتبقية (مع نقاط الربط المكتشفة)

| # | الخاصية | الكلاس/الميثود المرشّح | الملاحظة |
|---|---------|----------------------|----------|
| 1 | مشاهدة القصة بشكل متخفي | `IGStorySeenStateUploader` / `IGStorySeenStateStore.addSeenDateForStoryItem:reelPK:` | نمنع رفع حالة "شوهد" للسيرفر |
| 2 | عدم الانتقال للقصة التالية تلقائياً | مشغّل الـReel viewer (نبحث `IGReelViewer*` auto-advance timer) | نلغي مؤقت التقدم |
| 3 | مشاهدة البث بشكل متخفي | `IGLiveBroadcastViewer*` / join-event | نمنع حدث انضمام المشاهد |
| 4 | إبقاء رسائل الخاص المحذوفة | `IGDirectMessageUnsend*` / تطبيق mutation الحذف | نتجاهل حذف الرسالة محلياً |
| 5 | تعطيل إشعارات لقطة الشاشة | `IGDirectVisualMessageScreenshotSafetyLogger` / `IGDirectThreadViewScreenshotFeatureController` | نمنع إرسال إشعار الـscreenshot |
| 6 | تعطيل حماية لقطة الشاشة | `FBScreenshotCapturer` / view-once guard | نلغي منع التصوير |
| 7 | تعطيل الوسائط المعاد تشغيلها | منطق "played" للصوتيات/الوسائط | نمنع تعليم "أعيد التشغيل" |
| 8 | تنزيل الرسائل الصوتية | `IGDirectVisualMessage`/voice cell | نضيف زر حفظ |
| 9 | رفع فيديو كرسالة صوتية | مسار رفع الـvoice message | تحويل الفيديو لـaudio container |
| 10 | فتح الروابط في سفاري | `IGWebViewController` / `MAIInAppBrowser` | نعيد التوجيه لـ`-[UIApplication openURL:]` |
| 11 | تمكين قفل للتطبيق | overlay على `applicationDidBecomeActive` | Face ID/Passcode gate |
| 12 | تغيير الموقع | `CLLocationManager` hook (نعيد استخدام منطق LSpoof) | إحداثيات من اللوحة |
| 13 | تسجيل المكالمة عبر الانستا | مسار RTC للمكالمات | معقّد — يحتاج بحث عميق |
| 14 | حفظ صورة البروفايل | `IGProfileHeader*` long-press | حفظ full-res للاستوديو |
| 15 | تمكين إضافة فيديو من معرض الملصقات | sticker gallery picker | رفع قيد نوع الوسائط |

## البناء
```bash
export THEOS=~/theos
make package    # أو: make do  للتثبيت المباشر على جهاز مكسور الحماية
```
للـIPA غير المكسور: نبني الـdylib ثم نحقنه بـ`zsign` + `insert_dylib` (متوفر عندك في iOS_Patcher_Suite).
