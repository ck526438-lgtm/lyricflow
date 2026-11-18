"""Applique les réglages LyricFlow aux dossiers android/ et ios/ générés par `flutter create`."""
import os
import plistlib
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

# --- Android ---------------------------------------------------------------
man_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(man_path):
    man = open(man_path, encoding="utf-8").read()
    man = re.sub(r'android:label="[^"]*"', 'android:label="LyricFlow"', man, count=1)
    perms = [
        '<uses-permission android:name="android.permission.INTERNET" />',
        '<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />',
        '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />',
    ]
    for p in perms:
        name = re.search(r'android:name="([^"]+)"', p).group(1)
        if name not in man:
            man = man.replace("<application", p + "\n    <application", 1)
    open(man_path, "w", encoding="utf-8").write(man)
    print("Android patché")

# --- iOS -------------------------------------------------------------------
plist_path = "ios/Runner/Info.plist"
if os.path.exists(plist_path):
    with open(plist_path, "rb") as f:
        pl = plistlib.load(f)
    pl["CFBundleDisplayName"] = "LyricFlow"
    pl["CFBundleName"] = "LyricFlow"
    pl["NSAppleMusicUsageDescription"] = "LyricFlow lit tes fichiers audio pour synchroniser les paroles."
    pl["UIFileSharingEnabled"] = True
    pl["LSSupportsOpeningDocumentsInPlace"] = True
    pl["UIBackgroundModes"] = ["audio"]
    with open(plist_path, "wb") as f:
        plistlib.dump(pl, f)
    print("iOS patché")
