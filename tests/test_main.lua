-- Run from the repository root: lua tests/test_main.lua
-- Optional first argument supplies a different real mod-source path.
-- Lua 5.2+; no game, UE4SS, network, or third-party Lua package is required.
local SOURCE = arg[1] or "Mods/HideDevelopmentNotice/Scripts/main.lua"
local MENU_CLASS = "BlueprintGeneratedClass /Game/CPP_BP/MenuPawn.MenuPawn_C"
local MENU_EVENT = "/Game/CPP_BP/MenuPawn.MenuPawn_C:ReceiveBeginPlay"
local MENU_INSTANCE = "MenuPawn_C /Game/NotStronghold/Maps/MainMenu.MainMenu:PersistentLevel.MenuPawn_C_0"
local MAIN_CLASS = "WidgetBlueprintGeneratedClass /Game/UI/Main_Menu/mainMenu_widget.mainMenu_widget_C"
local NOTICE_CLASS = "WidgetBlueprintGeneratedClass /Game/UI/Elements/EarlyAccessWidget.EarlyAccessWidget_C"
local FINISH = "/Game/UI/Elements/EarlyAccessWidget.EarlyAccessWidget_C:DoFinish"
local TITLE = "This game is still in development"
local BODY = [[Manor Lords is an indie passion project and even though it's been 7 years, the game still needs more time to be fully complete.

Certain game or platform features aren't available yet, and you will probably encounter bugs. Feel free to drop feedback on our Discord channel where I try to respond every day.

Thank you for understanding as I continue work on the game,

Greg, Manor Lords lead dev]]

local passed, failed = 0, 0
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, callback)
    local ok, reason = pcall(callback)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(reason)) end
end

