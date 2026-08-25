local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local Config        = require(ReplicatedStorage:WaitForChild("GameConfig"))
local SubmitDrawing = Remotes:WaitForChild("SubmitDrawing")

local Signals = ReplicatedStorage:WaitForChild("Signals")
local DrawActiveEvent = Signals:WaitForChild("DrawActiveEvent")
local RenderStrokesEvent = Signals:WaitForChild("RenderStrokesEvent")

local CANVAS_W = 540
local CANVAS_H = 410

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
}

local COLORS = {
    Color3.fromRGB(0,0,0),     Color3.fromRGB(255,255,255),
    Color3.fromRGB(220,50,50), Color3.fromRGB(255,140,0),
    Color3.fromRGB(50,200,50), Color3.fromRGB(50,100,255),
    Color3.fromRGB(160,50,255),Color3.fromRGB(0,220,200),
    Color3.fromRGB(255,80,180),Color3.fromRGB(255,200,220),
}
local SIZES = {4, 8, 16}

local function drawDot(canvas, x, y, color, radius)
    local dot = Instance.new("Frame")
    dot.Name             = "Dot"
    dot.BackgroundColor3 = color
    dot.BorderSizePixel  = 0
    dot.Size             = UDim2.new(0, radius*2, 0, radius*2)
    dot.Position         = UDim2.new(0, x-radius, 0, y-radius)
    dot.ZIndex           = 2
    dot.Parent           = canvas
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = dot
end

local function drawLine(canvas, x1, y1, x2, y2, color, radius)
    local dx, dy = x2-x1, y2-y1
    local dist   = math.sqrt(dx*dx + dy*dy)
    local steps  = math.max(1, math.floor(dist / math.max(radius*0.5, 1)))
    for i = 0, steps do
        local t = i/steps
        drawDot(canvas, x1+dx*t, y1+dy*t, color, radius)
    end
end

local function clearCanvas(canvas)
    for _, c in ipairs(canvas:GetChildren()) do
        if c.Name == "Dot" then c:Destroy() end
    end
end

local function renderStrokes(canvas, strokes, targetW, targetH)
    if not canvas or not strokes then return end
    clearCanvas(canvas)
    local scaleX, scaleY = 1, 1
    if targetW and targetW > 0 and targetH and targetH > 0 then
        local scale = math.min(targetW / CANVAS_W, targetH / CANVAS_H)
        scaleX = scale ; scaleY = scale
    end
    for _, stroke in ipairs(strokes) do
        local ok, color = pcall(function()
            return Color3.fromRGB(stroke.r or 0, stroke.g or 0, stroke.b or 0)
        end)
        if not ok then color = Color3.fromRGB(0,0,0) end
        local radius = math.max(1, math.floor((stroke.size or 4) * scaleX))
        local points = stroke.points
        if not points or #points == 0 then continue end
        drawDot(canvas, points[1].x*scaleX, points[1].y*scaleY, color, radius)
        for i = 2, #points do
            drawLine(canvas,
                points[i-1].x*scaleX, points[i-1].y*scaleY,
                points[i].x*scaleX,   points[i].y*scaleY,
                color, radius)
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

local function getCanvasPos(screenPos, canvas)
    local abs = canvas.AbsolutePosition
    local sz  = canvas.AbsoluteSize
    local x   = screenPos.X - abs.X
    local y   = screenPos.Y - abs.Y
    if x < 0 or y < 0 or x > sz.X or y > sz.Y then return nil, nil end
    return x, y
end

local lastX, lastY = nil, nil

local function beginStroke(x, y)
    if not drawState.active then return end
    drawState.isDrawing     = true
    drawState.undoStack     = {}
    drawState.currentStroke = {
        color  = drawState.currentColor,
        size   = drawState.currentSize,
        points = {{x=x, y=y}},
    }
    drawDot(drawState.canvas, x, y, drawState.currentColor, drawState.currentSize)
    lastX, lastY = x, y
end

local function continueStroke(x, y)
    if not drawState.active or not drawState.isDrawing then return end
    if lastX then
        drawLine(drawState.canvas, lastX, lastY, x, y,
                 drawState.currentColor, drawState.currentSize)
    end
    if drawState.currentStroke then
        table.insert(drawState.currentStroke.points, {x=x, y=y})
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

local function setupCanvas()
    local sg = PlayerGui:WaitForChild(Config.MAIN_GUI_NAME, 10)
    if not sg then return end
    local df = sg:WaitForChild("DrawFrame", 10)
    if not df then return end
    local canvas    = df:WaitForChild("Canvas", 5)
    local toolPanel = df:WaitForChild("ToolPanel", 5)
    if not (canvas and toolPanel) then return end

    drawState.canvas = canvas

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

    local undoBtn = toolPanel:FindFirstChild("UndoBtn")
    if undoBtn then
        undoBtn.MouseButton1Click:Connect(function()
            if #drawState.strokes > 0 then
                table.insert(drawState.undoStack, table.remove(drawState.strokes))
                renderStrokes(canvas, serializeStrokes(drawState.strokes))
            end
        end)
    end
    local redoBtn = toolPanel:FindFirstChild("RedoBtn")
    if redoBtn then
        redoBtn.MouseButton1Click:Connect(function()
            if #drawState.undoStack > 0 then
                table.insert(drawState.strokes, table.remove(drawState.undoStack))
                renderStrokes(canvas, serializeStrokes(drawState.strokes))
            end
        end)
    end
    local clearBtn = toolPanel:FindFirstChild("ClearBtn")
    if clearBtn then
        clearBtn.MouseButton1Click:Connect(function()
            drawState.strokes   = {}
            drawState.undoStack = {}
            clearCanvas(canvas)
        end)
    end

    local submitBtn = df:FindFirstChild("SubmitButton")
    if submitBtn then
        submitBtn.MouseButton1Click:Connect(function()
            if drawState.submitted then return end
            drawState.submitted = true
            SubmitDrawing:FireServer(serializeStrokes(drawState.strokes))
            submitBtn.BackgroundColor3 = Color3.fromRGB(80,130,80)
            submitBtn.Text = "Submitted!"
        end)
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not drawState.active then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local x, y = getCanvasPos(input.Position, canvas)
        if not x then return end
        beginStroke(x, y)
    end)

    UserInputService.InputChanged:Connect(function(input, processed)
        if not drawState.active or not drawState.isDrawing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local x, y = getCanvasPos(input.Position, canvas)
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
        local x, y = getCanvasPos(input.Position, canvas)
        if not x then return end
        drawState.activeTouchId = input
        beginStroke(x, y)
    end)

    UserInputService.TouchMoved:Connect(function(input, processed)
        if not drawState.active or not drawState.isDrawing then return end
        if input ~= drawState.activeTouchId then return end
        local x, y = getCanvasPos(input.Position, canvas)
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
    if drawState.canvas then clearCanvas(drawState.canvas) end
end)

RenderStrokesEvent.Event:Connect(function(canvas, strokeData)
    task.spawn(function()
        task.wait(0.05)
        local tw = canvas.AbsoluteSize.X
        local th = canvas.AbsoluteSize.Y
        if tw <= 0 then tw = canvas.Size.X.Offset end
        if th <= 0 then th = canvas.Size.Y.Offset end
        renderStrokes(canvas, strokeData, tw, th)
    end)
end)

task.delay(1.5, setupCanvas)
print("[DrawingClient] Ready")
