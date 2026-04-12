local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local cfg = {
    enabled      = false,
    autoTeleport = false,
    useManualPos = false,
    showMarkers  = true,
    showStatus   = true,
    debugMode    = false,
}

local deathPos        = nil
local customSpawn     = nil
local lastCustomSpawn = nil
local lastAlivePos    = nil
local deathSnapshot   = nil
local wasDead         = false

local lastHealth        = 100
local DEATH_THRESHOLD   = 1

local PX, PY = 20, 80
local PW     = 254

local vt         = 0
local stText     = ""
local stAlpha    = 0
local stTimer    = 0
local flashAlpha = 0
local drag       = { active=false, ox=0, oy=0 }

local CP_H, CP_S, CP_V = 0.0, 167/255, 1.0
local _initR, _initG, _initB = 255, 88, 88
local DM_col = Color3.fromRGB(_initR, _initG, _initB)
local SM_col = Color3.fromRGB(_initR, _initG, _initB)

local CP_OPEN = false
local CP_DRAG = nil

local function hsvToRgb(h, s, v)
    local r, g, b
    local i = math.floor(h * 6) % 6
    local f = h * 6 - math.floor(h * 6)
    local p, q, t = v*(1-s), v*(1-f*s), v*(1-(1-f)*s)
    if     i==0 then r,g,b=v,t,p
    elseif i==1 then r,g,b=q,v,p
    elseif i==2 then r,g,b=p,v,t
    elseif i==3 then r,g,b=p,q,v
    elseif i==4 then r,g,b=t,p,v
    else             r,g,b=v,p,q end
    return math.floor(r*255+.5), math.floor(g*255+.5), math.floor(b*255+.5)
end

local function nd(k, props)
    local o = Drawing.new(k)
    for a,b in pairs(props) do o[a]=b end
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
local TOGON   = Color3.fromRGB(45,  148,  82)
local TOGONTX = Color3.fromRGB(185, 252, 205)
local TOGOFF  = Color3.fromRGB(40,  43,  65)
local TOGOFFTX= Color3.fromRGB(128, 132, 175)
local DEATH   = Color3.fromRGB(255,  88,  88)
local SPAWN   = Color3.fromRGB(168, 158, 235)
local GREEN   = Color3.fromRGB(138, 208, 162)
local RED     = Color3.fromRGB(200, 100, 100)

local E = {}

E.bg     = nd("Square",{Filled=true,  Color=BG,     Transparency=1, ZIndex=1, Visible=true})
E.border = nd("Square",{Filled=false, Color=BORDER, Transparency=1, ZIndex=2, Visible=true})
E.hdr    = nd("Square",{Filled=true,  Color=BG2,    Transparency=1, ZIndex=2, Visible=true})
E.topbar = nd("Square",{Filled=true,  Color=ACCENT, Transparency=1, ZIndex=3, Visible=true})
E.title  = nd("Text",{Text="LAST POSITION TELEPORT", Color=Color3.fromRGB(205,200,255), Size=13,
               Font=Drawing.Fonts.SystemBold, Outline=false, Visible=true, ZIndex=4, Transparency=1})
E.closeBtn  = nd("Square",{Filled=true,  Color=Color3.fromRGB(200,60,60),   Transparency=0, Visible=true, ZIndex=4})
E.closeBtnH = nd("Square",{Filled=false, Color=Color3.fromRGB(255,100,100), Transparency=0, Visible=true, ZIndex=5})
E.closeX1   = nd("Line",  {Color=Color3.fromRGB(255,255,255), Thickness=1.5, Transparency=0.9, Visible=true, ZIndex=6})
E.closeX2   = nd("Line",  {Color=Color3.fromRGB(255,255,255), Thickness=1.5, Transparency=0.9, Visible=true, ZIndex=6})

E.sep = {}
for i=1,5 do
    E.sep[i] = nd("Line",{Color=SEP, Thickness=1, Transparency=1, Visible=true, ZIndex=2})
end

E.secSys = nd("Text",{Text="MAIN",        Color=SECLBL, Size=10, Font=Drawing.Fonts.SystemBold, Outline=false, Visible=true, ZIndex=3, Transparency=1})
E.secVis = nd("Text",{Text="VISUALS",     Color=SECLBL, Size=10, Font=Drawing.Fonts.SystemBold, Outline=false, Visible=true, ZIndex=3, Transparency=1})
E.secPos = nd("Text",{Text="POSITIONS",   Color=SECLBL, Size=10, Font=Drawing.Fonts.SystemBold, Outline=false, Visible=true, ZIndex=3, Transparency=1})
E.secTp  = nd("Text",{Text="SPAWN POINT", Color=SECLBL, Size=10, Font=Drawing.Fonts.SystemBold, Outline=false, Visible=true, ZIndex=3, Transparency=1})

