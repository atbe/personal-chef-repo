# -*- coding: utf-8 -*-
#
# Cookbook Name:: osx_setup
# Recipe:: default
#
# Author:: Sean Fisk <sean@seanfisk.com>
# Copyright:: Copyright (c) 2013, Sean Fisk
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License")
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'etc'
require 'uri'

# Including this causes Homebrew to install if not already installed (needed
# for the next section) and to run `brew update' if already installed.
include_recipe 'homebrew'

###############################################################################
# SHELLS
###############################################################################

BREW_PREFIX = shell_out!('brew', '--prefix').stdout.rstrip

# Add the latest bash and zsh as possible login shells.
#
# Unfortunately, these commands will cause password prompts, meaning
# chef has to be watched. The "workaround" is to put them at the
# beginning of the run.
#
# We also need to install the shells separately from the other Homebrew
# packages because it needs to be available for changing the default shell. We
# don't want to wait for all the other packages to be installed to see the
# prompt, but we need the shell to be available before setting it as the
# default.
SHELLS_FILE = '/etc/shells'
%w(bash zsh).each do |shell|
  # Install the shell using Homebrew.
  package shell do
    action :install
  end

  shell_path = File.join(BREW_PREFIX, 'bin', shell)
  # First, add shell to /etc/shells so it is recognized as a valid user shell.
  execute "add #{shell_path} to #{SHELLS_FILE}" do
    # Unfortunately, using a ruby_block does not work because there's no way
    # that I know to execute it using sudo.
    command ['sudo', 'bash', '-c', "echo '#{shell_path}' >> '#{SHELLS_FILE}'"]
    not_if do
      # Don't execute if this shell is already in the shells config file. Open
      # a new file each time to reset the enumerator, and just in case these
      # are executed in parallel.
      File.open(SHELLS_FILE).each_line.any? do |line|
        line.include?(shell_path)
      end
    end
  end
end

# Then, set zsh as the current user's shell.
ZSH_PATH = File.join(BREW_PREFIX, 'bin', 'zsh')
execute "set #{ZSH_PATH} as default shell" do
  command ['chsh', '-s', ZSH_PATH]
  # getpwuid defaults to the current user, which is what we want.
  not_if { Etc.getpwuid.shell == ZSH_PATH }
end

# Make sure to use the `execute' resource than the `bash' resource, otherwise
# sudo cannot prompt for a password.
execute 'fix the zsh startup file that path_helper uses' do
  # OS X has a program called path_helper that allows paths to be easily set
  # for multiple shells. For bash (and other shells), it works great because it
  # is called /etc/profile which is executed only for login shells. However,
  # with zsh, path_helper is run from /etc/zshenv *instead of* /etc/zprofile
  # like it should be. This fixes Apple's mistake.
  #
  # See this link for more information:
  # <https://github.com/sorin-ionescu/prezto/issues/381>
  command ['sudo', 'mv', '/etc/zshenv', '/etc/zprofile']
  only_if { File.exist?('/etc/zshenv') }
end

###############################################################################
# HOMEBREW FORMULAS
###############################################################################

homebrew_tap 'homebrew/command-not-found'

# Install Emacs with options. Do this before installing the other formulas,
# because the cask formula depends on emacs.
package 'emacs' do
  # Building with glib allows file notification support.
  options '--cocoa --with-gnutls --with-glib'
end
execute "Link 'Emacs.app' to '/Applications'" do
  command %w(brew linkapps emacs)
  creates '/Applications/Emacs.app'
end

# git-grep PCRE. Do this before installing other formulas in
# case there is a dependency on git.
package 'git' do
  options '--with-pcre'
end

# LastPass command-line interface
package 'lastpass-cli' do
  options '--with-doc --with-pinentry'
end

# mitmproxy with options
#
# There is a cask for this as well, but it is out-of-date. We also want to make
# sure the extras are included.
package 'mitmproxy' do
  options '--with-cssutils --with-protobuf --with-pyamf'
end

# Ettercap with IPv6 support, GTK+ GUI, and Ghostscript (for PDF docs)
#
# Note: Ettercap is crashing at this time on my Mac, so I've disabled it for
# now. Hopefully there is a solution in the future.
#
# Note: When initially installing, I had a problem with this Ghostscript
# conflicting with Ghostscript from MacTeX, I believe. I just overwrote it, but
# this may be a problem again when installing fresh.
#
# package 'ettercap' do
#   options '--with-ghostscript --with-gtk+ --with-ipv6'
# end

