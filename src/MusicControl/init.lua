--[[

MusicControl v2.1.0 (previously MusicPlayer) made with <3 by 2048ping

now open source with typing, and OOP!

credits:
	Icon/TopbarPlus - ForeverHD, wouldn't be possible without this
	GoodSignal - stravant

usage:
to use MusicControl, simply require this module from a LocalScript, and call .new()


--example
local Music = MusicControl.new()
Music:SetControlState("Shuffle", "Off")
Music:SetControlState("Rewind", "Off")
Music:SetControlState("Skip", "Off")
Music:SetControlState("Repeat", "Off")
Music:SetControlState("ProgressBar", "Disabled")
-- Controls can either be Off, Disabled, or Enabled
-- By default, every control is Enabled, so we turn Off the controls we don't need, and set to Disabled controls we want visible but not adjustable
-- This leaves us with the Volume/PlayPause control, and a ProgressBar without user interaction

Music:SetTitle("Song name example")
Music:SetArtist("Artist name example")
Music:SetPlaybackLength(audio.TimeLength) -- These three attributes need to be updated every time the song changes.

-- Things don't automatically update, however. We have set the display ourselves after an action happens, which means we can keep it basic, or add complicated logic if desired.
Music.OnPlayPausePressed:Connect(function()
	audio.Playing = not audio.Playing
	Music:SetPlaying(audio.Playing)
end)

-- Same logic from above works with volume, however we get a "newVolume" value that will range from 0 - 1
Music.OnVolumeAdjust:Connect(function(newVolume)
	audio.Volume = newVolume
	Music:SetVolumePosition(newVolume)
end)

-- Update time position every frame
game:GetService("RunService").RenderStepped:Connect(function()
	Music:SetPlaybackPosition(audio.TimePosition)
end)

]]
local TweenService: TweenService = game:GetService("TweenService")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")
local ContextActionService: ContextActionService = game:GetService("ContextActionService")

local Icon = require(script.Packages.topbarplus)
local Signal = require(script.Packages.goodsignal)
local Images = require(script.Images)

type Connection<Variant... = ...any> = {
	Disconnect: (self: Connection<Variant...>) -> (),
}

type Signal<Variant... = ...any> = {
	Connect: (self: Signal<Variant...>, func: (Variant...) -> ()) -> Connection<Variant...>,
    Once: (self: Signal<Variant...>, func: (Variant...) -> ()) -> Connection<Variant...>,
	Wait: (self: Signal<Variant...>) -> Variant...,
}

export type Control = "Shuffle" | "Rewind" | "PlayPause" | "Skip" | "Repeat" | "Volume" | "ProgressBar"
export type ControlState = "Enabled" | "Disabled" | "Off"
export type RepeatState = "Repeat" | "RepeatOne" | "Off"

type controlStates = {[Control]: {value: ControlState, obj: ImageButton | Frame}}

export type MusicControl = {
	--Variables
	PlaybackStep: number,
	VolumeStep: number,
	VolumeIconChangePoint: number,
	
	--Signals
	OnShufflePressed: Signal<()>,
	OnRewindPressed: Signal<()>,
	OnPlayPausePressed: Signal<()>,
	OnSkipPressed: Signal<()>,
	OnRepeatPressed: Signal<()>,
	OnVolumePressed: Signal<()>,
	OnVolumeAdjust: Signal<number>, -- returns a float value 0 to 1
	OnPlaybackAdjust: Signal<number>, -- same as above
	OnVisibilityToggle: Signal<boolean>,
	
	--Methods
	SetTitle: (self: MusicControl, title: string) -> (),
	GetTitle: (self: MusicControl) -> (string),
	
	SetArtist: (self: MusicControl, artist: string) -> (),
	GetArtist: (self: MusicControl) -> (string),
	
	SetRepeat: (self: MusicControl, state: RepeatState) -> (),
	GetRepeat: (self: MusicControl) -> (RepeatState),
	
	SetPlaying: (self: MusicControl, state: boolean) -> (),
	GetPlaying: (self: MusicControl) -> (boolean),
	
	SetShuffle: (self: MusicControl, state: boolean) -> (),
	GetShuffle: (self: MusicControl) -> (boolean),
	
	SetVolumePosition: (self: MusicControl, value: number) -> (),
	GetVolumePosition: (self: MusicControl) -> (number),
	
	SetVolumeVisibility: (self: MusicControl, visible: boolean) -> (),
	GetVolumeVisibility: (self: MusicControl) -> (boolean),
	
	SetPlaybackPosition: (self: MusicControl, seconds: number) -> (),
	GetPlaybackPosition: (self: MusicControl) -> (number),
	
	SetPlaybackLength: (self: MusicControl, seconds: number) -> (),
	GetPlaybackLength: (self: MusicControl) -> (number),
	
	SetControlState: (self: MusicControl, control: Control, state: ControlState) -> (),
	GetControlState: (self: MusicControl, control: Control) -> (ControlState),
}