local function mkTog(lbl)
    return {
        lbl = nd("Text",  {Text=lbl, Color=TEXT, Size=11, Font=Drawing.Fonts.System, Outline=false, Visible=true, ZIndex=3, Transparency=1}),
        bg  = nd("Square",{Filled=true,  Color=TOGOFF, Transparency=1, ZIndex=3, Visible=true}),
        bdr = nd("Square",{Filled=false, Color=BORDER, Transparency=1, ZIndex=4, Visible=true}),
    }
end

E.tEnabled = mkTog("ENABLE")
E.tAutoTp  = mkTog("AUTO TELEPORT")
E.tManual  = mkTog("MANUAL SAVE POSITION")
E.tMarkers = mkTog("POSITION VISUALIZER")
E.tDebug   = mkTog("DEBUG INFO")

E.swatchBg  = nd("Square",{Filled=true,  Color=DM_col, Transparency=1,   ZIndex=4, Visible=true})
E.swatchBdr = nd("Square",{Filled=false, Color=BORDER, Transparency=0.9, ZIndex=5, Visible=true})

local CP = {
    bg      = nd("Square",{Filled=true,  Color=BG,     Transparency=1,   ZIndex=28, Visible=false}),
    bdr     = nd("Square",{Filled=false, Color=BORDER, Transparency=1,   ZIndex=29, Visible=false}),
    topbar  = nd("Square",{Filled=true,  Color=ACCENT, Transparency=1,   ZIndex=29, Visible=false}),
    title   = nd("Text",  {Text="COLOR PICKER", Color=TEXT, Size=11,
                  Font=Drawing.Fonts.SystemBold, Outline=false, Transparency=1, Visible=false, ZIndex=29}),
    ring    = {},
    sv      = {},
    ringCur = nd("Circle",{Radius=7, NumSides=16, Thickness=2,
                  Color=Color3.fromRGB(0,0,0), Transparency=0.95, Visible=false, ZIndex=32}),
    svCur   = nd("Circle",{Radius=5, NumSides=12, Thickness=2,
                  Color=Color3.fromRGB(0,0,0), Transparency=0.95, Visible=false, ZIndex=32}),
    prev    = nd("Square",{Filled=true,  Color=BG,     Transparency=1,   ZIndex=30, Visible=false}),
    prevBdr = nd("Square",{Filled=false, Color=BORDER, Transparency=0.8, ZIndex=31, Visible=false}),
    hexTxt  = nd("Text",  {Text="#FF5858", Color=TEXT, Size=11,
                  Font=Drawing.Fonts.System, Outline=false, Transparency=1, Visible=false, ZIndex=31}),
    rgbTxt  = nd("Text",  {Text="R 255  G 88  B 88", Color=TEXTDIM, Size=10,
                  Font=Drawing.Fonts.System, Outline=false, Transparency=1, Visible=false, ZIndex=31}),
}
do
    local _r, _g, _b
    for i = 1, 180 do
        _r, _g, _b = hsvToRgb((i-1)/180, 1, 1)
        CP.ring[i] = nd("Circle",{Radius=8, NumSides=32, Thickness=10,
                         Color=Color3.fromRGB(_r,_g,_b), Transparency=0.95, Visible=false, ZIndex=30})
    end
end
do
    for i = 1, 64 do
        CP.sv[i] = nd("Square",{Filled=true, Color=BG, Transparency=1, Visible=false, ZIndex=30})
    end
end

E.setSpBg  = nd("Square",{Filled=true,  Color=Color3.fromRGB(38,72,52),   Transparency=1, ZIndex=3, Visible=true})
E.setSpBdr = nd("Square",{Filled=false, Color=Color3.fromRGB(55,120,80),  Transparency=1, ZIndex=4, Visible=true})
E.setSpTxt = nd("Text",  {Text="SET SPAWN", Color=GREEN, Size=11, Font=Drawing.Fonts.SystemBold, Outline=false, Center=true, Visible=true, ZIndex=5, Transparency=1})
E.clrBg    = nd("Square",{Filled=true,  Color=Color3.fromRGB(65,30,30),   Transparency=1, ZIndex=3, Visible=true})
E.clrBdr   = nd("Square",{Filled=false, Color=Color3.fromRGB(120,55,55),  Transparency=1, ZIndex=4, Visible=true})
E.clrTxt   = nd("Text",  {Text="CLEAR", Color=RED, Size=11, Font=Drawing.Fonts.SystemBold, Outline=false, Center=true, Visible=true, ZIndex=5, Transparency=1})
E.flash    = nd("Square",{Filled=true,  Color=SPAWN, Transparency=0, ZIndex=25, Visible=false})

local guiVisible = true
local notif = {
    alpha=0, timer=0, phase="idle",
    bg  = nd("Square",{Filled=true,  Color=Color3.fromRGB(18,20,32), Transparency=0, ZIndex=50, Visible=false}),
    bdr = nd("Square",{Filled=false, Color=BORDER,                   Transparency=0, ZIndex=51, Visible=false}),
    bar = nd("Square",{Filled=true,  Color=ACCENT,                   Transparency=0, ZIndex=51, Visible=false}),
    txt = nd("Text",  {Text="PRESS RIGHT CTRL TO TOGGLE MENU", Color=TEXT, Size=11,
              Font=Drawing.Fonts.SystemBold, Outline=false, Transparency=0, Visible=false, ZIndex=52}),
}
local notifShown = false
local function showNotif()
    if notifShown then return end
    notifShown = true
    notif.phase="fadein"; notif.timer=0; notif.alpha=0
