local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local cfg = {
    enabled     = false,
    visualizer  = false,
    outline     = false,
    healthColor = false,
    hitboxSize  = 5.0,
    maxDistance = 500.0,
    partIndex   = 1,
    folderName  = "",
}

local PARTS = {"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg"}

local HBX = {
    originalSizes = {},
    expandedParts = {},
    cachedModels  = {},
    cacheTime     = 0,
    partTypeCache = {},
    cleanupTime   = 0,
    updateTime    = 0,
    wasEnabled    = false,
}

local PX, PY   = 20, 80
local PW       = 254
local PANEL_H  = 268

local guiVisible  = true
local drag        = {active=false, ox=0, oy=0}
local sliderDrag  = {active=false, which=nil}
local inputActive = false
local prevKeys    = {}
local keyRepeat   = {}
local cursorBlink = 0

local CP_H, CP_S, CP_V = 0.682, 0.534, 0.824
local visColor = Color3.fromRGB(108, 98, 210)
local CP_OPEN  = false
local CP_DRAG  = nil

local CP_PW    = 220
local CP_PH    = 182
local CP_R_OUT = 70
local CP_R_IN  = 50
local CP_R_MID = 60
local SV_COLS  = 8
local SV_CELL  = 8
local SV_SIZE  = SV_COLS * SV_CELL

local notif      = {alpha=0, timer=0, phase="idle"}
local notifShown = false

local function hsvToRgb(h, s, v)
    local i = math.floor(h*6) % 6
    local f = h*6 - math.floor(h*6)
    local p, q, t = v*(1-s), v*(1-f*s), v*(1-(1-f)*s)
    local r, g, b
    if     i==0 then r,g,b=v,t,p
    elseif i==1 then r,g,b=q,v,p
    elseif i==2 then r,g,b=p,v,t
    elseif i==3 then r,g,b=p,q,v
    elseif i==4 then r,g,b=t,p,v
    else              r,g,b=v,p,q end
    return math.floor(r*255+.5), math.floor(g*255+.5), math.floor(b*255+.5)
end

local function nd(k, props)
    local o = Drawing.new(k)
    for a, b in pairs(props) do o[a] = b end
    return o
end

local BG      = Color3.fromRGB(18,  20,  32)
local BG2     = Color3.fromRGB(12,  14,  22)
local BORDER  = Color3.fromRGB(80,  85, 145)
local ACCENT  = Color3.fromRGB(108, 98, 210)
local SEP     = Color3.fromRGB(45,  50,  78)
local SECLBL  = Color3.fromRGB(115, 120, 168)
local TEXT    = Color3.fromRGB(218, 222, 248)
local TEXTDIM = Color3.fromRGB(115, 120, 162)
local TOGOFF  = Color3.fromRGB(40,  43,  65)

local E = {}
E.bg    = nd("Square",{Filled=true,  Color=BG,     Transparency=1, ZIndex=1, Visible=true})
E.bdr   = nd("Square",{Filled=false, Color=BORDER, Transparency=1, ZIndex=2, Visible=true})
E.hdr   = nd("Square",{Filled=true,  Color=BG2,    Transparency=1, ZIndex=2, Visible=true})
E.bar   = nd("Square",{Filled=true,  Color=ACCENT, Transparency=1, ZIndex=3, Visible=true})
E.title = nd("Text",{Text="NPC HITBOX EXPANDER", Color=Color3.fromRGB(205,200,255), Size=13,
             Font=Drawing.Fonts.SystemBold, Outline=false, Visible=true, ZIndex=4, Transparency=1})
E.xbg   = nd("Square",{Filled=true,  Color=Color3.fromRGB(200,60,60),   Transparency=0, Visible=true, ZIndex=4})
E.xbdr  = nd("Square",{Filled=false, Color=Color3.fromRGB(255,100,100), Transparency=0, Visible=true, ZIndex=5})
E.xl1   = nd("Line",  {Color=Color3.fromRGB(255,255,255), Thickness=1.5, Transparency=0.9, Visible=true, ZIndex=6})
E.xl2   = nd("Line",  {Color=Color3.fromRGB(255,255,255), Thickness=1.5, Transparency=0.9, Visible=true, ZIndex=6})
E.sep   = nd("Line",  {Color=SEP, Thickness=1, Transparency=1, Visible=true, ZIndex=2})
E.secM  = nd("Text",{Text="MAIN",    Color=SECLBL, Size=10, Font=Drawing.Fonts.SystemBold, Outline=false, Visible=true, ZIndex=3, Transparency=1})
E.secV  = nd("Text",{Text="VISUALS", Color=SECLBL, Size=10, Font=Drawing.Fonts.SystemBold, Outline=false, Visible=true, ZIndex=3, Transparency=1})

local function mkTog(lbl)
    return {
        lbl = nd("Text",  {Text=lbl, Color=TEXT, Size=11, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=3, Transparency=1}),
        bg  = nd("Square",{Filled=true,  Color=TOGOFF, Transparency=1, ZIndex=3, Visible=true}),
        bdr = nd("Square",{Filled=false, Color=BORDER, Transparency=1, ZIndex=4, Visible=true}),
    }
end

E.tEn   = mkTog("ENABLE")
E.tVis  = mkTog("VISUALIZER")
E.tOut  = mkTog("OUTLINE")
E.tHC   = mkTog("HEALTH COLOR")

E.swBg  = nd("Square",{Filled=true,  Color=Color3.fromRGB(108,98,210), Transparency=1,   ZIndex=4, Visible=true})
E.swBdr = nd("Square",{Filled=false, Color=BORDER,   Transparency=0.9, ZIndex=5, Visible=true})

