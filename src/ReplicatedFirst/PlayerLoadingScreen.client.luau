--[[
	PlayerLoadingScreen (ReplicatedFirst)
	First designated loading screen: the story intro for new players (and
	always for the owner). Every UI element is built here in code.

	Optimizations:
	- One reusable ImageLabel for all 30 story images (swap Image between
	  fades) instead of 30 labels.
	- All image IDs preloaded as content strings; the first two block, the
	  rest stream in the background.
	- Late fade tweens are cancelled so they can't overwrite the next line.
	- The ScreenGui is destroyed when done, freeing everything.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// CONFIGURATION -----------------------------------------------------------
local FADE_IN_TIME = 1       -- image fade in
local DISPLAY_TIME = 5       -- image fully visible (text finishes typing at half of this)
local FADE_OUT_TIME = 1.5    -- image + text fade out
local SKIP_DELAY = 10        -- seconds before the skip hint appears
local MUSIC_ID = "rbxassetid://1842248801"
local SKIP_SOUND_ID = "rbxassetid://1843987583"
local MUSIC_VOLUME = 0.5
local ZOOM_SCALE = 1.06      -- slow push-in on each image
local STROKE_TRANSPARENCY = 0.1

local FONT = Font.new("rbxasset://fonts/families/SpecialElite.json")

-- { image id, story line }
local SEQUENCE = {
	{ "83931376041255", "A Peaceful morning." },
	{ "83594455036799", "Players explore the map." },
	{ "128295043247862", "Find clues and explore." },
	{ "117922989046379", "Collect scattered clues." },
	{ "132706537067428", "Solve puzzles to progress." },
	{ "75805948337642", "Multiple puzzle locations around the map." },
	{ "139983487695228", "Continue exploring." },
	{ "82263554984553", "Prepare before night." },
	{ "115575357397392", "As the sun sets..." },
	{ "130092738270643", "The night comes." },
	{ "82284335147838", "They awaken." },
	{ "91654849325721", "Subject 33 transforms." },
	{ "115906232265367", "Subject 204 transforms." },
	{ "106441801483548", "Both subjects are now active." },
	{ "90836260536147", "Players hide inside cabins." },
	{ "98920875556639", "They roam and hunt." },
	{ "107272999527679", "Listen... stay quiet." },
	{ "97004324529192", "They patrol the map." },
	{ "110174847855826", "Avoid being seen." },
	{ "85020026174147", "They search puzzle areas too." },
	{ "110801327737691", "Players must still complete puzzles during the night." },
	{ "87244881915179", "Be careful while solving." },
	{ "140293286190090", "If caught..." },
	{ "84407978360906", "You'll be taken." },
	{ "97762218136592", "Game over if all are caught." },
	{ "94143759366854", "Survive until dawn." },
	{ "94233987416819", "The dawn returns." },
	{ "110258551371373", "Both subjects return to their normal human form." },
	{ "98690690764805", "A new day begins." },
	{ "98066017170361", "Explore again. The cycle continues..." },
}
-------------------------------------------------------------------------------

--// UI builder -------------------------------------------------------------
local function create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for property, value in props do
		if property ~= "Parent" then
			(instance :: any)[property] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local gui = create("ScreenGui", {
	Name = "PlayerLoadingScreen",
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ResetOnSpawn = false,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local story = create("Frame", {
	Name = "Story",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 1,
	Parent = gui,
})

local storyImage = create("ImageLabel", {
	Name = "StoryImage",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	ScaleType = Enum.ScaleType.Crop,
	BackgroundTransparency = 1,
	ImageTransparency = 1,
	ImageColor3 = Color3.fromRGB(235, 222, 222),
	ZIndex = 2,
	Parent = story,
})

-- Cinematic vignette: black -> blood-red edges, centre fully clear
local EDGE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 0, 0)),
})
local EDGE_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.35, 0.45),
	NumberSequenceKeypoint.new(0.75, 0.9),
	NumberSequenceKeypoint.new(1, 1),
})

local vignette = create("Frame", {
	Name = "Vignette",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 10,
	Parent = story,
})

local function edge(name: string, position: UDim2, size: UDim2, rotation: number)
	create("Frame", {
		Name = name,
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = vignette,
	}, {
		create("UIGradient", { Color = EDGE_COLOR, Transparency = EDGE_FADE, Rotation = rotation }),
	})