node.default['homebrew']['formulas'] = [
  'ack',
  'aria2',
  'astyle',
  'cask',
  # Although there is a formula for this, it's best to install in a Python
  # environment, because cookiecutter uses the Python under which it runs to
  # execute things. Using /usr/bin/python causes problems...
  # 'cookiecutter',
  'coreutils',
  # An improved version of df with colors.
  'dfc',
  # Dos2Unix / Unix2Dos <http://waterlan.home.xs4all.nl/dos2unix.html> looks
  # superior to Tofrodos <http://www.thefreecountry.com/tofrodos/>. But that
  # was just from a quick look.
  'dos2unix',
  'doxygen',
  'duti',
  'editorconfig',
  'fasd',
  'ghostscript',
  'gibo',
  'gnu-tar',
  # Install both GraphicMagick and ImageMagick. In generally, I prefer
  # GraphicsMagick, but ImageMagick has ICO support so we use it for
  # BetterPlanner.
  'graphicsmagick',
  'graphviz',
  'grc',
  'htop-osx',
  'hub',
  # ImageMagick might already be present on the system (but just 'convert').
  # I'm not sure if it's just an artifact of an earlier build, but it was on my
  # Mavericks system before I installed it (again?).
  'imagemagick',
  # For pygit2 (which is for Powerline).
  'libgit2',
  # For rotating the Powerline log (see dotfiles).
  'logrotate',
  'mercurial',
  'mobile-shell',
  'mplayer', # For https://github.com/TeMPOraL/nyan-mode#features :)
  'mr', # myrepos, for managing multiple repos
  'nmap',
  'node',
  # I prefer ohcount to cloc and sloccount.
  'ohcount',
  'osquery',
  'p7zip',
  'parallel',
  'pdfgrep',
  'pidof',
  'progress',
  'pstree',
  # pwgen and sf-pwgen are both password generators. pwgen is more generic,
  # whereas sf-pwgen uses Apple's security framework. We also looked at APG,
  # but it seems unmaintained.
  'pwgen',
  'sf-pwgen',
  'pyenv',
  'pyenv-virtualenv',
  'pyenv-which-ext',
  'qpdf',
  # Even though the rbenv cookbooks looks nice, they don't work as I'd like.
  # fnichol's supports local install, but insists on templating
  # /etc/profile.d/rbenv.sh *even when doing a local install*. That makes no
  # sense. I don't want that.
  #
  # The RiotGames rbenv cookbook only supports global install.
  #
  # So let's just install through trusty Homebrew.
  #
  # We now also install pyenv through Homebrew, so it's nice to be consistent.
  'rbenv',
  # rbenv plugins
  # For the reason this was chosen over alternatives, see
  # https://github.com/maljub01/rbenv-bundle-exec#similar-plugins
  'rbenv-bundle-exec',
  'rbenv-communal-gems',
  'rbenv-default-gems',
  # reattach-to-user-namespace has options to fix launchctl and shim
  # pbcopy/pbaste. We haven't needed them yet, though.
  'reattach-to-user-namespace',
  'renameutils',
  'ruby-build',
  'ssh-copy-id',
  # Primarily for Sphinx
  'texinfo',
  'thefuck',
  'the_silver_searcher',
  'tmux',
  'tree',
  'valgrind',
  'watch',
  'wget',
  'xclip',
  'xz',
  # For downloading videos/audio. ffmpeg is for post-processing; we chose it
  # over libav based on http://blog.pkh.me/p/13-the-ffmpeg-libav-situation.html
  # However, youtube-dl seems to prefer avconv (libav) over ffmpeg, so we may
  # change this at a later time.
  'youtube-dl',
  'ffmpeg',
  # ZeroMQ (zmq) is included to speed up IPython installs. It can install a
  # bundled version to a virtualenv, but it's faster to have a globally built
  # version.
  'zmq',
  'zsh-syntax-highlighting',
  # XML utilities
  'html-xml-utils',
  'xml-coreutils',
  # Fun commands!
  'cmatrix',
  'cowsay',
  'figlet',
  'fortune',
  'ponysay',
  'sl',
  'toilet'
]

include_recipe 'homebrew::install_formulas'

###############################################################################
# HOMEBREW CASKS (see http://caskroom.io/)
###############################################################################

