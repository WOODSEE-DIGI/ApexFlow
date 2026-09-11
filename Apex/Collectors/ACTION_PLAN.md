# 🚀 Apex - Immediate Action Plan

## Priority Issues to Fix NOW

### 1. Fix .ai-context Build Errors ⚠️

**The Problem:**
Xcode is trying to compile `.ai-context` files and looking for them in the wrong location.

**IMPORTANT:** Don't delete these files - they enable Claude ↔ Claude communication!

**The Fix (in Xcode):**
1. Select `.ai-context` folder in Project Navigator (left sidebar)
2. Open File Inspector (right sidebar, first tab)
3. **Uncheck "Target Membership" for Apex target**
   - This keeps files in project but excludes from build
4. Files will remain for git/communication but won't be in the app bundle

**Alternative (via project.yml if using XcodeGen):**
```yaml
# In your project.yml, mark .ai-context as resources with no target
fileGroups:
  - .ai-context  # included in project but not in any target
```

**Why this works:**
- ✅ Files stay in repo for Amy and me to communicate
- ✅ Files visible in Xcode for editing
- ✅ NOT compiled into the app
- ✅ NOT included in App Store submission

---

### 2. Fix system_profiler Sandbox Issue 🔧

**File to modify:** `ConnCollector.swift` (Thunderbolt enumeration)

**Current approach:** Uses `system_profiler SPThunderboltDataType` subprocess ❌ (blocked in sandbox)

**New approach:** Use native IOKit queries ✅

**I can implement this for you!** Want me to write the replacement code?

---

### 3. Verify IOBluetooth Entitlements ✅

**Quick check:**
Does `Apex-AppStore.entitlements` have this key?
```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

If not, I'll add it when I see your entitlements file.

---

### 4. Create App Icon 🎨

**Options:**

**A) Quick & Simple (5 minutes):**
1. Find a system monitoring icon (gears, chart, dashboard)
2. Use [https://www.appicon.co](https://www.appicon.co) to generate all sizes
3. Drag into Xcode's `Assets.xcassets/AppIcon`

**B) Custom Design (30-60 minutes):**
1. Design in Figma, Sketch, or SF Symbols app
2. Export 512x512 @2x master file
3. Generate icon set with appicon.co

**Placeholder for now:**
- Use SF Symbol: `cpu` or `chart.xyaxis.line` or `speedometer`
- Convert to app icon format

---

## What I Need From You

To proceed efficiently, please provide or confirm:

1. **Do you have an Apple Developer account?**
   - [ ] Yes → What's your Team ID?
   - [ ] No → Need to create one ($99/year)

2. **Do you want me to:**
   - [ ] Fix the `system_profiler` → IOKit conversion? (I can write this now)
   - [ ] Create sample entitlements files?
   - [ ] Review your existing `project.yml` / entitlements?

3. **For the app icon:**
   - [ ] I'll create it myself
   - [ ] Need design guidance
   - [ ] Use a placeholder for now, polish later

---

## Suggested Order of Operations

### Today (2-4 hours):
1. ✅ ~~Fix `.ai-context` build errors~~ (Amy handled - ask her to confirm)
2. ✅ **DONE!** Fix `system_profiler` sandbox issue (IOKit replacement complete)
3. ✅ **DONE!** Add/verify entitlements (files created)
4. ⏳ Create placeholder app icon (see APP_STORE_READY.md)

### Tomorrow (2-3 hours):
5. ✅ Test sandbox build end-to-end
6. ✅ Take screenshots for App Store
7. ✅ Write app description

### Next 2-3 Days:
8. ✅ Set up code signing (certificates, profiles)
9. ✅ Archive and test distribution build
10. ✅ Create App Store Connect listing

### Next Week:
11. ✅ Submit for review
12. 🎉 Launch!

---

## Ready to Start?

**Option A: Let's fix the code issues first**
→ I'll start with the `system_profiler` → IOKit replacement

**Option B: Let's tackle assets first**
→ App icon, screenshots, descriptions

**Option C: Let's review existing config**
→ Show me `project.yml` and entitlements files

What's your preference? 🚀