local MusicControl = {}
MusicControl.__index = MusicControl

local function formatTime(totalSeconds: number): string
	totalSeconds = math.floor(totalSeconds)

	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return string.format("%d:%02d", minutes, seconds)
end

-- Creates a MusicControl instance, which is an object allowing you to display and control music within your experience.
function MusicControl.new(): MusicControl
	local self = setmetatable({}, MusicControl)
	
	local icon: any = Icon.new() -- probably unsafe but the type checker wouldn't shut up
	icon:setName("Music")
	icon:setImage(tonumber(Images.Icon))
	icon:setCaption("Open music player")
	icon:bindToggleKey(Enum.KeyCode.M)
	
	self._icon = icon
	self._title = ""
	self._artist = ""
	self._volume = 0.5
	self._playbackLength = 1
	self._playbackPosition = 0
	self._repeatState = "Off"
	self._shuffleState = false
	self._volumeVisibility = true
	self._playing = false
	
	self.PlaybackStep = 1
	self.VolumeStep = 0.1
	self.VolumeIconChangePoint = 0.7
	
	self._instance = script.MusicControlGUI:Clone()
	local player: Player? = game.Players.LocalPlayer
	if player ~= nil then
		self._instance.Parent = player.PlayerGui
	end
	
	self._controlStates = {
		["Shuffle"] = "Enabled",
		["Rewind"] = "Enabled",
		["PlayPause"] = "Enabled",
		["Skip"] = "Enabled",
		["Repeat"] = "Enabled",
		["Volume"] = "Enabled",
		["ProgressBar"] = "Enabled"
	}
	local window = self._instance.Window
	local controls = window.Controls
	self._tweens = { -- and so it begins
		window = {
			enable = TweenService:Create(window, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 300, 0, 160), BackgroundTransparency = 0.08}),
			disable = TweenService:Create(window, TweenInfo.new(0.08, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Size = UDim2.new(0, 300, 0, 0), BackgroundTransparency = 1})	
		},
		volume = {
			open = TweenService:Create(controls.PlaybackControls.Volume.Slider, TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, -37)}),
			close = TweenService:Create(controls.PlaybackControls.Volume.Slider, TweenInfo.new(0.05, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0)})
		},
		title = {
			expand = TweenService:Create(window.Title, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, 34)}),
			retract = TweenService:Create(window.Title, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(1, -32, 0, 34)})
		},
	}
	
	self._tweens.window.disable.Completed:Connect(function()
		window.Visible = false
	end)
	self._tweens.window.enable.Completed:Connect(function()
		controls.PlaybackControls.Visible = true
	end)
	
	self._tweens.volume.close.Completed:Connect(function()
		controls.PlaybackControls.Volume.Slider.Visible = false
	end)
	
	-- Signals!
	self.OnShufflePressed = Signal.new()
	self.OnRewindPressed = Signal.new()
	self.OnPlayPausePressed = Signal.new()
	self.OnSkipPressed = Signal.new()
	self.OnRepeatPressed = Signal.new()
	self.OnVolumePressed = Signal.new()
	self.OnVolumeAdjust = Signal.new()
	self.OnPlaybackAdjust = Signal.new()
	self.OnVisibilityToggle = Signal.new()
	
	icon.selected:Connect(function()
		window.Position = UDim2.fromOffset(icon:getInstance("IconButton").AbsolutePosition.X, 66)
		window.Size = UDim2.new(0, 300, 0, 0)
		window.Visible = true
		self._tweens.window.enable:Play()
		self.OnVisibilityToggle:Fire(true)
	end)
	icon.deselected:Connect(function()
		window.Size = UDim2.new(0, 300, 0, 160)
		window.Visible = true
		self._tweens.window.disable:Play()
		self.OnVisibilityToggle:Fire(false)
	end)
	
	local buttons: {ImageButton} = { --there almost absolutely exists a better way to do this, but i'm not bothered enough to figure it out
		controls.PlaybackControls.Shuffle,
		controls.PlaybackControls.Main.Rewind,
		controls.PlaybackControls.Main.PlayPause,
		controls.PlaybackControls.Main.Skip,
		controls.PlaybackControls.Repeat,
		controls.PlaybackControls.Volume.Button
	}
	for _, button in ipairs(buttons) do
		local tweenEnter = TweenService:Create(button, TweenInfo.new(0.075, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 0.8})
		local tweenExit = TweenService:Create(button, TweenInfo.new(0.075, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
		button.MouseEnter:Connect(function()
			tweenEnter:Play()
		end)
		button.MouseLeave:Connect(function()
			tweenExit:Play()
		end)
		local contentImage = button:WaitForChild("ContentImage") :: ImageLabel
		if contentImage then
			local activateTweenDown = TweenService:Create(contentImage, TweenInfo.new(0.075, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(0.7, 0, 0.7, 0)})
			local activateTweenUp = TweenService:Create(contentImage, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)})
			local activateTweenDownbg
			local activateTweenUpbg
			if button:FindFirstChild("Background") then
				activateTweenUpbg = TweenService:Create(button:FindFirstChild("Background"), TweenInfo.new(0.075, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(1, 6, 1, 6)})
				activateTweenDownbg = TweenService:Create(button:FindFirstChild("Background"), TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(1, 8, 1, 8)})	
			end
			 
			button.MouseButton1Down:Connect(function()
				contentImage.Size = UDim2.new(1, 0, 1, 0)
				activateTweenDown:Play()
				if activateTweenDownbg then
					activateTweenDownbg:Play()
				end
			end)
			button.MouseButton1Up:Connect(function()
				activateTweenUp:Play()
				if activateTweenUpbg then
					activateTweenUpbg:Play()
				end
			end)
		end
	end
	
	controls.PlaybackControls.Shuffle.Activated:Connect(function()
		if self._controlStates.Shuffle == "Enabled" then
			self.OnShufflePressed:Fire()
		end
	end)
	controls.PlaybackControls.Main.Rewind.Activated:Connect(function()
		if self._controlStates.Rewind == "Enabled" then
			self.OnRewindPressed:Fire()
		end
	end)
	controls.PlaybackControls.Main.PlayPause.Activated:Connect(function()
		if self._controlStates.PlayPause == "Enabled" then
			self.OnPlayPausePressed:Fire()
		end
	end)
	controls.PlaybackControls.Main.Skip.Activated:Connect(function()
		if self._controlStates.Skip == "Enabled" then
			self.OnSkipPressed:Fire()
		end
	end)
	controls.PlaybackControls.Repeat.Activated:Connect(function()
		if self._controlStates.Repeat == "Enabled" then
			self.OnRepeatPressed:Fire()
		end
	end)
	
	controls.PlaybackControls.Volume.Button.Activated:Connect(function()
		self:SetVolumeVisibility(not self._volumeVisibility)
		self.OnVolumePressed:Fire()
	end)
	
	controls.PlaybackControls.Volume.MouseWheelForward:Connect(function()
		if self._controlStates.Volume == "Enabled" then
			self:SetVolumeVisibility(true)
			self.OnVolumeAdjust:Fire(math.clamp(self._volume + self.VolumeStep, 0, 1))
		end
		
	end)
	controls.PlaybackControls.Volume.MouseWheelBackward:Connect(function()
		if self._controlStates.Volume == "Enabled" then
			self:SetVolumeVisibility(true)
			self.OnVolumeAdjust:Fire(math.clamp(self._volume - self.VolumeStep, 0, 1))
		end
	end)
	
	self._draggingVolume = false
	controls.PlaybackControls.Volume.Slider.InputBegan:Connect(function(io)
		if (io.UserInputType == Enum.UserInputType.Touch) and self._controlStates.Volume == "Enabled" then
			self._draggingVolume = true
		end
	end)

	controls.PlaybackControls.Volume.Slider.Display.InputBegan:Connect(function(io)
		if (io.UserInputType == Enum.UserInputType.MouseButton1) and self._controlStates.Volume == "Enabled" then
			self._draggingVolume = true
		end
	end)
	
	
	controls.Timestamps.Slider.MouseWheelForward:Connect(function()
		if self._controlStates.ProgressBar == "Enabled" then
			self.OnPlaybackAdjust:Fire(math.clamp((self._playbackPosition + self.PlaybackStep) / self._playbackLength, 0, 1))
		end
		
	end)
	controls.Timestamps.Slider.MouseWheelBackward:Connect(function()
		if self._controlStates.ProgressBar == "Enabled" then
			self.OnPlaybackAdjust:Fire(math.clamp((self._playbackPosition - self.PlaybackStep) / self._playbackLength, 0, 1))
		end
	end)
	
	self._draggingProgressBar = false
	controls.Timestamps.Slider.InputBegan:Connect(function(io)
		if (io.UserInputType == Enum.UserInputType.Touch) and self._controlStates.ProgressBar == "Enabled" then
			self._draggingProgressBar = true
		end
	end)

	controls.Timestamps.Slider.Display.InputBegan:Connect(function(io)
		if (io.UserInputType == Enum.UserInputType.MouseButton1) and self._controlStates.ProgressBar == "Enabled" then
			self._draggingProgressBar = true
		end
	end)

	UserInputService.InputEnded:Connect(function(io)
		if (io.UserInputType == Enum.UserInputType.MouseButton1) or (io.UserInputType == Enum.UserInputType.Touch) then
			self._draggingVolume = false
			self._draggingProgressBar = false
		end
	end)
	
	RunService.RenderStepped:Connect(function()
		if self._draggingVolume and self._controlStates.Volume == "Enabled" then
			local mousePos = UserInputService:GetMouseLocation() + Vector2.new(0, 10)
			local relativePos = mousePos - controls.PlaybackControls.Volume.Slider.Display.AbsolutePosition - controls.PlaybackControls.Volume.Slider.Display.AbsoluteSize
			local normalizedSize = math.clamp(relativePos.Y / controls.PlaybackControls.Volume.Slider.Display.AbsoluteSize.Y, 0, 1)
			normalizedSize = math.abs(1 - normalizedSize)
			self.OnVolumeAdjust:Fire(normalizedSize)
		end
		if self._draggingProgressBar and self._controlStates.ProgressBar == "Enabled" then
			local mousePos = UserInputService:GetMouseLocation()
			local relativeMouseX = mousePos.X - controls.Timestamps.Slider.Display.AbsolutePosition.X
			local normalizedSize = math.clamp(relativeMouseX / controls.Timestamps.Slider.Display.AbsoluteSize.X, 0, 1)
			self.OnPlaybackAdjust:Fire(normalizedSize)
		end
	end)
	
	ContextActionService:BindAction("MUSICCONTROL_VOLUME_UP", function(an: string, uis: Enum.UserInputState, io: InputObject)
		if uis == Enum.UserInputState.Begin and self._controlStates.Volume == "Enabled" then
			self.OnVolumeAdjust:Fire(math.clamp(self._volume + self.VolumeStep, 0, 1))
		end
		return nil
	end, false, Enum.KeyCode.ButtonR1, Enum.KeyCode.DPadUp, Enum.KeyCode.KeypadPlus) -- keybinds while window is open, meant for controller but can work with other things too
	ContextActionService:BindAction("MUSICCONTROL_VOLUME_DOWN", function(an: string, uis: Enum.UserInputState, io: InputObject)
		if uis == Enum.UserInputState.Begin and self._controlStates.Volume == "Enabled" then
			self.OnVolumeAdjust:Fire(math.clamp(self._volume - self.VolumeStep, 0, 1))
		end
		return nil
	end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.DPadDown, Enum.KeyCode.KeypadMinus) -- same as above
	
	return self :: MusicControl
