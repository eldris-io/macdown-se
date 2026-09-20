# First, check for git in $PATH
hash git 2>/dev/null || { echo >&2 "Git required, not installed.  Aborting build number update script."; exit 0; }

# Build version (closest-tag-or-branch "-" commits-since-tag "-" short-hash dirty-flag)
function get_build_version() {
    echo $(git describe --tags --always --dirty=+)
}

# The app plist is the canonical release identity for both GUI and CLI builds.
function get_short_version() {
    local tools_dir
    tools_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$tools_dir/../MacDown/MacDown-Info.plist"
}

function get_bundle_version() {
    local tools_dir
    tools_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$tools_dir/../MacDown/MacDown-Info.plist"
}
