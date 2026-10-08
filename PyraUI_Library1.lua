local _clockConns = {}

local function trackConn(conn)
    _clockConns[#_clockConns+1] = conn
    return conn
end

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local random = Random.new()
local player = Players.LocalPlayer
local cam = Workspace.CurrentCamera

task.spawn(function()
    local announcer = player.PlayerGui:WaitForChild("announcer")
    local function lockText(val)
        if val.Name ~= "Winner" then return end
        val.Text = "discord.gg/PYRA"
        val.Changed:Connect(function(prop)
            if prop == "Text" then val.Text = "discord.gg/PYRA" end
        end)
    end
    announcer.ChildAdded:Connect(lockText)
    local existing = announcer:FindFirstChild("Winner")
    if existing then lockText(existing) end
end)
local _pingHistory = {}

local _crypter = nil
local _clientHash = "ClockAP"
pcall(function()
    _crypter = loadstring(game:HttpGet("https://raw.githubusercontent.com/Egor-Skriptunoff/pure_lua_SHA/master/sha2.lua"))()
    local clientId = game:GetService("RbxAnalyticsService"):GetClientId()
    _clientHash = _crypter.sha3_384(clientId, "sha3-256"):sub(1, 16)
end)
local function _hashName(suffix)
    return _clientHash .. (suffix or "")
end


-- =============================================================================
-- Parry subsystem. The ONLY parry method is the one in working.txt (below),
-- verbatim and self-contained. Nothing else fires a parry. The Combat tab
-- wires into AP_start / AP_stop / AP_setActive; spam uses AP_fire.
-- =============================================================================

-- Handles the Combat tab wires into (assigned inside the verbatim block).
local AP_start, AP_stop, AP_setActive, AP_fire

-- Spam state (UI-driven).
local spamDetectionEnabled = false
local spamThresholdOffset  = 7      -- -10..10 (higher = fires faster)
local manualSpamEnabled = false
local manualSpamBind    = Enum.KeyCode.E
local manualSpamHold    = true
local spamming          = false
local _mobileSpamGui    = nil

-- Cosmetic UI state. Shown in the Combat tab but no longer alters the parry
-- method (the working.txt engine is the single source of truth for firing).
local autoParryEnabled = false
local parryType        = "Custom"
local parryMethod      = "Remote"
local parryAccuracy    = 50
local randomAccuracy   = false
local parryAnimationEnabled = true
local accelLift = 70
local forceTargetParry = false
local forcedTargetPlayer = nil
local accuracyRangeMin = 40
local accuracyRangeMax = 100

-- ---------------------------------------------------------------------------
-- working.txt parry engine, VERBATIM (GUI button omitted). This block owns the
-- remote capture/tokenize/fire path and the impact-prediction Auto Parry loop.
-- ---------------------------------------------------------------------------
do
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer

local _cloneref = cloneref or function(x) return x end
local RunService        = _cloneref(game:GetService("RunService"))
local ReplicatedStorage = _cloneref(game:GetService("ReplicatedStorage"))
local Workspace         = _cloneref(game:GetService("Workspace"))

local hook       = hookfunction or detour_function or (replaceclosure and function(o,n) return replaceclosure(o,n) end)
local cclosure   = newcclosure or function(f) return f end
local set_readonly = setreadonly or (make_writeable and function(t,v)
    if v then make_writeable(t) else make_readonly(t) end
end)

local VirtualInputManager
do
    local ok, vim = pcall(function() return cloneref(game:GetService("VirtualInputManager")) end)
    if ok and vim then VirtualInputManager = vim end
end

local Alive     = Workspace:WaitForChild("Alive", 9e9)
local is_mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local function send_virtual_key(keyCode)
    if not VirtualInputManager then return end
    pcall(function() VirtualInputManager:SendKeyEvent(true, keyCode, false, game) end)
    task.delay(0.015, function()
        if not VirtualInputManager then return end
        pcall(function() VirtualInputManager:SendKeyEvent(false, keyCode, false, game) end)
    end)
end

local function send_virtual_mouse(x, y)
    if not VirtualInputManager then return end
    pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0) end)
    task.delay(0.015, function()
        if not VirtualInputManager then return end
        pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
    end)
end

local ReplionData = nil
task.spawn(function()
    pcall(function()
        local packages = ReplicatedStorage:WaitForChild("Packages", 10)
        local replion  = packages and packages:FindFirstChild("Replion")
        if replion then
            ReplionData = require(replion).Client:WaitReplion("Data")
        end
    end)
end)

local function replion_get(path)
    if not ReplionData then return nil end
    local ok, value = pcall(function() return ReplionData:Get(path) end)
    if ok then return value end
    return nil
end

local noob_parry_enabled = nil
local function is_noob_parry_enabled()
    if noob_parry_enabled ~= nil then return noob_parry_enabled end
    noob_parry_enabled = false
    pcall(function()
        local ServerInfo  = require(ReplicatedStorage.ServerInfo)
        local UniverseIds = require(ReplicatedStorage.Shared.UniverseIds)
        local special = ServerInfo.isDungeonsMatchServer()
            or game.PlaceId == UniverseIds.RankedMatches.PlaceId
            or game.PlaceId == UniverseIds.RankedMatchesNoAbility.PlaceId
            or ServerInfo.isMedalServer()
            or ServerInfo.isClanWarServer()
            or ServerInfo.isTournamentMatchServer()
        if not special then
            local Utils = require(ReplicatedStorage.Common.Utils)
            noob_parry_enabled = Utils.FFlag.GetInstantFFlag("NoobParryEnabled", true) == true
        end
    end)
    return noob_parry_enabled
end

local PARRY_HOLD_STEPS = { 1.5, 1.25, 1, 0.75, 0.625 }
local function get_parry_hold_value()
    local timesParried = tonumber(replion_get("timesParried"))
    if not timesParried then return 0.5 end
    local value = PARRY_HOLD_STEPS[timesParried + 1] or 0.5
    if ReplionData and is_noob_parry_enabled() then
        local kills = tonumber(replion_get("TotalStats.Kills")) or 0
        if kills < 20 then value = value * kills / 20 end
    end
    return value
end

local MOUSE_BINDS = { MouseButton1 = 0, MouseButton2 = 1, MouseButton3 = 2 }
local block_bind_cache = { at = 0, key = Enum.KeyCode.F, mouse = nil }

local function get_block_bind()
    local now = os.clock()
    if now - block_bind_cache.at < 2 then
        return block_bind_cache.key, block_bind_cache.mouse
    end
    block_bind_cache.at = now

    local binds = replion_get({ "Settings", "Keybinds", "Block", "PC" })
    local chosen
    if type(binds) == "table" then
        for _, name in ipairs({ binds.Bind1, binds.Bind2, binds.Bind3 }) do
            if type(name) == "string" and not MOUSE_BINDS[name] then
                chosen = name
                break
            end
        end
        chosen = chosen or binds.Bind1 or binds.Bind2 or binds.Bind3
    end

    if type(chosen) == "string" and MOUSE_BINDS[chosen] then
        block_bind_cache.key, block_bind_cache.mouse = nil, MOUSE_BINDS[chosen]
    else
        local ok, keyCode = pcall(function() return Enum.KeyCode[chosen or "F"] end)
        block_bind_cache.key   = (ok and keyCode) or Enum.KeyCode.F
        block_bind_cache.mouse = nil
    end
    return block_bind_cache.key, block_bind_cache.mouse
end

local function press_block_bind()
    local keyCode, mouseButton = get_block_bind()
    if mouseButton and VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, mouseButton, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(0, 0, mouseButton, false, game, 0)
        end)
        return
    end
    send_virtual_key(keyCode or Enum.KeyCode.F)
end

local _token
local function _get_token_fn()
    if _token then return _token end
    if type(getgc) ~= "function" then return nil end
    for _, Function in getgc(true) do
        if type(Function) == 'function' and debug.info(Function, 's'):find('PRY', 1, true) then
            for _, value in debug.getupvalues(Function) do
                if type(value) == 'function' then
                    _token = value
                    return _token
                end
            end
        end
    end
    return nil
end
_get_token_fn()

local function _tokenize(_remote_uid)
    local fn = _get_token_fn()
    if not fn then return "" end
    local time = tostring(math.floor(Workspace:GetServerTimeNow() * 100))
    local key  = _token(_remote_uid, 'TIME')
    local chars = table.create(#time)
    for i = 1, #time do
        chars[i] = string.char(bit32.bxor(
            (string.byte(time, i) + i) % 256,
            string.byte(key, (i - 1) % #key + 1)
        ))
    end
    return table.concat(chars)
end

local _captured = nil

local function _is_valid(args)
    return #args == 8
        and type(args[2]) == "string"
        and type(args[3]) == "string"
        and type(args[4]) == "number"
        and typeof(args[5]) == "CFrame"
        and type(args[6]) == "table"
        and type(args[7]) == "table"
        and type(args[8]) == "boolean"
end

local function _record_capture(remote, args)
    _captured = { remote = remote, args = args }
end

local function _hook(remote)
    if not set_readonly then return end
    local raw_mt = getrawmetatable(remote)
    if not raw_mt then return end
    local _old = raw_mt.__index
    local _index_wrappers = setmetatable({}, { __mode = "k" })
    set_readonly(raw_mt, false)
    raw_mt.__index = cclosure(function(self, key)
        if (key == 'FireServer' and self:IsA('RemoteEvent')) or
           (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
            local wrapper = _index_wrappers[self]
            if not wrapper then
                local original = _old(self, key)
                wrapper = function(_, ...)
                    if select("#", ...) == 8 then
                        local a = {...}
                        if _is_valid(a) then _record_capture(self, a) end
                    end
                    return original(_, ...)
                end
                _index_wrappers[self] = wrapper
            end
            return wrapper
        end
        return _old(self, key)
    end)
    set_readonly(raw_mt, true)
end

do
    local anyRemote = ReplicatedStorage:FindFirstChildWhichIsA("RemoteEvent", true)
        or ReplicatedStorage:FindFirstChildWhichIsA("RemoteFunction", true)
    if anyRemote then _hook(anyRemote) end
end

if hook then
    pcall(function()
        local orig
        orig = hook(Instance.new("RemoteEvent").FireServer, cclosure(function(self, ...)
            if select("#", ...) == 8 then
                local a = {...}
                if _is_valid(a) then _record_capture(self, a) end
            end
            return orig(self, ...)
        end))
    end)
end

local function is_remote_valid()
    return _captured ~= nil
        and _captured.remote ~= nil
        and _captured.remote.Parent ~= nil
        and _captured.remote:IsDescendantOf(game)
        and _captured.args ~= nil
end

local function get_aim_target(camera)
    if forceTargetParry and forcedTargetPlayer then
        local char = forcedTargetPlayer.Character
        local pp = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
        if pp then
            local ok, pt = pcall(camera.WorldToScreenPoint, camera, pp.Position)
            if ok and pt then return { pt.X, pt.Y } end
        end
    end
    if is_mobile then
        local vp = camera.ViewportSize
        return { vp.X / 2, vp.Y / 2 }
    end
    local ok, mouse = pcall(UserInputService.GetMouseLocation, UserInputService)
    if ok and mouse then return { mouse.X, mouse.Y } end
    return { 0, 0 }
end

local _packet_cache = { EventDataAt = 0, EventData = {}, CurveAt = 0, CurveCFrame = nil }

local function visualGetCachedEventData(camera)
    local now = os.clock()
    if (now - _packet_cache.EventDataAt) >= 0.05 then
        local event_data = {}
        for _, entity in pairs(Alive:GetChildren()) do
            local primary = entity.PrimaryPart
            if primary then
                local ok, pt = pcall(camera.WorldToScreenPoint, camera, primary.Position)
                if ok then event_data[entity.Name] = pt end
            end
        end
        _packet_cache.EventData   = event_data
        _packet_cache.EventDataAt = now
    end
    return _packet_cache.EventData
end

local function visualGetCachedCurveCFrame()
    local now = os.clock()
    if not _packet_cache.CurveCFrame or (now - _packet_cache.CurveAt) >= (1 / 120) then
        local cam = workspace.CurrentCamera
        _packet_cache.CurveCFrame = cam and cam.CFrame or CFrame.new()
        _packet_cache.CurveAt     = now
    end
    return _packet_cache.CurveCFrame
end

local _prySignal = nil
local function getPrySignal()
    if _prySignal then return _prySignal end
    local controllers = ReplicatedStorage:FindFirstChild("Controllers")
    local packages    = ReplicatedStorage:FindFirstChild("Packages")
    local signalModule = packages and packages:FindFirstChild("Signal")
    if not controllers or not signalModule then return nil end

    local okSignal, Signal = pcall(require, signalModule)
    if not okSignal or type(Signal) ~= "table" or type(Signal.new) ~= "function" then return nil end

    for _, ctrl in ipairs(controllers:GetChildren()) do
        if ctrl.Name:find("SwordsController", 1, true) == 1 then
            local pry = ctrl:FindFirstChild("PRY")
            if pry and pry:IsA("ModuleScript") then
                local ok, fn = pcall(require, pry)
                if ok and type(fn) == "function" then
                    _prySignal = Signal.new()
                    _prySignal:Connect(fn)
                    return _prySignal
                end
            end
        end
    end
    return nil
end

local function fire_pry_module(curve_cframe, event_data, aim_target)
    local signal = getPrySignal()
    if not signal or not pcall(signal.Fire, signal, get_parry_hold_value(),
        curve_cframe, event_data, aim_target, false) then
        return false
    end
    return true
end

local BladeBallParry = {}

function BladeBallParry.is_ready()
    return is_remote_valid() or getPrySignal() ~= nil
end

function BladeBallParry.fire_remote(count, custom_cframe)
    local camera = workspace.CurrentCamera
    if not LocalPlayer.Character or not camera then return false end

    count = math.clamp(math.floor(tonumber(count) or 1), 1, 8)
    local event_data   = visualGetCachedEventData(camera)
    local curve_cframe = custom_cframe or visualGetCachedCurveCFrame()
    local aim_target   = get_aim_target(camera)

    if not is_remote_valid() then
        if not fire_pry_module(curve_cframe, event_data, aim_target) then
            press_block_bind()
        end
        return true
    end

    local token = _tokenize(_captured.args[2])
    if token == "" then
        return fire_pry_module(curve_cframe, event_data, aim_target)
    end

    local packet = {
        _captured.args[1], _captured.args[2], token,
        get_parry_hold_value(), curve_cframe, event_data, aim_target, false
    }

    local remote = _captured.remote
    if remote:IsA("RemoteEvent") then
        for _ = 1, count do pcall(remote.FireServer, remote, unpack(packet)) end
    elseif remote:IsA("RemoteFunction") then
        task.spawn(function() pcall(remote.InvokeServer, remote, unpack(packet)) end)
    else
        return false
    end
    return true
end

function BladeBallParry.fire_pry(custom_cframe)
    local camera = workspace.CurrentCamera
    if not camera then return false end
    return fire_pry_module(
        custom_cframe or visualGetCachedCurveCFrame(),
        visualGetCachedEventData(camera),
        get_aim_target(camera)
    )
end

function BladeBallParry.fire_keypress()
    if not LocalPlayer.Character then return false end
    press_block_bind()
    return true
end

function BladeBallParry.fire_mouse()
    if not LocalPlayer.Character then return false end
    local mp = UserInputService:GetMouseLocation()
    send_virtual_mouse(mp.X, mp.Y)
    return true
end

function BladeBallParry.parry(mode, count, custom_cframe)
    if mode == "Keypress" then return BladeBallParry.fire_keypress() end
    if mode == "Mouse"    then return BladeBallParry.fire_mouse()   end
    if mode == "PRY"      then return BladeBallParry.fire_pry(custom_cframe) end
    return BladeBallParry.fire_remote(count, custom_cframe)
end

local ballPrevVelocity = {}
local autoParryActive  = false
local autoParryLoop    = nil

-- Ported from clock_ap_clean: decision-layer state for the full pipeline.
local lastParriedBalls = {}     -- balls already parried this flight (no re-parry)
local ballLead         = {}     -- per-ball random lead jitter
local _pingHistory     = {}     -- rolling ping samples for smoothing
local lastDualParryAt  = 0
local apRandom         = Random.new()
local DUAL_LOCK_WINDOW = 0.22

local function cleanupBallTracking(ball)
    lastParriedBalls[ball] = nil
    ballLead[ball] = nil
    ballPrevVelocity[ball] = nil
end

local function getSpeedBonus(speed)
    local RAMP_START = 1200
    local RAMP_RATE  = 0.00004
    local MAX_BONUS  = 0.08
    return math.min(math.max(0, speed - RAMP_START) * RAMP_RATE, MAX_BONUS)
end

local _grabTrack, _grabSword, _grabAnimator
local function getParryAnimation()
    local char = LocalPlayer.Character
    if not char then return nil end
    local sword = char:GetAttribute("CurrentlyEquippedSword")
    if not sword then return nil end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local api = shared and shared:FindFirstChild("SwordAPI")
    local coll = api and api:FindFirstChild("Collection")
    if not coll then return nil end
    local def = coll:FindFirstChild("Default")
    local anim = def and (def:FindFirstChild("GrabParry") or def:FindFirstChild("Grab"))
    local repl = shared:FindFirstChild("ReplicatedInstances")
    local swords = repl and repl:FindFirstChild("Swords")
    local getSword = swords and swords:FindFirstChild("GetSword")
    if getSword then
        local ok, data = pcall(function() return getSword:Invoke(sword) end)
        if ok and type(data) == "table" and data.AnimationType then
            local folder = coll:FindFirstChild(data.AnimationType)
            if folder then
                anim = folder:FindFirstChild("GrabParry") or folder:FindFirstChild("Grab") or anim
            end
        end
    end
    return anim, sword
end

local function playParryAnimation()
    if not parryAnimationEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    if _grabAnimator ~= animator then
        _grabAnimator = animator
        _grabTrack, _grabSword = nil, nil
    end

    local anim, sword = getParryAnimation()
    if not anim then return end

    if not _grabTrack or _grabSword ~= sword then
        local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
        if not ok or not track then return end
        _grabTrack, _grabSword = track, sword
        _grabTrack.Priority = Enum.AnimationPriority.Movement
        _grabTrack.Stopped:Connect(function() end)
    end

    if _grabTrack and not _grabTrack.IsPlaying then
        local ok = pcall(function() _grabTrack:Play(0.05, 1, 1.66) end)
        if not ok then _grabTrack = nil end
    end
end

local function calculateImpactTime(ball, root)
    local aliveFolder = Workspace:FindFirstChild("Alive")
    if aliveFolder then
        local myChar = aliveFolder:FindFirstChild(LocalPlayer.Name)
        if myChar then
            local hrp = myChar:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp:FindFirstChild("SingularityCape", true)
                     or hrp:FindFirstChild("SingularityGravity", true)
                     or hrp:FindFirstChild("BeamPart2", true)) then
                return math.huge
            end
            if myChar:FindFirstChild("CalmingDeflectHighlight", true)
            or myChar:FindFirstChild("MaxRagingDeflectHighlight", true)
            or myChar:FindFirstChild("RagingDeflectHighlight", true)
            or myChar:FindFirstChild("FlashCounterHighlight", true) then
                return math.huge
            end
        end
    end

    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return math.huge end
    local v0    = zoomies.VectorVelocity
    local speed = v0.Magnitude
    if speed < 1 then return math.huge end

    local oneWayPing = math.min(LocalPlayer:GetNetworkPing() or 0, 0.3)
    local HIT_RADIUS = 15 + (oneWayPing * 50)

    local rawDist = (root.Position - ball.Position).Magnitude
    if rawDist < HIT_RADIUS then
        local toPlayer = root.Position - ball.Position
        if toPlayer.Magnitude > 0 and v0.Unit:Dot(toPlayer.Unit) > 0 then
            ballPrevVelocity[ball] = { v = v0, t = tick() }
            return 0
        end
    end

    local now      = tick()
    local prevData = ballPrevVelocity[ball]
    ballPrevVelocity[ball] = { v = v0, t = now }

    if prevData and prevData.v.Magnitude > 1 and (now - prevData.t) < 0.025 then
        local pv        = prevData.v
        local dirChange = v0.Unit:Dot(pv.Unit) < 0.7
        local magChange = math.abs(speed - pv.Magnitude) > pv.Magnitude * 0.4
        if dirChange and magChange then
            local toMe = root.Position - ball.Position
            local tm   = toMe.Magnitude
            if not (tm > 0.1 and v0.Unit:Dot(toMe / tm) > 0.80) then
                return math.huge
            end
        end
    end

    local observedAngVel = Vector3.zero
    if prevData and prevData.v.Magnitude > 1 then
        local dtObs = now - prevData.t
        if dtObs > 0.001 and dtObs < 0.2 then
            local cosA = math.clamp(prevData.v.Unit:Dot(v0.Unit), -1, 1)
            local ang  = math.acos(cosA)
            if ang > 0.0001 then
                local axisRaw = prevData.v:Cross(v0)
                if axisRaw.Magnitude > 0 then
                    observedAngVel = axisRaw.Unit * (ang / dtObs)
                end
            end
        end
    end

    local curvature = ball:GetAttribute("curvature") or 0
    local ballPos   = ball.Position + v0 * oneWayPing
    local PARRY_REACTION_WINDOW = math.max(0.15, 0.13 + oneWayPing * 1.5)

    local toPlayerVec  = root.Position - ballPos
    local toPlayerDist = toPlayerVec.Magnitude
    if toPlayerDist < HIT_RADIUS then return 0 end

    local toPlayerDir  = toPlayerVec / toPlayerDist
    local relVel       = v0 - root.AssemblyLinearVelocity
    local closingSpeed = relVel:Dot(toPlayerDir)
    local trajectoryStable = curvature == 0 and observedAngVel.Magnitude < 0.05
    local alignment        = v0.Unit:Dot(toPlayerDir)

    if trajectoryStable and closingSpeed > 0 and alignment > 0.85 then
        local timeToHit = (toPlayerDist - HIT_RADIUS) / closingSpeed
        if timeToHit < PARRY_REACTION_WINDOW then return 0 end
        return timeToHit
    end

    local stepRadius = math.max(10, speed / 120)
    local dt         = math.min(1 / 60, stepRadius * 0.5 / math.max(speed, 1))
    local maxT       = 3.0

    local P, V, t  = ballPos, v0, 0
    local prevDist = (root.Position - P).Magnitude
    local hasRot   = observedAngVel.Magnitude > 0.001
    local rotAxis  = hasRot and observedAngVel.Unit or nil
    local rotRate  = observedAngVel.Magnitude

    while t < maxT do
        if hasRot then
            local cf = CFrame.fromAxisAngle(rotAxis, rotRate * dt)
            V = cf:VectorToWorldSpace(V)
        end
        P = P + V * dt
        t = t + dt

        local dist = (root.Position - P).Magnitude
        if dist <= HIT_RADIUS then
            local f          = (prevDist - HIT_RADIUS) / math.max(prevDist - dist, 0.0001)
            local impactTime = t - dt + f * dt
            local curveBuf   = math.min(0.06, rotRate * 0.015)
            if impactTime < PARRY_REACTION_WINDOW + curveBuf then return 0 end
            return impactTime
        end
        prevDist = dist
    end

    return math.huge
end

-- Curve geometry for the Combat tab's "Curve Type" dropdown. Returns a CFrame
-- to send as the parry's curve, or nil for "Custom" (the file then uses its own
-- camera curve). Pure math — the parry still fires through the file's method.
local function getCurveCFrame()
    if parryType == "Custom" then return nil end

    local alive  = Workspace:FindFirstChild("Alive")
    local myChar = alive and alive:FindFirstChild(LocalPlayer.Name)
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    local origin = myHRP.Position

    local function closestEnemy()
        if not alive then return nil end
        if forceTargetParry and forcedTargetPlayer then
            local ch = alive:FindFirstChild(forcedTargetPlayer.Name)
            if ch and ch.PrimaryPart then return ch end
        end
        local best, bd = nil, math.huge
        for _, c in ipairs(alive:GetChildren()) do
            if c.Name ~= LocalPlayer.Name and c.PrimaryPart then
                local d = (c.PrimaryPart.Position - origin).Magnitude
                if d < bd then bd, best = d, c end
            end
        end
        return best
    end

    local function flatUnit(v, fallback)
        v = Vector3.new(v.X, 0, v.Z)
        if v.Magnitude < 0.01 then return fallback end
        return v.Unit
    end

    local enemy = closestEnemy()
    local toEnemy
    if enemy then
        toEnemy = flatUnit(enemy.PrimaryPart.Position - origin, Vector3.new(0, 0, 1))
    else
        toEnemy = flatUnit(myHRP.CFrame.LookVector, Vector3.new(0, 0, 1))
    end
    local rightOf = Vector3.new(-toEnemy.Z, 0, toEnemy.X)

    local aimPos
    if enemy and enemy.PrimaryPart then aimPos = enemy.PrimaryPart.Position end

    if parryType == "Dot" then
        return CFrame.new(origin, aimPos or (origin + toEnemy * 100))
    elseif parryType == "Accelerated" then
        local base = aimPos or (origin + toEnemy * 100)
        local flat = Vector3.new(base.X - origin.X, 0, base.Z - origin.Z).Magnitude
        local lift = math.clamp(flat * (accelLift / 100), 12, 140)
        return CFrame.new(origin, base + Vector3.new(0, lift, 0))
    elseif parryType == "Straight" then
        return CFrame.new(origin, origin + toEnemy * 100)
    elseif parryType == "Backwards" then
        return CFrame.new(origin, origin - toEnemy * 100)
    elseif parryType == "Random" then
        local a = math.random() * math.pi * 2
        local y = (math.random() * 2 - 1) * 0.6
        local dir = Vector3.new(math.cos(a), y, math.sin(a)).Unit
        return CFrame.new(origin, origin + dir * 100)
    elseif parryType == "Up" then
        return CFrame.new(origin, origin + Vector3.new(0, 100, 0))
    elseif parryType == "Left" then
        return CFrame.new(origin, origin - rightOf * 100)
    elseif parryType == "Right" then
        return CFrame.new(origin, origin + rightOf * 100)
    end
    return nil
end

local function _fireParry()
    local cf = getCurveCFrame()  -- nil for "Custom" -> file uses its own curve
    -- "Keyboard" uses the file's F / block-bind keypress path; else the remote.
    local mode = (parryMethod == "Keyboard") and "Keypress" or "Remote"
    pcall(function() BladeBallParry.parry(mode, 1, cf) end)
end

local function startAutoParry()
    if autoParryLoop then return end
    autoParryLoop = RunService.Heartbeat:Connect(function()
        -- Prune tracking for balls that vanished or no longer target us.
        for b in pairs(ballLead) do if not b or not b.Parent then cleanupBallTracking(b) end end
        for b in pairs(lastParriedBalls) do
            if not b or not b.Parent or b:GetAttribute("target") ~= LocalPlayer.Name then cleanupBallTracking(b) end
        end

        if not autoParryActive then return end
        if not BladeBallParry.is_ready() then return end

        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        -- Smoothed ping: rolling average of the last 8 samples.
        local rawPing = LocalPlayer:GetNetworkPing() or 0
        _pingHistory[#_pingHistory + 1] = rawPing
        if #_pingHistory > 8 then table.remove(_pingHistory, 1) end
        local pingSum = 0
        for _, p in ipairs(_pingHistory) do pingSum = pingSum + p end
        local ping = pingSum / #_pingHistory

        -- Accuracy slider = the real parry-timing control. The UI stays 1..100 but
        -- its effect is stretched as if it ran -50..150, so the usable timing range
        -- is roughly doubled (about +-90ms) while the max stays 100. Neutral at 50.
        -- "Random" (the chip on the Accuracy row) re-rolls the effective value every
        -- frame for a human-like jitter. This bias sits ON TOP of the automatic ping
        -- compensation below, so it stays sensible whether ping is 2ms or 100ms.
        -- Higher = parry a touch earlier (more lead / safer); lower = tighter.
        local effAcc           = randomAccuracy and math.random(accuracyRangeMin, accuracyRangeMax) or parryAccuracy
        local expandedAcc      = (effAcc * 2) - 50      -- 1->-48 .. 50->50 .. 100->150
        local accBias          = ((expandedAcc - 50) / 100) * 0.120
        local baseTiming       = 0.13
        local pingJitterBuffer = math.min(ping * 0.25, 0.04)
        local BASE_LEAD        = baseTiming + pingJitterBuffer + accBias
        local SAFETY_WINDOW    = math.max(0.05, ping + 0.04 + accBias)

        -- TrainingBalls while dead, else Balls.
        local deadFolder  = Workspace:FindFirstChild("Dead")
        local isDead      = deadFolder and deadFolder:FindFirstChild(LocalPlayer.Name)
        local ballsFolder = (isDead and Workspace:FindFirstChild("TrainingBalls")) or Workspace:FindFirstChild("Balls")
        if not ballsFolder then return end

        -- Emergency pass: a ball about to hit us gets parried immediately.
        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if ball:IsA("BasePart") and ball:GetAttribute("realBall")
               and ball:GetAttribute("target") == LocalPlayer.Name
               and not lastParriedBalls[ball] then
                local impact = calculateImpactTime(ball, root)
                if impact < math.huge and impact <= SAFETY_WINDOW then
                    lastParriedBalls[ball] = true
                    local thisBall = ball
                    _fireParry()
                    playParryAnimation()
                    task.spawn(function()
                        while thisBall and thisBall.Parent and thisBall:GetAttribute("target") == LocalPlayer.Name do RunService.Heartbeat:Wait() end
                        cleanupBallTracking(thisBall)
                    end)
                    return
                end
            end
        end

        -- Candidate pass: gather balls inside their lead window, soonest first.
        local MAX_CONSIDER = 1.0
        local candidates = {}
        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if ball:IsA("BasePart") and ball:GetAttribute("realBall")
               and ball:GetAttribute("target") == LocalPlayer.Name then
                local impact = calculateImpactTime(ball, root)
                if impact < math.huge and impact <= MAX_CONSIDER then
                    local zoomies = ball:FindFirstChild("zoomies")
                    local spd = (zoomies and zoomies.VectorVelocity.Magnitude) or 0
                    local speedBonus = getSpeedBonus(spd)
                    if not ballLead[ball] then ballLead[ball] = apRandom:NextNumber(0, 0.05) end
                    ballLead[ball] = math.min(ballLead[ball], 0.01)
                    local lead = BASE_LEAD + speedBonus + ballLead[ball]
                    if impact <= lead then table.insert(candidates, { ball = ball, t = impact }) end
                end
            elseif ball:IsA("BasePart") and not ball:GetAttribute("realBall") then
                ballPrevVelocity[ball] = nil
            end
        end
        if #candidates == 0 then return end
        table.sort(candidates, function(a, b) return a.t < b.t end)

        -- Dual/multi parry: 2+ balls landing within ~0.1s get burst-parried.
        local now = tick()
        if #candidates >= 2 and (now - lastDualParryAt) > DUAL_LOCK_WINDOW then
            local balls = {}
            for i = 1, math.min(4, #candidates) do table.insert(balls, candidates[i]) end
            local maxTimeDiff = 0.1
            for i = 1, #balls - 1 do
                if math.abs(balls[i].t - balls[i + 1].t) <= maxTimeDiff then
                    if not lastParriedBalls[balls[i].ball] and not lastParriedBalls[balls[i + 1].ball] then
                        lastDualParryAt = now
                        lastParriedBalls[balls[i].ball] = true
                        lastParriedBalls[balls[i + 1].ball] = true
                        for _ = 1, #balls do _fireParry() end
                        playParryAnimation()
                        task.spawn(function()
                            for _, b in ipairs(balls) do
                                local safetyTimer = 0
                                while b.ball and b.ball.Parent and b.ball:GetAttribute("target") == LocalPlayer.Name and safetyTimer < 1.0 do
                                    RunService.Heartbeat:Wait()
                                    safetyTimer = safetyTimer + 0.03
                                    if safetyTimer > 0.3 and b.ball:GetAttribute("target") == LocalPlayer.Name then
                                        _fireParry()
                                    end
                                end
                                cleanupBallTracking(b.ball)
                            end
                        end)
                        return
                    end
                end
            end
        end

        -- Single parry: soonest candidate.
        local first = candidates[1]
        if first and not lastParriedBalls[first.ball] then
            lastParriedBalls[first.ball] = true
            local thisBall = first.ball
            _fireParry()
            playParryAnimation()
            task.spawn(function()
                while thisBall and thisBall.Parent and thisBall:GetAttribute("target") == LocalPlayer.Name do RunService.Heartbeat:Wait() end
                cleanupBallTracking(thisBall)
            end)
        end
    end)
end

local function stopAutoParry()
    if autoParryLoop then
        autoParryLoop:Disconnect()
        autoParryLoop = nil
    end
    for b in pairs(ballLead) do cleanupBallTracking(b) end
    for b in pairs(lastParriedBalls) do cleanupBallTracking(b) end
    for k in pairs(ballPrevVelocity) do ballPrevVelocity[k] = nil end
end


    -- Expose exactly what the Pyra UI needs; firing stays inside this block.
    AP_start     = startAutoParry
    AP_stop      = stopAutoParry
    AP_setActive = function(v) autoParryActive = v end
    AP_fire      = function() pcall(function() BladeBallParry.parry("Remote", 1) end) end
end

-- Spam loop. Fires ONLY the working.txt method (BladeBallParry.parry("Remote", 1)).
task.spawn(function()
    while true do
        if spamming then
            AP_fire()
            task.wait(0.05)
        elseif spamDetectionEnabled then
            AP_fire()
            task.wait(math.max(0.03, 0.3 - (spamThresholdOffset + 10) * 0.0125))
        else
            task.wait(0.1)
        end
    end
end)

local function startManualSpamGrim() spamming = true end
local function stopManualSpamGrim()  spamming = false end


local function getNextPosition()
    local allFrames = {}
    if defaultAdvancedMonitor and defaultAdvancedMonitor.frame then table.insert(allFrames, defaultAdvancedMonitor.frame) end
    for _, data in pairs(advancedBallMonitors) do if data.frame then table.insert(allFrames, data.frame) end end
    if #allFrames == 0 then return UDim2.new(0, 20, 0, 400) end
    local lowestY = -math.huge
    local anchorX = 20
    for _, frame in ipairs(allFrames) do if frame.Position.Y.Offset > lowestY then lowestY = frame.Position.Y.Offset anchorX = frame.Position.X.Offset end end
    return UDim2.new(0, anchorX, 0, lowestY + 95)
end

local function createBallMonitor(displayText, initialPos)
    -- Pyra theme: Glass RGB(12,12,15) @ 0.34, white stroke @ 0.88, corner 14,
    -- GothamBold title / GothamMedium body, Text 248,248,250, SubText 150,150,160.
    local gui = Instance.new("ScreenGui")
    gui.Name = _hashName("BM"); gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999999; gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 170, 0, 82)
    frame.Position = UDim2.new(initialPos.X.Scale, initialPos.X.Offset - 270, initialPos.Y.Scale, initialPos.Y.Offset)
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    frame.BackgroundTransparency = 0.34
    frame.BorderSizePixel = 0; frame.Active = true; frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local fStroke = Instance.new("UIStroke")
    fStroke.Thickness = 1
    fStroke.Color = Color3.new(1, 1, 1)
    fStroke.Transparency = 0.88
    fStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fStroke.Parent = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.Parent = frame

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 0, 12)
    t.Position = UDim2.new(0, 0, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = displayText:upper()
    t.Font = Enum.Font.GothamBold
    t.TextColor3 = Color3.fromRGB(150, 150, 160)
    t.TextSize = 10
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = frame

    task.delay(0.05, function()
        TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = initialPos}):Play()
    end)

    local vL = Instance.new("TextLabel")
    vL.Size = UDim2.new(1, 0, 0, 22)
    vL.Position = UDim2.new(0, 0, 0, 18)
    vL.BackgroundTransparency = 1
    vL.Text = "-- st/s"
    vL.Font = Enum.Font.GothamBold
    vL.TextColor3 = Color3.fromRGB(248, 248, 250)
    vL.TextSize = 18
    vL.TextXAlignment = Enum.TextXAlignment.Left
    vL.Parent = frame

    local pL = Instance.new("TextLabel")
    pL.Size = UDim2.new(1, 0, 0, 12)
    pL.Position = UDim2.new(0, 0, 0, 44)
    pL.BackgroundTransparency = 1
    pL.Text = "PEAK  --"
    pL.Font = Enum.Font.GothamMedium
    pL.TextColor3 = Color3.fromRGB(90, 90, 100)
    pL.TextSize = 10
    pL.TextXAlignment = Enum.TextXAlignment.Left
    pL.Parent = frame
    local dragging = false; local dragStart = Vector2.new(); local startPos = UDim2.new()
    local connections = {}
    connections[#connections+1] = UserInputService.InputChanged:Connect((function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    connections[#connections+1] = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    gui.Destroying:Connect(function() for _, c in ipairs(connections) do c:Disconnect() end end)
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = Vector2.new(input.Position.X, input.Position.Y); startPos = frame.Position
        end
    end)
    return {gui = gui, frame = frame, titleLabel = t, velLabel = vL, peakLabel = pL, peakSpeed = 0, prevSpeed = 0}