end

local DBG_X, DBG_Y = nil, nil
local dbgDrag = { active=false, ox=0, oy=0 }
local DBG = {
    bg  = nd("Square",{Filled=true,  Color=BG2,    Transparency=1, ZIndex=14, Visible=false}),
    bdr = nd("Square",{Filled=false, Color=BORDER,  Transparency=1, ZIndex=15, Visible=false}),
    bar = nd("Square",{Filled=true,  Color=ACCENT,  Transparency=1, ZIndex=15, Visible=false}),
    hdr = nd("Text",  {Text="DEBUG", Color=SECLBL, Size=10, Font=Drawing.Fonts.SystemBold, Outline=false, Visible=false, ZIndex=16, Transparency=1}),
    t   = {}
}
for i=1,6 do
    DBG.t[i] = nd("Text",{Text="", Color=TEXT, Size=11, Font=Drawing.Fonts.System, Outline=false, Visible=false, ZIndex=16, Transparency=1})
end

local function mkMarker(r, g, b, lbl)
    local col = Color3.fromRGB(r,g,b)
    return {
        r=r, g=g, b=b, label=lbl,
        s1  = nd("Circle",{Radius=4,NumSides=32,Thickness=2,Color=col,                    Transparency=0,   Visible=false,ZIndex=6}),
        s2  = nd("Circle",{Radius=4,NumSides=32,Thickness=2,Color=col,                    Transparency=0,   Visible=false,ZIndex=6}),
        s3  = nd("Circle",{Radius=4,NumSides=32,Thickness=2,Color=col,                    Transparency=0,   Visible=false,ZIndex=6}),
        o1  = nd("Circle",{Radius=4,NumSides=32,Thickness=4,Color=Color3.fromRGB(8,8,16), Transparency=0,   Visible=false,ZIndex=5}),
        o2  = nd("Circle",{Radius=4,NumSides=32,Thickness=4,Color=Color3.fromRGB(8,8,16), Transparency=0,   Visible=false,ZIndex=5}),
        o3  = nd("Circle",{Radius=4,NumSides=32,Thickness=4,Color=Color3.fromRGB(8,8,16), Transparency=0,   Visible=false,ZIndex=5}),
        dot = nd("Circle",{Radius=3,NumSides=16,Thickness=4,Color=col,                    Transparency=0.9, Visible=false,ZIndex=7}),
        dotO= nd("Circle",{Radius=3,NumSides=16,Thickness=6,Color=Color3.fromRGB(8,8,16), Transparency=0.8, Visible=false,ZIndex=6}),
        arA = nd("Line",{Color=col,Thickness=2,Transparency=0.9,Visible=false,ZIndex=6}),
        arB = nd("Line",{Color=col,Thickness=2,Transparency=0.9,Visible=false,ZIndex=6}),
        arC = nd("Line",{Color=col,Thickness=2,Transparency=0.9,Visible=false,ZIndex=6}),
        arT = nd("Text",{Text=lbl,Color=col,Size=10,Font=Drawing.Fonts.SystemBold,
                 Outline=false,Center=true,Visible=false,ZIndex=7,Transparency=1}),
    }
end

local DM = mkMarker(255, 88,  88,  "Death Position")
local SM = mkMarker(168, 158, 235, "Saved Position")

local function hidePanel()
    local function hS(o) if o then o.Visible=false end end
    hS(E.bg);hS(E.border);hS(E.hdr);hS(E.topbar);hS(E.title)
    hS(E.closeBtn);hS(E.closeBtnH);hS(E.closeX1);hS(E.closeX2)
    for _,s in ipairs(E.sep) do s.Visible=false end
    hS(E.secSys);hS(E.secVis);hS(E.secPos);hS(E.secTp)
    for _,t in ipairs({E.tEnabled,E.tAutoTp,E.tManual,E.tMarkers,E.tDebug}) do
        t.bg.Visible=false;t.bdr.Visible=false;t.lbl.Visible=false
    end
    hS(E.swatchBg);hS(E.swatchBdr)
    hS(E.setSpBg);hS(E.setSpBdr);hS(E.setSpTxt)
    hS(E.clrBg);hS(E.clrBdr);hS(E.clrTxt)
    hS(E.flash)
end

