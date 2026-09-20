# MacDown SE

The Apple Silicon continuation of the classic native Markdown editor.

[![Build](https://github.com/eldris-io/macdown-se/actions/workflows/build.yml/badge.svg)](https://github.com/eldris-io/macdown-se/actions/workflows/build.yml)
![Version](https://img.shields.io/badge/version-1.0.0--SE-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2012%2B%20(Apple%20Silicon%20%7C%20Intel)-lightgrey.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

MacDown SE is an open-source, pure native AppKit Markdown editor for macOS. Maintained by Eldris Inc. and released under the terms of the MIT License, MacDown SE continues the beloved foundation created by Tzu-ping Chung (uranusjr) between 2014 and 2020, modernizing it for Apple Silicon and modern macOS.

---

## Why MacDown SE?

* **Pure Native AppKit:** Sub-second launch times, minimal memory consumption, and zero Electron or Chromium battery drain.
* **Universal 2 Architecture:** Fully native execution on Apple Silicon (M-series) and Intel Macs, supporting macOS 12 Monterey through modern macOS.
* **Synchronized Live Preview:** Dual-pane editor with instant HTML rendering and synchronized vertical scrolling.
* **Completely Private and Offline:** Zero telemetry, zero analytics, zero network tracking, and zero cloud lock-in. Your files live on your Mac.
* **Comprehensive Syntax:** Full support for standard Markdown, CommonMark, GitHub-Flavored Markdown tables, task lists, Jekyll YAML front matter, TeX math rendering, and Prism syntax highlighting for fenced code blocks.

---

## Installation

### Pre-built Universal Binary

Download the latest `MacDown-SE-universal.zip` from our [GitHub Releases](https://github.com/eldris-io/macdown-se/releases) or automated [Build Actions](https://github.com/eldris-io/macdown-se/actions/workflows/build.yml). Unpack the archive and drag `MacDown SE.app` into your `/Applications` directory.

### Command-Line Integration

MacDown SE includes a bundled command-line utility. To install it into your path, link it from the application bundle:

```sh
sudo ln -sf "/Applications/MacDown SE.app/Contents/SharedSupport/bin/macdown-se" /usr/local/bin/macdown-se
sudo ln -sf /usr/local/bin/macdown-se /usr/local/bin/macdown
```

You can then open files or pipes directly from your terminal:

```sh
macdown README.md
git diff | macdown
```

---

## Screenshot

![MacDown SE Screenshot](assets/screenshot.png)

---

## Building from Source

### Prerequisites

* macOS 12.0 or later
* Xcode 15 or later (tested on Xcode 27)
* CocoaPods 1.17.0 (`brew install cocoapods`)
* Node.js 20 or later

### Setup & Build Steps

Clone the repository with all submodules:

```sh
git clone --recurse-submodules https://github.com/eldris-io/macdown-se.git
cd macdown-se
```

Install dependencies and build the C parser and styles:

```sh
pod install
npm ci --prefix Tools/GitHub-style-generator
make -C Tools/GitHub-style-generator
make -C Dependency/peg-markdown-highlight -j$(sysctl -n hw.ncpu)
```

Compile a Universal 2 Release build:

```sh
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown -configuration Release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO -derivedDataPath build build
```

The resulting `MacDown SE.app` will be available in:
`build/Build/Products/Release/MacDown SE.app`

### Running Native Tests

To execute the unit test suite on Apple Silicon:

```sh
xcodebuild test -workspace MacDown.xcworkspace -scheme MacDown \
  -destination 'platform=macOS,arch=arm64'
```

---

## Lineage and Attribution

MacDown SE is an independent open-source continuation. We proudly acknowledge and honor the foundational work of:

* **Tzu-ping Chung ([@uranusjr](https://github.com/uranusjr)):** Original creator and principal maintainer of MacDown (2014-2020).
* **Chen Luo ([@chenluois](https://twitter.com/chenluois)):** Creator of Mou, the pioneering Mac Markdown editor that inspired MacDown.
* **The MacDown Open Source Contributors:** Dozens of developers, translators, and style designers whose contributions are preserved in full inside `MacDown/Localization/en.lproj/Credits.rtf`.

Third-party components include:
* **Hoedown:** High-performance Markdown processing.
* **Prism:** Code syntax highlighting.
* **PEG Markdown Highlight:** Fast in-editor syntax coloring.
* **Sparkle:** Software update framework (Universal 1.27.x).

---

## Community & Support

* **Bug Reports & Issues:** Submit detailed reports via [GitHub Issues](https://github.com/eldris-io/macdown-se/issues).
* **Discussions & Ideas:** Join the conversation on [GitHub Discussions](https://github.com/eldris-io/macdown-se/discussions).
* **Contributions:** Pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting code.

---

## License

MacDown SE is released under the terms of the MIT License. Full license texts for the project and bundled third-party libraries are located in the `LICENSE` directory and the application About panel.
