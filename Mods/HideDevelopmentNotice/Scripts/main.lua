-- Hide Development Notice
-- Dismiss only the verified English development notice through its normal action.
-- Any missing capability or identity mismatch leaves the original UI visible.
local DEBUG = false
local PREFIX = "[Hide Development Notice] "
local MENU_CLASS = "BlueprintGeneratedClass /Game/CPP_BP/MenuPawn.MenuPawn_C"
local MENU_START = "/Game/CPP_BP/MenuPawn.MenuPawn_C:ReceiveBeginPlay"
local MENU_INSTANCE_PREFIX = "MenuPawn_C /Game/NotStronghold/Maps/MainMenu.MainMenu:PersistentLevel."
local MAIN_MENU_CLASS = "WidgetBlueprintGeneratedClass /Game/UI/Main_Menu/mainMenu_widget.mainMenu_widget_C"
local NOTICE_CLASS = "WidgetBlueprintGeneratedClass /Game/UI/Elements/EarlyAccessWidget.EarlyAccessWidget_C"
local FINISH_PATH = "/Game/UI/Elements/EarlyAccessWidget.EarlyAccessWidget_C:DoFinish"
local TITLE = "This game is still in development"
local BODY = [[Manor Lords is an indie passion project and even though it's been 7 years, the game still needs more time to be fully complete.

Certain game or platform features aren't available yet, and you will probably encounter bugs. Feel free to drop feedback on our Discord channel where I try to respond every day.

Thank you for understanding as I continue work on the game,

Greg, Manor Lords lead dev]]
local logged = {}
local hooked = false

local function log(message) print(PREFIX .. message .. "\n") end
local function logOnce(key, message)
    if logged[key] then return end
    logged[key] = true
    log(message)
end
local function valid(object) return object ~= nil and object:IsValid() end
local function classIs(object, expected)
    return valid(object) and object:GetClass():GetFullName() == expected
end
local function sameObject(left, right)
    return valid(left) and valid(right) and left:GetAddress() == right:GetAddress()
end
local function normalize(text)
    -- Ignore only formatting whitespace, never words, punctuation, or case.
    return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
local function hasProperties(object, names)
    local found = {}
    object:GetClass():ForEachProperty(function(property)
        -- Unreal FName property lookup is case-insensitive; display casing can
        -- depend on which package first interned a name in this process.
        found[property:GetFName():ToString():lower()] = true
    end)
    for _, name in ipairs(names) do
        if not found[name:lower()] then
            if DEBUG then log("Missing reflected property: " .. name) end
            return false
        end
    end
    return true
end
local function childIs(child, expectedClass, notice)
    if not classIs(child, expectedClass) then return false end
    local tree = child:GetOuter()
    return classIs(tree, "Class /Script/UMG.WidgetTree") and sameObject(tree:GetOuter(), notice)
end