end

local function startAdvancedBallMonitor()
    local oldGui = CoreGui:FindFirstChild(_hashName("BM_P"))
    if oldGui then oldGui:Destroy() end
    for _, child in ipairs(CoreGui:GetChildren()) do if child.Name == _hashName("BM") then child:Destroy() end end
    if defaultAdvancedMonitor and defaultAdvancedMonitor.gui then defaultAdvancedMonitor.gui:Destroy() end
    for _, data in pairs(advancedBallMonitors) do if data.gui then data.gui:Destroy() end end
    advancedBallMonitors = {}; defaultAdvancedMonitor = nil
    if advancedMonitorUpdateConnection then advancedMonitorUpdateConnection:Disconnect() end
    defaultAdvancedMonitor = createBallMonitor("BALL MONITOR", getNextPosition())
    local hadBalls = false
    local function updateMonitor(data, ball)
        local zoomies = ball:FindFirstChild("zoomies")
        local speed = (zoomies and zoomies.VectorVelocity) and zoomies.VectorVelocity.Magnitude or 0
        if not data.smoothSpeed then data.smoothSpeed = speed end
        local alpha = speed > data.smoothSpeed and 0.35 or 0.06
        data.smoothSpeed = data.smoothSpeed + (speed - data.smoothSpeed) * alpha
        local displaySpeed = data.smoothSpeed
        data.velLabel.Text = string.format("%.0f st/s", displaySpeed)
        data.velLabel.TextColor3 = displaySpeed > 1200 and Color3.fromRGB(235, 70, 70) or displaySpeed > 600 and Color3.fromRGB(235, 190, 90) or Color3.fromRGB(248, 248, 250)
        local accelerating = speed > data.prevSpeed
        if speed > data.peakSpeed then data.peakSpeed = speed end
        data.prevSpeed = speed
        if data.peakSpeed > 0 then
            data.peakLabel.Text = string.format("PEAK  %.0f st/s", data.peakSpeed)
            data.peakLabel.TextColor3 = accelerating and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(90, 90, 100)
        end
    end
    local function resetPeak(data)
        data.peakSpeed = 0; data.prevSpeed = 0; data.smoothSpeed = 0
        data.peakLabel.Text = "PEAK  --"; data.peakLabel.TextColor3 = Color3.fromRGB(90, 90, 100)
    end
    local _monitorVelTimer = 0
    advancedMonitorUpdateConnection = RunService.RenderStepped:Connect((function(dt)
        _monitorVelTimer = _monitorVelTimer + dt
        if _monitorVelTimer < 0.1 then return end
        _monitorVelTimer = 0
        local ballsFolder = Workspace:FindFirstChild("Balls")
        local realBalls = {}
        if ballsFolder then for _, ball in ipairs(ballsFolder:GetChildren()) do if ball:IsA("BasePart") and ball:GetAttribute("realBall") then table.insert(realBalls, ball) end end end
        if #realBalls == 0 then
            for _, data in pairs(advancedBallMonitors) do if data.gui then data.gui:Destroy() end end
            advancedBallMonitors = {}
            if defaultAdvancedMonitor then
                defaultAdvancedMonitor.titleLabel.Text = "BALL MONITOR"
                defaultAdvancedMonitor.velLabel.Text = "-- st/s"
                defaultAdvancedMonitor.velLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
                if defaultAdvancedMonitor.peakSpeed > 0 then defaultAdvancedMonitor.peakLabel.TextColor3 = Color3.fromRGB(255, 60, 60) end
            end
            hadBalls = false; return
        end
        if not hadBalls then
            if defaultAdvancedMonitor then resetPeak(defaultAdvancedMonitor) end
            for _, data in pairs(advancedBallMonitors) do resetPeak(data) end
        end
        hadBalls = true
        for ball, data in pairs(advancedBallMonitors) do if not table.find(realBalls, ball) then if data.gui then data.gui:Destroy() end advancedBallMonitors[ball] = nil end end
        for i = 2, #realBalls do
            local ball = realBalls[i]
            if not advancedBallMonitors[ball] then advancedBallMonitors[ball] = createBallMonitor("BALL #" .. i, getNextPosition()) end
        end
        if defaultAdvancedMonitor and #realBalls >= 1 then
            defaultAdvancedMonitor.titleLabel.Text = "BALL MONITOR"
            updateMonitor(defaultAdvancedMonitor, realBalls[1])
        end
        for i = 2, #realBalls do
            local data = advancedBallMonitors[realBalls[i]]
            if data then updateMonitor(data, realBalls[i]) end
        end
    end))
end

local function stopAdvancedBallMonitor()
    if advancedMonitorUpdateConnection then advancedMonitorUpdateConnection:Disconnect() advancedMonitorUpdateConnection = nil end
    if defaultAdvancedMonitor and defaultAdvancedMonitor.gui then defaultAdvancedMonitor.gui:Destroy() defaultAdvancedMonitor = nil end
    for _, data in pairs(advancedBallMonitors) do if data.gui then data.gui:Destroy() end end
    advancedBallMonitors = {}
end

local CLOCK_BLUE = Color3.fromRGB(80, 200, 255)

local _NO_BALLS = {}
local function ballsNow()
    local f = Workspace:FindFirstChild("Balls")
    if not f then return _NO_BALLS end
    return f:GetChildren()
end
local function createAbilityBillboard(characterModel)
    if not characterModel or characterModel.Name == player.Name then return end
    local head = characterModel:WaitForChild("Head", 3)
    if not head then return end
    local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return end
    local plr = Players:FindFirstChild(characterModel.Name)
    if not plr or plr == player then return end
    if head:FindFirstChild("AbilityBillboard") then head.AbilityBillboard:Destroy() end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AbilityBillboard"
    billboard.Size = UDim2.fromOffset(132, 26)
    billboard.StudsOffset = Vector3.new(0, 3.6, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 260
    billboard.Parent = head

    local card = Instance.new("Frame")
    card.Size = UDim2.fromScale(1, 1)
    card.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    card.BackgroundTransparency = 0.25
    card.BorderSizePixel = 0
    card.Parent = billboard
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 7)
    cardCorner.Parent = card
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = CLOCK_BLUE
    cardStroke.Thickness = 1
    cardStroke.Transparency = 0.45
    cardStroke.Parent = card

    local pip = Instance.new("Frame")
    pip.AnchorPoint = Vector2.new(0, 0.5)
    pip.Position = UDim2.new(0, 7, 0.5, 0)
    pip.Size = UDim2.fromOffset(4, 12)
    pip.BackgroundColor3 = CLOCK_BLUE
    pip.BorderSizePixel = 0
    pip.Parent = card
    local pipCorner = Instance.new("UICorner")
    pipCorner.CornerRadius = UDim.new(1, 0)
    pipCorner.Parent = pip

    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0, 0.5)
    label.Position = UDim2.new(0, 17, 0.5, 0)
    label.Size = UDim2.new(1, -24, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextColor3 = Color3.fromRGB(248, 248, 250)
    label.Parent = card

    local function render()
        local ability = plr:GetAttribute("EquippedAbility")
        if ability and ability ~= "" then
            label.Text = tostring(ability)
            label.TextColor3 = Color3.fromRGB(248, 248, 250)
            pip.BackgroundColor3 = CLOCK_BLUE
            cardStroke.Color = CLOCK_BLUE
            cardStroke.Transparency = 0.45
        else
            label.Text = "No Ability"
            label.TextColor3 = Color3.fromRGB(150, 150, 160)
            pip.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
            cardStroke.Color = Color3.fromRGB(255, 255, 255)
            cardStroke.Transparency = 0.8
        end
    end
    render()

    if humanoid then humanoid.Died:Connect(function() if billboard and billboard.Parent then billboard:Destroy() end end) end
    plr:GetAttributeChangedSignal("EquippedAbility"):Connect(function()
        if label and label.Parent then render() end
    end)
    characterModel.AncestryChanged:Connect(function(_, parent)
        if not parent and billboard and billboard.Parent then billboard:Destroy() end
    end)
end

local function startAbilityESP()
    if abilityESPConnection then abilityESPConnection:Disconnect() end
    local aliveFolder = Workspace:WaitForChild("Alive")
    for _, characterModel in ipairs(aliveFolder:GetChildren()) do createAbilityBillboard(characterModel) end
    abilityESPConnection = aliveFolder.ChildAdded:Connect(function(characterModel) task.wait(0.6) createAbilityBillboard(characterModel) end)
end

local function stopAbilityESP()
    if abilityESPConnection then abilityESPConnection:Disconnect() abilityESPConnection = nil end
    local aliveFolder = Workspace:FindFirstChild("Alive")
    if aliveFolder then
        for _, characterModel in ipairs(aliveFolder:GetChildren()) do
            local head = characterModel:FindFirstChild("Head")
            if head and head:FindFirstChild("AbilityBillboard") then head.AbilityBillboard:Destroy() end
        end
    end
end

local noRenderEnabled = false
local noRenderConnection = nil
local function setClientFX(disabled)
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local fx = ps and ps:FindFirstChild("EffectScripts")
        local cfx = fx and fx:FindFirstChild("ClientFX")
        if cfx then cfx.Disabled = disabled end
    end)
end

local function startNoRender()
    setClientFX(true)
    local Debris = game:GetService("Debris")
    local Runtime = Workspace:FindFirstChild("Runtime")
    if not Runtime then return end
    noRenderConnection = Runtime.ChildAdded:Connect(function(child) if noRenderEnabled then Debris:AddItem(child, 0) end end)
end
local function stopNoRender()
    noRenderEnabled = false
    setClientFX(false)
    if noRenderConnection then noRenderConnection:Disconnect() noRenderConnection = nil end
end

local function setRaytracing(enabled)
    local Lighting = game:GetService("Lighting")
    for _, v in ipairs(Lighting:GetChildren()) do
        if v.Name == "CLOCKAP_Bloom" or v.Name == "CLOCKAP_DOF" then v:Destroy() end
    end

    if enabled then
        local bloom = Instance.new("BloomEffect")
        bloom.Name = "CLOCKAP_Bloom"; bloom.Intensity = 0.45; bloom.Size = 20; bloom.Threshold = 0.9
        bloom.Parent = Lighting
    end
end

local fullbrightEnabled = false
local fulldarkEnabled   = false

local _settingLighting = false
local function setNormalLighting()
    local Lighting = game:GetService("Lighting")
    Lighting.Brightness           = 1
    Lighting.Ambient              = Color3.fromRGB(70, 70, 70)
    Lighting.OutdoorAmbient       = Color3.fromRGB(70, 70, 70)
    Lighting.ClockTime            = 14
    Lighting.FogEnd               = 100000
    Lighting.ExposureCompensation = 0
    local cc = Lighting:FindFirstChild("CLOCKAP_FullDarkCC")
    if cc then cc:Destroy() end
end

local function setFullbright(enabled)
    local Lighting = game:GetService("Lighting")
    _settingLighting = true
    if enabled then
        Lighting.Brightness     = 2
        Lighting.Ambient        = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.ClockTime      = 12
        Lighting.FogEnd         = 1e9
    else
        setNormalLighting()
    end
    _settingLighting = false
end

local function setFulldark(enabled)
    local Lighting = game:GetService("Lighting")
    _settingLighting = true
    if enabled then
        Lighting.ClockTime            = 0
        Lighting.Brightness           = 1
        Lighting.Ambient              = Color3.fromRGB(8, 8, 12)
        Lighting.OutdoorAmbient       = Color3.fromRGB(12, 12, 18)
        Lighting.ExposureCompensation = 0.25
        local cc = Lighting:FindFirstChild("CLOCKAP_FullDarkCC")
        if not cc then cc = Instance.new("ColorCorrectionEffect"); cc.Name = "CLOCKAP_FullDarkCC"; cc.Parent = Lighting end
        cc.Enabled = true; cc.Brightness = 0; cc.Contrast = 0.08; cc.Saturation = 0.15
    else
        setNormalLighting()
    end
    _settingLighting = false
end

RunService.Heartbeat:Connect(function()
    if fullbrightEnabled then
        local Lighting = game:GetService("Lighting")
        if Lighting.Brightness ~= 2 then setFullbright(true) end
    elseif fulldarkEnabled then
        local Lighting = game:GetService("Lighting")
        if Lighting.ClockTime ~= 0 then setFulldark(true) end
    end
end)

local function setFOV(value)
    local c = Workspace.CurrentCamera
    if c then c.FieldOfView = value end
end

local ballTrailEnabled = false
local ballTrailColor = Color3.new(1, 1, 1)
local ballTrailDistance = 0
local ballTrailRainbow = false
local effectsRainbow = false
local visualizerRainbow = false
local _rainbowEnabled = false
local _syncRainbow = false
local trailHue = 0
local glowHue = 0
local visualizerHue = 0
local ballTrailParticle = false
local ballTrailGlow = false
local ballTrailHueConn = nil

local applyTrail = (function(ball)
    local trail = ball:FindFirstChild("Trail")
    if not trail then
        trail = Instance.new("Trail"); trail.Name = "Trail"
        local a0 = Instance.new("Attachment"); a0.Name = "Attachment0"; a0.Position = Vector3.new(0, ball.Size.Y*0.6, 0); a0.Parent = ball
        local a1 = Instance.new("Attachment"); a1.Name = "Attachment1"; a1.Position = Vector3.new(0, -ball.Size.Y*0.6, 0); a1.Parent = ball
        trail.Attachment0 = a0; trail.Attachment1 = a1; trail.Lifetime = 0.65
        trail.FaceCamera = true; trail.LightEmission = 0.6; trail.LightInfluence = 0
        trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.55),NumberSequenceKeypoint.new(1,0)})
        trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(0.3,0.35),NumberSequenceKeypoint.new(1,1)})
        trail.Parent = ball
    end
    trail.Lifetime = 0.325 + (ballTrailDistance / 100) * 1.825
    trail.Color = ColorSequence.new(ballTrailColor)
end)

local applyGlow = (function(ball, on)
    local g = ball:FindFirstChild("BallGlow")
    if on then
        if not g then g = Instance.new("PointLight"); g.Name = "BallGlow"; g.Range = 20; g.Brightness = 1.4; g.Parent = ball end
        g.Color = ballTrailColor
    elseif g then g:Destroy() end
end)

local applyParticle = (function(ball, on)
    local e = ball:FindFirstChild("ParticleEmitter")
    if on then
        if not e then
            e = Instance.new("ParticleEmitter"); e.Name = "ParticleEmitter"
            e.Rate = 140; e.Lifetime = NumberRange.new(0.6, 1.1); e.Speed = NumberRange.new(1, 3)
            e.SpreadAngle = Vector2.new(180, 180); e.LightEmission = 1; e.LightInfluence = 0
            e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,1.6),NumberSequenceKeypoint.new(1,0.4)})
            e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(1,1)})
            e.Parent = ball
        end
        e.Color = ColorSequence.new(ballTrailColor)
    elseif e then e:Destroy() end
end)

local refreshBallTrails = (function()
    for _, ball in ipairs(ballsNow()) do
        if ball:IsA("BasePart") then
            if ballTrailEnabled then applyTrail(ball) else local t = ball:FindFirstChild("Trail"); if t then t:Destroy() end end
            applyGlow(ball, ballTrailGlow); applyParticle(ball, ballTrailParticle)
        end
    end
end)

local _trailRainbowHue = 0
local _visRainbowHue = 0
local rainbowSpeed = 0
local _lastPickerPush = 0
local function startBallTrailLoop()
    if ballTrailHueConn then return end
    ballTrailHueConn = RunService.Heartbeat:Connect((function()
        local anyActive = ballTrailEnabled or ballTrailGlow or ballTrailParticle or visualizerEnabled
        if not anyActive then return end
        if _rainbowEnabled then
            local increment = 2 ^ (rainbowSpeed / 50)
            if ballTrailRainbow then
                _trailRainbowHue = (_trailRainbowHue + increment) % 360
                ballTrailColor = Color3.fromHSV(_trailRainbowHue/360, 1, 1)
                -- Reflect the live rainbow color on the GUI picker swatch.
                -- Throttled to ~10Hz so we don't thrash the UI.
                local now = tick()
                if now - _lastPickerPush > 0.1 then
                    _lastPickerPush = now
                    local h = getgenv()._PyraTrailColorHandle
                    if h and h.Set then
                        pcall(function() h:Set(ballTrailColor, true) end)
                    end
                end
            end
            if visualizerRainbow then
                if _syncRainbow and ballTrailRainbow then
                    _visRainbowHue = _trailRainbowHue
                else
                    _visRainbowHue = (_visRainbowHue + increment) % 360
                end
            end
        end
        for _, ball in ipairs(ballsNow()) do
            if ball:IsA("BasePart") then
                if ballTrailEnabled then
                    local trail = ball:FindFirstChild("Trail") or (applyTrail(ball) or ball:FindFirstChild("Trail"))
                    if trail then trail.Color = ColorSequence.new(ballTrailColor) end
                end
                applyGlow(ball, ballTrailGlow); applyParticle(ball, ballTrailParticle)
            end
        end
    end))
end

local visualizerEnabled = false
local visualPart = nil

local ViewCamPart = Instance.new("Part")
ViewCamPart.Shape = Enum.PartType.Block
ViewCamPart.Size = Vector3.new(2.4, 1.6, 1.0)
ViewCamPart.Material = Enum.Material.Neon
ViewCamPart.Color = Color3.fromRGB(100, 115, 190)
ViewCamPart.Anchored = true; ViewCamPart.CanCollide = false
ViewCamPart.CastShadow = false; ViewCamPart.Transparency = 1
ViewCamPart.Parent = Workspace
local _vcpLight = Instance.new("PointLight", ViewCamPart)
_vcpLight.Brightness = 4; _vcpLight.Range = 16
_vcpLight.Color = Color3.fromRGB(100, 115, 190); _vcpLight.Enabled = false
local visualizerConn = nil

local visSegments = {}
local VIS_SEGS = 14
local _visRadius = 4
local function startVisualizer()
    if #visSegments == 0 then
        for i = 1, VIS_SEGS do
            local seg = Instance.new("Part")
            seg.Name = _hashName("VR" .. i)
            seg.Size = Vector3.new(0.3, 0.3, 1.5)
            seg.Material = Enum.Material.Neon
            seg.Color = Color3.fromRGB(255, 255, 255)
            seg.Transparency = 0.2
            seg.Anchored = true
            seg.CanCollide = false
            seg.CanQuery = false
            seg.CanTouch = false
            seg.CastShadow = false
            seg.Parent = Workspace
            visSegments[i] = seg
        end
    end
    visualizerConn = RunService.RenderStepped:Connect(function()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            for _, seg in ipairs(visSegments) do seg.Transparency = 1 end
            return
        end
        local col
        if visualizerRainbow then col = Color3.fromHSV(_visRainbowHue / 360, 0.85, 1)
        else col = Color3.fromHSV(visualizerHue / 360, 0.85, 1) end

        local speed = 0
        for _, ball in ipairs(ballsNow()) do
            if ball:IsA("BasePart") and ball:FindFirstChild("zoomies") then
                speed = math.min(ball.AssemblyLinearVelocity.Magnitude, 350)
                break
            end
        end
        local t = tick()
        local norm = speed / 350
        _visRadius = _visRadius + ((3.4 + norm * 9.5) - _visRadius) * 0.08
        local radius = _visRadius + math.sin(t * 1.6) * (0.7 + norm * 1.6)
        local spin = t * (0.18 + norm * 0.55)
        local segLen = ((2 * math.pi * radius) / VIS_SEGS) * 0.62
        local center = hrp.Position - Vector3.new(0, 2.4, 0)

        for i, seg in ipairs(visSegments) do
            local a = spin + (i / VIS_SEGS) * math.pi * 2
            local pos = center + Vector3.new(
                math.cos(a) * radius,
                math.sin(a * 3 + t * 2) * 0.4,
                math.sin(a) * radius
            )
            local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
            seg.CFrame = CFrame.new(pos, pos + tangent)
            seg.Size = Vector3.new(0.3, 0.3, segLen)
            seg.Color = col
            seg.Transparency = 0.18 + (i % 2) * 0.22
        end
    end)
end

local function stopVisualizer()
    if visualizerConn then visualizerConn:Disconnect(); visualizerConn = nil end
    for _, seg in ipairs(visSegments) do pcall(function() seg:Destroy() end) end
    table.clear(visSegments)
    if visualPart then visualPart:Destroy(); visualPart = nil end
end

local PYRA_LIB_URL = "https://raw.githubusercontent.com/SwipeCard/PyraUI/main/PyraUI_Library.lua"
local SESSION_FILE = "PyraSession.txt"
local SESSION_GAP = 90
local hasFiles = (type(writefile) == "function") and (type(readfile) == "function") and (type(isfile) == "function")

local function writeSession(startEpoch)
	if hasFiles then pcall(function() writefile(SESSION_FILE, startEpoch .. "|" .. os.time()) end) end
end
local function resolveSessionStart()
	if type(_G.PyraSessionStart) == "number" and _G.PyraSessionStart > 0 then return _G.PyraSessionStart end
	if hasFiles then
		local ok, data = pcall(function() if isfile(SESSION_FILE) then return readfile(SESSION_FILE) end end)
		if ok and type(data) == "string" then
			local startStr, lastStr = data:match("^(%d+)|(%d+)$")
			local startEpoch = tonumber(startStr)
			local lastSeen = tonumber(lastStr) or 0
			if startEpoch and (os.time() - lastSeen) <= SESSION_GAP then return startEpoch end
		end
	end
	return os.time()
end
local SESSION_START = resolveSessionStart()
_G.PyraSessionStart = SESSION_START
writeSession(SESSION_START)
task.spawn(function()
	while _G.PyraSessionStart == SESSION_START do
		writeSession(SESSION_START)
		task.wait(15)
	end
end)

local Library = (function()
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function raiseIdentity()
	local get = get_thread_identity or getthreadidentity or getidentity
	local set = set_thread_identity or setthreadidentity or setidentity
	if type(get) ~= "function" or type(set) ~= "function" then return nil, nil end
	local ok, old = pcall(get)
	if not ok or type(old) ~= "number" then return nil, nil end
	if old < 2 then pcall(set, 2) end
	return set, old
end

local function restoreIdentity(set, old)
	if set and old and old < 2 then pcall(set, old) end
end

local function getGuiParent()
	if RunService:IsStudio() then
		return player:WaitForChild("PlayerGui")
	end
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui end
	end
	local set, old = raiseIdentity()
	local ok = pcall(function() return CoreGui:GetChildren() end)
	restoreIdentity(set, old)
	if ok then return CoreGui end
	return player:WaitForChild("PlayerGui")
end

local function protect(gui)
	local fn = protectgui
		or protect_gui
		or (syn and syn.protect_gui)
		or (secure_gui)
		or (fluxus and fluxus.protect_gui)
	if type(fn) == "function" then pcall(fn, gui) end
end

local THEME = {
	Glass         = Color3.fromRGB(12, 12, 15),
	Card          = Color3.fromRGB(255, 255, 255),
	Switch        = Color3.fromRGB(52, 52, 58),
	Text          = Color3.fromRGB(248, 248, 250),
	Body          = Color3.fromRGB(220, 220, 226),
	SubText       = Color3.fromRGB(150, 150, 160),
	Muted         = Color3.fromRGB(90, 90, 100),
	Premium       = Color3.fromRGB(255, 205, 70),
	Accent        = Color3.fromRGB(255, 255, 255),
	AccentInverse = Color3.fromRGB(10, 10, 12),
}

local GLASS_DOCK_T  = 0.28
local GLASS_PANEL_T = 0.34
local SOLID_T       = 0.06
local CARD_T        = 0.955
local CARD_HOVER_T  = 0.93

local FONT        = Enum.Font.GothamMedium
local FONT_MEDIUM = Enum.Font.GothamBold
local FONT_BOLD   = Enum.Font.GothamBold

local LOGO_ID = "rbxassetid://6023426921"

local ICONS = {
	Logo = "rbxassetid://6023426921",
	Diamond = "rbxassetid://89788278732735",
	Arrow = "rbxassetid://86644458913479",
	Close = "rbxassetid://71379270081112",
	Minimize = "rbxassetid://95004752241443",
	Search = "rbxassetid://129236045938066",
	Settings = "rbxassetid://110768919221533",
	Spectate = "rbxassetid://137427491983393",
	Pin = "rbxassetid://102761078072952",
	Spectate_Selected = "rbxassetid://77306507937998",
	Pin_Selected = "rbxassetid://135812284323262",
	Warning = "rbxassetid://90951955041815",
	Discord = "rbxassetid://123978857883708",
	Sword = "rbxassetid://105435037070971",
	Sword_Selected = "rbxassetid://120638001068240",
}

local function iconOrText(id, fallback)
	return (type(id) == "string" and id ~= "" and id) or nil, fallback
end

task.spawn(function()
	local ok, ContentProvider = pcall(function() return game:GetService("ContentProvider") end)
	if not ok then return end
	local assets = {}
	for _, v in pairs(ICONS) do
		if type(v) == "string" and v ~= "" then
			local holder = Instance.new("ImageLabel")
			holder.Image = v
			table.insert(assets, holder)
		end
	end
	pcall(function() ContentProvider:PreloadAsync(assets) end)
	for _, a in ipairs(assets) do a:Destroy() end
end)

local WINDOW_W = 640
local DOCK_H   = 44
local GAP      = 8
local PANEL_H  = 380
local FOOTER_H = 48

local PARALLAX_STRENGTH  = 16
local PARALLAX_STIFFNESS = 60
local PARALLAX_DAMPING   = 13
local PARALLAX_DEPTH     = 0.35
local TAB_H    = 30

local SOUND_INTRO      = "rbxassetid://9113084671"
local SOUND_OUTRO      = "rbxassetid://9114144862"
local SOUND_TOGGLE_ON  = "rbxassetid://6895079853"
local SOUND_TOGGLE_OFF = "rbxassetid://6895079733"
local SOUND_CLICK      = "rbxassetid://6042583638"

for _, c in ipairs(SoundService:GetChildren()) do
	if c.Name == "PyraSound" then c:Destroy() end
end

local soundCache = {}
local function playSound(id, volume, pitch)
	volume = volume or 0.5
	pitch = pitch or 1
	local key = id .. "|" .. volume .. "|" .. pitch
	local snd = soundCache[key]
	if not snd or not snd.Parent then
		snd = Instance.new("Sound")
		snd.Name = "PyraSound"
		snd.SoundId = id
		snd.Volume = volume
		snd.PlaybackSpeed = pitch
		snd.Parent = SoundService
		soundCache[key] = snd
	end
	local ok = pcall(function() SoundService:PlayLocalSound(snd) end)
	if not ok then
		snd.TimePosition = 0
		snd:Play()
	end
end

local tweenInfoCache = {}
local function getTweenInfo(time, style, direction)
	local byStyle = tweenInfoCache[time]
	if not byStyle then byStyle = {} tweenInfoCache[time] = byStyle end
	local sv = style.Value
	local byDir = byStyle[sv]
	if not byDir then byDir = {} byStyle[sv] = byDir end
	local dv = direction.Value
	local info = byDir[dv]
	if not info then info = TweenInfo.new(time, style, direction) byDir[dv] = info end
	return info
end

local function tween(obj, time, props, style, direction)
	local t = TweenService:Create(
		obj,
		getTweenInfo(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function new(className, props, children)
	local inst = Instance.new(className)
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then parent = v else inst[k] = v end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(radius) return new("UICorner", { CornerRadius = UDim.new(0, radius) }) end
local function round() return new("UICorner", { CornerRadius = UDim.new(1, 0) }) end
local function stroke(color, transparency, thickness)
	return new("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end
local function pad(top, right, bottom, left)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
	})
end
local function label(props)
	local p = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = THEME.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}
	for k, v in pairs(props) do p[k] = v end
	return new("TextLabel", p)
end
local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end
local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function dragBus(window)
	local bus = window._DragBus
	if bus then return bus end
	bus = {}
	window._DragBus = bus
	table.insert(window.Connections, UserInputService.InputChanged:Connect(function(input)
		local a = bus.active
		if a and isMove(input) then a.move(input) end
	end))
	table.insert(window.Connections, UserInputService.InputEnded:Connect(function(input)
		local a = bus.active
		if a and isPress(input) then
			bus.active = nil
			if a.stop then a.stop() end
		end
	end))
	return bus
end

local function beginDrag(window, move, stop)
	local bus = dragBus(window)
	local prev = bus.active
	if prev and prev.stop then prev.stop() end
	bus.active = { move = move, stop = stop }
end

local function keyBus(window)
	local bus = window._KeyBus
	if bus then return bus end
	bus = { handlers = {} }
	window._KeyBus = bus
	table.insert(window.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local cap = bus.capture
		if cap then
			bus.capture = nil
			cap(input.KeyCode)
			return
		end
		if processed then return end
		local list = bus.handlers
		for i = 1, #list do list[i](input.KeyCode) end
	end))
	return bus