end

function MusicControl:_getControlObject(control: Control) : (Frame | ImageButton)?
	local controls = self._instance.Window.Controls

	if control == "Shuffle" then
		return controls.PlaybackControls:WaitForChild("Shuffle")
	elseif control == "Rewind" then
		return controls.PlaybackControls.Main:WaitForChild("Rewind")
	elseif control == "PlayPause" then
		return controls.PlaybackControls.Main:WaitForChild("PlayPause")
	elseif control == "Skip" then
		return controls.PlaybackControls.Main:WaitForChild("Skip")
	elseif control == "Repeat" then
		return controls.PlaybackControls:WaitForChild("Repeat")
	elseif control == "Volume" then
		return controls.PlaybackControls:WaitForChild("Volume")
	elseif control == "ProgressBar" then
		return controls:WaitForChild("Timestamps")
	end

	return nil
end

function MusicControl:SetTitle(title: string)
	self._title = title
	self._instance.Window.Title.Text = self._title
end

function MusicControl:GetTitle() : string
	return self._title
end

function MusicControl:SetArtist(artist: string)
	self._artist = artist
	self._instance.Window.Artist.Text = self._artist
end

function MusicControl:GetArtist() : string
	return self._artist
end


function MusicControl:SetRepeat(state: RepeatState)
	local obj = self._instance.Window.Controls.PlaybackControls.Repeat
	self._repeatState = state
	obj.ContentImage.Image = Images.Repeat[state]
	if state == "Repeat" or state == "RepeatOne" then
		obj.ContentImage.ImageColor3 = Color3.new(0,0,0)
		obj.Background.BackgroundTransparency = 0
	elseif state == "Off" then
		obj.ContentImage.ImageColor3 = Color3.new(1,1,1)
		obj.Background.BackgroundTransparency = 1
	end