end
edge("Top", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.3), 90)
edge("Bottom", UDim2.fromScale(0, 0.7), UDim2.fromScale(1, 0.3), -90)
edge("Left", UDim2.fromScale(0, 0), UDim2.fromScale(0.22, 1), 0)
edge("Right", UDim2.fromScale(0.78, 0), UDim2.fromScale(0.22, 1), 180)

for _, barInfo in { { "LetterboxTop", 0 }, { "LetterboxBottom", 0.95 } } do
	create("Frame", {
		Name = barInfo[1],
		Position = UDim2.fromScale(0, barInfo[2]),
		Size = UDim2.fromScale(1, 0.05),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = story,
	})
end

local storyStroke = create("UIStroke", {
	Color = Color3.fromRGB(35, 0, 0),
	Thickness = 1,
	Transparency = 1,
})

local storyText = create("TextLabel", {
	Name = "StoryText",
	Position = UDim2.new(0, 0, 0.85, 0),
	Size = UDim2.new(1, 0, 0.04, 0),
	BackgroundTransparency = 1,
	FontFace = FONT,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	TextWrapped = true,
	TextTransparency = 1,
	MaxVisibleGraphemes = 0,
	ZIndex = 20,
	Parent = story,
}, {
	create("UIPadding", { PaddingLeft = UDim.new(0.1, 0), PaddingRight = UDim.new(0.1, 0) }),
	create("UITextSizeConstraint", { MinTextSize = 7, MaxTextSize = 18 }),
	-- Bone-white fading into dried blood towards the bottom of the letters
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 236, 226)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(222, 190, 182)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 24, 24)),
		}),
	}),
	storyStroke,
})

local skipLabel = create("TextLabel", {
	Name = "SkipLabel",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -8),
	Size = UDim2.fromOffset(300, 24),
	BackgroundTransparency = 1,
	FontFace = FONT,
	Text = "Click anywhere to skip",
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(200, 60, 55),
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	Visible = false,
	ZIndex = 21,
	Parent = story,
})

local fade = create("Frame", {
	Name = "Fade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 30,
	Parent = story,
})

local music = create("Sound", { Name = "StoryMusic", SoundId = MUSIC_ID, Looped = true, Volume = 0, Parent = gui })
local skipSound = create("Sound", { Name = "SkipSound", SoundId = SKIP_SOUND_ID, Volume = 0.8, Parent = gui })

gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

--// Helpers ----------------------------------------------------------------
local function tween(instance: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		props
	)
	t:Play()
	return t
end

-- CoreGui may not be ready this early in ReplicatedFirst, so retry briefly
local function setCoreGuiEnabled(enabled: boolean)
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, enabled) then
				return
			end
			task.wait(0.25)
		end
	end)
end

--// Server decision --------------------------------------------------------
local remotes = ReplicatedStorage:WaitForChild("Mechanism"):WaitForChild("LoadingScreenRemotes")
local shouldPlayIntro = remotes:WaitForChild("ShouldPlayIntro")
local introFinished = remotes:WaitForChild("IntroFinished")

local ok, shouldPlay = pcall(function()
	return shouldPlayIntro:InvokeServer()
end)
if not ok or not shouldPlay then
	-- Returning player: keep the black cover until the game has loaded
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	tween(story, 0.6, { BackgroundTransparency = 1 }).Completed:Wait()
	gui:Destroy()
	return
end

--// State ------------------------------------------------------------------
local skipped = false
local skipEnabled = false
local skipPulse: Tween? = nil
local pendingTweens: { Tween } = {}

local function waitUnlessSkipped(seconds: number)
	local elapsed = 0
	while elapsed < seconds and not skipped do
		elapsed += task.wait()
	end
end

-- Cancels fades from the previous slide so a late tween can't hide the next one
local function cancelPendingTweens()
	for _, t in pendingTweens do
		t:Cancel()
	end
	table.clear(pendingTweens)
end

local function track(t: Tween): Tween
	table.insert(pendingTweens, t)
	return t
end

local function typeText(text: string, duration: number)
	local length = utf8.len(text) or #text
	local elapsed = 0
	while elapsed < duration and not skipped do
		elapsed += task.wait()
		storyText.MaxVisibleGraphemes = math.floor(length * math.min(elapsed / duration, 1))
	end
	storyText.MaxVisibleGraphemes = -1
