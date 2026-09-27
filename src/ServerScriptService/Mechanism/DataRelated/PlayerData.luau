--[[
	PlayerData
	Central ProfileStore session manager. Every system that needs saved
	player data should go through this module instead of DataStoreService.

	Usage (server only):
		local PlayerData = require(ServerScriptService.Mechanism.DataRelated.PlayerData)
		local profile = PlayerData.WaitForProfile(player) -- yields; nil if the player left
		if profile then
			profile.Data.HasSeenIntro = true
		end

	Add new saved fields to PROFILE_TEMPLATE; Reconcile() fills them in for
	existing players automatically.
]]

local Players = game:GetService("Players")

local ProfileStore = require(script.Parent:WaitForChild("ProfileStore"))

--// CONFIGURATION -----------------------------------------------------------
local STORE_NAME = "PlayerData_v1"

local PROFILE_TEMPLATE = {
	HasSeenIntro = false, -- first designated loading screen (story) finished or skipped
}
-------------------------------------------------------------------------------

local PlayerStore = ProfileStore.New(STORE_NAME, PROFILE_TEMPLATE)

local PlayerData = {}

local profiles: { [Player]: any } = {}
local loadFailed: { [Player]: boolean } = {}

local function onPlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		loadFailed[player] = true
		player:Kick("Your data couldn't be loaded. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)

	if player.Parent == Players then
		profiles[player] = profile
	else
		profile:EndSession()
	end
end

--- Returns the loaded profile or nil (doesn't yield).
function PlayerData.GetProfile(player: Player)
	return profiles[player]
end

--- Yields until the player's profile is loaded. Returns nil if the player
--- left, loading failed, or the optional timeout ran out.
function PlayerData.WaitForProfile(player: Player, timeout: number?)
	local start = os.clock()
	while not profiles[player] and not loadFailed[player] and player.Parent == Players do
		if timeout and os.clock() - start >= timeout then
			break
		end
		task.wait()
	end
	return profiles[player]
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	profiles[player] = nil
	loadFailed[player] = nil
	if profile then
		profile:EndSession()
	end
end)

return PlayerData