local function renderPanel()
    if not guiVisible then hidePanel() return end
    E.bg.Visible=true; E.border.Visible=true; E.hdr.Visible=true
    E.topbar.Visible=true; E.title.Visible=true
    E.closeBtn.Visible=true; E.closeBtnH.Visible=true
    E.closeX1.Visible=true; E.closeX2.Visible=true
    E.secSys.Visible=true; E.secVis.Visible=true
    for _,s in ipairs(E.sep) do s.Visible=true end
    for _,t in ipairs({E.tEnabled,E.tAutoTp,E.tManual,E.tMarkers,E.tDebug}) do
        t.bg.Visible=true; t.bdr.Visible=true; t.lbl.Visible=true
    end
    E.swatchBg.Visible=true; E.swatchBdr.Visible=true

    local x, y, w = PX, PY, PW
    local showSpawn = cfg.useManualPos
    local PH = showSpawn and 202 or 162

    E.bg.Position=Vector2.new(x,y);     E.bg.Size=Vector2.new(w,PH)
    E.border.Position=Vector2.new(x,y); E.border.Size=Vector2.new(w,PH)
    E.hdr.Position=Vector2.new(x,y);    E.hdr.Size=Vector2.new(w,28)
    E.topbar.Position=Vector2.new(x,y); E.topbar.Size=Vector2.new(w,3)
    E.title.Position=Vector2.new(x+10,y+8)

    local cbw,cbh = 28,28
    local cbx = x+w-cbw
    E.closeBtn.Position =Vector2.new(cbx,y); E.closeBtn.Size =Vector2.new(cbw,cbh)
    E.closeBtnH.Position=Vector2.new(cbx,y); E.closeBtnH.Size=Vector2.new(cbw,cbh)
    local p=5; local cx2,cy2=cbx+cbw/2,y+cbh/2
    E.closeX1.From=Vector2.new(cx2-p,cy2-p); E.closeX1.To=Vector2.new(cx2+p,cy2+p)
    E.closeX2.From=Vector2.new(cx2+p,cy2-p); E.closeX2.To=Vector2.new(cx2-p,cy2+p)

    E.sep[1].Visible=false
    E.sep[2].From=Vector2.new(x+6,y+100); E.sep[2].To=Vector2.new(x+w-6,y+100)
    E.sep[3].Visible=false
    E.sep[4].Visible=false
    E.sep[5].Visible=false

    E.secSys.Position=Vector2.new(x+8,y+32)
    E.secVis.Position=Vector2.new(x+8,y+104)
    E.secPos.Visible=false

    local cbS = 13
    local rows = {
        {tog=E.tEnabled,  val=cfg.enabled,      y=y+46},
        {tog=E.tAutoTp,   val=cfg.autoTeleport,  y=y+64},
        {tog=E.tManual,   val=cfg.useManualPos,  y=y+82},
        {tog=E.tMarkers,  val=cfg.showMarkers,   y=y+118},
        {tog=E.tDebug,    val=cfg.debugMode,     y=y+136},
    }
    for _,row in ipairs(rows) do
        local t   = row.tog
        local cbY = row.y + math.floor((18-cbS)/2)
        t.bg.Position  = Vector2.new(x+10, cbY); t.bg.Size  = Vector2.new(cbS, cbS)
        t.bdr.Position = Vector2.new(x+10, cbY); t.bdr.Size = Vector2.new(cbS, cbS)
        t.lbl.Position = Vector2.new(x+10+cbS+7, row.y+3)
        if row.val then
            t.bg.Color  = ACCENT
            t.bdr.Color = Color3.fromRGB(140,130,240)
        else
            t.bg.Color  = TOGOFF
            t.bdr.Color = BORDER
        end
    end

    local swSize = 13
    local swX = x + w - 26
    local swY = y + 118 + math.floor((18-swSize)/2)
    E.swatchBg.Position  = Vector2.new(swX, swY); E.swatchBg.Size  = Vector2.new(swSize, swSize)
    E.swatchBdr.Position = Vector2.new(swX, swY); E.swatchBdr.Size = Vector2.new(swSize, swSize)
    E.swatchBg.Color = DM_col

    if showSpawn then
        E.secTp.Position = Vector2.new(x+8, y+162)
        E.secTp.Visible  = true
        local bw = w-16
        local hw = math.floor((bw-6)/2)
        local bh = 24
        local lCX = x+8 + math.floor(hw/2)
        local rCX = x+8+hw+6 + math.floor(hw/2)
        local ty  = y+174 + math.floor((bh-11)/2) + 5
        E.setSpBg.Position  = Vector2.new(x+8,      y+174); E.setSpBg.Size  = Vector2.new(hw,bh)
        E.setSpBdr.Position = Vector2.new(x+8,      y+174); E.setSpBdr.Size = Vector2.new(hw,bh)
        E.setSpTxt.Position = Vector2.new(lCX,      ty)
        E.clrBg.Position    = Vector2.new(x+8+hw+6, y+174); E.clrBg.Size   = Vector2.new(hw,bh)
        E.clrBdr.Position   = Vector2.new(x+8+hw+6, y+174); E.clrBdr.Size  = Vector2.new(hw,bh)
        E.clrTxt.Position   = Vector2.new(rCX,      ty)
        E.setSpBg.Visible=true; E.setSpBdr.Visible=true; E.setSpTxt.Visible=true
        E.clrBg.Visible=true;   E.clrBdr.Visible=true;   E.clrTxt.Visible=true
    else
        E.secTp.Visible=false
        E.setSpBg.Visible=false; E.setSpBdr.Visible=false; E.setSpTxt.Visible=false
        E.clrBg.Visible=false;   E.clrBdr.Visible=false;   E.clrTxt.Visible=false
    end
