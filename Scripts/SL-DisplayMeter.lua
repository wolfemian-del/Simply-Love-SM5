-- SL-DisplayMeter.lua
--
-- Chooses which difficulty number the theme shows for a Steps object:
-- the chart's official meter, the modeled rating from DifficultyModel.lua,
-- or both.  Display only: scores, GrooveStats hashes, the engine's Meter
-- sort, Casual mode's meter limit and Course meters are unaffected.
--
-- Theme pref "DifficultyDisplay": Official | Modeled | Both | PerPack
-- Pack.ini (used when the pref is PerPack):
--     [Group]
--     DifficultyMode=official   (or: modeled, both)
-- Packs without the key show Official.  Pack.ini is read once per pack per
-- session; restart the game after editing it.
--
-- If DifficultyModel is not installed, or it cannot rate a chart (not
-- dance-single, no cached data, Edit charts, Course mode), the official
-- meter is shown.

DisplayMeter = {}

local memo      = {}  -- chart key -> modeled rating (or false)
local pack_mode = {}  -- pack folder -> "official" | "modeled" | "both"

local VALID = { official=true, modeled=true, both=true }

local function Pref()
	local v = ThemePrefs and ThemePrefs.Get("DifficultyDisplay")
	if v == "Modeled" or v == "Both" or v == "PerPack" then return v end
	return "Official"
end

-- Reads [Group] DifficultyMode from the Pack.ini of the chart's pack.
-- steps:GetFilename() is ".../<Pack>/<Song>/<chart file>", so dropping the
-- last two path components gives the pack folder.
local function PackMode(steps)
	local fn = steps:GetFilename()
	if not fn or fn == "" then return "official" end
	local dir = fn:match("^(.*)/[^/]+/[^/]+$")
	if not dir then return "official" end

	local cached = pack_mode[dir]
	if cached then return cached end

	local mode = "official"
	local path = dir .. "/Pack.ini"
	if FILEMAN:DoesFileExist(path) then
		local ini   = IniFile.ReadFile(path)
		local group = ini and ini["Group"]
		if type(group) == "table" then
			-- IniFile.ReadFile does not trim keys ("Key = value" gives "Key "),
			-- so match the key case-insensitively with whitespace removed.
			for k, v in pairs(group) do
				if type(k) == "string" and type(v) == "string"
				and k:gsub("%s+", ""):lower() == "difficultymode" then
					v = v:gsub("^%s+", ""):gsub("%s+$", ""):lower()
					if VALID[v] then mode = v end
				end
			end
		end
	end
	pack_mode[dir] = mode
	return mode
end

-- "official", "modeled" or "both" for this chart.
local function Mode(steps)
	local p = Pref()
	if p == "Official" then return "official" end
	if p == "PerPack"  then return PackMode(steps) end
	return p:lower()
end

local function Modeled(steps)
	if not DifficultyModel or not DifficultyModel.Rating then return nil end
	if GAMESTATE:IsCourseMode() then return nil end
	if steps:IsAnEdit() then return nil end

	local key = table.concat({
		steps:GetFilename() or "", tostring(steps:GetStepsType()),
		tostring(steps:GetDifficulty()), steps:GetDescription() or ""
	}, "|")
	local v = memo[key]
	if v == nil then
		v = DifficultyModel.Rating(steps) or false
		memo[key] = v
	end
	return v or nil
end

-- Number the theme should treat as this chart's meter.
function DisplayMeter.Number(steps)
	if not steps then return nil end
	if Mode(steps) ~= "official" then
		local r = Modeled(steps)
		if r then return r end
	end
	return steps:GetMeter()
end

-- Text to show.  compact=true (small cells) never shows the "13 (12)" form.
function DisplayMeter.Text(steps, compact)
	if not steps then return "" end
	local official = steps:GetMeter()
	local m = Mode(steps)
	if m == "official" then return tostring(official) end
	local r = Modeled(steps)
	if not r then return tostring(official) end
	if m == "both" and not compact and r ~= official then
		return ("%d (%d)"):format(r, official)
	end
	return tostring(r)
end

-- For difficulty filters: does this chart match meter n?
-- In Both mode the official meter also matches.
function DisplayMeter.Matches(steps, n)
	if DisplayMeter.Number(steps) == n then return true end
	return Mode(steps) == "both" and steps:GetMeter() == n
end

-- Forget cached ratings and Pack.ini reads (e.g. after reloading songs).
function DisplayMeter.Reset()
	memo, pack_mode = {}, {}
end
