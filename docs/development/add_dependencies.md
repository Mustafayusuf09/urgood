# Adding Firebase Crashlytics and RevenueCat Dependencies

## Steps to add dependencies in Xcode:

### 1. Add Firebase Crashlytics
1. Open `urgood.xcodeproj` in Xcode
2. Go to File → Add Package Dependencies
3. Search for: `https://github.com/firebase/firebase-ios-sdk`
4. Select "FirebaseCrashlytics" from the list
5. Click "Add Package"

### 2. Add RevenueCat
1. Go to File → Add Package Dependencies
2. Search for: `https://github.com/RevenueCat/purchases-ios`
3. Select "RevenueCat" from the list
4. Click "Add Package"

### 3. Update Build Phases (for Crashlytics)
1. Select your target
2. Go to Build Phases
3. Add a new "Run Script Phase"
4. Add this script:
```bash
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```
5. Add input files:
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
```

### 4. Update Info.plist
Add this to your Info.plist:
```xml
<key>FirebaseCrashlyticsCollectionEnabled</key>
<true/>
```

## Alternative: Use Swift Package Manager directly

If you prefer to add dependencies programmatically, you can add this to your Package.swift or use the Package Dependencies section in Xcode project settings.

## Current Firebase Dependencies Already Added:
- ✅ FirebaseCore
- ✅ FirebaseAuth  
- ✅ FirebaseFirestore
- ✅ FirebaseAnalytics

## Dependencies to Add:
- ❌ FirebaseCrashlytics
- ❌ RevenueCat
