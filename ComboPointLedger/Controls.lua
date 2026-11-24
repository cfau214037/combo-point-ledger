local _, ledger = ...
local TITLE = "Combo Point Ledger"
local ICON = 132292 -- Sinister Strike
local category, showCheckbox, editor

local function button(parent, label, width, onClick)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 24)
    control:SetText(label)
    control:SetScript("OnClick", onClick)
    return control
end

local function openEditor()
    HideUIPanel(SettingsPanel)
    editor:Show()
end

local function createEditor()
    editor = CreateFrame("Frame", "ComboPointLedgerEditor", UIParent, "BackdropTemplate")
    editor:SetPoint("TOP", UIParent, "TOP", 0, -110)
    editor:SetSize(290, 152)
    editor:SetFrameStrata("DIALOG")
    editor:SetClampedToScreen(true)
    editor:EnableMouse(true)
    editor:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editor:SetBackdropColor(0.07, 0.07, 0.09, 0.96)
    editor:Hide()

    local title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Edit Combo Point HUD")
    local hint = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -8)
    hint:SetText("Drag the highlighted HUD to move it.")

    local sizeText = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeText:SetPoint("TOP", hint, "BOTTOM", 0, -14)
    local slider = CreateFrame("Slider", "ComboPointLedgerSizeSlider", editor, "OptionsSliderTemplate")
    slider:SetSize(218, 16)
    slider:SetPoint("TOP", sizeText, "BOTTOM", 0, -4)
    slider:SetMinMaxValues(ledger.minScale, ledger.maxScale)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged", function(_, scale)
        ledger.SetScale(scale)
        sizeText:SetFormattedText("Size  %.0f%%", scale * 100)
    end)

    button(editor, "Reset position", 116, ledger.ResetPosition):SetPoint("BOTTOMLEFT", 16, 14)
    button(editor, "Lock HUD", 106, function() editor:Hide() end):SetPoint("BOTTOMRIGHT", -16, 14)
    editor:SetScript("OnShow", function()
        local scale = ledger.GetScale()
        slider:SetValue(scale)
        sizeText:SetFormattedText("Size  %.0f%%", scale * 100)
        ledger.SetEditing(true)
    end)
    editor:SetScript("OnHide", function() ledger.SetEditing(false) end)
    table.insert(UISpecialFrames, editor:GetName())
end

function ledger.OpenOptions()
    Settings.OpenToCategory(category:GetID())
end

function ledger.RefreshControls()
    showCheckbox:SetChecked(ledger.IsHUDShown())
end

local function createSettings()
    local panel = CreateFrame("Frame")
    panel:Hide()
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(TITLE)

    showCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    showCheckbox:SetSize(24, 24)
    showCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    showCheckbox.Text:SetText("Show HUD")
    showCheckbox:SetScript("OnClick", function(self)
        ledger.SetHUDShown(self:GetChecked() and true or false)
    end)
    panel:SetScript("OnShow", ledger.RefreshControls)

    local styleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", showCheckbox, "BOTTOMLEFT", 4, -16)
    styleLabel:SetText("Display Style")
    local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    dropdown:SetSize(150, 26)
    dropdown:SetPoint("LEFT", styleLabel, "RIGHT", 14, 0)
    dropdown:SetupMenu(function(_, root)
        for _, style in ipairs(ledger.styles) do
            root:CreateRadio(style, function(value) return ledger.GetStyle() == value end, ledger.SetStyle, style)
        end
    end)

    button(panel, "Edit HUD", 110, openEditor):SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", 0, -20)
    category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
end

function ledger.BuildMinimapMenu(menu)
    menu:CreateCheckbox("Show HUD", ledger.IsHUDShown, function()
        ledger.SetHUDShown(not ledger.IsHUDShown())
    end)
    local label = editor:IsShown() and "Lock HUD" or "Edit HUD"
    menu:CreateButton(label, function()
        if editor:IsShown() then editor:Hide() else openEditor() end
    end)
    menu:CreateDivider()
    menu:CreateButton("Settings", ledger.OpenOptions)
end

local function createLauncher(db)
    local launcher = CreateFrame("Button", nil, Minimap)
    launcher:SetSize(32, 32)
    launcher:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    launcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    launcher:RegisterForDrag("LeftButton")

    local icon = launcher:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON)
    local rim = launcher:CreateTexture(nil, "OVERLAY")
    rim:SetSize(53, 53)
    rim:SetPoint("TOPLEFT", launcher, "CENTER", -17, 15)
    rim:SetTexture(136430)
    launcher:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function position()
        local angle = math.rad(db.minimapAngle or 210)
        launcher:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(angle) * (Minimap:GetWidth() / 2 + 5),
            math.sin(angle) * (Minimap:GetHeight() / 2 + 5))
    end
    position()

    launcher:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local centerX, centerY = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            db.minimapAngle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
            position()
        end)
    end)
    local function stopDrag(self)
        self:SetScript("OnUpdate", nil)
    end
    launcher:SetScript("OnDragStop", stopDrag)
    launcher:SetScript("OnHide", stopDrag)
    launcher:SetScript("OnClick", function(self, mouse)
        GameTooltip:Hide()
        if mouse == "RightButton" then
            MenuUtil.CreateContextMenu(self, function(_, menu)
                menu:CreateTitle(TITLE)
                ledger.BuildMinimapMenu(menu)
            end)
        else
            ledger.OpenOptions()
        end
    end)
    launcher:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(TITLE)
        GameTooltip:AddLine("Left-click for settings. Right-click for HUD controls.", 1, 1, 1)
        GameTooltip:Show()
    end)
    launcher:SetScript("OnLeave", GameTooltip_Hide)
    return launcher
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local _, class = UnitClass("player")
    if class ~= "ROGUE" then return end

    if type(ComboPointLedgerDB) ~= "table" then ComboPointLedgerDB = {} end
    ledger.InitializeHUD(ComboPointLedgerDB)
    createEditor()
    createSettings()
    ledger.button = createLauncher(ComboPointLedgerDB)
    ComboPointLedger = ledger
    SLASH_COMBOPOINTLEDGER1 = "/cpl"
    SlashCmdList.COMBOPOINTLEDGER = ledger.OpenOptions
end)