node.default['homebrew']['casks'] = [
  'adium',
  'adobe-reader',
  'atext',
  'caffeine',
  'cathode',
  'chicken',
  'cord',
  'crashplan',
  'dash',
  'deeper',
  'disk-inventory-x',
  # There are a number of different versions of Eclipse. The eclipse-ide cask,
  # described as 'Eclipse IDE for Eclipse Committers', is actually just the
  # standard package without any extras. This is nice, because extras can
  # always be installed using the Eclipse Marketplace.
  'eclipse-ide',
  'firefox',
  'flash',
  'flash-player',
  'flux',
  'gfxcardstatus',
  'gimp',
  'google-chrome',
  # This is 'GoogleVoiceAndVideoSetup', which installs the browser plugins.
  'google-hangouts',
  'inkscape',
  'iterm2',
  # Java
  #
  # I wish we could avoid installing Java, but I need it for at least these
  # reasons:
  #
  # - Network Connect, GVSU's SSL VPN
  # - Playing TankPit, a Java applet-based game
  # - Eclipse
  #
  # Apple Java 6 was installed, then uninstalled like so:
  #
  #     sudo rm -r /System/Library/Java/JavaVirtualMachines/1.6.0.jdk
  #     sudo pkgutil --forget com.apple.pkg.JavaForMacOSX107
  #
  # See here for the procedure followed: http://superuser.com/a/712783
  #
  # Oracle Java 7 JDK was installed, then uninstalled with:
  #
  #     sudo rm -r /Library/Java/JavaVirtualMachines/jdk1.7.0_60.jdk
  #
  # See here:
  # JDK: http://docs.oracle.com/javase/7/docs/webnotes/install/mac/mac-jdk.html#uninstall
  # JRE: https://www.java.com/en/download/help/mac_uninstall_java.xml
  'java',
  'jettison',
  'karabiner',
  'lastpass', # NOTE: Requires manual intervention
  'libreoffice',
  # This is a maintained fork of the original Slate:
  # https://github.com/mattr-/slate
  'mattr-slate',
  # This cask already applies the fix as shown here:
  # https://github.com/osxfuse/osxfuse/wiki/SSHFS#macfusion
  'macfusion',
  'monotype-skyfonts',
  'openemu',
  'osxfuse',
  # Pandoc also has Homebrew formula. There isn't a particular reason to pick
  # one over the other.
  'pandoc',
  'quicksilver',
  'remote-desktop-connection',
  'skim',
  'skitch',
  'skype',
  # Recommended by Lifehacker
  # http://lifehacker.com/the-best-antivirus-app-for-mac-488021445
  'sophos-anti-virus-home-edition',
  'speedcrunch',
  'spotify',
  # SQLite browser options:
  #
  # - sqlitebrowser: open-source, cross-platform, well-maintained
  # - sqliteman: looks unmaintained, questionable OS support
  # - mesasqlite: OS X-only, looks unmaintained
  # - sqlprosqlite: OS X-only, proprietary
  # - sqlitestudio: open-source, cross-platform, well-maintained
  # - navicat-for-sqlite: cross-platform, proprietary
  #
  # Also available is SQLite Manager, which is a high-quality Firefox add-on.
  # <https://addons.mozilla.org/en-US/firefox/addon/sqlite-manager/>
  #
  # We've tried DB Browser for SQLite (sqlitebrowser), SQLite Studio
  # (sqlitestudio), and SQLite Manager for Firefox. All are excellent. The
  # first two are written in Qt and look great on OS X. DB Browser and SQLite
  # manager both have options for CSV and SQL export, while SQLite Studio has
  # those in addition to HTML, JSON, PDF, and XML. However, we've decided to go
  # for DB Browser for SQLite because it has an intuitive interface and has
  # packages for both Homebrew and Chocolatey. For Homebrew, both a formula and
  # a cask are available. We've decided to go for the cask to avoid having to
  # build (although it's bottled anyway).
  'sqlitebrowser',
  'sshfs',
  'vagrant',
  'virtualbox',
  'wireshark',
  # Note: XQuartz is installed to /Applications/Utilities/XQuartz.app
  'xquartz'
]

include_recipe 'homebrew::install_casks'

###############################################################################
# CUSTOM INSTALLS
###############################################################################

# Deep Sleep Dashboard widget

# The original version (http://deepsleep.free.fr/) is unfortunately broken for
# newer Macs as the hibernate modes have changed. However, CODE2K has updated
# the widget for Mountain Lion (and Mavericks)
# (http://code2k.net/blog/2012-11-06/).

DEEP_SLEEP_ARCHIVE_NAME = 'deepsleep-1.3-beta1.zip'
DEEP_SLEEP_ARCHIVE_PATH =
  "#{Chef::Config[:file_cache_path]}/#{DEEP_SLEEP_ARCHIVE_NAME}"

# This isn't perfect -- the widget will only download and install when the
# archive file doesn't exist.
remote_file 'download Deep Sleep dashboard widget' do
  source 'https://github.com/downloads/code2k/Deep-Sleep.wdgt/' +
    DEEP_SLEEP_ARCHIVE_NAME
  checksum 'fa41a926d7c1b6566b074579bdd4c9bc969d348292597ac3064731326efc4207'
  path DEEP_SLEEP_ARCHIVE_PATH
  notifies :run, 'execute[install Deep Sleep dashboard widget]'
end

execute 'install Deep Sleep dashboard widget' do
  command ['unzip', '-o', DEEP_SLEEP_ARCHIVE_PATH]
  cwd "#{node['osx_setup']['home']}/Library/Widgets"
  action :nothing
end