end

local CP_PW    = 220
local CP_PH    = 182
local CP_R_OUT = 70
local CP_R_IN  = 50
local CP_R_MID = 60
local SV_COLS  = 8
local SV_CELL  = 8
local SV_SIZE  = SV_COLS * SV_CELL

local function renderPicker()
    local px = PX + PW + 6
    local py = PY
    local cx = px + CP_PW / 2
    local cy = py + 28 + CP_R_OUT + 4

    CP.bg.Position    = Vector2.new(px, py); CP.bg.Size    = Vector2.new(CP_PW, CP_PH); CP.bg.Visible    = true
    CP.bdr.Position   = Vector2.new(px, py); CP.bdr.Size   = Vector2.new(CP_PW, CP_PH); CP.bdr.Visible   = true
    CP.topbar.Position= Vector2.new(px, py); CP.topbar.Size= Vector2.new(CP_PW, 3);     CP.topbar.Visible= true
    CP.title.Position = Vector2.new(px+10, py+8);                                        CP.title.Visible  = true

    local RING_N = #CP.ring
    for i, dot in ipairs(CP.ring) do
        local angle = ((i-1)/RING_N) * math.pi * 2 - math.pi/2
        dot.Position = Vector2.new(cx + CP_R_MID*math.cos(angle), cy + CP_R_MID*math.sin(angle))
        dot.Visible  = true
    end

    local ra = CP_H * math.pi * 2 - math.pi/2
    CP.ringCur.Position = Vector2.new(cx + CP_R_MID*math.cos(ra), cy + CP_R_MID*math.sin(ra))
    CP.ringCur.Visible  = true

    local svX = math.floor(cx - SV_SIZE/2)
    local svY = math.floor(cy - SV_SIZE/2)
    for i = 1, SV_COLS * SV_COLS do
        local c   = (i-1) % SV_COLS
        local r   = math.floor((i-1) / SV_COLS)
        local s   = c / (SV_COLS-1)
        local v   = 1 - r / (SV_COLS-1)
        local dr, dg, db = hsvToRgb(CP_H, s, v)
        local cell = CP.sv[i]
        cell.Position = Vector2.new(svX + c*SV_CELL, svY + r*SV_CELL)
        cell.Size     = Vector2.new(SV_CELL + 1, SV_CELL + 1)
        cell.Color    = Color3.fromRGB(dr, dg, db)
        cell.Visible  = true
    end

    CP.svCur.Position = Vector2.new(svX + CP_S*(SV_SIZE-SV_CELL) + SV_CELL/2,
                                    svY + (1-CP_V)*(SV_SIZE-SV_CELL) + SV_CELL/2)
    CP.svCur.Visible  = true
    CP.prev.Visible   = false
    CP.prevBdr.Visible= false
    CP.hexTxt.Visible = false
    CP.rgbTxt.Visible = false
end

local function hidePicker()
    CP.bg.Visible=false; CP.bdr.Visible=false; CP.topbar.Visible=false; CP.title.Visible=false
    CP.ringCur.Visible=false; CP.svCur.Visible=false
    CP.prev.Visible=false; CP.prevBdr.Visible=false
    CP.hexTxt.Visible=false; CP.rgbTxt.Visible=false
    for _,d in ipairs(CP.ring) do d.Visible=false end
    for _,d in ipairs(CP.sv)   do d.Visible=false end
end

local function applyPickerColor()
    local r, g, b = hsvToRgb(CP_H, CP_S, CP_V)
    local col = Color3.fromRGB(r, g, b)
    DM_col = col
    SM_col = col
    E.swatchBg.Color = col
    DM.s1.Color=col; DM.s2.Color=col; DM.s3.Color=col
    DM.dot.Color=col; DM.arA.Color=col; DM.arB.Color=col; DM.arC.Color=col; DM.arT.Color=col
    SM.s1.Color=col; SM.s2.Color=col; SM.s3.Color=col
    SM.dot.Color=col; SM.arA.Color=col; SM.arB.Color=col; SM.arC.Color=col; SM.arT.Color=col
end

local function hideM(m)
    m.s1.Visible=false; m.s2.Visible=false; m.s3.Visible=false
    m.o1.Visible=false; m.o2.Visible=false; m.o3.Visible=false
    m.dot.Visible=false; m.dotO.Visible=false
    m.arA.Visible=false; m.arB.Visible=false; m.arC.Visible=false; m.arT.Visible=false
end

local SONAR_SPD = 0.45

