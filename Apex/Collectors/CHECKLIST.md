# Apex - App Store Submission Checklist

Use this to track your progress toward App Store submission.

## Phase 1: Code & Configuration ✅

- [x] **Fix sandbox issues** (Xcode Claude - DONE)
  - [x] Replace system_profiler with IOKit
  - [x] Remove subprocess dependencies
  - [x] Fix IOKit defer bug (Amy - DONE)
  - [x] Fix USB enumeration (Amy - DONE)
  
- [x] **Create entitlements** (Xcode Claude - DONE)
  - [x] Apex-AppStore.entitlements
  - [x] Apex-Development.entitlements
  - [x] Include all required permissions

- [x] **Build configuration** (Xcode Claude - DONE)
  - [x] exportOptions.plist
  - [x] build-appstore.sh script
  - [x] Test scripts

- [ ] **Update Team ID**
  - [ ] Find Team ID at developer.apple.com/account
  - [ ] Edit exportOptions.plist
  - [ ] Replace YOUR_TEAM_ID_HERE

## Phase 2: Assets 🎨

- [ ] **App Icon**
  - [ ] Design or find icon (CPU, chart, or system theme)
  - [ ] Generate all sizes (16x16 to 512x512 @2x)
  - [ ] Add to Assets.xcassets/AppIcon.appiconset
  - [ ] Build and verify icon shows in Dock

- [ ] **Screenshots** (minimum 2-3 required)
  - [ ] CPU panel (showing live charts)
  - [ ] Network panel (with active interface)
  - [ ] Connectivity panel (TB/USB/BT/MIDI/OSC)
  - [ ] Optional: Memory, Disk, Processes panels
  - [ ] Save at 1280x800 or larger (Retina quality)

## Phase 3: Testing 🧪

- [ ] **Build locally**
  - [ ] Run: `xcodebuild -project Apex.xcodeproj -scheme Apex`
  - [ ] Verify no compiler errors
  - [ ] App launches successfully

- [ ] **Test all features**
  - [ ] CPU monitoring shows per-core usage
  - [ ] Memory shows RAM usage
  - [ ] Disk shows I/O rates
  - [ ] Network shows interface stats
  - [ ] Connectivity shows:
    - [ ] WiFi info
    - [ ] Bluetooth devices
    - [ ] Thunderbolt ports (NEW IOKit method)
    - [ ] USB devices
    - [ ] MIDI devices (if available)
    - [ ] OSC messages (if sending)
  - [ ] Processes list updates
  - [ ] Process kill works (via ApexHelper)

- [ ] **Test sandbox build** (IMPORTANT)
  - [ ] Build with Apex-AppStore.entitlements
  - [ ] Verify Thunderbolt enumeration still works
  - [ ] No console errors about permissions
  - [ ] All collectors function properly

## Phase 4: Apple Developer Setup 🍎

- [ ] **Apple Developer Account**
  - [ ] Active account ($99/year)
  - [ ] Team ID noted

- [ ] **Certificates**
  - [ ] Mac App Distribution certificate created
  - [ ] Certificate installed in Keychain
  - [ ] Verify: Xcode → Settings → Accounts → View Details

- [ ] **App ID**
  - [ ] Create at developer.apple.com
  - [ ] Bundle ID: com.woodsee-digi.Apex
  - [ ] Enable required capabilities

- [ ] **Provisioning Profile**
  - [ ] Mac App Store profile created
  - [ ] Downloaded and installed
  - [ ] Linked to App ID and certificate

## Phase 5: Build & Archive 📦

- [ ] **Make script executable**
  ```bash
  chmod +x build-appstore.sh
  chmod +x test-thunderbolt.sh
  ```

- [ ] **Run build script**
  ```bash
  ./build-appstore.sh
  ```
  - [ ] Archive created successfully
  - [ ] Export completed
  - [ ] Apex.pkg file exists in ./build/AppStore/

- [ ] **Validate package** (optional)
  ```bash
  xcrun altool --validate-app \
    --type macos \
    --file ./build/AppStore/Apex.pkg
  ```

