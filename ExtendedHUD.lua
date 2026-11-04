-- Extended HUD 1.0.0.3 - MrMorty92
ExtendedHUD = {}

local function pack(...)
    return {n = select("#", ...), ...}
end

local function getAdditionalEntryCount(uiScale)
    if uiScale > 1.25 then return 1
    elseif uiScale > 1.15 then return 3
    elseif uiScale > 1.05 then return 5
    elseif uiScale > 0.95 then return 6
    elseif uiScale > 0.90 then return 7
    elseif uiScale > 0.85 then return 8
    elseif uiScale > 0.75 then return 9
    end
    return 10
end

local function widenHelp(display, saved)
    local line = display.lineBg
    if line == nil or type(line.width) ~= "number" then return end

    -- Scale the native 330-pixel panel to 430 pixels without changing row height.
    local extraWidth = line.width * (100 / 330)
    for _, name in ipairs({"lineBg", "comboBg", "separatorHorizontal"}) do
        local overlay = display[name]
        if overlay ~= nil and type(overlay.width) == "number"
            and type(overlay.height) == "number" and overlay.setDimension ~= nil then
            saved[#saved + 1] = {overlay = overlay, width = overlay.width}
            overlay:setDimension(overlay.width + extraWidth, overlay.height)
        end
    end
    if type(display.helpAnchorOffsetX) == "number" then
        saved.anchor = display.helpAnchorOffsetX
        display.helpAnchorOffsetX = display.helpAnchorOffsetX + extraWidth
    end
end

local function restoreHelpWidth(display, saved)
    for _, entry in ipairs(saved) do
        entry.overlay:setDimension(entry.width, entry.overlay.height)
    end
    if saved.anchor ~= nil then display.helpAnchorOffsetX = saved.anchor end
end

local function restorePendingDraw()
    local pending = ExtendedHUD.pendingDraw
    if pending == nil then return end

    InputHelpDisplay.MAX_NUM_ELEMENTS = pending.normalLimit
    InputHelpDisplay.MAX_NUM_ELEMENTS_HIGH_PRIORITY = pending.highLimit
    restoreHelpWidth(pending.display, pending.savedWidth)
    ExtendedHUD.pendingDraw = nil
end

function ExtendedHUD.drawInputHelp(display, superFunc, ...)
    -- A previous native draw error must not accumulate extra rows or width.
    restorePendingDraw()
    if not ExtendedHUD.active then return superFunc(display, ...) end
    if not display:getVisible() then return superFunc(display, ...) end

    local normalLimit = InputHelpDisplay.MAX_NUM_ELEMENTS
    local highLimit = InputHelpDisplay.MAX_NUM_ELEMENTS_HIGH_PRIORITY
    if type(normalLimit) ~= "number" or type(highLimit) ~= "number" then
        return superFunc(display, ...)
    end
    local uiScale = tonumber(display.uiScale) or 1
    if display.uiScale == nil and g_gameSettings ~= nil then
        uiScale = tonumber(g_gameSettings.uiScale) or uiScale
    end
    local additionalEntries = getAdditionalEntryCount(uiScale)
    local savedWidth = {}
    ExtendedHUD.pendingDraw = {
        display = display,
        normalLimit = normalLimit,
        highLimit = highLimit,
        savedWidth = savedWidth
    }
    InputHelpDisplay.MAX_NUM_ELEMENTS = normalLimit + additionalEntries
    InputHelpDisplay.MAX_NUM_ELEMENTS_HIGH_PRIORITY = highLimit + additionalEntries
    widenHelp(display, savedWidth)
    -- Call directly so native Lua errors and their original stack reach the log.
    -- On success restore immediately; on error the next update/draw/unload restores.
    local result = pack(superFunc(display, ...))
    restorePendingDraw()
    return unpack(result, 1, result.n)
end

function ExtendedHUD:loadMap()
    restorePendingDraw()
    self.active = true
end

function ExtendedHUD:update(dt)
    restorePendingDraw()
end

function ExtendedHUD:deleteMap()
    self.active = false
    restorePendingDraw()
end

-- Keep existing key bindings and the native action callback. No extra F1 binding.
if InputHelpDisplay ~= nil and InputHelpDisplay.draw ~= nil then
    InputHelpDisplay.draw = Utils.overwrittenFunction(InputHelpDisplay.draw, ExtendedHUD.drawInputHelp)
end
addModEventListener(ExtendedHUD)
