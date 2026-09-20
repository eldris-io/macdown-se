# Contributing to MacDown SE

Thank you for your interest in contributing to MacDown SE.

MacDown SE is an open-source, community-driven project maintained by Eldris Inc. under the MIT License. We welcome bug reports, feature enhancements, documentation improvements, and localization updates.

---

## Community and Communication

* **Discussions & Questions:** Join the community on [GitHub Discussions](https://github.com/eldris-io/macdown-se/discussions).
* **Bug Reports & Issues:** File actionable issues with crash logs or reproduction steps via [GitHub Issues](https://github.com/eldris-io/macdown-se/issues).

---

## Development Setup

1. **Clone with Submodules:**
   ```sh
   git clone --recurse-submodules https://github.com/eldris-io/macdown-se.git
   cd macdown-se
   ```

2. **Install Dependencies:**
   ```sh
   pod install
   npm ci --prefix Tools/GitHub-style-generator
   make -C Tools/GitHub-style-generator
   make -C Dependency/peg-markdown-highlight -j$(sysctl -n hw.ncpu)
   ```

3. **Open the Workspace:**
   Always open `MacDown.xcworkspace` in Xcode (never `MacDown.xcodeproj` directly, as CocoaPods dependencies will be missing).

---

## Coding Style & Standards

All code contributions should adhere to standard Apple AppKit and Objective-C conventions:

### Objective-C Guidelines

* **Indentation:** Use 4 spaces for indentation. Never use hard tabs. Configure Xcode to automatically trim trailing whitespace.
* **Brace Style:** Use Allman style (opening and closing braces on their own lines).
* **Control Flow:**
  * Prefer explicit bounds checking. Never use unchecked C stack arrays or unbounded pointer arithmetic.
  * Use `NSSet` or `NSArray` with safe accessor methods.
  * Prefer implicit boolean checks for object presence (`if (string.length)`) and explicit checks for numeric values (`if (range.location == 0)`).
* **Memory Management:** ARC (Automatic Reference Counting) is enabled across all targets. Avoid retain cycles in blocks by using weak/strong reference patterns (`__weak typeof(self) weakSelf = self;`).
* **Line Width:** Aim for an 80-column limit where practical. Long URLs or complex macros may exceed this constraint when readability requires it.

---

## Testing & Verification

Every pull request must pass the native test suite and compile cleanly without warnings:

1. **Run Unit Tests:**
   ```sh
   xcodebuild test -workspace MacDown.xcworkspace -scheme MacDown \
     -destination 'platform=macOS,arch=arm64'
   ```

2. **Live Execution Verification:**
   Before submitting changes, compile a Release build and launch the executable directly to ensure no runtime exceptions or AppKit nib loading failures occur:
   ```sh
   xcodebuild -workspace MacDown.xcworkspace -scheme MacDown -configuration Release \
     ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO -derivedDataPath build build
   open "build/Build/Products/Release/MacDown SE.app"
   ```

---

## Submitting Pull Requests

1. **Target Branch:** Branch off and submit pull requests against `master`.
2. **Commit Messages:** Write concise, imperative commit messages (e.g. `fix: Prevent out of bounds index in toolbar controller`).
3. **Continuous Integration:** Ensure all GitHub Actions workflows pass cleanly on your fork prior to requesting review.
4. **Attribution:** All contributors are acknowledged in the project credits. New contributors will have their names added to `Credits.rtf` upon merge.
