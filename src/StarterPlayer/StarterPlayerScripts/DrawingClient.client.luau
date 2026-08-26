local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local Config        = require(ReplicatedStorage:WaitForChild("GameConfig"))
local SubmitDrawing = Remotes:WaitForChild("SubmitDrawing")
local SyncTimer     = Remotes:WaitForChild("SyncTimer")

local Signals = ReplicatedStorage:WaitForChild("Signals")
local DrawActiveEvent = Signals:WaitForChild("DrawActiveEvent")
local RenderStrokesEvent = Signals:WaitForChild("RenderStrokesEvent")

local CANVAS_W = Config.CANVAS_W
local CANVAS_H = Config.CANVAS_H
-- Keep stroke density low so clients do not freeze / disconnect mid-draw.
local MIN_POINT_GAP = 4
local MAX_STROKE_POINTS = 120
local MAX_TOTAL_POINTS = 800
local STAMP_CAP = 32

local drawState = {
    active        = false,
    isDrawing     = false,
    currentColor  = Color3.fromRGB(0, 0, 0),
    currentSize   = 4,
    strokes       = {},
    currentStroke = nil,
    undoStack     = {},
    canvas        = nil,
    submitted     = false,
    activeTouchId = nil,
    totalPoints   = 0,
}

local COLORS = {
    Color3.fromRGB(0,0,0),     Color3.fromRGB(255,255,255),
    Color3.fromRGB(220,50,50), Color3.fromRGB(255,140,0),
    Color3.fromRGB(50,200,50), Color3.fromRGB(50,100,255),
    Color3.fromRGB(160,50,255),Color3.fromRGB(0,220,200),
    Color3.fromRGB(255,80,180),Color3.fromRGB(255,200,220),
}
local SIZES = Config.BRUSH_SIZES

local function drawDot(canvas, x, y, color, radius)
    local d = math.max(2, radius * 2)
    local dot = Instance.new("Frame")
    dot.Name             = "Dot"
    dot.BackgroundColor3 = color
    dot.BorderSizePixel  = 0
    dot.Size             = UDim2.new(0, d, 0, d)
    dot.Position         = UDim2.new(0, x - d * 0.5, 0, y - d * 0.5)
    dot.ZIndex           = 2
    dot.Parent           = canvas
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = dot
end

-- Overlapping circle stamps. Rotated frames + UICorner look dotted at M/L sizes
-- and leak past ClipsDescendants.
local function drawLine(canvas, x1, y1, x2, y2, color, radius)
    local dx, dy = x2 - x1, y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = math.max(1.15, radius * 0.38)
    if dist < step then
        drawDot(canvas, x2, y2, color, radius)
        return
    end
    local n = math.ceil(dist / step)
    if n > STAMP_CAP then n = STAMP_CAP end
    for i = 1, n do
        local t = i / n
        drawDot(canvas, x1 + dx * t, y1 + dy * t, color, radius)
    end
end

local function clearCanvas(canvas)
    local layer = canvas:FindFirstChild("StrokeLayer")
    local roots = { canvas }
    if layer then table.insert(roots, layer) end
    for _, root in ipairs(roots) do
        for _, c in ipairs(root:GetChildren()) do
            if c.Name == "Dot" or c.Name == "Seg" then c:Destroy() end
        end
    end
end

local function ensureStrokeLayer(canvas)
    canvas.ClipsDescendants = true
    local layer = canvas:FindFirstChild("StrokeLayer")
    if not layer then
        layer = Instance.new("Frame")
        layer.Name = "StrokeLayer"
        layer.BackgroundTransparency = 1
        layer.BorderSizePixel = 0
        layer.Size = UDim2.fromScale(1, 1)
        layer.Position = UDim2.fromScale(0, 0)
        layer.ClipsDescendants = true
        layer.ZIndex = 2
        layer.Parent = canvas
    else
        layer.ClipsDescendants = true
        layer.Size = UDim2.fromScale(1, 1)
    end
    return layer
end

