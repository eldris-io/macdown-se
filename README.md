# MacDown

[![](https://img.shields.io/github/release/MacDownApp/macdown.svg)](http://macdown.uranusjr.com/download/latest/)
![Total downloads](https://img.shields.io/github/downloads/MacDownApp/macdown/latest/total.svg)
[![Build Status](https://travis-ci.org/MacDownApp/macdown.svg?branch=master)](https://travis-ci.org/MacDownApp/macdown)


MacDown is an open source Markdown editor for OS X, released under the MIT License. The author stole the idea from [Chen Luo](https://twitter.com/chenluois)’s [Mou](http://mouapp.com) so that people can make crappy clones.

Visit the [project site](http://macdown.uranusjr.com/) for more information, or download [MacDown.app.zip](http://macdown.uranusjr.com/download/latest/) directly from the [latest releases](https://github.com/MacDownApp/macdown/releases/latest) page.

## Install

[Download](http://macdown.uranusjr.com/download/latest/), unzip, and drag the app to Applications folder. MacDown is also available through [Homebrew Cask](https://caskroom.github.io/):

    brew install --cask macdown

## Screenshot

![screenshot](assets/screenshot.png)

## License

MacDown is released under the terms of MIT License. You may find the content of the license [here](http://opensource.org/licenses/MIT), or inside the `LICENSE` directory.

You may find full text of licenses about third-party components in the `LICENSE` directory, or the **About MacDown** panel in the application.

The following editor themes and CSS files are extracted from [Mou](http://mouapp.com), courtesy of Chen Luo:

* Mou Fresh Air
* Mou Fresh Air+
* Mou Night
* Mou Night+
* Mou Paper
* Mou Paper+
* Tomorrow
* Tomorrow Blue
* Tomorrow+
* Writer
* Writer+
* Clearness
* Clearness Dark
* GitHub
* GitHub2

## Development

### Requirements

MacDown builds as a Universal 2 application for macOS 12 or later.

Requirements: Xcode with the macOS SDK, Git, CocoaPods 1.17.0, and Node.js 22
or later. Local validation uses Xcode 27. The XCTest bundle requires macOS 14
or later because the current Xcode XCTest framework has that minimum; the app,
command-line helper, parser, and pods retain their macOS 12 deployment target.

### Environment Setup

From the repository root:

```sh
git submodule update --init --recursive
pod install
npm ci --prefix Tools/GitHub-style-generator
make -C Tools/GitHub-style-generator
make -C Dependency/peg-markdown-highlight -j$(sysctl -n hw.ncpu)
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown -configuration Release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO -derivedDataPath build build
lipo -info build/Build/Products/Release/MacDown.app/Contents/MacOS/MacDown
```

Open `MacDown.xcworkspace` for development. On Apple Silicon, run the tests with:

```sh
xcodebuild test -workspace MacDown.xcworkspace -scheme MacDown \
  -destination 'platform=macOS,arch=arm64'
```

The GitHub Actions build runs on `macos-14` and `macos-latest`, checks both binary
architectures, runs native tests, and uploads a zipped app. These CI artifacts
are development builds, not Developer ID signed or notarized releases.

### Translation

Please help translation on [Transifex](https://www.transifex.com/macdown/macdown/).

![Transifex translation percentage](https://www.transifex.com/projects/p/macdown/resource/macdownxliff/chart/image_png/)

## Discussion

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/MacDownApp/macdown)

Join our [Gitter channel](https://gitter.im/MacDownApp/macdown) if you have any problems with MacDown. Any suggestions are welcomed, too!

You can also [file an issue directly](https://github.com/MacDownApp/macdown/issues/new) on GitHub if you prefer so. But please, **search first to make sure no-one has reported the same issue already** before opening one yourself. MacDown does not update in your computer immediately when we make changes, so something you experienced might be known, or even fixed in the development version.

MacDown depends a lot on other open source projects, such as [Hoedown](https://github.com/hoedown/hoedown) for Markdown-to-HTML rendering, [Prism](http://prismjs.com) for syntax highlighting (in code blocks), and [PEG Markdown Highlight](https://github.com/ali-rantakari/peg-markdown-highlight) for editor highlighting. If you find problems when using those particular features, you can also consider reporting them directly to upstream projects as well as to MacDown’s issue tracker. I will do what I can if you report it here, but sometimes it can be more beneficial to interact with them directly.

## Tipping

If you find MacDown suitable for your needs, please consider [giving me a tip through PayPal](http://macdown.uranusjr.com/faq/#donation). Or, if you prefer to buy me a drink *personally* instead, just [send me a tweet](https://twitter.com/uranusjr) when you visit [Taipei, Taiwan](http://en.wikipedia.org/wiki/Taipei), where I live. I look forward to meeting you!

