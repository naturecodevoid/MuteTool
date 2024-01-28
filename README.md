# MuteTool

A simple menu bar icon and global shortcut for muting your microphone on macOS

Features:

-   Menu bar icon that shows if your microphone is muted or not
-   Global shortcut for muting your microphone (CMD+\`)
-   Text-to-speech audio that plays when your microphone mute status is changed to indicate if it is muted or unmuted
-   Follows default input device changes
-   Follows external mute status changes (for example, toggling mute in Audio MIDI Setup)
-   Upon quiting the app, the microphone will be unmuted if it is muted to ensure you aren't stuck in a muted state

## Installation

As of now, you will have to build it from source.

## Configuration

MuteTool has no configuration window (yet). It cannot automatically install a login item to open itself, but that is something I will look into adding in the future. To change the shortcut for
toggling mute, you must rebuild the application after changing the keybinds in [MuteToolApp.swift](./MuteTool/MuteToolApp.swift) (they are located at the top of the file).