E.inLbl = nd("Text",{Text="NPC FOLDER", Color=TEXTDIM, Size=10, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=3, Transparency=1})
E.inBg  = nd("Square",{Filled=true,  Color=BG2,    Transparency=1, ZIndex=3, Visible=true})
E.inBdr = nd("Square",{Filled=false, Color=BORDER, Transparency=1, ZIndex=4, Visible=true})
E.inTxt = nd("Text",{Text="", Color=TEXT, Size=11, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=5, Transparency=1})
E.inPlh = nd("Text",{Text="folder name...", Color=TEXTDIM, Size=11, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=5, Transparency=1})
E.inCur = nd("Line",{Color=TEXT, Thickness=1, Transparency=1, Visible=false, ZIndex=5})

E.dpLbl = nd("Text",{Text="HITBOX PART", Color=TEXTDIM, Size=10, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=3, Transparency=1})
E.dpBg  = nd("Square",{Filled=true,  Color=BG2,    Transparency=1, ZIndex=3, Visible=true})
E.dpBdr = nd("Square",{Filled=false, Color=BORDER, Transparency=1, ZIndex=4, Visible=true})
E.dpTxt = nd("Text",{Text=PARTS[1], Color=TEXT, Size=11, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=5, Transparency=1})
E.dpArr = nd("Text",{Text=">", Color=TEXTDIM, Size=10, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=5, Transparency=1})

local dropOpen = false
local DD_W = 130
local DD_IH = 18
local DD = {
    bg     = nd("Square",{Filled=true,  Color=BG,     Transparency=1, ZIndex=20, Visible=false}),
    bdr    = nd("Square",{Filled=false, Color=BORDER, Transparency=1, ZIndex=21, Visible=false}),
    topbar = nd("Square",{Filled=true,  Color=ACCENT, Transparency=1, ZIndex=21, Visible=false}),
    items  = {},
}
for i=1,#PARTS do
    DD.items[i] = {
        bg  = nd("Square",{Filled=true, Color=ACCENT, Transparency=0, ZIndex=21, Visible=false}),
        lbl = nd("Text",{Text=PARTS[i], Color=TEXT, Size=11, Font=Drawing.Fonts.System, Outline=false, Visible=false, ZIndex=22, Transparency=1}),
    }
end

local function mkSld(lbl, val)
    return {
        lbl  = nd("Text",  {Text=lbl, Color=TEXTDIM, Size=10, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=3, Transparency=1}),
        val  = nd("Text",  {Text=val, Color=TEXT,    Size=10, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=5, Transparency=1}),
        bg   = nd("Square",{Filled=true,  Color=Color3.fromRGB(30,32,50), Transparency=1, ZIndex=3, Visible=true}),
        fill = nd("Square",{Filled=true,  Color=ACCENT, Transparency=1, ZIndex=4, Visible=true}),
        bdr  = nd("Square",{Filled=false, Color=BORDER, Transparency=0.8, ZIndex=5, Visible=true}),
    }
end

E.sSize = mkSld("HITBOX SIZE",  "5.0")
E.sDist = mkSld("MAX DISTANCE", "500")

local CP = {ring={}, sv={}}
CP.bg     = nd("Square",{Filled=true,  Color=BG,     Transparency=1, ZIndex=28, Visible=false})
CP.bdr    = nd("Square",{Filled=false, Color=BORDER, Transparency=1, ZIndex=29, Visible=false})
CP.topbar = nd("Square",{Filled=true,  Color=ACCENT, Transparency=1, ZIndex=29, Visible=false})
CP.title  = nd("Text",  {Text="COLOR PICKER", Color=TEXT, Size=11, Font=Drawing.Fonts.SystemBold, Outline=false, Transparency=1, Visible=false, ZIndex=29})
CP.ringCur= nd("Circle",{Radius=7, NumSides=16, Thickness=2, Color=Color3.fromRGB(0,0,0), Transparency=0.95, Visible=false, ZIndex=32})
CP.svCur  = nd("Circle",{Radius=5, NumSides=12, Thickness=2, Color=Color3.fromRGB(0,0,0), Transparency=0.95, Visible=false, ZIndex=32})
do
    for i=1,180 do
        local r,g,b = hsvToRgb((i-1)/180,1,1)
        CP.ring[i] = nd("Circle",{Radius=8, NumSides=32, Thickness=10, Color=Color3.fromRGB(r,g,b), Transparency=0.95, Visible=false, ZIndex=30})
    end
end
do
    for i=1,64 do
        CP.sv[i] = nd("Square",{Filled=true, Color=BG, Transparency=1, Visible=false, ZIndex=30})
    end
end

local NF = {
    bg  = nd("Square",{Filled=true,  Color=Color3.fromRGB(18,20,32), Transparency=0, ZIndex=50, Visible=false}),
    bdr = nd("Square",{Filled=false, Color=BORDER, Transparency=0, ZIndex=51, Visible=false}),
    bar = nd("Square",{Filled=true,  Color=ACCENT, Transparency=0, ZIndex=51, Visible=false}),
    txt = nd("Text",  {Text="PRESS RIGHT CTRL TO TOGGLE MENU", Color=TEXT, Size=11,
              Font=Drawing.Fonts.SystemBold, Outline=false, Transparency=0, Visible=false, ZIndex=52}),
}

local POOL = 720
local boxLines = {}
for i=1,POOL do
    boxLines[i] = nd("Line",{Color=Color3.fromRGB(108,98,210), Thickness=2, Transparency=1, Visible=false, ZIndex=10})
end
local boxUsed    = 0
local boxUsedPrev = 0

local function getLine()
    boxUsed = boxUsed + 1
    if boxUsed > POOL then boxUsed=POOL; return nil end
    return boxLines[boxUsed]
end

local function flushLines()
    for i=boxUsed+1,boxUsedPrev do boxLines[i].Visible=false end
    boxUsedPrev = boxUsed
    boxUsed = 0
end

local KEY_MAP = {}
for i=0,25 do KEY_MAP[0x41+i]={string.char(97+i), string.char(65+i)} end
for i=0,9  do KEY_MAP[0x30+i]={tostring(i), tostring(i)} end
KEY_MAP[0x20]={" "," "}
KEY_MAP[0xBD]={"-","_"}
KEY_MAP[0xBE]={".","." }