local function toPx(canvas, lx, ly)
    local sz = canvas.AbsoluteSize
    return lx / CANVAS_W * sz.X, ly / CANVAS_H * sz.Y
end

local function sizePx(canvas, logicalSize)
    local sz = canvas.AbsoluteSize
    local s = math.min(sz.X / CANVAS_W, sz.Y / CANVAS_H)
    if s <= 0 then s = 1 end
    return math.max(1, logicalSize * s)
end

local function renderStrokes(canvas, strokes, targetW, targetH)
    if not canvas or not strokes then return end
    local layer = ensureStrokeLayer(canvas)
    clearCanvas(canvas)
    local tw = targetW
    local th = targetH
    if not tw or tw <= 1 then tw = layer.AbsoluteSize.X end
    if not th or th <= 1 then th = layer.AbsoluteSize.Y end
    if tw <= 1 then tw = CANVAS_W end
    if th <= 1 then th = CANVAS_H end
    local scale = math.min(tw / CANVAS_W, th / CANVAS_H)
    local ox = (tw - CANVAS_W * scale) * 0.5
    local oy = (th - CANVAS_H * scale) * 0.5
    for _, stroke in ipairs(strokes) do
        local ok, color = pcall(function()
            return Color3.fromRGB(stroke.r or 0, stroke.g or 0, stroke.b or 0)
        end)
        if not ok then color = Color3.fromRGB(0,0,0) end
        local radius = math.max(1, (stroke.size or 4) * scale)
        local points = stroke.points
        if not points or #points == 0 then continue end
        local x1 = ox + points[1].x * scale
        local y1 = oy + points[1].y * scale
        drawDot(layer, x1, y1, color, radius)
        for i = 2, #points do
            local x2 = ox + points[i].x * scale
            local y2 = oy + points[i].y * scale
            drawLine(layer, x1, y1, x2, y2, color, radius)
            x1, y1 = x2, y2
        end
    end
end

local function serializeStrokes(strokes)
    local data = {}
    for _, stroke in ipairs(strokes) do
        table.insert(data, {
            r      = math.floor(stroke.color.R * 255),
            g      = math.floor(stroke.color.G * 255),
            b      = math.floor(stroke.color.B * 255),
            size   = stroke.size,
            points = stroke.points,
        })
    end
    return data
end

local function getCanvasPos(screenPos, canvas, clampOutside)
    local abs = canvas.AbsolutePosition
    local sz  = canvas.AbsoluteSize
    if sz.X <= 1 or sz.Y <= 1 then return nil, nil end
    local x   = screenPos.X - abs.X
    local y   = screenPos.Y - abs.Y
    if clampOutside then
        x = math.clamp(x, 0, sz.X)
        y = math.clamp(y, 0, sz.Y)
    else
        if x < 0 or y < 0 or x > sz.X or y > sz.Y then return nil, nil end
    end
    return x / sz.X * CANVAS_W, y / sz.Y * CANVAS_H
end

local lastX, lastY = nil, nil

local function beginStroke(x, y)
    if not drawState.active then return end
    if drawState.totalPoints >= MAX_TOTAL_POINTS then return end
    local canvas = drawState.canvas
    if not canvas then return end
    drawState.isDrawing     = true
    drawState.undoStack     = {}
    drawState.currentStroke = {
        color  = drawState.currentColor,
        size   = drawState.currentSize,
        points = {{x=x, y=y}},
    }
    drawState.totalPoints += 1
    local layer = ensureStrokeLayer(canvas)
    local px, py = toPx(canvas, x, y)
    drawDot(layer, px, py, drawState.currentColor, sizePx(canvas, drawState.currentSize))
    lastX, lastY = x, y
end