end

function MusicControl:GetRepeat() : RepeatState
	return self._repeatState
end

function MusicControl:SetPlaying(state: boolean)
	local obj = self._instance.Window.Controls.PlaybackControls.Main.PlayPause
	self._playing = state
	obj.ContentImage.Image = Images.PlayPause[(state and "Pause" or "Play")]

end

function MusicControl:GetPlaying() : boolean
	return self._playing
end

function MusicControl:SetShuffle(state: boolean)
	local obj = self._instance.Window.Controls.PlaybackControls.Shuffle
	self._shuffleState = state
	if state then
		obj.ContentImage.ImageColor3 = Color3.new(0,0,0)
		obj.Background.BackgroundTransparency = 0
	else
		obj.ContentImage.ImageColor3 = Color3.new(1,1,1)
		obj.Background.BackgroundTransparency = 1
	end
	
end

function MusicControl:GetShuffle() : boolean
	return self._shuffleState
end

function MusicControl:SetVolumePosition(value: number) --implement images eventually
	local volume = self._instance.Window.Controls.PlaybackControls.Volume
	local obj = volume.Slider.Display.Filled
	local tween = TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, math.clamp(value, 0, 1), 0)})
	tween:Play()
	self._volume = math.clamp(value, 0, 1)
	
	if self._controlStates.Volume == "Disabled" then
		volume.Button.ContentImage.Image = Images.Volume.Off
	else
		if self._volume <= 0 then
			volume.Button.ContentImage.Image = Images.Volume.Muted
		elseif self._volume < self.VolumeIconChangePoint then
			volume.Button.ContentImage.Image = Images.Volume.Low
		else
			volume.Button.ContentImage.Image = Images.Volume.High
		end
	end
