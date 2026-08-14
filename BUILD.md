# بناء وحقن OmarTweak (Dev | OMAR)

## أ) البناء عبر GitHub Actions (المضمون — بدون ماك)
1. أنشئ ريبو جديد على GitHub (خاص).
2. ارفع **محتويات مجلد `OmarTweak`** في جذر الريبو (بحيث يكون `Makefile` و`.github/` في الجذر).
3. ادخل تبويب **Actions** → شغّل *Build OmarTweak dylib* (أو ادفع أي تحديث).
4. بعد نجاح البناء، نزّل الـartifact **`OmarTweak-dylib`** — بداخله `OmarTweak.dylib`.

## ب) الحقن في IPA غير مكسور الحماية
باستخدام أدواتك في `iOS_Patcher_Suite`:
```bash
# 1) أضف الدايلب لمجلد Frameworks داخل الـ.app ثم اربطه بالتنفيذي
insert_dylib --inplace --weak @executable_path/Frameworks/OmarTweak.dylib Payload/Instagram.app/Instagram
cp OmarTweak.dylib Payload/Instagram.app/Frameworks/
# 2) أعد التوقيع
zsign -k cert.p12 -p PASS -m profile.mobileprovision -o Instagram-Omar.ipa Payload
```
> ملاحظة: الـMakefile مضبوط لبناء dylib عادي (غير rootless) مناسب للحقن في IPA.
> على جهاز مكسور الحماية استخدم `make package` وثبّت الـ.deb مباشرة.

## ج) لو صار خطأ بناء
انسخ لي **كامل لوق خطوة Build من Actions** وأنا أحلّه من الجذر (توقيع ميثود ناقص،
SDK، أو Logos syntax). لا تكتفي بالسطر الأخير — الرسائل قبله هي المفتاح.