local function fixture(options)
    options = options or {}
    local f = { writes = 0, actions = {}, forbidden = {}, logs = {}, hookCount = 0, watcherCount = 0, removed = 0, data = {} }
    local nextAddress = 100
    local methods = {}
    local function object(spec)
        nextAddress = nextAddress + 1
        spec.address, spec.valid = nextAddress, spec.valid ~= false
        local proxy = setmetatable({}, {
            __index = function(self, key)
                local data = f.data[self]
                if data.missingMethod == key then return nil end
                if data.props and data.props[key] ~= nil then return data.props[key] end
                return methods[key]
            end,
            __newindex = function(_, key)
                f.writes = f.writes + 1
                error("The mod wrote UObject property " .. tostring(key))
            end,
        })
        f.data[proxy] = spec
        return proxy
    end
    function methods:IsValid() return f.data[self].valid end
    function methods:GetClass() return f.data[self].class end
    function methods:GetFullName() return f.data[self].name end
    function methods:GetAddress() return f.data[self].address end
    function methods:GetOuter() return f.data[self].outer end
    function methods:ForEachProperty(callback)
        local data = f.data[self]
        if data.throwProperties then error("Reflection unavailable") end
        for _, name in ipairs(data.fields or {}) do
            callback({ GetFName = function() return { ToString = function() return name end } end })
        end
    end
    function methods:GetText()
        local data = f.data[self]
        if data.throwText then error("Text unavailable") end
        return { ToString = function() return data.text end }
    end
    function methods:GetOwningPlayer() return f.data[self].player end
    function methods:IsInViewport()
        local data = f.data[self]
        if data.throwViewport then error("Viewport state unavailable") end
        return data.viewport
    end
    function methods:FindFocusedWindow() return f.focus end
    function methods:DoFinish()
        f.actions[#f.actions + 1] = self
        if options.finishThrows then error("Injected normal-action failure") end
        if not options.finishKeepsVisible then f.data[self].viewport = false end
        if options.viewportThrowsAfterFinish then f.data[self].throwViewport = true end
    end
    local function forbid(name)
        return function()
            f.forbidden[#f.forbidden + 1] = name
            error("Unexpected action outside normal completion: " .. name)
        end
    end
    for _, name in ipairs({ "RemoveFromParent", "SetVisibility", "SetRenderOpacity", "SetIsEnabled", "SetPropertyValue", "ProcessEvent", "ConsoleCommand", "SaveGame" }) do
        methods[name] = forbid(name)
    end
    local function class(name, fields) return object({ name = name, fields = fields or {} }) end
    f.class, f.object = class, object
    f.menuClass = class(MENU_CLASS, { "EarlyAccessDialog", "mainMenu" })
    f.noticeClass = class(NOTICE_CLASS, { "Header", "nda_txt_1", "Button" })
    f.mainClass = class(MAIN_CLASS)
    f.player = object({ name = "PlayerController /Transient.Player" })
    f.notice = object({ name = "EarlyAccessWidget_C /Transient.Notice", class = f.noticeClass, player = f.player, viewport = true, props = {} })
    f.tree = object({ name = "WidgetTree /Transient.Notice.WidgetTree", class = class("Class /Script/UMG.WidgetTree"), outer = f.notice })
    f.header = object({ name = "TextBlock /Transient.Notice.Header", class = class("Class /Script/UMG.TextBlock"), outer = f.tree, text = TITLE })
    f.body = object({ name = "TextBlock /Transient.Notice.Body", class = class("Class /Script/UMG.TextBlock"), outer = f.tree, text = BODY })
    f.button = object({ name = "Button /Transient.Notice.Button", class = class("Class /Script/UMG.Button"), outer = f.tree })
    f.data[f.notice].props = { Header = f.header, nda_txt_1 = f.body, Button = f.button }
    f.mainMenu = object({ name = "mainMenu_widget_C /Transient.MainMenu", class = f.mainClass, player = f.player, viewport = true })
    f.menu = object({ name = MENU_INSTANCE, class = f.menuClass, props = { EarlyAccessDialog = f.notice, mainMenu = f.mainMenu } })
    f.focus = f.notice
    f.start = object({ name = "Function " .. MENU_EVENT, outer = f.menuClass })
    f.finish = object({ name = "Function " .. FINISH, outer = f.noticeClass, fields = {} })
    f.objects = { [MENU_EVENT] = f.start, [FINISH] = f.finish }
    local standardLua = {
        assert = assert, error = error, ipairs = ipairs, pairs = pairs, next = next,
        pcall = pcall, select = select, tonumber = tonumber, tostring = tostring,
        type = type, string = string, table = table, math = math,
    }
    local env = setmetatable({
        print = function(message) f.logs[#f.logs + 1] = message end,
        StaticFindObject = function(path) return f.objects[path] end,
        RegisterHook = function(path, callback)
            f.hookCount = f.hookCount + 1
            equal(path, MENU_EVENT, "hook scope")
            if options.hookThrows then error("Hook registration rejected") end
            f.hook = callback
            return 101, 102
        end,
        NotifyOnNewObject = function(path, callback)
            f.watcherCount = f.watcherCount + 1
            equal(path, "/Script/ManorLords.MenuPawn", "allocation scope")
            if options.watcherThrows then error("Allocation notification rejected") end
            f.watcher = callback
        end,
    }, { __index = standardLua })
    for _, name in ipairs({ "ExecuteWithDelay", "LoopAsync", "ExecuteConsoleCommand", "RegisterLoadMapPostHook", "RegisterBeginPlayPostHook" }) do
        env[name] = forbid(name)
    end
    if options.missingWatcherApi then env.NotifyOnNewObject = false end
    if options.missingHookApi then env.RegisterHook = false end
    if options.missingFindApi then env.StaticFindObject = false end
    f.env = env
    function f.load()
        local chunk = assert(loadfile(SOURCE, "t", env))
        chunk()
    end
    function f.allocate(menu)
        if not f.watcher then return nil end
        local remove = f.watcher(menu or f.menu)
        if remove == true then f.watcher = nil; f.removed = f.removed + 1 end
        return remove
    end
    function f.fire(menu, contextThrows)
        assert(f.hook, "Expected exact startup hook")
        local result = f.hook({ get = function()
            if contextThrows then error("Context unavailable") end
            return menu or f.menu
        end })
        equal(#f.forbidden, 0, "alternate actions or broad callbacks")
        equal(f.writes, 0, "UObject writes")
        return result
    end
    function f.startMod() f.load(); equal(f.allocate(), true, "successful watcher removal"); equal(f.fire(), nil, "no vanilla result override") end
    function f.assertNoAction()
        equal(#f.actions, 0, "normal completion calls")
        equal(#f.forbidden, 0, "alternate actions or broad callbacks")
        equal(f.writes, 0, "UObject writes")
        equal(f.data[f.notice].viewport, true, "notice remains visible")
    end
    return f
end

test("validated target calls only its normal action once", function()
    local f = fixture(); f.startMod()
    equal(#f.actions, 1); equal(f.actions[1], f.notice); equal(f.writes, 0)
    equal(f.data[f.notice].viewport, false); equal(f.hookCount, 1); equal(f.removed, 1)
    equal(f.watcher, nil, "allocation watcher no longer active")
    equal(f.allocate(), nil); equal(f.hookCount, 1)
    f.fire(); equal(#f.actions, 1, "repeated event does not redismiss detached notice")
end)
test("whitespace formatting and mixed-case reflected FNames are accepted", function()
    local f = fixture()
    f.data[f.menuClass].fields = { "EARLYACCESSDIALOG", "MainMenu" }
    f.data[f.noticeClass].fields = { "header", "NDA_TXT_1", "BUTTON" }
    f.data[f.header].text = "  This\tgame is still\r\nin development  "
    f.data[f.body].text = BODY:gsub("\n", "\r\n\t")
    f.startMod(); equal(#f.actions, 1); equal(f.writes, 0)
end)
test("different Lua wrappers for the same owning player remain valid", function()
    local f = fixture()
    local playerWrapper = f.object({ name = "PlayerController /Transient.Player" })
    f.data[playerWrapper].address = f.data[f.player].address
    f.data[f.mainMenu].player = playerWrapper
    f.startMod(); equal(#f.actions, 1); equal(f.writes, 0)
end)
test("mod load only registers exact creation watcher", function()
    local f = fixture(); f.load()
    equal(f.watcherCount, 1); equal(f.hookCount, 0); f.assertNoAction()
end)
test("unrelated allocation leaves watcher active and never registers hook", function()
    local f = fixture(); f.load()
    local other = f.object({ class = f.class("BlueprintGeneratedClass /Game/Other.MenuPawn_C"), name = MENU_INSTANCE })
    equal(f.allocate(other), nil); equal(f.hookCount, 0); equal(f.removed, 0); f.assertNoAction()
    equal(f.allocate(), true); equal(f.hookCount, 1)
end)

local negativeCases = {
    { "unrelated menu event context", function(f) f.data[f.menu].class = f.class("BlueprintGeneratedClass /Game/Other.Other_C") end },
    { "same generic notice layout on EULA class", function(f) f.data[f.noticeClass].name = "WidgetBlueprintGeneratedClass /Game/UI/EULA.EULA_C" end },
    { "NDA widget class with identical notice text", function(f) f.data[f.noticeClass].name = "WidgetBlueprintGeneratedClass /Game/UI/Elements/NDA_widget.NDA_widget_C" end },
    { "notice class name near match", function(f) f.data[f.noticeClass].name = NOTICE_CLASS .. "_Changed" end },
    { "menu outside exact MainMenu level", function(f) f.data[f.menu].name = MENU_INSTANCE:gsub("Maps/MainMenu", "Maps/InGame") end },
    { "menu reference property missing", function(f) f.data[f.menuClass].fields = { "mainMenu" } end },
    { "main menu reference property missing", function(f) f.data[f.menuClass].fields = { "EarlyAccessDialog" } end },
    { "main-menu widget class mismatch", function(f) f.data[f.mainClass].name = "WidgetBlueprintGeneratedClass /Game/UI/PauseMenu.PauseMenu_C" end },
    { "main-menu widget invalid", function(f) f.data[f.mainMenu].valid = false end },
    { "main-menu widget missing", function(f) f.data[f.menu].props.mainMenu = nil end },
    { "notice missing", function(f) f.data[f.menu].props.EarlyAccessDialog = nil end },
    { "notice invalid", function(f) f.data[f.notice].valid = false end },
    { "notice title wording changed", function(f) f.data[f.header].text = TITLE .. "!" end },
    { "notice title case changed", function(f) f.data[f.header].text = TITLE:upper() end },
    { "notice title new localization", function(f) f.data[f.header].text = "Ce jeu est toujours en developpement" end },
    { "notice body new localization", function(f) f.data[f.body].text = "Este juego sigue en desarrollo" end },
    { "notice body one word changed", function(f) f.data[f.body].text = BODY:gsub("indie", "studio", 1) end },
    { "notice body truncated", function(f) f.data[f.body].text = BODY:sub(1, 150) end },
    { "notice body extra agreement", function(f) f.data[f.body].text = BODY .. "\nI agree to new terms." end },
    { "header reflected property missing", function(f) f.data[f.noticeClass].fields = { "nda_txt_1", "Button" } end },
    { "body reflected property missing", function(f) f.data[f.noticeClass].fields = { "Header", "Button" } end },
    { "button reflected property missing", function(f) f.data[f.noticeClass].fields = { "Header", "nda_txt_1" } end },
    { "header child missing", function(f) f.data[f.notice].props.Header = nil end },
    { "body child missing", function(f) f.data[f.notice].props.nda_txt_1 = nil end },
    { "button child missing", function(f) f.data[f.notice].props.Button = nil end },
    { "header child wrong class", function(f) f.data[f.header].class = f.class("Class /Script/UMG.RichTextBlock") end },
    { "body child wrong class", function(f) f.data[f.body].class = f.class("Class /Script/UMG.RichTextBlock") end },
    { "button child wrong class", function(f) f.data[f.button].class = f.class("Class /Script/UMG.CheckBox") end },
    { "child belongs to another notice", function(f) f.data[f.tree].outer = f.mainMenu end },
    { "body alone belongs to another notice", function(f) f.data[f.body].outer = f.object({ class = f.class("Class /Script/UMG.WidgetTree"), outer = f.mainMenu }) end },
    { "button alone belongs to another notice", function(f) f.data[f.button].outer = f.object({ class = f.class("Class /Script/UMG.WidgetTree"), outer = f.mainMenu }) end },
    { "child outer is not WidgetTree", function(f) f.data[f.tree].class = f.class("Class /Script/UMG.CanvasPanel") end },
    { "header child invalid", function(f) f.data[f.header].valid = false end },
    { "body child invalid", function(f) f.data[f.body].valid = false end },
    { "button child invalid", function(f) f.data[f.button].valid = false end },
    { "child ownership unavailable", function(f) f.data[f.header].outer = nil end },
    { "owning player mismatch", function(f) f.data[f.notice].player = f.object({ name = "PlayerController /Transient.Other" }) end },
    { "owning player invalid", function(f) f.data[f.player].valid = false end },
    { "owning player missing", function(f) f.data[f.notice].player = nil end },
    { "focus belongs to another dialog", function(f) f.focus = f.mainMenu end },
    { "focused window invalid", function(f) f.focus = f.object({ valid = false }) end },
    { "normal function missing", function(f) f.objects[FINISH] = nil end },
    { "normal function invalid", function(f) f.data[f.finish].valid = false end },
    { "normal function exact path changed", function(f) f.data[f.finish].name = "Function " .. FINISH .. "_Changed" end },
    { "normal function owner class mismatch", function(f) f.data[f.finish].outer = f.mainClass end },
    { "normal function arguments changed", function(f) f.data[f.finish].fields = { "AcceptAgreement" } end },
    { "normal function return signature changed", function(f) f.data[f.finish].fields = { "ReturnValue" } end },
    { "normal function method unavailable", function(f) f.data[f.notice].missingMethod = "DoFinish" end },
    { "reflection throws", function(f) f.data[f.noticeClass].throwProperties = true end },
    { "text retrieval throws", function(f) f.data[f.body].throwText = true end },
    { "viewport query throws", function(f) f.data[f.notice].throwViewport = true end },
}
for _, case in ipairs(negativeCases) do
    test("reject " .. case[1] .. " with zero actions or writes", function()
        local f = fixture(); f.load(); f.allocate(); case[2](f)
        equal(f.fire(), nil); f.assertNoAction()
    end)
end
test("notice already outside viewport is never completed again", function()
    local f = fixture(); f.load(); f.allocate(); f.data[f.notice].viewport = false
    f.fire(); equal(#f.actions, 0); equal(f.writes, 0)
end)
test("invalid event context leaves UI unchanged", function()
    local f = fixture(); f.load(); f.allocate(); f.data[f.menu].valid = false
    f.fire(); f.assertNoAction()
end)
test("event context extraction failure leaves UI unchanged", function()
    local f = fixture(); f.load(); f.allocate(); equal(f.fire(nil, true), nil); f.assertNoAction()
end)
test("repeated mismatch logs once and never acts", function()
    local f = fixture(); f.load(); f.allocate(); f.data[f.header].text = "Changed"
    f.fire(); f.fire(); f.fire(); equal(#f.logs, 1); f.assertNoAction()
end)
for _, case in ipairs({
    { "missing startup function", function(f) f.objects[MENU_EVENT] = nil end },
    { "invalid startup function", function(f) f.data[f.start].valid = false end },
    { "changed startup function path", function(f) f.data[f.start].name = "Function /Game/Other:ReceiveBeginPlay" end },
}) do
    test(case[1] .. " keeps allocation watcher active", function()
        local f = fixture(); case[2](f); f.load(); equal(f.allocate(), nil)
        equal(f.hookCount, 0); equal(f.removed, 0); assert(f.watcher); f.assertNoAction()
    end)
end
for _, option in ipairs({ "hookThrows", "missingHookApi", "missingFindApi" }) do
    test(option .. " leaves UI unchanged and never removes watcher", function()
        local f = fixture({ [option] = true }); f.load(); equal(f.allocate(), nil)
        equal(f.removed, 0); assert(f.watcher); f.assertNoAction()
    end)
end
for _, option in ipairs({ "watcherThrows", "missingWatcherApi" }) do
    test(option .. " is contained at mod load", function()
        local f = fixture({ [option] = true }); f.load()
        equal(f.hookCount, 0); equal(f.removed, 0); equal(#f.logs, 1); f.assertNoAction()
    end)
end
test("hook registration failure can recover without duplicate active hooks", function()
    local options = { hookThrows = true }; local f = fixture(options); f.load()
    equal(f.allocate(), nil); equal(f.removed, 0)
    options.hookThrows = false; equal(f.allocate(), true); equal(f.removed, 1)
    f.fire(); equal(#f.actions, 1); equal(f.writes, 0)
end)
test("normal action failure has no fallback property writes", function()
    local f = fixture({ finishThrows = true }); f.startMod()
    equal(#f.actions, 1); equal(f.writes, 0); equal(f.data[f.notice].viewport, true)
    equal(#f.logs, 1); assert(f.logs[1]:find("no fallback attempted", 1, true))
end)
test("action returning without removal is reported without fallback", function()
    local f = fixture({ finishKeepsVisible = true }); f.startMod()
    equal(#f.actions, 1); equal(f.writes, 0); equal(f.data[f.notice].viewport, true)
    equal(#f.logs, 1); assert(f.logs[1]:find("could not be confirmed", 1, true))
end)
test("post-action inspection failure never triggers another action", function()
    local f = fixture({ viewportThrowsAfterFinish = true }); f.startMod()
    equal(#f.actions, 1); equal(f.writes, 0); equal(#f.logs, 1)
    assert(f.logs[1]:find("could not be confirmed", 1, true))
end)

print(string.format("\n%d passed; %d failed", passed, failed))
assert(failed == 0, "Regression suite failed")