end

function MusicControl:GetVolumePosition() : number
	return self._volume
end

function MusicControl:SetVolumeVisibility(value: boolean)
	local obj = self._instance.Window.Controls.PlaybackControls.Volume.Slider
	self._volumeVisibility = value
	obj.Visible = true
	if self._volumeVisibility then
		self._tweens.volume.open:Play()
		self._tweens.title.retract:Play()
	else
		self._tweens.volume.close:Play()
		self._tweens.title.expand:Play()
	end
	self.OnVisibilityToggle:Fire(self._volumeVisibility)
end

function MusicControl:GetVolumeVisibility() : boolean
	return self._volumeVisibility
end
function MusicControl:_setPlaybackDisplay()
	local timestamps = self._instance.Window.Controls.Timestamps
	timestamps.Slider.Display.Filled.Size = UDim2.new(math.clamp(self._playbackPosition :: number / self._playbackLength :: number, 0, 1), 0, 1,0)
	timestamps.TimeElapsed.Text = formatTime(self._playbackPosition)
	timestamps.TimeRemaining.Text = "-"..formatTime(math.ceil(self._playbackLength) :: number - self._playbackPosition :: number)
end
function MusicControl:SetPlaybackPosition(seconds: number)
	self._playbackPosition = seconds
	self:_setPlaybackDisplay()