local function updateMarker(m, wpos, col)
    if not wpos then hideM(m) return end
    local sp, onScr = WorldToScreen(wpos)
    if not onScr then hideM(m) return end
    m.arA.Visible=false; m.arB.Visible=false; m.arC.Visible=false; m.arT.Visible=false

    local sideSp = WorldToScreen(Vector3.new(wpos.X + 3, wpos.Y, wpos.Z))
    local maxR   = math.max(10, math.min(36, math.abs(sideSp.X - sp.X)))

    local rings    = {m.s1, m.s2, m.s3}
    local outlines = {m.o1, m.o2, m.o3}
    for i = 1, 3 do
        local phase = math.fmod(vt * SONAR_SPD + (i-1)/3, 1.0)
        local r     = 4 + phase * (maxR - 4)
        local t     = (1 - phase) * 0.88
        rings[i].Position    = sp; rings[i].Radius    = r
        rings[i].Color       = col; rings[i].Transparency = t
        rings[i].Visible     = true
        outlines[i].Position = sp; outlines[i].Radius = r
        outlines[i].Transparency = t * 0.65
        outlines[i].Visible  = true
    end

    m.dotO.Position = sp; m.dotO.Visible = true
    m.dot.Position  = sp; m.dot.Color = col; m.dot.Visible = true
end

local function setStatus(txt, dur)
    stText=txt; stAlpha=1; stTimer=dur or 3
end

local function getHRP() local c=LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c=LocalPlayer.Character; return c and c:FindFirstChildOfClass("Humanoid") end

local function setSpawn()
    local hrp=getHRP()
    if not hrp then return end
    customSpawn=hrp.Position; lastCustomSpawn=hrp.Position
end

local function clearSpawn()
    customSpawn=nil
end