end

local function beginCapture(window, onKey)
	local bus = keyBus(window)
	bus.capture = onKey
end

local function onKeyPressed(window, fn)
	local bus = keyBus(window)
	table.insert(bus.handlers, fn)
end
local function fire(callback, ...)
	if type(callback) ~= "function" then return end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(callback, table.unpack(args, 1, args.n))
		if not ok then warn("[PYRA] callback error: " .. tostring(err)) end
	end)
end

local function valueBox(props)
	local p = {
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = FONT_MEDIUM,
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		ZIndex = 6,
	}
	for k, v in pairs(props) do p[k] = v end
	return new("TextBox", p, { corner(4), pad(0, 4, 0, 4) })
end

local function selectAll(box)
	box.CursorPosition = #box.Text + 1
	box.SelectionStart = 1
end

local function glassify(frame, transparency, radius)
	radius = radius or 12
	frame.BackgroundColor3 = THEME.Glass
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	corner(radius).Parent = frame
	stroke(Color3.new(1, 1, 1), 0.88).Parent = frame
	new("ImageLabel", {
		Name = "Noise",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "rbxassetid://9968344227",
		ImageTransparency = 0.94,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(128, 128),
		ZIndex = frame.ZIndex,
		Parent = frame,
	}, { corner(radius) })
	new("Frame", {
		Name = "Sheen",
		Size = UDim2.new(1, 0, 0.6, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
		ZIndex = frame.ZIndex,
		Parent = frame,
	}, {
		corner(radius),
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }),
	})
end

local acrylicDof
local function ensureDof()
	if acrylicDof and acrylicDof.Parent then return end
	acrylicDof = Instance.new("DepthOfFieldEffect")
	acrylicDof.Name = "PyraAcrylic"
	acrylicDof.FarIntensity = 0
	acrylicDof.NearIntensity = 1
	acrylicDof.InFocusRadius = 0.1
	acrylicDof.Enabled = false
	acrylicDof.Parent = Lighting
end

local function mapRange(v, inMin, inMax, outMin, outMax)
	return (v - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
end

local function moveAbs(inst, v)
	local ap = inst.AbsolutePosition
	local p = inst.Position
	inst.Position = UDim2.fromOffset(
		p.X.Offset + (v.X - ap.X),
		p.Y.Offset + (v.Y - ap.Y)
	)
end

local function screenToWorld(point, distance)
	local ray = camera:ScreenPointToRay(point.X, point.Y)
	return ray.Origin + ray.Direction * distance
end

local function createAcrylic(frame)
	ensureDof()
	local part = new("Part", {
		Name = "PyraGlass",
		Color = Color3.new(0, 0, 0),
		Material = Enum.Material.Glass,
		Size = Vector3.new(1, 1, 0),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
	})
	local mesh = new("SpecialMesh", {
		MeshType = Enum.MeshType.Brick,
		Offset = Vector3.new(0, 0, -1e-6),
		Parent = part,
	})
	part.Parent = workspace

	local obj = { Part = part, Visible = false }
	local lastT, lastCF, lastPos, lastSize, lastVpY, cachedInset, lastFov, lastStamp
	function obj:Update()
		if not self.Visible or not frame.Visible or frame.AbsoluteSize.X < 4 or frame.AbsoluteSize.Y < 4 then
			if lastT ~= 1 then part.Transparency = 1 lastT = 1 end
			return
		end
		if lastT ~= 0.98 then part.Transparency = 0.98 lastT = 0.98 end

		local vpY = camera.ViewportSize.Y
		if vpY ~= lastVpY then
			lastVpY = vpY
			cachedInset = mapRange(vpY, 0, 2560, 8, 56)
		end

		local cf = camera.CFrame
		local fov = camera.FieldOfView
		local aPos, aSize = frame.AbsolutePosition, frame.AbsoluteSize
		local now = os.clock()
		local stale = (lastStamp == nil) or ((now - lastStamp) > 0.2)
		if not stale and cf == lastCF and fov == lastFov and aPos == lastPos and aSize == lastSize then return end
		lastCF, lastFov, lastPos, lastSize, lastStamp = cf, fov, aPos, aSize, now

		local inset = cachedInset
		local size = aSize - Vector2.new(inset, inset)
		local pos = aPos + Vector2.new(inset / 2, inset / 2)
		local d = 0.001
		local tl = screenToWorld(pos, d)
		local tr = screenToWorld(pos + Vector2.new(size.X, 0), d)
		local br = screenToWorld(pos + size, d)
		part.CFrame = CFrame.fromMatrix((tl + br) / 2, cf.XVector, cf.YVector, cf.ZVector)
		mesh.Scale = Vector3.new((tr - tl).Magnitude, (tr - br).Magnitude, 0)
	end
	function obj:Destroy() part:Destroy() end
	return obj
end

local STATUS_GREEN = Color3.fromRGB(90, 220, 130)

local function runIntro(gui, onComplete)
	local overlay = new("Frame", {
		Name = "Intro",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1000,
		Parent = gui,
	})
	local blur = Instance.new("BlurEffect")
	blur.Name = "PyraBlur"
	blur.Size = 0
	blur.Parent = Lighting
	tween(blur, 0.5, { Size = 28 })
	playSound(SOUND_INTRO, 0.4)

	local logoHolder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 120),
		BackgroundTransparency = 1,
		ZIndex = 1001,
		Parent = overlay,
	})
	local logoScale = new("UIScale", { Scale = 0.6, Parent = logoHolder })

	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(96, 96),
		BackgroundTransparency = 1,
		ZIndex = 1001,
		Parent = logoHolder,
	}, { round(), stroke(THEME.Accent, 0.3, 2) })

	local pyramid = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Image = LOGO_ID,
		ImageColor3 = THEME.Accent,
		ImageTransparency = 1,
		ZIndex = 1002,
		Parent = logoHolder,
	})

	local pyraText = label({
		Text = "PYRA",
		Font = FONT_BOLD,
		TextSize = 32,
		TextColor3 = THEME.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 20),
		Size = UDim2.fromOffset(200, 40),
		ZIndex = 1002,
		Parent = logoHolder,
	})

	local tag = label({
		Text = "I N T E R F A C E",
		Font = FONT_MEDIUM,
		TextSize = 10,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 60),
		Size = UDim2.fromOffset(200, 14),
		ZIndex = 1002,
		Parent = logoHolder,
	})

	tween(logoScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.1, function()
		tween(pyramid, 0.45, { Size = UDim2.fromOffset(56, 56), ImageTransparency = 0 }, Enum.EasingStyle.Back)
	end)
	task.delay(0.35, function()
		tween(pyraText, 0.4, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 1, 10) })
	end)
	task.delay(0.5, function()
		tween(tag, 0.4, { TextTransparency = 0.3, Position = UDim2.new(0.5, 0, 1, 50) })
	end)

	local spin
	spin = RunService.RenderStepped:Connect(function(dt)
		if not ring.Parent then spin:Disconnect() return end
		ring.Rotation = (ring.Rotation + dt * 90) % 360
	end)

	task.delay(1.8, function()
		tween(logoScale, 0.35, { Scale = 1.15 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(pyramid, 0.3, { ImageTransparency = 1 })
		tween(pyraText, 0.3, { TextTransparency = 1 })
		tween(tag, 0.3, { TextTransparency = 1 })
		local ringStroke = ring:FindFirstChildOfClass("UIStroke")
		if ringStroke then tween(ringStroke, 0.3, { Transparency = 1 }) end

		task.wait(0.3)
		tween(blur, 0.6, { Size = 0 })
		playSound(SOUND_OUTRO, 0.35)

		if onComplete then task.spawn(onComplete) end

		task.wait(0.65)
		blur:Destroy()
		overlay:Destroy()
	end)
end

local Library = {}
Library.__index = Library

local Tab = {}
Tab.__index = Tab

function Library.new(config)
	config = config or {}
	local self = setmetatable({}, Library)
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightShift
	self.Tabs = {}
	self.ActiveTab = nil
	self.Open = false
	self.Minimized = false
	self.ScaleMultiplier = 1
	self.Connections = {}

	self.SessionStart = (type(config.SessionStart) == "number" and config.SessionStart > 0) and config.SessionStart or nil
	self.IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	self.AcrylicEnabled = not self.IsMobile
	self.WorldDimEnabled = true
	self.WorldDimPersistent = false
	self.ParallaxEnabled = false
	self.Parallax = Vector2.zero
	self.ParallaxVelocity = Vector2.zero
	self.SuppressedDof = {}

	if _G.__PYRA_ACTIVE then
		pcall(function() _G.__PYRA_ACTIVE:Destroy() end)
		_G.__PYRA_ACTIVE = nil
	end

	local guiParent = getGuiParent()
	for _, c in ipairs(guiParent:GetChildren()) do
		if c.Name == "PyraUI" then c:Destroy() end
	end
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name == "PyraGlass" then c:Destroy() end
	end
	for _, c in ipairs(Lighting:GetChildren()) do
		if c.Name == "PyraAcrylic" or c.Name == "PyraGrade" or c.Name == "PyraBlur" then c:Destroy() end
	end
	for _, c in ipairs(SoundService:GetChildren()) do
		if c.Name == "PyraSound" then c:Destroy() end
	end

	self.Gui = new("ScreenGui", {
		Name = "PyraUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
	})

	self.Grade = new("ColorCorrectionEffect", { Name = "PyraGrade", Parent = Lighting })

	self.TargetPosition = UDim2.fromScale(0.5, 0.5)
	self.Base = self.TargetPosition
	self.Holder = new("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = self.TargetPosition,
		Size = UDim2.fromOffset(WINDOW_W, DOCK_H + GAP + PANEL_H + GAP + FOOTER_H),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.Gui,
	})
	self.UIScale = new("UIScale", { Scale = 0, Parent = self.Holder })

	local shadow = new("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 64, 1, 64),
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.42,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		ZIndex = 0,
		Parent = self.Holder,
	})

	self.Dock = new("Frame", {
		Name = "Dock",
		Size = UDim2.new(1, 0, 0, DOCK_H),
		Active = true,
		ZIndex = 1,
		Parent = self.Holder,
	})
	glassify(self.Dock, GLASS_DOCK_T, 12)

	self.Panel = new("Frame", {
		Name = "Panel",
		Position = UDim2.new(0, 0, 0, DOCK_H + GAP),
		Size = UDim2.new(1, 0, 0, PANEL_H),
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = self.Holder,
	})
	glassify(self.Panel, GLASS_PANEL_T, 14)

	local logo = new("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Image = LOGO_ID,
		ImageColor3 = THEME.Accent,
		ZIndex = 3,
		Parent = self.Dock,
	})
	TweenService:Create(
		logo,
		TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = 8 }
	):Play()
	label({
		Text = config.Title or "PYRA",
		Font = FONT_BOLD,
		TextSize = 14,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 42, 0.5, 0),
		Size = UDim2.fromOffset(60, 20),
		ZIndex = 3,
		Parent = self.Dock,
	})

	self.TabBar = new("Frame", {
		Name = "TabBar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 108, 0.5, 0),
		Size = UDim2.fromOffset(0, TAB_H),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = self.Dock,
	})
	self.TabBarWidth = 0
	self.Pill = new("Frame", {
		Name = "Pill",
		Size = UDim2.fromOffset(60, TAB_H),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
		Parent = self.TabBar,
	}, { corner(8) })

	local function dockButton(text, xOffset, iconId)
		local useIcon = type(iconId) == "string" and iconId ~= ""
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = THEME.Card,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = useIcon and "" or text,
			Font = FONT_MEDIUM,
			TextSize = 17,
			TextColor3 = THEME.SubText,
			ZIndex = 12,
			Parent = self.Dock,
		}, { corner(8) })
		local img
		if useIcon then

			img = new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				ImageTransparency = 0,
				Image = iconId,
				ImageColor3 = THEME.SubText,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 13,
				Parent = b,
			})
		end
		b.MouseEnter:Connect(function()
			tween(b, 0.2, { BackgroundTransparency = 0.9, TextColor3 = THEME.Text })
			if img then tween(img, 0.2, { ImageColor3 = THEME.Text }) end
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.2, { BackgroundTransparency = 1, TextColor3 = THEME.SubText })
			if img then tween(img, 0.2, { ImageColor3 = THEME.SubText }) end
		end)
		return b
	end
	local closeButton = dockButton("×", -8, ICONS.Close)
	self.MinButton = dockButton("-", -40, ICONS.Minimize)
	self.MinButtonIcon = self.MinButton:FindFirstChildOfClass("ImageLabel")
	closeButton.Activated:Connect(function() self:Hide() end)
	self.MinButton.Activated:Connect(function() self:SetMinimized(not self.Minimized) end)

	self.SearchIndex = {}
	local searchOpen = false
	local COLLAPSED, EXPANDED = 28, 150

	local search = new("Frame", {
		Name = "Search",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -78, 0.5, 0),
		Size = UDim2.fromOffset(COLLAPSED, 28),
		BackgroundColor3 = THEME.Card,

		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = self.Dock,
	}, { corner(8), stroke(Color3.new(1, 1, 1), 1) })
	local searchStroke = search:FindFirstChildOfClass("UIStroke")
	local useSearchIcon = type(ICONS.Search) == "string" and ICONS.Search ~= ""

	local ICON_COLLAPSED_POS = UDim2.new(0.5, 0, 0.5, 0)
	local ICON_EXPANDED_POS = UDim2.new(1, -6, 0.5, 0)
	local icon = label({
		Text = useSearchIcon and "" or "⌕", Font = FONT_BOLD, TextSize = 20, TextColor3 = THEME.SubText,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = ICON_COLLAPSED_POS,
		Size = UDim2.fromOffset(22, 24), TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9, Parent = search,
	})
	local searchImg
	if useSearchIcon then
		searchImg = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = ICON_COLLAPSED_POS,
			Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
			Image = ICONS.Search, ImageColor3 = THEME.Body, ZIndex = 9, Parent = search,
		})
		icon:GetPropertyChangedSignal("TextColor3"):Connect(function()
			searchImg.ImageColor3 = icon.TextColor3
		end)
	end
	local searchBox = new("TextBox", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = FONT,
		TextSize = 12,
		TextColor3 = THEME.Text,
		PlaceholderText = "Search settings...",
		PlaceholderColor3 = THEME.Muted,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextEditable = false,
		Visible = false,
		ZIndex = 6,
		Parent = search,
	})
	local iconBtn = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 10, Parent = search,
	})

	local function setTabIconsHidden(hidden)
		if not self.TabIcons then return end
		for _, e in ipairs(self.TabIcons) do
			e.holder.Active = not hidden
			e.holder.AutoButtonColor = false
			tween(e.img, 0.2, { ImageTransparency = hidden and 1 or 0 })
		end
	end

	local function setSearch(open)
		if open == searchOpen then return end
		searchOpen = open
		setTabIconsHidden(open)
		if open then
			searchBox.Visible = true
			searchBox.TextEditable = true
			tween(search, 0.3, { Size = UDim2.fromOffset(EXPANDED, 28), BackgroundTransparency = 0.92 }, Enum.EasingStyle.Quint)
			tween(searchStroke, 0.3, { Transparency = 0.82 })
			tween(icon, 0.2, { TextColor3 = THEME.Text, Position = ICON_EXPANDED_POS })
			if searchImg then tween(searchImg, 0.2, { Position = ICON_EXPANDED_POS }) end
			task.delay(0.12, function() if searchOpen then searchBox:CaptureFocus() end end)
			playSound(SOUND_CLICK, 0.22, 1.1)
		else
			searchBox.Text = ""
			searchBox.TextEditable = false
			searchBox.Visible = false

			tween(search, 0.3, { Size = UDim2.fromOffset(COLLAPSED, 28), BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
			tween(searchStroke, 0.3, { Transparency = 1, Color = Color3.new(1, 1, 1) })
			tween(icon, 0.2, { TextColor3 = THEME.SubText, Position = ICON_COLLAPSED_POS })
			if searchImg then tween(searchImg, 0.2, { Position = ICON_COLLAPSED_POS }) end
			self:_hideSearchPage()
		end
	end
	self._collapseSearch = function() setSearch(false) end

	iconBtn.MouseEnter:Connect(function()
		if not searchOpen then tween(search, 0.2, { BackgroundTransparency = 0.9 }) end
		if icon then tween(icon, 0.2, { TextColor3 = THEME.Text }) end
	end)
	iconBtn.MouseLeave:Connect(function()
		if not searchOpen then tween(search, 0.2, { BackgroundTransparency = 1 }) end
		if icon then tween(icon, 0.2, { TextColor3 = THEME.SubText }) end
	end)

	iconBtn.Activated:Connect(function()
		if self.Minimized then self:SetMinimized(false) end
		if searchOpen then searchBox:CaptureFocus() else setSearch(true) end
	end)
	local searchToken = 0
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = searchBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		searchToken += 1
		local token = searchToken
		if q ~= "" then
			tween(searchStroke, 0.2, { Transparency = 0.3, Color = THEME.Accent })
			self:_showSearchPage()
			local text = searchBox.Text
			task.delay(0.05, function()
				if token ~= searchToken or self.Destroyed then return end
				self:_updateSearchPage(text)
			end)
		else
			tween(searchStroke, 0.2, { Transparency = 0.82, Color = Color3.new(1, 1, 1) })
			self:_hideSearchPage()
		end
	end)
	searchBox.FocusLost:Connect(function()
		task.wait(0.15)
		if searchBox.Text == "" and not self._searchActive then setSearch(false) end
	end)
	self.SearchBar = search

	self.Content = new("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = self.Panel,
	})

	self.ContentHighlight = new("Frame", {
		Name = "ContentHighlight",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = self.Content,
	}, { corner(12) })

	self.SearchPage = new("CanvasGroup", {
		Name = "SearchPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 4,
		Parent = self.Content,
	})
	self.SearchList = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 4,
		Parent = self.SearchPage,
	}, {
		pad(12, 14, 12, 14),
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({
		Text = "SEARCH RESULTS", Font = FONT_BOLD, TextSize = 10, TextColor3 = THEME.SubText,
		Size = UDim2.new(1, 0, 0, 18), TextYAlignment = Enum.TextYAlignment.Bottom,
		LayoutOrder = 0, ZIndex = 5, Parent = self.SearchList,
	})

	self.FooterY = DOCK_H + GAP + PANEL_H + GAP
	self.Footer = new("Frame", {
		Name = "Footer",
		Position = UDim2.new(0, 0, 0, self.FooterY),
		Size = UDim2.new(1, 0, 0, FOOTER_H),
		ZIndex = 1,
		Parent = self.Holder,
	})
	glassify(self.Footer, GLASS_DOCK_T, 12)

	local avatar = new("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = THEME.Switch,
		ZIndex = 3,
		Parent = self.Footer,
	}, { round(), stroke(Color3.new(1, 1, 1), 0.8) })
	local onlineDot = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 1, 1, 1),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = STATUS_GREEN,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = avatar,
	}, { round(), stroke(THEME.Glass, 0, 2) })
	TweenService:Create(
		onlineDot,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.45 }
	):Play()
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then avatar.Image = image end
	end)
	label({
		Text = player.DisplayName, Font = FONT_BOLD, TextSize = 13,
		Position = UDim2.new(0, 50, 0.5, -15), Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3, Parent = self.Footer,
	})
	local useDiamond = type(ICONS.Diamond) == "string" and ICONS.Diamond ~= ""
	local diamond
	if useDiamond then
		diamond = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 58, 0.5, 9),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Image = ICONS.Diamond,
			ImageColor3 = THEME.Premium,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
			Parent = self.Footer,
		})
		TweenService:Create(
			diamond,
			TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ ImageTransparency = 0.35 }
		):Play()
	else
		diamond = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 54, 0.5, 9),
			Size = UDim2.fromOffset(6, 6),
			Rotation = 45,
			BackgroundColor3 = THEME.Premium,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = self.Footer,
		}, { corner(1) })
		TweenService:Create(
			diamond,
			TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.35 }
		):Play()
	end
	label({
		Text = "P R E M I U M", Font = FONT_BOLD, TextSize = 11,
		TextColor3 = Color3.fromRGB(240, 200, 60),
		TextTransparency = 0.1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 70, 0.5, 9), Size = UDim2.fromOffset(0, 16),
		TextYAlignment = Enum.TextYAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3, Parent = self.Footer,
	})

	local stats = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(1, -200, 1, -12),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = self.Footer,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local chipOrder = 0
	local function chip(caption, value)
		chipOrder += 1
		if chipOrder > 1 then
			new("Frame", {
				Size = UDim2.fromOffset(1, 22),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.88,
				BorderSizePixel = 0,
				LayoutOrder = chipOrder * 2 - 1,
				ZIndex = 3,
				Parent = stats,
			})
		end
		local c = new("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = chipOrder * 2,
			ZIndex = 3,
			Parent = stats,
		}, {
			new("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 1),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		label({
			Text = caption, Font = FONT_BOLD, TextSize = 9, TextColor3 = THEME.SubText,
			Size = UDim2.fromOffset(0, 11), AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1, ZIndex = 3, Parent = c,
		})
		return label({
			Text = value, Font = FONT_MEDIUM, TextSize = 12, RichText = true,
			Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2, ZIndex = 3, Parent = c,
		})
	end

	self.StatusColor = (typeof(config.StatusColor) == "Color3") and config.StatusColor or STATUS_GREEN
	self.StatusText = config.Status or "Manual"
	local statusHex = self.StatusColor:ToHex()
	self.StatusValue = chip("STATUS", string.format('<font color="#%s">●</font> %s', statusHex, self.StatusText))
	self.ExpiryValue = chip("EXPIRES", config.Expiry or "12/21/2036")
	local pingValue = chip("PING", "-- ms")
	local fpsValue = chip("FPS", "--")
	local sessionValue = chip("SESSION", "00:00:00")

	local sessionStart = os.clock()
	local frameCount, frameClock = 0, os.clock()
	table.insert(self.Connections, RunService.RenderStepped:Connect(function()
		frameCount += 1
	end))
	task.spawn(function()
		while not self.Destroyed do
			local now = os.clock()
			if not self.Open then
				frameCount, frameClock = 0, now
				task.wait(0.75)
			else
				fpsValue.Text = tostring(math.floor(frameCount / math.max(now - frameClock, 1e-3) + 0.5))
				frameCount, frameClock = 0, now
				local ok, ping = pcall(function() return player:GetNetworkPing() end)
				pingValue.Text = ok and (math.floor(ping * 1000 + 0.5) .. " ms") or "-- ms"

				local e
				if self.SessionStart then
					e = math.max(0, math.floor(os.time() - self.SessionStart))
				else
					e = math.floor(now - sessionStart)
				end
				sessionValue.Text = string.format("%02d:%02d:%02d", e // 3600, (e % 3600) // 60, e % 60)
				task.wait(0.75)
			end
		end
	end)

	self.OpenButton = new("TextButton", {
		Name = "OpenButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = THEME.Glass,
		BackgroundTransparency = SOLID_T,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = self.Gui,
	}, { round(), stroke(Color3.new(1, 1, 1), 0.85) })
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Image = LOGO_ID,
		ImageColor3 = THEME.Accent,
		Parent = self.OpenButton,
	})
	self.OpenButtonScale = new("UIScale", { Scale = 0, Parent = self.OpenButton })
	self.OpenButton.Activated:Connect(function() self:Show() end)

	self.MobileMode = false
	self.MobileButtons = {}
	self.MobileHolder = new("Frame", {
		Name = "MobileOverlay",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(196, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.Gui,
	}, {
		new("UIListLayout", {
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	self.NotifyHolder = new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 310, 1, -32),
		BackgroundTransparency = 1,
		Parent = self.Gui,
	}, {
		new("UIListLayout", {
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.NotifyCount = 0

	self.Acrylic = { createAcrylic(self.Dock), createAcrylic(self.Panel), createAcrylic(self.Footer) }

	local dragging, dragStart, startPos = false, nil, nil
	self.Dock.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		dragging = true
		dragStart = input.Position
		startPos = self.TargetPosition
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				conn:Disconnect()
			end
		end)
	end)
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local delta = input.Position - dragStart
			self.TargetPosition = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))

	local glassWasOn = false
	local lastShadow = Vector2.new(math.huge, 0)
	table.insert(self.Connections, RunService.RenderStepped:Connect(function(dt)
		local glassOn = self.AcrylicEnabled and self.Open and self.UIScale.Scale > 0.05
		if glassOn then
			if acrylicDof and not acrylicDof.Enabled then acrylicDof.Enabled = true end
			for _, a in ipairs(self.Acrylic) do
				a.Visible = true
				a:Update()
			end
		elseif glassWasOn then
			if acrylicDof then acrylicDof.Enabled = false end
			for _, a in ipairs(self.Acrylic) do
				a.Visible = false
				a:Update()
			end
		end
		glassWasOn = glassOn

		if not self.Holder.Visible then return end

		local step = math.min(dt, 1 / 30)
		local goalParallax = Vector2.zero
		if self.ParallaxEnabled and self.Open and not dragging then
			local vp = camera.ViewportSize
			local m = UserInputService:GetMouseLocation()
			local nx = math.clamp((m.X - vp.X / 2) / (vp.X / 2), -1, 1)
			local ny = math.clamp((m.Y - vp.Y / 2) / (vp.Y / 2), -1, 1)

			goalParallax = Vector2.new(-nx, -ny) * PARALLAX_STRENGTH
		end

		local b, t = self.Base, self.TargetPosition
		if b.X.Scale == t.X.Scale and b.Y.Scale == t.Y.Scale
			and math.abs(b.X.Offset - t.X.Offset) < 0.5
			and math.abs(b.Y.Offset - t.Y.Offset) < 0.5
			and self.ParallaxVelocity.Magnitude < 0.01
			and (goalParallax - self.Parallax).Magnitude < 0.01 then
			self.Base = t
			self.Parallax = goalParallax
			self.ParallaxVelocity = Vector2.zero
			local rest = t + UDim2.fromOffset(goalParallax.X, goalParallax.Y)
			if rest ~= self.Holder.Position then self.Holder.Position = rest end
			return
		end

		local accel = (goalParallax - self.Parallax) * PARALLAX_STIFFNESS - self.ParallaxVelocity * PARALLAX_DAMPING
		self.ParallaxVelocity += accel * step
		self.Parallax += self.ParallaxVelocity * step

		self.Base = self.Base:Lerp(self.TargetPosition, math.clamp(dt * 18, 0, 1))
		local final = self.Base + UDim2.fromOffset(self.Parallax.X, self.Parallax.Y)
		if final ~= self.Holder.Position then self.Holder.Position = final end

		if (self.Parallax - lastShadow).Magnitude > 0.02 then
			lastShadow = self.Parallax
			shadow.Position = UDim2.new(0.5, -self.Parallax.X * 0.9, 0.5, -self.Parallax.Y * 0.9)
			self.Content.Position = UDim2.fromOffset(self.Parallax.X * PARALLAX_DEPTH, self.Parallax.Y * PARALLAX_DEPTH)
		end
	end))

	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == self.ToggleKey then self:Toggle() end
	end))
	table.insert(self.Connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if self.Open then tween(self.UIScale, 0.3, { Scale = self:_fitScale() }) end
	end))

	if not self.AcrylicEnabled then
		self.Dock.BackgroundTransparency = SOLID_T
		self.Panel.BackgroundTransparency = SOLID_T
		self.Footer.BackgroundTransparency = SOLID_T
	end

	self.Gui.Parent = guiParent
	protect(self.Gui)

	_G.__PYRA_ACTIVE = self

	runIntro(self.Gui, function() self:Show() end)

	return self
end

function Library:_fitScale()
	local vp = camera.ViewportSize
	local h = DOCK_H + GAP + PANEL_H + GAP + FOOTER_H
	local fit = math.min((vp.X - 28) / WINDOW_W, (vp.Y - 28) / h, 1)
	return math.max(fit, 0.45) * self.ScaleMultiplier
end

function Library:_suppressOtherDof(state)
	if state then
		local function grab(container)
			for _, d in ipairs(container:GetChildren()) do
				if d:IsA("DepthOfFieldEffect") and d ~= acrylicDof and self.SuppressedDof[d] == nil then
					self.SuppressedDof[d] = d.Enabled
					d.Enabled = false
				end
			end
		end
		grab(Lighting)
		grab(camera)
	else
		for d, was in pairs(self.SuppressedDof) do
			if d.Parent then d.Enabled = was end
		end
		self.SuppressedDof = {}
	end
end

function Library:_applyWorld(open)
	local dim = self.WorldDimEnabled and (open or self.WorldDimPersistent)
	if dim then
		tween(self.Grade, 0.7, { Saturation = -0.5, Contrast = -0.03, Brightness = -0.09 }, Enum.EasingStyle.Sine)
	else
		tween(self.Grade, 0.5, { Saturation = 0, Contrast = 0, Brightness = 0 }, Enum.EasingStyle.Sine)
	end
	self:_suppressOtherDof(open and self.AcrylicEnabled)
end

function Library:Show()
	if self.Open then return end
	self.Open = true
	self.Holder.Visible = true
	tween(self.UIScale, 0.55, { Scale = self:_fitScale() }, Enum.EasingStyle.Back)
	tween(self.OpenButtonScale, 0.2, { Scale = 0 })
	task.delay(0.2, function()
		if self.Open then self.OpenButton.Visible = false end
	end)
	self:_applyWorld(true)
	if self.SidePanels then
		for _, p in ipairs(self.SidePanels) do pcall(p._uiShown, p) end
	end
end

