local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local MusicControl = require(game.ReplicatedStorage.MusicControl)

local Audios = {
	"rbxassetid://1841647093",
	"rbxassetid://1837768517",
	"rbxassetid://118939739460633",
	"rbxassetid://1838457617",
	"rbxassetid://1846458016",
	"rbxassetid://1845341094",
	"rbxassetid://1846575559"
}

local Music = MusicControl.new()
local data = AssetService:GetAudioMetadataAsync(Audios)

local currentIndex = 1
local history = {currentIndex}
local Audio = Instance.new("Sound")
Audio.Parent = script
function changeSong(newindex)
	Audio:Stop()
	Audio.SoundId = Audios[newindex]
	Audio:Play()
	Audio.Loaded:Wait()
	Audio.TimePosition = 0
	Music:SetTitle(data[newindex].Title)
	Music:SetArtist(data[newindex].Artist)
	Music:SetPlaybackLength(Audio.TimeLength)
	Music:SetPlaybackPosition(Audio.TimePosition)
	Music:SetPlaying(true)
end
changeSong(currentIndex)
Music.VolumeStep = 0.1

function previousSong()
	if #history > 1 then
		table.remove(history)
		currentIndex = history[#history]
		changeSong(currentIndex)
	else
		Audio.TimePosition = 0
		Music:SetPlaybackPosition(0)
	end
end

Music.OnShufflePressed:Connect(function()
	Music:SetShuffle(not Music:GetShuffle())
end)

Music.OnRewindPressed:Connect(function()
	if Audio.TimePosition < 3 and #history > 1 then
		previousSong()
	else
		Audio.TimePosition = 0
	end
	Audio.Playing = true
	Music:SetPlaying(Audio.Playing)
end)

Music.OnPlayPausePressed:Connect(function()
	Audio.Playing = not Audio.Playing
	Music:SetPlaying(Audio.Playing)
end)

function nextSong()
	local lastPlayedIndex = currentIndex

	if Music:GetRepeat() == "RepeatOne" then
		changeSong(currentIndex)
		return
	end

	if not Music:GetShuffle() then
		currentIndex += 1
		if currentIndex > #Audios then
			if Music:GetRepeat() == "Repeat" then
				currentIndex = 1
			else
				Audio:Stop()
				Music:SetPlaying(false)
				currentIndex = #Audios
				return
			end
		end
	else
		repeat 
			currentIndex = math.random(1, #Audios) 
		until currentIndex ~= lastPlayedIndex or #Audios == 1
	end

	table.insert(history, currentIndex)
	changeSong(currentIndex)
end

Audio.Ended:Connect(nextSong)
Music.OnSkipPressed:Connect(nextSong)

local repeats = {"Off", "Repeat", "RepeatOne"}
local repeatIndex = 1
Music.OnRepeatPressed:Connect(function()
	repeatIndex += 1
	if repeatIndex > #repeats then
		repeatIndex = 1
	end
	Music:SetRepeat(repeats[repeatIndex])
	Audio.Looped = Music:GetRepeat() == "RepeatOne"
end)

Music.OnVolumeAdjust:Connect(function(value: number)
	Audio.Volume = value
	Music:SetVolumePosition(value)
end)

Music.OnPlaybackAdjust:Connect(function(value: number)
	Audio.TimePosition = value * Audio.TimeLength
end)

RunService.RenderStepped:Connect(function(dt: number)
	Music:SetPlaybackPosition(Audio.TimePosition)
end)