# Tasks Explorer, distributed as a pkg file not inside a DMG.
#
# All pkg ids installed:
#
#     com.macosinternals.tasksexplorer.Contents.pkg
#     com.macosinternals.tasksexplorer.tasksexplorerd.pkg
#     com.macosinternals.tasksexplorer.com.macosinternals.tasksexplorerd.pkg
#
# We only check for the first one, though.
TE_IS_INSTALLED = shell_out!(
  'pkgutil', '--pkg-info', 'com.macosinternals.tasksexplorer.Contents.pkg'
).exitstatus == 0
TE_PKG_CACHE_PATH = "#{Chef::Config[:file_cache_path]}/Tasks Explorer.pkg"
# First, download the file.
remote_file 'download Tasks Explorer pkg' do
  source 'https://github.com/astavonin/Tasks-Explorer/blob/master/release/' \
         'Tasks%20Explorer.pkg?raw=true'
  path TE_PKG_CACHE_PATH
  checksum '8fa4fff39a6cdea368e0110905253d7fb9e26e36bbe053704330fe9f24f7db6a'
  # Don't bother downloading the file if Tasks Explorer is already installed.
  not_if { TE_IS_INSTALLED }
end
# Now install.
execute 'install Tasks Explorer' do
  # With some help from:
  # - https://github.com/opscode-cookbooks/dmg/blob/master/providers/package.rb
  # - https://github.com/mattdbridges/chef-osx_pkg/blob/master/providers/package.rb
  command ['sudo', 'installer', '-pkg', TE_PKG_CACHE_PATH, '-target', '/']
  not_if { TE_IS_INSTALLED }
end

# Ubuntu fonts
#
# The regular Ubuntu font can be installed with SkyFonts, but it doesn't
# include Ubuntu Mono, which we want.
UBUNTU_FONT_ARCHIVE_NAME = 'ubuntu-font-family-0.83.zip'
UBUNTU_FONT_ARCHIVE_PATH =
    "#{Chef::Config[:file_cache_path]}/#{UBUNTU_FONT_ARCHIVE_NAME}"
UBUNTU_FONT_DIR = "#{node['osx_setup']['fonts_dir']}/Ubuntu"

directory UBUNTU_FONT_DIR

remote_file 'download Ubuntu fonts' do
  source "http://font.ubuntu.com/download/#{UBUNTU_FONT_ARCHIVE_NAME}"
  path UBUNTU_FONT_ARCHIVE_PATH
  checksum '456d7d42797febd0d7d4cf1b782a2e03680bb4a5ee43cc9d06bda172bac05b42'
  notifies :run, 'execute[install Ubuntu fonts]'
end

execute 'install Ubuntu fonts' do
  command "unzip '#{UBUNTU_FONT_ARCHIVE_PATH}'"
  cwd UBUNTU_FONT_DIR
  action :nothing
end

# Inconsolata for Powerline (can't be installed via SkyFonts, for obvious
# reasons).
INCONSOLATA_POWERLINE_FILE = 'Inconsolata for Powerline.otf'
remote_file 'download Inconsolata for Powerline font' do
  source 'https://github.com/powerline/fonts/raw/master/Inconsolata/' +
    URI.escape(INCONSOLATA_POWERLINE_FILE)
  path "#{node['osx_setup']['fonts_dir']}/#{INCONSOLATA_POWERLINE_FILE}"
end

###############################################################################
# PREFERENCES
###############################################################################

# Password-protected screensaver + delay
include_recipe 'mac_os_x::screensaver'

# Turn on the OS X firewall.
include_recipe 'mac_os_x::firewall'

# Set up clock with day of week, date, and 24-hour clock.
node.default['mac_os_x']['settings']['clock'] = {
  domain: 'com.apple.menuextra.clock',
  DateFormat: 'EEE MMM d  H:mm',
  FlashDateSeparators: false,
  IsAnalog: false
}

# Start the character viewer in docked mode. The large window mode doesn't take
# focus automatically, and can't AFAIK be focused with any keyboard shortcut,
# rendering it less useful for those who like to stay on the keyboard. The
# docked mode puts the cursor right in the search field, which is perfect for
# keyboard users like myself.
node.default['mac_os_x']['settings']['character_viewer'] = {
  domain: 'com.apple.CharacterPaletteIM',
  CVStartAsLargeWindow: false
}

node.default['mac_os_x']['settings']['messages'] = {
  domain: 'com.apple.iChat',
  AddressMeInGroupchat: true, # Notify me when my name is mentioned
  SaveConversationsOnClose: true # Save history when conversations are closed
}

# Show percentage on battery indicator.
#
# Note: For some reason, Apple chose the value of ShowPercent to be 'YES' or
# 'NO' as a string instead of using a boolean. mac_os_x_userdefaults treats
# 'YES' as a boolean when reading, making it overwrite every time. For this
# reason, we just write the plist.
mac_os_x_plist_file 'com.apple.menuextra.battery.plist'