end

function MusicControl:GetPlaybackPosition() : number
	return self._playbackPosition
end

function MusicControl:SetPlaybackLength(seconds: number)
	self._playbackLength = seconds
	self:_setPlaybackDisplay()
end

function MusicControl:GetPlaybackLength() : number
	return self._playbackLength
end

function MusicControl:SetControlState(control: Control, state: ControlState)
	self._controlStates[control] = state
	if state == "Enabled" or state == "Disabled" then
		self:_getControlObject(control).Visible = true
		if control == "ProgressBar" then
			self._instance.Window.Controls.PlaybackControls.Position = UDim2.new(0, 0, 1, -26)
			self._instance.Window.Controls.PlaybackControls.Size = UDim2.new(1, 0, 1, -26)
		end
		if control == "Volume" then
			self._instance.Window.Controls.PlaybackControls.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			if self._volumeVisibility then
				self._tweens.title.retract:Play()
			else
				self._tweens.title.expand:Play()
			end
			local volume = self._instance.Window.Controls.PlaybackControls.Volume
			if state == "Enabled" then
				if self._volume <= 0 then
					volume.Button.ContentImage.Image = Images.Volume.Muted
				elseif self._volume < self.VolumeIconChangePoint then
					volume.Button.ContentImage.Image = Images.Volume.Low
				else
					volume.Button.ContentImage.Image = Images.Volume.High
				end
			else
				volume.Button.ContentImage.Image = Images.Volume.Off
			end
		end
	end
	if state == "Off" then
		self:_getControlObject(control).Visible = false
		if control == "ProgressBar" then
			self._instance.Window.Controls.PlaybackControls.Position = UDim2.new(0, 0, 1, 0)
			self._instance.Window.Controls.PlaybackControls.Size = UDim2.new(1, 0, 1, 0)
		end
		if control == "Volume" then
			self._instance.Window.Controls.PlaybackControls.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			self._tweens.title.expand:Play()	
		end
	end
	
	if control == "PlayPause" or control == "Rewind" or control == "Skip" then
		local totalVisible: number = 0 -- calculates visible main controls, stretches size to match
		if self._controlStates["PlayPause" :: Control] == "Enabled" then totalVisible += 1 end
		if self._controlStates["Rewind" :: Control] == "Enabled" then totalVisible += 1 end
		if self._controlStates["Skip" :: Control] == "Enabled" then totalVisible += 1 end
		
		if totalVisible == 0 then
			self._instance.Window.Controls.PlaybackControls.Main.Visible = false
			self._instance.Window.Controls.PlaybackControls.Main.Size = UDim2.new(0,0,0,32)
		else
			self._instance.Window.Controls.PlaybackControls.Main.Visible = true
			self._instance.Window.Controls.PlaybackControls.Main.Size = UDim2.new(0 + (totalVisible * .135), 0, 0, 32)
		end
	end
end

function MusicControl:GetControlState(control: Control) : ControlState
	return self._controlStates[control]
end

return MusicControl