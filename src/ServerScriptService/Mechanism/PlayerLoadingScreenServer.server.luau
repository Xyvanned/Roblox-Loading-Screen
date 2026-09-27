--[[
	PlayerLoadingScreenServer
	Decides who sees the first (story) loading screen and teleports players
	to Workspace.LoadingScreenRelated.SpawnPoint once it's skipped or finished.

	- New players (profile.Data.HasSeenIntro == false) see it once.
	- The game owner always sees it.
]]

local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("DataRelated"):WaitForChild("PlayerData"))

local remotes = ReplicatedStorage:WaitForChild("Mechanism"):WaitForChild("LoadingScreenRemotes")
local shouldPlayIntro = remotes:WaitForChild("ShouldPlayIntro")
local introFinished = remotes:WaitForChild("IntroFinished")

local SPAWN_HEIGHT_PADDING = 0.5

local cachedOwnerId

local function getOwnerId(): number
	if cachedOwnerId then
		return cachedOwnerId
	end

	if game.CreatorType == Enum.CreatorType.Group then
		local ok, info = pcall(GroupService.GetGroupInfoAsync, GroupService, game.CreatorId)
		if ok and info and info.Owner then
			cachedOwnerId = info.Owner.Id
		end
		return cachedOwnerId or 0
	end

	cachedOwnerId = game.CreatorId
	return cachedOwnerId
end

-- Players currently watching the intro (only these may trigger the teleport)
local watchingIntro: { [Player]: boolean } = {}

shouldPlayIntro.OnServerInvoke = function(player: Player): boolean
	local profile = PlayerData.WaitForProfile(player)
	if not profile then
		return false -- player left / data failed to load
	end

	local play = player.UserId == getOwnerId() or not profile.Data.HasSeenIntro
	watchingIntro[player] = play or nil
	return play
end

local function teleportToSpawn(player: Player)
	local spawnPoint = workspace:WaitForChild("LoadingScreenRelated"):WaitForChild("SpawnPoint")
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local standHeight = if humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3
	local position = spawnPoint.Position
		+ Vector3.new(0, spawnPoint.Size.Y / 2 + standHeight + SPAWN_HEIGHT_PADDING, 0)

	-- Keep the spawn's facing direction but stay upright
	local look = spawnPoint.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end

	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.lookAt(position, position + look.Unit))
end

introFinished.OnServerInvoke = function(player: Player): boolean
	if not watchingIntro[player] then
		return false
	end
	watchingIntro[player] = nil

	local profile = PlayerData.GetProfile(player)
	if profile then
		profile.Data.HasSeenIntro = true -- ProfileStore autosaves
	end

	teleportToSpawn(player)
	return true
end

Players.PlayerRemoving:Connect(function(player)
	watchingIntro[player] = nil
end)