node.default['mac_os_x']['settings']['atext'] = {
  domain: 'com.trankynam.aText',
  # Most of aText's settings are [presumably] stored in a giant data blob.
  # XXX These settings are dubiously applied.
  PlayFeedbackSound: false,
  ShowDockIcon: false
}

node.default['mac_os_x']['settings']['caffeine'] = {
  domain: 'com.lightheadsw.caffeine',
  ActivateOnLaunch: true, # Turn on Caffeine when the app is started.
  DefaultDuration: 0, # Activate indefinitely
  SuppressLaunchMessage: true
}

node.default['mac_os_x']['settings']['cathode'] = {
  domain: 'com.secretgeometry.Cathode',
  # Console and Monitor themes themselves seem not to be stored in preferences.
  CloseOnExit: false,
  JitterWhenWindowMoves: true,
  PositionalPerspective: true,
  RenderingQuality: 3, # High
  UseColorPalette: true,
  UseOptionAsMeta: true,
  UseSounds: false
}

node.default['mac_os_x']['settings']['deeper'] = {
  domain: 'com.titanium.Deeper',
  ConfirmQuit: false,
  ConfirmQuitApp: true,
  DeleteLog: true,
  DrawerEffect: true,
  Licence: false, # Don't show the license at startup
  OpenLog: false,
  ShowHelp: false
}

node.default['mac_os_x']['settings']['gfxcardstatus'] = {
  domain: 'com.codykrieger.gfxCardStatus-Preferences',
  shouldCheckForUpdatesOnStartup: true,
  shouldUseSmartMenuBarIcons: true
  # Note: shouldStartAtLogin doesn't actually work, because gfxCardStatus uses
  # login items like most other applications. So don't bother setting it.
}

# iTerm2
#
# There is a Chef cookbook for iterm2, but we've chosen to install using
# Homebrew Cask. The iterm2 cookbook can install tmux integration, but it's
# apparently spotty, and I haven't wanted tmux integration anyway. It also
# raises an annoying error because it looks for the plist in its own cookbook.

# Set top-level iTerm2 preferences.
node.default['mac_os_x']['settings']['iterm2'] = {
  domain: 'com.googlecode.iterm2',
  Hotkey: true,
  HotkeyChar: 59,
  HotkeyCode: 41,
  HotkeyModifiers: 1_048_840,
  PasteFromClipboard: false
}

# Install background image.
backgrounds_dir = "#{node['osx_setup']['home']}/Pictures/Backgrounds"
background_name = 'holland-beach-sunset.jpg'
background_path = "#{backgrounds_dir}/#{background_name}"

directory backgrounds_dir
cookbook_file background_name do
  path background_path
end

# Install and run script which merges our specific customizations into the
# fuller iTerm2 preferences. There is an array of profiles in the key 'New
# Bookmarks' (no idea why they chose this name). By default there is only one
# profile, the default profile. Our script sets only the keys within the
# default profile we have specifically changed.
#
# This can't be done with mac_os_x_userdefaults because it only supports
# setting top-level keys, not merging. The current approach is to use
# CoreFoundation's Preferences API to retrieve the profile dictionary through
# the top-level key, merge the values, then set the top-level key with the new
# values. This is done through Python using PyObjC so that we don't have to
# compile an Objective-C or Swift program.
#
# Other approaches that have been considered are:
#
# - Modifying the plist directly (templating values or merging or setting with
#   PlistBuddy). This is not good because preference plists are synced with
#   cached defaults, and the plists are not really meant to be modified
#   directly. The correct way to interact with them is through the preferences
#   APIs. PlistBuddy does support setting of keys within nested structures, but
#   is cumbersome to use.
# - NSUserDefaults only supports operations on preferences for the current
#   application.
# - It would be nice to call the CoreFoundation API from Ruby, but RubyCocoa,
#   MacRuby, and HotCocoa are apparently defunct; they have been succeeded by
#   RubyMotion which is a proprietary product. Frustrating.
iterm2_script_name = 'iterm2-set-profile-prefs.py'
iterm2_script_path = "#{Chef::Config[:file_cache_path]}/#{iterm2_script_name}"
cookbook_file 'Copy iTerm2 Profile Preferences Script' do
  source iterm2_script_name
  path iterm2_script_path
  mode '700'
end

execute 'Run iTerm2 Profile Preferences Script' do
  command [iterm2_script_path, background_path]
  only_if [iterm2_script_path, '--should-run', background_path]
end

node.default['mac_os_x']['settings']['jettison'] = {
  domain: 'com.stclairsoft.Jettison',
  autoEjectAtLogout: false,
  # This really means autoEjectAtSleep.
  autoEjectEnabled: true,
  ejectDiskImages: true,
  ejectHardDisks: true,
  ejectNetworkDisks: true,
  ejectOpticalDisks: false,
  ejectSDCards: false,
  hideMenuBarIcon: false,
  moveToApplicationsFolderAlertSuppress: true,
  playSoundOnFailure: false,
  playSoundOnSuccess: false,
  showRemountProgress: false,
  statusItemEnabled: true,
  toggleMassStorageDriver: false
}