local function identify(menu)
    if not classIs(menu, MENU_CLASS) then return nil, "menu class changed" end
    if menu:GetFullName():sub(1, #MENU_INSTANCE_PREFIX) ~= MENU_INSTANCE_PREFIX then
        return nil, "outside the expected main-menu level"
    end
    if not hasProperties(menu, {"EarlyAccessDialog", "mainMenu"}) then
        return nil, "menu references changed"
    end
    local notice, mainMenu = menu.EarlyAccessDialog, menu.mainMenu
    if not classIs(notice, NOTICE_CLASS) then return nil, "no exact development-notice widget" end
    if not classIs(mainMenu, MAIN_MENU_CLASS) then return nil, "main-menu widget changed" end
    if not hasProperties(notice, {"Header", "nda_txt_1", "Button"}) then
        return nil, "notice properties changed"
    end
    local header, body, button = notice.Header, notice.nda_txt_1, notice.Button
    if not childIs(header, "Class /Script/UMG.TextBlock", notice)
        or not childIs(body, "Class /Script/UMG.TextBlock", notice)
        or not childIs(button, "Class /Script/UMG.Button", notice) then
        return nil, "notice child types or ownership changed"
    end
    if normalize(header:GetText():ToString()) ~= TITLE or normalize(body:GetText():ToString()) ~= normalize(BODY) then
        return nil, "notice text differs from the verified English message"
    end
    if not sameObject(notice:GetOwningPlayer(), mainMenu:GetOwningPlayer()) then
        return nil, "notice and menu have different owning players"
    end
    if not notice:IsInViewport() or not sameObject(menu:FindFocusedWindow(), notice) then
        return nil, "notice is not the active menu window"
    end
    local finish = StaticFindObject(FINISH_PATH)
    if not valid(finish) or finish:GetFullName() ~= "Function " .. FINISH_PATH
        or not sameObject(finish:GetOuter(), notice:GetClass()) then
        return nil, "normal dismiss function changed"
    end
    local fields = 0
    finish:ForEachProperty(function() fields = fields + 1 end)
    if fields ~= 0 then return nil, "normal dismiss signature changed" end
    return notice
end

local function onMenuStarted(menu)
    -- Validation and the normal dismiss call run together in the menu's game-thread event.
    -- No timers, retries, broad widget searches, global dialog hooks, or Tick processing.
    local ok, notice, reason = pcall(identify, menu)
    if not ok then
        logOnce("inspection-error", "Notice left visible: identity inspection unavailable.")
        if DEBUG then log(tostring(notice)) end
        return
    end
    if not notice then
        logOnce(reason, "Notice left visible: " .. reason .. ".")
        return
    end
    if DEBUG then
        log("Matched exact notice class, complete text, children, menu ownership, focus, and dismiss signature: " .. notice:GetFullName())
    end
    local dismissed, errorMessage = pcall(function() notice:DoFinish() end)
    if not dismissed then
        -- Never attempt another method after an action error.
        logOnce("dismiss-error", "Normal dismiss action failed; no fallback attempted.")
        if DEBUG then log(tostring(errorMessage)) end
        return
    end
    local checked, remaining = pcall(function() return valid(notice) and notice:IsInViewport() end)
    if checked and not remaining then
        logOnce("dismissed", "Development notice dismissed through its normal Continue action.")
    else
        logOnce("dismiss-unconfirmed", "Normal dismiss action returned; removal could not be confirmed.")
    end
end

local function installForMenu(menu)
    if hooked then return true end
    if not classIs(menu, MENU_CLASS) then
        if DEBUG then log("Ignored unrelated menu class: " .. menu:GetClass():GetFullName()) end
        return
    end
    local start = StaticFindObject(MENU_START)
    if not valid(start) or start:GetFullName() ~= "Function " .. MENU_START then
        logOnce("startup-unavailable", "Notice left visible: exact menu startup function unavailable.")
        return
    end
    -- /Game Blueprint hooks are post-hooks in the verified UE4SS build.
    RegisterHook(MENU_START, function(context)
        local ok, errorMessage = pcall(function() onMenuStarted(context:get()) end)
        if not ok then
            logOnce("callback-error", "Notice left visible: menu callback unavailable.")
            if DEBUG then log(tostring(errorMessage)) end
        end
        -- No returned override: preserve the vanilla event's result.
    end)
    hooked = true
    if DEBUG then log("Observing only " .. MENU_START) end
    return true -- The hook now handles this exact startup event; remove the allocation watcher.
end

local registered, registrationError = pcall(function()
    NotifyOnNewObject("/Script/ManorLords.MenuPawn", function(menu)
        local ok, removeWatcher = pcall(installForMenu, menu)
        if not ok then
            logOnce("hook-error", "Notice left visible: exact startup hook unavailable.")
            if DEBUG then log(tostring(removeWatcher)) end
            return
        end
        return removeWatcher
    end)
end)
if not registered then
    logOnce("registration-error", "Notice left visible: menu creation notifications unavailable.")
    if DEBUG then log(tostring(registrationError)) end
elseif DEBUG then
    log("Loaded; awaiting the exact main-menu startup event.")
end
