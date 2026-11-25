local addonName, ledger = ...

local MAX_POINTS = 5
local TEXTURES = "Interface\\AddOns\\" .. addonName .. "\\Textures\\"
local DEFAULT_Y = -105
local NAMEPLATE_GAP = 4
local AMBER_LIGHT = CreateColor(1, 0.70, 0.14, 1)
local FULL_AMBER_LIGHT = CreateColor(1, 0.90, 0.46, 1)
local db, editing, moving, inCombat

ledger.styles = { "Dots", "Ticks", "Number" }
ledger.placements = { "Screen HUD", "Target Nameplate" }
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
local count = counter(number, AMBER_LIGHT:GetRGB())
local fullNumber = CreateFrame("Frame", nil, number)
fullNumber:SetAllPoints()
fullNumber:SetFrameLevel(number:GetFrameLevel() + 1)
local fullCount = counter(fullNumber, FULL_AMBER_LIGHT:GetRGB())

local dots = {}
for i = 1, MAX_POINTS do
    local slot = CreateFrame("Frame", nil, marks)
    slot:SetSize(16, 16)
    slot:SetPoint("CENTER", (i - 3) * 17, 0)

    local backing = texture(slot, "BACKGROUND")
    backing:SetVertexColor(0.025, 0.02, 0.016, 0.96)
    local empty = texture(slot, "BORDER")
    empty:SetVertexColor(0.29, 0.21, 0.115, 0.9)

    local active = CreateFrame("Frame", nil, slot)
    active:SetAllPoints()
    local rim = texture(active, "BACKGROUND")
    rim:SetVertexColor(0.14, 0.085, 0.04)
    local fill = texture(active, "ARTWORK")
    fill:SetVertexColor(0.88, 0.77, 0.65)

    local full = CreateFrame("Frame", nil, slot)
    full:SetAllPoints()
    full:SetFrameLevel(active:GetFrameLevel() + 1)
    local fullFill = texture(full, "ARTWORK")

    -- The engine evaluates these thresholds even when the count is secret.
    local curve = C_CurveUtil.CreateCurve()
    curve:AddPoint(0, 0)
    if i > 1 then curve:AddPoint(i - 1, 0) end
    curve:AddPoint(i, 1)
    if i < MAX_POINTS then curve:AddPoint(MAX_POINTS, 1) end

    dots[i] = {
        backing = backing, empty = empty, rim = rim, fill = fill,
        fullFill = fullFill, active = active, full = full, curve = curve,
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

    if editing or inCombat then
        art:SetAlpha(1)
    else
        -- Render restricted counts through the curve without comparing them in Lua.
        art:SetAlpha(dots[1].curve:Evaluate(points))
    end

    local fullAlpha = dots[MAX_POINTS].curve:Evaluate(points)
    if db.style == "Number" then
        count:SetFormattedText("%d", points)
        fullCount:SetFormattedText("%d", points)
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

local function updatePlacement()
    if not editing and not db.show then
        hud:Hide()
        return
    end

    if editing or not ledger.IsNameplatePlacement() then
        hud:SetParent(UIParent)
        hud:SetClampedToScreen(true)
        if not moving then position() end
        hud:Show()
    else
        local plate = UnitCanAttack("player", "target") and C_NamePlate.GetNamePlateForUnit("target")
        if not plate or plate:IsForbidden() then
            hud:Hide()
            hud:ClearAllPoints()
            hud:SetParent(UIParent)
            return
        end

        local unitFrame = plate.UnitFrame
        local health = unitFrame and not unitFrame:IsForbidden() and unitFrame.HealthBarsContainer
        local anchor = health and not health:IsForbidden() and health or plate
        hud:SetParent(plate)
        hud:SetClampedToScreen(false)
        hud:ClearAllPoints()
        hud:SetPoint("BOTTOM", anchor, "TOP", 0, NAMEPLATE_GAP)
        hud:Show()
    end
    render()
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
    if editing and not ledger.IsNameplatePlacement() then
        moving = true
        hud:StartMoving()
    end
end)
hud:SetScript("OnDragStop", stopMoving)

local events = CreateFrame("Frame")
local removalPending
local function refreshVisibility()
    inCombat = InCombatLockdown()
    events:UnregisterAllEvents()
    if db.show and not editing then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterEvent("PLAYER_TARGET_CHANGED")
        if ledger.IsNameplatePlacement() then
            events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
            events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        end
        if C_EventUtils.IsEventValid("UNIT_COMBO_POINTS") then
            events:RegisterEvent("UNIT_COMBO_POINTS")
        end
        events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
        events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    end
    updatePlacement()
end

events:SetScript("OnEvent", function(_, event, unit, powerType)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        inCombat = event == "PLAYER_REGEN_DISABLED"
    elseif event == "PLAYER_ENTERING_WORLD" then
        inCombat = InCombatLockdown()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- Let the client finish removing or recycling the plate before looking it up again.
        if not removalPending then
            removalPending = true
            C_Timer.After(0, function()
                removalPending = false
                updatePlacement()
            end)
        end
        return
    elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" then
        if powerType ~= "COMBO_POINTS" then return end
    end
    if event == "PLAYER_TARGET_CHANGED" or event == "NAME_PLATE_UNIT_ADDED" or event == "PLAYER_ENTERING_WORLD" then
        updatePlacement()
    else
        render()
    end
end)

function ledger.IsHUDShown()
    return db.show
end

function ledger.SetHUDShown(shown)
    db.show = shown
    refreshVisibility()
    ledger.RefreshControls()
end

function ledger.IsNameplatePlacement()
    return db.placement == "Target Nameplate"
end

function ledger.GetPlacement()
    return db.placement
end

function ledger.SetPlacement(placement)
    stopMoving()
    db.placement = placement
    hud:EnableMouse(editing and not ledger.IsNameplatePlacement())
    refreshVisibility()
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
            dot.backing:SetSize(16, 16)
            dot.empty:SetTexture(TEXTURES .. "Ring")
            dot.empty:SetSize(14, 14)
            dot.rim:SetTexture(TEXTURES .. "Dot")
            dot.rim:SetSize(16, 16)
            dot.fill:SetTexture(TEXTURES .. "AmberDot")
            dot.fill:SetSize(12, 12)
            dot.fullFill:SetTexture(TEXTURES .. "AmberDot")
            dot.fullFill:SetSize(12, 12)
        elseif style == "Ticks" then
            dot.backing:SetTexture(TEXTURES .. "Tick")
            dot.backing:SetSize(14, 10)
            dot.empty:SetTexture(TEXTURES .. "TickRing")
            dot.empty:SetSize(11, 7)
            dot.rim:SetTexture(TEXTURES .. "Tick")
            dot.rim:SetSize(14, 10)
            dot.fill:SetTexture(TEXTURES .. "AmberTick")
            dot.fill:SetSize(9, 5)
            dot.fullFill:SetTexture(TEXTURES .. "AmberTick")
            dot.fullFill:SetSize(9, 5)
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
    hud:EnableMouse(enabled and not ledger.IsNameplatePlacement())
    editBackground:SetShown(enabled)
    refreshVisibility()
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
    if not ledger.IsNameplatePlacement() then
        db.placement = "Screen HUD"
    end
    if db.style ~= "Dots" and db.style ~= "Ticks" and db.style ~= "Number" then
        db.style = "Dots"
    end
    db.scale = math.max(ledger.minScale, math.min(ledger.maxScale, numberOr(db.scale, 1)))
    db.x, db.y = numberOr(db.x, 0), numberOr(db.y, DEFAULT_Y)
    position()
    ledger.SetStyle(db.style)
    ledger.SetEditing(false)
end
