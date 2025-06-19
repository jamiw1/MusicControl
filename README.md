original devforum post: https://devforum.roblox.com/t/musiccontrol-v210-an-extremely-customizable-yet-easy-to-use-music-displaycontrol/3760727

install using Wally: https://wally.run/package/jamiw1/musiccontrol

# MusicControl v2
an extremely customizable, yet easy to use music display/control

MusicControl v2 (formerly MusicPlayer) is a native-like display and control for music within your experience, with full support for all input types.

to use MusicControl, simply require the module inside a LocalScript, and create it using `MusicControl.new()`.

## displaying
```lua
local Music = MusicControl.new()
Music:SetControlState("Shuffle", "Off")
Music:SetControlState("Rewind", "Off")
Music:SetControlState("Skip", "Enabled")
Music:SetControlState("PlayPause", "Enabled")
Music:SetControlState("Repeat", "Off")
Music:SetControlState("Volume", "Enabled")
Music:SetControlState("ProgressBar", "Disabled")
```

in the MusicControl object, there are 7 different `Control`s, which can each be `Enabled`, `Disabled`, or `Off`. the default value is `Enabled` for all controls.
`Enabled`: the `Control` is visible, and listening for user input.
`Disabled`: the `Control` is visible, however it doesn't listen for user input.
`Off`: the `Control` is no longer visible, and the other `Control`s will adapt to fill the missing space.

to set the displayed title and artist, call `:SetTitle()` and `:SetArtist()`.
```lua
local Music = MusicControl.new()
Music:SetTitle("cool song 😎")
Music:SetArtist("that one artist")
```

you can also display where you currently are at in the song with `:SetPlaybackLength()` and `:SetPlaybackPosition()`

```lua
local Music = MusicControl.new()
Music:SetPlaybackLength(audio.TimeLength)
Music:SetPlaybackPosition(audio.TimePosition)
```

however, typically you would call `:SetPlaybackPosition()` inside `RenderStepped`, so it stays updated as the audio plays.
```lua
game:GetService("RunService").RenderStepped:Connect(function()
    Music:SetPlaybackPosition(audio.TimePosition)
end)
```
## interactions
you can detect when interactions occur by listening to built-in events, such as `OnPlayPausePressed` and `OnVolumeAdjust`.
for volume changes, you need to listen to the `OnVolumeAdjust` event, and accordingly update the audio and display.
```lua
Music.OnVolumeAdjust:Connect(function(newVolume) 
    -- newVolume will always be a value between 0 and 1
    audio.Volume = newVolume
    Music:SetVolumePosition(newVolume) -- sets the volume slider position
end)
```

similarly, for playback, you listen to the `OnPlaybackAdjust` event and adjust values accordingly.
```lua
Music.OnPlaybackAdjust:Connect(function(newPosition)
    -- newPosition will also always be a value ranging from 0 to 1
    audio.TimePosition = audio.TimeLength * newPosition
    Music:SetPlaybackPosition(audio.TimePosition)
end)
```

each button has its own event, all of which are listed below
`OnShufflePressed`
`OnRewindPressed`
`OnPlayPausePressed`
`OnSkipPressed`
`OnRepeatPressed`
`OnVolumePressed` - the volume **BUTTON**, not the slider

with some `Control`s, you can adjust the "state" (appearance) of the control by setting it
`Music:SetPlaying(value: boolean)` - Displays pause icon (shown above) if true, otherwise play icon if false
`Music:SetShuffle(value: boolean)` - Displays filled shuffle icon if true, regular (shown above) if false
`Music:SetRepeat(value: RepeatState)` - Can be one of three states, `"Repeat"`, `"RepeatOne"`, or `"Off"` (shown above)
every single `Set` method has an corresponding `Get` method, including the methods not mentioned earlier.

```lua
Music.OnPlayPausePressed:Connect(function()
    -- the buttons don't pass any parameters
    audio.Playing = not audio.Playing
    Music:SetPlaying(audio.Playing)
end)
```

```lua
Music.OnShufflePressed:Connect(function()
	Music:SetShuffle(not Music:GetShuffle())
end)
```

simple repeat cycle
```lua
local repeats = {"Off", "Repeat", "RepeatOne"}
local repeatIndex = 1
Music.OnRepeatPressed:Connect(function()
	repeatIndex += 1
	if repeatIndex > #repeats then
		repeatIndex = 1
	end
	Music:SetRepeat(repeats[repeatIndex])
	audio.Looped = Music:GetRepeat() == "RepeatOne"
end)
```

i have a fully working test place, with 5 songs to loop through or shuffle. try it out!
https://www.roblox.com/games/71381252711529/music-handler

## credits:
- Icon/TopbarPlus - ForeverHD, wouldn't be possible without this
- GoodSignal - stravant