function Library:Hide()
	if not self.Open then return end
	self.Open = false
	local t = tween(self.UIScale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	t.Completed:Connect(function()
		if not self.Open then self.Holder.Visible = false end
	end)
	self.OpenButton.Visible = true
	tween(self.OpenButtonScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	self:_applyWorld(false)
	if self.SidePanels then
		for _, p in ipairs(self.SidePanels) do pcall(p._uiHidden, p) end
	end
	self:Notify("Interface hidden", "Press " .. self.ToggleKey.Name .. " to open it again.", 5)
end

function Library:Toggle()
	if self.Open then self:Hide() else self:Show() end
end

function Library:SetMinimized(state)
	if state == self.Minimized then return end
	self.Minimized = state

	if self.MinButtonIcon then
		if state then
			self.MinButtonIcon.Image = ICONS.Close
			self.MinButtonIcon.Rotation = 45
		else
			self.MinButtonIcon.Image = ICONS.Minimize
			self.MinButtonIcon.Rotation = 0
		end
	end

	local fullH = DOCK_H + GAP + PANEL_H + GAP + FOOTER_H
	local miniH = DOCK_H + GAP + FOOTER_H

	local dockUsed = 108 + (self.TabBarWidth or 0) + 48 + 88
	local miniW = math.clamp(dockUsed, 320, WINDOW_W)

	if state then
		if self._closeSearch then self:_closeSearch() end
		if self.SearchBar then self.SearchBar.Visible = false end
		tween(self.Panel, 0.35, { Size = UDim2.new(1, 0, 0, 0) }).Completed:Connect(function()
			if self.Minimized then self.Panel.Visible = false end
		end)
		tween(self.Footer, 0.35, { Position = UDim2.new(0, 0, 0, DOCK_H + GAP) })
		tween(self.Holder, 0.4, { Size = UDim2.fromOffset(miniW, miniH) }, Enum.EasingStyle.Quint)
	else
		if self.SearchBar then self.SearchBar.Visible = true end
		self.Panel.Visible = true
		tween(self.Panel, 0.4, { Size = UDim2.new(1, 0, 0, PANEL_H) })
		tween(self.Footer, 0.4, { Position = UDim2.new(0, 0, 0, self.FooterY) })
		tween(self.Holder, 0.4, { Size = UDim2.fromOffset(WINDOW_W, fullH) }, Enum.EasingStyle.Quint)
	end
end

function Library:SetToggleKey(key)
	if typeof(key) ~= "EnumItem" then return end
	self.ToggleKey = key
	for _, fn in ipairs(self.ToggleKeyListeners or {}) do task.spawn(fn, key) end
end

function Library:OnToggleKeyChanged(fn)
	self.ToggleKeyListeners = self.ToggleKeyListeners or {}
	table.insert(self.ToggleKeyListeners, fn)
	task.spawn(fn, self.ToggleKey)
end

function Library:_ensureMonitorBar()
	if self.MonitorBar then return self.MonitorBar end
	local HOME = UDim2.new(0.5, 0, 0, 12)
	self.MonitorHome = HOME
	local bar = new("Frame", {
		Name = "MonitorBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = HOME,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.Glass,
		BackgroundTransparency = self.IsMobile and SOLID_T or GLASS_DOCK_T,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		Parent = self.Gui,
	}, {
		corner(8),
		stroke(Color3.new(1, 1, 1), 0.86),
		pad(0, 10, 0, 10),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	if not self.IsMobile then
		self.MonitorAcrylic = createAcrylic(bar)
		table.insert(self.Acrylic, self.MonitorAcrylic)
	end
	self.MonitorBar = bar
	self.MonitorOrder = {}
	self.MonitorItems = {}
	self.MonitorCount = 0

	local dragging, dragStart, startOff
	bar.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		dragging = true
		dragStart = input.Position
		startOff = Vector2.new(bar.Position.X.Offset, bar.Position.Y.Offset)
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false conn:Disconnect() end
		end)
	end)
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local d = input.Position - dragStart
			bar.Position = UDim2.new(HOME.X.Scale, startOff.X + d.X, HOME.Y.Scale, startOff.Y + d.Y)
		end
	end))
	return bar
end

function Library:_refreshMonitorSeparators()
	local shownItems = {}
	for _, it in ipairs(self.MonitorOrder) do
		if it.shown then table.insert(shownItems, it) end
	end
	local wanted = {}
	for i = 2, #shownItems do wanted[shownItems[i].sep] = true end
	for _, it in ipairs(self.MonitorOrder) do
		local sep = it.sep
		if wanted[sep] then
			if not sep.Visible then
				sep.Visible = true
				sep.BackgroundTransparency = 1
				tween(sep, 0.22, { BackgroundTransparency = 0.86 })
			end
		elseif sep.Visible then
			sep.Visible = false
			sep.BackgroundTransparency = 0.86
		end
	end

	local any = #shownItems > 0
	local bar = self.MonitorBar
	if any and not bar.Visible then
		bar.Visible = true
		bar.Position = self.MonitorHome + UDim2.fromOffset(0, -10)
		tween(bar, 0.3, { Position = self.MonitorHome }, Enum.EasingStyle.Back)
	elseif not any and bar.Visible then
		bar.Visible = false
		bar.Position = self.MonitorHome
		if self.MonitorAcrylic then
			self.MonitorAcrylic.Visible = false
			pcall(function() self.MonitorAcrylic:Update() end)
		end
	end
end

function Library:CreateSidePanel(opts)
	opts = opts or {}
	local W = opts.Width or 230
	local panel = {}

	local root = new("CanvasGroup", {
		Name = "SidePanel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(W, 300),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Glass,
		BackgroundTransparency = self.IsMobile and SOLID_T or GLASS_PANEL_T,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 80,
		Parent = self.Gui,
	}, { corner(12), stroke(Color3.new(1, 1, 1), 0.88) })
	if not self.IsMobile then
		local a = createAcrylic(root)
		table.insert(self.Acrylic, a)
	end

	new("ImageLabel", {
		Name = "Noise", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Image = "rbxassetid://9968344227", ImageTransparency = 0.94,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(128, 128),
		ZIndex = 2, Parent = root,
	}, { corner(12) })

	local header = new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = root,
	})
	local title = label({
		Text = opts.Title or "Target Info", Font = FONT_BOLD, TextSize = 14,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -72, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = header,
	})

	local pinned = opts.Pinned == true
	local pinBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 4,
		Parent = header,
	}, { corner(7) })
	local usePinIcon = type(ICONS.Pin) == "string" and ICONS.Pin ~= ""
	local pinImg, pinGlyph
	if usePinIcon then
		pinImg = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
			Image = ICONS.Pin, ImageColor3 = THEME.SubText, ZIndex = 5, Parent = pinBtn,
		})
	else
		pinGlyph = label({
			Text = "📌", TextSize = 13, Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Parent = pinBtn,
		})
	end

	local body = new("Frame", {
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = root,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 12),
		}),
	})

	local DEFAULT_AVATAR = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150"
	local avatar = new("ImageLabel", {
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = THEME.Switch,
		Image = DEFAULT_AVATAR,
		LayoutOrder = 0,
		ZIndex = 4,
		Parent = body,
	}, { round(), stroke(Color3.new(1, 1, 1), 0.85) })
	local avatarWrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		ZIndex = 4,
		Parent = body,
	})
	avatar.Parent = avatarWrap
	avatar.AnchorPoint = Vector2.new(0.5, 0)
	avatar.Position = UDim2.new(0.5, 0, 0, 4)

	local rows = {}
	local function addStat(key)
		local r = new("Frame", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			LayoutOrder = #rows + 1,
			ZIndex = 4,
			Parent = body,
		})
		label({
			Text = key, Font = FONT_MEDIUM, TextSize = 11, TextColor3 = THEME.SubText,
			Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.42, 0, 1, 0), ZIndex = 5, Parent = r,
		})
		local v = label({
			Text = "-", Font = FONT_MEDIUM, TextSize = 12, TextColor3 = THEME.Text,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.58, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = r,
		})
		rows[key] = v
		return v
	end

	function panel:SetAvatar(userId)
		task.spawn(function()
			local ok, img = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok then avatar.Image = img end
		end)
	end
	function panel:SetTitle(t) title.Text = t end
	function panel:SetStat(key, value, color)
		if not rows[key] then addStat(key) end
		local r = rows[key]
		r.Text = tostring(value)
		r.TextColor3 = color or THEME.Text
	end
	function panel:ClearAvatar() avatar.Image = DEFAULT_AVATAR end

	local win = self

	local shown = false
	local detached = false
	local dragging = false
	local target = Vector2.new()

	local function setAbs(v) moveAbs(root, v) end

	local lastDock = nil
	local function dockTopLeft()
		local h = win.Holder
		local hp, hs = h.AbsolutePosition, h.AbsoluteSize
		if hs.X < 8 or hs.Y < 8 then
			return lastDock or Vector2.new(hp.X + 16, hp.Y)
		end
		lastDock = Vector2.new(hp.X + hs.X + 16, hp.Y + hs.Y / 2 - root.AbsoluteSize.Y / 2)
		return lastDock
	end

	local function hideTopLeft()
		local cam = workspace.CurrentCamera
		local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
		local d = dockTopLeft()
		return Vector2.new(vp.X + 30, d.Y)
	end

	setAbs(hideTopLeft())

	local driveConn = RunService.RenderStepped:Connect(function(dt)
		if not root.Visible then return end
		if dragging or detached then return end

		if shown then target = dockTopLeft() end
		local cur = root.AbsolutePosition
		local dx, dy = target.X - cur.X, target.Y - cur.Y
		if dx * dx + dy * dy < 0.25 then
			if dx ~= 0 or dy ~= 0 then setAbs(target) end
			return
		end
		local a = math.clamp(dt * 16, 0, 1)
		local p = root.Position
		root.Position = UDim2.fromOffset(p.X.Offset + dx * a, p.Y.Offset + dy * a)
	end)
	table.insert(self.Connections, driveConn)

	local fadeTok = 0
	local function fadeTo(t)
		fadeTok += 1
		TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { GroupTransparency = t }):Play()
	end

	function panel:Show()
		if detached then return end
		if shown then return end
		shown = true
		if not root.Visible then
			setAbs(hideTopLeft())
			root.GroupTransparency = 1
		end
		root.Visible = true
		target = dockTopLeft()
		fadeTo(0)
	end
	function panel:Hide()
		if detached then return end
		if not shown then return end
		shown = false
		target = hideTopLeft()
		fadeTo(1)
		local myTok = fadeTok
		task.delay(0.4, function()
			if myTok == fadeTok and not shown and not detached then root.Visible = false end
		end)
	end

	local function detach()
		if detached then return end
		detached = true
		shown = true
		root.Visible = true
		root.GroupTransparency = 0
		playSound(SOUND_CLICK, 0.3, 1.2)
		if opts.OnDetach then opts.OnDetach(true) end
	end
	local function reattach()
		if not detached then return end
		detached = false

		target = dockTopLeft()
		playSound(SOUND_CLICK, 0.3, 0.9)
		if opts.OnDetach then opts.OnDetach(false) end

		if win.ActiveTab ~= panel._homeTab and not pinned then
			task.delay(0.28, function() if not detached then panel:Hide() end end)
		end
	end

	function panel:IsDetached() return detached end
	function panel:IsPinned() return pinned end
	local pinSel = type(ICONS.Pin_Selected) == "string" and ICONS.Pin_Selected ~= ""
	local function applyPin()
		if pinImg then
			if pinSel then pinImg.Image = pinned and ICONS.Pin_Selected or ICONS.Pin end
			pinImg.ImageColor3 = pinned and THEME.Accent or THEME.SubText
		end
		if pinGlyph then pinGlyph.TextTransparency = pinned and 0 or 0.4 end
	end
	function panel:SetPinned(on)
		pinned = on == true
		applyPin()
		if opts.OnPin then opts.OnPin(pinned) end
	end

	pinBtn.Activated:Connect(function() panel:SetPinned(not pinned) end)
	pinBtn.MouseEnter:Connect(function() if not pinned and pinImg then tween(pinImg, 0.15, { ImageColor3 = THEME.Text }) end end)
	pinBtn.MouseLeave:Connect(function() if not pinned and pinImg then tween(pinImg, 0.15, { ImageColor3 = THEME.SubText }) end end)

	local dragHandle = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Active = true,
		ZIndex = 1,
		Parent = root,
	})

	local dragStart = nil
	local grabOffset = nil
	local DETACH_THRESHOLD = 20
	local DOCK_SNAP_RADIUS = 130

	local function followCursor(mouse)
		if not grabOffset then return end
		setAbs(mouse - grabOffset)
	end

	local rootStroke = root:FindFirstChildOfClass("UIStroke")
	local snapLit = false
	local function snapColor()
		local t = panel._homeTab or win.ActiveTab
		return (t and t.Accent) or THEME.Accent
	end

	local ghost = new("Frame", {
		Name = "SidePanelDock",
		Size = UDim2.fromOffset(W, 120),
		BackgroundColor3 = THEME.Glass,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 78,
		Parent = self.Gui,
	}, { corner(12), stroke(Color3.new(1, 1, 1), 1) })
	local ghostStroke = ghost:FindFirstChildOfClass("UIStroke")

	local function setSnapHint(on)
		if on == snapLit then return end
		snapLit = on
		local c = snapColor()
		if rootStroke then
			tween(rootStroke, 0.15, {
				Color = on and c or Color3.new(1, 1, 1),
				Transparency = on and 0.25 or 0.88,
			})
		end
		if on then
			ghost.Size = UDim2.fromOffset(W, math.max(60, root.AbsoluteSize.Y))
			ghost.Visible = true
			moveAbs(ghost, dockTopLeft())
			ghost.BackgroundColor3 = c
			ghostStroke.Color = c
			tween(ghost, 0.15, { BackgroundTransparency = 0.9 })
			tween(ghostStroke, 0.15, { Transparency = 0.35 })
		else
			tween(ghost, 0.15, { BackgroundTransparency = 1 })
			tween(ghostStroke, 0.15, { Transparency = 1 })
			task.delay(0.16, function() if not snapLit then ghost.Visible = false end end)
		end
	end

	dragHandle.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		if dragging then return end
		dragging = true
		dragStart = Vector2.new(input.Position.X, input.Position.Y)
		grabOffset = dragStart - root.AbsolutePosition
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState ~= Enum.UserInputState.End then return end
			conn:Disconnect()
			dragging = false
			setSnapHint(false)
			if not detached then return end
			local tl = root.AbsolutePosition
			if (tl - dockTopLeft()).Magnitude < DOCK_SNAP_RADIUS then
				reattach()
			else
				target = tl
			end
		end)
	end)
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
		if not dragging or not isMove(input) then return end
		local mouse = Vector2.new(input.Position.X, input.Position.Y)
		if not detached then
			if (mouse - dragStart).Magnitude > DETACH_THRESHOLD then
				grabOffset = dragStart - root.AbsolutePosition
				detach()
				followCursor(mouse)
			end
			return
		end
		followCursor(mouse)
		setSnapHint((root.AbsolutePosition - dockTopLeft()).Magnitude < DOCK_SNAP_RADIUS)
	end))

	function panel:_uiHidden()
		if pinned then panel._wasVisible = false return end
		panel._wasVisible = root.Visible
		if not root.Visible then return end
		fadeTo(1)
		local myTok = fadeTok
		task.delay(0.3, function()
			if myTok == fadeTok then root.Visible = false end
		end)
	end
	function panel:_uiShown()
		if not panel._wasVisible then return end
		root.Visible = true
		if not detached then target = dockTopLeft() end
		fadeTo(0)
	end

	panel.Root = root
	applyPin()
	self.SidePanels = self.SidePanels or {}
	table.insert(self.SidePanels, panel)
	return panel
end

function Library:AddMonitor(key, label_)
	self:_ensureMonitorBar()
	if self.MonitorItems[key] then return self.MonitorItems[key] end
	self.MonitorCount += 1
	local order = self.MonitorCount

	local sep = new("Frame", {
		Size = UDim2.fromOffset(1, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Visible = false,
		LayoutOrder = order * 2 - 1,
		Parent = self.MonitorBar,
	})
	local cell = new("Frame", {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = order * 2,
		Parent = self.MonitorBar,
	})
	local content = new("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = cell,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local capLabel = label({
		Text = (label_ or key):upper(), Font = FONT_BOLD, TextSize = 9, TextColor3 = THEME.SubText,
		TextTransparency = 1,
		Size = UDim2.fromOffset(0, 12), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = content,
	})
	local valueLabel = label({
		Text = "--", Font = FONT_MEDIUM, TextSize = 12, TextColor3 = THEME.Text,
		TextTransparency = 1,
		Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = content,
	})

	local clickBtn = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Active = true, Parent = cell,
	})

	local win = self
	local FADE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeToken = 0
	local item = { cell = cell, sep = sep, value = valueLabel, caption = capLabel, shown = false }
	function item:Set(v) valueLabel.Text = tostring(v) end
	function item:SetColor(c)
		valueLabel.TextColor3 = c or THEME.Text
	end
	function item:OnClick(fn)
		clickBtn.Activated:Connect(function() if type(fn) == "function" then fn() end end)
	end
	function item:Show(on)
		on = on ~= false
		if on == self.shown then return end
		self.shown = on
		fadeToken += 1
		local myToken = fadeToken
		if on then
			cell.Visible = true
			TweenService:Create(capLabel, FADE, { TextTransparency = 0 }):Play()
			TweenService:Create(valueLabel, FADE, { TextTransparency = 0 }):Play()
			win:_refreshMonitorSeparators()
		else
			TweenService:Create(capLabel, FADE, { TextTransparency = 1 }):Play()
			TweenService:Create(valueLabel, FADE, { TextTransparency = 1 }):Play()
			if sep.Visible then tween(sep, 0.12, { BackgroundTransparency = 1 }) end
			task.delay(0.12, function()
				if myToken == fadeToken and not self.shown then
					cell.Visible = false
					sep.BackgroundTransparency = 0.86
					win:_refreshMonitorSeparators()
				end
			end)
		end
	end
	table.insert(self.MonitorOrder, item)
	self.MonitorItems[key] = item
	return item
end

function Library:SetStatus(text, color)
	if typeof(color) == "Color3" then self.StatusColor = color end
	if text ~= nil then self.StatusText = tostring(text) end
	local hex = (self.StatusColor or STATUS_GREEN):ToHex()
	self.StatusValue.Text = string.format('<font color="#%s">●</font> %s', hex, self.StatusText or "")
end

function Library:SetExpiry(text)
	self.ExpiryValue.Text = tostring(text)
end

function Library:SetScaleMultiplier(multiplier)
	self.ScaleMultiplier = math.clamp(tonumber(multiplier) or 1, 0.5, 1.5)
	if self.Open then tween(self.UIScale, 0.25, { Scale = self:_fitScale() }) end
end

function Library:AddMobileButton(opts)
	opts = opts or {}
	local isToggle = opts.Toggle == true
	local state = opts.Default == true

	local btn = new("TextButton", {
		Name = opts.Name or "MobileButton",
		Size = UDim2.fromOffset(196, isToggle and 66 or 52),
		BackgroundColor3 = THEME.Glass,
		BackgroundTransparency = SOLID_T,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = #self.MobileButtons + 1,
		Parent = self.MobileHolder,
	}, { corner(12), stroke(Color3.new(1, 1, 1), 0.85) })
	local dot, stateLbl
	if isToggle then
		dot = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.fromOffset(12, 12), BackgroundColor3 = state and STATUS_GREEN or THEME.Switch,
			BorderSizePixel = 0, Parent = btn,
		}, { round() })
	end
	local lbl = label({
		Text = opts.Name or "Button", Font = FONT_BOLD, TextSize = 15, TextColor3 = THEME.Text,
		Position = UDim2.fromOffset(isToggle and 38 or 16, isToggle and 11 or 0),
		Size = UDim2.new(1, -(isToggle and 52 or 32), 0, isToggle and 20 or 52),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn,
	})
	if isToggle then
		stateLbl = label({
			Text = state and "ON" or "OFF", Font = FONT_BOLD, TextSize = 12,
			TextColor3 = state and STATUS_GREEN or THEME.Muted,
			Position = UDim2.fromOffset(38, 33), Size = UDim2.new(1, -52, 0, 18),
			Parent = btn,
		})
	end

	local api = {}
	function api:Get() return state end
	function api:Set(v, silent)
		if isToggle then
			state = v == true
			if dot then tween(dot, 0.2, { BackgroundColor3 = state and STATUS_GREEN or THEME.Switch }) end
			if stateLbl then
				stateLbl.Text = state and "ON" or "OFF"
				tween(stateLbl, 0.2, { TextColor3 = state and STATUS_GREEN or THEME.Muted })
			end
			tween(btn, 0.2, { BackgroundTransparency = state and (SOLID_T - 0.05) or SOLID_T })
		end

		if not silent and opts.OnClick then fire(opts.OnClick, isToggle and state or nil) end
	end
	function api:SetVisible(v) btn.Visible = v ~= false end

	btn.MouseEnter:Connect(function() tween(btn, 0.15, { BackgroundTransparency = SOLID_T - 0.03 }) end)
	btn.MouseLeave:Connect(function() tween(btn, 0.15, { BackgroundTransparency = SOLID_T }) end)
	btn.Activated:Connect(function()
		playSound(SOUND_CLICK, 0.3, 1.1)
		if isToggle then api:Set(not state) else api:Set(true) end
	end)

	table.insert(self.MobileButtons, { api = api, btn = btn })
	return api
end

function Library:SetMobileMode(on)
	self.MobileMode = on == true
	self.MobileHolder.Visible = self.MobileMode
end

function Library:SetFPSCap(n)
	n = tonumber(n) or 0
	if n <= 0 then n = 1e6 end
	local env = (type(getgenv) == "function") and getgenv() or nil
	local fn = setfpscap
		or set_fps_cap
		or setfpslimit
		or set_fps_limit
		or (env and (env.setfpscap or env.set_fps_cap or env.setfpslimit or env.set_fps_limit))
		or (syn and syn.set_fps_cap)
		or (fluxus and (fluxus.setfpscap or fluxus.set_fps_cap))
	if type(fn) == "function" and pcall(fn, n) then return true, "executor" end

	local okSettings = pcall(function() settings().Rendering.FramerateCap = n end)
	if okSettings then return true, "settings" end

	if type(setfflag) == "function" then
		local capped = math.min(math.floor(n), 10000)
		if pcall(setfflag, "DFIntTaskSchedulerTargetFps", tostring(capped)) then
			return true, "fflag"
		end
	end
	return false
end

function Library:SetAcrylic(state)
	self.AcrylicEnabled = state == true
	local dockT = self.AcrylicEnabled and GLASS_DOCK_T or SOLID_T
	local panelT = self.AcrylicEnabled and GLASS_PANEL_T or SOLID_T
	tween(self.Dock, 0.3, { BackgroundTransparency = dockT })
	tween(self.Panel, 0.3, { BackgroundTransparency = panelT })
	tween(self.Footer, 0.3, { BackgroundTransparency = dockT })
	if self.Open then self:_suppressOtherDof(self.AcrylicEnabled) end
end

function Library:SetWorldDim(state)
	self.WorldDimEnabled = state == true
	self:_applyWorld(self.Open)
end

function Library:SetWorldDimPersistent(state)
	self.WorldDimPersistent = state == true
	self:_applyWorld(self.Open)
end

function Library:Notify(title, text, durationOrOpts)
	local opts = type(durationOrOpts) == "table" and durationOrOpts or {}
	local duration = type(durationOrOpts) == "number" and durationOrOpts or (opts.Duration or 5)
	local width = 310
	self.NotifyCount += 1

	local wrap = new("Frame", {
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self.NotifyCount,
		Parent = self.NotifyHolder,
	})
	local card = new("TextButton", {
		Position = UDim2.fromOffset(width + 40, 0),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Glass,
		BackgroundTransparency = SOLID_T,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = wrap,
	}, {
		corner(12),
		stroke(Color3.new(1, 1, 1), 0.86),
		pad(12, 14, 12, 14),
		new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local header = new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = card,
	})

	local bareIcon = opts.BareIcon == true
	local avatar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(26, 26, 30),
		BackgroundTransparency = bareIcon and 1 or 0,
		BorderSizePixel = 0,
		Parent = header,
	}, bareIcon and { } or { round(), stroke(Color3.new(1, 1, 1), 0.8) })
	local notifIcon = (type(opts.Icon) == "string" and opts.Icon ~= "") and opts.Icon or LOGO_ID
	local notifIconColor = (typeof(opts.IconColor) == "Color3") and opts.IconColor or THEME.Accent
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = bareIcon and UDim2.fromOffset(24, 24) or UDim2.fromOffset(15, 15),
		BackgroundTransparency = 1,
		Image = notifIcon,
		ImageColor3 = notifIconColor,
		ScaleType = Enum.ScaleType.Fit,
		Parent = avatar,
	})
	local nameRow = new("Frame", {
		Position = UDim2.new(0, 34, 0, 0),
		Size = UDim2.new(1, -34, 1, 0),
		BackgroundTransparency = 1,
		Parent = header,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	label({
		Text = tostring(title or "PYRA"), Font = FONT_BOLD, TextSize = 13,
		TextColor3 = (typeof(opts.TitleColor) == "Color3") and opts.TitleColor or THEME.Text,
		Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1, Parent = nameRow,
	})

	label({
		Text = tostring(text or ""), TextSize = 13, TextColor3 = THEME.Body,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LineHeight = 1.1, LayoutOrder = 2, Parent = card,
	})

	local closed = false
	local function close()
		if closed then return end
		closed = true
		tween(card, 0.35, { Position = UDim2.fromOffset(width + 40, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.3)
		local h = wrap.AbsoluteSize.Y
		wrap.AutomaticSize = Enum.AutomaticSize.None
		wrap.ClipsDescendants = true
		wrap.Size = UDim2.fromOffset(width, h)
		tween(wrap, 0.25, { Size = UDim2.fromOffset(width, 0) }).Completed:Wait()
		wrap:Destroy()
	end

	if type(opts.Button) == "string" then
		nameRow.Size = UDim2.new(1, -120, 1, 0)
		local btn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = THEME.Card,
			BackgroundTransparency = 0.9,
			AutoButtonColor = false,
			Font = FONT_MEDIUM, TextSize = 11, TextColor3 = THEME.SubText,
			Text = opts.Button,
			ZIndex = 3,
			Parent = header,
		}, { corner(6), stroke(Color3.new(1, 1, 1), 0.88), pad(0, 10, 0, 10) })
		btn.MouseEnter:Connect(function() tween(btn, 0.15, { BackgroundTransparency = 0.82, TextColor3 = THEME.Text }) end)
		btn.MouseLeave:Connect(function() tween(btn, 0.15, { BackgroundTransparency = 0.9, TextColor3 = THEME.SubText }) end)
		btn.Activated:Connect(function()
			if opts.OnButton then pcall(opts.OnButton) end
			task.spawn(close)
		end)
	end

	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		LayoutOrder = 4,
		Parent = card,
	}, { round() })
	local bar = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Accent,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = track,
	}, { round() })

	playSound(SOUND_CLICK, 0.2, 1.25)
	tween(card, 0.6, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	tween(bar, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)

	card.Activated:Connect(function() task.spawn(close) end)
	task.delay(duration, close)
end

function Library:_attachTooltip(target, text)
	if not self.Tooltip then
		self.Tooltip = new("Frame", {
			Name = "Tooltip",
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = THEME.Glass,
			BackgroundTransparency = SOLID_T,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 200,
			Parent = self.Gui,
		}, { corner(7), stroke(Color3.new(1, 1, 1), 0.82), pad(7, 10, 7, 10) })
		self.TooltipLabel = label({
			Text = "", Font = FONT_MEDIUM, TextSize = 12, TextColor3 = THEME.Text,
			Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
			ZIndex = 201, Parent = self.Tooltip,
		})
	end
	target.MouseEnter:Connect(function()
		self.TooltipLabel.Text = text
		self.Tooltip.Visible = true
		local ap = target.AbsolutePosition
		local as = target.AbsoluteSize
		self.Tooltip.Position = UDim2.fromOffset(ap.X + as.X / 2, ap.Y - 6)
	end)
	target.MouseMoved:Connect(function()
		if self.Tooltip.Visible then
			local ap = target.AbsolutePosition
			local as = target.AbsoluteSize
			self.Tooltip.Position = UDim2.fromOffset(ap.X + as.X / 2, ap.Y - 6)
		end
	end)
	target.MouseLeave:Connect(function()
		self.Tooltip.Visible = false
	end)
end

function Library:OnDestroy(fn)
	self.DestroyListeners = self.DestroyListeners or {}
	table.insert(self.DestroyListeners, fn)
end

function Library:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	for _, fn in ipairs(self.DestroyListeners or {}) do pcall(fn) end
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	self.Connections = {}
	if self.Acrylic then for _, a in ipairs(self.Acrylic) do pcall(function() a:Destroy() end) end end
	pcall(function() self:_suppressOtherDof(false) end)
	if acrylicDof then acrylicDof:Destroy() acrylicDof = nil end
	if self.Grade then self.Grade:Destroy() self.Grade = nil end
	for _, snd in pairs(soundCache) do pcall(function() snd:Destroy() end) end
	table.clear(soundCache)
	for _, c in ipairs(Lighting:GetChildren()) do
		if c.Name == "PyraBlur" then c:Destroy() end
	end
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name == "PyraGlass" then c:Destroy() end
	end
	if self.Gui then self.Gui:Destroy() end
	if _G.__PYRA_ACTIVE == self then _G.__PYRA_ACTIVE = nil end
end

function Library:_index(tab, frame, name, desc)
	if not self.SearchIndex or not frame or not name then return end
	local text = name .. " " .. (desc or "")
	table.insert(self.SearchIndex, {
		name = name,
		text = text,
		lower = text:lower(),
		tab = tab.Name,
		tabRef = tab,
		frame = frame,
	})
end

function Library:_resolveTabName(entry)
	if entry.tab then return entry.tab end
	for _, t in ipairs(self.Tabs) do
		if t.Page and entry.frame:IsDescendantOf(t.Page) then
			entry.tab = t.Name
			entry.realTab = t
			return t.Name
		end
	end
	return ""
end

function Library:_pulse(frame)
	if not frame then return end
	local glow = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Accent,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 25,
		Parent = frame,
	}, { corner(8) })
	task.delay(0.35, function()
		if not glow.Parent then return end
		tween(glow, 1.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine).Completed:Connect(function()
			glow:Destroy()
		end)
	end)
end

function Library:_showSearchPage()
	if self._searchActive then return end
	self._searchActive = true
	self._searchReturnTab = self.ActiveTab
	if self.ActiveTab then
		local old = self.ActiveTab.Page
		tween(old, 0.25, { GroupTransparency = 1, Position = UDim2.fromOffset(-20, 0) })
		task.delay(0.25, function()
			if self._searchActive then old.Visible = false end
		end)
		tween(self.ActiveTab.Button, 0.25, { TextColor3 = THEME.SubText })
		if self.ActiveTab.Icon then tween(self.ActiveTab.Icon, 0.25, { ImageColor3 = THEME.SubText }) end
	end
	tween(self.Pill, 0.3, { Size = UDim2.fromOffset(self.Pill.Size.X.Offset, 0) })
	self.SearchPage.Visible = true
	self.SearchPage.Position = UDim2.fromOffset(20, 0)
	tween(self.SearchPage, 0.3, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
end

function Library:_hideSearchPage()
	if not self._searchActive then return end
	self._searchActive = false
	local back = self._searchReturnTab
	tween(self.SearchPage, 0.25, { GroupTransparency = 1, Position = UDim2.fromOffset(20, 0) })
	task.delay(0.25, function()
		if not self._searchActive then self.SearchPage.Visible = false end
	end)
	if back then
		self.ActiveTab = nil
		self:SelectTab(back, false)
	end
end

function Library:_updateSearchPage(query)
	local list = self.SearchList
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("TextButton") or c.Name == "NoneState" then c:Destroy() end
	end
	query = (query or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
	local shown, i = 0, 0
	for _, entry in ipairs(self.SearchIndex) do
		if (entry.lower or entry.text:lower()):find(query, 1, true) then
			shown += 1
			i += 1
			local b = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = THEME.Card,
				BackgroundTransparency = CARD_T,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = i,
				ZIndex = 5,
				Parent = list,
			}, { corner(8), stroke(Color3.new(1, 1, 1), 0.92) })
			label({
				Text = entry.name, Font = FONT_MEDIUM, TextSize = 13, TextColor3 = THEME.Text,
				Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 16),
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6, Parent = b,
			})
			label({
				Text = self:_resolveTabName(entry), Font = FONT_MEDIUM, TextSize = 10, TextColor3 = THEME.SubText,
				Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -24, 0, 12),
				ZIndex = 6, Parent = b,
			})
			b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundTransparency = CARD_HOVER_T }) end)
			b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundTransparency = CARD_T }) end)
			b.Activated:Connect(function() self:_jumpTo(entry) end)
		end
	end

	if shown == 0 then
		local none = new("Frame", {
			Name = "NoneState",
			Size = UDim2.new(1, 0, 0, 90),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			ZIndex = 5,
			Parent = list,
		})
		label({
			Text = "Setting Not Found", Font = FONT_BOLD, TextSize = 15, TextColor3 = THEME.Text,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18),
			Size = UDim2.fromOffset(300, 20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = none,
		})
		label({
			Text = "Try rewording your search", TextSize = 12, TextColor3 = THEME.SubText,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40),
			Size = UDim2.fromOffset(300, 16), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = none,
		})
		local back = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 62),
			Size = UDim2.fromOffset(90, 24),
			BackgroundColor3 = THEME.Accent,
			AutoButtonColor = false,
			Font = FONT_MEDIUM, TextSize = 12, TextColor3 = THEME.AccentInverse,
			Text = "Go back",
			ZIndex = 6,
			Parent = none,
		}, { corner(6) })
		back.Activated:Connect(function()
			if self.SearchBar then
				local box = self.SearchBar:FindFirstChildOfClass("TextBox")
				if box then box.Text = "" box:ReleaseFocus() end
			end
			self:_closeSearch()
		end)
	end
