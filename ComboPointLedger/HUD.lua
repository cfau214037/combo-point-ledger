local addonName, ledger = ...

local MAX_POINTS = 5
local TEXTURES = "Interface\\AddOns\\" .. addonName .. "\\Textures\\"
local DEFAULT_Y = -105
local RED_SHADE = CreateColor(0.44, 0.015, 0.035, 1)
local RED_LIGHT = CreateColor(0.86, 0.10, 0.13, 1)
local GOLD_SHADE = CreateColor(0.55, 0.34, 0.15, 1)
local GOLD_LIGHT = CreateColor(0.88, 0.71, 0.46, 1)
local db, editing, moving

ledger.styles = { "Dots", "Ticks", "Number" }
ledger.minScale, ledger.maxScale = 0.6, 2

local hud = CreateFrame("Frame", nil, UIParent)
hud:SetFrameStrata("HIGH")
hud:SetMovable(true)
hud:SetClampedToScreen(true)
hud:RegisterForDrag("LeftButton")
hud:Hide()

local art = CreateFrame("Frame", nil, hud)
art:SetSize(86, 30)
art:SetPoint("CENTER")

local editBackground = hud:CreateTexture(nil, "BACKGROUND")
editBackground:SetAllPoints()
editBackground:SetColorTexture(0.06, 0.07, 0.09, 0.85)
editBackground:Hide()

local marks = CreateFrame("Frame", nil, art)
marks:SetAllPoints()

local function texture(parent, layer)
    local region = parent:CreateTexture(nil, layer)
    region:SetPoint("CENTER")
    return region
end

local function counter(parent, r, g, b)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 25, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetTextColor(r, g, b)
    return text
end

local number = CreateFrame("Frame", nil, art)
number:SetAllPoints()
local count = counter(number, 1, 0.96, 0.84)
local fullNumber = CreateFrame("Frame", nil, number)
fullNumber:SetAllPoints()
fullNumber:SetFrameLevel(number:GetFrameLevel() + 1)
local goldCount = counter(fullNumber, 1, 0.72, 0.24)

local dots = {}
for i = 1, MAX_POINTS do
    local slot = CreateFrame("Frame", nil, marks)
    slot:SetSize(16, 16)
    slot:SetPoint("CENTER", (i - 3) * 17, 0)

    local backing = texture(slot, "BACKGROUND")
    backing:SetVertexColor(0.04, 0.025, 0.02, 0.96)
    local empty = texture(slot, "BORDER")
    empty:SetVertexColor(0.48, 0.33, 0.17, 0.9)

    local full = CreateFrame("Frame", nil, slot)
    full:SetAllPoints()
    local gold = texture(full, "ARTWORK")
    gold:SetVertexColor(0.99, 0.79, 0.46)

    local active = CreateFrame("Frame", nil, slot)
    active:SetAllPoints()
    active:SetFrameLevel(full:GetFrameLevel() + 1)
    local rim = texture(active, "BORDER")
    local fill = texture(active, "ARTWORK")

    -- The engine evaluates these thresholds even when the count is secret.
    local curve = C_CurveUtil.CreateCurve()
    curve:AddPoint(0, 0)
    if i > 1 then curve:AddPoint(i - 1, 0) end
    curve:AddPoint(i, 1)
    if i < MAX_POINTS then curve:AddPoint(MAX_POINTS, 1) end

    dots[i] = {
        backing = backing, empty = empty, rim = rim, fill = fill,
        gold = gold, active = active, full = full, curve = curve,
    }
end

local function render()
    if not hud:IsShown() then return end
    local points
    if editing then
        points = MAX_POINTS
    else
        points = GetComboPoints("player", "target")
    end

    local fullAlpha = dots[MAX_POINTS].curve:Evaluate(points)
    if db.style == "Number" then
        count:SetFormattedText("%d", points)
        goldCount:SetFormattedText("%d", points)
        fullNumber:SetAlpha(fullAlpha)
    else
        for _, dot in ipairs(dots) do
            dot.active:SetAlpha(dot.curve:Evaluate(points))
            dot.full:SetAlpha(fullAlpha)
        end
    end
end

local function position()
    hud:ClearAllPoints()
    hud:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local function stopMoving()
    if not moving then return end
    moving = false
    hud:StopMovingOrSizing()
    local x, y = hud:GetCenter()
    local rootX, rootY = UIParent:GetCenter()
    db.x, db.y = x - rootX, y - rootY
    position()
