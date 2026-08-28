local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local BlockyDummy = {}

local PASS_GROUP = "LobbyDummy"
local passGroupReady = false

local function ensurePassGroup()
	if passGroupReady or not RunService:IsServer() then
		return
	end
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PASS_GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(PASS_GROUP, "Default", false)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(PASS_GROUP, "Player", false)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(PASS_GROUP, "Players", false)
	end)
	passGroupReady = true
end

export type JobStyle = {
	limbColor: Color3,
	bodyColor: Color3,
	labelColor: Color3,
}

local JOB_STYLES: { [string]: JobStyle } = {
	queue3 = {
		limbColor = Color3.fromRGB(202, 203, 209),
		bodyColor = Color3.fromRGB(45, 95, 180),
		labelColor = Color3.fromRGB(120, 180, 255),
	},
	queue4 = {
		limbColor = Color3.fromRGB(202, 203, 209),
		bodyColor = Color3.fromRGB(95, 55, 160),
		labelColor = Color3.fromRGB(180, 140, 255),
	},
	queue5 = {
		limbColor = Color3.fromRGB(202, 203, 209),
		bodyColor = Color3.fromRGB(30, 140, 95),
		labelColor = Color3.fromRGB(90, 230, 170),
	},
	casino = {
		limbColor = Color3.fromRGB(235, 210, 150),
		bodyColor = Color3.fromRGB(120, 35, 45),
		labelColor = Color3.fromRGB(255, 210, 80),
	},
}

local DEFAULT_STYLE = JOB_STYLES.queue5

function BlockyDummy.applyBlockyScales(desc: HumanoidDescription): HumanoidDescription
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	desc.Head = 0
	desc.Torso = 0
	desc.LeftArm = 0
	desc.RightArm = 0
	desc.LeftLeg = 0
	desc.RightLeg = 0
	desc.HeadScale = 1
	desc.HeightScale = 1
	desc.WidthScale = 1
	desc.DepthScale = 1
	return desc
end

function BlockyDummy.buildDescription(styleKey: string?): HumanoidDescription
	local style = if styleKey then JOB_STYLES[styleKey] else DEFAULT_STYLE
	style = style or DEFAULT_STYLE
	local desc = BlockyDummy.applyBlockyScales(Instance.new("HumanoidDescription"))
	desc.HeadColor = style.limbColor
	desc.LeftArmColor = style.limbColor
	desc.RightArmColor = style.limbColor
	desc.TorsoColor = style.bodyColor
	desc.LeftLegColor = style.bodyColor
	desc.RightLegColor = style.bodyColor
	desc.Shirt = 0
	desc.Pants = 0
	desc.GraphicTShirt = 0
	desc.HatAccessory = ""
	desc.HairAccessory = ""
	desc.FaceAccessory = ""
	desc.NeckAccessory = ""
	desc.ShouldersAccessory = ""
	desc.FrontAccessory = ""
	desc.BackAccessory = ""
	desc.WaistAccessory = ""
	return desc
end

local function applyPartLook(model: Model)
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") and inst.Name ~= "HumanoidRootPart" then
			inst.Material = Enum.Material.SmoothPlastic
		end
	end
end

