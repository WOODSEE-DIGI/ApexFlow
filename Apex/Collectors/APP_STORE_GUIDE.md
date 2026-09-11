# Apex - Mac App Store Submission Guide

## 🎯 Overview
Apex is a native macOS system monitor built with Swift 6 / SwiftUI for macOS 14+.

**App Store Requirements:**
- ✅ Sandboxed build (using `Apex-AppStore.entitlements`)
- ✅ Embedded privileged helper (`ApexHelper` via SMAppService)
- ✅ XPC for privileged operations (process killing)
- ⚠️ Issues to resolve before submission (see below)

---

## 📋 Pre-Submission Checklist

### 1. Required Assets

- [ ] **App Icon** - Required in all sizes (16x16 to 512x512 @2x)
  - Create in `Assets.xcassets/AppIcon.appiconset`
  - Must be macOS-specific (no transparency, square with rounded corners)
  - Tool: [https://www.appicon.co](https://www.appicon.co) or SF Symbols app

- [ ] **App Store Screenshots** (at least 2-3 required)
  - Recommended sizes: 1280x800, 1440x900, or 2880x1800 (Retina)
  - Show main panels: CPU, Memory, Network, Connectivity, Processes
  - Use `Cmd+Shift+4` or screenshot tool

- [ ] **App Description** (for App Store Connect)
  - Short: "Professional system monitor for macOS. btop replacement."
  - Long: Highlight features (real-time monitoring, MIDI/OSC support, etc.)

---

### 2. Code Signing & Provisioning

**Requirements:**
- [ ] Apple Developer account ($99/year)
- [ ] Mac App Distribution certificate
- [ ] Mac App Store provisioning profile

**Steps:**
1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles → Certificates → Create
   - Type: **Mac App Distribution**
3. Identifiers → Create App ID
   - Bundle ID: `com.woodsee-digi.Apex` (must match project)
4. Profiles → Create
   - Type: **Mac App Store**
   - Select your App ID and certificate

**Download and install:**
```bash
# Double-click the downloaded .cer and .provisionprofile files
# They'll install into Keychain and ~/Library/MobileDevice/Provisioning Profiles/
```

---

### 3. Entitlements & Sandbox Fixes

#### Current Issues (from handoff):

##### ❌ **Issue 1: system_profiler subprocess blocked in sandbox**

**Problem:** `ConnCollector` uses `system_profiler SPThunderboltDataType` to enumerate Thunderbolt ports, but subprocesses are restricted in sandbox.

**Solution:** Replace subprocess with native IOKit queries.

**File:** `ConnCollector.swift` (Thunderbolt enumeration)

**Alternative approach:**
```swift
// Instead of system_profiler, use IOServiceMatching("IOThunderboltPort")
// Similar to how USB/Bluetooth are queried
```

I can help implement this if needed!

##### ❌ **Issue 2: IOBluetooth sandbox verification**

**Problem:** IOBluetooth framework may require additional entitlements.

**Check entitlements file needs:**
```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

---

### 4. Entitlements Configuration

#### `Apex-AppStore.entitlements` should include:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- REQUIRED: App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Network monitoring -->
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    
    <!-- File access for disk monitoring -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    
    <!-- Bluetooth monitoring (if used) -->
    <key>com.apple.security.device.bluetooth</key>
    <true/>
    
    <!-- USB monitoring -->
    <key>com.apple.security.device.usb</key>
    <true/>
    
    <!-- XPC to privileged helper -->
    <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
    <array>
        <string>com.woodsee-digi.ApexHelper</string>
    </array>
    
    <!-- SMAppService daemon embedding -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.woodsee-digi.Apex</string>
    </array>
</dict>
</plist>
```

#### `ApexHelper` entitlements:

The helper daemon runs with elevated privileges, so it needs minimal entitlements:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Helper can kill processes -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
</dict>
</plist>
```

---

### 5. Info.plist Requirements

Ensure `Info.plist` includes:

```xml
<key>CFBundleName</key>
<string>Apex</string>

<key>CFBundleDisplayName</key>
<string>Apex System Monitor</string>

<key>CFBundleShortVersionString</key>
<string>1.0</string>

<key>CFBundleVersion</key>
<string>1</string>

<key>LSMinimumSystemVersion</key>
<string>14.0</string>

<key>NSHumanReadableCopyright</key>
<string>Copyright © 2026 Woodsee Digi. All rights reserved.</string>

<key>LSApplicationCategoryType</key>
<string>public.app-category.utilities</string>

<!-- Privacy usage descriptions (if accessing camera/mic in future) -->
<!-- Currently not needed for system monitoring -->
```

---

### 6. Build Configuration

#### Development Build (for testing):
```bash
cd ~/Documents/GitHub/Apex
xcodegen generate
xcodebuild -project Apex.xcodeproj \
  -scheme Apex \
  -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="-"
```

#### App Store Build:
```bash
xcodebuild -project Apex.xcodeproj \
  -scheme Apex \
  -configuration AppStore \
  -destination "platform=macOS" \
  -archivePath ./build/Apex.xcarchive \
  archive
```

Then export for App Store:
```bash
xcodebuild -exportArchive \
  -archivePath ./build/Apex.xcarchive \
  -exportPath ./build/AppStore \
  -exportOptionsPlist exportOptions.plist
```

**exportOptions.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

Replace `YOUR_TEAM_ID` with your Apple Developer Team ID (found in developer.apple.com account).

---

### 7. Upload to App Store Connect

**Using Transporter app (recommended):**
1. Download "Transporter" from Mac App Store
2. Drag the exported `.pkg` file into Transporter
3. Click "Deliver"

**Or using command line:**
```bash
xcrun altool --upload-app \
  --type macos \
  --file ./build/AppStore/Apex.pkg \
  --username "your@apple.id" \
  --password "app-specific-password"
```

**Create app-specific password:**
- Go to [appleid.apple.com](https://appleid.apple.com)
- Sign In → Security → App-Specific Passwords → Generate

---

### 8. App Store Connect Setup

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. **My Apps** → **+** → **New App**
3. Fill in:
   - Platform: **macOS**
   - Name: **Apex**
   - Primary Language: **English**
   - Bundle ID: Select `com.woodsee-digi.Apex`
   - SKU: `apex-macos-2026` (any unique identifier)
   - User Access: **Full Access**

4. **App Information:**
   - Category: **Utilities**
   - Subcategory: **System Utilities** (optional)
   - Content Rights: Declare as appropriate

5. **Pricing and Availability:**
   - Price: **Free** or set a price tier
   - Availability: Select countries

6. **Version Information:**
   - Screenshots (at least 2-3)
   - Description (highlight features)
   - Keywords: "system monitor, cpu, memory, network, btop, htop, activity monitor"
   - Support URL: GitHub repo or your website
   - Privacy Policy URL: Required if collecting any user data (even analytics)

---

### 9. Privacy & Data Collection

**Important:** Even for local-only monitoring apps, Apple requires clarity.

**App Privacy Questions:**
- "Does your app collect data?" → **No** (if purely local monitoring)
- "Does your app use tracking?" → **No**

If you add analytics later, you must update this.

---

### 10. App Review Notes

In App Store Connect, under **App Review Information**, add notes:

```
Apex is a system monitoring utility for macOS.

TESTING NOTES:
- The app displays real-time CPU, memory, disk, network, and process information
- MIDI and OSC features require external MIDI devices or OSC clients for full testing
- The privileged helper (ApexHelper) will prompt for authorization on first launch
  - This is expected behavior for process kill functionality
- All monitoring is local-only; no data leaves the device

DEMO ACCOUNT: Not applicable (no user accounts)
```

---

## 🚀 Step-by-Step Submission Workflow

### Phase 1: Prepare Assets (This Week)
1. ✅ Create app icon (all sizes)
2. ✅ Take 3-5 high-quality screenshots
3. ✅ Write App Store description

### Phase 2: Fix Code Issues (This Week)
4. ✅ Replace `system_profiler` subprocess with native IOKit
5. ✅ Verify IOBluetooth entitlements
6. ✅ Test sandbox build thoroughly
7. ✅ Ensure SMAppService helper embeds correctly

### Phase 3: Code Signing (Next Week)
8. ✅ Create certificates and provisioning profiles
9. ✅ Update `project.yml` with proper signing config
10. ✅ Test signed build locally

### Phase 4: Archive & Upload (Next Week)
11. ✅ Create archive build
12. ✅ Export for App Store
13. ✅ Upload via Transporter

### Phase 5: App Store Connect (Next Week)
14. ✅ Create app listing
15. ✅ Add metadata, screenshots, description
16. ✅ Submit for review

### Phase 6: Review & Launch (1-3 days)
17. ✅ Respond to any App Review questions
18. ✅ Approve for release once approved
19. 🎉 **Apex is live!**

---

## 📞 Next Steps - Let's Start!

I'm ready to help you with:

1. **Fix the sandbox issues** (system_profiler + IOBluetooth) - I can write the code
2. **Create app icon** - I can provide design guidance
3. **Review entitlements** - Ensure compliance
4. **Test sandbox build** - Validate all features work
5. **Generate exportOptions.plist** - Ready for archive

What would you like to tackle first? 🚀

---

**Estimated Timeline:**
- Code fixes: **1-2 days**
- Assets & testing: **2-3 days**
- Submission: **1 day**
- Apple Review: **1-3 days**

**Total: ~1 week to submission, potentially live in 10 days!**