end

--// Lock the player in while the story plays -----------------------------
-- Freeze the local humanoid (movement is simulated on the owning client)
local frozenHumanoid: Humanoid? = nil
local savedMovement = {}

local function freezeCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	frozenHumanoid = humanoid
	savedMovement = {
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
end

local function unfreezeCharacter()
	if frozenHumanoid and frozenHumanoid.Parent then
		for property, value in savedMovement do
			(frozenHumanoid :: any)[property] = value
		end
	end
	frozenHumanoid = nil
end

task.spawn(function()
	freezeCharacter(player.Character or player.CharacterAdded:Wait())
end)
setCoreGuiEnabled(false)

--// Skip input -------------------------------------------------------------
task.delay(SKIP_DELAY, function()
	if skipped then
		return
	end
	skipEnabled = true
	skipLabel.Visible = true
	tween(skipLabel, 1, { TextTransparency = 0.15, TextStrokeTransparency = 0.4 }).Completed:Wait()
	if skipped then
		return
	end
	skipPulse = TweenService:Create(
		skipLabel,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ TextTransparency = 0.7, TextStrokeTransparency = 0.9 }
	)
	skipPulse:Play()
end)

local inputConnection = UserInputService.InputBegan:Connect(function(input)
	if not skipEnabled or skipped then
		return
	end
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.ButtonA
	then
		skipped = true
		skipSound:Play()
	end
end)

--// Preload ----------------------------------------------------------------
local imageIds = table.create(#SEQUENCE)
for i, entry in SEQUENCE do
	imageIds[i] = "rbxassetid://" .. entry[1]
end

pcall(ContentProvider.PreloadAsync, ContentProvider, { imageIds[1], imageIds[2], MUSIC_ID, SKIP_SOUND_ID })
task.spawn(function()
	pcall(ContentProvider.PreloadAsync, ContentProvider, table.move(imageIds, 3, #imageIds, 1, {}))
end)

music:Play()
tween(music, 3, { Volume = MUSIC_VOLUME })

--// Sequence ---------------------------------------------------------------
for i, entry in SEQUENCE do
	if skipped then
		break
	end

	local text = entry[2]
	cancelPendingTweens()

	storyImage.Image = imageIds[i]
	storyImage.ImageTransparency = 1
	storyImage.Size = UDim2.fromScale(1, 1)
	storyText.Text = text
	storyText.MaxVisibleGraphemes = 0
	storyText.TextTransparency = 0
	storyStroke.Transparency = STROKE_TRANSPARENCY

	track(tween(storyImage, FADE_IN_TIME, { ImageTransparency = 0 }))
	track(tween(
		storyImage,
		FADE_IN_TIME + DISPLAY_TIME + FADE_OUT_TIME,
		{ Size = UDim2.fromScale(ZOOM_SCALE, ZOOM_SCALE) },
		Enum.EasingStyle.Linear
	))
	waitUnlessSkipped(FADE_IN_TIME)

	typeText(text, DISPLAY_TIME / 2)
	waitUnlessSkipped(DISPLAY_TIME / 2)

	if skipped then
		break
	end

	track(tween(storyImage, FADE_OUT_TIME, { ImageTransparency = 1 }))
	track(tween(storyText, FADE_OUT_TIME, { TextTransparency = 1 }))
	track(tween(storyStroke, FADE_OUT_TIME, { Transparency = 1 }))
	waitUnlessSkipped(FADE_OUT_TIME)
end

--// Finish (skipped or story complete) -------------------------------------
skipEnabled = false
inputConnection:Disconnect()
if skipPulse then
	skipPulse:Cancel()
end
tween(skipLabel, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
tween(music, 1.5, { Volume = 0 })
tween(fade, 1.2, { BackgroundTransparency = 0 }).Completed:Wait()

-- Teleport happens while the screen is black
pcall(function()
	introFinished:InvokeServer()
end)

cancelPendingTweens()
music:Stop()
storyImage.Visible = false
storyText.Visible = false
story.BackgroundTransparency = 1

unfreezeCharacter()
setCoreGuiEnabled(true)

tween(fade, 1.5, { BackgroundTransparency = 1 }).Completed:Wait()
gui:Destroy()
