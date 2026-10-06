-- Keyboard shortcut for song search: pressing F (no modifiers) on
-- ScreenSelectMusic does the same thing as SortMenu > "WhereforeArtThou".
--
-- Only active when the "KeyboardFeatures" theme preference is on, which is
-- also the condition for the SortMenu entry. Ctrl+<letter> is handled by the
-- engine ("jump to that letter" in Title sort), so modifier combinations are
-- deliberately left alone here.

local modifiers = {
	["DeviceButton_left ctrl"]   = true,
	["DeviceButton_right ctrl"]  = true,
	["DeviceButton_left shift"]  = true,
	["DeviceButton_right shift"] = true,
	["DeviceButton_left alt"]    = true,
	["DeviceButton_right alt"]   = true,
}

-- modifier keys currently held, as seen by this callback
local held = {}

local input = function(event)
	if not (event and event.DeviceInput) then return false end

	local button = event.DeviceInput.button

	if modifiers[button] then
		if event.type == "InputEventType_FirstPress" then
			held[button] = true
		elseif event.type == "InputEventType_Release" then
			held[button] = nil
		end
		return false
	end

	if button ~= "DeviceButton_f" or event.type ~= "InputEventType_FirstPress" then
		return false
	end

	-- no modifiers: Ctrl+F is already used by the engine
	if next(held) ~= nil then return false end

	-- The engine only fills in PlayerNumber for keys mapped to a game button.
	-- If the player mapped F to a pad or menu button, leave it alone.
	if event.PlayerNumber ~= nil then return false end

	-- Any SongSearch/SortMenu/TestInput/Leaderboard overlay that has taken the
	-- input redirects all players away from the engine; stay out of its way.
	for player in ivalues(PlayerNumber) do
		if SCREENMAN:get_input_redirected(player) then return false end
	end

	local screen = SCREENMAN:GetTopScreen()
	if not screen or screen:GetName() ~= "ScreenSelectMusic" then return false end
	if screen:IsTransitioning() then return false end
	if GAMESTATE:IsCourseMode() then return false end

	local wheel = screen:GetMusicWheel()
	if wheel:IsLocked() then return false end
	-- The ScreenTextEntry will receive the key release, not this screen,
	-- so stop the wheel here in case a direction is being held.
	wheel:Move(0)

	-- same path the SortMenu uses to start the search
	screen:GetChild("Overlay"):GetChild("SortMenu"):queuecommand("DirectInputToEngineForSongSearch")
	return false
end

return Def.Actor{
	OnCommand=function(self)
		if not ThemePrefs.Get("KeyboardFeatures") then return end
		local screen = SCREENMAN:GetTopScreen()
		if screen then screen:AddInputCallback(input) end
	end
}