end

function Library:_closeSearch()
	self:_hideSearchPage()
	if self.SearchBar and self._collapseSearch then self._collapseSearch() end
end

function Library:_jumpTo(entry)
	self:_resolveTabName(entry)
	local target = entry.realTab
	if not target then
		for _, t in ipairs(self.Tabs) do
			if t.Page and entry.frame:IsDescendantOf(t.Page) then target = t break end
		end
	end
	self._searchActive = false
	self.SearchPage.Visible = false
	if self.SearchBar then
		local box = self.SearchBar:FindFirstChildOfClass("TextBox")
		if box then box.Text = "" box:ReleaseFocus() end
		if self._collapseSearch then self._collapseSearch() end
	end
	if target then self:SelectTab(target) end
	task.delay(0.25, function()
		local frame = entry.frame
		if not frame or not frame.Parent then return end
		local scroll = frame
		while scroll and not scroll:IsA("ScrollingFrame") do scroll = scroll.Parent end
		if scroll then
			local rel = frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
			scroll.CanvasPosition = Vector2.new(0, math.max(0, rel - 40))
		end
		self:_pulse(frame)
	end)
end

function Library:AddTab(name, tabOpts)
	tabOpts = tabOpts or {}
	local index = #self.Tabs + 1
	local accent = tabOpts.Accent or THEME.Accent
	local accentInverse = tabOpts.AccentInverse or THEME.AccentInverse
	local tab = setmetatable({
		Window = self, Name = name, Order = 0, Index = index,
		Accent = accent, AccentInverse = accentInverse,
	}, Tab)

	local textWidth = TextService:GetTextSize(name, 13, FONT_MEDIUM, Vector2.new(1000, TAB_H)).X
	local width = math.max(52, math.ceil(textWidth) + 28)
	local x = self.TabBarWidth
	self.TabBarWidth = x + width + 4
	self.TabBar.Size = UDim2.fromOffset(self.TabBarWidth - 4, TAB_H)

	local button = new("TextButton", {
		Name = name,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(width, TAB_H),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = name,
		Font = FONT_BOLD,
		TextSize = 13,
		TextColor3 = THEME.SubText,
		ZIndex = 4,
		Parent = self.TabBar,
	})
	tab.Button = button

	local page = new("CanvasGroup", {
		Name = name .. "Page",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 3,
		Parent = self.Content,
	})
	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
		Parent = page,
	}, {
		pad(12, 14, 12, 14),
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	tab.Page, tab.Container = page, scroll

	button.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then tween(button, 0.2, { TextColor3 = THEME.Text }) end
	end)
	button.MouseLeave:Connect(function()
		if self.ActiveTab ~= tab then tween(button, 0.2, { TextColor3 = THEME.SubText }) end
	end)
	button.Activated:Connect(function()
		if self.Minimized then self:SetMinimized(false) end
		self:SelectTab(tab)
	end)

	table.insert(self.Tabs, tab)
	if not self.ActiveTab then self:SelectTab(tab, true) end
	return tab
end

function Library:AddTabIcon(iconId, onClick, size)
	size = size or 22
	local holder = new("TextButton", {
		Name = "TabIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 108 + (self.TabBarWidth or 0) + 6, 0.5, 0),
		Size = UDim2.fromOffset(size + 8, size + 8),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 4,
		Parent = self.Dock,
	})
	local img = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = iconId,
		ImageColor3 = THEME.SubText,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
		Parent = holder,
	})
	holder.MouseEnter:Connect(function() tween(img, 0.15, { ImageColor3 = THEME.Text }) end)
	holder.MouseLeave:Connect(function() tween(img, 0.15, { ImageColor3 = THEME.SubText }) end)
	holder.Activated:Connect(function()
		playSound(SOUND_CLICK, 0.25, 1.1)
		if type(onClick) == "function" then pcall(onClick) end
	end)
	self.TabIcons = self.TabIcons or {}
	table.insert(self.TabIcons, { holder = holder, img = img })
	return holder
end

function Library:SelectTab(tab, instant)
	if self._searchActive then
		self._searchActive = false
		self.SearchPage.Visible = false
		if self.SearchBar then
			local box = self.SearchBar:FindFirstChildOfClass("TextBox")
			if box then box.Text = "" box:ReleaseFocus() end
			if self._collapseSearch then self._collapseSearch() end
		end
	end
	local previous = self.ActiveTab
	if previous == tab then return end
	self.ActiveTab = tab
	local tIn, tOut = 0.26, 0.12

	if previous then
		tween(previous.Button, 0.25, { TextColor3 = THEME.SubText })
		local oldPage = previous.Page
		local dir = tab.Index > previous.Index and -1 or 1
		tween(oldPage, tOut, { GroupTransparency = 1, Position = UDim2.fromOffset(14 * dir, 0) }, Enum.EasingStyle.Quad)
		task.delay(tOut, function()
			if self.ActiveTab ~= previous then
				oldPage.Visible = false
				oldPage.Position = UDim2.fromOffset(0, 0)
			end
		end)
	end

	local pillPos, pillSize = tab.Button.Position, tab.Button.Size
	if instant or not self.Pill.Visible then
		self.Pill.Position = pillPos
		self.Pill.Size = pillSize
		self.Pill.Visible = true
	else
		tween(self.Pill, 0.4, { Position = pillPos, Size = pillSize })
		playSound(SOUND_CLICK, 0.2, 1.1)
	end
	if instant then
		self.Pill.BackgroundColor3 = tab.Accent
	else
		tween(self.Pill, 0.4, { BackgroundColor3 = tab.Accent })
	end
	tween(tab.Button, 0.25, { TextColor3 = tab.AccentInverse })

	local page = tab.Page
	page.Visible = true
	if instant then
		page.Position = UDim2.new()
		page.GroupTransparency = 0
	else
		local dir = (previous and tab.Index < previous.Index) and -1 or 1
		page.Position = UDim2.fromOffset(24 * dir, 0)
		tween(page, tIn, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	end

	for _, fn in ipairs(self.TabListeners or {}) do task.spawn(fn, tab) end
end

function Library:OnTabChanged(fn)
	self.TabListeners = self.TabListeners or {}
	table.insert(self.TabListeners, fn)
end

function Tab:_nextOrder()
	self.Order += 1
	return self.Order
end

local function elementFrame(tab, height)
	local row = tab._rowMode
	local ord = tab:_nextOrder()
	local f = new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = row and 1 or CARD_T,
		BorderSizePixel = 0,
		LayoutOrder = ord,
		ZIndex = 3,
		Parent = tab.Container,
	}, { corner(row and 0 or 8) })
	f:SetAttribute("RestT", row and 1 or CARD_T)
	if not row then
		stroke(Color3.new(1, 1, 1), 0.92).Parent = f
	elseif ord > 1 then
		new("Frame", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = f,
		})
	end
	return f
end

local function hoverable(frame, target)
	local rest = frame:GetAttribute("RestT")
	if rest == nil then rest = CARD_T end
	local hover = rest >= 1 and 0.965 or CARD_HOVER_T
	target.MouseEnter:Connect(function() tween(frame, 0.2, { BackgroundTransparency = hover }) end)
	target.MouseLeave:Connect(function() tween(frame, 0.2, { BackgroundTransparency = rest }) end)
end

function Tab:AddGroup(opts)
	opts = opts or {}
	local collapsible = opts.Collapsible == true

	local container = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = CARD_T,
		BorderSizePixel = 0,
		LayoutOrder = self:_nextOrder(),
		ZIndex = 3,
		Parent = self.Container,
	}, {
		corner(8),
		stroke(Color3.new(1, 1, 1), 0.92),
		new("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local proxy = setmetatable({
		Window = self.Window, Order = 0,
		Accent = self.Accent, AccentInverse = self.AccentInverse,
		_rowMode = true,
	}, Tab)
	proxy.Container = container

	if not collapsible then
		return proxy
	end

	local head = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = container,
	}, { new("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = container,
	}, { new("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local inner = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Position = UDim2.fromOffset(0, -8),
		ZIndex = 3,
		Parent = body,
	}, { new("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })

	proxy.Container = head
	proxy._collapseBody = body
	proxy._collapseInner = inner

	proxy.Body = setmetatable({
		Window = self.Window, Order = 1, Container = inner,
		Accent = self.Accent, AccentInverse = self.AccentInverse,
		_rowMode = true,
	}, Tab)

	local expanded = true
	local function measure()
		local layout = inner:FindFirstChildOfClass("UIListLayout")
		return layout and layout.AbsoluteContentSize.Y or 0
	end

	function proxy:SetExpanded(on, instant)
		on = on ~= false
		if on == expanded and not instant then return end
		expanded = on
		if on then
			body.Visible = true
			inner.Visible = true
			local h = measure()
			if instant then
				body.Size = UDim2.new(1, 0, 0, 0)
				body.AutomaticSize = Enum.AutomaticSize.Y
				inner.Position = UDim2.fromOffset(0, 0)
				inner.GroupTransparency = 0
			else
				body.AutomaticSize = Enum.AutomaticSize.None
				body.Size = UDim2.new(1, 0, 0, 0)
				tween(body, 0.3, { Size = UDim2.new(1, 0, 0, h) }, Enum.EasingStyle.Quint)
				tween(inner, 0.3, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
				task.delay(0.3, function()
					if expanded then body.AutomaticSize = Enum.AutomaticSize.Y end
				end)
			end
		else
			local h = measure()
			body.AutomaticSize = Enum.AutomaticSize.None
			body.Size = UDim2.new(1, 0, 0, h)
			if instant then
				body.Size = UDim2.new(1, 0, 0, 0)
				inner.Position = UDim2.fromOffset(0, -8)
				inner.GroupTransparency = 1
				body.Visible = false
			else
				tween(body, 0.28, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint)
				tween(inner, 0.28, { Position = UDim2.fromOffset(0, -8), GroupTransparency = 1 }, Enum.EasingStyle.Quint)
				task.delay(0.28, function()
					if not expanded then body.Visible = false end
				end)
			end
		end
	end

	proxy:SetExpanded(opts.DefaultExpanded ~= false, true)
	return proxy
end

local function titleBlock(parent, name, description, rightInset, iconId)
	local tx = 12
	if type(iconId) == "string" and iconId ~= "" then
		new("ImageLabel", {
			Name = "TitleIcon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(19, 19),
			BackgroundTransparency = 1,
			Image = iconId,
			ImageColor3 = THEME.Text,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4,
			Parent = parent,
		})
		tx = 36
	end
	if description then
		return label({
			Text = name, Font = FONT_MEDIUM, TextSize = 13,
			Position = UDim2.fromOffset(tx, 7), Size = UDim2.new(1, -(tx + rightInset), 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = parent,
		}), label({
			Text = description, TextSize = 11, TextColor3 = THEME.SubText,
			Position = UDim2.fromOffset(tx, 24), Size = UDim2.new(1, -(tx + rightInset), 0, 14),
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = parent,
		})
	else
		return label({
			Text = name, Font = FONT_MEDIUM, TextSize = 13,
			Position = UDim2.fromOffset(tx, 0), Size = UDim2.new(1, -(tx + rightInset), 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = parent,
		})
	end
end

function Tab:AddSection(text, opts)
	opts = opts or {}
	local hasIcon = type(opts.Icon) == "string" and opts.Icon ~= ""
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(),
		ZIndex = 4,
		Parent = self.Container,
	})
	self.Sections = self.Sections or {}
	table.insert(self.Sections, { name = text, row = row })
	if self.Window and self.Window._sectionNavs then
		for _, nv in ipairs(self.Window._sectionNavs) do
			if nv._tab == self then nv._dirty = true end
		end
	end

	local lbl = label({
		Text = string.upper(text), Font = FONT_BOLD, TextSize = 10,
		TextColor3 = opts.Color or (self.Accent == THEME.Accent and THEME.SubText or self.Accent),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		TextYAlignment = hasIcon and Enum.TextYAlignment.Center or Enum.TextYAlignment.Bottom,
		ZIndex = 4, Parent = row,
	})
	if hasIcon then
		local iconHolder = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = row,
		})
		new("ImageLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Image = opts.Icon, ImageColor3 = opts.Color or THEME.Text,
			ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = iconHolder,
		})
		lbl.Position = UDim2.fromOffset(20, 0)
		if type(opts.Tooltip) == "string" then
			self.Window:_attachTooltip(iconHolder, opts.Tooltip)
		end
	end
	return row
end

function Tab:AddLockedSection(opts)
	opts = opts or {}
	local unlocked = opts.Unlocked == true

	local header = new("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(),
		ZIndex = 4,
		Parent = self.Container,
	})
	local lockIcon = label({
		Text = unlocked and "◆" or "🔒",
		Font = FONT_BOLD, TextSize = unlocked and 9 or 11,
		TextColor3 = unlocked and self.Accent or THEME.SubText,
		Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(16, 22),
		TextYAlignment = Enum.TextYAlignment.Bottom, ZIndex = 4, Parent = header,
	})
	local titleLabel = label({
		Text = string.upper(opts.Name or "Premium"),
		Font = FONT_BOLD, TextSize = 10,
		TextColor3 = unlocked and (self.Accent == THEME.Accent and THEME.SubText or self.Accent) or THEME.Muted,
		Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -120, 1, 0),
		TextYAlignment = Enum.TextYAlignment.Bottom, ZIndex = 4, Parent = header,
	})
	local badge = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(74, 16),
		BackgroundColor3 = unlocked and self.Accent or THEME.Switch,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = header,
	}, { corner(4) })
	local badgeLabel = label({
		Text = unlocked and "UNLOCKED" or "LOCKED",
		Font = FONT_BOLD, TextSize = 9,
		TextColor3 = unlocked and self.AccentInverse or THEME.SubText,
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5, Parent = badge,
	})

	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(),
		ZIndex = 3,
		Parent = self.Container,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local overlay = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Glass,
		BackgroundTransparency = unlocked and 1 or 0.35,
		AutoButtonColor = false,
		Text = "",
		Visible = not unlocked,
		ZIndex = 20,
		Parent = holder,
	}, { corner(8) })
	local overlayText = label({
		Text = "🔒  " .. (opts.LockText or "Unlock with gamepass"),
		Font = FONT_MEDIUM, TextSize = 12, TextColor3 = THEME.Text,
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		Visible = not unlocked, ZIndex = 21, Parent = overlay,
	})

	local proxy = setmetatable({
		Window = self.Window, Container = holder, Order = 0,
		Accent = self.Accent, AccentInverse = self.AccentInverse,
	}, Tab)

	local api = { Section = proxy }
	function api:AddToggle(o) return proxy:AddToggle(o) end
	function api:AddSlider(o) return proxy:AddSlider(o) end
	function api:AddButton(o) return proxy:AddButton(o) end
	function api:AddDropdown(o) return proxy:AddDropdown(o) end
	function api:AddKeybind(o) return proxy:AddKeybind(o) end
	function api:AddInput(o) return proxy:AddInput(o) end
	function api:AddColorPicker(o) return proxy:AddColorPicker(o) end
	function api:AddRangeSlider(o) return proxy:AddRangeSlider(o) end
	function api:SetUnlocked(state)
		unlocked = state == true
		overlay.Visible = not unlocked
		overlayText.Visible = not unlocked
		tween(overlay, 0.3, { BackgroundTransparency = unlocked and 1 or 0.35 })
		lockIcon.Text = unlocked and "◆" or "🔒"
		lockIcon.TextSize = unlocked and 9 or 11
		lockIcon.TextColor3 = unlocked and self.Accent or THEME.SubText
		titleLabel.TextColor3 = unlocked and (self.Accent == THEME.Accent and THEME.SubText or self.Accent) or THEME.Muted
		badgeLabel.Text = unlocked and "UNLOCKED" or "LOCKED"
		badgeLabel.TextColor3 = unlocked and self.AccentInverse or THEME.SubText
		tween(badge, 0.3, { BackgroundColor3 = unlocked and self.Accent or THEME.Switch })
		if unlocked then playSound(SOUND_TOGGLE_ON, 0.4, 1.15) end
	end
	function api:IsUnlocked() return unlocked end
	return api
end

function Tab:AddParagraph(title, body)
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = CARD_T,
		BorderSizePixel = 0,
		LayoutOrder = self:_nextOrder(),
		ZIndex = 3,
		Parent = self.Container,
	}, {
		corner(8), stroke(Color3.new(1, 1, 1), 0.92), pad(10, 12, 10, 12),
		new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local titleLabel = label({ Text = title, Font = FONT_MEDIUM, TextSize = 13, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, ZIndex = 4, Parent = frame })
	local bodyLabel = label({
		Text = body, TextSize = 12, TextColor3 = THEME.SubText, TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 4, Parent = frame,
	})
	local api = {}
	function api:SetTitle(text) titleLabel.Text = tostring(text) end
	function api:SetBody(text) bodyLabel.Text = tostring(text) end
	return api
end

function Tab:AddToggle(opts)
	opts = opts or {}
	local state = opts.Default == true
	local hasKey = opts.Keybind ~= nil or opts.ShowKeybind == true
	local hasDrop = type(opts.Options) == "table" and #opts.Options > 0
	local hasChip = type(opts.Chip) == "string"
	local sliderOpts = opts.Slider
	local baseH = opts.Description and 50 or 38
	if sliderOpts then baseH = 68 end

	local frame = elementFrame(self, baseH)
	frame.ClipsDescendants = true
	local inset = 70
	if hasKey then inset = 110 end
	if hasDrop then inset = 164 end
	if hasChip then inset = 110 end
	if hasChip and hasKey then inset = 170 end

	local chipInline = hasChip and opts.ChipInline == true
	if chipInline then inset = hasKey and 110 or 70 end
	local inlineRow
	local iconToggle = opts.IconToggle == true and type(opts.Icon) == "string" and opts.Icon ~= ""
	if sliderOpts then
		label({
			Text = opts.Name or "Toggle", Font = FONT_MEDIUM, TextSize = 13,
			Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -(12 + inset), 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = frame,
		})
		if opts.Description then
			label({
				Text = opts.Description, TextSize = 11, TextColor3 = THEME.SubText,
				Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 0, 14),
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = frame,
			})
		end
	else
		if chipInline then
			local tx = ((not iconToggle) and type(opts.Icon) == "string" and opts.Icon ~= "") and 36 or 12
			if tx == 36 then
				new("ImageLabel", {
					Name = "TitleIcon",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 12, 0.5, 0),
					Size = UDim2.fromOffset(19, 19),
					BackgroundTransparency = 1,
					Image = opts.Icon,
					ImageColor3 = THEME.Text,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 4,
					Parent = frame,
				})
			end
			inlineRow = new("Frame", {
				Position = UDim2.fromOffset(tx, opts.Description and 5 or 9),
				Size = UDim2.new(0, 0, 0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				ZIndex = 8,
				Parent = frame,
			}, {
				new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			label({
				Text = opts.Name or "Toggle", Font = FONT_MEDIUM, TextSize = 13,
				Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 1, ZIndex = 4, Parent = inlineRow,
			})
			if opts.Description then
				label({
					Text = opts.Description, TextSize = 11, TextColor3 = THEME.SubText,
					Position = UDim2.fromOffset(tx, 24), Size = UDim2.new(1, -(tx + inset), 0, 14),
					TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = frame,
				})
			end
		else
			titleBlock(frame, opts.Name or "Toggle", opts.Description, inset, (not iconToggle) and opts.Icon or nil)
		end
	end
	self.Window:_index(self, frame, opts.Name or "Toggle", opts.Description)

	local bigIcon
	local switch, knob
	if iconToggle then

		bigIcon = new("ImageLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -15, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			Image = opts.Icon,
			ImageColor3 = THEME.SubText,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4,
			Parent = frame,
		})
	else
		local switchY = sliderOpts and UDim2.new(1, -12, 0, 16) or UDim2.new(1, -12, 0.5, 0)
		switch = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = switchY,
			Size = UDim2.fromOffset(40, 22),
			BackgroundColor3 = THEME.Switch,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = frame,
		}, { round(), stroke(Color3.new(1, 1, 1), 0.9) })
		knob = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = THEME.SubText,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = switch,
		}, { round() })
	end
	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = frame,
	})
	hoverable(frame, hit)

	local titleIcon = frame:FindFirstChild("TitleIcon")
	local iconBase = opts.Icon
	local iconSel = opts.IconSelected
	local function render(instant)
		local t = instant and 0 or 0.28
		local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if iconToggle then
			if bigIcon then
				if type(iconSel) == "string" and iconSel ~= "" then
					bigIcon.Image = state and iconSel or iconBase
				end
				TweenService:Create(bigIcon, info, { ImageColor3 = state and self.Accent or THEME.SubText }):Play()
			end
		else
			TweenService:Create(switch, info, { BackgroundColor3 = state and self.Accent or THEME.Switch }):Play()
			TweenService:Create(knob, info, { BackgroundColor3 = state and self.AccentInverse or THEME.SubText }):Play()
			TweenService:Create(
				knob,
				TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }
			):Play()
		end
		if titleIcon and type(iconSel) == "string" and iconSel ~= "" then
			titleIcon.Image = state and iconSel or (iconBase or iconSel)
			titleIcon.ImageColor3 = state and self.Accent or THEME.Text
		end
	end

	local api = {}
	local changedListeners = {}
	function api:Set(value, silent)
		value = value == true
		if value == state then return end
		state = value
		render(false)
		if not silent then
			playSound(state and SOUND_TOGGLE_ON or SOUND_TOGGLE_OFF, 0.35, state and 1 or 0.85)
		end
		fire(opts.Callback, state)
		for _, fn in ipairs(changedListeners) do fire(fn, state) end
	end
	function api:Get() return state end

	function api:OnChanged(fn)
		if type(fn) == "function" then table.insert(changedListeners, fn) end
	end

	hit.Activated:Connect(function() api:Set(not state) end)

	if sliderOpts then
		local smin, smax = sliderOpts.Min or 0, sliderOpts.Max or 100
		local sinc = sliderOpts.Increment or 1
		local ssuffix = sliderOpts.Suffix or ""
		local sdec = 0
		do
			local str = tostring(sinc)
			local dot = string.find(str, ".", 1, true)
			if dot then sdec = #str - dot end
		end
		local function ssnap(x)
			x = math.clamp(x, smin, smax)
			x = smin + math.floor((x - smin) / sinc + 0.5) * sinc
			x = math.clamp(x, smin, smax)
			if sdec > 0 then local m = 10 ^ sdec x = math.floor(x * m + 0.5) / m end
			return x
		end
		local function sfmt(x)
			if sdec > 0 then return string.format("%." .. sdec .. "f", x) end
			return tostring(math.floor(x + 0.5))
		end
		local sval = ssnap(sliderOpts.Default or smin)

		local sValLabel = label({
			Font = FONT_MEDIUM, TextSize = 11, TextColor3 = THEME.SubText,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 8), Size = UDim2.fromOffset(70, 16),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Parent = frame,
		})
		local strack = new("Frame", {
			Position = UDim2.new(0, 12, 0, 36),
			Size = UDim2.new(1, -24, 0, 4),
			BackgroundColor3 = THEME.Card,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = frame,
		}, { round() })
		local sfill = new("Frame", {
			Size = UDim2.fromScale(0, 1), BackgroundColor3 = self.Accent, BorderSizePixel = 0, ZIndex = 4, Parent = strack,
		}, { round() })
		local sknob = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(12, 12), BackgroundColor3 = self.Accent, BorderSizePixel = 0, ZIndex = 5, Parent = strack,
		}, { round() })
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(4, 4), BackgroundColor3 = self.AccentInverse,
			BorderSizePixel = 0, ZIndex = 6, Parent = sknob,
		}, { round() })
		local shit = new("TextButton", {
			Position = UDim2.new(0, 6, 0, 28), Size = UDim2.new(1, -12, 0, 20),
			BackgroundTransparency = 1, Text = "", ZIndex = 7, Parent = frame,
		})

		local function srender(instant)
			local pct = (smax == smin) and 0 or (sval - smin) / (smax - smin)
			local tt = instant and 0 or 0.12
			tween(sfill, tt, { Size = UDim2.fromScale(pct, 1) })
			tween(sknob, tt, { Position = UDim2.fromScale(pct, 0.5) })
			sValLabel.Text = sfmt(sval) .. ssuffix
		end
		api.Slider = {}
		function api.Slider:Set(v)
			v = ssnap(tonumber(v) or sval)
			if v == sval then return end
			sval = v
			srender(false)
			fire(sliderOpts.Callback, sval)
		end
		function api.Slider:Get() return sval end
		local function sFromX(x)
			local pos, size = strack.AbsolutePosition.X, strack.AbsoluteSize.X
			if size <= 0 then return end
			api.Slider:Set(smin + (smax - smin) * math.clamp((x - pos) / size, 0, 1))
		end
		local sdrag = false
		shit.InputBegan:Connect(function(input)
			if not isPress(input) then return end
			sdrag = true
			playSound(SOUND_CLICK, 0.22, 1.1)
			tween(sknob, 0.2, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
			beginDrag(self.Window, function(i)
				sFromX(i.Position.X)
			end, function()
				sdrag = false
				tween(sknob, 0.2, { Size = UDim2.fromOffset(12, 12) })
			end)
			sFromX(input.Position.X)
		end)
		srender(true)
	end

	local keyChipRef
	if hasKey then
		local key = opts.Keybind
		local listening = false
		local chip = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -60, 0.5, 0),
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = THEME.Card,
			BackgroundTransparency = 0.92,
			AutoButtonColor = false,
			Font = FONT_MEDIUM,
			TextSize = 11,
			TextColor3 = THEME.Text,
			ZIndex = 7,
			Parent = frame,
		}, { corner(5), stroke(Color3.new(1, 1, 1), 0.85), pad(0, 8, 0, 8) })
		local chipStroke = chip:FindFirstChildOfClass("UIStroke")
		local function crender() chip.Text = listening and "..." or (key and key.Name or "None") end

		chip.MouseEnter:Connect(function() if not listening then tween(chip, 0.15, { BackgroundTransparency = 0.86 }) end end)
		chip.MouseLeave:Connect(function() if not listening then tween(chip, 0.15, { BackgroundTransparency = 0.92 }) end end)
		chip.Activated:Connect(function()
			listening = true
			crender()
			playSound(SOUND_CLICK, 0.25, 1.1)
			tween(chipStroke, 0.2, { Transparency = 0.3 })
			beginCapture(self.Window, function(keyCode)
				listening = false
				tween(chipStroke, 0.2, { Transparency = 0.85 })
				if keyCode ~= Enum.KeyCode.Escape then
					key = keyCode
					fire(opts.KeybindChanged, key)
				end
				crender()
			end)
		end)
		crender()
		keyChipRef = chip
		api.Keybind = { Get = function() return key end, Set = function(_, k) key = k crender() end }
	end

	if hasChip then
		local chipState = opts.ChipDefault == true
		local chipW = type(opts.Chip) == "string" and (#opts.Chip > 3) and (18 + #opts.Chip * 6) or 42
		local chipX = hasKey and -60 or -60
		local chipProps = {
			Size = UDim2.fromOffset(chipW, 20),
			BackgroundColor3 = chipState and self.Accent or THEME.Switch,
			AutoButtonColor = false,
			Font = FONT_BOLD,
			TextSize = 9,
			TextColor3 = chipState and self.AccentInverse or THEME.Text,
			Text = opts.Chip,
			ZIndex = 7,
			Parent = frame,
		}
		if inlineRow then
			chipProps.LayoutOrder = 2
			chipProps.Parent = inlineRow
		else
			chipProps.AnchorPoint = Vector2.new(1, 0.5)
			chipProps.Position = UDim2.new(1, chipX, 0.5, 0)
		end
		local chip = new("TextButton", chipProps, { corner(5), stroke(Color3.new(1, 1, 1), 0.82) })
		local function chrender()
			tween(chip, 0.2, { BackgroundColor3 = chipState and self.Accent or THEME.Switch })
			chip.TextColor3 = chipState and self.AccentInverse or THEME.Text
		end
		local chipApi = {}
		function chipApi:Set(on)
			on = on == true
			if on == chipState then return end
			chipState = on
			chrender()
			playSound(SOUND_CLICK, 0.22, on and 1.05 or 0.95)
			fire(opts.ChipCallback, on)
		end
		function chipApi:Get() return chipState end
		chip.Activated:Connect(function() chipApi:Set(not chipState) end)
		api.Chip = chipApi

		if hasKey and keyChipRef and not inlineRow then
			local function reposition()
				chip.Position = UDim2.new(1, -60 - keyChipRef.AbsoluteSize.X - 6, 0.5, 0)
			end
			keyChipRef:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)
			task.defer(reposition)
		end
	end

	if hasDrop then
		local options = opts.Options
		local selected = opts.Default2 or options[1]
		local isOpen = false
		local OPT_H, GAP = 24, 2

		local box = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -60, 0.5, 0),
			Size = UDim2.fromOffset(88, 24),
			BackgroundColor3 = THEME.Card,
			BackgroundTransparency = 0.92,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 7,
			Parent = frame,
		}, { corner(5), stroke(Color3.new(1, 1, 1), 0.85) })
		local sel = label({
			Text = tostring(selected), Font = FONT_MEDIUM, TextSize = 11, TextColor3 = THEME.Text,
			Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -22, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = box,
		})
		local arrUseIcon = type(ICONS.Arrow) == "string" and ICONS.Arrow ~= ""
		local arr
		if arrUseIcon then

			arr = new("ImageLabel", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0),
				Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = ICONS.Arrow, ImageColor3 = THEME.Body, ZIndex = 8, Parent = box,
			})
		else
			arr = label({
				Text = "▾", TextSize = 10, TextColor3 = THEME.SubText,
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(10, 10), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = box,
			})
		end
		box.MouseEnter:Connect(function() if not isOpen then tween(box, 0.15, { BackgroundTransparency = 0.86 }) end end)
		box.MouseLeave:Connect(function() if not isOpen then tween(box, 0.15, { BackgroundTransparency = 0.92 }) end end)

		local win = self.Window
		local OVL_W = 132
		local overlay = new("Frame", {
			Name = "DropOverlay",
			Size = UDim2.fromOffset(OVL_W, 0),
			BackgroundColor3 = THEME.Glass,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 200,
			ClipsDescendants = true,
			Parent = win.Gui,
		}, {
			corner(8),
			stroke(Color3.new(1, 1, 1), 0.82),
			pad(5, 5, 5, 5),
			new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
		})

		local dropApi = api
		local function dselect(opt)
			selected = opt
			sel.Text = tostring(opt)
			fire(opts.OptionCallback, opt)
		end
		local function rebuild()
			for _, c in ipairs(overlay:GetChildren()) do
				if c:IsA("TextButton") then c:Destroy() end
			end
			for i, opt in ipairs(options) do
				local isSel = opt == selected
				local b = new("TextButton", {
					Size = UDim2.new(1, 0, 0, OPT_H + 4),
					BackgroundColor3 = isSel and THEME.Accent or THEME.Glass,
					BackgroundTransparency = isSel and 0 or SOLID_T,
					AutoButtonColor = false,
					Text = "",
					LayoutOrder = i,
					ZIndex = 201,
					Parent = overlay,
				}, { corner(6), stroke(Color3.new(1, 1, 1), 0.88) })
				local optLbl = label({
					Text = tostring(opt), Font = FONT_MEDIUM, TextSize = 11,
					TextColor3 = isSel and THEME.AccentInverse or THEME.Body,
					Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -12, 1, 0), ZIndex = 202, Parent = b,
				})
				b.MouseEnter:Connect(function() if opt ~= selected then tween(b, 0.1, { BackgroundTransparency = 0 }) end end)
				b.MouseLeave:Connect(function() if opt ~= selected then tween(b, 0.1, { BackgroundTransparency = SOLID_T }) end end)
				b.Activated:Connect(function()
					dselect(opt)
					rebuild()
				end)
			end
		end

		local function repositionOverlay()
			local holder = win.Holder
			local hx = holder.AbsolutePosition.X
			local hw = holder.AbsoluteSize.X
			local by = box.AbsolutePosition.Y
			overlay.Position = UDim2.fromOffset(hx + hw + 10, by)
		end

		local posConn
		self.Window:OnDestroy(function()
			if posConn then posConn:Disconnect() posConn = nil end
		end)
		function api:SetDropOpen(open)
			isOpen = open
			playSound(SOUND_CLICK, 0.2, open and 1.05 or 0.95)
			if arrUseIcon then
				tween(arr, 0.25, { Rotation = open and 180 or 0, ImageColor3 = open and THEME.Text or THEME.Body })
			else
				tween(arr, 0.25, { Rotation = open and 180 or 0, TextColor3 = open and THEME.Text or THEME.SubText })
			end
			tween(box, 0.2, { BackgroundTransparency = open and 0.86 or 0.92 })
			if open then
				rebuild()
				repositionOverlay()
				overlay.Visible = true
				local fullH = #options * (OPT_H + 4 + 3) + 10
				overlay.Size = UDim2.fromOffset(OVL_W, 0)
				tween(overlay, 0.2, { Size = UDim2.fromOffset(OVL_W, fullH) }, Enum.EasingStyle.Quint)
				posConn = RunService.RenderStepped:Connect(repositionOverlay)
			else
				if posConn then posConn:Disconnect() posConn = nil end
				tween(overlay, 0.18, { Size = UDim2.fromOffset(OVL_W, 0) }, Enum.EasingStyle.Quint)
				task.delay(0.18, function() if not isOpen then overlay.Visible = false end end)
			end
		end
		function api:GetOption() return selected end
		function api:SetOption(opt) dselect(opt) rebuild() end
		box.Activated:Connect(function() api:SetDropOpen(not isOpen) end)
	end

	render(true)
	return api