cookbook_file 'Karabiner XML settings file' do
  source 'Karabiner_private.xml'
  path "#{node['osx_setup']['home']}/Library/Application Support/" \
       'Karabiner/private.xml'
end

LASTPASS_CMD_SHIFT_KEY = '1179914'
node.default['mac_os_x']['settings']['lastpass'] = {
  domain: 'com.lastpass.LastPass',
  # Some preferences are prefixed by a hash, which seems to be stored in
  # 'lp_local_pwhash'. We don't know what that hash means, or whether it's
  # consistent, so just leave those alone.
  global_StartOnLogin: '1',
  # Cmd-Shift-L
  global_SearchHotKeyMod: LASTPASS_CMD_SHIFT_KEY,
  global_SearchHotKeyVK: '37',
  # Cmd-Shift-V
  global_VaultHotKeyMod: LASTPASS_CMD_SHIFT_KEY,
  global_VaultHotKeyVK: '9'
}

# Note: We are not setting the Quicksilver hotkey through these settings.
#
# It was easy to do when we just copied the plist, but the plist has the
# disadvantage of replacing *all* of the settings.
#
# However, the mac_os_x_userdefaults provider does not support dictionaries
# with integer values, so it's not currently possible to set the hotkey through
# that either.
#
# We could run this command manually:
#
#     defaults write com.blacktree.Quicksilver QSActivationHotKey \
#     -dict keyCode -int 49 modifiers -int 524576
#
# However, the idempotency check presents a problem, since 'defaults read'
# displays both an integer and string in the same way. The 'defaults read'
# command also does not support descending into a dictionary to read a value.
# These are weaknesses of the defaults command-line interface, I guess.
#
# However, /usr/libexec/PlistBuddy can descend into dictionaries, and can print
# out type information when using the XML output option (-x). This gets ugly
# quickly, though, as PlistBuddy is somewhat cumbersome, and also might not
# play well with cached preferences.
#
# The most correct way to do this with an idempotence check that I can see
# would be to use the NSUserDefaults Cocoa class [1] to read the values
# programatically. The easiest way I can see to do this is to use the cocoa gem
# [2]. In this way, we are playing with real data types, and not shuffling them
# through an inaccurate command-line interface.
#
# However, with all these options being very complicated, we've decided just to
# leave it unautomated for now. The story of the adventure is left here for
# posterity.
#
# [1]: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/UserDefaults/AccessingPreferenceValues/AccessingPreferenceValues.html
# [2]: https://rubygems.org/gems/cocoa
#
node.default['mac_os_x']['settings']['quicksilver'] = {
  :domain => 'com.blacktree.Quicksilver',
  'Check for Updates' => true,
  'Hide Dock Icon' => true,
  :QSAgreementAccepted => true,
  :QSCommandInterfaceControllers => 'QSBezelInterfaceController',
  :QSShowMenuIcon => true,
  :QSUseFullMenuStatusItem => false,
  'Setup Assistant Completed' => true
}

cookbook_file 'Quicksilver catalog preferences file' do
  source 'Quicksilver-Catalog.plist'
  path node['osx_setup']['home'] +
    '/Library/Application Support/Quicksilver/Catalog.plist'
end

cookbook_file 'Slate preferences file' do
  source 'slate.js'
  path "#{node['osx_setup']['home']}/.slate.js"
end

node.default['mac_os_x']['settings']['tasks_explorer'] = {
  domain: 'com.macosinternals.Tasks-Explorer',
  highlight_processes: true,
  show_kernel_cpu_time: true,
  update_frequency: 2 # 2 seconds
}

node.default['mac_os_x']['settings']['xquartz'] = {
  domain: 'org.macosforge.xquartz.X11',
  # Input
  enable_fake_buttons: false,
  sync_keymap: false,
  enable_key_equivalents: true,
  option_sends_alt: true,
  # Output
  # XXX The idempotency check for this is not working because grep is
  # interpreting it as an option.
  # See https://github.com/chef-osx/mac_os_x/blob/9a63d0a14a3574d32c4adb91377c719d7b533835/providers/userdefaults.rb#L35
  depth: '-1', # use colors from display
  rootless: true,
  fullscreen_menu: true,
  # Pasteboard
  ## Syncing is somewhat broken, see here:
  ## <http://xquartz.macosforge.org/trac/ticket/765>
  ## If you go into XQuartz and press Cmd-C it will usually sync it.
  sync_pasteboard: true,
  sync_clipboard_to_pasteboard: true,
  sync_pasteboard_to_clipboard: true,
  sync_pasteboard_to_primary: true,
  sync_primary_on_select: false,
  # Windows
  wm_click_through: false,
  wm_ffm: false,
  wm_focus_on_new_window: true,
  # Security
  no_auth: false,
  nolisten_tcp: true,
  # Other
  login_shell: ZSH_PATH # XXX seems to do nothing, xterm still starts /bin/sh
}

