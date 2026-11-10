# BizPilot AI — Google Play Store Deployment & Launch Guide
*(Roman Urdu & English Instructions)*

---

## 📁 Release Kit Overview (Kya Kahan Hai)

Aapke project me complete ready-to-upload Play Store Kit generate ho chuka hai:

```
BizPilotAI/
└── playstore_release_kit/
    ├── app_bundle/                 # Google Play upload file (.aab) yahan aati hai
    ├── graphics/
    │   ├── app_icon_512x512.png    # Google Play Store Icon (512x512)
    │   └── feature_graphic_1024x500.png # Store Banner (1024x500)
    ├── store_listing/
    │   ├── APP_TITLE.txt           # Play Store Name (BizPilot AI: POS & Khata)
    │   ├── SHORT_DESCRIPTION.txt   # 80 characters short description
    │   ├── FULL_DESCRIPTION.md    # Rich formatted store description
    │   └── TAGS_AND_CATEGORIES.txt # Category: Business
    ├── legal_and_compliance/
    │   ├── privacy_policy.html     # Live privacy policy document
    │   └── DATA_SAFETY_ANSWERS.md  # Google Play Console Data Safety form answers
    ├── signing_credentials/
    │   ├── bizpilot_upload_keystore.jks # Secure production signing key
    │   └── CREDENTIALS_BACKUP.txt  # Keystore passwords backup
    └── build_playstore_bundle.bat  # 1-Click build script (.aab & .apk)
```

---

## 🚀 1-Click Production Build Run Karne Ka Tareeqa

1. Apne computer me `playstore_release_kit\build_playstore_bundle.bat` file par double click karein.
2. Script automatically:
   - Dependencies fetch karega.
   - Google Play Store ke liye **Signed `.aab` (Android App Bundle)** banayega.
   - Direct testing ke liye **Signed `.apk`** generate karega.
   - Dono files ko `playstore_release_kit\app_bundle\` me copy kar dega!

---

## 📲 Google Play Console Upload Steps

1. **Google Play Console** me jayein aur "Create app" par click karein.
2. **App Name:** `BizPilot AI: POS & Khata` (from `store_listing/APP_TITLE.txt`).
3. **App Details:**
   - Short description: `store_listing/SHORT_DESCRIPTION.txt` copy karein.
   - Full description: `store_listing/FULL_DESCRIPTION.md` copy karein.
4. **Graphics Upload:**
   - App icon: `graphics/app_icon_512x512.png` upload karein.
   - Feature graphic: `graphics/feature_graphic_1024x500.png` upload karein.
   - Phone Screenshots: Phone par app open karke Dashboard, POS, aur Khata ke 3-4 screenshots le kar upload karein.
5. **App Bundle Upload:**
   - **Production > Create new release** me jayein.
   - `playstore_release_kit/app_bundle/app-release.aab` drag and drop karein.
6. **Data Safety Form:**
   - `legal_and_compliance/DATA_SAFETY_ANSWERS.md` ke mutabiq form fill karein.
   - Privacy Policy link me `privacy_policy.html` provide karein.
7. **Submit for Review!** 🎉