## Phase 6: App Store Connect 🌐

- [ ] **Create app listing**
  - [ ] Go to appstoreconnect.apple.com
  - [ ] My Apps → + → New App
  - [ ] Platform: macOS
  - [ ] Name: Apex (or "Apex System Monitor")
  - [ ] Bundle ID: com.woodsee-digi.Apex
  - [ ] SKU: apex-macos-2026 (or similar)

- [ ] **App Information**
  - [ ] Category: Utilities
  - [ ] Subcategory: System Utilities
  - [ ] Copyright: © 2026 Woodsee Digi
  - [ ] Privacy Policy URL (if collecting data)
  - [ ] Support URL (can use GitHub)

- [ ] **Pricing**
  - [ ] Free or set price
  - [ ] Select availability (countries)

- [ ] **Version Information**
  - [ ] Upload screenshots (2-3 minimum)
  - [ ] Write description:
    ```
    Professional system monitor for macOS.
    
    Features:
    • Real-time CPU monitoring with per-core visualization
    • Memory and disk I/O tracking
    • Network interface statistics
    • Thunderbolt, USB, and Bluetooth device monitoring
    • MIDI and OSC support for professional audio
    • Process management with privileged kill
    • Native Swift 6 / SwiftUI application
    ```
  - [ ] Keywords: system monitor, cpu, memory, network, btop, htop, activity monitor
  - [ ] What's New: "Initial release"
  - [ ] Support URL
  - [ ] Privacy Policy URL (or declare no data collection)

- [ ] **App Privacy**
  - [ ] Data collection: None (if purely local monitoring)
  - [ ] Tracking: None
  - [ ] Submit privacy questionnaire

- [ ] **App Review Information**
  - [ ] Contact info (your email/phone)
  - [ ] Notes for reviewer (see APP_STORE_READY.md)
  - [ ] Demo account: N/A (no accounts needed)

## Phase 7: Upload & Submit 🚀

- [ ] **Upload build**
  - Option A: Transporter app
    - [ ] Download Transporter from Mac App Store
    - [ ] Drag Apex.pkg into Transporter
    - [ ] Click "Deliver"
  - Option B: Command line
    - [ ] Create app-specific password at appleid.apple.com
    - [ ] Run upload command (shown in build script output)

- [ ] **Select build in App Store Connect**
  - [ ] Wait for build to process (10-30 minutes)
  - [ ] Go to version → Build → Select uploaded build
  - [ ] Answer export compliance questions (no encryption = No)

- [ ] **Submit for review**
  - [ ] Review all information
  - [ ] Click "Submit for Review"
  - [ ] Confirm submission

## Phase 8: After Submission 📧

- [ ] **Monitor status**
  - [ ] App Store Connect → My Apps → Apex
  - [ ] Watch for status changes
  - [ ] Respond to any reviewer questions

- [ ] **Possible statuses:**
  - Waiting for Review (1-3 days typically)
  - In Review (a few hours)
  - Pending Developer Release (approved! 🎉)
  - Rejected (fix issues and resubmit)

- [ ] **On approval:**
  - [ ] Choose release option (automatic or manual)
  - [ ] Monitor App Store listing
  - [ ] Share with users!

## Estimated Timeline ⏱️

- Phase 1: ✅ Complete
- Phase 2: ~1 hour (icon + screenshots)
- Phase 3: ~30 minutes (testing)
- Phase 4: ~30 minutes (certificates setup)
- Phase 5: ~10 minutes (build)
- Phase 6: ~30 minutes (App Store Connect)
- Phase 7: ~15 minutes (upload)
- Phase 8: 1-3 days (Apple review)

**Total active work: ~3 hours**  
**Total calendar time: 3-5 days**

## Notes 📝

- Update this file as you complete items
- If you get stuck, check APP_STORE_GUIDE.md for details
- Ask Xcode Claude or Amy for help via ai-context bridge
- Keep calm - you're almost there! 🚀

---

**Started:** April 12, 2026  
**Target submission:** _____________  
**Status:** Phase 1 Complete ✅