function BlockyDummy.applyNaturalLook(model: Model, styleKey: string?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and model:IsDescendantOf(game) then
		pcall(function()
			humanoid:ApplyDescription(BlockyDummy.buildDescription(styleKey))
		end)
	end
	applyPartLook(model)
end

function BlockyDummy.ensureSubLabel(model: Model, text: string, styleKey: string?)
	local style = if styleKey then JOB_STYLES[styleKey] else DEFAULT_STYLE
	style = style or DEFAULT_STYLE
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local billboard = head:FindFirstChild("SubLabel")
	if not billboard then
		warn("[BlockyDummy] Missing SubLabel on", model:GetFullName())
		return
	end

	local label = billboard:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
		local muted = style.labelColor:Lerp(Color3.fromRGB(180, 180, 190), 0.55)
		label.TextColor3 = muted
		label.TextTransparency = 0.25
	end
end

function BlockyDummy.ensureJobLabel(model: Model, text: string, styleKey: string?)
	local style = if styleKey then JOB_STYLES[styleKey] else DEFAULT_STYLE
	style = style or DEFAULT_STYLE
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local billboard = head:FindFirstChild("JobLabel")
	if not billboard then
		warn("[BlockyDummy] Missing JobLabel on", model:GetFullName())
		return
	end

	local label = billboard:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
		label.TextColor3 = style.labelColor
	end
end

local function copyPlayerColors(dummyDesc: HumanoidDescription, playerDesc: HumanoidDescription)
	dummyDesc.HeadColor = playerDesc.HeadColor
	dummyDesc.LeftArmColor = playerDesc.LeftArmColor
	dummyDesc.RightArmColor = playerDesc.RightArmColor
	dummyDesc.TorsoColor = playerDesc.TorsoColor
	dummyDesc.LeftLegColor = playerDesc.LeftLegColor
	dummyDesc.RightLegColor = playerDesc.RightLegColor
end

function BlockyDummy.buildPlayerDescription(player: Player): HumanoidDescription
	local dummyDesc = BlockyDummy.buildDescription()
	local ok, playerDesc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
	end)
	if ok and playerDesc then
		copyPlayerColors(dummyDesc, playerDesc)
	end
	return dummyDesc
end

function BlockyDummy.applyToCharacter(character: Model, player: Player?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	humanoid.AutomaticScalingEnabled = false

	local dummyDesc = if player
		then BlockyDummy.buildPlayerDescription(player)
		else BlockyDummy.buildDescription()

	local ok = pcall(function()
		humanoid:ApplyDescriptionReset(dummyDesc)
	end)
	if not ok then
		humanoid:ApplyDescription(dummyDesc)
	end

	for _, child in character:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
end

function BlockyDummy.makePassable(model: Model)
	ensurePassGroup()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		pcall(function()
			(humanoid :: any).EvaluateStateMachine = false
		end)
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end
	local isServer = RunService:IsServer()
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.Massless = true
			if isServer then
				inst.CollisionGroup = PASS_GROUP
			end
		end
	end
end

function BlockyDummy.freeze(model: Model, styleKey: string?, skipLook: boolean?)
	for _, inst in model:GetDescendants() do
		if inst:IsA("Script") or inst:IsA("LocalScript") then
			inst:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		model.PrimaryPart = hrp
	end
	if skipLook then
		applyPartLook(model)
		BlockyDummy.makePassable(model)
	else
		BlockyDummy.applyNaturalLook(model, styleKey)
		BlockyDummy.makePassable(model)
	end
end

function BlockyDummy.styleLobbyDummy(model: Model, labelText: string, styleKey: string?, subLabelText: string?)
	BlockyDummy.applyNaturalLook(model, styleKey)
	BlockyDummy.makePassable(model)
	BlockyDummy.ensureJobLabel(model, labelText, styleKey)
	if subLabelText and subLabelText ~= "" then
		BlockyDummy.ensureSubLabel(model, subLabelText, styleKey)
	end
end

function BlockyDummy.isUnstyled(model: Model): boolean
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Color.R < 0.05 and head.Color.G < 0.05 and head.Color.B < 0.05
	end
	return true
end

function BlockyDummy.create(name: string, pivot: CFrame, styleKey: string?): Model
	local model = Players:CreateHumanoidModelFromDescription(BlockyDummy.buildDescription(styleKey), Enum.HumanoidRigType.R15)
	model.Name = name
	BlockyDummy.freeze(model, styleKey, true)
	model:PivotTo(pivot)
	return model
end

function BlockyDummy.getFolder(lobby: Instance): Folder?
	local folder = lobby:FindFirstChild("Dummies") or lobby:FindFirstChild("QueueDummies")
	if folder and folder:IsA("Folder") then
		folder.Name = "Dummies"
		return folder
	end
	warn("[BlockyDummy] Missing Dummies folder under", lobby:GetFullName())
	return nil
end

return BlockyDummy