end

function Tab:AddSubToggle(opts)
	opts = opts or {}
	local state = opts.Default == true
	local enabled = true

	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, opts.Description and 46 or 34),
		BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(),
		ZIndex = 3,
		Parent = self.Container,
	}, { new("UIPadding", { PaddingTop = UDim.new(0, -4) }) })

	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = CARD_T,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = wrap,
	}, { corner(8), stroke(Color3.new(1, 1, 1), 0.92) })
	local tick = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(2, 14),
		BackgroundColor3 = self.Accent,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = frame,
	}, { corner(1) })
	titleBlock(frame, opts.Name or "Option", opts.Description, 70)
	self.Window:_index(self, frame, opts.Name or "Option", opts.Description)

	local switch = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		BackgroundColor3 = THEME.Switch,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = frame,
	}, { round(), stroke(Color3.new(1, 1, 1), 0.9) })
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = THEME.SubText,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = switch,
	}, { round() })
	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = frame,
	})
	hoverable(frame, hit)

	local function render(instant)
		local t = instant and 0 or 0.28
		local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(switch, info, { BackgroundColor3 = state and self.Accent or THEME.Switch }):Play()
		TweenService:Create(knob, info, { BackgroundColor3 = state and self.AccentInverse or THEME.SubText }):Play()
		TweenService:Create(
			knob,
			TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }
		):Play()
	end

	local api = {}
	function api:Set(value, silent)
		value = value == true
		if value == state then return end
		state = value
		render(false)
		if not silent then
			playSound(state and SOUND_TOGGLE_ON or SOUND_TOGGLE_OFF, 0.35, state and 1 or 0.85)
		end
		fire(opts.Callback, state)
	end
	function api:Get() return state end
	function api:SetEnabled(on)
		enabled = on == true
		hit.Active = enabled
		tween(wrap, 0.2, {})
		tween(frame, 0.2, { BackgroundTransparency = enabled and CARD_T or 0.97 })
		for _, d in ipairs(frame:GetDescendants()) do
			if d:IsA("TextLabel") then
				tween(d, 0.2, { TextTransparency = enabled and 0 or 0.5 })
			end
		end
		tween(switch, 0.2, { BackgroundTransparency = enabled and 0 or 0.5 })
		tween(knob, 0.2, { BackgroundTransparency = enabled and 0 or 0.5 })
		tween(tick, 0.2, { BackgroundTransparency = enabled and 0 or 0.6 })
		if not enabled and state then api:Set(false) end
	end

	hit.Activated:Connect(function()
		if enabled then api:Set(not state) end
	end)
	render(true)
	return api
end

function Tab:AddSlider(opts)
	opts = opts or {}
	local min, max = opts.Min or 0, opts.Max or 100
	local increment = opts.Increment or 1
	local suffix = opts.Suffix or ""
	local decimals = 0
	do
		local s = tostring(increment)
		local dot = string.find(s, ".", 1, true)
		if dot then decimals = #s - dot end
	end

	local frame = elementFrame(self, 50)
	label({
		Text = opts.Name or "Slider", Font = FONT_MEDIUM, TextSize = 13,
		Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -100, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = frame,
	})
	local valueLabel = valueBox({
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(88, 20),
		Parent = frame,
	})
	self.Window:_index(self, frame, opts.Name or "Slider", opts.Description)

	local track = new("Frame", {
		Position = UDim2.new(0, 12, 1, -16),
		Size = UDim2.new(1, -24, 0, 4),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = frame,
	}, { round() })
	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = self.Accent, BorderSizePixel = 0, ZIndex = 4, Parent = track,
	}, { round() })
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = self.Accent,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	}, { round() })
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4), BackgroundColor3 = self.AccentInverse,
		BorderSizePixel = 0, ZIndex = 6, Parent = knob,
	}, { round() })

	local hit = new("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 1, -14),
		Size = UDim2.new(1, -12, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 7,
		Parent = frame,
	})
	hoverable(frame, frame)

	local value
	local dragging = false
	local editing = false

	local function format(v)
		if type(opts.Format) == "function" then
			local ok, out = pcall(opts.Format, v)
			if ok and out ~= nil then return tostring(out) end
		end
		if decimals > 0 then return string.format("%." .. decimals .. "f", v) end
		return tostring(math.floor(v + 0.5))
	end
	local function snap(v)
		v = math.clamp(v, min, max)
		v = min + math.floor((v - min) / increment + 0.5) * increment
		v = math.clamp(v, min, max)
		if decimals > 0 then
			local m = 10 ^ decimals
			v = math.floor(v * m + 0.5) / m
		end
		return v
	end
	local function render(instant)
		local pct = (max == min) and 0 or (value - min) / (max - min)
		local t = instant and 0 or 0.12
		tween(fill, t, { Size = UDim2.fromScale(pct, 1) })
		tween(knob, t, { Position = UDim2.fromScale(pct, 0.5) })
		if not editing then valueLabel.Text = format(value) .. suffix end
	end

	local api = {}
	function api:Set(v)
		v = snap(tonumber(v) or min)
		if v == value then return end
		value = v
		render(false)
		fire(opts.Callback, value)
	end
	function api:Get() return value end

	if type(opts.Chip) == "string" then
		local chipState = opts.ChipDefault == true
		local chipW = (#opts.Chip > 3) and (18 + #opts.Chip * 6) or 42
		local chip = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8 - 88 - 8, 0, 5),
			Size = UDim2.fromOffset(chipW, 20),
			BackgroundColor3 = chipState and self.Accent or THEME.Switch,
			AutoButtonColor = false,
			Font = FONT_BOLD,
			TextSize = 9,
			TextColor3 = chipState and self.AccentInverse or THEME.Text,
			Text = opts.Chip,
			ZIndex = 7,
			Parent = frame,
		}, { corner(5), stroke(Color3.new(1, 1, 1), 0.82) })
		local function chrender()
			tween(chip, 0.2, { BackgroundColor3 = chipState and self.Accent or THEME.Switch })
			chip.TextColor3 = chipState and self.AccentInverse or THEME.Text
		end
		local chipApi = {}
		function chipApi:Set(on)
			on = on == true
			if on == chipState then return end
			chipState = on
			chrender()
			playSound(SOUND_CLICK, 0.22, on and 1.05 or 0.95)
			fire(opts.ChipCallback, on)
		end
		function chipApi:Get() return chipState end
		chip.Activated:Connect(function() chipApi:Set(not chipState) end)
		api.Chip = chipApi
	end

	local function setFromX(x)
		local pos, size = track.AbsolutePosition.X, track.AbsoluteSize.X
		if size <= 0 then return end
		api:Set(min + (max - min) * math.clamp((x - pos) / size, 0, 1))
	end

	frame.MouseEnter:Connect(function()
		if not dragging then tween(knob, 0.2, { Size = UDim2.fromOffset(14, 14) }) end
	end)
	frame.MouseLeave:Connect(function()
		if not dragging then tween(knob, 0.2, { Size = UDim2.fromOffset(12, 12) }) end
	end)

	hit.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		dragging = true
		playSound(SOUND_CLICK, 0.25, 1.1)
		tween(knob, 0.25, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
		tween(valueLabel, 0.2, { TextColor3 = THEME.Text })
		beginDrag(self.Window, function(i)
			setFromX(i.Position.X)
		end, function()
			dragging = false
			tween(knob, 0.25, { Size = UDim2.fromOffset(12, 12) })
			if not editing then tween(valueLabel, 0.2, { TextColor3 = THEME.SubText }) end
		end)
		setFromX(input.Position.X)
	end)

	valueLabel.Focused:Connect(function()
		editing = true
		valueLabel.Text = format(value)
		selectAll(valueLabel)
		tween(valueLabel, 0.15, { BackgroundTransparency = 0.9, TextColor3 = THEME.Text })
	end)
	valueLabel.FocusLost:Connect(function()
		editing = false
		tween(valueLabel, 0.15, { BackgroundTransparency = 1, TextColor3 = THEME.SubText })
		local n = tonumber((string.gsub(valueLabel.Text, "[^%d%.%-]", "")))
		if n then api:Set(n) end
		valueLabel.Text = format(value) .. suffix
	end)

	value = snap(opts.Default or min)
	render(true)
	return api
end

function Tab:AddButton(opts)
	opts = opts or {}
	local frame = elementFrame(self, opts.Description and 50 or 36)
	frame.ClipsDescendants = true
	local titleLabel, descLabel = titleBlock(frame, opts.Name or "Button", opts.Description, 36)
	self.Window:_index(self, frame, opts.Name or "Button", opts.Description)

	local useArrowIcon = type(ICONS.Arrow) == "string" and ICONS.Arrow ~= ""
	local arrow = label({
		Text = useArrowIcon and "" or "›", Font = FONT_BOLD, TextSize = 18, TextColor3 = THEME.SubText,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -1),
		Size = UDim2.fromOffset(12, 18), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = frame,
	})
	local arrowImg
	if useArrowIcon then
		arrowImg = new("ImageLabel", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -15, 0.5, -1),
			Size = UDim2.fromOffset(20, 13), BackgroundTransparency = 1, Rotation = -90,
			ScaleType = Enum.ScaleType.Fit,
			Image = ICONS.Arrow, ImageColor3 = THEME.Body, ZIndex = 4, Parent = frame,
		})
		arrow:GetPropertyChangedSignal("TextColor3"):Connect(function() arrowImg.ImageColor3 = arrow.TextColor3 end)
		arrow:GetPropertyChangedSignal("Position"):Connect(function() arrowImg.Position = arrow.Position end)
	end
	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = frame,
	})
	hoverable(frame, hit)
	hit.MouseEnter:Connect(function()
		tween(arrow, 0.25, { Position = UDim2.new(1, -10, 0.5, -1), TextColor3 = THEME.Text })
	end)
	hit.MouseLeave:Connect(function()
		tween(arrow, 0.25, { Position = UDim2.new(1, -14, 0.5, -1), TextColor3 = THEME.SubText })
	end)

	hit.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		playSound(SOUND_CLICK, 0.3)
		local scale = self.Window.UIScale.Scale
		if scale <= 0 then return end
		local rel = (Vector2.new(input.Position.X, input.Position.Y) - frame.AbsolutePosition) / scale
		local ripple = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(rel.X, rel.Y),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = self.Accent,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = frame,
		}, { round() })
		local size = (frame.AbsoluteSize.X / scale) * 2.2
		tween(ripple, 0.6, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }).Completed:Connect(function()
			ripple:Destroy()
		end)
	end)
	hit.Activated:Connect(function() fire(opts.Callback) end)

	local api = {}
	function api:SetTitle(text) titleLabel.Text = tostring(text) end
	function api:SetDescription(text) if descLabel then descLabel.Text = tostring(text) end end
	return api
end

function Tab:AddDropdown(opts)
	opts = opts or {}
	local options = opts.Options or {}
	local selected = opts.Default or options[1]
	local isOpen = false
	local HEADER, OPTION_H, OPTION_GAP = 36, 26, 2

	local frame = elementFrame(self, HEADER)
	frame.ClipsDescendants = true

	label({
		Text = opts.Name or "Dropdown", Font = FONT_MEDIUM, TextSize = 13,
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, -12, 0, HEADER), ZIndex = 4, Parent = frame,
	})
	self.Window:_index(self, frame, opts.Name or "Dropdown", opts.Description)
	local current = label({
		TextSize = 12, TextColor3 = THEME.SubText,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -34, 0, 0), Size = UDim2.new(0.5, -34, 0, HEADER),
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = frame,
	})
	local arrowUseIcon = type(ICONS.Arrow) == "string" and ICONS.Arrow ~= ""
	local arrow
	if arrowUseIcon then
		arrow = new("ImageLabel", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0, HEADER / 2),
			Size = UDim2.fromOffset(24, 16), BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = ICONS.Arrow, ImageColor3 = THEME.Body, ZIndex = 4, Parent = frame,
		})
	else
		arrow = label({
			Text = "▾", TextSize = 12, TextColor3 = THEME.SubText,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, HEADER / 2),
			Size = UDim2.fromOffset(14, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = frame,
		})
	end
	local header = new("TextButton", {
		Size = UDim2.new(1, 0, 0, HEADER), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = frame,
	})
	hoverable(frame, header)

	local list = new("Frame", {
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 0, #options * (OPTION_H + OPTION_GAP) + 8),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Visible = false,
		Parent = frame,
	}, {
		pad(0, 8, 8, 8),
		new("UIListLayout", { Padding = UDim.new(0, OPTION_GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local items = {}
	local api = {}

	local function refresh(instant)
		current.Text = tostring(selected or " - ")
		local t = instant and 0 or 0.2
		for _, item in ipairs(items) do
			local on = item.option == selected
			tween(item.label, t, { TextColor3 = on and THEME.Text or THEME.SubText })
			tween(item.dot, t, { BackgroundTransparency = on and 0 or 1 })
			if item.num then tween(item.num, t, { TextTransparency = on and 1 or 0 }) end
		end
	end

	for i, option in ipairs(options) do
		local b = new("TextButton", {
			Size = UDim2.new(1, 0, 0, OPTION_H),
			BackgroundColor3 = THEME.Card,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = i,
			ZIndex = 5,
			Parent = list,
		}, { corner(5) })
		local numbered = tonumber(opts.NumberStart)
		local l = label({
			Text = tostring(option), TextSize = 12, TextColor3 = THEME.SubText,
			Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -28, 1, 0),
			ZIndex = 5, Parent = b,
		})
		local num
		if numbered then
			num = label({
				Text = tostring(numbered + i - 1), Font = FONT_BOLD, TextSize = 10,
				TextColor3 = THEME.Muted,
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
				Size = UDim2.fromOffset(14, 14), TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 5, Parent = b,
			})
		end
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(5, 5), BackgroundColor3 = self.Accent,
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6, Parent = b,
		}, { round() })
		b.MouseEnter:Connect(function() tween(b, 0.15, { BackgroundTransparency = 0.94 }) end)
		b.MouseLeave:Connect(function() tween(b, 0.15, { BackgroundTransparency = 1 }) end)
		b.Activated:Connect(function()
			api:Set(option)
			api:SetOpen(false)
		end)
		table.insert(items, { option = option, label = l, dot = dot, num = num })
	end

	local fullHeight = HEADER + #options * (OPTION_H + OPTION_GAP) + 8

	local openId = 0
	function api:SetOpen(state)
		isOpen = state
		openId += 1
		local id = openId
		playSound(SOUND_CLICK, 0.22, state and 1.05 or 0.95)
		if state then list.Visible = true end
		tween(frame, 0.3, { Size = UDim2.new(1, 0, 0, isOpen and fullHeight or HEADER) }).Completed:Connect(function()
			if id == openId and not isOpen then list.Visible = false end
		end)
		if arrowUseIcon then
			tween(arrow, 0.3, { Rotation = isOpen and 180 or 0, ImageColor3 = isOpen and THEME.Text or THEME.Body })
		else
			tween(arrow, 0.3, { Rotation = isOpen and 180 or 0, TextColor3 = isOpen and THEME.Text or THEME.SubText })
		end
	end
	function api:Set(option)
		if option == selected then return end
		selected = option
		refresh(false)
		fire(opts.Callback, selected)
	end
	function api:Get() return selected end

	header.Activated:Connect(function() api:SetOpen(not isOpen) end)
	refresh(true)
	return api
end

local function trackDrag(window, target, onMove, onEnd)
	target.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		beginDrag(window, function(i) onMove(i.Position, false) end, onEnd)
		onMove(input.Position, true)
	end)
end

function Tab:AddColorPicker(opts)
	opts = opts or {}
	local h, s, v = (opts.Default or Color3.fromRGB(255, 255, 255)):ToHSV()
	local isOpen = false
	local HEADER, BODY = 38, 132

	local frame = elementFrame(self, HEADER)
	frame.ClipsDescendants = true
	label({
		Text = opts.Name or "Color", Font = FONT_MEDIUM, TextSize = 13,
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, -12, 0, HEADER), ZIndex = 4, Parent = frame,
	})
	self.Window:_index(self, frame, opts.Name or "Color", opts.Description)
	local swatch = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, HEADER / 2),
		Size = UDim2.fromOffset(34, 18),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = frame,
	}, { corner(5), stroke(Color3.new(1, 1, 1), 0.75) })
	local hexLabel = label({
		TextSize = 12, TextColor3 = THEME.SubText, Font = FONT_MEDIUM,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -54, 0, 0), Size = UDim2.fromOffset(70, HEADER),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Parent = frame,
	})
	local header = new("TextButton", {
		Size = UDim2.new(1, 0, 0, HEADER), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = frame,
	})
	hoverable(frame, header)

	local body = new("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, HEADER + BODY),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 4,
		Parent = frame,
	})
	local sv = new("TextButton", {
		Position = UDim2.fromOffset(12, HEADER),
		Size = UDim2.new(1, -60, 0, BODY - 12),
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = body,
	}, { corner(6) })
	new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = sv,
	}, { corner(6), new("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4, Parent = sv,
	}, { corner(6), new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
	local svCursor = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = sv,
	}, { round(), stroke(Color3.new(1, 1, 1), 0, 2) })

	local rainbow = {}
	for i = 0, 6 do
		table.insert(rainbow, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)))
	end
	local hue = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, HEADER),
		Size = UDim2.new(0, 14, 0, BODY - 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = body,
	}, { round(), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rainbow) }) })
	local hueCursor = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 6, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = hue,
	}, { round(), stroke(Color3.new(0, 0, 0), 0.5) })

	local api = {}
	local function render(notify)
		local color = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
		tween(swatch, 0.15, { BackgroundColor3 = color })
		hexLabel.Text = "#" .. string.upper(color:ToHex())
		if notify then fire(opts.Callback, color) end
	end

	trackDrag(self.Window, sv, function(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		render(true)
	end)
	trackDrag(self.Window, hue, function(pos)
		h = math.clamp((pos.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 0.999)
		render(true)
	end)

	local openId = 0
	function api:SetOpen(state)
		isOpen = state
		openId += 1
		local id = openId
		playSound(SOUND_CLICK, 0.22, state and 1.05 or 0.95)
		if state then body.Visible = true end
		tween(frame, 0.3, { Size = UDim2.new(1, 0, 0, isOpen and (HEADER + BODY) or HEADER) }).Completed:Connect(function()
			if id == openId and not isOpen then body.Visible = false end
		end)
	end
	function api:Set(color)
		h, s, v = color:ToHSV()
		render(true)
	end
	function api:Get() return Color3.fromHSV(h, s, v) end

	header.Activated:Connect(function() api:SetOpen(not isOpen) end)
	swatch.BackgroundColor3 = Color3.fromHSV(h, s, v)
	render(false)
	return api
end

function Tab:AddRangeSlider(opts)
	opts = opts or {}
	local min, max = opts.Min or 0, opts.Max or 100
	local increment = opts.Increment or 1
	local suffix = opts.Suffix or ""
	local decimals = 0
	do
		local str = tostring(increment)
		local dot = string.find(str, ".", 1, true)
		if dot then decimals = #str - dot end
	end
	local function snap(x)
		x = math.clamp(x, min, max)
		x = min + math.floor((x - min) / increment + 0.5) * increment
		x = math.clamp(x, min, max)
		if decimals > 0 then
			local m = 10 ^ decimals
			x = math.floor(x * m + 0.5) / m
		end
		return x
	end
	local function format(x)
		if decimals > 0 then return string.format("%." .. decimals .. "f", x) end
		return tostring(math.floor(x + 0.5))
	end

	local lo = snap(opts.DefaultMin or min)
	local hi = snap(opts.DefaultMax or max)
	if lo > hi then lo, hi = hi, lo end

	local frame = elementFrame(self, 50)
	label({
		Text = opts.Name or "Range", Font = FONT_MEDIUM, TextSize = 13,
		Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -130, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = frame,
	})
	self.Window:_index(self, frame, opts.Name or "Range", opts.Description)
	local valueLabel = valueBox({
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(124, 20),
		Parent = frame,
	})
	local editing = false
	local track = new("Frame", {
		Position = UDim2.new(0, 12, 1, -16),
		Size = UDim2.new(1, -24, 0, 4),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = frame,
	}, { round() })
	local fill = new("Frame", {
		BackgroundColor3 = self.Accent, BorderSizePixel = 0, ZIndex = 4, Parent = track,
	}, { round() })
	local function makeKnob()
		local k = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = self.Accent,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = track,
		}, { round() })
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(4, 4), BackgroundColor3 = self.AccentInverse,
			BorderSizePixel = 0, ZIndex = 6, Parent = k,
		}, { round() })
		return k
	end
	local knobLo, knobHi = makeKnob(), makeKnob()
	local hit = new("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 1, -14),
		Size = UDim2.new(1, -12, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 7,
		Parent = frame,
	})
	hoverable(frame, frame)

	local function pctOf(x) return (max == min) and 0 or (x - min) / (max - min) end
	local function render(instant)
		local t = instant and 0 or 0.12
		local a, b = pctOf(lo), pctOf(hi)
		tween(knobLo, t, { Position = UDim2.fromScale(a, 0.5) })
		tween(knobHi, t, { Position = UDim2.fromScale(b, 0.5) })
		tween(fill, t, { Position = UDim2.fromScale(a, 0), Size = UDim2.fromScale(b - a, 1) })
		if not editing then valueLabel.Text = format(lo) .. suffix .. "  -  " .. format(hi) .. suffix end
	end

	local api = {}
	function api:Set(newLo, newHi)
		newLo, newHi = snap(tonumber(newLo) or lo), snap(tonumber(newHi) or hi)
		if newLo > newHi then newLo, newHi = newHi, newLo end
		if newLo == lo and newHi == hi then return end
		lo, hi = newLo, newHi
		render(false)
		fire(opts.Callback, lo, hi)
	end
	function api:Get() return lo, hi end
	function api:Random()
		if decimals == 0 and increment == 1 then
			return math.random(math.floor(lo), math.floor(hi))
		end
		return snap(lo + math.random() * (hi - lo))
	end

	local active
	local function valueAt(x)
		local pos, size = track.AbsolutePosition.X, track.AbsoluteSize.X
		if size <= 0 then return lo end
		return min + (max - min) * math.clamp((x - pos) / size, 0, 1)
	end
	trackDrag(self.Window, hit, function(pos, began)
		local x = valueAt(pos.X)
		if began then
			active = (math.abs(x - lo) <= math.abs(x - hi)) and "lo" or "hi"
			if lo == hi then active = (x < lo) and "lo" or "hi" end
			playSound(SOUND_CLICK, 0.25, 1.1)
			tween(active == "lo" and knobLo or knobHi, 0.25, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
			tween(valueLabel, 0.2, { TextColor3 = THEME.Text })
		end
		if active == "lo" then
			if x > hi then active = "hi" api:Set(hi, x) else api:Set(x, hi) end
		else
			if x < lo then active = "lo" api:Set(x, lo) else api:Set(lo, x) end
		end
	end, function()
		tween(knobLo, 0.25, { Size = UDim2.fromOffset(12, 12) })
		tween(knobHi, 0.25, { Size = UDim2.fromOffset(12, 12) })
		if not editing then tween(valueLabel, 0.2, { TextColor3 = THEME.SubText }) end
	end)

	valueLabel.Focused:Connect(function()
		editing = true
		valueLabel.Text = format(lo) .. " - " .. format(hi)
		selectAll(valueLabel)
		tween(valueLabel, 0.15, { BackgroundTransparency = 0.9, TextColor3 = THEME.Text })
	end)
	valueLabel.FocusLost:Connect(function()
		editing = false
		tween(valueLabel, 0.15, { BackgroundTransparency = 1, TextColor3 = THEME.SubText })
		local nums = {}
		for n in string.gmatch(valueLabel.Text, "%-?%d+%.?%d*") do
			table.insert(nums, tonumber(n))
		end
		if #nums >= 2 then
			api:Set(nums[1], nums[2])
		elseif #nums == 1 then
			api:Set(nums[1], nums[1])
		end
		valueLabel.Text = format(lo) .. suffix .. "  -  " .. format(hi) .. suffix
	end)

	render(true)
	return api
end

function Tab:AddRandomSlider(opts)
	opts = opts or {}
	local min, max = opts.Min or 0, opts.Max or 100
	local increment = opts.Increment or 1
	local suffix = opts.Suffix or ""
	local decimals = 0
	do
		local str = tostring(increment)
		local dot = string.find(str, ".", 1, true)
		if dot then decimals = #str - dot end
	end
	local function snap(x)
		x = math.clamp(x, min, max)
		x = min + math.floor((x - min) / increment + 0.5) * increment
		x = math.clamp(x, min, max)
		if decimals > 0 then
			local m = 10 ^ decimals
			x = math.floor(x * m + 0.5) / m
		end
		return x
	end
	local function format(x)
		if decimals > 0 then return string.format("%." .. decimals .. "f", x) end
		return tostring(math.floor(x + 0.5))
	end

	local val = snap(opts.Default or min)
	local lo = snap(opts.DefaultMin or min)
	local hi = snap(opts.DefaultMax or max)
	if lo > hi then lo, hi = hi, lo end
	local randomize = opts.Randomize == true

	local frame = elementFrame(self, 50)
	local headRow = new("Frame", {
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(0, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = frame,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	label({
		Text = opts.Name or "Value", Font = FONT_MEDIUM, TextSize = 13,
		Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1, ZIndex = 4, Parent = headRow,
	})
	local valueLabel = valueBox({
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(130, 20),
		Parent = frame,
	})

	local ACC, ACCI = self.Accent, self.AccentInverse
	local api_extra_chip
	local rngChip = new("TextButton", {
		Size = UDim2.fromOffset(62, 20),
		LayoutOrder = 2,
		BackgroundColor3 = randomize and ACC or THEME.Switch,
		AutoButtonColor = false,
		Font = FONT_BOLD,
		TextSize = 9,
		TextColor3 = randomize and ACCI or THEME.Text,
		Text = "RANDOM",
		ZIndex = 7,
		Parent = headRow,
	}, { corner(5), stroke(Color3.new(1, 1, 1), 0.82) })

	local extraChip
	if type(opts.Chip) == "string" then
		local st = opts.ChipDefault == true
		local w = (#opts.Chip > 3) and (18 + #opts.Chip * 6) or 42
		extraChip = new("TextButton", {
			Size = UDim2.fromOffset(w, 20),
			LayoutOrder = 3,
			BackgroundColor3 = st and ACC or THEME.Switch,
			AutoButtonColor = false,
			Font = FONT_BOLD,
			TextSize = 9,
			TextColor3 = st and ACCI or THEME.Text,
			Text = opts.Chip,
			ZIndex = 7,
			Parent = headRow,
		}, { corner(5), stroke(Color3.new(1, 1, 1), 0.82) })
		local eApi = {}
		function eApi:Set(on)
			on = on == true
			if on == st then return end
			st = on
			tween(extraChip, 0.2, { BackgroundColor3 = on and ACC or THEME.Switch })
			extraChip.TextColor3 = on and ACCI or THEME.Text
			playSound(SOUND_CLICK, 0.22, on and 1.05 or 0.95)
			fire(opts.ChipCallback, on)
		end
        function eApi:Get() return st end
		extraChip.Activated:Connect(function() eApi:Set(not st) end)
		api_extra_chip = eApi
	end
	self.Window:_index(self, frame, opts.Name or "Value", opts.Description)

	local track = new("Frame", {
		Position = UDim2.new(0, 12, 1, -16),
		Size = UDim2.new(1, -24, 0, 4),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = frame,
	}, { round() })
	local fill = new("Frame", {
		BackgroundColor3 = self.Accent, BorderSizePixel = 0, ZIndex = 4, Parent = track,
	}, { round() })
	local function makeKnob()
		local k = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = self.Accent,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = track,
		}, { round() })
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(4, 4), BackgroundColor3 = self.AccentInverse,
			BorderSizePixel = 0, ZIndex = 6, Parent = k,
		}, { round() })
		return k
	end
	local knobA, knobB = makeKnob(), makeKnob()
	local hit = new("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 1, -14),
		Size = UDim2.new(1, -12, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 7,
		Parent = frame,
	})
	hoverable(frame, frame)

	local editing = false
	local morphing = false
	local function pctOf(x) return (max == min) and 0 or (x - min) / (max - min) end
	local function render(instant)
		if morphing then return end
		local t = instant and 0 or 0.12
		if randomize then
			knobB.Visible = true
			tween(knobA, t, { Position = UDim2.fromScale(pctOf(lo), 0.5) })
			tween(knobB, t, { Position = UDim2.fromScale(pctOf(hi), 0.5) })
			tween(fill, t, { Position = UDim2.fromScale(pctOf(lo), 0), Size = UDim2.fromScale(pctOf(hi) - pctOf(lo), 1) })
			if not editing then valueLabel.Text = format(lo) .. suffix .. "  -  " .. format(hi) .. suffix end
		else
			knobB.Visible = false
			tween(knobA, t, { Position = UDim2.fromScale(pctOf(val), 0.5) })
			tween(fill, t, { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(pctOf(val), 1) })
			if not editing then valueLabel.Text = format(val) .. suffix end
		end
	end

	local FADE = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function setKnobAlpha(k, t)
		k.BackgroundTransparency = t
		local dot = k:FindFirstChildOfClass("Frame")
		if dot then dot.BackgroundTransparency = t end
	end
	local function fadeKnob(k, t)
		TweenService:Create(k, FADE, { BackgroundTransparency = t }):Play()
		local dot = k:FindFirstChildOfClass("Frame")
		if dot then TweenService:Create(dot, FADE, { BackgroundTransparency = t }):Play() end
	end
	local morphTok = 0
	local api = {}
	function api:SetRandomize(on)
		on = on == true
		if on == randomize then return end
		randomize = on
		tween(rngChip, 0.25, { BackgroundColor3 = on and ACC or THEME.Switch })
		rngChip.TextColor3 = on and ACCI or THEME.Text

		morphing = true
		morphTok += 1
		local tok = morphTok

		fadeKnob(knobA, 1)
		fadeKnob(knobB, 1)
		TweenService:Create(fill, FADE, { BackgroundTransparency = 1 }):Play()

		task.delay(0.1, function()
			if tok ~= morphTok then return end
			if randomize then
				knobB.Visible = true
				knobA.Position = UDim2.fromScale(pctOf(lo), 0.5)
				knobB.Position = UDim2.fromScale(pctOf(hi), 0.5)
				fill.Position = UDim2.fromScale(pctOf(lo), 0)
				fill.Size = UDim2.fromScale(pctOf(hi) - pctOf(lo), 1)
				if not editing then valueLabel.Text = format(lo) .. suffix .. "  -  " .. format(hi) .. suffix end
			else
				knobB.Visible = false
				knobA.Position = UDim2.fromScale(pctOf(val), 0.5)
				fill.Position = UDim2.fromScale(0, 0)
				fill.Size = UDim2.fromScale(pctOf(val), 1)
				if not editing then valueLabel.Text = format(val) .. suffix end
			end
			TweenService:Create(fill, FADE, { BackgroundTransparency = 0 }):Play()
			fadeKnob(knobA, 0)
			if randomize then fadeKnob(knobB, 0) end
			task.delay(0.12, function()
				if tok == morphTok then morphing = false end
			end)
		end)
		playSound(SOUND_CLICK, 0.25, on and 1.1 or 0.9)
		fire(opts.Callback, api:Config())
	end
	function api:Config()
		if randomize then return { randomize = true, min = lo, max = hi } end
		return { randomize = false, value = val }
	end
	api.Chip = api_extra_chip
	function api:Get()
		if randomize then
			if decimals == 0 and increment == 1 then return math.random(math.floor(lo), math.floor(hi)) end
			return snap(lo + math.random() * (hi - lo))
		end
		return val
	end
	function api:Set(a, b)
		if randomize then
			local nl, nh = snap(tonumber(a) or lo), snap(tonumber(b) or hi)
			if nl > nh then nl, nh = nh, nl end
			lo, hi = nl, nh
		else
			val = snap(tonumber(a) or val)
		end
		render(false)
		fire(opts.Callback, api:Config())
	end

	rngChip.Activated:Connect(function()
		playSound(SOUND_CLICK, 0.22, randomize and 0.95 or 1.05)
		api:SetRandomize(not randomize)
	end)

	local active
	local function valueAt(x)
		local pos, size = track.AbsolutePosition.X, track.AbsoluteSize.X
		if size <= 0 then return min end
		return min + (max - min) * math.clamp((x - pos) / size, 0, 1)
	end
	trackDrag(self.Window, hit, function(pos, began)
		local x = valueAt(pos.X)
		if began then
			playSound(SOUND_CLICK, 0.25, 1.1)
			tween(valueLabel, 0.2, { TextColor3 = THEME.Text })
			if randomize then
				active = (math.abs(x - lo) <= math.abs(x - hi)) and "lo" or "hi"
				if lo == hi then active = x < lo and "lo" or "hi" end
			end
		end
		if randomize then
			if active == "lo" then
				if x > hi then active = "hi" api:Set(hi, x) else api:Set(x, hi) end
			else
				if x < lo then active = "lo" api:Set(x, lo) else api:Set(lo, x) end
			end
		else
			api:Set(x)
		end
	end, function()
		tween(valueLabel, 0.2, { TextColor3 = THEME.SubText })
	end)

	valueLabel.Focused:Connect(function()
		editing = true
		valueLabel.Text = randomize and (format(lo) .. " - " .. format(hi)) or format(val)
		selectAll(valueLabel)
		tween(valueLabel, 0.15, { BackgroundTransparency = 0.9, TextColor3 = THEME.Text })
	end)
	valueLabel.FocusLost:Connect(function()
		editing = false
		tween(valueLabel, 0.15, { BackgroundTransparency = 1, TextColor3 = THEME.SubText })
		local nums = {}
		for n in string.gmatch(valueLabel.Text, "%-?%d+%.?%d*") do table.insert(nums, tonumber(n)) end
		if randomize then
			if #nums >= 2 then api:Set(nums[1], nums[2]) elseif #nums == 1 then api:Set(nums[1], nums[1]) end
		elseif #nums >= 1 then
			api:Set(nums[1])
		end
		render(true)
	end)

	rngChip.TextColor3 = randomize and self.AccentInverse or THEME.Text
	rngChip.BackgroundColor3 = randomize and self.Accent or THEME.Switch
	render(true)
	return api
end

function Tab:AddKeybind(opts)
	opts = opts or {}
	local key = opts.Default
	local listening = false

	local frame = elementFrame(self, opts.Description and 50 or 38)
	titleBlock(frame, opts.Name or "Keybind", opts.Description, 110)
	self.Window:_index(self, frame, opts.Name or "Keybind", opts.Description)

	local keyChip = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 0.92,
		AutoButtonColor = false,
		Font = FONT_MEDIUM,
		TextSize = 12,
		TextColor3 = THEME.Text,
		ZIndex = 6,
		Parent = frame,
	}, { corner(6), stroke(Color3.new(1, 1, 1), 0.85), pad(0, 10, 0, 10) })
	local chipStroke = keyChip:FindFirstChildOfClass("UIStroke")

	local function render()
		keyChip.Text = listening and "..." or (key and key.Name or "None")
	end

	local api = {}
	function api:Set(newKey)
		key = newKey
		render()
		fire(opts.ChangedCallback, key)
	end
	function api:Get() return key end

	keyChip.Activated:Connect(function()
		listening = true
		render()
		playSound(SOUND_CLICK, 0.25, 1.1)
		tween(chipStroke, 0.2, { Transparency = 0.3 })
		beginCapture(self.Window, function(keyCode)
			listening = false
			tween(chipStroke, 0.2, { Transparency = 0.85 })
			if keyCode == Enum.KeyCode.Escape then
				if opts.AllowNone == false then render() else api:Set(nil) end
			else
				api:Set(keyCode)
			end
		end)
	end)
	hoverable(frame, keyChip)

	onKeyPressed(self.Window, function(keyCode)
		if key and keyCode == key then fire(opts.Callback, key) end
	end)

	render()
	return api