local function continueStroke(x, y)
    if not drawState.active or not drawState.isDrawing then return end
    if lastX then
        local dx, dy = x - lastX, y - lastY
        if dx * dx + dy * dy < MIN_POINT_GAP * MIN_POINT_GAP then
            return
        end
    end
    local stroke = drawState.currentStroke
    if stroke and #stroke.points >= MAX_STROKE_POINTS then
        return
    end
    if drawState.totalPoints >= MAX_TOTAL_POINTS then
        return
    end
    local canvas = drawState.canvas
    if canvas and lastX then
        local layer = ensureStrokeLayer(canvas)
        local x1, y1 = toPx(canvas, lastX, lastY)
        local x2, y2 = toPx(canvas, x, y)
        drawLine(layer, x1, y1, x2, y2, drawState.currentColor, sizePx(canvas, drawState.currentSize))
    end
    if stroke then
        table.insert(stroke.points, {x=x, y=y})
        drawState.totalPoints += 1
    end
    lastX, lastY = x, y
end

local function endStroke()
    if drawState.isDrawing and drawState.currentStroke then
        table.insert(drawState.strokes, drawState.currentStroke)
        drawState.currentStroke = nil
        drawState.isDrawing     = false
        lastX, lastY            = nil, nil
        drawState.activeTouchId = nil
    end
end

local function countStrokePoints(strokes)
    local n = 0
    for _, s in ipairs(strokes) do
        n += #(s.points or {})
    end
    return n
end

local function autoSubmitIfNeeded()
    if not drawState.active or drawState.submitted then return end
    if not drawState.canvas then return end
    drawState.submitted = true
    drawState.active = false
    endStroke()
    SubmitDrawing:FireServer(serializeStrokes(drawState.strokes))
    local df = drawState.canvas.Parent
    local submitBtn = df and df:FindFirstChild("SubmitButton")
    if submitBtn and submitBtn:IsA("TextButton") then
        submitBtn.BackgroundColor3 = Color3.fromRGB(80,130,80)
        submitBtn.Text = "Submitted!"
    end
end

