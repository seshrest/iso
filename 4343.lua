local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ws         = game:GetService("Workspace")
local lp         = Players.LocalPlayer or Players.PlayerAdded:Wait()

local VK_V      = 0x56
local enabled   = false
local smooth    = 0.5
local hitWindow = 20
local showDot   = true

local dot, dotOutline, statusBg, statusText

local function getMapData()
    return lp:FindFirstChild("MapData")
end

local function keyIsDown()
    if type(iskeypressed) == "function" then
        local ok, result = pcall(iskeypressed, VK_V)
        if ok then return result == true end
    end
    return UserInputService:IsKeyDown(Enum.KeyCode.V)
end

local function projectToScreen(position)
    if type(WorldToScreen) == "function" then
        local screen, visible = WorldToScreen(position)
        return screen, visible ~= false
    end

    local camera = ws.CurrentCamera
    if not camera then return nil, false end
    local point, visible = camera:WorldToViewportPoint(position)
    return Vector2.new(point.X, point.Y), visible
end

local function initDrawings()
    if dot then return end

    dot = Drawing.new("Circle")
    dot.Filled=true; dot.Radius=10
    dot.Color=Color3.fromRGB(0,255,100)
    dot.NumSides=32; dot.Visible=false

    dotOutline = Drawing.new("Circle")
    dotOutline.Filled=false; dotOutline.Radius=13; dotOutline.Thickness=2
    dotOutline.Color=Color3.fromRGB(0,0,0)
    dotOutline.NumSides=32; dotOutline.Visible=false

    statusBg = Drawing.new("Square")
    statusBg.Filled=true; statusBg.Color=Color3.fromRGB(0,0,0)
    statusBg.Transparency=0.5; statusBg.Visible=true

    statusText = Drawing.new("Text")
    statusText.Size=14; statusText.Center=true; statusText.Outline=true
    statusText.Font=Drawing.Fonts.SystemBold or Drawing.Fonts.System or 1
    statusText.Color=Color3.fromRGB(255,60,60)
    statusText.Text="AutoPlay OFF"
    statusText.Visible=true
end

local function updateStatus()
    if not statusText then return end
    local vp = ws.CurrentCamera.ViewportSize
    local text = "AutoPlay " .. (enabled and "ON" or "OFF")
    statusText.Text = text
    statusText.Color = enabled and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,60,60)
    local bounds = statusText.TextBounds
    local w = (bounds and bounds.X or 80) + 20
    local x = vp.X / 2
    local y = vp.Y - 40
    statusText.Position = Vector2.new(x, y - 4)
    statusBg.Position   = Vector2.new(x - w/2, y - 6)
    statusBg.Size       = Vector2.new(w, 22)
end

local function getGF()
    local c=ws:FindFirstChild("Client"); return c and c:FindFirstChild("Game")
end
local function getCursor(gf)
    for _,c in ipairs(gf:GetChildren()) do
        if c.ClassName=="Part" and c.Name=="Cursor" then return c end
    end
end
local function getBestNote(gf)
    local best,bestDist=nil,math.huge
    for _,c in ipairs(gf:GetChildren()) do
        if c.ClassName=="Part" and #c.Name==0 then
            local ok,pos=pcall(function() return c.Position end)
            if ok and pos then
                local d=math.abs(pos.X)
                if d<hitWindow and d<bestDist then bestDist=d;best=pos end
            end
        end
    end
    return best
end

local kbWasDown = false

RunService.RenderStepped:Connect(function()
    initDrawings()
    updateStatus()

    local vDown = keyIsDown()
    if vDown and not kbWasDown then
        enabled = not enabled
        pcall(function()
            if UI and type(UI.SetValue) == "function" then
                UI.SetValue("auto_on", enabled)
            end
        end)
        if not enabled then dot.Visible=false; dotOutline.Visible=false end
        updateStatus()
    end
    kbWasDown = vDown

    if not enabled then dot.Visible=false; dotOutline.Visible=false; return end
    local mapData = getMapData()
    local playing = mapData and mapData:FindFirstChild("Playing")
    if not playing or not playing.Value then dot.Visible=false; dotOutline.Visible=false; return end
    local gf = getGF()
    if not gf then dot.Visible=false; dotOutline.Visible=false; return end
    local cursor  = getCursor(gf)
    local notePos = getBestNote(gf)
    if not cursor or not notePos then dot.Visible=false; dotOutline.Visible=false; return end

    local ok1,curScreen, curOn = pcall(projectToScreen, cursor.Position)
    local ok2,noteScreen, on   = pcall(projectToScreen, Vector3.new(0,notePos.Y,notePos.Z))
    if not ok1 or not ok2 or not curScreen or not noteScreen or not curOn or not on then
        dot.Visible=false; dotOutline.Visible=false; return
    end

    if showDot then
        dot.Position=Vector2.new(noteScreen.X,noteScreen.Y); dot.Visible=true
        dotOutline.Position=Vector2.new(noteScreen.X,noteScreen.Y); dotOutline.Visible=true
    else
        dot.Visible=false; dotOutline.Visible=false
    end

    local dx=(noteScreen.X-curScreen.X)*smooth
    local dy=(noteScreen.Y-curScreen.Y)*smooth
    if math.abs(dx)<0.5 and math.abs(dy)<0.5 then return end
    local outX=dx>=0 and math.floor(dx+0.25) or math.ceil(dx-0.25)
    local outY=dy>=0 and math.floor(dy+0.25) or math.ceil(dy-0.25)
    if (outX~=0 or outY~=0) and type(mousemoverel) == "function" then
        pcall(mousemoverel, outX, outY)
    end
end)

UI.AddTab("SoundSpace", function(tab)
    local sec = tab:Section("AutoPlay", "Left")

    sec:Toggle("auto_on", "Enable AutoPlay", false, function(v)
        enabled = v == true
        if not enabled and dot then dot.Visible=false; dotOutline.Visible=false end
        updateStatus()
    end)

    local kb = sec:Keybind("auto_key", 0x56, "toggle")
    pcall(function() kb:AddToHotkey("AutoPlay", "auto_on") end)

    sec:SliderFloat("auto_smooth", "Speed", 0.05, 1.0, smooth, "%.2f", function(v)
        smooth = tonumber(v) or smooth
    end)

    sec:SliderInt("auto_window", "Hit Window", 2, 40, hitWindow, function(v)
        hitWindow = tonumber(v) or hitWindow
    end)

    sec:Toggle("auto_vis", "Show Target Dot", true, function(v)
        showDot = v == true
        if not showDot and dot then dot.Visible=false; dotOutline.Visible=false end
    end)
end)