end

function Tab:AddInput(opts)
	opts = opts or {}
	local isSearch = opts.Search == true
	local hasPicker = type(opts.PickerSource) == "function"
	local frame = elementFrame(self, opts.Description and 50 or 38)
	frame.ClipsDescendants = true
	titleBlock(frame, opts.Name or "Input", opts.Description, 160)
	self.Window:_index(self, frame, opts.Name or "Input", opts.Description)

	local COLLAPSED, EXPANDED = 28, 170
	local boxW = isSearch and COLLAPSED or 140
	local box = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(boxW, 24),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = isSearch and 1 or 0.94,
		ClearTextOnFocus = false,
		Font = FONT,
		TextSize = 12,
		TextColor3 = THEME.Text,
		PlaceholderText = opts.Placeholder or "Type here...",
		PlaceholderColor3 = THEME.Muted,
		Text = tostring(opts.Default or ""),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextEditable = not isSearch,
		ClipsDescendants = true,
		ZIndex = 6,
		Parent = frame,
	}, { corner(6), stroke(Color3.new(1, 1, 1), isSearch and 1 or 0.88), pad(0, isSearch and 30 or 8, 0, 8) })
	local boxStroke = box:FindFirstChildOfClass("UIStroke")
	hoverable(frame, frame)

	local searchBtn, searchImg, searchGlyph
	if isSearch then
		searchBtn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 8,
			Parent = frame,
		})
		local useIcon = type(ICONS.Search) == "string" and ICONS.Search ~= ""
		if useIcon then
			searchImg = new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(15, 15), BackgroundTransparency = 1,
				Image = ICONS.Search, ImageColor3 = THEME.SubText, ZIndex = 9, Parent = searchBtn,
			})
		else
			searchGlyph = label({
				Text = "⌕", Font = FONT_BOLD, TextSize = 17, TextColor3 = THEME.SubText,
				Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 9, Parent = searchBtn,
			})
		end
	end

	local picker
	if hasPicker then
		picker = new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, (opts.Description and 50 or 38) - 6),
			Size = UDim2.fromOffset(EXPANDED, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = THEME.Glass,
			BackgroundTransparency = SOLID_T,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 30,
			Parent = frame,
		}, {
			corner(8), stroke(Color3.new(1, 1, 1), 0.86), pad(5, 5, 5, 5),
			new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end

	local api = {}
	function api:Set(text)
		box.Text = tostring(text)
		fire(opts.Callback, box.Text)
	end
	function api:Get() return box.Text end

	local function clearPicker()
		if not picker then return end
		for _, c in ipairs(picker:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
	end
	local function runPicker()
		if not picker then return end
		clearPicker()
		local q = box.Text:gsub("^%s+", ""):gsub("%s+$", ""):lower()
		local source = opts.PickerSource() or {}
		local shown = 0
		for i, entry in ipairs(source) do
			local lbl = type(entry) == "table" and entry.label or tostring(entry)
			if (q == "" or lbl:lower():find(q, 1, true)) and shown < 6 then
				shown += 1
				local b = new("TextButton", {
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = THEME.Card, BackgroundTransparency = 0.94,
					AutoButtonColor = false, Text = "", LayoutOrder = shown, ZIndex = 31, Parent = picker,
				}, { corner(5) })
				label({
					Text = lbl, Font = FONT_MEDIUM, TextSize = 12, TextColor3 = THEME.Text,
					Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -16, 1, 0),
					TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 32, Parent = b,
				})
				b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundTransparency = 0.88 }) end)
				b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundTransparency = 0.94 }) end)
				b.Activated:Connect(function()
					box.Text = lbl
					picker.Visible = false
					fire(opts.PickerCallback or opts.Callback, entry)
				end)
			end
		end
		picker.Visible = shown > 0
	end

	local searchOpen = false
	local function setSearch(open)
		if not isSearch then return end
		if open == searchOpen then return end
		searchOpen = open
		if open then
			box.TextEditable = true
			tween(box, 0.3, { Size = UDim2.fromOffset(EXPANDED, 24), BackgroundTransparency = 0.92 }, Enum.EasingStyle.Quint)
			tween(boxStroke, 0.3, { Transparency = 0.82 })
			task.delay(0.1, function() if searchOpen then box:CaptureFocus() end end)
			playSound(SOUND_CLICK, 0.22, 1.1)
		else
			box.TextEditable = false
			tween(box, 0.3, { Size = UDim2.fromOffset(COLLAPSED, 24), BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
			tween(boxStroke, 0.3, { Transparency = 1 })
			if picker then picker.Visible = false end
		end
	end
	if isSearch then
		searchBtn.Activated:Connect(function()
			if searchOpen then box:CaptureFocus() else setSearch(true) end
		end)
	end

	box.Focused:Connect(function()
		tween(boxStroke, 0.2, { Transparency = 0.4 })
		if not isSearch then tween(box, 0.2, { BackgroundTransparency = 0.9 }) end
		if hasPicker then runPicker() end
	end)
	if hasPicker then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if box:IsFocused() then runPicker() end
		end)
	end
	box.FocusLost:Connect(function(enter)
		tween(boxStroke, 0.2, { Transparency = isSearch and (searchOpen and 0.82 or 1) or 0.88 })
		if not isSearch then tween(box, 0.2, { BackgroundTransparency = 0.94 }) end
		task.wait(0.15)
		if picker and not picker.Visible then else if picker then picker.Visible = false end end
		if opts.Numeric and not tonumber(box.Text) then
			box.Text = tostring(opts.Default or "")
		elseif enter or not opts.EnterOnly then
			fire(opts.Callback, box.Text)
		end
		if isSearch and box.Text == "" then setSearch(false) end
	end)

	function api:Reset()
		box.Text = ""
		if picker then picker.Visible = false end
		if box:IsFocused() then box:ReleaseFocus() end
		if isSearch then setSearch(false) end
	end
	return api
end

function Tab:AddPlayerSearch(opts)
	opts = opts or {}
	local Players = game:GetService("Players")
	local HEADER, ROW_H = 40, 40

	local frame = elementFrame(self, HEADER)
	frame.ClipsDescendants = true

	local box = new("TextBox", {
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.new(1, -52, 0, 24),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 0.88,
		ClearTextOnFocus = false,
		Font = FONT,
		TextSize = 12,
		TextColor3 = THEME.Text,
		PlaceholderText = opts.Placeholder or "Search a player...",
		PlaceholderColor3 = Color3.new(1, 1, 1),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 6,
		Parent = frame,
	}, { corner(6), stroke(Color3.new(1, 1, 1), 0.85), pad(0, 8, 0, 8) })
	local boxStroke = box:FindFirstChildOfClass("UIStroke")

	local focusBlocker = new("TextButton", {
		Position = box.Position,
		Size = box.Size,
		BackgroundTransparency = 1,
		Text = "",
		Visible = false,
		ZIndex = 9,
		Parent = frame,
	})
	box.Focused:Connect(function() focusBlocker.Visible = true end)
	box.FocusLost:Connect(function() focusBlocker.Visible = false end)
	focusBlocker.Activated:Connect(function()
		box:ReleaseFocus()
		focusBlocker.Visible = false
	end)

	focusBlocker.MouseEnter:Connect(function()
		UserInputService.MouseIcon = "rbxasset://SystemCursors/PointingHand"
		tween(boxStroke, 0.12, { Transparency = 0.2 })
	end)
	focusBlocker.MouseLeave:Connect(function()
		UserInputService.MouseIcon = ""
		tween(boxStroke, 0.12, { Transparency = 0.4 })
	end)

	local searchBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 0.82,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 7,
		Parent = frame,
	}, { corner(6), stroke(Color3.new(1, 1, 1), 0.85) })
	local useSearchIcon = type(ICONS.Search) == "string" and ICONS.Search ~= ""
	if useSearchIcon then
		new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
			Image = ICONS.Search, ImageColor3 = THEME.Body, ZIndex = 8, Parent = searchBtn,
		})
	else
		label({
			Text = "⌕", Font = FONT_BOLD, TextSize = 16, TextColor3 = THEME.Body,
			Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 8, Parent = searchBtn,
		})
	end

	local listHolder = new("Frame", {
		Position = UDim2.new(0, 10, 0, HEADER),
		Size = UDim2.new(1, -20, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = frame,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8) }),
	})

	local open = false
	local selecting = false
	local api = {}

	local function rebuild(query)
		for _, c in ipairs(listHolder:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		query = (query or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
		local shown = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= game:GetService("Players").LocalPlayer then
				local hitName = p.Name:lower():find(query, 1, true)
				local hitDisp = p.DisplayName:lower():find(query, 1, true)
				if (query == "" or hitName or hitDisp) and shown < 20 then
					shown += 1
					local row = new("TextButton", {
						Size = UDim2.new(1, 0, 0, ROW_H),
						BackgroundColor3 = THEME.Card,
						BackgroundTransparency = CARD_T,
						AutoButtonColor = false,
						Text = "",
						LayoutOrder = shown,
						ZIndex = 6,
						Parent = listHolder,
					}, { corner(7), stroke(Color3.new(1, 1, 1), 0.92) })
					local pfp = new("ImageLabel", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 6, 0.5, 0),
						Size = UDim2.fromOffset(28, 28),
						BackgroundColor3 = THEME.Switch,
						ZIndex = 7,
						Parent = row,
					}, { round(), stroke(Color3.new(1, 1, 1), 0.85) })
					task.spawn(function()
						local ok, img = pcall(function()
							return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
						end)
						if ok and pfp.Parent then pfp.Image = img end
					end)
					label({
						Text = p.DisplayName, Font = FONT_MEDIUM, TextSize = 13, TextColor3 = THEME.Text,
						Position = UDim2.fromOffset(42, 5), Size = UDim2.new(1, -52, 0, 16),
						TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, Parent = row,
					})
					label({
						Text = "@" .. p.Name, TextSize = 11, TextColor3 = THEME.SubText,
						Position = UDim2.fromOffset(42, 21), Size = UDim2.new(1, -52, 0, 13),
						TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, Parent = row,
					})
					row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundTransparency = CARD_HOVER_T }) end)
					row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundTransparency = CARD_T }) end)
					row.Activated:Connect(function()
						selecting = true
						box.Text = p.DisplayName
						selecting = false
						fire(opts.Callback, p)
						api:Close()
					end)
				end
			end
		end

		local listH = shown > 0 and (shown * (ROW_H + 4) + 10) or 0
		listHolder.Size = UDim2.new(1, -20, 0, math.max(listH, 0))
		return listH
	end

	function api:Open()
		if open then return end
		open = true
		local listH = rebuild(box.Text)
		tween(frame, 0.3, { Size = UDim2.new(1, 0, 0, HEADER + listH) }, Enum.EasingStyle.Quint)
		tween(boxStroke, 0.2, { Transparency = 0.4 })
		playSound(SOUND_CLICK, 0.2, 1.05)
	end
	function api:Close()
		if not open then return end
		open = false
		if box:IsFocused() then box:ReleaseFocus() end
		tween(frame, 0.3, { Size = UDim2.new(1, 0, 0, HEADER) }, Enum.EasingStyle.Quint)
		tween(boxStroke, 0.2, { Transparency = 0.85 })
	end
	function api:Toggle() if open then api:Close() else api:Open() end end

	searchBtn.Activated:Connect(function()
		if box:IsFocused() then
			box:ReleaseFocus()
		elseif open then
			box:CaptureFocus()
		else
			api:Open()
		end
	end)
	local focusGuard = false
	box.Focused:Connect(function()
		focusGuard = true
		if box.Text ~= "" then
			box.Text = ""
			rebuild("")
		end
		api:Open()
		task.delay(0.1, function() focusGuard = false end)
	end)

	box.FocusLost:Connect(function()
		task.delay(0.05, function()
			if selecting then return end
			if open and not box:IsFocused() then api:Close() end
		end)
	end)
	box.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		if box:IsFocused() and not focusGuard then
			box:ReleaseFocus()
		end
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if open and not selecting then
			local listH = rebuild(box.Text)
			tween(frame, 0.15, { Size = UDim2.new(1, 0, 0, HEADER + listH) })
		end
	end)
	searchBtn.MouseEnter:Connect(function() tween(searchBtn, 0.15, { BackgroundTransparency = 0.74 }) end)
	searchBtn.MouseLeave:Connect(function() tween(searchBtn, 0.15, { BackgroundTransparency = 0.82 }) end)

	return api
end

Library.Icons = ICONS

return Library

end)()

local camera = Workspace.CurrentCamera

local UI = Library.new({
	Title = "PYRA",
	Status = "Active",
	StatusColor = Color3.fromRGB(90, 220, 130),
	Expiry = "12/21/2036",
	ToggleKey = Enum.KeyCode.RightShift,
	SessionStart = _G.PyraSessionStart or SESSION_START,
})
_G.PyraUI = UI


local Combat = UI:AddTab("Combat")
local Extra = UI:AddTab("Extra")
local Target = UI:AddTab("Target")
local Settings = UI:AddTab("Settings")

local DISCORD_CODE = "pyra"
local DISCORD_URL = "https://discord.gg/" .. DISCORD_CODE

local function openDiscord()
	local request = http_request or request or (syn and syn.request) or (http and http.request)
	if not request then
		if setclipboard and pcall(setclipboard, DISCORD_URL) then return "clipboard" end
		return "none"
	end
	local ok = pcall(function()
		request({
			Url = "http://127.0.0.1:6463/rpc?v=1",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["origin"] = "https://discord.com",
			},
			Body = game:GetService("HttpService"):JSONEncode({
				["args"] = { ["code"] = DISCORD_CODE },
				["cmd"] = "INVITE_BROWSER",
				["nonce"] = ".",
			}),
		})
	end)
	if ok then return "app" end
	if setclipboard and pcall(setclipboard, DISCORD_URL) then return "clipboard" end
	return "none"
end

UI:AddTabIcon(Library.Icons.Discord, function()
	task.spawn(function()
		local how = openDiscord()
		if how == "app" then
			UI:Notify("Discord", "Opening the invite in Discord.", 4)
		elseif how == "browser" then
			UI:Notify("Discord", "Opened the invite in your browser.", 4)
		elseif how == "clipboard" then
			UI:Notify("Discord", "Link copied - discord.gg/" .. DISCORD_CODE, 5)
		else
			UI:Notify("Discord", "Join at discord.gg/" .. DISCORD_CODE, 6)
		end
	end)
end, 24)

Combat:AddSection("Parry")
local parryGroup = Combat:AddGroup()
parryGroup:AddToggle({
	Name = "Auto Parry",
	Description = "Predicts incoming balls and parries only on impact.",
	Default = false,
	Icon = Library.Icons.Sword,
	IconSelected = Library.Icons.Sword_Selected,
	IconToggle = true,
	Callback = function(s)
		AP_setActive(s)
		if s then AP_start() else AP_stop() end
	end,
})
parryGroup:AddRandomSlider({
	Name = "Accuracy",
	Min = 1, Max = 100, Increment = 1, Default = 50,
	DefaultMin = 40, DefaultMax = 100, Suffix = "%",
	Randomize = false,
	Chip = "ANIMATION FIX",
	ChipDefault = true,
	ChipCallback = function(on) parryAnimationEnabled = on end,
	Callback = function(cfg)
		if cfg.randomize then
			randomAccuracy = true
			accuracyRangeMin = math.min(cfg.min, cfg.max)
			accuracyRangeMax = math.max(cfg.min, cfg.max)
		else
			randomAccuracy = false
			parryAccuracy = cfg.value
		end
	end,
})
local curveHandle = parryGroup:AddDropdown({
	Name = "Curve Type",
	Options = { "Custom", "Dot", "Accelerated", "Backwards", "Random", "Up", "Left", "Right" },
	Default = "Custom",
	NumberStart = 0,
	Callback = function(v)
		parryType = v
		if getgenv then getgenv()._clockParryType = v end
	end,
})
local methodHandle = parryGroup:AddSlider({
	Name = "Accel Lift",
	Description = "Upward angle for the Accelerated curve",
	Min = 10, Max = 150, Increment = 5, Default = 70, Suffix = "%",
	Callback = function(v) accelLift = v end,
})
parryGroup:AddDropdown({
	Name = "Parry Type",
	Options = { "Remote", "Keyboard" },
	Default = "Remote",
	NumberStart = 8,
	Callback = function(v) parryMethod = v end,
})

Combat:AddSection("Spam")
local autoSpamGroup = Combat:AddGroup()
autoSpamGroup:AddToggle({
	Name = "Auto Spam",
	Description = "Detects when to spam parry",
	Default = false,
	Icon = Library.Icons.Sword,
	IconSelected = Library.Icons.Sword_Selected,
	IconToggle = true,
	Callback = function(s) spamDetectionEnabled = s end,
})
autoSpamGroup:AddSlider({
	Name = "Spam Range",
	Min = -10, Max = 10, Increment = 1, Default = 7,
	Callback = function(v) spamThresholdOffset = v end,
})
local manualGroup = Combat:AddGroup()
local RESERVED_KEYS = {
	[Enum.KeyCode.Zero] = "Curve 0",
	[Enum.KeyCode.One] = "Curve 1",
	[Enum.KeyCode.Two] = "Curve 2",
	[Enum.KeyCode.Three] = "Curve 3",
	[Enum.KeyCode.Four] = "Curve 4",
	[Enum.KeyCode.Five] = "Curve 5",
	[Enum.KeyCode.Six] = "Curve 6",
	[Enum.KeyCode.Seven] = "Curve 7",
	[Enum.KeyCode.Eight] = "Parry Type 8",
	[Enum.KeyCode.Nine] = "Parry Type 9",
}
local manualToggle
manualToggle = manualGroup:AddToggle({
	Name = "Manual Spam",
	Description = "Hold the bind to spam parry",
	Default = false,
	Icon = Library.Icons.Sword,
	IconSelected = Library.Icons.Sword_Selected,
	IconToggle = true,
	Chip = "Hold",
	ChipDefault = true,
	ChipCallback = function(on) manualSpamHold = on end,
	Keybind = Enum.KeyCode.E,
	KeybindChanged = function(key)
		local clash = key and RESERVED_KEYS[key]
		if clash then
			UI:Notify("Keybind in use", key.Name .. " is reserved for " .. clash .. ".", 4)
			if manualToggle and manualToggle.Keybind then
				manualToggle.Keybind:Set(manualSpamBind)
			end
			return
		end
		manualSpamBind = key
	end,
	Callback = function(s)
		manualSpamEnabled = s
		if not s then stopManualSpamGrim() end
		if _mobileSpamGui then _mobileSpamGui.Enabled = s end
	end,
})
do
	local function matches(input) return input.KeyCode == manualSpamBind end
	table.insert(UI.Connections, UserInputService.InputBegan:Connect(function(input, gp)
		if gp or not manualSpamEnabled then return end
		if not matches(input) then return end
		if manualSpamHold then
			if not spamming then startManualSpamGrim() end
		else
			if spamming then stopManualSpamGrim() else startManualSpamGrim() end
		end
	end))
	table.insert(UI.Connections, UserInputService.InputEnded:Connect(function(input)
		if not matches(input) then return end
		if manualSpamHold then stopManualSpamGrim() end
	end))
	local mobileManual = UI:AddMobileButton({
		Name = "Manual Spam",
		Toggle = true,
		Default = false,
		OnClick = function(on) if manualToggle then manualToggle:Set(on) end end,
	})
	mobileManual:SetVisible(false)
	if manualToggle and manualToggle.OnChanged then
		manualToggle:OnChanged(function(on)
			mobileManual:Set(on, true)
			mobileManual:SetVisible(on)
		end)
	end
end

Extra:AddSection("Display")
local displayGroup = Extra:AddGroup()
displayGroup:AddSlider({
	Name = "Field of View",
	Min = 70, Max = 120, Increment = 1, Default = 70,
	Callback = function(v) setFOV(v) end,
})
displayGroup:AddToggle({
	Name = "Ability ESP",
	Description = "Billboards for enemy abilities",
	Default = false,
	Callback = function(s)
		abilityESPEnabled = s
		if s then startAbilityESP() else stopAbilityESP() end
	end,
})
displayGroup:AddToggle({
	Name = "Visualizer",
	Description = "Sphere scaled to ball speed",
	Default = false,
	Callback = function(s)
		visualizerEnabled = s
		startBallTrailLoop()
		if s then startVisualizer() else stopVisualizer() end
	end,
})

Extra:AddSection("World")
local worldGroup = Extra:AddGroup()
worldGroup:AddToggle({
	Name = "No Render",
	Description = "Stops unnecessary visuals",
	Default = false,
	Callback = function(s)
		noRenderEnabled = s
		if s then startNoRender() else stopNoRender() end
	end,
})
worldGroup:AddToggle({
	Name = "Raytracing",
	Description = "Toggle bloom and depth effects",
	Default = false,
	Callback = function(s) raytracingEnabled = s; setRaytracing(s) end,
})
local fbHandle, fdHandle
fbHandle = worldGroup:AddToggle({
	Name = "Fullbright",
	Description = "Max brightness lighting",
	Default = false,
	Callback = function(s)
		fullbrightEnabled = s
		if s and fulldarkEnabled then fulldarkEnabled = false; if fdHandle then fdHandle:Set(false, true) end; setFulldark(false) end
		setFullbright(s)
	end,
})
fdHandle = worldGroup:AddToggle({
	Name = "Fulldark",
	Description = "Pitch black lighting",
	Default = false,
	Callback = function(s)
		fulldarkEnabled = s
		if s and fullbrightEnabled then fullbrightEnabled = false; if fbHandle then fbHandle:Set(false, true) end; setFullbright(false) end
		setFulldark(s)
	end,
})

Extra:AddSection("Player")
do
	local moveEnabled, moveSpeed = false, 0
	local antiSlow = false
	local gravityMod, gravityPower = false, 0
	local orbitEnabled, orbitDistance, orbitHeight, orbitSpeed = false, 35, 0, 2.4
	local orbitAngle = 0
	local DEFAULT_GRAVITY = 196.2

	local function realBall()
		for _, b in ipairs(ballsNow()) do
			if b:IsA("BasePart") and b:GetAttribute("realBall") then return b end
		end
		return nil
	end
	local function myAliveChar()
		local alive = Workspace:FindFirstChild("Alive")
		return alive and alive:FindFirstChild(player.Name) or nil
	end

	local playerGroup = Extra:AddGroup()
	playerGroup:AddToggle({
		Name = "Speed Boost",
		Default = false,
		Callback = function(s) moveEnabled = s end,
	})
	playerGroup:AddSlider({
		Name = "Boost Power",
		Min = 0, Max = 50, Increment = 1, Default = 0,
		Callback = function(v) moveSpeed = v end,
	})
	playerGroup:AddToggle({
		Name = "Anti-Slow",
		Description = "Keeps walk speed from being slowed",
		Default = false,
		Callback = function(s) antiSlow = s end,
	})

	local gravGroup = Extra:AddGroup({ Collapsible = true, DefaultExpanded = false })
	gravGroup:AddToggle({
		Name = "Gravity Mod",
		Description = "Lowers world gravity",
		Default = false,
		Callback = function(s)
			gravityMod = s
			gravGroup:SetExpanded(s)
			if not s then pcall(function() Workspace.Gravity = DEFAULT_GRAVITY end) end
		end,
	})
	gravGroup.Body:AddSlider({
		Name = "Gravity Power",
		Min = 0, Max = 50, Increment = 1, Default = 0,
		Callback = function(v) gravityPower = v end,
	})

	local orbitGroup = Extra:AddGroup({ Collapsible = true, DefaultExpanded = false })
	orbitGroup:AddToggle({
		Name = "Orbit Around Ball",
		Description = "Circles your character around the ball",
		Default = false,
		Callback = function(s)
			orbitEnabled = s
			orbitGroup:SetExpanded(s)
			if not s then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then hrp.AssemblyAngularVelocity = Vector3.zero end
			end
		end,
	})
	orbitGroup.Body:AddSlider({
		Name = "Orbit Distance",
		Min = 0, Max = 200, Increment = 1, Default = 35,
		Callback = function(v) orbitDistance = v end,
	})
	orbitGroup.Body:AddSlider({
		Name = "Orbit Height",
		Min = -100, Max = 200, Increment = 1, Default = 0,
		Callback = function(v) orbitHeight = v end,
	})
	orbitGroup.Body:AddSlider({
		Name = "Orbit Speed",
		Min = 1, Max = 100, Increment = 1, Default = 2,
		Callback = function(v) orbitSpeed = math.max(0.1, v) end,
	})

	table.insert(UI.Connections, RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		if not char then return end

		if moveEnabled and moveSpeed > 0 and char.PrimaryPart then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.MoveDirection.Magnitude > 0 then
				pcall(function()
					char:TranslateBy(hum.MoveDirection * moveSpeed * dt * 1.2)
				end)
			end
		end

		if antiSlow and myAliveChar() then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.WalkSpeed < 36 then hum.WalkSpeed = 36 end
		end

		if gravityMod and gravityPower > 0 then
			local goal = DEFAULT_GRAVITY / (gravityPower / 10)
			if Workspace.Gravity ~= goal then Workspace.Gravity = goal end
		elseif not gravityMod and Workspace.Gravity ~= DEFAULT_GRAVITY then
			Workspace.Gravity = DEFAULT_GRAVITY
		end

		if orbitEnabled then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			local ball = realBall()
			if hrp and hum and hum.Health > 0 and ball and myAliveChar() then
				local ballPos = ball.Position
				orbitAngle = (orbitAngle + (orbitSpeed * dt)) % (math.pi * 2)
				local radius = math.clamp(orbitDistance, 0, 200)
				local height = math.clamp(orbitHeight, -100, 200)
				local goalPos = ballPos + Vector3.new(math.cos(orbitAngle) * radius, height, math.sin(orbitAngle) * radius)
				local smooth = hrp.Position:Lerp(goalPos, math.clamp(dt * 8, 0.08, 0.28))
				hrp.CFrame = CFrame.new(smooth, Vector3.new(ballPos.X, smooth.Y, ballPos.Z))
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end))

	UI:OnDestroy(function()
		pcall(function() Workspace.Gravity = DEFAULT_GRAVITY end)
	end)