local function processInput()
    if not inputActive then prevKeys = {}; return end
    local now   = os.clock()
    local shift = iskeypressed(0xA0) or iskeypressed(0xA1)
    local caps  = iskeypressed(0x14)
    local upper = (shift ~= caps)
    local ctrl  = iskeypressed(0x11) or iskeypressed(0xA2) or iskeypressed(0xA3)

    if ctrl then
        local vDown = iskeypressed(0x56)
        if vDown and not prevKeys[0x56] then
            if type(getclipboard) == "function" then
                local ok, clip = pcall(getclipboard)
                if ok and type(clip) == "string" and #clip > 0 then
                    cfg.folderName = cfg.folderName .. clip
                    HBX.cacheTime = 0
                end
            end
        end
        prevKeys[0x56] = vDown
        prevKeys[0x08] = iskeypressed(0x08)
        prevKeys[0x0D] = iskeypressed(0x0D)
        return
    end

    for vk, chars in pairs(KEY_MAP) do
        local dn = iskeypressed(vk)
        if dn then
            if not prevKeys[vk] then
                cfg.folderName = cfg.folderName .. (upper and chars[2] or chars[1])
                keyRepeat[vk] = now + 0.4
                HBX.cacheTime = 0
            elseif now >= (keyRepeat[vk] or math.huge) then
                cfg.folderName = cfg.folderName .. (upper and chars[2] or chars[1])
                keyRepeat[vk] = now + 0.05
                HBX.cacheTime = 0
            end
        else
            keyRepeat[vk] = nil
        end
        prevKeys[vk] = dn
    end

    local bs = iskeypressed(0x08)
    if bs then
        if not prevKeys[0x08] then
            if #cfg.folderName > 0 then cfg.folderName = cfg.folderName:sub(1,-2); HBX.cacheTime = 0 end
            keyRepeat[0x08] = now + 0.4
        elseif now >= (keyRepeat[0x08] or math.huge) then
            if #cfg.folderName > 0 then cfg.folderName = cfg.folderName:sub(1,-2); HBX.cacheTime = 0 end
            keyRepeat[0x08] = now + 0.05
        end
    else
        keyRepeat[0x08] = nil
    end
    prevKeys[0x08] = bs

    if iskeypressed(0x0D) and not prevKeys[0x0D] then inputActive = false end
    prevKeys[0x0D] = iskeypressed(0x0D)
end

function HBX:GetNPCModels()
    local now = os.clock()
    if now - self.cacheTime < 0.5 and #self.cachedModels > 0 then return self.cachedModels end
    self.cachedModels = {}
    if cfg.folderName == "" then self.cacheTime=now; return self.cachedModels end
    local fn = cfg.folderName
    for _,child in ipairs(workspace:GetChildren()) do
        if child.Name == fn then
            if child.ClassName == "Folder" then
                for _,m in ipairs(child:GetChildren()) do
                    if m:IsA("Model") then table.insert(self.cachedModels,m) end
                end
            elseif child:IsA("Model") then
                table.insert(self.cachedModels, child)
            elseif child.ClassName=="Part" or child.ClassName=="MeshPart" then
                table.insert(self.cachedModels, child)
            end
        elseif child:IsA("Folder") then
            for _,item in ipairs(child:GetChildren()) do
                if item.Name == fn then
                    if item.ClassName=="Folder" then
                        for _,m in ipairs(item:GetChildren()) do
                            if m:IsA("Model") then table.insert(self.cachedModels,m) end
                        end
                    elseif item:IsA("Model") then
                        table.insert(self.cachedModels, item)
                    end
                end
            end
        end
    end
    self.cacheTime = now
    return self.cachedModels
end

function HBX:FindPart(model, partType)
    local key = model.Address.."_"..partType
    local now = os.clock()
    if self.partTypeCache[key] then
        local c = self.partTypeCache[key]
        if now - c.t < 10.0 then
            local ok, p = pcall(function() return c.part.Parent end)
            if ok and p then return c.part end
        end
    end
    local function tryDirect(names)
        for _,n in ipairs(names) do
            local p = model:FindFirstChild(n)
            if p and p:IsA("BasePart") then return p end
        end
    end
    local function searchAttach(anames)
        for _,obj in ipairs(model:GetDescendants()) do
            local cn = obj.ClassName
            if cn=="Part" or cn=="MeshPart" then
                for _,ch in ipairs(obj:GetChildren()) do
                    if ch.ClassName=="Attachment" then
                        local ln = string.lower(ch.Name)
                        for _,an in ipairs(anames) do
                            if string.find(ln,string.lower(an)) then return obj end
                        end
                    end
                end
            end
        end
    end
    local found
    if     partType=="Head"      then found=tryDirect({"Head","head","HeadHB"}) or searchAttach({"FaceFront","FaceCenterAttachment","HatAttachment"})
    elseif partType=="Torso"     then found=tryDirect({"HumanoidRootPart","Torso","UpperTorso","LowerTorso"}) or searchAttach({"RootRigAttachment","BodyFrontAttachment"})
    elseif partType=="Left Arm"  then found=tryDirect({"LeftHand","LeftUpperArm","LeftLowerArm","LeftArm"}) or searchAttach({"LeftShoulderRigAttachment","LeftElbowRigAttachment"})
    elseif partType=="Right Arm" then found=tryDirect({"RightHand","RightUpperArm","RightLowerArm","RightArm"}) or searchAttach({"RightShoulderRigAttachment","RightElbowRigAttachment"})
    elseif partType=="Left Leg"  then found=tryDirect({"LeftFoot","LeftUpperLeg","LeftLowerLeg","LeftLeg"}) or searchAttach({"LeftHipRigAttachment","LeftKneeRigAttachment"})
    elseif partType=="Right Leg" then found=tryDirect({"RightFoot","RightUpperLeg","RightLowerLeg","RightLeg"}) or searchAttach({"RightHipRigAttachment","RightKneeRigAttachment"})
    end
    if found then self.partTypeCache[key]={part=found, t=now} end
    return found
end