local function setupCanvas()
    local sg = PlayerGui:WaitForChild(Config.MAIN_GUI_NAME, 10)
    if not sg then return end
    local df = sg:WaitForChild("DrawFrame", 10)
    if not df then return end
    local canvas    = df:WaitForChild("Canvas", 5)
    local toolPanel = df:WaitForChild("ToolPanel", 5)
    if not (canvas and toolPanel) then return end

    drawState.canvas = canvas
    ensureStrokeLayer(canvas)

    -- Ensure palette readable + big enough (Studio place may already be sized).
    toolPanel.Size = UDim2.new(0, math.max(toolPanel.Size.X.Offset, 150), 0, math.max(toolPanel.Size.Y.Offset, 560))
    local undoBtn = toolPanel:FindFirstChild("UndoBtn")
    if undoBtn and undoBtn:IsA("TextButton") then
        undoBtn.Text = "< Undo"
        undoBtn.TextSize = 16
        undoBtn.Font = Enum.Font.GothamBold
    end
    local redoBtn = toolPanel:FindFirstChild("RedoBtn")
    if redoBtn and redoBtn:IsA("TextButton") then
        redoBtn.Text = "Redo >"
        redoBtn.TextSize = 16
        redoBtn.Font = Enum.Font.GothamBold
    end
    local clearBtn = toolPanel:FindFirstChild("ClearBtn")
    if clearBtn and clearBtn:IsA("TextButton") then
        clearBtn.Text = "Clear"
        clearBtn.TextSize = 16
        clearBtn.Font = Enum.Font.GothamBold
    end

    for i = 1, #COLORS do
        local btn = toolPanel:FindFirstChild("ColorBtn_" .. i)
        if btn then
            btn.MouseButton1Click:Connect(function()
                drawState.currentColor = COLORS[i]
                for j = 1, #COLORS do
                    local b = toolPanel:FindFirstChild("ColorBtn_"..j)
                    if b then b.BorderSizePixel = 0 end
                end
                btn.BorderSizePixel = 3
            end)
        end
    end

    for i, sz in ipairs(SIZES) do
        local btn = toolPanel:FindFirstChild("SizeBtn"..i)
        if btn then
            btn.MouseButton1Click:Connect(function()
                drawState.currentSize = sz
                for j = 1, #SIZES do
                    local b = toolPanel:FindFirstChild("SizeBtn"..j)
                    if b then b.BackgroundColor3 = Color3.fromRGB(40,30,90) end
                end
                btn.BackgroundColor3 = Color3.fromRGB(180,130,255)
            end)
        end
    end

    if undoBtn then
        undoBtn.MouseButton1Click:Connect(function()
            if #drawState.strokes > 0 then
                local removed = table.remove(drawState.strokes)
                table.insert(drawState.undoStack, removed)
                drawState.totalPoints = countStrokePoints(drawState.strokes)
                renderStrokes(canvas, serializeStrokes(drawState.strokes))
            end
        end)
    end
    if redoBtn then
        redoBtn.MouseButton1Click:Connect(function()
            if #drawState.undoStack > 0 then
                local restored = table.remove(drawState.undoStack)
                table.insert(drawState.strokes, restored)
                drawState.totalPoints = countStrokePoints(drawState.strokes)
                renderStrokes(canvas, serializeStrokes(drawState.strokes))
            end
        end)
    end
    if clearBtn then
        clearBtn.MouseButton1Click:Connect(function()
            drawState.strokes     = {}
            drawState.undoStack   = {}
            drawState.totalPoints = 0
            clearCanvas(canvas)
        end)
    end

    local submitBtn = df:FindFirstChild("SubmitButton")
    if submitBtn then
        submitBtn.MouseButton1Click:Connect(function()
            if drawState.submitted then return end
            drawState.submitted = true
            drawState.active = false
            endStroke()
            SubmitDrawing:FireServer(serializeStrokes(drawState.strokes))
            submitBtn.BackgroundColor3 = Color3.fromRGB(80,130,80)
            submitBtn.Text = "Submitted!"
        end)
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not drawState.active then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local x, y = getCanvasPos(input.Position, canvas, false)
        if not x then return end
        beginStroke(x, y)
    end)

    UserInputService.InputChanged:Connect(function(input, processed)
        if not drawState.active or not drawState.isDrawing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local x, y = getCanvasPos(input.Position, canvas, true)
        if not x then return end
        continueStroke(x, y)
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            endStroke()
        end
    end)

    -- Only the first finger draws; extra touches are ignored.
    UserInputService.TouchStarted:Connect(function(input, processed)
        if processed or not drawState.active then return end
        if drawState.activeTouchId ~= nil then return end
        local x, y = getCanvasPos(input.Position, canvas, false)
        if not x then return end
        drawState.activeTouchId = input
        beginStroke(x, y)
    end)

    UserInputService.TouchMoved:Connect(function(input, processed)
        if not drawState.active or not drawState.isDrawing then return end
        if input ~= drawState.activeTouchId then return end
        local x, y = getCanvasPos(input.Position, canvas, true)
        if not x then return end
        continueStroke(x, y)
    end)

    UserInputService.TouchEnded:Connect(function(input)
        if input ~= drawState.activeTouchId then return end
        endStroke()
    end)

    print("[DrawingClient] Canvas ready (mouse + touch)")
end

DrawActiveEvent.Event:Connect(function(active)
    drawState.active        = active
    drawState.strokes       = {}
    drawState.undoStack     = {}
    drawState.submitted     = false
    drawState.activeTouchId = nil
    drawState.totalPoints   = 0
    if drawState.canvas then
        ensureStrokeLayer(drawState.canvas)
        clearCanvas(drawState.canvas)
    end
end)

RenderStrokesEvent.Event:Connect(function(canvas, strokeData)
    task.spawn(function()
        for _ = 1, 12 do
            if canvas.AbsoluteSize.X > 4 and canvas.AbsoluteSize.Y > 4 then break end
            task.wait(0.05)
        end
        renderStrokes(canvas, strokeData, canvas.AbsoluteSize.X, canvas.AbsoluteSize.Y)
    end)
end)

SyncTimer.OnClientEvent:Connect(function(remaining, _total)
    if remaining == 0 then
        autoSubmitIfNeeded()
    end
end)

task.delay(1.5, setupCanvas)
print("[DrawingClient] Ready")