# Tweaks from
# https://github.com/kevinSuttle/OSXDefaults/blob/master/.osx
# https://github.com/mathiasbynens/dotfiles/blob/master/.osx

# A note on settings: if the value is zero, set it as an integer 0 instead of
# float 0.0. Otherwise, it will be "cast" to a float by the defaults system and
# the resource will be updated every time. In addition, if the dock settings
# are updated, the mac_os_x cookbook will `killall dock' every time.

node.default['mac_os_x']['settings']['global'] = {
  :domain => 'NSGlobalDomain',
  # Always show scrollbars
  :AppleShowScrollBars => 'Always',
  # Allow keyboard access to all controls (using Tab), not just text boxes and
  # lists.
  #
  # Note: We used to use
  #
  #     include_recipe 'mac_os_x::kbaccess'
  #
  # which supposedly does the same thing, but its idempotence check was not
  # behaving properly. Moved it to here and it is working fine.
  :AppleKeyboardUIMode => 2,
  # Increase window resize speed for Cocoa applications
  :NSWindowResizeTime => 0.001,
  # Expand save panel by default
  :NSNavPanelExpandedStateForSaveMode => true,
  :NSNavPanelExpandedStateForSaveMode2 => true,
  # Expand print panel by default
  :PMPrintingExpandedStateForPrint => true,
  :PMPrintingExpandedStateForPrint2 => true,
  # Save to disk (not to iCloud) by default
  :NSDocumentSaveNewDocumentsToCloud => false,
  # Disable natural (Lion-style) scrolling
  'com.apple.swipescrolldirection' => false,
  # Display ASCII control characters using caret notation in standard text
  # views
  # Try e.g. `cd /tmp; echo -e '\x00' > cc.txt; open -e cc.txt`
  :NSTextShowsControlCharacters => true,
  # Disable press-and-hold for keys in favor of key repeat
  :ApplePressAndHoldEnabled => false,
  # Key repeat
  # This is also possible through the mac_os_x::key_repeat recipe, but having
  # it here allows customization of the values.
  ## Set a keyboard repeat rate to fast
  :KeyRepeat => 2,
  ## Set low initial delay
  :InitialKeyRepeat => 15,
  # Finder
  ## Show all filename extensions
  :AppleShowAllExtensions => true,
  ## Enable spring loading for directories
  'com.apple.springing.enabled' => true,
  # Remove the spring loading delay for directories
  'com.apple.springing.delay' => 0
}

# Automatically quit printer app once the print jobs complete
node.default['mac_os_x']['settings']['print'] = {
  :domain => 'com.apple.print.PrintingPrefs',
  'Quit When Finished' => true
}

# Set Help Viewer windows to non-floating mode
node.default['mac_os_x']['settings']['helpviewer'] = {
  domain: 'com.apple.helpviewer',
  DevMode: true
}

# Reveal IP address, hostname, OS version, etc. when clicking the clock in the
# login window
node.default['mac_os_x']['settings']['loginwindow'] = {
  domain: '/Library/Preferences/com.apple.loginwindow',
  AdminHostInfo: 'HostName'
}

# More Finder tweaks
# Note: Quitting Finder will also hide desktop icons.
node.default['mac_os_x']['settings']['finder'] = {
  domain: 'com.apple.finder',
  # Allow quitting via Command-Q
  QuitMenuItem: true,
  # Disable window animations and Get Info animations
  DisableAllAnimations: true,
  # Don't show hidden files by default -- this shows hidden files on the
  # desktop, which is just kind of annoying. I've haven't really seen other
  # benefits, since I don't use Finder much.
  AppleShowAllFiles: false,
  # Show status bar
  ShowStatusBar: true,
  # Show path bar
  ShowPathbar: true,
  # Allow text selection in Quick Look
  QLEnableTextSelection: true,
  # Display full POSIX path as Finder window title
  _FXShowPosixPathInTitle: true,
  # When performing a search, search the current folder by default
  FXDefaultSearchScope: 'SCcf',
  # Disable the warning when changing a file extension
  FXEnableExtensionChangeWarning: false,
  # Use list view in all Finder windows by default
  # Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
  FXPreferredViewStyle: 'Nlsv'
}

# Avoid creating .DS_Store files on network
node.default['mac_os_x']['settings']['desktopservices'] = {
  domain: 'com.apple.desktopservices',
  DSDontWriteNetworkStores: true
}

node.default['mac_os_x']['settings']['networkbrowser'] = {
  domain: 'com.apple.NetworkBrowser',
  # Enable AirDrop over Ethernet and on unsupported Macs running Lion
  BrowseAllInterfaces: true
}

