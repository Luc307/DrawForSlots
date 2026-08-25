-- Proximity prompts on lobby casino dummies -> open ShopUI page
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SoundController = require(RS.Modules.SoundController)
local BlockyDummy = require(RS.Modules.BlockyDummy)
local player = Players.LocalPlayer

local PAGE_BY_DUMMY = {
	CasinoDummy_Slots1 = "slots1",
	CasinoDummy_Slots2 = "slots2",
	CasinoDummy_Plinko = "slots3",
	CasinoDummy_Wheel = "wheel",
	CasinoDummy_Mines = "mines",
}

local wired: { [ProximityPrompt]: boolean } = {}

local function getOpenEvent()
	local signals = RS:WaitForChild("Signals", 30)
	if not signals then
		return nil
	end
	return signals:WaitForChild("RequestOpenUI", 30)
end

local function wireDummy(dummy: Model, openEvent: BindableEvent)
	BlockyDummy.makePassable(dummy)
	local pageName = PAGE_BY_DUMMY[dummy.Name]
	if not pageName then
		return
	end

	local hrp = dummy:FindFirstChild("HumanoidRootPart") or dummy:WaitForChild("HumanoidRootPart", 15)
	if not hrp then
		return
	end

	local prompt = hrp:FindFirstChild("CasinoGamePrompt") or hrp:WaitForChild("CasinoGamePrompt", 15)
	if not (prompt and prompt:IsA("ProximityPrompt")) then
		return
	end
	if wired[prompt] then
		return
	end
	wired[prompt] = true

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer and triggerPlayer ~= player then
			return
		end
		SoundController.playClick()
		openEvent:Fire(pageName)
	end)
end

task.spawn(function()
	local openEvent = getOpenEvent()
	if not openEvent then
		warn("[ShopUICasinoWire] RequestOpenUI missing")
		return
	end

	local lobby = Workspace:WaitForChild("Floating Lobby", 30)
	if not lobby then
		return
	end

	local dummiesFolder = lobby:WaitForChild("Dummies", 30)
	if not dummiesFolder then
		return
	end

	local function scan()
		for _, child in dummiesFolder:GetChildren() do
			if child:IsA("Model") then
				BlockyDummy.makePassable(child)
				wireDummy(child, openEvent)
			end
		end
	end

	scan()
	dummiesFolder.ChildAdded:Connect(function(child)
		task.defer(function()
			if child:IsA("Model") then
				BlockyDummy.makePassable(child)
				wireDummy(child, openEvent)
			end
		end)
	end)
	-- Humanoid can re-enable collide shortly after load
	task.delay(0.5, scan)
	task.delay(2, scan)
end)