task.spawn(function()
    local prevM1        = false
    local prevEnabled   = false
    local prevAutoTp    = false
    local prevManualPos = false
    local prevRCtrl     = false
    local lastChar, lastHum = nil, nil
    local Mouse = LocalPlayer:GetMouse()
    local lastT = tick()

    while true do
        task.wait(1/60)
        local now=tick(); local dt=math.min(now-lastT,0.1); lastT=now
        vt=vt+dt

        local m1=ismouse1pressed(); local mx,my=Mouse.X,Mouse.Y

        if not m1 then CP_DRAG = nil end

        if m1 then
            if CP_DRAG == "ring" and CP_OPEN then
                local pcx=PX+PW+6+CP_PW/2; local pcy=PY+28+CP_R_OUT+4
                CP_H = (math.atan2(my-pcy, mx-pcx)/(math.pi*2) + 0.25 + 1) % 1
                applyPickerColor()
            elseif CP_DRAG == "sv" and CP_OPEN then
                local pcx=PX+PW+6+CP_PW/2; local pcy=PY+28+CP_R_OUT+4
                local svX=math.floor(pcx-SV_SIZE/2); local svY=math.floor(pcy-SV_SIZE/2)
                CP_S = math.max(0,math.min(1,(mx-svX)/SV_SIZE))
                CP_V = math.max(0,math.min(1,1-(my-svY)/SV_SIZE))
                applyPickerColor()
            end

            if not prevM1 then
                if cfg.debugMode and DBG_X and not drag.active then
                    if mx>=DBG_X and mx<=DBG_X+260 and my>=DBG_Y and my<=DBG_Y+20 then
                        dbgDrag.active=true; dbgDrag.ox=mx-DBG_X; dbgDrag.oy=my-DBG_Y
                    end
                end
                local cbx=PX+PW-28
                if mx>=cbx and mx<=PX+PW and my>=PY and my<=PY+28 then
                    guiVisible=false; CP_OPEN=false; showNotif()
                elseif mx>=PX and mx<=cbx and my>=PY and my<=PY+28 then
                    drag.active=true; drag.ox=mx-PX; drag.oy=my-PY
                end
                if not drag.active then
                    local x,y,w=PX,PY,PW
                    local swSize=13; local swX=x+w-26; local swY=y+118+math.floor((18-swSize)/2)
                    if mx>=swX and mx<=swX+swSize and my>=swY and my<=swY+swSize then
                        CP_OPEN = not CP_OPEN
                        if CP_OPEN then
                            local rr=DM_col.R; local gg=DM_col.G; local bb=DM_col.B
                            local mx2=math.max(rr,gg,bb)/255; local mn=math.min(rr,gg,bb)/255
                            CP_V = mx2
                            CP_S = mx2>0 and (mx2-mn)/mx2 or 0
                            local d = mx2 - mn
                            if d < 0.001 then CP_H = 0
                            elseif mx2==rr/255 then CP_H = ((gg-bb)/255/d % 6)/6
                            elseif mx2==gg/255 then CP_H = ((bb-rr)/255/d + 2)/6
                            else                    CP_H = ((rr-gg)/255/d + 4)/6 end
                        end
                    elseif CP_OPEN and CP_DRAG == nil then
                        local pcx = PX+PW+6 + CP_PW/2
                        local pcy = PY + 28 + CP_R_OUT + 4
                        local ddx, ddy = mx-pcx, my-pcy
                        local ddist = math.sqrt(ddx*ddx+ddy*ddy)
                        if ddist >= CP_R_IN and ddist <= CP_R_OUT then
                            CP_H = (math.atan2(ddy,ddx)/(math.pi*2) + 0.25 + 1) % 1
                            CP_DRAG = "ring"
                            applyPickerColor()
                        elseif ddist < CP_R_IN - 6 then
                            local svX = math.floor(pcx - SV_SIZE/2); local svY = math.floor(pcy - SV_SIZE/2)
                            if mx>=svX and mx<=svX+SV_SIZE and my>=svY and my<=svY+SV_SIZE then
                                CP_S = math.max(0,math.min(1,(mx-svX)/SV_SIZE))
                                CP_V = math.max(0,math.min(1,1-(my-svY)/SV_SIZE))
                                CP_DRAG = "sv"
                                applyPickerColor()
                            end
                        elseif ddist > CP_R_OUT then
                            local ppx=PX+PW+6; local ppy=PY
                            if not(mx>=ppx and mx<=ppx+CP_PW and my>=ppy and my<=ppy+CP_PH) then
                                CP_OPEN = false
                            end
                        end
                    end

                    local cbS=13; local cbX=x+10
                    if mx>=cbX and mx<=cbX+cbS then
                        local function cbHit(ry) return my>=ry+math.floor((18-cbS)/2) and my<=ry+math.floor((18-cbS)/2)+cbS end
                        if     cbHit(y+46)  then cfg.enabled=not cfg.enabled
                        elseif cbHit(y+64)  then cfg.autoTeleport=not cfg.autoTeleport
                        elseif cbHit(y+82)  then cfg.useManualPos=not cfg.useManualPos
                        elseif cbHit(y+118) then cfg.showMarkers=not cfg.showMarkers
                        elseif cbHit(y+136) then cfg.debugMode=not cfg.debugMode
                        end
                    end
                    if cfg.useManualPos then
                        local bw=w-16; local hw=math.floor((bw-6)/2)
                        if mx>=x+8      and mx<=x+8+hw   and my>=y+174 and my<=y+198 then setSpawn() end
                        if mx>=x+8+hw+6 and mx<=x+8+bw   and my>=y+174 and my<=y+198 then clearSpawn() end
                    end
                end
            elseif drag.active then
                PX=mx-drag.ox; PY=my-drag.oy
            elseif dbgDrag.active then
                DBG_X=mx-dbgDrag.ox; DBG_Y=my-dbgDrag.oy
            end
        else
            drag.active=false
            dbgDrag.active=false
        end
        prevM1=m1

        local rCtrl = iskeypressed(0xA3)
        if rCtrl and not prevRCtrl then
            guiVisible = not guiVisible
            if guiVisible then
                notif.phase="idle"; notif.alpha=0
                notif.bg.Visible=false; notif.bdr.Visible=false
                notif.bar.Visible=false; notif.txt.Visible=false
            else
                CP_OPEN=false; showNotif()
            end
        end
        prevRCtrl=rCtrl

        if prevEnabled and not cfg.enabled then
            lastAlivePos  = nil
            deathSnapshot = nil
            deathPos      = nil
            wasDead       = false
        end
        prevEnabled = cfg.enabled

        if prevAutoTp and not cfg.autoTeleport then
            deathPos = nil
        end
        prevAutoTp = cfg.autoTeleport

        if prevManualPos and not cfg.useManualPos then
            lastCustomSpawn = customSpawn
            customSpawn = nil
        elseif not prevManualPos and cfg.useManualPos then
            customSpawn = lastCustomSpawn
        end
        prevManualPos = cfg.useManualPos

        if cfg.enabled then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if char and root and hum then
                local health = hum.Health

                if health > DEATH_THRESHOLD and not wasDead then
                    lastAlivePos = root.Position
                end

                if health <= DEATH_THRESHOLD and lastHealth > DEATH_THRESHOLD and not wasDead then
                    wasDead       = true
                    deathSnapshot = lastAlivePos or root.Position
                    deathPos      = deathSnapshot
                end

                if health > DEATH_THRESHOLD and lastHealth <= DEATH_THRESHOLD and wasDead then
                    wasDead = false
                    local dest = (cfg.useManualPos and customSpawn) or (cfg.autoTeleport and deathPos)
                    if dest then
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.Position = dest
                        if not cfg.useManualPos then deathPos = nil end
                    end
                end

                lastHealth = health
            end
        end

        if stTimer>0 then
            stTimer=stTimer-dt
            if stTimer<0.7 then stAlpha=math.max(0,stAlpha-dt*1.5) end
        end

        E.flash.Visible=false

        renderPanel()

        if CP_OPEN then renderPicker() else hidePicker() end

        if cfg.debugMode then
            local dw=260; local lineH=15; local nLines=7
            local dh=22+nLines*lineH+6
            if not DBG_X then
                local vp=Camera.ViewportSize
                DBG_X=vp.X-dw-14; DBG_Y=14
            end
            local dx,dy=DBG_X,DBG_Y
            DBG.bg.Position=Vector2.new(dx,dy);  DBG.bg.Size=Vector2.new(dw,dh);  DBG.bg.Transparency=1;  DBG.bg.Visible=true
            DBG.bdr.Position=Vector2.new(dx,dy); DBG.bdr.Size=Vector2.new(dw,dh); DBG.bdr.Transparency=1; DBG.bdr.Visible=true
            DBG.bar.Position=Vector2.new(dx,dy); DBG.bar.Size=Vector2.new(dw,3);  DBG.bar.Transparency=1; DBG.bar.Visible=true
            DBG.hdr.Position=Vector2.new(dx+8,dy+5); DBG.hdr.Visible=true
            local char2=LocalPlayer.Character
            local root2=char2 and char2:FindFirstChild("HumanoidRootPart")
            local hum2=char2 and char2:FindFirstChildOfClass("Humanoid")
            local hp=hum2 and hum2.Health or 0
            local hpMax=hum2 and hum2.MaxHealth or 100
            local pos2=root2 and root2.Position
            local stateStr=wasDead and "dead" or "alive"
            local lines={
                {t="State:        "..stateStr,                                                                                           c=stateStr=="alive" and GREEN or DEATH},
                {t=string.format("Health:       %.0f / %.0f",hp,hpMax),                                                                 c=hp>20 and TEXT or DEATH},
                {t="PlaceId:      "..tostring(game.PlaceId),                                                                             c=TEXTDIM},
                {t="Position:     "..(pos2 and string.format("%.0f  %.0f  %.0f",pos2.X,pos2.Y,pos2.Z) or "none"),                        c=TEXT},
                {t="Last Death:   "..(deathSnapshot and string.format("%.0f  %.0f  %.0f",deathSnapshot.X,deathSnapshot.Y,deathSnapshot.Z) or "none"), c=deathSnapshot and DEATH or TEXTDIM},
                {t="Custom Spawn: "..(customSpawn and string.format("%.0f  %.0f  %.0f",customSpawn.X,customSpawn.Y,customSpawn.Z) or "none"),         c=customSpawn and SPAWN or TEXTDIM},
            }
            for i,row in ipairs(lines) do
                DBG.t[i].Position=Vector2.new(dx+8,dy+22+(i-1)*lineH)
                DBG.t[i].Text=row.t; DBG.t[i].Color=row.c
                DBG.t[i].Transparency=1; DBG.t[i].Visible=true
            end
        else
            DBG.bg.Visible=false; DBG.bdr.Visible=false; DBG.bar.Visible=false; DBG.hdr.Visible=false
            for _,t in ipairs(DBG.t) do t.Visible=false end
        end

        if notif.phase ~= "idle" then
            notif.timer = notif.timer + dt
            local FADE_IN, HOLD, FADE_OUT = 0.3, 2.5, 0.7
            if notif.phase == "fadein" then
                notif.alpha = math.min(notif.timer / FADE_IN, 1)
                if notif.timer >= FADE_IN then notif.phase="hold"; notif.timer=0 end
            elseif notif.phase == "hold" then
                notif.alpha = 1
                if notif.timer >= HOLD then notif.phase="fadeout"; notif.timer=0 end
            elseif notif.phase == "fadeout" then
                notif.alpha = math.max(1 - notif.timer / FADE_OUT, 0)
                if notif.timer >= FADE_OUT then
                    notif.phase="idle"; notif.alpha=0
                    notif.bg.Visible=false; notif.bdr.Visible=false
                    notif.bar.Visible=false; notif.txt.Visible=false
                end
            end
            if notif.phase ~= "idle" then
                local vp  = Camera.ViewportSize
                local nw, nh = 270, 36
                local nx = vp.X - nw - 16
                local ny = vp.Y - nh - 16
                local a   = notif.alpha
                notif.bg.Position =Vector2.new(nx,ny); notif.bg.Size =Vector2.new(nw,nh)
                notif.bg.Transparency=a*0.96; notif.bg.Visible=true
                notif.bdr.Position=Vector2.new(nx,ny); notif.bdr.Size=Vector2.new(nw,nh)
                notif.bdr.Transparency=a*0.9; notif.bdr.Visible=true
                notif.bar.Position=Vector2.new(nx,ny); notif.bar.Size=Vector2.new(nw,3)
                notif.bar.Transparency=a; notif.bar.Visible=true
                notif.txt.Position=Vector2.new(nx+12, ny+12)
                notif.txt.Transparency=a; notif.txt.Visible=true
            end
        end

        if cfg.showMarkers then
            updateMarker(DM, cfg.autoTeleport and deathPos or nil, DM_col)
            updateMarker(SM, customSpawn, SM_col)
        else
            hideM(DM); hideM(SM)
        end
    end
end)

