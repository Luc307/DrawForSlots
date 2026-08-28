local AssetService      = game:GetService("AssetService")
local GuiService        = game:GetService("GuiService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
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
local MIN_POINT_GAP = 3
local MAX_STROKE_POINTS = 400
local MAX_TOTAL_POINTS = Config.MAX_DRAW_POINTS or 50000

local drawState = {
    active        = false,
    isDrawing     = false,
    tool          = "brush",
    currentColor  = Color3.fromRGB(0, 0, 0),
    currentSize   = 4,
    strokes       = {},
    currentStroke = nil,
    undoStack     = {},
    canvas        = nil,
    toolPanel     = nil,
    submitted     = false,
    activeTouchId = nil,
    totalPoints   = 0,
    fillLock      = false,
}

local COLORS = {
    Color3.fromRGB(0,0,0),     Color3.fromRGB(255,255,255),
    Color3.fromRGB(220,50,50), Color3.fromRGB(255,140,0),
    Color3.fromRGB(50,200,50), Color3.fromRGB(50,100,255),
    Color3.fromRGB(160,50,255),Color3.fromRGB(0,220,200),
    Color3.fromRGB(255,80,180),Color3.fromRGB(255,200,220),
}
local SIZES = Config.BRUSH_SIZES

local paints = {}

local function rgb255(c)
    return math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
end

local function bufIndex(x, y)
    return ((y * CANVAS_W + x) * 4)
end

local function setPx(buf, x, y, r, g, b)
    if x < 0 or y < 0 or x >= CANVAS_W or y >= CANVAS_H then return end
    local i = bufIndex(x, y)
    buffer.writeu8(buf, i, r)
    buffer.writeu8(buf, i + 1, g)
    buffer.writeu8(buf, i + 2, b)
    buffer.writeu8(buf, i + 3, 255)
end

local function getPx(buf, x, y)
    local i = bufIndex(x, y)
    return buffer.readu8(buf, i), buffer.readu8(buf, i + 1), buffer.readu8(buf, i + 2)
end

local function samePx(r1, g1, b1, r2, g2, b2)
    return r1 == r2 and g1 == g2 and b1 == b2
end

local function fillWhite(buf)
    local n = CANVAS_W * CANVAS_H * 4
    local i = 0
    while i < n do
        buffer.writeu8(buf, i, 255)
        buffer.writeu8(buf, i + 1, 255)
        buffer.writeu8(buf, i + 2, 255)
        buffer.writeu8(buf, i + 3, 255)
        i += 4
    end
end

local function stampCircle(buf, cx, cy, radius, r, g, b)
    local rad = math.max(1, math.floor(radius + 0.5))
    local r2 = rad * rad
    local x0 = math.max(0, math.floor(cx - rad))
    local y0 = math.max(0, math.floor(cy - rad))
    local x1 = math.min(CANVAS_W - 1, math.ceil(cx + rad))
    local y1 = math.min(CANVAS_H - 1, math.ceil(cy + rad))
    for y = y0, y1 do
        local dy = y - cy
        for x = x0, x1 do
            local dx = x - cx
            if dx * dx + dy * dy <= r2 then
                setPx(buf, x, y, r, g, b)
            end
        end
    end
end

local function stampLine(buf, x1, y1, x2, y2, radius, r, g, b)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = math.max(1, radius * 0.45)
    if dist < step then
        stampCircle(buf, x2, y2, radius, r, g, b)
        return
    end
    local n = math.ceil(dist / step)
    for i = 1, n do
        local t = i / n
        stampCircle(buf, x1 + dx * t, y1 + dy * t, radius, r, g, b)
    end
end

local function colorDist2(r1, g1, b1, r2, g2, b2)
    local dr, dg, db = r1 - r2, g1 - g2, b1 - b2
    return dr * dr + dg * dg + db * db
end

-- Scanline bucket. Tolerance so anti-aliased / near-white pixels still fill.
local FILL_TOL2 = 22 * 22
local function floodFill(buf, sx, sy, r, g, b)
    sx = math.clamp(math.floor(sx + 0.5), 0, CANVAS_W - 1)
    sy = math.clamp(math.floor(sy + 0.5), 0, CANVAS_H - 1)
    local tr, tg, tb = getPx(buf, sx, sy)
    if colorDist2(tr, tg, tb, r, g, b) <= FILL_TOL2 then return false end

    local function matches(x, y)
        if x < 0 or y < 0 or x >= CANVAS_W or y >= CANVAS_H then return false end
        local cr, cg, cb = getPx(buf, x, y)
        return colorDist2(cr, cg, cb, tr, tg, tb) <= FILL_TOL2
    end

    local stack = {sx, sy}
    local visited = buffer.create(CANVAS_W * CANVAS_H)
    local function marked(x, y)
        return buffer.readu8(visited, y * CANVAS_W + x) == 1
    end
    local function mark(x, y)
        buffer.writeu8(visited, y * CANVAS_W + x, 1)
    end

    while #stack >= 2 do
        local y = table.remove(stack)
        local x = table.remove(stack)
        if marked(x, y) or not matches(x, y) then continue end
        local xL = x
        while xL > 0 and matches(xL - 1, y) do
            xL -= 1
        end
        local xR = x
        while xR < CANVAS_W - 1 and matches(xR + 1, y) do
            xR += 1
        end
        for i = xL, xR do
            setPx(buf, i, y, r, g, b)
            mark(i, y)
            if y > 0 and matches(i, y - 1) and not marked(i, y - 1) then
                table.insert(stack, i)
                table.insert(stack, y - 1)
            end
            if y < CANVAS_H - 1 and matches(i, y + 1) and not marked(i, y + 1) then
                table.insert(stack, i)
                table.insert(stack, y + 1)
            end
        end
    end
    return true
end

local function flushPaint(paint)
    if not paint or not paint.ei or not paint.buf then return end
    pcall(function()
        paint.ei:WritePixelsBuffer(Vector2.zero, Vector2.new(CANVAS_W, CANVAS_H), paint.buf)
    end)
end

local function destroyPaint(canvas)
    local paint = paints[canvas]
    if not paint then return end
    if paint.ei then
        pcall(function() paint.ei:Destroy() end)
    end
    if paint.img and paint.img.Parent then
        paint.img:Destroy()
    end
    paints[canvas] = nil
end

local function ensurePaint(canvas)
    if not canvas then return nil end
    local paint = paints[canvas]
    if paint and paint.img and paint.img.Parent == canvas and paint.ei then
        return paint
    end
    destroyPaint(canvas)

    local img = Instance.new("ImageLabel")
    img.Name = "PaintImage"
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Size = UDim2.fromScale(1, 1)
    img.Position = UDim2.fromScale(0, 0)
    img.ZIndex = 2
    img.Active = false
    img.Interactable = false
    img.ScaleType = Enum.ScaleType.Stretch
    img.Parent = canvas
    canvas.ClipsDescendants = true

    local ei = nil
    local ok, result = pcall(function()
        return AssetService:CreateEditableImage({ Size = Vector2.new(CANVAS_W, CANVAS_H) })
    end)
    if ok then ei = result end
    if not ei then
        return nil
    end

    local buf = buffer.create(CANVAS_W * CANVAS_H * 4)
    fillWhite(buf)
    pcall(function()
        img.ImageContent = Content.fromObject(ei)
    end)

    paint = { img = img, ei = ei, buf = buf, dirty = true }
    paints[canvas] = paint
    flushPaint(paint)
    return paint
end

local function rasterize(canvas, strokes)
    local paint = ensurePaint(canvas)
    if not paint then return end
    fillWhite(paint.buf)
    if strokes then
        for _, stroke in ipairs(strokes) do
            local r = stroke.r or 0
            local g = stroke.g or 0
            local b = stroke.b or 0
            if typeof(stroke.color) == "Color3" then
                r, g, b = rgb255(stroke.color)
            end
            local pts = stroke.points
            if stroke.kind == "fill" and pts and pts[1] then
                floodFill(paint.buf, pts[1].x, pts[1].y, r, g, b)
            elseif pts and #pts > 0 then
                local radius = math.max(1, (stroke.size or 4) * 0.5)
                stampCircle(paint.buf, pts[1].x, pts[1].y, radius, r, g, b)
                for i = 2, #pts do
                    stampLine(paint.buf, pts[i - 1].x, pts[i - 1].y, pts[i].x, pts[i].y, radius, r, g, b)
                end
            end
        end
    end
    flushPaint(paint)
end

local function clearCanvas(canvas)
    if not canvas then return end
    local layer = canvas:FindFirstChild("StrokeLayer")
    if layer then layer:Destroy() end
    for _, c in ipairs(canvas:GetChildren()) do
        if c.Name == "Dot" or c.Name == "Seg" then c:Destroy() end
    end
    rasterize(canvas, {})
end

local function serializeStrokes(strokes)
    local data = {}
    for _, stroke in ipairs(strokes) do
        local r, g, b = rgb255(stroke.color)
        table.insert(data, {
            kind   = stroke.kind,
            r      = r,
            g      = g,
            b      = b,
            size   = stroke.size,
            points = stroke.points,
        })
    end
    return data
end

local function overGui(gui, screenPos)
    if not gui then return false end
    local a = gui.AbsolutePosition
    local s = gui.AbsoluteSize
    return screenPos.X >= a.X and screenPos.X <= a.X + s.X
        and screenPos.Y >= a.Y and screenPos.Y <= a.Y + s.Y
end

local function getCanvasPos(screenPos, canvas, clampOutside)
    local abs = canvas.AbsolutePosition
    local sz  = canvas.AbsoluteSize
    if sz.X <= 1 or sz.Y <= 1 then return nil, nil end
    local x   = screenPos.X - abs.X
    local y   = screenPos.Y - abs.Y
    if clampOutside then
        if not drawState.isDrawing then
            if x < 0 or y < 0 or x > sz.X or y > sz.Y then return nil, nil end
        else
            x = math.clamp(x, 0, sz.X)
            y = math.clamp(y, 0, sz.Y)
        end
    else
        if x < 0 or y < 0 or x > sz.X or y > sz.Y then return nil, nil end
    end
    return x / sz.X * CANVAS_W, y / sz.Y * CANVAS_H
end

local lastX, lastY = nil, nil
local endStroke
local commitStroke

commitStroke = function()
    if drawState.isDrawing and drawState.currentStroke then
        table.insert(drawState.strokes, drawState.currentStroke)
    end
    drawState.currentStroke = nil
    drawState.isDrawing     = false
    lastX, lastY            = nil, nil
end

local function setTool(tool)
    drawState.tool = tool
    local panel = drawState.toolPanel
    if not panel then return end
    local fillBtn = panel:FindFirstChild("FillBtn")
    if fillBtn and fillBtn:IsA("GuiObject") then
        fillBtn.BackgroundColor3 = tool == "fill"
            and Color3.fromRGB(180, 130, 255)
            or Color3.fromRGB(40, 30, 90)
    end
    if tool == "fill" then
        for j = 1, #SIZES do
            local b = panel:FindFirstChild("SizeBtn"..j)
            if b then b.BackgroundColor3 = Color3.fromRGB(40, 30, 90) end
        end
    end
end

local function applyFill(x, y)
    if drawState.fillLock then return end
    local canvas = drawState.canvas
    if not canvas then return end
    local paint = ensurePaint(canvas)
    if not paint then return end
    commitStroke()
    drawState.fillLock = true
    local r, g, b = rgb255(drawState.currentColor)
    local ok = floodFill(paint.buf, x, y, r, g, b)
    flushPaint(paint)
    paint.dirty = false
    if ok then
        table.insert(drawState.strokes, {
            kind   = "fill",
            color  = drawState.currentColor,
            size   = drawState.currentSize,
            points = {{x = x, y = y}},
        })
        drawState.undoStack = {}
    end
    setTool("brush")
    task.delay(0.12, function()
        drawState.fillLock = false
    end)
end

local function beginStroke(x, y)
    if not drawState.active then return end
    if drawState.isDrawing then return end
    if drawState.tool == "fill" then
        applyFill(x, y)
        return
    end
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
    local paint = ensurePaint(canvas)
    if paint then
        local r, g, b = rgb255(drawState.currentColor)
        stampCircle(paint.buf, x, y, math.max(1, drawState.currentSize * 0.5), r, g, b)
        paint.dirty = true
    end
    lastX, lastY = x, y
end

local function continueStroke(x, y)
    if not drawState.active or not drawState.isDrawing then return end
    if drawState.tool == "fill" then return end
    local stroke = drawState.currentStroke
    if stroke and #stroke.points >= MAX_STROKE_POINTS then
        endStroke()
        if drawState.totalPoints >= MAX_TOTAL_POINTS then return end
        beginStroke(x, y)
        return
    end
    if drawState.totalPoints >= MAX_TOTAL_POINTS then
        endStroke()
        return
    end
    if lastX then
        local dx, dy = x - lastX, y - lastY
        if dx * dx + dy * dy < MIN_POINT_GAP * MIN_POINT_GAP then
            return
        end
    end
    local canvas = drawState.canvas
    if canvas and lastX then
        local paint = ensurePaint(canvas)
        if paint then
            local r, g, b = rgb255(drawState.currentColor)
            stampLine(paint.buf, lastX, lastY, x, y, math.max(1, drawState.currentSize * 0.5), r, g, b)
            paint.dirty = true
        end
    end
    if stroke then
        table.insert(stroke.points, {x=x, y=y})
        drawState.totalPoints += 1
    end
    lastX, lastY = x, y
end

endStroke = function()
    commitStroke()
    drawState.activeTouchId = nil
    local paint = drawState.canvas and paints[drawState.canvas]
    if paint and paint.dirty then
        flushPaint(paint)
        paint.dirty = false
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
    drawState.toolPanel = toolPanel
    canvas.Active = false
    canvas.Interactable = false
    ensurePaint(canvas)

    local largeBtn = toolPanel:FindFirstChild("SizeBtn"..#SIZES)
    local fillBtn = toolPanel:FindFirstChild("FillBtn")
    local SHIFT = 0
    if largeBtn then
        local gap = 8
        local h = largeBtn.Size.Y.Offset
        if h < 8 then h = largeBtn.AbsoluteSize.Y end
        if h < 8 then h = 36 end
        SHIFT = h + gap
        if fillBtn then fillBtn:Destroy() end
        fillBtn = largeBtn:Clone()
        fillBtn.Name = "FillBtn"
        fillBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 90)
        fillBtn.Position = UDim2.new(
            largeBtn.Position.X.Scale, largeBtn.Position.X.Offset,
            largeBtn.Position.Y.Scale, largeBtn.Position.Y.Offset + SHIFT
        )
        fillBtn.Parent = toolPanel
        if fillBtn:IsA("TextButton") then
            fillBtn.Text = "Fill"
        else
            local cap = fillBtn:FindFirstChild("FillCaption")
            if not cap then
                cap = Instance.new("TextLabel")
                cap.Name = "FillCaption"
                cap.BackgroundTransparency = 1
                cap.Size = UDim2.fromScale(1, 1)
                cap.Font = Enum.Font.GothamBold
                cap.TextSize = 14
                cap.TextColor3 = Color3.fromRGB(255, 255, 255)
                cap.ZIndex = fillBtn.ZIndex + 1
                cap.Parent = fillBtn
            end
            cap.Text = "Fill"
        end
        local cutY = largeBtn.Position.Y.Offset + largeBtn.Size.Y.Offset
        for _, ch in ipairs(toolPanel:GetChildren()) do
            if ch:IsA("GuiObject") and ch ~= fillBtn and not string.match(ch.Name, "^SizeBtn") then
                if ch.Position.Y.Offset >= cutY - 1 then
                    ch.Position = ch.Position + UDim2.fromOffset(0, SHIFT)
                end
            end
        end
    elseif not fillBtn then
        fillBtn = Instance.new("TextButton")
        fillBtn.Name = "FillBtn"
        fillBtn.Size = UDim2.new(1, -12, 0, 36)
        fillBtn.Position = UDim2.new(0, 6, 1, -44)
        fillBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 90)
        fillBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        fillBtn.Font = Enum.Font.GothamBold
        fillBtn.TextSize = 16
        fillBtn.Text = "Fill"
        fillBtn.ZIndex = 5
        fillBtn.Parent = toolPanel
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = fillBtn
    end

    if toolPanel:IsA("ScrollingFrame") then
        local maxB = 0
        for _, ch in ipairs(toolPanel:GetChildren()) do
            if ch:IsA("GuiObject") then
                maxB = math.max(maxB, ch.Position.Y.Offset + ch.Size.Y.Offset)
            end
        end
        toolPanel.ScrollingEnabled = true
        toolPanel.AutomaticCanvasSize = Enum.AutomaticSize.None
        toolPanel.CanvasSize = UDim2.new(0, 0, 0, maxB + 24)
        toolPanel.ScrollBarThickness = 8
        toolPanel.VerticalScrollBarInset = Enum.ScrollBarInset.None
    end
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

    fillBtn = toolPanel:FindFirstChild("FillBtn")
    if fillBtn then
        fillBtn.MouseButton1Click:Connect(function()
            setTool(drawState.tool == "fill" and "brush" or "fill")
        end)
    end

    for i = 1, #COLORS do
        local btn = toolPanel:FindFirstChild("ColorBtn_" .. i)
        if btn then
            btn.MouseButton1Click:Connect(function()
                drawState.currentColor = COLORS[i]
                setTool("brush")
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
                setTool("brush")
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
                rasterize(canvas, serializeStrokes(drawState.strokes))
            end
        end)
    end
    if redoBtn then
        redoBtn.MouseButton1Click:Connect(function()
            if #drawState.undoStack > 0 then
                local restored = table.remove(drawState.undoStack)
                table.insert(drawState.strokes, restored)
                drawState.totalPoints = countStrokePoints(drawState.strokes)
                rasterize(canvas, serializeStrokes(drawState.strokes))
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

    UserInputService.InputBegan:Connect(function(input, _processed)
        if not drawState.active then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if drawState.activeTouchId then return end
        if overGui(toolPanel, input.Position) then return end
        local x, y = getCanvasPos(input.Position, canvas, false)
        if not x then return end
        beginStroke(x, y)
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if drawState.activeTouchId then return end
        endStroke()
    end)

    RunService.RenderStepped:Connect(function()
        if not drawState.active then return end
        local paint = paints[canvas]
        if paint and paint.dirty then
            flushPaint(paint)
            paint.dirty = false
        end
        if drawState.activeTouchId then return end
        if not drawState.isDrawing then return end
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end
        local inset = GuiService:GetGuiInset()
        local mouse = UserInputService:GetMouseLocation() - inset
        local x, y = getCanvasPos(mouse, canvas, true)
        if not x then return end
        continueStroke(x, y)
    end)

    UserInputService.TouchStarted:Connect(function(input, _processed)
        if not drawState.active then return end
        if drawState.activeTouchId ~= nil then return end
        if overGui(toolPanel, input.Position) then return end
        local x, y = getCanvasPos(input.Position, canvas, false)
        if not x then return end
        drawState.activeTouchId = input
        beginStroke(x, y)
        local paint = paints[canvas]
        if paint and paint.dirty then
            flushPaint(paint)
            paint.dirty = false
        end
    end)

    UserInputService.TouchMoved:Connect(function(input, _processed)
        if not drawState.active then return end
        if input ~= drawState.activeTouchId then return end
        if not drawState.isDrawing then return end
        local x, y = getCanvasPos(input.Position, canvas, true)
        if not x then return end
        continueStroke(x, y)
        local paint = paints[canvas]
        if paint and paint.dirty then
            flushPaint(paint)
            paint.dirty = false
        end
    end)

    UserInputService.TouchEnded:Connect(function(input)
        if input ~= drawState.activeTouchId then return end
        endStroke()
    end)

    print("[DrawingClient] Canvas ready (paint + fill)")
end

DrawActiveEvent.Event:Connect(function(active)
    drawState.active        = active
    drawState.strokes       = {}
    drawState.undoStack     = {}
    drawState.submitted     = false
    drawState.activeTouchId = nil
    drawState.totalPoints   = 0
    drawState.fillLock      = false
    drawState.tool          = "brush"
    setTool("brush")
    if drawState.canvas then
        clearCanvas(drawState.canvas)
    end
end)

RenderStrokesEvent.Event:Connect(function(canvas, strokeData)
    task.spawn(function()
        for _ = 1, 16 do
            if canvas.AbsoluteSize.X > 4 and canvas.AbsoluteSize.Y > 4 then break end
            task.wait(0.05)
        end
        rasterize(canvas, strokeData)
    end)
end)

SyncTimer.OnClientEvent:Connect(function(remaining, _total)
    if remaining == 0 then
        autoSubmitIfNeeded()
    end
end)

task.delay(1.5, setupCanvas)
print("[DrawingClient] Ready")