end

hud:SetScript("OnDragStart", function()
    if editing then
        moving = true
        hud:StartMoving()
    end
end)
hud:SetScript("OnDragStop", stopMoving)

local events = CreateFrame("Frame")
local function refreshVisibility(inCombat)
    local visible = editing or (db.show and inCombat) or false
    hud:SetShown(visible)
    events:UnregisterAllEvents()
    if db.show and not editing then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        if inCombat then
            events:RegisterEvent("PLAYER_TARGET_CHANGED")
            if C_EventUtils.IsEventValid("UNIT_COMBO_POINTS") then
                events:RegisterEvent("UNIT_COMBO_POINTS")
            end
            events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
            events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        end
    end
    render()
end

events:SetScript("OnEvent", function(_, event, unit, powerType)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        refreshVisibility(event == "PLAYER_REGEN_DISABLED")
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        refreshVisibility(InCombatLockdown())
        return
    end
    if event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" then
        if powerType ~= "COMBO_POINTS" then return end
    end
    render()
end)

function ledger.IsHUDShown()
    return db.show
end

function ledger.SetHUDShown(shown)
    db.show = shown
    refreshVisibility(InCombatLockdown())
    ledger.RefreshControls()
end

function ledger.GetStyle()
    return db.style
end

function ledger.SetStyle(style)
    db.style = style
    number:SetShown(style == "Number")
    marks:SetShown(style ~= "Number")
    for _, dot in ipairs(dots) do
        if style == "Dots" then
            dot.backing:SetTexture(TEXTURES .. "Dot")
            dot.backing:SetSize(24, 24)
            dot.empty:SetTexture(TEXTURES .. "Ring")
            dot.empty:SetSize(14, 14)
            dot.rim:SetTexture(TEXTURES .. "Ring")
            dot.rim:SetSize(16, 16)
            dot.fill:SetTexture(TEXTURES .. "Dot")
            dot.fill:SetSize(14, 14)
            dot.gold:SetTexture(TEXTURES .. "Ring")
            dot.gold:SetSize(17, 17)
        elseif style == "Ticks" then
            dot.backing:SetTexture(TEXTURES .. "Tick")
            dot.backing:SetSize(14, 10)
            dot.empty:SetTexture(TEXTURES .. "TickRing")
            dot.empty:SetSize(12, 8)
            dot.rim:SetTexture(TEXTURES .. "Tick")
            dot.rim:SetSize(12, 8)
            dot.fill:SetTexture(TEXTURES .. "Tick")
            dot.fill:SetSize(9, 5)
            dot.gold:SetTexture(TEXTURES .. "Tick")
            dot.gold:SetSize(13, 9)
        end
        if style ~= "Number" then
            dot.rim:SetGradient("VERTICAL", GOLD_SHADE, GOLD_LIGHT)
            dot.fill:SetGradient("VERTICAL", RED_SHADE, RED_LIGHT)
        end
    end
    ledger.SetScale(db.scale)
    render()
end

function ledger.GetScale()
    return db.scale
end

function ledger.SetScale(scale)
    db.scale = scale
    art:SetScale(scale)
    local width = db.style == "Number" and 40 or 88
    hud:SetSize(width * scale, 32 * scale)
end

function ledger.ResetPosition()
    stopMoving()
    db.x, db.y = 0, DEFAULT_Y
    position()
end

function ledger.SetEditing(enabled)
    if editing == enabled then return end
    stopMoving()
    editing = enabled
    hud:EnableMouse(enabled)
    editBackground:SetShown(enabled)
    refreshVisibility(InCombatLockdown())
end

local function numberOr(value, default)
    if type(value) == "number" and value > -math.huge and value < math.huge then
        return value
    end
    return default
end

function ledger.InitializeHUD(saved)
    db = saved
    db.show = db.show ~= false
    if db.style ~= "Dots" and db.style ~= "Ticks" and db.style ~= "Number" then
        db.style = "Dots"
    end
    db.scale = math.max(ledger.minScale, math.min(ledger.maxScale, numberOr(db.scale, 1)))
    db.x, db.y = numberOr(db.x, 0), numberOr(db.y, DEFAULT_Y)
    position()
    ledger.SetStyle(db.style)
    ledger.SetEditing(false)
end