function HBX:IsPartValid(part)
    if not part then return false end
    local ok, p = pcall(function() return part.Parent end)
    return ok and p ~= nil
end

function HBX:RestorePart(addr, part)
    if self:IsPartValid(part) then
        local orig = self.originalSizes[addr]
        if orig then pcall(function() part.Size=orig; part.Transparency=0; part.CanCollide=true end) end
    end
    self.expandedParts[addr]=nil; self.originalSizes[addr]=nil
end

function HBX:RestoreAll()
    for addr,part in pairs(self.expandedParts) do
        self:RestorePart(addr, part)
    end
    self.expandedParts={}; self.partTypeCache={}
end

function HBX:Cleanup()
    local now = os.clock()
    if now - self.cleanupTime < 3.0 then return end
    self.cleanupTime = now
    local dead = {}
    for addr,part in pairs(self.expandedParts) do
        if not self:IsPartValid(part) then dead[#dead+1]=addr end
    end
    for _,a in ipairs(dead) do self.expandedParts[a]=nil; self.originalSizes[a]=nil end
    local stale = {}
    for k,d in pairs(self.partTypeCache) do
        if now - d.t > 30.0 then stale[#stale+1]=k end
    end
    for _,k in ipairs(stale) do self.partTypeCache[k]=nil end
end

function HBX:ExpandHitboxes()
    local now = os.clock()
    if now - self.updateTime < 0.15 then return end
    self.updateTime = now
    local partType = PARTS[cfg.partIndex]
    local expSz    = cfg.hitboxSize
    local maxDist  = cfg.maxDistance
    local models   = self:GetNPCModels()
    if #models == 0 then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local lp = hrp.Position
    local cur = {}
    for _,npc in ipairs(models) do
        local function processNPC()
            local hum = npc:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then
                local p = self:FindPart(npc, partType)
                if p then local a=p.Address; if self.expandedParts[a] then self:RestorePart(a,p) end end
                return
            end
            local npos
            if npc.ClassName=="Part" or npc.ClassName=="MeshPart" then
                npos = npc.Position
            else
                local h2 = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
                if h2 then npos = h2.Position end
            end
            if npos then
                local d = npos - lp
                if d.X*d.X+d.Y*d.Y+d.Z*d.Z <= maxDist*maxDist then
                    local p = self:FindPart(npc, partType)
                    if p and self:IsPartValid(p) then
                        local a = p.Address
                        cur[a] = p
                        if not self.originalSizes[a] then self.originalSizes[a]=p.Size end
                        local orig = self.originalSizes[a]
                        if orig then
                            pcall(function()
                                p.Size = Vector3.new(orig.X+expSz, orig.Y+expSz, orig.Z+expSz)
                                p.Transparency = 0
                                p.CanCollide = false
                            end)
                            self.expandedParts[a] = p
                        end
                    end
                end
            end
        end
        processNPC()
    end
    local rc = 0
    for a,p in pairs(self.expandedParts) do
        if rc >= 10 then break end
        if not cur[a] then self:RestorePart(a,p); rc=rc+1 end
    end
end

function HBX:RenderBoxes()
    boxUsed = 0
    if not cfg.enabled or not cfg.visualizer then flushLines(); return end
    local vp  = Camera.ViewportSize
    local sw  = vp.X; local sh = vp.Y
    local mg  = 150
    local cam = Camera.Position
    local cr  = math.floor(visColor.R*255)
    local cg  = math.floor(visColor.G*255)
    local cb  = math.floor(visColor.B*255)
    local rendered = 0
    for addr,part in pairs(self.expandedParts) do
        local function renderBox()
            if not self:IsPartValid(part) then return end
            local model = part.Parent
            if not model then return end
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then return end
            local dr, dg, db = cr, cg, cb
            if cfg.healthColor and hum then
                local hp = hum.Health / math.max(hum.MaxHealth, 1)
                if hp > 0.5 then dr=math.floor(255*(1-hp)*2); dg=255
                else dr=255; dg=math.floor(255*hp*2) end
                db=0
            end
            local pp = part.Position
            local dx = pp.X-cam.X; local dy=pp.Y-cam.Y; local dz=pp.Z-cam.Z
            local dsq = dx*dx+dy*dy+dz*dz
            if dsq < 25 then return end
            local dist = math.sqrt(dsq)
            local baseThick = math.max(1, math.min(2, math.floor(60/dist)))
            local orig = HBX.originalSizes[addr]
            local ps = orig and Vector3.new(orig.X+cfg.hitboxSize, orig.Y+cfg.hitboxSize, orig.Z+cfg.hitboxSize) or part.Size
            local hx=math.min(ps.X,100)/2; local hy=math.min(ps.Y,100)/2; local hz=math.min(ps.Z,100)/2
            local px=pp.X; local py=pp.Y; local pz=pp.Z
            local c3={
                Vector3.new(px-hx,py+hy,pz-hz), Vector3.new(px+hx,py+hy,pz-hz),
                Vector3.new(px+hx,py+hy,pz+hz), Vector3.new(px-hx,py+hy,pz+hz),
                Vector3.new(px-hx,py-hy,pz-hz), Vector3.new(px+hx,py-hy,pz-hz),
                Vector3.new(px+hx,py-hy,pz+hz), Vector3.new(px-hx,py-hy,pz+hz),
            }
            local sc={}; local vc=0
            for i,v3 in ipairs(c3) do
                local sv,onS = WorldToScreen(v3)
                if onS then
                    local sx,sy=sv.X,sv.Y
                    if sx>-mg and sx<sw+mg and sy>-mg and sy<sh+mg then
                        sc[i]={x=math.floor(sx),y=math.floor(sy)}; vc=vc+1
                    end
                end
            end
            if vc < 6 then return end
            local ml2 = (sw*0.7)*(sw*0.7)
            local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
            local bc = Color3.fromRGB(dr,dg,db)
            if cfg.outline then
                for _,e in ipairs(edges) do
                    local i1,i2=e[1],e[2]
                    if sc[i1] and sc[i2] then
                        local ex=sc[i2].x-sc[i1].x; local ey=sc[i2].y-sc[i1].y
                        if ex*ex+ey*ey < ml2 then
                            local ln=getLine()
                            if ln then
                                ln.From=Vector2.new(sc[i1].x,sc[i1].y); ln.To=Vector2.new(sc[i2].x,sc[i2].y)
                                ln.Color=Color3.fromRGB(0,0,0); ln.Thickness=baseThick+2; ln.Transparency=1; ln.Visible=true
                            end
                        end
                    end
                end
            end
            for _,e in ipairs(edges) do
                local i1,i2=e[1],e[2]
                if sc[i1] and sc[i2] then
                    local ex=sc[i2].x-sc[i1].x; local ey=sc[i2].y-sc[i1].y
                    if ex*ex+ey*ey < ml2 then
                        local ln=getLine()
                        if ln then
                            ln.From=Vector2.new(sc[i1].x,sc[i1].y); ln.To=Vector2.new(sc[i2].x,sc[i2].y)
                            ln.Color=bc; ln.Thickness=baseThick; ln.Transparency=1; ln.Visible=true
                        end
                    end
                end
            end
            rendered=rendered+1
        end
        renderBox()
    end
    flushLines()
end

local function applyColor()
    local r,g,b = hsvToRgb(CP_H,CP_S,CP_V)
    visColor = Color3.fromRGB(r,g,b)
    E.swBg.Color = visColor
end

local function hidePicker()
    CP.bg.Visible=false; CP.bdr.Visible=false; CP.topbar.Visible=false; CP.title.Visible=false
    CP.ringCur.Visible=false; CP.svCur.Visible=false
    for _,d in ipairs(CP.ring) do d.Visible=false end
    for _,d in ipairs(CP.sv)   do d.Visible=false end
end

local function renderPicker()
    local ppx=PX+PW+6; local ppy=PY
    local pcx=ppx+CP_PW/2; local pcy=ppy+28+CP_R_OUT+4
    CP.bg.Position=Vector2.new(ppx,ppy);     CP.bg.Size=Vector2.new(CP_PW,CP_PH);  CP.bg.Visible=true
    CP.bdr.Position=Vector2.new(ppx,ppy);    CP.bdr.Size=Vector2.new(CP_PW,CP_PH); CP.bdr.Visible=true
    CP.topbar.Position=Vector2.new(ppx,ppy); CP.topbar.Size=Vector2.new(CP_PW,3);  CP.topbar.Visible=true
    CP.title.Position=Vector2.new(ppx+10,ppy+8); CP.title.Visible=true
    local N=#CP.ring
    for i,dot in ipairs(CP.ring) do
        local angle=((i-1)/N)*math.pi*2-math.pi/2
        dot.Position=Vector2.new(pcx+CP_R_MID*math.cos(angle), pcy+CP_R_MID*math.sin(angle))
        dot.Visible=true
    end
    local ra=CP_H*math.pi*2-math.pi/2
    CP.ringCur.Position=Vector2.new(pcx+CP_R_MID*math.cos(ra), pcy+CP_R_MID*math.sin(ra))
    CP.ringCur.Visible=true
    local svX=math.floor(pcx-SV_SIZE/2); local svY=math.floor(pcy-SV_SIZE/2)
    for i=1,SV_COLS*SV_COLS do
        local cc=(i-1)%SV_COLS; local rr=math.floor((i-1)/SV_COLS)
        local s=cc/(SV_COLS-1); local v=1-rr/(SV_COLS-1)
        local dr,dg,db=hsvToRgb(CP_H,s,v)
        local cell=CP.sv[i]
        cell.Position=Vector2.new(svX+cc*SV_CELL, svY+rr*SV_CELL)
        cell.Size=Vector2.new(SV_CELL+1,SV_CELL+1)
        cell.Color=Color3.fromRGB(dr,dg,db)
        cell.Visible=true
    end
    CP.svCur.Position=Vector2.new(svX+CP_S*(SV_SIZE-SV_CELL)+SV_CELL/2,
                                   svY+(1-CP_V)*(SV_SIZE-SV_CELL)+SV_CELL/2)
    CP.svCur.Visible=true
end

local function hideDropdown()
    dropOpen=false
    DD.bg.Visible=false; DD.bdr.Visible=false; DD.topbar.Visible=false
    for _,item in ipairs(DD.items) do item.bg.Visible=false; item.lbl.Visible=false end
end

local function hidePanel()
    local function hs(o) if o then o.Visible=false end end
    hs(E.bg);hs(E.bdr);hs(E.hdr);hs(E.bar);hs(E.title)
    hs(E.xbg);hs(E.xbdr);hs(E.xl1);hs(E.xl2);hs(E.sep)
    hs(E.secM);hs(E.secV)
    for _,t in ipairs({E.tEn,E.tVis,E.tOut,E.tHC}) do
        t.bg.Visible=false; t.bdr.Visible=false; t.lbl.Visible=false
    end
    hs(E.swBg);hs(E.swBdr)
    hs(E.inLbl);hs(E.inBg);hs(E.inBdr);hs(E.inTxt);hs(E.inPlh);hs(E.inCur)
    hs(E.dpLbl);hs(E.dpBg);hs(E.dpBdr);hs(E.dpTxt);hs(E.dpArr)
    for _,sl in ipairs({E.sSize,E.sDist}) do
        sl.lbl.Visible=false; sl.val.Visible=false; sl.bg.Visible=false; sl.fill.Visible=false; sl.bdr.Visible=false
    end
    hideDropdown()
end

local SLW = PW - 20
local SLH = 6

local function renderPanel(dt)
    cursorBlink = cursorBlink + dt
    if not guiVisible then hidePanel(); return end
    local x,y,w = PX,PY,PW
    E.bg.Visible=true;  E.bg.Position=Vector2.new(x,y);  E.bg.Size=Vector2.new(w,PANEL_H)
    E.bdr.Visible=true; E.bdr.Position=Vector2.new(x,y); E.bdr.Size=Vector2.new(w,PANEL_H)
    E.hdr.Visible=true; E.hdr.Position=Vector2.new(x,y); E.hdr.Size=Vector2.new(w,28)
    E.bar.Visible=true; E.bar.Position=Vector2.new(x,y); E.bar.Size=Vector2.new(w,3)
    E.title.Visible=true; E.title.Position=Vector2.new(x+10,y+8)
    local cbw,cbh=28,28; local cbx=x+w-cbw
    E.xbg.Visible=true;  E.xbg.Position=Vector2.new(cbx,y); E.xbg.Size=Vector2.new(cbw,cbh)
    E.xbdr.Visible=true; E.xbdr.Position=Vector2.new(cbx,y); E.xbdr.Size=Vector2.new(cbw,cbh)
    local p=5; local cx2,cy2=cbx+cbw/2,y+cbh/2
    E.xl1.Visible=true; E.xl1.From=Vector2.new(cx2-p,cy2-p); E.xl1.To=Vector2.new(cx2+p,cy2+p)
    E.xl2.Visible=true; E.xl2.From=Vector2.new(cx2+p,cy2-p); E.xl2.To=Vector2.new(cx2-p,cy2+p)
    E.secM.Visible=true; E.secM.Position=Vector2.new(x+8,y+32)

    local cbS=13
    local function drawTog(t, val, ry)
        local cbY = ry+math.floor((18-cbS)/2)
        t.bg.Visible=true;  t.bg.Position=Vector2.new(x+10,cbY);  t.bg.Size=Vector2.new(cbS,cbS)
        t.bdr.Visible=true; t.bdr.Position=Vector2.new(x+10,cbY); t.bdr.Size=Vector2.new(cbS,cbS)
        t.lbl.Visible=true; t.lbl.Position=Vector2.new(x+10+cbS+7,ry+3)
        if val then t.bg.Color=ACCENT; t.bdr.Color=Color3.fromRGB(140,130,240)
        else t.bg.Color=TOGOFF; t.bdr.Color=BORDER end
    end

    drawTog(E.tEn, cfg.enabled, y+46)

    E.inLbl.Visible=true; E.inLbl.Position=Vector2.new(x+10,y+68)
    local inX=x+10; local inW=w-20; local inY=y+80; local inH=16
    E.inBg.Visible=true;  E.inBg.Position=Vector2.new(inX,inY);  E.inBg.Size=Vector2.new(inW,inH)
    E.inBdr.Visible=true; E.inBdr.Position=Vector2.new(inX,inY); E.inBdr.Size=Vector2.new(inW,inH)
    E.inBdr.Color = inputActive and ACCENT or BORDER
    local showPlh = cfg.folderName == ""
    E.inTxt.Visible=not showPlh; E.inTxt.Text=cfg.folderName; E.inTxt.Position=Vector2.new(inX+4,inY+2)
    E.inPlh.Visible=showPlh;     E.inPlh.Position=Vector2.new(inX+4,inY+2)
    local curShow = inputActive and (math.floor(cursorBlink*2)%2==0)
    E.inCur.Visible=curShow
    if curShow then
        local tx = inX+4 + math.min(#cfg.folderName*6.5, inW-8)
        E.inCur.From=Vector2.new(tx,inY+2); E.inCur.To=Vector2.new(tx,inY+inH-2)
    end

    E.dpLbl.Visible=true; E.dpLbl.Position=Vector2.new(x+10,y+104)
    local dpY=y+116; local dpH=16
    E.dpBg.Visible=true;  E.dpBg.Position=Vector2.new(inX,dpY);  E.dpBg.Size=Vector2.new(inW,dpH)
    E.dpBdr.Visible=true; E.dpBdr.Position=Vector2.new(inX,dpY); E.dpBdr.Size=Vector2.new(inW,dpH)
    E.dpTxt.Visible=true; E.dpTxt.Text=PARTS[cfg.partIndex]; E.dpTxt.Position=Vector2.new(inX+4,dpY+2)
    E.dpArr.Visible=true; E.dpArr.Position=Vector2.new(x+w-18,dpY+2)

    E.sSize.lbl.Visible=true; E.sSize.lbl.Position=Vector2.new(x+10,y+140)
    E.sSize.val.Visible=true; E.sSize.val.Text=tostring(math.floor(cfg.hitboxSize*10)/10); E.sSize.val.Position=Vector2.new(x+w-42,y+140)
    local szY=y+152
    local szFrac = math.max(0,math.min(1,(cfg.hitboxSize-1)/(25-1)))
    E.sSize.bg.Visible=true;   E.sSize.bg.Position=Vector2.new(x+10,szY);   E.sSize.bg.Size=Vector2.new(SLW,SLH)
    E.sSize.fill.Visible=true; E.sSize.fill.Position=Vector2.new(x+10,szY); E.sSize.fill.Size=Vector2.new(math.floor(szFrac*SLW),SLH)
    E.sSize.bdr.Visible=true;  E.sSize.bdr.Position=Vector2.new(x+10,szY);  E.sSize.bdr.Size=Vector2.new(SLW,SLH)

    E.sDist.lbl.Visible=true; E.sDist.lbl.Position=Vector2.new(x+10,y+166)
    E.sDist.val.Visible=true; E.sDist.val.Text=tostring(math.floor(cfg.maxDistance)); E.sDist.val.Position=Vector2.new(x+w-46,y+166)
    local dsY=y+178
    local dsFrac = math.max(0,math.min(1,(cfg.maxDistance-1)/(5000-1)))
    E.sDist.bg.Visible=true;   E.sDist.bg.Position=Vector2.new(x+10,dsY);   E.sDist.bg.Size=Vector2.new(SLW,SLH)
    E.sDist.fill.Visible=true; E.sDist.fill.Position=Vector2.new(x+10,dsY); E.sDist.fill.Size=Vector2.new(math.floor(dsFrac*SLW),SLH)
    E.sDist.bdr.Visible=true;  E.sDist.bdr.Position=Vector2.new(x+10,dsY);  E.sDist.bdr.Size=Vector2.new(SLW,SLH)

    E.sep.Visible=true; E.sep.From=Vector2.new(x+6,y+192); E.sep.To=Vector2.new(x+w-6,y+192)
    E.secV.Visible=true; E.secV.Position=Vector2.new(x+8,y+196)

    drawTog(E.tVis, cfg.visualizer,  y+210)
    drawTog(E.tOut, cfg.outline,     y+228)
    drawTog(E.tHC,  cfg.healthColor, y+246)

    local swSize=13; local swX=x+w-26; local swY=y+210+math.floor((18-swSize)/2)
    E.swBg.Visible=true;  E.swBg.Position=Vector2.new(swX,swY);  E.swBg.Size=Vector2.new(swSize,swSize)
    E.swBdr.Visible=true; E.swBdr.Position=Vector2.new(swX,swY); E.swBdr.Size=Vector2.new(swSize,swSize)
    E.swBg.Color = visColor

    if dropOpen then
        local ddX = x+w+4
        local ddH = #PARTS*DD_IH+4
        local ddY = y+116-2
        DD.bg.Visible=true;     DD.bg.Position=Vector2.new(ddX,ddY);     DD.bg.Size=Vector2.new(DD_W,ddH)
        DD.bdr.Visible=true;    DD.bdr.Position=Vector2.new(ddX,ddY);    DD.bdr.Size=Vector2.new(DD_W,ddH)
        DD.topbar.Visible=true; DD.topbar.Position=Vector2.new(ddX,ddY); DD.topbar.Size=Vector2.new(DD_W,3)
        for i,item in ipairs(DD.items) do
            local iy = ddY+2+(i-1)*DD_IH
            local sel = i==cfg.partIndex
            item.bg.Visible=true
            item.bg.Position=Vector2.new(ddX+2,iy); item.bg.Size=Vector2.new(DD_W-4,DD_IH)
            item.bg.Transparency = sel and 1 or 0
            item.lbl.Visible=true; item.lbl.Position=Vector2.new(ddX+8,iy+3)
            item.lbl.Color = sel and Color3.fromRGB(200,195,255) or TEXT
        end
    else
        hideDropdown()
    end

    if CP_OPEN then renderPicker() else hidePicker() end
end

local function showNotif()
    if notifShown then return end
    notifShown = true
    notif.phase="fadein"; notif.timer=0; notif.alpha=0
end

task.spawn(function()
    local prevM1     = false
    local prevRCtrl  = false
    local Mouse      = LocalPlayer:GetMouse()
    local lastT      = tick()

    while true do
        task.wait(1/60)
        local now=tick(); local dt=math.min(now-lastT,0.1); lastT=now
        local m1=ismouse1pressed(); local mx,my=Mouse.X,Mouse.Y

        if not m1 then CP_DRAG=nil; sliderDrag.active=false end

        if m1 then
            if CP_DRAG=="ring" and CP_OPEN then
                local pcx=PX+PW+6+CP_PW/2; local pcy=PY+28+CP_R_OUT+4
                CP_H=(math.atan2(my-pcy,mx-pcx)/(math.pi*2)+0.25+1)%1
                applyColor()
            elseif CP_DRAG=="sv" and CP_OPEN then
                local pcx=PX+PW+6+CP_PW/2; local pcy=PY+28+CP_R_OUT+4
                local svX=math.floor(pcx-SV_SIZE/2); local svY=math.floor(pcy-SV_SIZE/2)
                CP_S=math.max(0,math.min(1,(mx-svX)/SV_SIZE))
                CP_V=math.max(0,math.min(1,1-(my-svY)/SV_SIZE))
                applyColor()
            elseif sliderDrag.active then
                local t = sliderDrag.which
                if t == "size" then
                    local frac=math.max(0,math.min(1,(mx-(PX+10))/SLW))
                    cfg.hitboxSize=math.floor((1+(frac*(25-1)))*10)/10
                elseif t == "dist" then
                    local frac=math.max(0,math.min(1,(mx-(PX+10))/SLW))
                    cfg.maxDistance=math.floor(1+frac*(5000-1))
                end
            end

            if not prevM1 then
                local cbx=PX+PW-28
                if mx>=cbx and mx<=PX+PW and my>=PY and my<=PY+28 then
                    guiVisible=false; CP_OPEN=false; dropOpen=false; showNotif()
                elseif mx>=PX and mx<=cbx and my>=PY and my<=PY+28 then
                    drag.active=true; drag.ox=mx-PX; drag.oy=my-PY
                    inputActive=false
                end

                if not drag.active and guiVisible then
                    local x,y,w=PX,PY,PW

                    local swSize=13; local swX=x+w-26; local swY=y+210+math.floor((18-swSize)/2)
                    if mx>=swX and mx<=swX+swSize and my>=swY and my<=swY+swSize then
                        CP_OPEN=not CP_OPEN
                        if CP_OPEN then
                            local rr=math.floor(visColor.R*255+.5)
                            local gg=math.floor(visColor.G*255+.5)
                            local bb=math.floor(visColor.B*255+.5)
                            local mx2=math.max(rr,gg,bb)/255; local mn=math.min(rr,gg,bb)/255
                            CP_V=mx2
                            CP_S=mx2>0 and (mx2-mn)/mx2 or 0
                            local d2=mx2-mn
                            if d2<0.001 then CP_H=0
                            elseif mx2==rr/255 then CP_H=((gg-bb)/255/d2%6)/6
                            elseif mx2==gg/255 then CP_H=((bb-rr)/255/d2+2)/6
                            else CP_H=((rr-gg)/255/d2+4)/6 end
                        end
                    elseif CP_OPEN and CP_DRAG==nil then
                        local pcx=PX+PW+6+CP_PW/2; local pcy=PY+28+CP_R_OUT+4
                        local ddx,ddy=mx-pcx,my-pcy
                        local ddist=math.sqrt(ddx*ddx+ddy*ddy)
                        if ddist>=CP_R_IN and ddist<=CP_R_OUT then
                            CP_H=(math.atan2(ddy,ddx)/(math.pi*2)+0.25+1)%1
                            CP_DRAG="ring"; applyColor()
                        elseif ddist<CP_R_IN-6 then
                            local svX=math.floor(pcx-SV_SIZE/2); local svY=math.floor(pcy-SV_SIZE/2)
                            if mx>=svX and mx<=svX+SV_SIZE and my>=svY and my<=svY+SV_SIZE then
                                CP_S=math.max(0,math.min(1,(mx-svX)/SV_SIZE))
                                CP_V=math.max(0,math.min(1,1-(my-svY)/SV_SIZE))
                                CP_DRAG="sv"; applyColor()
                            end
                        elseif ddist>CP_R_OUT then
                            local ppx=PX+PW+6
                            if not(mx>=ppx and mx<=ppx+CP_PW and my>=PY and my<=PY+CP_PH) then
                                CP_OPEN=false
                            end
                        end
                    else
                        local cbS=13
                        local function cbHit(ry) return mx>=x+10 and mx<=x+10+cbS and my>=ry+math.floor((18-cbS)/2) and my<=ry+math.floor((18-cbS)/2)+cbS end
                        if     cbHit(y+46)  then cfg.enabled    =not cfg.enabled; if not cfg.enabled then HBX:RestoreAll() end
                        elseif cbHit(y+210) then cfg.visualizer =not cfg.visualizer
                        elseif cbHit(y+228) then cfg.outline    =not cfg.outline
                        elseif cbHit(y+246) then cfg.healthColor=not cfg.healthColor
                        end

                        local inY=y+80; local inH=16; local inX=x+10; local inW=w-20
                        if mx>=inX and mx<=inX+inW and my>=inY and my<=inY+inH then
                            inputActive=true; cursorBlink=0
                        else
                            inputActive=false
                        end

                        local dpY=y+116; local dpH=16
                        local ddX=x+w+4; local ddH=#PARTS*DD_IH+4; local ddY=y+116-2
                        if dropOpen and mx>=ddX and mx<=ddX+DD_W and my>=ddY and my<=ddY+ddH then
                            local idx=math.floor((my-(ddY+2))/DD_IH)+1
                            if idx>=1 and idx<=#PARTS then cfg.partIndex=idx; HBX.partTypeCache={} end
                            dropOpen=false
                        elseif mx>=inX and mx<=inX+inW and my>=dpY and my<=dpY+dpH then
                            dropOpen=not dropOpen
                        else
                            dropOpen=false
                        end

                        local szY=y+152
                        if mx>=x+10 and mx<=x+10+SLW and my>=szY and my<=szY+SLH then
                            sliderDrag.active=true; sliderDrag.which="size"
                            local frac=math.max(0,math.min(1,(mx-(x+10))/SLW))
                            cfg.hitboxSize=math.floor((1+frac*(25-1))*10)/10
                        end

                        local dsY=y+178
                        if mx>=x+10 and mx<=x+10+SLW and my>=dsY and my<=dsY+SLH then
                            sliderDrag.active=true; sliderDrag.which="dist"
                            local frac=math.max(0,math.min(1,(mx-(x+10))/SLW))
                            cfg.maxDistance=math.floor(1+frac*(5000-1))
                        end
                    end
                end
            elseif drag.active then
                PX=mx-drag.ox; PY=my-drag.oy
            end
        else
            drag.active=false
        end
        prevM1=m1

        local rCtrl=iskeypressed(0xA3)
        if rCtrl and not prevRCtrl then
            guiVisible=not guiVisible
            if guiVisible then
                notif.phase="idle"; notif.alpha=0
                NF.bg.Visible=false; NF.bdr.Visible=false; NF.bar.Visible=false; NF.txt.Visible=false
            else
                CP_OPEN=false; dropOpen=false; showNotif()
            end
        end
        prevRCtrl=rCtrl

        processInput()

        if cfg.enabled then
            HBX:ExpandHitboxes()
            HBX:Cleanup()
        elseif HBX.wasEnabled then
            HBX:RestoreAll()
        end
        HBX.wasEnabled = cfg.enabled

        HBX:RenderBoxes()

        renderPanel(dt)

        if notif.phase=="fadein" then
            notif.timer=notif.timer+dt
            notif.alpha=math.min(1,notif.timer/0.3)
            if notif.timer>=0.3 then notif.phase="hold"; notif.timer=0 end
        elseif notif.phase=="hold" then
            notif.timer=notif.timer+dt
            if notif.timer>=3 then notif.phase="fadeout"; notif.timer=0 end
        elseif notif.phase=="fadeout" then
            notif.timer=notif.timer+dt
            notif.alpha=math.max(0,1-notif.timer/0.4)
            if notif.timer>=0.4 then
                notif.phase="idle"
                NF.bg.Visible=false; NF.bdr.Visible=false; NF.bar.Visible=false; NF.txt.Visible=false
            end
        end

        if notif.phase~="idle" then
            local vp=Camera.ViewportSize
            local nw=280; local nh=32
            local nx=math.floor(vp.X/2-nw/2); local ny=20
            local a=notif.alpha
            NF.bg.Visible=true;  NF.bg.Position=Vector2.new(nx,ny);  NF.bg.Size=Vector2.new(nw,nh);  NF.bg.Transparency=a
            NF.bdr.Visible=true; NF.bdr.Position=Vector2.new(nx,ny); NF.bdr.Size=Vector2.new(nw,nh); NF.bdr.Transparency=a
            NF.bar.Visible=true; NF.bar.Position=Vector2.new(nx,ny); NF.bar.Size=Vector2.new(nw,3);  NF.bar.Transparency=a
            NF.txt.Visible=true; NF.txt.Position=Vector2.new(nx+nw/2,ny+10); NF.txt.Transparency=a; NF.txt.Center=true
        end
    end
end)