node.default['mac_os_x']['settings']['dock'] = {
  :domain => 'com.apple.dock',
  # Remove the auto-hiding Dock delay
  'autohide-delay' => 0,
  # Remove the animation when hiding/showing the Dock
  'autohide-time-modifier' => 0,
  # Automatically hide and show the Dock
  :autohide => true,
  # Make Dock icons of hidden applications translucent
  :showhidden => true
}

node.default['mac_os_x']['settings']['timemachine'] = {
  domain: 'com.apple.TimeMachine',
  # Prevent Time Machine from prompting to use new hard drives as backup volume
  DoNotOfferNewDisksForBackup: true
}

node.default['mac_os_x']['settings']['textedit'] = {
  # Use plain text mode for new TextEdit documents
  domain: 'com.apple.TextEdit',
  RichText: 0,
  # Open and save files as UTF-8 in TextEdit
  PlainTextEncoding: 4,
  PlainTextEncodingForWrite: 4
}

node.default['mac_os_x']['settings']['diskutil'] = {
  :domain => 'com.apple.DiskUtility',
  # Enable the debug menu in Disk Utility
  :DUDebugMenuEnabled => true,
  # enable the advanced image menu in Disk Utility
  'advanced-image-options' => true
}

# My own tweaks

node.default['mac_os_x']['settings']['universalaccess'] = {
  domain: 'com.apple.universalaccess',
  # All closeView keys control the screen zoom.
  ## 'Zoom style' choices:
  ##
  ##     0. Fullscreen
  ##     1. Picture-in-picture
  ##
  ## Don't set this. Fullscreen is the default anyway, and this way we can let
  ## the user change based upon needs at that point. We have fullscreen and PIP
  ## settings later as well.
  # closeViewZoomMode: 0,
  closeViewHotkeysEnabled: false,
  ## Use scroll gesture with modifier keys to zoom.
  closeViewScrollWheelToggle: true,
  ## Use Ctrl as the modifier key (the number is a key code or something).
  ## This seems not to work correctly (?).
  # closeViewScrollWheelModifiersInt: 262_144,
  closeViewSmoothImages: true,
  ## Don't follow *keyboard* focus.
  closeViewZoomFollowsFocus: false,
  ## Fullscreen zoom settings
  ### Choices: When zoomed in, the screen image moves:
  ###
  ###     0. Continuously with pointer
  ###     1. Only when the pointer reaches an edge
  ###     2. So the pointer is at or near the center of the screen
  closeViewPanningMode: 1,
  ## Picture-in-picture settings
  ### Use system cursor in zoom.
  closeViewCursorType: 0,
  ### Enable temporary zoom (with Ctrl-Cmd)
  closeViewPressOnReleaseOff: true,
  ### Choices:
  ###
  ###     1. Stationary
  ###     2. Follow mouse cursor
  ###     3. Tiled along edge
  closeViewWindowMode: 1
}

# Actually write all the settings using the 'defaults' command.
include_recipe 'mac_os_x::settings'

# Set Skim as default PDF reader using duti.
CURRENT_PDF_APP = shell_out!('duti', '-x', 'pdf').stdout.lines[0].rstrip
execute 'set Skim as PDF viewer' do
  # Note: Although setting the default app for 'viewer' instead of 'all' works
  # and makes more sense, there is apparently no way to query this information
  # using duti. Since we won't really be editing PDFs, we'll just set the role
  # to 'all' for Skim.
  command %w(duti -s net.sourceforge.skim-app.skim pdf all)
  not_if { CURRENT_PDF_APP == 'Skim.app' }
end

###############################################################################
# DOTFILES AND EMACS
###############################################################################

directory node['osx_setup']['personal_dir'] do
  recursive true
  action :create
end

git node['osx_setup']['emacs_dir'] do
  repository 'git@github.com:seanfisk/emacs.git'
  enable_submodules true
  action :checkout
  notifies :run, 'execute[install emacs configuration]'
end

execute 'install emacs configuration' do
  command %w(make install)
  cwd node['osx_setup']['emacs_dir']
  action :nothing
end

execute 'invalidate sudo timestamp' do
  # 'sudo -K' will remove the timestamp entirely, which means that sudo will
  # print the initial 'Improper use of the sudo command' warning. Not what we
  # want. 'sudo -k' just invalidates the timestamp without removing it.
  command ['sudo', '-k']
  # Kill only if we have sudo privileges. 'sudo -k' is idempotent anyway, but
  # it's nice to see less resources updated when possible.
  #
  # 'sudo -n command' exits with 0 if a password is needed (what?), or the exit
  # code of 'command' if it is able to run it. Hence the unusual guard here: an
  # exit code of 1 indicates sudo privileges, while 0 indicates none.
  not_if ['sudo', '-n', 'false']
end