end

Extra:AddSection("Autoplay")
do
	local apEnabled, apMode, apJump = false, "Dynamic", true
	local avEnabled, avMode = false, "FFA"

	local AP_PRESSURE = 20
	local AP = {
		CurrentTarget = nil, TargetTime = 0, State = "idle",
		LastPosition = nil, StuckTime = 0, StuckCheckTime = 0, LastJump = 0, NextJump = 1.2, Circle = 0, HoldUntil = 0,
	}

	local function alivePlayers()
		local alive = Workspace:FindFirstChild("Alive")
		return alive and alive:GetChildren() or _NO_BALLS
	end
	local function realBall()
		for _, b in ipairs(ballsNow()) do
			if b:IsA("BasePart") and b:GetAttribute("realBall") then return b end
		end
		return nil
	end
	local function randomPos(center, radius)
		local a = math.random() * math.pi * 2
		local d = math.random() * radius
		return center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
	end
	local function setTargetPos(pos, state)
		AP.CurrentTarget = pos
		AP.TargetTime = tick()
		AP.State = state or "roaming"
		AP.StuckTime = 0
	end
	local function isStuck(hrp)
		if (tick() - AP.StuckCheckTime) < 0.5 then return false end
		AP.StuckCheckTime = tick()
		if AP.LastPosition then
			if (hrp.Position - AP.LastPosition).Magnitude < 1 then
				AP.StuckTime = AP.StuckTime + 0.5
			else
				AP.StuckTime = 0
			end
		end
		AP.LastPosition = hrp.Position
		return AP.StuckTime >= 1.5
	end
	local function unstuckPos(char, hrp)
		local dirs = {
			hrp.CFrame.RightVector, -hrp.CFrame.RightVector, -hrp.CFrame.LookVector,
			(hrp.CFrame.RightVector + hrp.CFrame.LookVector).Unit,
			(-hrp.CFrame.RightVector + hrp.CFrame.LookVector).Unit,
		}
		local rp = RaycastParams.new()
		rp.FilterDescendantsInstances = { char }
		rp.FilterType = Enum.RaycastFilterType.Exclude
		for _, d in ipairs(dirs) do
			local flat = Vector3.new(d.X, 0, d.Z)
			if flat.Magnitude > 0.01 then
				flat = flat.Unit
				if not Workspace:Raycast(hrp.Position, flat * 20, rp) then
					return hrp.Position + flat * 15
				end
			end
		end
		return randomPos(hrp.Position, 10)
	end
	local function needsNewTarget(hrp)
		if not AP.CurrentTarget then return true end
		if isStuck(hrp) then AP.StuckTime = 0 return true end
		if (hrp.Position - AP.CurrentTarget).Magnitude < 5 then return true end
		if (tick() - AP.TargetTime) > 4 then return true end
		return false
	end
	local function moveToTarget(char)
		if not AP.CurrentTarget then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		hum:MoveTo(AP.CurrentTarget)

		if hum.AutoJumpEnabled ~= apJump then hum.AutoJumpEnabled = apJump end
		if not apJump then
			AP.HoldUntil = 0
			return
		end

		local now = tick()
		if now < AP.HoldUntil then
			if hum.FloorMaterial ~= Enum.Material.Air then
				pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
				hum.Jump = true
			end
		elseif (now - AP.LastJump) >= AP.NextJump then
			AP.LastJump = now
			AP.NextJump = 1.1 + math.random() * 2.2
			AP.HoldUntil = now + (0.25 + math.random() * 0.75)
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
			hum.Jump = true
		end
	end
	local function isRushingMe(entity, hrp)
		local ep = entity.PrimaryPart
		if not ep then return false end
		local v = ep.AssemblyLinearVelocity
		if v.Magnitude < 10 then return false end
		local flat = Vector3.new(v.X, 0, v.Z)
		if flat.Magnitude < 0.01 then return false end
		return flat.Unit:Dot((hrp.Position - ep.Position).Unit) > 0.6
	end
	local function closestRusher(char, hrp)
		local best, bd = nil, math.huge
		for _, e in ipairs(alivePlayers()) do
			if e ~= char and e.PrimaryPart then
				local d = (hrp.Position - e.PrimaryPart.Position).Magnitude
				if d < 50 and d < bd and isRushingMe(e, hrp) then bd, best = d, e end
			end
		end
		return best, bd
	end
	local function escapePos(hrp, dangerPos)
		local away = (hrp.Position - dangerPos)
		if away.Magnitude < 0.01 then return nil end
		away = away.Unit
		local ang = math.rad(math.random(-45, 45))
		local c, sn = math.cos(ang), math.sin(ang)
		local rot = Vector3.new(away.X * c - away.Z * sn, 0, away.X * sn + away.Z * c)
		return hrp.Position + rot * math.random(15, 25)
	end
	local function rushTarget(char)
		local ball = realBall()
		if not ball then return nil end
		local t = ball:GetAttribute("target")
		for _, e in ipairs(alivePlayers()) do
			if e.Name == t and e ~= char then return e end
		end
		return nil
	end
	local function inSpawn(char, hrp)
		local spawnFolder = Workspace:FindFirstChild("Spawn")
		if not spawnFolder then return false end
		local base = spawnFolder:FindFirstChild("Base")
		if base and base:IsA("BasePart") then
			local pos, bp, half = hrp.Position, base.Position, base.Size * 0.5
			if math.abs(pos.X - bp.X) <= (half.X + 1.5)
			   and math.abs(pos.Z - bp.Z) <= (half.Z + 1.5)
			   and pos.Y >= (bp.Y - half.Y - 3) and pos.Y <= (bp.Y + half.Y + 8) then
				return true
			end
		end
		local rp = RaycastParams.new()
		rp.FilterDescendantsInstances = { char }
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local hit = Workspace:Raycast(hrp.Position, Vector3.new(0, -14, 0), rp)
		return hit ~= nil and hit.Instance ~= nil and hit.Instance:IsDescendantOf(spawnFolder)
	end

	local apGroup = Extra:AddGroup()
	apGroup:AddToggle({
		Name = "Auto Play",
		Description = "Moves and jumps for you",
		Default = false,
		Callback = function(s)
			apEnabled = s
			if not s then
				AP.CurrentTarget = nil
				AP.State = "idle"
				AP.HoldUntil = 0
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then hum.AutoJumpEnabled = false end
			end
		end,
	})
	apGroup:AddDropdown({
		Name = "Auto Play Mode",
		Options = { "Aggressive", "Dynamic", "Safe" },
		Default = "Dynamic",
		Callback = function(v) apMode = v end,
	})
	apGroup:AddToggle({
		Name = "Auto Jump",
		Description = "Holds jump in bursts while roaming",
		Default = false,
		Callback = function(s)
			apJump = s
			AP.HoldUntil = 0
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum.AutoJumpEnabled = s end
		end,
	})

	local voteGroup = Extra:AddGroup()
	voteGroup:AddToggle({
		Name = "Auto Vote",
		Description = "Votes for a mode every round",
		Default = false,
		Callback = function(s) avEnabled = s end,
	})
	voteGroup:AddDropdown({
		Name = "Vote Mode",
		Options = { "FFA", "2Teams", "4Teams" },
		Default = "FFA",
		Callback = function(v) avMode = v end,
	})

	table.insert(UI.Connections, RunService.Heartbeat:Connect(function()
		if not apEnabled then return end
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp or hum.Health <= 0 then return end

		if inSpawn(char, hrp) then
			hum:MoveTo(hrp.Position)
			AP.CurrentTarget = nil
			AP.State = "idle"
			return
		end

		if AP.StuckTime >= 1.5 then
			local up = unstuckPos(char, hrp)
			if up then
				setTargetPos(up, "unstuck")
				moveToTarget(char)
				return
			end
		end

		if apMode == "Aggressive" then
			local rt = rushTarget(char)
			if rt and rt.PrimaryPart then
				local tp = rt.PrimaryPart.Position
				local dist = (hrp.Position - tp).Magnitude
				if dist > AP_PRESSURE + 6 or needsNewTarget(hrp) then
					AP.Circle = (AP.Circle + 0.5 + math.random() * 1.2) % (math.pi * 2)
					local ring = tp + Vector3.new(
						math.cos(AP.Circle) * AP_PRESSURE,
						0,
						math.sin(AP.Circle) * AP_PRESSURE
					)
					setTargetPos(ring, "rushing")
				end
				moveToTarget(char)
				return
			end
		elseif apMode == "Safe" then
			local r, rd = closestRusher(char, hrp)
			if r and rd < 45 then
				local ep = escapePos(hrp, r.PrimaryPart.Position)
				if ep then
					setTargetPos(ep, "escaping")
					moveToTarget(char)
					return
				end
			end
		elseif apMode == "Dynamic" then
			local r, rd = closestRusher(char, hrp)
			if r and rd < 35 and AP.State ~= "escaping" and math.random() > 0.4 then
				local ep = escapePos(hrp, r.PrimaryPart.Position)
				if ep then setTargetPos(ep, "escaping") end
			end
		end

		if needsNewTarget(hrp) then
			setTargetPos(randomPos(hrp.Position, 25), "roaming")
		end
		moveToTarget(char)
	end))

	local function doVote(mode)
		pcall(function()
			local pkgs = ReplicatedStorage:FindFirstChild("Packages")
			local idx = pkgs and pkgs:FindFirstChild("_Index")
			local sl = idx and idx:FindFirstChild("sleitnick_net@0.1.0")
			local net = sl and sl:FindFirstChild("net")
			local re = net and net:FindFirstChild("RE/UpdateVotes")
			if re then re:FireServer(mode) end
		end)
	end
	task.spawn(function()
		while not UI.Destroyed do
			task.wait(1)
			if avEnabled then doVote(avMode) end
		end
	end)
end

local monFps = UI:AddMonitor("fps", "FPS")
local monPing = UI:AddMonitor("ping", "PING")
local monVel = UI:AddMonitor("vel", "BALL")
local _showFps, _showPing, _showBallVel, _fpsUnlocked = false, false, false, false
task.spawn(function()
	local frames, clock = 0, os.clock()
	local conn = RunService.RenderStepped:Connect(function() frames += 1 end)
	table.insert(UI.Connections, conn)
	while not UI.Destroyed do
		local now = os.clock()
		if _showFps then monFps:Set(math.floor(frames / math.max(now - clock, 1e-3) + 0.5)) end
		frames, clock = 0, now
		if _showPing then
			local ok, p = pcall(function() return player:GetNetworkPing() end)
			monPing:Set(ok and (math.floor(p * 1000 + 0.5) .. " ms") or "-- ms")
		end
		if _showBallVel then
			local best = 0
			for _, ball in ipairs(ballsNow()) do
				if ball:IsA("BasePart") and ball:GetAttribute("realBall") then
					local z = ball:FindFirstChild("zoomies")
					if z then
						local m = z.VectorVelocity.Magnitude
						if m > best then best = m end
					end
				end
			end
			monVel:Set(math.floor(best + 0.5) .. " st/s")
		end
		task.wait(0.75)
	end
end)

Settings:AddSection("Monitors")
local fpsUnlockSlider
local _fpsCapWarned = false
local function applyFpsUnlock(unlocked, cap)
	_fpsUnlocked = unlocked
	local target = unlocked and math.max(tonumber(cap) or 1000, 61) or 60
	local ok, how = UI:SetFPSCap(target)
	if ok and how == "fflag" and not _fpsCapWarned then
		_fpsCapWarned = true
		UI:Notify("FPS Unlock", "Applied via fast flag - rejoin for it to take effect.", 7)
	elseif not ok and not _fpsCapWarned then
		_fpsCapWarned = true
		UI:Notify("FPS Unlock", "No FPS cap hook available in this executor.", 7)
	end
end
local fpsGroup = Settings:AddGroup({ Collapsible = false })
fpsGroup:AddToggle({
	Name = "FPS Counter",
	Description = "Show framerate on the HUD bar",
	Default = false,
	Callback = function(on) _showFps = on; monFps:Show(on) end,
})
fpsUnlockSlider = fpsGroup:AddSlider({
	Name = "Unlock FPS",
	Min = 30, Max = 1000, Increment = 10, Default = 60,
	Callback = function(v)
		local unlocked = v > 60
		applyFpsUnlock(unlocked, v)
	end,
})
monFps:OnClick(function()
	local nowUnlocked = not _fpsUnlocked
	applyFpsUnlock(nowUnlocked, 1000)
	if fpsUnlockSlider then fpsUnlockSlider:Set(nowUnlocked and 1000 or 60) end
end)
Settings:AddToggle({
	Name = "Ping Monitor",
	Description = "Show live ping on the HUD bar",
	Default = false,
	Callback = function(on) _showPing = on; monPing:Show(on) end,
})
Settings:AddToggle({
	Name = "Ball Velocity",
	Description = "Show incoming ball speed on the HUD bar",
	Default = false,
	Callback = function(on) _showBallVel = on; monVel:Show(on) end,
})

Settings:AddSection("Immersion")
Settings:AddToggle({
	Name = "Glass Blur",
	Description = "Blurs the UI",
	Default = UI.AcrylicEnabled,
	Callback = function(on) UI:SetAcrylic(on) end,
})
local worldDimGroup = Settings:AddGroup({ Collapsible = true, DefaultExpanded = true })
worldDimGroup:AddToggle({
	Name = "World Dim",
	Description = "Softens lighting while menu is open",
	Default = true,
	Callback = function(on)
		UI:SetWorldDim(on)
		worldDimGroup:SetExpanded(on)
	end,
})
worldDimGroup.Body:AddToggle({
	Name = "Persistent",
	Description = "Keep dim even when closed",
	Default = false,
	Callback = function(on) UI:SetWorldDimPersistent(on) end,
})
Settings:AddToggle({
	Name = "Parallax",
	Description = "Window floats away from your cursor",
	Default = UI.ParallaxEnabled,
	Callback = function(on) UI.ParallaxEnabled = on end,
})

Settings:AddSection("Interface")
Settings:AddKeybind({
	Name = "Toggle Key",
	Description = "Click, then press a key (esc to cancel)",
	Default = UI.ToggleKey,
	AllowNone = false,
	ChangedCallback = function(key) UI:SetToggleKey(key) end,
})
local uiScaleSlider = Settings:AddSlider({
	Name = "UI Scale",
	Min = 70, Max = 125, Default = 125, Suffix = "%",
	Callback = function(value) UI:SetScaleMultiplier(value / 100) end,
})
UI:SetScaleMultiplier(1.25)
local _isTouchDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
Settings:AddToggle({
	Name = "Mobile UI",
	Description = "On-screen buttons for touch players",
	Default = _isTouchDevice,
	Callback = function(on) UI:SetMobileMode(on) end,
})
if _isTouchDevice then UI:SetMobileMode(true) end
local hideButton = Settings:AddButton({
	Name = "Hide Interface",
	Description = "",
	Callback = function() UI:Hide() end,
})
UI:OnToggleKeyChanged(function(key)
	hideButton:SetDescription(key.Name .. " or the round button brings it back")
end)
Settings:AddButton({
	Name = "Destroy UI",
	Description = "Fully unload, like it never ran",
	Callback = function() UI:Destroy() end,
})

-- Number-row hotkeys cycle Curve Type (1=Custom, 2=Random, 3=Backwards, 4=Straight, 5=Up, 6=Left, 7=Right)
do
	local parryHotkeys = {
		[Enum.KeyCode.Zero] = "Custom",
		[Enum.KeyCode.One] = "Dot",
		[Enum.KeyCode.Two] = "Accelerated",
		[Enum.KeyCode.Three] = "Backwards",
		[Enum.KeyCode.Four] = "Random",
		[Enum.KeyCode.Five] = "Up",
		[Enum.KeyCode.Six] = "Left",
		[Enum.KeyCode.Seven] = "Right",
	}
	local methodHotkeys = {
		[Enum.KeyCode.Eight] = "Remote",
		[Enum.KeyCode.Nine] = "Keyboard",
	}
	table.insert(UI.Connections, UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		local pt = parryHotkeys[input.KeyCode]
		if pt then
			parryType = pt
			if curveHandle then curveHandle:Set(pt) end
			if getgenv then getgenv()._clockParryType = pt end
			return
		end
		local pm = methodHotkeys[input.KeyCode]
		if pm then
			parryMethod = pm
			if methodHandle then methodHandle:Set(pm) end
		end
	end))
end

do
	local targetState = {
		target = nil,
		spectating = false,
		forceParry = false,
		viewCam = false,
		esp = false,
		espColor = Color3.fromRGB(255, 255, 255),
		viewCamColor = Color3.fromRGB(255, 255, 255),
	}
	local hideDetachToast, hideTargetToast = false, false
	local espHighlight

	local statsPanel
	statsPanel = UI:CreateSidePanel({
		Title = "Target Stats",
		Pinned = false,
		OnPin = function(pinned)
			if not statsPanel then return end
			if pinned then
				statsPanel:Show()
			elseif UI.ActiveTab ~= Target and not statsPanel:IsDetached() then
				statsPanel:Hide()
			end
		end,
		OnDetach = function(detached)
			if detached and not hideDetachToast then
				UI:Notify("Target Stats", "Detached - drag it back to the side to re-attach.", {
					Duration = 5,
					Button = "Don't show again",
					OnButton = function() hideDetachToast = true end,
				})
			end
		end,
	})
	statsPanel._homeTab = Target

	local function clearESP()
		if espHighlight then pcall(function() espHighlight:Destroy() end) espHighlight = nil end
	end

	local function applyESP()
		clearESP()
		if not targetState.esp then return end
		local t = targetState.target
		local char = t and t.Character
		if not char then return end
		espHighlight = Instance.new("Highlight")
		espHighlight.Name = "PyraTargetESP"
		espHighlight.FillTransparency = 0.65
		espHighlight.OutlineTransparency = 0
		espHighlight.FillColor = targetState.espColor
		espHighlight.OutlineColor = targetState.espColor
		espHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		espHighlight.Adornee = char
		espHighlight.Parent = char
	end

	local function setCameraSubject(toTarget)
		local cam = Workspace.CurrentCamera
		if not cam then return end
		if toTarget and targetState.target and targetState.target.Character then
			local hum = targetState.target.Character:FindFirstChildOfClass("Humanoid")
			if hum then cam.CameraSubject = hum return end
		end
		if player.Character then
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			if hum then cam.CameraSubject = hum end
		end
	end

	local viewCamParts, viewTint = nil, nil
	local function destroyViewCamParts()
		if not viewCamParts then return end
		for _, inst in pairs(viewCamParts) do pcall(function() inst:Destroy() end) end
		viewCamParts = nil
	end
	local function stopViewCam()
		pcall(function() RunService:UnbindFromRenderStep("PyraViewCam") end)
		destroyViewCamParts()
		if viewTint then pcall(function() viewTint:Destroy() end) viewTint = nil end
	end
	local function buildViewCamParts()
		destroyViewCamParts()
		local col = targetState.viewCamColor or Color3.new(1, 1, 1)

		local screen = Instance.new("Part")
		screen.Name = "PyraViewScreen"
		screen.Size = Vector3.new(16, 9, 0.12)
		screen.Material = Enum.Material.Neon
		screen.Color = col
		screen.Transparency = 0.72
		screen.Anchored = true
		screen.CanCollide = false
		screen.CanQuery = false
		screen.CanTouch = false
		screen.CastShadow = false
		screen.Parent = Workspace

		local box = Instance.new("SelectionBox")
		box.Adornee = screen
		box.Color3 = col
		box.LineThickness = 0.045
		box.SurfaceTransparency = 1
		box.Parent = screen

		local lens = Instance.new("Part")
		lens.Name = "PyraViewLens"
		lens.Shape = Enum.PartType.Ball
		lens.Size = Vector3.new(0.9, 0.9, 0.9)
		lens.Material = Enum.Material.Neon
		lens.Color = col
		lens.Transparency = 0.25
		lens.Anchored = true
		lens.CanCollide = false
		lens.CanQuery = false
		lens.CanTouch = false
		lens.CastShadow = false
		lens.Parent = Workspace

		local tagHolder = Instance.new("BillboardGui")
		tagHolder.Name = "PyraViewTag"
		tagHolder.Size = UDim2.fromOffset(190, 22)
		tagHolder.StudsOffsetWorldSpace = Vector3.new(0, 5.4, 0)
		tagHolder.AlwaysOnTop = true
		tagHolder.Adornee = screen
		tagHolder.Parent = screen
		local tag = Instance.new("TextLabel")
		tag.Size = UDim2.fromScale(1, 1)
		tag.BackgroundTransparency = 1
		tag.Font = Enum.Font.GothamBold
		tag.TextSize = 14
		tag.TextColor3 = col
		tag.TextStrokeTransparency = 0.4
        tag.Text = "VIEW"
		tag.Parent = tagHolder

		viewCamParts = { screen = screen, lens = lens, box = box, tag = tag, holder = tagHolder }
	end
	local function setViewCamColor(c)
		if not viewCamParts then return end
		viewCamParts.screen.Color = c
		viewCamParts.lens.Color = c
		viewCamParts.box.Color3 = c
		viewCamParts.tag.TextColor3 = c
		if viewTint then viewTint.BackgroundColor3 = c end
	end
	local function startViewCam()
		stopViewCam()
		buildViewCamParts()
		viewTint = Instance.new("Frame")
		viewTint.Name = "PyraViewTint"
		viewTint.Size = UDim2.fromScale(1, 1)
		viewTint.BackgroundColor3 = targetState.viewCamColor
		viewTint.BackgroundTransparency = 0.94
		viewTint.BorderSizePixel = 0
		viewTint.ZIndex = 0
		viewTint.Parent = UI.Gui

		RunService:BindToRenderStep("PyraViewCam", Enum.RenderPriority.Camera.Value + 1, function()
			if not viewCamParts then return end
			local t = targetState.target
			local aliveFolder = Workspace:FindFirstChild("Alive")
			local model = (t and aliveFolder) and aliveFolder:FindFirstChild(t.Name) or nil
			local look = model and model:FindFirstChild("Look")
			if not (look and look.Value) then
				viewCamParts.screen.Transparency = 1
				viewCamParts.lens.Transparency = 1
				viewCamParts.box.Transparency = 1
				viewCamParts.holder.Enabled = false
				return
			end
			local camCF = look.Value
			viewCamParts.screen.Transparency = 0.72
			viewCamParts.lens.Transparency = 0.25
			viewCamParts.box.Transparency = 0
			viewCamParts.holder.Enabled = true
			viewCamParts.tag.Text = t.DisplayName .. "  |  VIEW"
			viewCamParts.lens.CFrame = camCF
			viewCamParts.screen.CFrame = camCF * CFrame.new(0, 0, -6)
		end)
	end

	local function setTarget(p)
		targetState.target = p
		forcedTargetPlayer = p
		if p then
			statsPanel:SetAvatar(p.UserId)
			if not hideTargetToast then
				UI:Notify("Target Selected", p.DisplayName, {
					Duration = 3,
					Button = "Don't show again",
					OnButton = function() hideTargetToast = true end,
				})
			end
		end
		applyESP()
		if targetState.spectating then setCameraSubject(true) end
	end

	Target:AddSection("Target")
	Target:AddPlayerSearch({
		Placeholder = "Search a player...",
		Callback = function(p) setTarget(p) end,
	})

	Target:AddSection("Actions")
	Target:AddToggle({
		Name = "Force Target Parry",
		Description = "Prefer this player when parrying",
		Default = false,
		Icon = Library.Icons.Sword,
		IconSelected = Library.Icons.Sword_Selected,
		IconToggle = true,
		Callback = function(on)
			targetState.forceParry = on
			forceTargetParry = on
			if on and not targetState.target then
				UI:Notify("Force Target Parry", "Pick a player in the Target tab first.", 4)
			end
		end,
	})
	Target:AddToggle({
		Name = "Spectate",
		Description = "Watch the target instead of yourself",
		Default = false,
		Icon = Library.Icons.Spectate,
		IconSelected = Library.Icons.Spectate_Selected,
		IconToggle = true,
		Callback = function(on)
			targetState.spectating = on
			setCameraSubject(on)
		end,
	})
	local viewCamGroup = Target:AddGroup({ Collapsible = true, DefaultExpanded = false })
	viewCamGroup:AddToggle({
		Name = "View Camera",
		Description = "Match the target's look direction",
		Default = false,
		Icon = Library.Icons.Spectate,
		IconSelected = Library.Icons.Spectate_Selected,
		IconToggle = true,
		Callback = function(on)
			targetState.viewCam = on
			viewCamGroup:SetExpanded(on)
			if on then startViewCam() else stopViewCam() end
		end,
	})
	viewCamGroup.Body:AddColorPicker({
		Name = "View Cam Color",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(c)
			targetState.viewCamColor = c
			setViewCamColor(c)
		end,
	})

	Target:AddSection("Options")
	local espGroup = Target:AddGroup({ Collapsible = true, DefaultExpanded = false })
	espGroup:AddToggle({
		Name = "ESP Highlight",
		Description = "Outline the target through walls",
		Default = false,
		Icon = Library.Icons.Spectate,
		IconSelected = Library.Icons.Spectate_Selected,
		IconToggle = true,
		Callback = function(on)
			targetState.esp = on
			espGroup:SetExpanded(on)
			applyESP()
		end,
	})
	espGroup.Body:AddColorPicker({
		Name = "ESP Color",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(c)
			targetState.espColor = c
			if espHighlight then
				espHighlight.FillColor = c
				espHighlight.OutlineColor = c
			end
		end,
	})

	UI:OnTabChanged(function(tab)
		if statsPanel:IsDetached() then return end
		if tab == Target then
			statsPanel:Show()
		elseif not statsPanel:IsPinned() then
			statsPanel:Hide()
		end
	end)

	local STAT_KEYS = {
		"Username", "ELO", "Device", "Account Age", "RAP",
		"Sword", "Wins", "Elims", "Ability", "Alive", "Targeted", "Pulsed",
	}
	local GOOD = Color3.fromRGB(90, 220, 130)
	local BAD  = Color3.fromRGB(235, 90, 90)

	local function isTargeted(t)
		local ballsFolder = Workspace:FindFirstChild("Balls")
		if not ballsFolder then return false end
		for _, b in ipairs(ballsFolder:GetChildren()) do
			if b:GetAttribute("realBall") and b:GetAttribute("target") == t.Name then return true end
		end
		return false
	end
	local function isPulsed(t)
		local aliveFolder = Workspace:FindFirstChild("Alive")
		local model = aliveFolder and aliveFolder:FindFirstChild(t.Name)
		local p = model and model:FindFirstChild("PULSED")
		if p and p.Value then return true end
		local char = t.Character
        if char and char:GetAttribute("Pulsed") then return true end
		return false
	end

	task.spawn(function()
		local lastChar
		while not UI.Destroyed do
			local t = targetState.target
			if t and t.Parent then
				if targetState.esp and t.Character ~= lastChar then
					lastChar = t.Character
					applyESP()
				end
				statsPanel:SetTitle(t.DisplayName)
				statsPanel:SetStat("Username", "@" .. t.Name)
				statsPanel:SetStat("ELO", tostring(t:GetAttribute("ELO") or "N/A"))
				statsPanel:SetStat("Device", tostring(t:GetAttribute("Device") or "N/A"))
				statsPanel:SetStat("Account Age", t.AccountAge .. " days")
				statsPanel:SetStat("RAP", tostring(t:GetAttribute("TotalRAP") or "N/A"))
				statsPanel:SetStat("Sword", tostring(t:GetAttribute("CurrentlyEquippedSword") or "N/A"))
				statsPanel:SetStat("Wins", tostring(t:GetAttribute("PlayerWins") or "N/A"))
				statsPanel:SetStat("Elims", tostring(t:GetAttribute("PlayerElims") or "N/A"))
				statsPanel:SetStat("Ability", tostring(t:GetAttribute("EquippedAbility") or "None"))

				local alive = t.Team ~= nil and t.Team.Name == "Playing"
				statsPanel:SetStat("Alive", alive and "Yes" or "No", alive and GOOD or BAD)
				local tg = isTargeted(t)
				statsPanel:SetStat("Targeted", tg and "Yes" or "No", tg and GOOD or BAD)
				local pl = isPulsed(t)
				statsPanel:SetStat("Pulsed", pl and "Yes" or "No", pl and GOOD or BAD)
			else
				if lastChar then lastChar = nil clearESP() end
				statsPanel:ClearAvatar()
				statsPanel:SetTitle("No Target")
				for _, k in ipairs(STAT_KEYS) do statsPanel:SetStat(k, "-") end
			end
			task.wait(0.5)
		end
	end)

	UI.TargetState = targetState
	UI:OnDestroy(function()
		clearESP()
		pcall(stopViewCam)
		pcall(setCameraSubject, false)
	end)
end

local function unloadClock()
	autoParryEnabled = false
	pcall(function() AP_setActive(false) end)
	pcall(AP_stop)
	spamDetectionEnabled = false
	manualSpamEnabled = false
	spamming = false
	if _mobileSpamGui then pcall(function() _mobileSpamGui:Destroy() end); _mobileSpamGui = nil end
	pcall(stopAdvancedBallMonitor)
	pcall(stopAbilityESP); pcall(stopNoRender); pcall(stopVisualizer)
	if fullbrightEnabled or fulldarkEnabled then pcall(setNormalLighting) end
	pcall(function()
		local c = Workspace.CurrentCamera
		if c then c.FieldOfView = 70; if c.CameraType == Enum.CameraType.Scriptable then c.CameraType = Enum.CameraType.Custom end end
	end)
	for _, c in ipairs(_clockConns) do pcall(function() c:Disconnect() end) end
	table.clear(_clockConns)
	if ballTrailHueConn then pcall(function() ballTrailHueConn:Disconnect() end); ballTrailHueConn = nil end
	pcall(function()
		for _, ball in ipairs(ballsNow()) do
			for _, n in ipairs({ "Trail", "BallGlow", "ParticleEmitter", "Attachment0", "Attachment1" }) do
				local inst = ball:FindFirstChild(n); if inst then pcall(function() inst:Destroy() end) end
			end
		end
	end)
	if visualPart then pcall(function() visualPart:Destroy() end); visualPart = nil end
	pcall(function() ViewCamPart.Transparency = 1 end)
	local Lighting = game:GetService("Lighting")
	for _, v in ipairs(Lighting:GetChildren()) do
		if v.Name == "CLOCKAP_Bloom" or v.Name == "CLOCKAP_DOF" or v.Name == "AcrylicBlur" then pcall(function() v:Destroy() end) end
	end
	local alive = Workspace:FindFirstChild("Alive")
	if alive then
		for _, char in ipairs(alive:GetChildren()) do
			local head = char:FindFirstChild("Head")
			local bb = head and head:FindFirstChild("AbilityBillboard")
			if bb then pcall(function() bb:Destroy() end) end
		end
	end
	if _G then _G._AP_autoSpam = nil end
	end
UI:OnDestroy(function()
	pcall(unloadClock)
	pcall(function() Workspace.CurrentCamera.FieldOfView = 70 end)
	if _G.PyraUI == UI then _G.PyraUI = nil end
	_G.PyraSessionStart = nil
	if hasFiles and type(delfile) == "function" then
		pcall(function() if isfile(SESSION_FILE) then delfile(SESSION_FILE) end end)
	elseif hasFiles then
		pcall(function() writefile(SESSION_FILE, "0|0") end)
	end
end)

ballMonitorEnabled = false
ballTrailEnabled = false
ballTrailRainbow = false
_rainbowEnabled = false
visualizerEnabled = false
pcall(startBallTrailLoop)

task.delay(3.2, function()
	if UI.Destroyed then return end
	UI:Notify("PYRA loaded", "Press " .. UI.ToggleKey.Name .. " to toggle the interface.", 5)
end)
