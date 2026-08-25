local UiImporter = {}

local function color3(t)
	if typeof(t) ~= "table" or #t < 3 then
		return Color3.new(1, 1, 1)
	end
	return Color3.new(t[1], t[2], t[3])
end

local function udim2(t)
	if typeof(t) ~= "table" or #t < 4 then
		return UDim2.new()
	end
	return UDim2.new(t[1], t[2], t[3], t[4])
end

local function applyProps(inst: Instance, d)
	if inst:IsA("GuiObject") then
		if d.ap then inst.AnchorPoint = Vector2.new(d.ap[1], d.ap[2]) end
		if d.sz then inst.Size = udim2(d.sz) end
		if d.ps then inst.Position = udim2(d.ps) end
		if d.bg then inst.BackgroundColor3 = color3(d.bg) end
		if d.bt ~= nil then inst.BackgroundTransparency = d.bt end
		if d.z then inst.ZIndex = d.z end
		if d.vis ~= nil then inst.Visible = d.vis end
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		if d.tx then inst.Text = d.tx end
		if d.tc then inst.TextColor3 = color3(d.tc) end
	end
	if inst:IsA("UIStroke") then
		if d.th then inst.Thickness = d.th end
		if d.sc then inst.Color = color3(d.sc) end
	end
	if inst:IsA("UICorner") then
		if d.rad or d.rado then
			inst.CornerRadius = UDim.new(d.rad or 0, d.rado or 0)
		end
	end
	if inst:IsA("UIGradient") and d.rot then inst.Rotation = d.rot end
	if inst:IsA("UIScale") and d.scl then inst.Scale = d.scl end
	if inst:IsA("UISizeConstraint") then
		if d.mn then inst.MinSize = Vector2.new(d.mn[1], d.mn[2]) end
		if d.mx then inst.MaxSize = Vector2.new(d.mx[1], d.mx[2]) end
	end
	if inst:IsA("UIAspectRatioConstraint") and d.ar then inst.AspectRatio = d.ar end
	if inst:IsA("ScrollingFrame") and d.cds then inst.CanvasSize = udim2(d.cds) end
	if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and d.img then inst.Image = d.img end
end

local function buildNode(d, parent: Instance)
	local inst = Instance.new(d.c)
	inst.Name = d.n
	applyProps(inst, d)
	inst.Parent = parent
	for _, child in d.p or {} do
		buildNode(child, inst)
	end
	return inst
end

function UiImporter.buildScreenGui(data)
	local gui = buildNode(data, nil)
	if gui:IsA("ScreenGui") then
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end
	return gui
end

return UiImporter
