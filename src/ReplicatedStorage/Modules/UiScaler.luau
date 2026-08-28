local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local UiScaler = {}

local REF_W = Config.UI_REF_W or 1920
local REF_H = Config.UI_REF_H or 1080
local SCALE_MIN = Config.UI_SCALE_MIN or 0.5
local SCALE_MAX = Config.UI_SCALE_MAX or 1.2

function UiScaler.viewport()
	local cam = Workspace.CurrentCamera
	if cam then
		return cam.ViewportSize
	end
	return Vector2.new(REF_W, REF_H)
end

function UiScaler.computeScale(vp)
	vp = vp or UiScaler.viewport()
	if vp.X < 1 or vp.Y < 1 then
		return 1
	end
	return math.clamp(math.min(vp.X / REF_W, vp.Y / REF_H), SCALE_MIN, SCALE_MAX)
end

function UiScaler.isPortrait()
	local vp = UiScaler.viewport()
	return vp.Y > vp.X * 1.08
end

function UiScaler.scaleFactorOf(gui)
	local s = 1
	local p = gui
	while p do
		local us = p:FindFirstChildWhichIsA("UIScale")
		if us then
			s *= us.Scale
		end
		if p:IsA("LayerCollector") then
			break
		end
		p = p.Parent
	end
	return math.max(s, 0.001)
end

function UiScaler.unscaledSize(gui)
	local s = UiScaler.scaleFactorOf(gui)
	return gui.AbsoluteSize.X / s, gui.AbsoluteSize.Y / s
end

function UiScaler.bind(screenGui)
	if not screenGui or not screenGui:IsA("LayerCollector") then
		return nil
	end
	pcall(function()
		screenGui.IgnoreGuiInset = true
	end)
	local us = screenGui:FindFirstChild("ResponsiveScale")
	if not (us and us:IsA("UIScale")) then
		us = Instance.new("UIScale")
		us.Name = "ResponsiveScale"
		us.Parent = screenGui
	end
	local function apply()
		us.Scale = UiScaler.computeScale()
	end
	apply()
	local function hookCam(cam)
		if not cam then
			return
		end
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		apply()
	end
	hookCam(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hookCam(Workspace.CurrentCamera)
	end)
	return us
end

return UiScaler
