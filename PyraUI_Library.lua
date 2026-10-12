--dont add comments (never delete this line)
local _hiddenUI = (gethui and gethui()) or (get_hidden_gui and get_hidden_gui())
local _protectGui = protect_gui
	or (syn and syn.protect_gui)
	or (protectgui)
	or function(gui)
		if _hiddenUI then gui.Parent = _hiddenUI end
	end

if type(_G.PyraUnload) == "function" then
	pcall(_G.PyraUnload)
	_G.PyraUnload = nil
end

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local PYRA_LIB_URL = "https://raw.githubusercontent.com/SwipeCard/PyraUI/main/PyraUI_Library.lua"
local Library = loadstring(game:HttpGet(PYRA_LIB_URL .. "?t=" .. os.time()))()

local UI = Library.new({
	Title = "PYRA",
	Status = "Inactive",
	StatusLabel = "PARRY STATUS",
	StatusColor = Color3.fromRGB(220, 70, 70),
	Expiry = "12/21/2069",
	ToggleKey = Enum.KeyCode.RightShift,
	SkipIntro = true,
})
if UI.Gui then _protectGui(UI.Gui) end
_G.PyraUI = UI

local _tabs = {}
_tabs.Combat = UI:AddTab("Combat")
_tabs.Extra = UI:AddTab("Extra")
_tabs.Target = UI:AddTab("Target")
_tabs.Settings = UI:AddTab("Settings")

local introGui = nil

_G.PyraUnload = function()
	if introGui then
		pcall(introGui.Destroy, introGui)
		introGui = nil
	end
	pcall(function() if UI and not UI.Destroyed then UI:Destroy() end end)
end

UI:OnDestroy(function()
	if introGui then
		pcall(introGui.Destroy, introGui)
		introGui = nil
	end
	if _G.PyraUI == UI then _G.PyraUI = nil end
	if _G.PyraUnload then _G.PyraUnload = nil end
end)


-- ===== COMBAT =====
do
if not (Library.Features and Library.Features.NoSwitch) then
	task.delay(1, function()
		UI:Notify("Outdated library", "Re-upload PyraUI_Library to GitHub to remove the triggerbot switch.", 10)
	end)
end

local refreshStatus = function() end

local spamDetectionEnabled = false
local spamDistanceSetting = 1
local SPAM_STAGES = {
	[0] = { parries = 2, range = 0.8 },
	[1] = { parries = 2, range = 1.0 },
	[2] = { parries = 2, range = 1.2 },
	[3] = { parries = 1, range = 1.4 },
	[4] = { parries = 1, range = 1.6 },
	[5] = { parries = 1, range = 1.7 },
}
local SPAM_AWAY_RATE = 4
local SPAM_AWAY_TIME = 0.12
local SPAM_AWAY_BLOCK = 0.5
local manualSpamEnabled = true
local manualSpamBind = Enum.KeyCode.E
local manualSpamHold = false
local tbEnabled = true
local tbToggle, manualToggle
local tbBind = Enum.KeyCode.T
local tbHold = false
local tbActive = false
local spamming = false
local manualKeyOwned = false
local _mobileSpamGui = nil

local parryType = "Camera"
local parryAccuracy = 50
local randomAccuracy = false
local parryAnimationEnabled = false
local PARRY_ANIM_SPEED = 1
local accuracyRangeMin = 0
local accuracyRangeMax = 100
local forceTargetParry = false
local forcedTargetPlayer = nil

local IB_NO_VIRTUALIZE = IB_NO_VIRTUALIZE or function(f) return f end

local function createParrySender()
	local playerData = require(ReplicatedStorage.Packages.Replion).Client:WaitReplion("Data")
	local serverInfo = require(ReplicatedStorage.ServerInfo)
	local universeIds = require(ReplicatedStorage.Shared.UniverseIds)
	local noobParry = not serverInfo.isDungeonsMatchServer()
		and game.PlaceId ~= universeIds.RankedMatches.PlaceId
		and game.PlaceId ~= universeIds.RankedMatchesNoAbility.PlaceId
		and not serverInfo.isMedalServer()
		and not serverInfo.isClanWarServer()
		and not serverInfo.isTournamentMatchServer()
		and require(ReplicatedStorage.Common.Utils).FFlag.GetInstantFFlag("NoobParryEnabled", true)
	local parryFunction = require(ReplicatedStorage.Controllers["SwordsController \012"].PRY)
	local encoder = debug.getupvalue(parryFunction, 4)
	local hash = debug.getupvalue(parryFunction, 8)
	local remote, key, timeKey
	local timeHash = {}
	local durations = {1.5, 1.25, 1, 0.75, 0.625}
	local signal = require(ReplicatedStorage.Packages.Signal).new()
	signal:Connect(parryFunction)

	local function capture(event, eventHash, eventKey, proof, duration, direction, targets, aim, flag)
		if eventHash == hash and type(eventKey) == "string" and type(proof) == "string"
			and type(duration) == "number" and typeof(direction) == "CFrame"
			and type(targets) == "table" and type(aim) == "table" and type(flag) == "boolean" then
			remote, key = event, eventKey
		end
	end
	local fireServer
	fireServer = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(IB_NO_VIRTUALIZE(function(event, ...)
		if not remote and not checkcaller() then
			capture(event, ...)
		end
		return fireServer(event, ...)
	end)))

	return function(direction, targets, aim)
		local duration = durations[(playerData:Get("timesParried") or 0) + 1] or 0.5
		if noobParry then
			local kills = playerData:Get("TotalStats.Kills") or 0
			duration = kills < 20 and duration * kills / 20 or duration
		end
		if not key then
			signal:Fire(duration, direction, targets, aim, false)
			return true
		end
		timeKey = timeKey or encoder(key, "TIME")
		local stamp = tostring(math.floor(workspace:GetServerTimeNow() * 100))
		table.clear(timeHash)
		for index = 1, #stamp do
			timeHash[index] = string.char(bit32.bxor(
				(string.byte(stamp, index) + index) % 256,
				string.byte(timeKey, (index - 1) % #timeKey + 1)
			))
		end
		fireServer(remote, hash, key, table.concat(timeHash), duration, direction, targets, aim, false)
		return true
	end
end

local sendParry = nil
task.spawn(function()
	local env = getgenv and getgenv() or nil
	if env and env._PyraSender and env._PyraSenderJob == game.JobId then
		sendParry = env._PyraSender
		UI.ParryReady = true
		return
	end
	local ok, result = pcall(createParrySender)
	if ok and type(result) == "function" then
		sendParry = result
		UI.ParryReady = true
		refreshStatus()
		if env then
			env._PyraSender = result
			env._PyraSenderJob = game.JobId
		end
	else
		UI:Notify("Parry", "Parry sender failed to start: " .. tostring(result), 8)
	end
end)

local autoParryActive = false
local tb = { busy = false }
local lastParryEvent = 0
local autoParry = { debounce = false, untilAt = 0, rolled = nil, conn = nil }
local ballState = { AerodynamicTime = tick(), LastWarping = tick(), LerpRadians = 0, Curving = tick() }
local function resetAutoParry()
	autoParry.debounce = false
	autoParry.untilAt = 0
	autoParry.rolled = nil
end

refreshStatus = function()
	local on = sendParry ~= nil
	UI:SetStatus(on and "Active" or "Inactive", on and Color3.fromRGB(90, 220, 130) or Color3.fromRGB(220, 70, 70))
end

local _pyraConns = {}
local function trackConn(conn)
	_pyraConns[#_pyraConns + 1] = conn
	return conn
end

local _ballCache = {}
local _ballCacheConns = {}
local _ballRemovedHandlers = {}
local function onBallRemoved(fn) _ballRemovedHandlers[#_ballRemovedHandlers + 1] = fn end

local function _rebuildList(entry)
    local list, n = {}, 0
    for ball in pairs(entry.set) do
        if ball.Parent then
            n = n + 1; list[n] = ball
        else
            entry.set[ball] = nil
            if entry.attrConns[ball] then entry.attrConns[ball]:Disconnect(); entry.attrConns[ball] = nil end
        end
    end
    entry.list = list; entry.dirty = false
end

local function _attachBall(entry, ball)
    if not ball:IsA("BasePart") then return end
    if entry.attrConns[ball] then return end
    if ball:GetAttribute("realBall") then entry.set[ball] = true; entry.dirty = true end
    entry.attrConns[ball] = ball:GetAttributeChangedSignal("realBall"):Connect(function()
        if ball:GetAttribute("realBall") then
            if not entry.set[ball] then entry.set[ball] = true; entry.dirty = true end
        else
            if entry.set[ball] then entry.set[ball] = nil; entry.dirty = true end
        end
    end)
end

local function _detachBall(entry, ball)
    if entry.set[ball] then entry.set[ball] = nil; entry.dirty = true end
    local c = entry.attrConns[ball]
    if c then c:Disconnect(); entry.attrConns[ball] = nil end
    for i = 1, #_ballRemovedHandlers do _ballRemovedHandlers[i](ball) end
end

local function _bindFolder(folder)
    if _ballCache[folder] then return _ballCache[folder] end
    local entry = { set = {}, list = {}, dirty = false, attrConns = {} }
    _ballCache[folder] = entry
    _ballCacheConns[folder] = {
        trackConn(folder.ChildAdded:Connect(function(ch) _attachBall(entry, ch) end)),
        trackConn(folder.ChildRemoved:Connect(function(ch) _detachBall(entry, ch) end)),
    }
    for _, ch in ipairs(folder:GetChildren()) do _attachBall(entry, ch) end
    _rebuildList(entry)
    return entry
end

local function realBallsIn(folder)
    if not folder then return nil end
    local entry = _ballCache[folder] or _bindFolder(folder)
    if entry.dirty then _rebuildList(entry) end
    return entry.list
end

local _folderCache, _folderAt = nil, 0
local function activeBallFolder()
    local now = os.clock()
    if _folderCache and _folderCache.Parent and now - _folderAt < 0.25 then
        return _folderCache
    end
    local ws = game:GetService("Workspace")
    local dead = ws:FindFirstChild("Dead")
    local me = game:GetService("Players").LocalPlayer
    local folder
    if dead and me and dead:FindFirstChild(me.Name) then
        folder = ws:FindFirstChild("TrainingBalls")
    else
        folder = ws:FindFirstChild("Balls")
    end
    _folderCache, _folderAt = folder, now
    return folder
end

local _zoomCache = setmetatable({}, { __mode = "k" })
local function getZoomies(ball)
    local z = _zoomCache[ball]
    if z and z.Parent == ball then return z end
    z = ball:FindFirstChild("zoomies")
    _zoomCache[ball] = z
    return z
end

local runtimeState = { tornado = nil }
task.spawn(function()
    local runtime = Workspace:FindFirstChild("Runtime") or Workspace:WaitForChild("Runtime", 10)
    if not runtime then return end
    runtimeState.tornado = runtime:FindFirstChild("Tornado")
    trackConn(runtime.ChildAdded:Connect(function(ch)
        if ch.Name == "Tornado" then runtimeState.tornado = ch end
    end))
    trackConn(runtime.ChildRemoved:Connect(function(ch)
        if ch == runtimeState.tornado then runtimeState.tornado = nil end
    end))
end)

local function firstRealBall()
    local list = realBallsIn(activeBallFolder())
    return list and list[1] or nil
end

task.spawn(function()
    local ws = game:GetService("Workspace")
    local b = ws:FindFirstChild("Balls") or ws:WaitForChild("Balls", 10)
    if b then _bindFolder(b) end
    local tb = ws:FindFirstChild("TrainingBalls")
    if tb then _bindFolder(tb) end
    trackConn(ws.ChildAdded:Connect(function(ch)
        if ch.Name == "Balls" or ch.Name == "TrainingBalls" then _bindFolder(ch) end
    end))
end)


local anim = {
    active = nil,
    cache = {},
    tracks = {},
    api = nil,
    next_at = 0,
}

pcall(function()
    anim.api = require(ReplicatedStorage.Shared.SwordAPI)
end)

trackConn(LocalPlayer.CharacterAdded:Connect(function()
    table.clear(anim.tracks)
    anim.active = nil
    anim.next_at = 0
    task.delay(2, function() pcall(anim.warm) end)
end))
task.delay(1, function() pcall(anim.warm) end)

function anim.find(folder)
    local found = folder:FindFirstChild("GrabParry") or folder:FindFirstChild("Parry") or folder:FindFirstChild("Grab")
    if found then
        return found
    end
    local base = folder:FindFirstChild("Base")
    if base then
        return base:FindFirstChild("GrabParry") or base:FindFirstChild("Parry") or base:FindFirstChild("Grab")
    end
    return nil
end

function anim.resolve(character, sword_name)
    if not sword_name then
        return nil
    end
    local cached = anim.cache[sword_name]
    if cached then
        return cached
    end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if not shared then
        return nil
    end
    local replicated_instances = shared:FindFirstChild("ReplicatedInstances")
    local swords = replicated_instances and replicated_instances:FindFirstChild("Swords")
    local get_sword = swords and swords:FindFirstChild("GetSword")
    local sword_data
    if get_sword then
        pcall(function()
            sword_data = get_sword:Invoke(sword_name)
        end)
    end
    local anim_type = (sword_data and sword_data.AnimationType) or "Single"
    local sword_type = (sword_data and sword_data.SwordType) or "Single"
    if anim.api and type(anim.api.GetAnimations) == "function" then
        local ok, anims = pcall(function()
            return anim.api:GetAnimations(character, { "Parry", "GrabParry" }, anim_type, sword_type)
        end)
        if ok and type(anims) == "table" and anims[1] then
            anim.cache[sword_name] = anims[1]
            return anims[1]
        end
    end
    local sword_folder = shared:FindFirstChild("SwordAPI")
    local collection = sword_folder and (sword_folder:FindFirstChild("Collection") or sword_folder)
    if collection then
        local type_folder = collection:FindFirstChild(anim_type)
        if type_folder then
            local found = anim.find(type_folder)
            if found then
                anim.cache[sword_name] = found
                return found
            end
        end
        local default_folder = collection:FindFirstChild("Default")
        if default_folder then
            local found = anim.find(default_folder)
            if found then
                anim.cache[sword_name] = found
                return found
            end
        end
    end
    return nil
end

function anim.load(animator, parry_anim)
    local animator_tracks = anim.tracks[animator]
    if not animator_tracks then
        animator_tracks = {}
        anim.tracks[animator] = animator_tracks
    end
    local track = animator_tracks[parry_anim]
    if track then
        return track
    end
    local ok, new_track = pcall(function()
        return animator:LoadAnimation(parry_anim)
    end)
    if not ok or not new_track then
        return nil
    end
    for attribute, value in pairs(parry_anim:GetAttributes()) do
        new_track:SetAttribute(attribute, value)
    end
    new_track:SetAttribute("GrabParry", true)
    new_track.Priority = Enum.AnimationPriority.Action4
    animator_tracks[parry_anim] = new_track
    return new_track
end

function anim.warm()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        return
    end
    local sword_name = character:GetAttribute("CurrentlyEquippedSword") or "Base Sword"
    local parry_anim = anim.resolve(character, sword_name)
    if parry_anim then
        anim.load(animator, parry_anim)
    end
end

function anim.grab(is_spam)
    if os.clock() < anim.next_at then
        local playing_now = false
        if anim.active then
            pcall(function() playing_now = anim.active.IsPlaying end)
        end
        if playing_now then
            return true
        end
    end
    local character = LocalPlayer.Character
    if not character then
        return false
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not humanoid or not animator then
        return false
    end
    local sword_name = character:GetAttribute("CurrentlyEquippedSword") or "Base Sword"
    local parry_anim = anim.resolve(character, sword_name)
    if not parry_anim then
        return false
    end
    local track = anim.load(animator, parry_anim)
    if not track then
        anim.cache[sword_name] = nil
        return false
    end
    for _, playing in ipairs(animator:GetPlayingAnimationTracks()) do
        if playing:GetAttribute("GrabParry") or playing:GetAttribute("Parry") or playing:GetAttribute("SuccessParry") then
            pcall(playing.Stop, playing, playing:GetAttribute("StopFadeTime") or 0.05)
        end
    end
    local play_fade = parry_anim:GetAttribute("PlayFadeTime") or 0.05
    local play_weight = parry_anim:GetAttribute("PlayWeight") or 1
    local play_speed = (parry_anim:GetAttribute("PlaySpeed") or 1) * PARRY_ANIM_SPEED
    track.TimePosition = 0
    track:Play(play_fade, play_weight, play_speed)
    anim.active = track
    local track_length = track.Length
    if not track_length or track_length <= 0 then track_length = 0.66 end
    anim.next_at = os.clock() + track_length / math.max(play_speed, 0.1)
    character:SetAttribute("ParryTime", math.max(character:GetAttribute("ParryTime") or 0, track.Length ~= 0 and (track.Length - track.TimePosition) * play_speed or 1))
    return true
end

task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    local parrySuccess = remotes and remotes:WaitForChild("ParrySuccess", 10)
    if not parrySuccess then return end
    trackConn(parrySuccess.OnClientEvent:Connect(function()
        lastParryEvent = os.clock()
        if not (autoParryActive or spamming or spamDetectionEnabled or tbActive) then
            return
        end
        if not parryAnimationEnabled then return end
        local character = LocalPlayer.Character
        if not character or not character:IsDescendantOf(Workspace) then
            return
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            return
        end
        for _, playing in ipairs(animator:GetPlayingAnimationTracks()) do
            if playing ~= anim.active and (playing:GetAttribute("GrabParry") or playing:GetAttribute("Parry")) then
                playing:Stop(playing:GetAttribute("StopFadeTime"))
            end
        end
    end))
end)

local function playParryAnimation(isSpam)
    if not parryAnimationEnabled then return end
    anim.grab(isSpam == true)
end

local function flatUnit(v, fallback)
    v = Vector3.new(v.X, 0, v.Z)
    if v.Magnitude < 0.01 then return fallback end
    return v.Unit
end

local TARGET_AIM_CURVES = { Dot = true, Backwards = true, Accelerate = true, Camera = true }
local function getCurveCFrame(camera, target)
    local camCF = camera.CFrame
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return camCF end
    local rootPos = root.Position
    local camPos = camCF.Position
    local targetPos = (target and target.PrimaryPart and target.PrimaryPart.Position)
        or (rootPos + camCF.LookVector * 1000)
    local method = parryType
    if method == "Dot" then
        return CFrame.lookAt(rootPos, targetPos + Vector3.new(0, 1.75, 0))
    elseif method == "Backwards" then
        local direction = (targetPos - rootPos).Unit
        return CFrame.new(rootPos, rootPos + (-direction) * 1000)
    elseif method == "Random" then
        local a = math.random() * math.pi * 2
        local y = (math.random() * 2 - 1) * 0.6
        local dir = Vector3.new(math.cos(a), y, math.sin(a)).Unit
        return CFrame.new(rootPos, rootPos + dir * 100)
    elseif method == "Accelerate" then
        local toTarget = flatUnit(targetPos - rootPos, Vector3.new(0, 0, 1))
        return CFrame.new(rootPos, rootPos + (toTarget + Vector3.new(0, 0.5, 0)).Unit * 100)
    elseif method == "Up" then
        return CFrame.new(camPos, camPos + camCF.UpVector * 10000)
    elseif method == "Slow" then
        return CFrame.new(rootPos, rootPos + Vector3.new(0, -350, 0))
    elseif method == "Left" then
        return CFrame.new(camPos, camPos - camCF.RightVector * 10000)
    elseif method == "Right" then
        return CFrame.new(camPos, camPos + camCF.RightVector * 10000)
    end
    return camCF
end

local parryTimes, parryHead, parryTail = {}, 1, 0
local function recordParry()
    parryTail = parryTail + 1
    parryTimes[parryTail] = os.clock()
end
local function recentParries()
    local cutoff = os.clock() - 0.5
    while parryHead <= parryTail and parryTimes[parryHead] < cutoff do
        parryTimes[parryHead] = nil
        parryHead = parryHead + 1
    end
    return parryTail - parryHead + 1
end
local function clearParries()
    table.clear(parryTimes)
    parryHead, parryTail = 1, 0
end

local function syncForcedTarget()
    local ts = UI.TargetState
    forceTargetParry = ts ~= nil and ts.forceParry == true
    forcedTargetPlayer = ts and ts.target or nil
end

local aliveCache = { folder = nil, list = {}, dirty = true }
local aliveEmpty = {}
local aliveBound = setmetatable({}, { __mode = "k" })
local function bindAliveFolder(folder)
	if aliveBound[folder] then return end
	aliveBound[folder] = true
	aliveCache.folder = folder
	aliveCache.dirty = true
	trackConn(folder.ChildAdded:Connect(function() aliveCache.dirty = true end))
	trackConn(folder.ChildRemoved:Connect(function() aliveCache.dirty = true end))
end
local function aliveList()
	local folder = aliveCache.folder
	if not folder or not folder.Parent then
		folder = Workspace:FindFirstChild("Alive")
		if not folder then return aliveEmpty end
		bindAliveFolder(folder)
	end
	if aliveCache.dirty then
		aliveCache.list = folder:GetChildren()
		aliveCache.dirty = false
	end
	return aliveCache.list
end

local function pickSpamTarget()
	syncForcedTarget()
	local list = aliveList()
	if forceTargetParry and forcedTargetPlayer then
		local forcedName = forcedTargetPlayer.Name
		for i = 1, #list do
			local ch = list[i]
			if ch.Name == forcedName and ch.PrimaryPart then return ch end
		end
	end
	local cam = Workspace.CurrentCamera
	local camPos, look, ray
	if cam then
		local camCF = cam.CFrame
		camPos, look = camCF.Position, camCF.LookVector
		if UserInputService.MouseEnabled then
			local m = UserInputService:GetMouseLocation()
			ray = cam:ScreenPointToRay(m.X, m.Y).Direction
		else
			local vp = cam.ViewportSize
			ray = cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5).Direction
		end
	end
	local myName = LocalPlayer.Name
	local first, best, bestDot = nil, nil, -math.huge
	for i = 1, #list do
		local ch = list[i]
		local pp = ch.PrimaryPart
		if pp and ch.Name ~= myName then
			first = first or ch
			if ray then
				local to = pp.Position - camPos
				local mag = to.Magnitude
				if mag > 0 then
					local dir = to / mag
					if look:Dot(dir) > 0 then
						local d = ray:Dot(dir)
						if d > bestDot then
							bestDot = d
							best = ch
						end
					end
				end
			end
		end
	end
	return best or first
end

local _spamTargetCache, _spamTargetAt = nil, 0
local function pickSpamTargetCached()
	local now = os.clock()
	local cached = _spamTargetCache
	if cached and cached.Parent and cached.PrimaryPart and now - _spamTargetAt < 0.1 then
		return cached
	end
	_spamTargetCache = pickSpamTarget()
	_spamTargetAt = now
	return _spamTargetCache
end

local function buildTargets(camera, into)
	table.clear(into)
	local list = aliveList()
	for i = 1, #list do
		local entity = list[i]
		local primary = entity.PrimaryPart
		if primary then
			local pt = camera:WorldToScreenPoint(primary.Position)
			if pt.Z > 0 then into[entity.Name] = pt end
		end
	end
	return into
end


local function neutralAim(camera)
    if UserInputService.MouseEnabled then
        local mouse = UserInputService:GetMouseLocation()
        return { mouse.X, mouse.Y }
    end
    local size = camera.ViewportSize
    return { size.X * 0.5, size.Y * 0.5 }
end

local function parryAim(camera, target)
    local part = target and target.PrimaryPart
    if part and TARGET_AIM_CURVES[parryType] then
        local vp = camera:WorldToViewportPoint(part.Position)
        return { vp.X, vp.Y }
    end
    return neutralAim(camera)
end

local oneShotTargets = {}
local function _fireParry()
    if not sendParry then return false end
    local camera = Workspace.CurrentCamera
    if not LocalPlayer.Character or not camera then return false end
    local target = pickSpamTarget()
    local direction = getCurveCFrame(camera, target)
    local targets = buildTargets(camera, oneShotTargets)
    local aim = parryAim(camera, target)
    local ok = pcall(sendParry, direction, targets, aim)
    if ok and spamDetectionEnabled then recordParry() end
    return ok
end

local SPAM_DOWN = Vector3.new(0, -350, 0)
local spamPack = { targets = {}, aim = { 0, 0 }, at = -1, dir = nil, dirAt = -1 }
local function _fireSpamParry()
    if not sendParry then return false end
    local character = LocalPlayer.Character
    local root = character and character.PrimaryPart
    if not root then return false end
    local now = os.clock()
    if now - spamPack.at >= 0.25 then
        local camera = Workspace.CurrentCamera
        if camera then
            buildTargets(camera, spamPack.targets)
            spamPack.aim = parryAim(camera)
        end
        spamPack.at = now
    end
    if not spamPack.dir or now - spamPack.dirAt >= 0.004 then
        local pos = root.Position
        spamPack.dir = CFrame.new(pos, pos + SPAM_DOWN)
        spamPack.dirAt = now
    end
    local ok = pcall(sendParry, spamPack.dir, spamPack.targets, spamPack.aim)
    if ok and spamDetectionEnabled then recordParry() end
    return ok
end

local dataPing
pcall(function() dataPing = game:GetService("Stats").Network.ServerStatsItem["Data Ping"] end)
local function getDataPingRaw()
	if dataPing then
		local ok, v = pcall(dataPing.GetValue, dataPing)
		if ok and type(v) == "number" then return v end
	end
	return (LocalPlayer:GetNetworkPing() or 0) * 1000
end
local _pingAt, _pingVal = 0, 0
local function getDataPing()
	local now = os.clock()
	if now - _pingAt >= 0.05 then
		_pingVal = getDataPingRaw()
		_pingAt = now
	end
	return _pingVal
end

local ballPositions = setmetatable({}, { __mode = "k" })
task.spawn(function()
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	local index = packages and packages:FindFirstChild("_Index")
	local netPkg = index and index:FindFirstChild("sleitnick_net@0.1.0")
	local net = netPkg and netPkg:FindFirstChild("net")
	if not net then return end
	for _, inst in ipairs(net:GetChildren()) do
		if inst:IsA("UnreliableRemoteEvent") and inst.Name ~= "URE/ReplicateBallPosition" then
			trackConn(inst.OnClientEvent:Connect(function(b, pos)
				if typeof(b) == "Instance" and b:GetAttribute("realBall") == true then
					ballPositions[b] = pos
				end
			end))
			break
		end
	end
end)
local function ballPos(b)
	return ballPositions[b] or b.Position
end

task.spawn(function()
	local ballsFolder = Workspace:FindFirstChild("Balls") or Workspace:WaitForChild("Balls", 10)
	if not ballsFolder then return end
	trackConn(ballsFolder.ChildRemoved:Connect(function(b)
		ballPositions[b] = nil
		clearParries()
		resetAutoParry()
	end))
	trackConn(ballsFolder.ChildAdded:Connect(resetAutoParry))
end)


local function spamStage()
	return SPAM_STAGES[spamDistanceSetting] or SPAM_STAGES[2]
end
local function spamParriesNeeded()
	return spamStage().parries
end
local function spamRange(ballInst, root, ping)
	local zoomies = getZoomies(ballInst)
	local velocity = zoomies and zoomies.VectorVelocity or ballInst.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local toBall = root.Position - ballPos(ballInst)
	local alignment = 0
	if toBall.Magnitude > 0 and speed > 0 then
		alignment = toBall.Unit:Dot(velocity.Unit)
	end
	local rangeScale = spamStage().range
	local maxDistance = (ping + math.min(speed / 6, 95)) * rangeScale
	return maxDistance - math.clamp(alignment, -1, 0) * (5 - math.min(speed / 5, 5))
end

local spamLast = 0
local spamBlockUntil = 0
local spamPrevDist = nil
local spamDistClock = 0
local spamAwayRate = 0
local spamAwayFor = 0
local function autoSpamCheck()
	if spamming then return end
	local now = os.clock()
	if now < spamBlockUntil then return end
	local ballInst = firstRealBall()
	if not ballInst or not getZoomies(ballInst) then return end
	local current = pickSpamTargetCached()
	if not current or not current.PrimaryPart then return end
	local character = LocalPlayer.Character
	local root = character and character.PrimaryPart
	if not root then return end
	local ping = math.clamp(getDataPing() / 10, 1, 16)
	local range = spamRange(ballInst, root, ping)
	local ballDistance = (root.Position - ballPos(ballInst)).Magnitude
	local targetName = ballInst:GetAttribute("target")
	if not targetName then return end
	local targetDistance = (current.PrimaryPart.Position - root.Position).Magnitude
	local sampleDt = now - spamDistClock
	spamDistClock = now
	if spamPrevDist and sampleDt > 0 and sampleDt < 0.25 then
		local rate = (targetDistance - spamPrevDist) / sampleDt
		spamAwayRate = spamAwayRate + (rate - spamAwayRate) * 0.5
		if spamAwayRate > SPAM_AWAY_RATE then
			spamAwayFor = spamAwayFor + sampleDt
		else
			spamAwayFor = 0
		end
	else
		spamAwayRate = 0
		spamAwayFor = 0
	end
	spamPrevDist = targetDistance
	if spamAwayFor >= SPAM_AWAY_TIME and now - spamLast < 0.25 then
		spamAwayFor = 0
		spamBlockUntil = now + SPAM_AWAY_BLOCK
		return
	end
	if targetDistance > range or ballDistance > range then return end
	if character:GetAttribute("Pulsed") then return end
	if targetName == LocalPlayer.Name and targetDistance > 30 and ballDistance > 30 then return end
	if recentParries() >= spamParriesNeeded() and now - spamLast >= 1e-3 then
		if now - spamLast > 0.3 then
			lastParryEvent = math.max(lastParryEvent, now)
		elseif now - lastParryEvent > 1.5 then
			spamBlockUntil = now + 1
			return
		end
		spamLast = now
		_fireSpamParry()
		playParryAnimation(true)
	end
end

local autoSpamConn = nil
local function setAutoSpam(on)
	spamDetectionEnabled = on
	if on then
		if not autoSpamConn then
			autoSpamConn = RunService.PreSimulation:Connect(autoSpamCheck)
		end
	elseif autoSpamConn then
		autoSpamConn:Disconnect()
		autoSpamConn = nil
	end
	refreshStatus()
end

local function tbFire(ballInst)
	if tb.busy then return end
	tb.busy = true
	_fireParry()
	playParryAnimation(false)
	ballInst:GetAttributeChangedSignal("target"):Once(function()
		tb.busy = false
	end)
	local startedAt = os.clock()
	task.spawn(function()
		repeat
			RunService.PreSimulation:Wait()
		until (os.clock() - startedAt >= 1) or not tb.busy
		tb.busy = false
	end)
end

local tbConn = nil
local function tbStep()
	local ballInst = firstRealBall()
	if ballInst and ballInst:GetAttribute("target") == LocalPlayer.Name then
		tbFire(ballInst)
	end
end
local function setTriggerActive(on)
	on = on == true
	if tbActive == on then return end
	tbActive = on
	if on then
		if not tbConn then tbConn = RunService.PreSimulation:Connect(tbStep) end
	else
		tb.busy = false
		if tbConn then
			tbConn:Disconnect()
			tbConn = nil
		end
	end
	if tbToggle and tbToggle.Indicator then tbToggle.Indicator:Set(on) end
end

local Debris = game:GetService("Debris")

local function linearPredict(startValue, endValue, alpha)
	return startValue + (endValue - startValue) * alpha
end

local function ballCurved(instance)
	local zoomies = getZoomies(instance)
	if not zoomies then return false end
	local character = LocalPlayer.Character
	local root = character and character.PrimaryPart
	if not root then return false end
	local velocity = zoomies.VectorVelocity
	local speed = velocity.Magnitude
	if speed < 1 then return false end
	local now = tick()
	local ping = getDataPing()
	local velocityUnit = velocity.Unit
	local rootPosition = root.Position
	local ballPosition = ballPos(instance)
	local toPlayer = (rootPosition - ballPosition).Unit
	local alignment = toPlayer:Dot(velocityUnit)
	local speedAdjustment = math.min(speed / 100, 40)
	local alignmentDelta = alignment - toPlayer:Dot((velocityUnit - velocity).Unit)
	local distance = (rootPosition - ballPosition).Magnitude
	local curveThreshold = 0.5 - (ping / 1000)
	local travelTime = distance / speed - (ping / 1000)
	local distanceThreshold = 15 - math.min(distance / 1000, 15) + speedAdjustment
	ballState.LerpRadians = linearPredict(ballState.LerpRadians, math.rad(math.asin(math.clamp(alignment, -1, 1))), 0.8)
	if speed > 100 and travelTime > ping / 10 then
		distanceThreshold = math.max(distanceThreshold - 15, 15)
	end
	if distance < distanceThreshold then return false end
	if alignmentDelta < curveThreshold then return true end
	if ballState.LerpRadians < 0.018 then
		ballState.LastWarping = now
	end
	if (now - ballState.LastWarping) < (travelTime / 1.5) then return true end
	if (now - ballState.Curving) < (travelTime / 1.5) then return true end
	return alignment < curveThreshold
end

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	local parrySuccessAll = remotes and remotes:WaitForChild("ParrySuccessAll", 10)
	if not parrySuccessAll then return end
	trackConn(parrySuccessAll.OnClientEvent:Connect(function(_, parryPlayer)
		lastParryEvent = os.clock()
		local character = LocalPlayer.Character
		local root = character and character.PrimaryPart
		if not root then return end
		local instance = firstRealBall()
		if not instance then return end
		local zoomies = getZoomies(instance)
		if not zoomies then return end
		local speed = zoomies.VectorVelocity.Magnitude
		local distance = (root.Position - ballPos(instance)).Magnitude
		local ping = getDataPing()
		local travelTime = distance / speed - (ping / 1000)
		local distanceThreshold = 15 - math.min(distance / 1000, 15) + math.min(speed / 100, 40)
		if speed > 100 and travelTime > ping / 10 then
			distanceThreshold = math.max(distanceThreshold - 15, 15)
		end
		if parryPlayer ~= root and distance > distanceThreshold then
			ballState.Curving = tick()
		end
	end))
end)

local boundBalls = setmetatable({}, { __mode = "k" })
local function bindBall(instance)
	if boundBalls[instance] then return end
	local conns = {
		instance:GetAttributeChangedSignal("target"):Connect(resetAutoParry),
	}
	boundBalls[instance] = conns
	local function noteAero(child)
		if child.Name == "AeroDynamicSlashVFX" then
			Debris:AddItem(child, 0)
			ballState.AerodynamicTime = tick()
		end
	end
	conns[#conns + 1] = instance.ChildAdded:Connect(noteAero)
	local existing = instance:FindFirstChild("AeroDynamicSlashVFX")
	if existing then noteAero(existing) end
end
onBallRemoved(function(instance)
	local conns = boundBalls[instance]
	if conns then
		for i = 1, #conns do conns[i]:Disconnect() end
		boundBalls[instance] = nil
	end
end)

local PARRY_SPEED_BASE = 2.3497562749127492
local PARRY_SPEED_CAP = 425
local PARRY_SPEED_RATE = 0.002
local PARRY_PING_MIN = 10
local PARRY_PING_MAX = 16
local PARRY_ACC_CENTER = 65
local PARRY_LATE_SCALE = 0.3
local PARRY_EARLY_SCALE = 1.35
local PARRY_MIN_LEAD = 0.04
local PARRY_LATENCY_FACTOR = 1
local PARRY_RANGE_BONUS = 0

local function accuracyValue()
	local value = parryAccuracy
	if randomAccuracy then
		if not autoParry.rolled then
			autoParry.rolled = math.random(math.min(accuracyRangeMin, accuracyRangeMax), math.max(accuracyRangeMin, accuracyRangeMax))
		end
		value = autoParry.rolled
	end
	return math.clamp(value, 0, 100)
end

local function accuracyScale(accuracy)
	if accuracy < PARRY_ACC_CENTER then
		return PARRY_LATE_SCALE + (1 - PARRY_LATE_SCALE) * (accuracy / PARRY_ACC_CENTER)
	end
	return 1 + (PARRY_EARLY_SCALE - 1) * ((accuracy - PARRY_ACC_CENTER) / (100 - PARRY_ACC_CENTER))
end

local function parryTriggerDistance(speed, pingMs, accuracy)
	local pingTerm = math.clamp(pingMs / 10, PARRY_PING_MIN, PARRY_PING_MAX)
	local divisor = PARRY_SPEED_BASE + math.clamp(speed, 0, PARRY_SPEED_CAP) * PARRY_SPEED_RATE
	local rtt = pingMs * 0.001
	local distance = (pingTerm + math.max(speed / divisor, 9.5)) * accuracyScale(accuracy) + PARRY_RANGE_BONUS
	distance = distance + speed * rtt * PARRY_LATENCY_FACTOR
	local latencyFloor = speed * (rtt + PARRY_MIN_LEAD)
	return math.max(distance, latencyFloor, 9.5)
end

local function autoParryCheck(dt)
	if not autoParryActive or tb.busy then return end
	local character = LocalPlayer.Character
	local primary = character and character.PrimaryPart
	if not primary then return end
	local now = tick()
	if autoParry.debounce or now < autoParry.untilAt then return end
	local rootPos = primary.Position
	local pingMs = getDataPing()
	local list = realBallsIn(activeBallFolder())
	if not list or #list == 0 then return end
	local realTarget = list[1]:GetAttribute("target")
	local tornado = runtimeState.tornado
	if tornado and not tornado.Parent then tornado = nil end
	local tornadoTime = tornado and (tornado:GetAttribute("TornadoTime") or 1)
	local accuracy = accuracyValue()
	local frameStep = math.min(dt or 0, 0.05) * 0.5
	for _, instance in ipairs(list) do
		bindBall(instance)
		local zoomies = getZoomies(instance)
		if not zoomies then return end
		local ballTarget = instance:GetAttribute("target")
		local speed = zoomies.VectorVelocity.Magnitude
		local distance = (rootPos - ballPos(instance)).Magnitude
		if tornado and (now - ballState.AerodynamicTime) < tornadoTime + 0.314159 then return end
		if realTarget == LocalPlayer.Name and ballCurved(instance) then return end
		if ballTarget == LocalPlayer.Name and distance - speed * frameStep <= parryTriggerDistance(speed, pingMs, accuracy) then
			_fireParry()
			playParryAnimation(false)
			autoParry.debounce = true
			autoParry.untilAt = now + 1
		end
	end
end

local function startAutoParry()
	if autoParry.conn then return end
	autoParry.conn = RunService.PostSimulation:Connect(autoParryCheck)
end

local function stopAutoParry()
	if autoParry.conn then
		autoParry.conn:Disconnect()
		autoParry.conn = nil
	end
	resetAutoParry()
end

local function AP_setActive(v)
	autoParryActive = v
	refreshStatus()
end
local function AP_start() startAutoParry() end
local function AP_stop() stopAutoParry() end

local SPAM_HZ = 240
local SPAM_INTERVAL = 1 / SPAM_HZ
local SPAM_MAX_BURST = 4
local spamDue = 0
local spamClock = 0
local spamConn = nil

local function manualSpamStep()
	local aliveFolder = Workspace:FindFirstChild("Alive")
	local deadFolder = Workspace:FindFirstChild("Dead")
	local inAlive = aliveFolder and aliveFolder:FindFirstChild(LocalPlayer.Name)
	local inDead = deadFolder and deadFolder:FindFirstChild(LocalPlayer.Name)
	if not (inAlive or inDead) then
		spamDue = 1
		spamClock = 0
		return
	end
	local now = os.clock()
	if spamClock == 0 then spamClock = now end
	spamDue = spamDue + (now - spamClock) / SPAM_INTERVAL
	spamClock = now
	local fires = math.floor(spamDue)
	if fires < 1 then return end
	spamDue = spamDue - fires
	if fires > SPAM_MAX_BURST then fires = SPAM_MAX_BURST; spamDue = 0 end
	for _ = 1, fires do
		_fireSpamParry()
	end
	playParryAnimation(true)
end

local function startManualSpam()
	spamming = true
	spamDue = 1
	spamClock = 0
	spamPack.at = -1
	if not spamConn then spamConn = RunService.PreSimulation:Connect(manualSpamStep) end
end
local function stopManualSpam()
	spamming = false
	if spamConn then
		spamConn:Disconnect()
		spamConn = nil
	end
end

local Combat = _tabs.Combat

local RESERVED_KEYS = {
	[Enum.KeyCode.Zero] = "Curve 0",
	[Enum.KeyCode.One] = "Curve 1",
	[Enum.KeyCode.Two] = "Curve 2",
	[Enum.KeyCode.Three] = "Curve 3",
	[Enum.KeyCode.Four] = "Curve 4",
	[Enum.KeyCode.Five] = "Curve 5",
	[Enum.KeyCode.Six] = "Curve 6",
	[Enum.KeyCode.Seven] = "Curve 7",
	[Enum.KeyCode.Eight] = "Curve 8",
}
Combat:AddSection("Parry")
local parryGroup = Combat:AddGroup()
parryGroup:AddToggle({
	Name = "Auto Parry",
	Flag = "auto_parry",
	Default = true,
	Icon = Library.Icons.Sword,
	IconSelected = Library.Icons.Sword_Selected,
	IconToggle = true,
	IconOffsetX = 6,
	Chip = "ANIM",
	ChipDefault = false,
	ChipCallback = function(on) parryAnimationEnabled = on end,
	Callback = function(s)
		AP_setActive(s)
		if s then AP_start() else AP_stop() end
	end,
})
AP_setActive(true)
AP_start()
parryGroup:AddRandomSlider({
	Name = "Accuracy",
	Flag = "accuracy",
	Min = 0, Max = 100, Increment = 1, Default = 50,
	DefaultMin = 0, DefaultMax = 100, Suffix = "%",
	Randomize = false,
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
	Flag = "curve_type",
	Options = { "Camera", "Dot", "Random", "Slow", "Accelerate", "Backwards", "Up", "Left", "Right" },
	Default = "Camera",
	NumberStart = 0,
	Callback = function(v)
		parryType = v
		if getgenv then getgenv()._pyraParryType = v end
	end,
})

tbToggle = parryGroup:AddToggle({
	Name = "Triggerbot",
	Flag = "triggerbot",
	Description = "Parries as soon as the ball targets you.",
	NoSwitch = true,
	Indicator = true,
	Chip = "Hold Mode",
	ChipDefault = false,
	ChipCallback = function(on)
		tbHold = on
		setTriggerActive(false)
	end,
	Keybind = Enum.KeyCode.T,
	KeybindChanged = function(key)
		local clash = key and RESERVED_KEYS[key]
		if clash then
			UI:Notify("Keybind in use", key.Name .. " is reserved for " .. clash .. ".", 4)
			if tbToggle and tbToggle.Keybind then tbToggle.Keybind:Set(tbBind) end
			return
		end
		if key and key == manualSpamBind then
			UI:Notify("Keybind in use", key.Name .. " is already used by Manual Spam.", 4)
			if tbToggle and tbToggle.Keybind then tbToggle.Keybind:Set(tbBind) end
			return
		end
		tbBind = key
	end,
})

Combat:AddSection("Spam")
local spamGroup = Combat:AddGroup()
manualToggle = spamGroup:AddToggle({
	Name = "Manual Spam",
	Flag = "manual_spam",
	Description = "Hold the bind to spam parry",
	NoSwitch = true,
	Indicator = true,
	Chip = "Hold Mode",
	ChipDefault = false,
	ChipCallback = function(on)
		manualSpamHold = on
		manualKeyOwned = false
		if spamming then stopManualSpam() end
	end,
	Keybind = Enum.KeyCode.E,
	KeyOffsetX = 3,
	KeybindChanged = function(key)
		local clash = key and RESERVED_KEYS[key]
		if clash then
			UI:Notify("Keybind in use", key.Name .. " is reserved for " .. clash .. ".", 4)
			if manualToggle and manualToggle.Keybind then
				manualToggle.Keybind:Set(manualSpamBind)
			end
			return
		end
		if key and key == tbBind then
			UI:Notify("Keybind in use", key.Name .. " is already used by Triggerbot.", 4)
			if manualToggle and manualToggle.Keybind then
				manualToggle.Keybind:Set(manualSpamBind)
			end
			return
		end
		manualSpamBind = key
	end,
})
spamGroup:AddSlider({
	Name = "Auto Spam",
	Flag = "auto_spam_level",
	Description = "Determines when to start/stop spamming. 0 is off.",
	Min = 0, Max = 5, Increment = 1, Default = 0,
	Format = function(v) return v == 0 and "OFF" or tostring(v) end,
	Callback = function(v)
		if v >= 1 then spamDistanceSetting = v end
		setAutoSpam(v >= 1)
	end,
})
do
	local mobileManual

	local function syncMobileToSpam()
		if mobileManual then mobileManual:Set(spamming == true, true) end
		if manualToggle and manualToggle.Indicator then manualToggle.Indicator:Set(spamming == true) end
	end
	local _startSpam, _stopSpam = startManualSpam, stopManualSpam
	startManualSpam = function() _startSpam(); syncMobileToSpam() end
	stopManualSpam = function()
		_stopSpam()
		clearParries()
		syncMobileToSpam()
	end

	mobileManual = UI:AddMobileButton({
		Name = "Manual Spam",
		Toggle = true,
		Default = false,
		OnClick = function(on)
			if not manualSpamEnabled then return end
			if on then startManualSpam() else stopManualSpam() end
		end,
	})
end

local function releaseHeldKeys()
	if manualKeyOwned then
		manualKeyOwned = false
		if manualSpamHold and spamming then stopManualSpam() end
	end
	if tbHold and tbActive then setTriggerActive(false) end
end

table.insert(UI.Connections, UserInputService.InputBegan:Connect(function(input)
	local code = input.KeyCode
	if code == Enum.KeyCode.Unknown then return end
	if UserInputService:GetFocusedTextBox() ~= nil then return end
	if manualSpamEnabled and code == manualSpamBind then
		if manualSpamHold then
			manualKeyOwned = true
			if not spamming then startManualSpam() end
		elseif spamming then
			stopManualSpam()
		else
			startManualSpam()
		end
	end
	if tbEnabled and code == tbBind then
		if tbHold then setTriggerActive(true) else setTriggerActive(not tbActive) end
	end
end))
table.insert(UI.Connections, UserInputService.InputEnded:Connect(function(input)
	local code = input.KeyCode
	if code == manualSpamBind and manualSpamHold and manualKeyOwned then
		manualKeyOwned = false
		if spamming then stopManualSpam() end
	end
	if code == tbBind and tbHold then setTriggerActive(false) end
end))
table.insert(UI.Connections, UserInputService.WindowFocusReleased:Connect(releaseHeldKeys))
table.insert(UI.Connections, UserInputService.TextBoxFocused:Connect(releaseHeldKeys))


UI:OnDestroy(function()
	for _, c in ipairs(_pyraConns) do pcall(function() c:Disconnect() end) end
	table.clear(_pyraConns)
	for _, conns in pairs(boundBalls) do
		for i = 1, #conns do pcall(function() conns[i]:Disconnect() end) end
	end
	table.clear(boundBalls)
	autoParryActive = false
	pcall(stopAutoParry)
	setAutoSpam(false)
	setTriggerActive(false)
	manualSpamEnabled = false
	spamming = false
	if spamConn then
		spamConn:Disconnect()
		spamConn = nil
	end
end)
end

-- ===== TARGET =====
do
local player = Players.LocalPlayer
local forcedTargetPlayer, forceTargetParry
local Target = _tabs.Target

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
	local hideDetachToast, hideTargetToast, hideLeftToast = false, false, false
	local espHighlight, espWatch
	local espToggle, forceToggle, spectateToggle, searchApi
	local espAuto, settingEspAuto = false, false
	local GOOD = Color3.fromRGB(90, 220, 130)
	local BAD = Color3.fromRGB(235, 90, 90)

	local statsPanel
	statsPanel = UI:CreateSidePanel({
		Title = "Target Info",
		DockPriority = 1,
		Pinned = false,
		Closable = true,
		PinSide = "Left",
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
				UI:Notify("Target Info", "Detached - drag it back to the side to re-attach.", {
					Duration = 5,
					Button = "Don't show again",
					OnButton = function() hideDetachToast = true end,
				})
			end
		end,
	})
	statsPanel._homeTab = Target

	local function isTargeted(t)
		local ballsFolder = Workspace:FindFirstChild("Balls")
		if not ballsFolder then return false end
		for _, b in ipairs(ballsFolder:GetChildren()) do
			if b:GetAttribute("realBall") and b:GetAttribute("target") == t.Name then return true end
		end
		return false
	end

	local function isAlive(p)
		local aliveFolder = Workspace:FindFirstChild("Alive")
		return aliveFolder ~= nil and aliveFolder:FindFirstChild(p.Name) ~= nil
	end

	local espHidden = false

	local function clearESP()
		if espWatch then pcall(function() espWatch:Disconnect() end) espWatch = nil end
		if espHighlight then pcall(function() espHighlight:Destroy() end) espHighlight = nil end
		espHidden = false
	end

	local function syncESPVisibility()
		if not espHighlight then return end
		local t = targetState.target
		local hide = t ~= nil and isTargeted(t)
		if hide ~= espHidden then
			espHidden = hide
			espHighlight.Enabled = not hide
		end
	end

	local applyESP
	local reapplyQueued = false
	local function queueReapply()
		if reapplyQueued then return end
		reapplyQueued = true
		task.delay(0.1, function()
			reapplyQueued = false
			if not (espHighlight and targetState.esp) then return end
			syncESPVisibility()
			if not espHidden then applyESP() end
		end)
	end

	function applyESP()
		clearESP()
		if not targetState.esp then return end
		local t = targetState.target
		local char = t and t.Character
		if not char then return end
		local hl = Instance.new("Highlight")
		hl.Name = "PyraTargetESP"
		hl.FillTransparency = 0
		hl.OutlineTransparency = 0
		hl.FillColor = targetState.espColor
		hl.OutlineColor = targetState.espColor
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Adornee = char
		espHidden = isTargeted(t)
		hl.Enabled = not espHidden
		espHighlight = hl
		hl.Parent = char
		espWatch = char.DescendantAdded:Connect(function(d)
			if d ~= espHighlight and d:IsA("Highlight") then
				syncESPVisibility()
				if not espHidden then queueReapply() end
			end
		end)
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
	local viewLookModel, viewLookName, viewLookInst
	local viewPrev, viewLast, viewLastAt, viewInterval, viewShown, viewOffset, viewVisible = nil, nil, 0, 0.1, nil, nil, nil
	local function resetViewMotion()
		viewLookModel, viewLookName, viewLookInst = nil, nil, nil
		viewPrev, viewLast, viewShown, viewOffset, viewVisible = nil, nil, nil, nil, nil
	end
	local function resolveLook(t)
		if not t then return nil end
		if viewLookInst and viewLookName == t.Name and viewLookModel and viewLookModel.Parent and viewLookInst.Parent == viewLookModel then
			return viewLookInst
		end
		local aliveFolder = Workspace:FindFirstChild("Alive")
		local model = aliveFolder and aliveFolder:FindFirstChild(t.Name) or nil
		viewLookModel, viewLookName = model, t.Name
		viewLookInst = model and model:FindFirstChild("Look") or nil
		return viewLookInst
	end
	local function destroyViewCamParts()
		if not viewCamParts then return end
		for _, inst in pairs(viewCamParts) do pcall(function() inst:Destroy() end) end
		viewCamParts = nil
	end
	local function stopViewCam()
		pcall(function() RunService:UnbindFromRenderStep("PyraViewCam") end)
		destroyViewCamParts()
		resetViewMotion()
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

		viewCamParts = { screen = screen, lens = lens, box = box }
	end
	local function setViewCamColor(c)
		if not viewCamParts then return end
		viewCamParts.screen.Color = c
		viewCamParts.lens.Color = c
		viewCamParts.box.Color3 = c
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

		resetViewMotion()
		RunService:BindToRenderStep("PyraViewCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
			if not viewCamParts then return end
			dt = dt or (1 / 60)
			local look = resolveLook(targetState.target)
			local cf = look and look.Value
			if not cf then
				if viewVisible ~= false then
					viewVisible = false
					viewCamParts.screen.Transparency = 1
					viewCamParts.lens.Transparency = 1
					viewCamParts.box.Transparency = 1
				end
				viewPrev, viewLast, viewShown, viewOffset = nil, nil, nil, nil
				return
			end
			local now = os.clock()
			local fresh = false
			if cf ~= viewLast then
				fresh = true
				if viewLast and (cf.Position - viewLast.Position).Magnitude < 40 then
					viewPrev = viewLast
					viewInterval = math.clamp(now - viewLastAt, 1 / 90, 0.25)
					local turn = math.acos(math.clamp(cf.LookVector:Dot(viewLast.LookVector), -1, 1))
					if turn / viewInterval > 9 then viewPrev = nil end
				else
					viewPrev = nil
					viewShown = nil
				end
				viewLast, viewLastAt = cf, now
			end
			local pose = viewLast
			if viewPrev then
				local a = math.clamp((now - viewLastAt) / viewInterval, 0, 1)
				pose = viewLast:Lerp(viewLast * viewPrev:ToObjectSpace(viewLast), a)
			end
			if fresh then
				viewOffset = viewShown and pose:ToObjectSpace(viewShown) or nil
			end
			if viewOffset then
				viewOffset = viewOffset:Lerp(CFrame.new(), 1 - math.exp(-dt * 60))
				viewShown = pose * viewOffset
			else
				viewShown = pose
			end
			if viewVisible ~= true then
				viewVisible = true
				viewCamParts.screen.Transparency = 0.72
				viewCamParts.lens.Transparency = 0.25
				viewCamParts.box.Transparency = 0
			end
			viewCamParts.lens.CFrame = viewShown
			viewCamParts.screen.CFrame = viewShown * CFrame.new(0, 0, -6)
		end)
	end

	local function setTarget(p)
		if p and not p.Parent then return end
		targetState.target = p
		forcedTargetPlayer = p
		resetViewMotion()
		local espDone = false
		if p then
			statsPanel:SetAvatar(p.UserId)
			if type(statsPanel.SetClearVisible) == "function" then statsPanel:SetClearVisible(true) end
			if UI.ActiveTab == Target and type(statsPanel.IsShown) == "function" and not statsPanel:IsShown() then
				statsPanel:Show()
			end
			if not hideTargetToast then
				UI:Notify("Target Selected", p.DisplayName, {
					Duration = 3,
					Button = "Don't show again",
					OnButton = function() hideTargetToast = true end,
				})
			end
			if not targetState.esp and espToggle then
				settingEspAuto = true
				espToggle:Set(true)
				settingEspAuto = false
				espAuto = true
				espDone = true
			end
		end
		if not espDone then applyESP() end
		if targetState.spectating then setCameraSubject(true) end
	end

	Target:AddSection("Target")
	searchApi = Target:AddPlayerSearch({
		Placeholder = "Search a player...",
		RowInfo = function(p)
			if isAlive(p) then return "PLAYING", GOOD, 1 end
			return "DEAD", BAD, 2
		end,
		Callback = function(p) setTarget(p) end,
	})

	local optionsGroup = Target:AddGroup({ Collapsible = false })
	forceToggle = optionsGroup:AddToggle({
		Name = "Force Target Parry",
		Flag = "force_target_parry",
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
	spectateToggle = optionsGroup:AddToggle({
		Name = "Spectate",
		Flag = "spectate",
		Description = "Watch the target",
		Default = false,
		Icon = Library.Icons.Spectate,
		IconSelected = Library.Icons.Spectate_Selected,
		IconToggle = true,
		Callback = function(on)
			targetState.spectating = on
			setCameraSubject(on)
		end,
	})
	optionsGroup:AddToggle({
		Name = "View Camera Location",
		Flag = "view_camera",
		Default = false,
		Icon = Library.Icons.Spectate,
		IconSelected = Library.Icons.Spectate_Selected,
		IconToggle = true,
		Callback = function(on)
			targetState.viewCam = on
			if on then startViewCam() else stopViewCam() end
		end,
	})
	optionsGroup:AddColorPicker({
		Name = "View Cam Color",
		Sub = true,
		Flag = "view_cam_color",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(c)
			targetState.viewCamColor = c
			setViewCamColor(c)
		end,
	})

	espToggle = optionsGroup:AddToggle({
		Name = "ESP Highlight",
		Flag = "esp_highlight",
		Default = false,
		Icon = Library.Icons.Spectate,
		IconSelected = Library.Icons.Spectate_Selected,
		IconToggle = true,
		Callback = function(on)
			targetState.esp = on
			if not settingEspAuto then espAuto = false end
			applyESP()
		end,
	})
	optionsGroup:AddColorPicker({
		Name = "ESP Color",
		Sub = true,
		Flag = "esp_color",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(c)
			targetState.espColor = c
			if espHighlight then
				espHighlight.FillColor = c
				espHighlight.OutlineColor = c
			end
		end,
	})

	if type(statsPanel.AddAvatarButton) == "function" then
		local forceIcon = statsPanel:AddAvatarButton({
			Corner = "BottomRight",
			Index = 2,
			IconSize = 26,
			Icon = Library.Icons.Sword,
			IconSelected = Library.Icons.Sword_Selected,
			Callback = function(on) forceToggle:Set(on) end,
		})
		local spectateIcon = statsPanel:AddAvatarButton({
			Corner = "BottomRight",
			Index = 1,
			IconSize = 28,
			Icon = Library.Icons.Spectate,
			IconSelected = Library.Icons.Spectate_Selected,
			Callback = function(on) spectateToggle:Set(on) end,
		})
		forceToggle:OnChanged(function(on) forceIcon:SetState(on) end)
		spectateToggle:OnChanged(function(on) spectateIcon:SetState(on) end)
		forceIcon:SetState(forceToggle:Get())
		spectateIcon:SetState(spectateToggle:Get())
	end
	UI:OnTabChanged(function(tab)
		if statsPanel:IsDetached() then return end
		if tab == Target then
			statsPanel:Show()
		elseif not statsPanel:IsPinned() then
			statsPanel:Hide()
		end
	end)

	task.spawn(function()
		while not UI.Destroyed and not UI.Open do task.wait(0.1) end
		if UI.Destroyed or UI.ActiveTab ~= Target then return end
		if not statsPanel:IsDetached() then statsPanel:Show() end
	end)

	local STAT_KEYS = {
		"Username", "ELO", "Device", "Account Age", "RAP",
		"Sword", "Wins", "Elims", "Ability", "Alive", "Targeted", "Pulsed",
	}

	local function isPulsed(t)
		local aliveFolder = Workspace:FindFirstChild("Alive")
		local model = aliveFolder and aliveFolder:FindFirstChild(t.Name)
		local p = model and model:FindFirstChild("PULSED")
		if p and p.Value then return true end
		local char = t.Character
		if char and char:GetAttribute("Pulsed") then return true end
		return false
	end

	local function getElo(t)
		local v = t:FindFirstChild("TotalRAP")
		if v and v:IsA("ValueBase") then return v.Value end
		return t:GetAttribute("ELO")
	end

	local function showNoTarget()
		statsPanel:ClearAvatar()
		statsPanel:SetTitle("Display Name")
		for _, k in ipairs(STAT_KEYS) do statsPanel:SetStat(k, "-") end
	end

	local hasClear = type(statsPanel.SetClearVisible) == "function"

	local function clearTarget()
		targetState.target = nil
		forcedTargetPlayer = nil
		resetViewMotion()
		if searchApi and type(searchApi.Clear) == "function" then searchApi:Clear() end
		if espAuto and espToggle and targetState.esp then
			settingEspAuto = true
			espToggle:Set(false)
			settingEspAuto = false
		end
		espAuto = false
		applyESP()
		if targetState.spectating then setCameraSubject(true) end
		showNoTarget()
		if hasClear then statsPanel:SetClearVisible(false) end
	end
	if type(statsPanel.SetClearHandler) == "function" then statsPanel:SetClearHandler(clearTarget) end

	local function handleTargetLeft()
		local t = targetState.target
		if not t then return end
		local name = t.DisplayName
		clearTarget()
		if not hideLeftToast then
			UI:Notify("Target left", name .. " left the server.", {
				Duration = 4,
				Button = "Don't show again",
				OnButton = function() hideLeftToast = true end,
			})
		end
	end

	local leaveConn = Players.PlayerRemoving:Connect(function(p)
		if p == targetState.target then handleTargetLeft() end
	end)

	task.spawn(function()
		while not UI.Destroyed do
			if espHighlight then pcall(syncESPVisibility) end
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		local lastChar
		while not UI.Destroyed do
			local ok = pcall(function()
			local t = targetState.target
			if t and not t.Parent then
				handleTargetLeft()
				t = nil
				lastChar = nil
			end
			if t then
				if targetState.esp and t.Character ~= lastChar then
					lastChar = t.Character
					applyESP()
				end
				if hasClear then statsPanel:SetClearVisible(true) end
				statsPanel:SetTitle(t.DisplayName)
				statsPanel:SetStat("Username", "@" .. t.Name)
				statsPanel:SetStat("ELO", tostring(getElo(t) or "N/A"))
				statsPanel:SetStat("Device", tostring(t:GetAttribute("Device") or "N/A"))
				statsPanel:SetStat("Account Age", t.AccountAge .. " days")
				statsPanel:SetStat("RAP", tostring(t:GetAttribute("TotalRAP") or "N/A"))
				statsPanel:SetStat("Sword", tostring(t:GetAttribute("CurrentlyEquippedSword") or "N/A"))
				statsPanel:SetStat("Wins", tostring(t:GetAttribute("PlayerWins") or "N/A"))
				statsPanel:SetStat("Elims", tostring(t:GetAttribute("PlayerElims") or "N/A"))
				statsPanel:SetStat("Ability", tostring(t:GetAttribute("EquippedAbility") or "None"))

				local alive = isAlive(t)
				statsPanel:SetStat("Alive", alive and "Yes" or "No", alive and GOOD or BAD)
				local tg = isTargeted(t)
				statsPanel:SetStat("Targeted", tg and "Yes" or "No", tg and GOOD or BAD)
				local pl = isPulsed(t)
				statsPanel:SetStat("Pulsed", pl and "Yes" or "No", pl and GOOD or BAD)
			else
				if lastChar then lastChar = nil clearESP() end
				showNoTarget()
				if hasClear then statsPanel:SetClearVisible(false) end
			end
			end)
			task.wait(0.5)
		end
	end)

	UI.TargetState = targetState
	UI:OnDestroy(function()
		pcall(function() leaveConn:Disconnect() end)
		clearESP()
		pcall(stopViewCam)
		pcall(setCameraSubject, false)
	end)
end


UI:OnDestroy(function()
end)
end

-- ===== SETTINGS =====
do
local player = Players.LocalPlayer
local _pyraConns = {}
local function trackConn(conn)
	_pyraConns[#_pyraConns + 1] = conn
	return conn
end
local function realBallsIn(folder)
    if not folder then return nil end
    local list, n = {}, 0
    for _, b in ipairs(folder:GetChildren()) do
        if b:IsA("BasePart") and b:GetAttribute("realBall") then
            n = n + 1; list[n] = b
        end
    end
    return list
end

local PYRA_LIB_URL = "https://raw.githubusercontent.com/SwipeCard/PyraUI/main/PyraUI_Library.lua"
local SESSION_FILE = "PyraSession.txt"
local SESSION_GAP = 90
local hasFiles = (type(writefile) == "function") and (type(readfile) == "function") and (type(isfile) == "function")

local PYRA_DIR = "Pyra"
local PYRA_CONFIG_DIR = PYRA_DIR .. "/configs"
local hasFolders = (type(makefolder) == "function") and (type(isfolder) == "function")
local function ensurePyraFolders()
	if not hasFolders then return end
	pcall(function() if not isfolder(PYRA_DIR) then makefolder(PYRA_DIR) end end)
	pcall(function() if not isfolder(PYRA_CONFIG_DIR) then makefolder(PYRA_CONFIG_DIR) end end)
end
local function pyraPath(name) return PYRA_DIR .. "/" .. name end
local function pyraConfigPath(name) return PYRA_CONFIG_DIR .. "/" .. name end
if hasFiles then ensurePyraFolders() end

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

local camera = Workspace.CurrentCamera


task.spawn(function()
	local lastReady = nil
	while not UI.Destroyed do
		local ready = UI.ParryReady == true
		if ready ~= lastReady then
			lastReady = ready
			if ready then
				UI:SetStatus("Active", Color3.fromRGB(90, 220, 130))
				print("[Pyra] status -> ACTIVE (remote captured)")
			else
				UI:SetStatus("Inactive", Color3.fromRGB(220, 70, 70))
				print("[Pyra] status -> INACTIVE (no remote captured yet)")
			end
		end
		task.wait(0.5)
	end
end)

local Settings = _tabs.Settings

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
			Url = 'http://127.0.0.1:6463/rpc?v=1',
			Method = 'POST',
			Headers = {
				['Content-Type'] = 'application/json',
				['origin'] = 'https://discord.com',
			},
			Body = game:GetService('HttpService'):JSONEncode({
				["args"] = {
					['code'] = DISCORD_CODE,
				},
				['cmd'] = 'INVITE_BROWSER',
				['nonce'] = '.',
			});
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

local monFps = UI:AddMonitor("fps", "FPS")
local monPing = UI:AddMonitor("ping", "PING")
local monVel = UI:AddMonitor("vel", "BALL")
local _showFps, _showPing, _showBallVel, _fpsUnlocked = false, false, false, false
task.spawn(function()
	local frames, t0 = 0, os.clock()
	local conn = RunService.RenderStepped:Connect(function() frames += 1 end)
	table.insert(UI.Connections, conn)
	while not UI.Destroyed do
		local now = os.clock()
		if _showFps then monFps:Set(math.floor(frames / math.max(now - t0, 1e-3) + 0.5)) end
		frames, t0 = 0, now
		if _showPing then
			local ok, p = pcall(function() return player:GetNetworkPing() end)
			monPing:Set(ok and (math.floor(p * 1000 + 0.5) .. " ms") or "-- ms")
		end
		task.wait(0.75)
	end
end)

local _peakSpeed = 0
local _knownBalls = {}
task.spawn(function()
	while not UI.Destroyed do
		if _showBallVel then
			local balls = realBallsIn(Workspace:FindFirstChild("Balls"))
			local live, present, any = 0, {}, false
			if balls then
				for i = 1, #balls do
					local b = balls[i]
					any = true
					present[b] = true
					if not _knownBalls[b] then
						_knownBalls[b] = true
						_peakSpeed = 0
					end
					local z = b:FindFirstChild("zoomies")
					if z then
						local s = z.VectorVelocity.Magnitude
						if s > live then live = s end
					end
				end
			end
			for b in pairs(_knownBalls) do
				if not present[b] then _knownBalls[b] = nil end
			end
			if live > _peakSpeed then _peakSpeed = live end
			if any then
				monVel:Set(string.format("%d (peak: %d)", math.floor(live + 0.5), math.floor(_peakSpeed + 0.5)))
			else
				monVel:Set("-- (peak: --)")
			end
		end
		RunService.Heartbeat:Wait()
	end
end)

Settings:AddSection("Monitors")
local fpsUnlockSlider
local _fpsCapWarned = false
local function applyFpsUnlock(cap, silent)
	cap = math.clamp(tonumber(cap) or 60, 30, 420)
	_fpsUnlocked = cap > 60
	local ok, how = UI:SetFPSCap(cap)
	if silent then return end
	if ok and how == "fflag" and not _fpsCapWarned then
		_fpsCapWarned = true
		UI:Notify("FPS Unlock", "Applied via fast flag - rejoin for it to take effect.", 7)
	elseif not ok and not _fpsCapWarned then
		_fpsCapWarned = true
		UI:Notify("FPS Unlock", "No FPS cap hook available in this executor.", 7)
	end
end
local monitorGroup = Settings:AddGroup({ Collapsible = false })
monitorGroup:AddToggle({
	Name = "Display Ping",
	Flag = "ping_monitor",
	Default = false,
	Callback = function(on) _showPing = on; monPing:Show(on) end,
})
monitorGroup:AddToggle({
	Name = "Display Ball Velocity",
	Flag = "ball_velocity",
	Default = false,
	Callback = function(on) _showBallVel = on; monVel:Show(on) end,
})
monitorGroup:AddToggle({
	Name = "Display FPS",
	Flag = "fps_counter",
	Default = false,
	Callback = function(on) _showFps = on; monFps:Show(on) end,
})
fpsUnlockSlider = monitorGroup:AddSlider({
	Name = "Unlock FPS",
	Flag = "unlock_fps",
	Min = 30, Max = 420, Increment = 10, Default = 120,
	Callback = function(v) applyFpsUnlock(v) end,
})
applyFpsUnlock(120, true)
monFps:OnClick(function()
	local nowUnlocked = not _fpsUnlocked
	applyFpsUnlock(nowUnlocked and 420 or 60)
	if fpsUnlockSlider then fpsUnlockSlider:Set(nowUnlocked and 420 or 60) end
end)

local ICON_SAVE = "rbxassetid://130769208232286"
local ICON_DELETE = "rbxassetid://88197698549266"
local openFFlagEditor
do
	local HttpService = game:GetService("HttpService")
	local FFLAG_DIR = PYRA_DIR .. "/fastflags"
	local function ensureFFlagFolder()
		if not hasFolders then return end
		pcall(function() if not isfolder(PYRA_DIR) then makefolder(PYRA_DIR) end end)
		pcall(function() if not isfolder(FFLAG_DIR) then makefolder(FFLAG_DIR) end end)
	end

	local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

	local function fflagPath(name)
		local clean = trim(name)
		if clean == "" then return nil, "profile name is empty" end
		clean = clean:gsub('[<>:"/\\|%?%*%c]', "_"):sub(1, 64)
		return FFLAG_DIR .. "/cfg_" .. clean .. ".json", nil, clean
	end

	local function fflagDecode(json_text)
		if type(json_text) ~= "string" or trim(json_text) == "" then
			return nil, "fflags json is empty"
		end
		local ok, decoded = pcall(function() return HttpService:JSONDecode(json_text) end)
		if not ok or type(decoded) ~= "table" then return nil, "invalid fflags json" end
		local flags, count = {}, 0
		for name, value in pairs(decoded) do
			if type(name) ~= "string" or trim(name) == "" then return nil, "every fflag needs a valid string name" end
			if type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" then
				return nil, "fflag values must be strings, numbers, or booleans"
			end
			flags[name] = tostring(value)
			count = count + 1
		end
		if count == 0 then return nil, "fflags json has no flags" end
		return flags, nil, count
	end

	local function fflagApply(json_text)
		if type(setfflag) ~= "function" then return false, "setfflag unavailable in this executor" end
		local flags, err, count = fflagDecode(json_text)
		if not flags then return false, err end
		local failed = {}
		for name, value in pairs(flags) do
			if not pcall(setfflag, name, value) then table.insert(failed, name) end
		end
		if #failed > 0 then return false, "failed " .. #failed .. "/" .. count .. " flags" end
		return true, "applied " .. count .. " fflags"
	end

	local function fflagSave(name, json_text)
		if not hasFiles then return false, "no file storage" end
		local flags, err = fflagDecode(json_text)
		if not flags then return false, err end
		local path, perr = fflagPath(name)
		if not path then return false, perr end
		local ok, encoded = pcall(function() return HttpService:JSONEncode(flags) end)
		if not ok then return false, "could not encode profile" end
		ensureFFlagFolder()
		if not pcall(writefile, path, encoded) then return false, "could not save profile" end
		return true, "saved"
	end

	local function fflagLoad(name)
		if not hasFiles then return false, "no file storage" end
		local path, perr = fflagPath(name)
		if not path then return false, perr end
		local ok, json_text = pcall(readfile, path)
		if not ok or type(json_text) ~= "string" then return false, "profile not found" end
		return true, json_text
	end
	local function fflagDelete(name)
		if not hasFiles or type(delfile) ~= "function" then return false, "cannot delete files here" end
		local path, perr = fflagPath(name)
		if not path then return false, perr end
		local ok = pcall(function() if isfile(path) then delfile(path) end end)
		return ok, ok and "deleted" or "could not delete"
	end
	local function fflagList()
		local names = {}
		if hasFiles and type(listfiles) == "function" then
			local ok, files = pcall(listfiles, FFLAG_DIR)
			if ok and type(files) == "table" then
				for _, p in ipairs(files) do
					local fname = tostring(p):match("([^/\\]+)$")
					local n = fname and fname:match("^cfg_(.+)%.json$")
					if n then table.insert(names, n) end
				end
			end
		end
		table.sort(names)
		return names
	end

	local NONE_FF = "No saved configs"
	local PRIVATE_NAME = "Private Flags"
	local PRIVATE_URL = "https://raw.githubusercontent.com/SwipeCard/PyraUI/main/PyraUI_Flags.lua"
	local AUTO_FILE = FFLAG_DIR .. "/auto.txt"

	local function normalizeFlags(tbl)
		local flags, count = {}, 0
		local function put(name, value)
			if type(name) ~= "string" or trim(name) == "" then return end
			local tv = type(value)
			if tv == "boolean" then value = value and "True" or "False"
			elseif tv ~= "number" and tv ~= "string" then return end
			if flags[name] == nil then count = count + 1 end
			flags[name] = value
		end
		for k, v in pairs(tbl) do
			if type(k) == "string" then
				put(k, v)
			elseif type(v) == "table" then
				local val = v[2]
				if val == nil then val = v.Value end
				if val == nil then val = v.value end
				put(v[1] or v.Name or v.name, val)
			elseif type(v) == "string" then
				local n, val = v:match("^%s*([%w_]+)%s*[=:]%s*(.-)%s*$")
				if n then put(n, val) end
			end
		end
		if count == 0 then return nil end
		return flags
	end

	local function flagsFromSource(src, depth)
		depth = depth or 0
		if type(src) ~= "string" or depth > 2 then return nil end
		local text = trim((src:gsub("^\239\187\191", "")))
		if text == "" then return nil end
		local c = text:sub(1, 1)
		if c == "{" or c == "[" then
			local ok, decoded = pcall(function() return HttpService:JSONDecode(text) end)
			if ok and type(decoded) == "table" then
				local f = normalizeFlags(decoded)
				if f then return f end
			end
		end
		if type(loadstring) == "function" and type(setfenv) == "function" then
			local fn = loadstring(text)
			if type(fn) == "function" and pcall(setfenv, fn, {}) then
				local ok, result = pcall(fn)
				if ok then
					if type(result) == "table" then
						local f = normalizeFlags(result)
						if f then return f end
					elseif type(result) == "string" then
						local f = flagsFromSource(result, depth + 1)
						if f then return f end
					end
				end
			end
		end
		local flags, count = {}, 0
		for line in text:gmatch("[^\r\n]+") do
			local n, v = line:match("setfflag%s*%(%s*[\"']([^\"']+)[\"']%s*,%s*[\"']?([^\"')]*)[\"']?%s*%)")
			if not n then n, v = line:match("[\"']([%w_]+)[\"']%s*%]?%s*[=:]%s*[\"']?([^\"',}]*)[\"']?") end
			if not n then n, v = line:match("^%s*([%a][%w_]*)%s*[=:]%s*[\"']?([^\"',}]*)[\"']?") end
			if n and n:match("^[DS]?F[FILS]%a") and v ~= nil then
				if flags[n] == nil then count = count + 1 end
				flags[n] = trim(v)
			end
		end
		if count > 0 then return flags end
		return nil
	end

	local function quoteJson(v)
		v = tostring(v):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("%c", " ")
		return '"' .. v .. '"'
	end
	local function flagsToText(flags)
		local names = {}
		for n in pairs(flags) do names[#names + 1] = n end
		table.sort(names)
		local out = {}
		for _, n in ipairs(names) do
			local v = flags[n]
			out[#out + 1] = "  " .. quoteJson(n) .. ": " .. (type(v) == "number" and tostring(v) or quoteJson(v))
		end
		return "{\n" .. table.concat(out, ",\n") .. "\n}"
	end

	local privateText
	local function fetchPrivate()
		local ok, body = pcall(function() return game:HttpGet(PRIVATE_URL .. "?t=" .. os.time()) end)
		if not ok or type(body) ~= "string" or body == "" then return false, "Couldn't download Private Flags." end
		local flags = flagsFromSource(body)
		if not flags then return false, "Couldn't read the Private Flags list." end
		return true, flagsToText(flags)
	end

	local function loadProfile(name, cb)
		if name == PRIVATE_NAME then
			if privateText then cb(true, privateText); return end
			task.spawn(function()
				local ok, text = fetchPrivate()
				if ok then privateText = text end
				cb(ok, text)
			end)
		else
			local ok, text = fflagLoad(name)
			cb(ok, text)
		end
	end

	local function readAuto()
		if not hasFiles then return nil end
		local ok, v = pcall(function() if isfile(AUTO_FILE) then return readfile(AUTO_FILE) end end)
		if ok and type(v) == "string" then
			v = trim(v)
			if v ~= "" then return v end
		end
		return nil
	end
	local function writeAuto(name)
		if not hasFiles then return end
		ensureFFlagFolder()
		pcall(writefile, AUTO_FILE, name)
	end
	local function clearAuto()
		if not hasFiles then return end
		if type(delfile) == "function" then
			pcall(function() if isfile(AUTO_FILE) then delfile(AUTO_FILE) end end)
		else
			pcall(writefile, AUTO_FILE, "")
		end
	end

	local function fflagLoadOptions()
		local out = { PRIVATE_NAME }
		for _, n in ipairs(fflagList()) do
			if n ~= PRIVATE_NAME then table.insert(out, n) end
		end
		return out
	end
	local function cleanProfile(text)
		local t = trim(text)
		if t == "" then return nil end
		local _, _, clean = fflagPath(t)
		return clean
	end

	local fflagPanel, fflagBox, nameInput, configDrop
	if type(UI.CreateSidePanel) == "function" then
		fflagPanel = UI:CreateSidePanel({ Title = "Fast Flags", Width = 300, Editor = true, Closable = true, PinSide = "Left", DockPriority = 2 })
		if type(fflagPanel.AddTextArea) ~= "function" then
			pcall(function() fflagPanel.Root:Destroy() end)
			fflagPanel = nil
		end
	end

	if fflagPanel then
		fflagPanel._homeTab = Settings

		fflagBox = fflagPanel:AddTextArea({
			Height = 200, Monospace = true,
			Placeholder = '{\n  "DFIntTaskSchedulerTargetFps": 240\n}',
		})

		if type(fflagPanel.BeginJoin) == "function" then fflagPanel:BeginJoin() end
		nameInput = fflagPanel:AddInput({
			Name = "Config Save",
			Placeholder = "Enter Name...",
			Default = "",
			Buttons = {
				{ Icon = ICON_SAVE, Glyph = "S", Callback = function(text)
					local name = cleanProfile(text)
					if not name then UI:Notify("Fast Flags", "Enter a name first.", 4); return end
					if name == PRIVATE_NAME then UI:Notify("Fast Flags", "'Private Flags' is built in - use another name.", 5); return end
					local ok, msg = fflagSave(name, fflagBox:GetText())
					UI:Notify("Fast Flags", ok and ("Saved '" .. name .. "'") or msg, 4)
					if ok then
						configDrop:SetOptions(fflagLoadOptions())
						configDrop:SetSelected(name)
					end
				end },
				{ Icon = ICON_DELETE, Glyph = "X", Callback = function(text)
					local name = cleanProfile(text)
					if not name then UI:Notify("Fast Flags", "Enter a name first.", 4); return end
					if name == PRIVATE_NAME then UI:Notify("Fast Flags", "'Private Flags' is built in - use another name.", 5); return end
					local ok, msg = fflagDelete(name)
					UI:Notify("Fast Flags", ok and ("Deleted '" .. name .. "'") or msg, 4)
					if ok then configDrop:SetOptions(fflagLoadOptions()) end
				end },
			},
		})

		local autoName = readAuto()
		if autoName and autoName ~= PRIVATE_NAME then
			local exists = false
			for _, n in ipairs(fflagList()) do if n == autoName then exists = true break end end
			if not exists then autoName = nil end
		end
		local startName = autoName or PRIVATE_NAME

		configDrop = fflagPanel:AddDropdown({
			Name = "Load Config",
			Options = fflagLoadOptions(),
			Default = startName,
			Chip = "AUTO",
			ChipDefault = autoName == startName,
			ChipCallback = function(on)
				local sel = configDrop and configDrop:Get()
				if not sel then return end
				if on then
					autoName = sel
					writeAuto(sel)
					UI:Notify("Fast Flags", "'" .. sel .. "' will auto-apply on every launch.", 4)
				else
					if autoName == sel then autoName = nil; clearAuto() end
					UI:Notify("Fast Flags", "Auto-apply turned off.", 3)
				end
			end,
			Callback = function(v)
				if v == NONE_FF then return end
				if configDrop and configDrop.Chip then configDrop.Chip:Set(autoName == v, true) end
				loadProfile(v, function(ok, data)
					if UI.Destroyed then return end
					if ok then
						fflagBox:SetText(data)
						nameInput:SetText(v == PRIVATE_NAME and "" or v)
						UI:Notify("Fast Flags", "Loaded '" .. v .. "'", 4)
					else
						UI:Notify("Fast Flags", data, 4)
					end
				end)
			end,
		})
		if type(fflagPanel.EndJoin) == "function" then fflagPanel:EndJoin() end

		local grid = fflagPanel:AddGrid(2)
		grid:AddButton({ Name = "Apply", Color = Color3.fromRGB(40, 90, 70), Callback = function()
			local ok, msg = fflagApply(fflagBox:GetText())
			UI:Notify("Fast Flags", msg, 5)
		end })
		grid:AddButton({ Name = "Clear", Callback = function() fflagBox:SetText("") end })

		task.spawn(function()
			loadProfile(startName, function(ok, data)
				if UI.Destroyed then return end
				if not ok then UI:Notify("Fast Flags", tostring(data), 5); return end
				fflagBox:SetText(data)
				if autoName then
					local aok, msg = fflagApply(data)
					UI:Notify("Fast Flags", "Auto: " .. tostring(msg) .. " ('" .. autoName .. "')", 6)
				end
			end)
		end)
	end

	openFFlagEditor = function()
		if not fflagPanel then UI:Notify("Fast Flags", "Editor needs the updated UI library", 5); return end
		if configDrop then configDrop:SetOptions(fflagLoadOptions()) end
		fflagPanel:Toggle()
	end
end

Settings:AddSection("Configs")
do
	local HttpService = game:GetService("HttpService")
	local configDropdown
	local NONE = "No saved configs"
	local nameInputRef
	local autoSaveOn, autoSaveToken, autoSaveBlockUntil, lastConfigName = false, 0, 0, nil

	local function configFile(name) return pyraConfigPath("cfg_" .. name .. ".json") end

	local function listConfigs()
		local names = {}
		if hasFiles and type(listfiles) == "function" then
			local ok, files = pcall(listfiles, PYRA_CONFIG_DIR)
			if ok and type(files) == "table" then
				for _, path in ipairs(files) do
					local n = tostring(path):match("cfg_(.+)%.json$")
					if n then table.insert(names, n) end
				end
			end
		end
		table.sort(names)
		return names
	end
	local function loadOptions()
		local l = listConfigs()
		if #l == 0 then return { NONE } end
		return l
	end
	local function cleanName(text)
		local t = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		t = t:gsub('[<>:"/\\|%?%*%c]', "_"):sub(1, 64)
		if t == "" then return nil end
		return t
	end

	local function saveConfig(name, silent)
		if not hasFiles then
			if not silent then UI:Notify("Configs", "No file access in this executor.", 4) end
			return
		end
		if not name or name == "" then
			if not silent then UI:Notify("Configs", "Enter a name first.", 4) end
			return
		end
		ensurePyraFolders()
		local data = UI:GetConfig()
		local ok = pcall(function() writefile(configFile(name), HttpService:JSONEncode(data)) end)
		if not silent then UI:Notify("Configs", ok and ("Saved '" .. name .. "'.") or "Save failed.", 4) end
		if ok and configDropdown and configDropdown.SetOptions then
			configDropdown:SetOptions(loadOptions())
			if configDropdown.SetSelected then configDropdown:SetSelected(name) end
		end
	end

	local function loadConfig(name)
		if not hasFiles then UI:Notify("Configs", "No file access in this executor.", 4); return end
		if not name or name == "" then return end
		local ok, raw = pcall(function()
			if isfile(configFile(name)) then return readfile(configFile(name)) end
		end)
		if not (ok and raw) then UI:Notify("Configs", "No config named '" .. name .. "'.", 4); return end
		local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
		if not ok2 then UI:Notify("Configs", "Config file is corrupt.", 4); return end
		autoSaveBlockUntil = os.clock() + 1.5
		lastConfigName = name
		UI:SetConfig(data)
		UI:Notify("Configs", "Loaded '" .. name .. "'.", 4)
	end

	local function deleteConfig(name)
		if not hasFiles or type(delfile) ~= "function" then return end
		if not name or name == "" then UI:Notify("Configs", "Enter a name first.", 4); return end
		pcall(function() if isfile(configFile(name)) then delfile(configFile(name)) end end)
		UI:Notify("Configs", "Deleted '" .. name .. "'.", 4)
		if configDropdown and configDropdown.SetOptions then configDropdown:SetOptions(loadOptions()) end
	end

	local function scheduleAutoSave()
		if not autoSaveOn or UI.Destroyed then return end
		autoSaveToken = autoSaveToken + 1
		local token = autoSaveToken
		task.delay(0.8, function()
			if token ~= autoSaveToken or not autoSaveOn or UI.Destroyed then return end
			local typed = cleanName(nameInputRef and nameInputRef:Get())
			local name = typed or lastConfigName or "AutoSave"
			lastConfigName = name
			if not typed and nameInputRef then
				nameInputRef:Set(name)
				UI:Notify("Auto Save", "Saving to '" .. name .. "'. Enter a name to change it.", 4)
			end
			saveConfig(name, true)
		end)
	end
	if type(UI.OnConfigChanged) == "function" then
		UI:OnConfigChanged(function()
			if os.clock() < autoSaveBlockUntil then return end
			scheduleAutoSave()
		end)
	end

	if type(UI.GetConfig) ~= "function" then
		Settings:AddButton({
			Name = "Configs",
			Description = "Requires the updated UI library.",
			Callback = function() UI:Notify("Configs", "Update the UI library to use configs.", 5) end,
		})
		Settings:AddButton({
			Name = "Fast Flags Editor",
			Callback = function() if openFFlagEditor then openFFlagEditor() end end,
		})
	else
		local cfgGroup = Settings:AddGroup({ Collapsible = false })
		local nameInput = cfgGroup:AddInput({
			Name = "Config Save",
			Placeholder = "Enter Name...",
			Default = "",
			Buttons = {
				{ Icon = ICON_SAVE,   Glyph = "S", Callback = function(text) saveConfig(cleanName(text)) end },
				{ Icon = ICON_DELETE, Glyph = "X", Callback = function(text) deleteConfig(cleanName(text)) end },
			},
		})
		nameInputRef = nameInput
		cfgGroup:AddToggle({
			Name = "Auto Save",
			Flag = "auto_save",
					Default = false,
			Callback = function(on)
				autoSaveOn = on
				if on then scheduleAutoSave() end
			end,
		})
		configDropdown = cfgGroup:AddDropdown({
			Name = "Load Config",
			Options = loadOptions(),
			AlwaysFire = true,
			Callback = function(v)
				if v == NONE then return end
				loadConfig(v)
				if nameInput then nameInput:Set(v) end
			end,
		})
		cfgGroup:AddButton({
			Name = "Fast Flags Editor",
			Callback = function() if openFFlagEditor then openFFlagEditor() end end,
		})
		if type(Library.BuildInlineButtons) ~= "function" then
			local fb = Settings:AddGroup({ Collapsible = false })
			fb:AddButton({ Name = "Save", Callback = function() saveConfig(cleanName(nameInput:Get())) end })
			fb:AddButton({ Name = "Delete", Callback = function() deleteConfig(cleanName(nameInput:Get())) end })
		end
	end
end

Settings:AddSection("Interface")
local interfaceGroup = Settings:AddGroup({ Collapsible = false })
local uiScaleSlider = interfaceGroup:AddSlider({
	Name = "UI Scale",
	Flag = "ui_scale",
	Min = 70, Max = 150, Default = 125, Suffix = "%",
	Callback = function(value) UI:SetScaleMultiplier(value / 100) end,
})
UI:SetScaleMultiplier(1.25)
local _isTouchDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
interfaceGroup:AddToggle({
	Name = "Mobile UI",
	Flag = "mobile_ui",
	Description = "On-screen buttons for touch players",
	Default = _isTouchDevice,
	Callback = function(on) UI:SetMobileMode(on) end,
})
if _isTouchDevice then UI:SetMobileMode(true) end
interfaceGroup:AddKeybind({
	Name = "Toggle Key",
	Flag = "toggle_key",
	Default = UI.ToggleKey,
	AllowNone = false,
	ChangedCallback = function(key) UI:SetToggleKey(key) end,
})
interfaceGroup:AddButton({
	Name = "Hide Interface",
	Callback = function() UI:Hide() end,
})
interfaceGroup:AddButton({
	Name = "Destroy UI",
	Callback = function() UI:Destroy() end,
})

local function unloadPyra()
	for _, c in ipairs(_pyraConns) do pcall(function() c:Disconnect() end) end
	table.clear(_pyraConns)
end

UI:OnDestroy(function()
	pcall(unloadPyra)
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
pcall(startBallTrailLoop)

task.delay(3.2, function()
	if UI.Destroyed then return end
	UI:Notify("PYRA loaded", "Press " .. UI.ToggleKey.Name .. " to toggle the interface.", 5)
end)
end

-- ===== EXTRA =====
do
local player = Players.LocalPlayer
local LocalPlayer = player
local _pyraConns = {}
local function trackConn(conn)
	_pyraConns[#_pyraConns + 1] = conn
	return conn
end
local function _hashName(suffix)
	return "Pyra" .. (suffix or "")
end
local ABILITY_BB = "AbilityBillboard"
local NAME_BLOOM = "PYRA_Bloom"
local NAME_RAYS = "PYRA_SunRays"
local NAME_RTCC = "PYRA_RTCC"
local NAME_FDCC = "PYRA_FullDarkCC"

local abilityESPConnection, abilityESPEnabled, raytracingEnabled

local PYRA_LIB_URL = "https://raw.githubusercontent.com/SwipeCard/PyraUI/main/PyraUI_Library.lua"


local Extra = _tabs.Extra

local _ballCache = {}
local _ballCacheConns = {}

local function _rebuildList(entry)
    local list, n = {}, 0
    for ball in pairs(entry.set) do
        if ball.Parent then
            n = n + 1; list[n] = ball
        else
            entry.set[ball] = nil
            if entry.attrConns[ball] then entry.attrConns[ball]:Disconnect(); entry.attrConns[ball] = nil end
        end
    end
    entry.list = list; entry.dirty = false
end

local function _attachBall(entry, ball)
    if not ball:IsA("BasePart") then return end
    if entry.attrConns[ball] then return end
    if ball:GetAttribute("realBall") then entry.set[ball] = true; entry.dirty = true end
    entry.attrConns[ball] = ball:GetAttributeChangedSignal("realBall"):Connect(function()
        if ball:GetAttribute("realBall") then
            if not entry.set[ball] then entry.set[ball] = true; entry.dirty = true end
        else
            if entry.set[ball] then entry.set[ball] = nil; entry.dirty = true end
        end
    end)
end

local function _detachBall(entry, ball)
    if entry.set[ball] then entry.set[ball] = nil; entry.dirty = true end
    local c = entry.attrConns[ball]
    if c then c:Disconnect(); entry.attrConns[ball] = nil end
end

local function _bindFolder(folder)
    if _ballCache[folder] then return _ballCache[folder] end
    local entry = { set = {}, list = {}, dirty = false, attrConns = {} }
    _ballCache[folder] = entry
    _ballCacheConns[folder] = {
        trackConn(folder.ChildAdded:Connect(function(ch) _attachBall(entry, ch) end)),
        trackConn(folder.ChildRemoved:Connect(function(ch) _detachBall(entry, ch) end)),
    }
    for _, ch in ipairs(folder:GetChildren()) do _attachBall(entry, ch) end
    _rebuildList(entry)
    return entry
end

local function realBallsIn(folder)
    if not folder then return nil end
    local entry = _ballCache[folder] or _bindFolder(folder)
    if entry.dirty then _rebuildList(entry) end
    return entry.list
end

local function activeBallFolder()
    local ws = game:GetService("Workspace")
    local dead = ws:FindFirstChild("Dead")
    local me = game:GetService("Players").LocalPlayer
    if dead and me and dead:FindFirstChild(me.Name) then
        return ws:FindFirstChild("TrainingBalls")
    end
    return ws:FindFirstChild("Balls")
end

local function firstRealBall()
    local list = realBallsIn(activeBallFolder())
    return list and list[1] or nil
end

task.spawn(function()
    local ws = game:GetService("Workspace")
    local b = ws:FindFirstChild("Balls") or ws:WaitForChild("Balls", 10)
    if b then _bindFolder(b) end
    local tb = ws:FindFirstChild("TrainingBalls")
    if tb then _bindFolder(tb) end
    trackConn(ws.ChildAdded:Connect(function(ch)
        if ch.Name == "Balls" or ch.Name == "TrainingBalls" then _bindFolder(ch) end
    end))
end)


local _NO_BALLS = {}
local function ballsNow()
    local f = Workspace:FindFirstChild("Balls")
    if not f then return _NO_BALLS end
    return f:GetChildren()
end

local _abilitiesModule = nil
do
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local mod = shared and shared:FindFirstChild("Abilities")
    if mod then
        local ok, result = pcall(require, mod)
        if ok and type(result) == "table" and result.getAbilityCooldown then
            _abilitiesModule = result
        end
    end
end
local function _serverNow()
    local ok, t = pcall(function() return Workspace:GetServerTimeNow() end)
    if ok and type(t) == "number" then return t end
    return tick()
end
local function _getAbilityCooldown(plr, abilityName)
    if not _abilitiesModule then return nil end
    local ok, cd = pcall(_abilitiesModule.getAbilityCooldown, plr, abilityName)
    if ok and type(cd) == "number" then return cd end
    return nil
end
local _abilityCooldownEnd = {}

local function createAbilityBillboard(characterModel)
    if not characterModel or characterModel.Name == player.Name then return end
    local head = characterModel:WaitForChild("Head", 3)
    if not head then return end
    local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return end
    local plr = Players:FindFirstChild(characterModel.Name)
    if not plr or plr == player then return end
    local oldBB = head:FindFirstChild(ABILITY_BB)
    if oldBB then oldBB:Destroy() end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = ABILITY_BB
    billboard.Size = UDim2.fromOffset(170, 40)
    billboard.StudsOffset = Vector3.new(0, 3.7, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 300
    billboard.Parent = head

    local COL_TEXT = Color3.fromRGB(240, 240, 245)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.AnchorPoint = Vector2.new(0.5, 0)
    nameLabel.Position = UDim2.new(0.5, 0, 0, 4)
    nameLabel.Size = UDim2.new(1, -12, 0, 14)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 11
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.TextColor3 = COL_TEXT
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Text = plr.DisplayName
    nameLabel.Parent = billboard

    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 1)
    label.Position = UDim2.new(0.5, 0, 0, 3)
    label.Size = UDim2.new(1, -12, 0, 15)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextColor3 = COL_TEXT
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.5
    label.Parent = billboard

    local function render()
        local ability = plr:GetAttribute("EquippedAbility")
        if not (ability and ability ~= "") then
            label.Text = "No Ability"
            return
        end
        local char = plr.Character
        local active = char and char:GetAttribute("AbilityActive")
        local status
        if active then
            status = "ACTIVE"
        else
            local cdEnd = _abilityCooldownEnd[plr]
            local remaining = cdEnd and (cdEnd - _serverNow()) or 0
            if remaining and remaining > 0.05 then
                status = string.format("%.1fs", remaining)
            else
                _abilityCooldownEnd[plr] = nil
                status = "Ready"
            end
        end
        label.Text = tostring(ability) .. "  |  " .. status
    end
    render()

    local bbConns = {}
    local function cleanup()
        for _, c in ipairs(bbConns) do pcall(function() c:Disconnect() end) end
        table.clear(bbConns)
    end

    if humanoid then
        bbConns[#bbConns+1] = humanoid.Died:Connect(function() if billboard and billboard.Parent then billboard:Destroy() end end)
    end
    bbConns[#bbConns+1] = plr:GetAttributeChangedSignal("EquippedAbility"):Connect(function()
        if label and label.Parent then render() end
    end)
    bbConns[#bbConns+1] = characterModel:GetAttributeChangedSignal("AbilityActive"):Connect(function()
        if characterModel:GetAttribute("AbilityActive") then
            local ability = plr:GetAttribute("EquippedAbility")
            if ability and ability ~= "" then
                local total = _getAbilityCooldown(plr, ability)
                if total and total > 0 then
                    _abilityCooldownEnd[plr] = _serverNow() + total
                end
            end
        end
        if label and label.Parent then render() end
    end)
    bbConns[#bbConns+1] = characterModel.AncestryChanged:Connect(function(_, parent)
        if not parent and billboard and billboard.Parent then billboard:Destroy() end
    end)
    local acc = 0
    bbConns[#bbConns+1] = RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        if label and label.Parent then render() end
    end)
    bbConns[#bbConns+1] = billboard.Destroying:Connect(cleanup)
end

local function startAbilityESP()
    if abilityESPConnection then abilityESPConnection:Disconnect() end
    local aliveFolder = Workspace:WaitForChild("Alive")
    for _, characterModel in ipairs(aliveFolder:GetChildren()) do createAbilityBillboard(characterModel) end
    abilityESPConnection = aliveFolder.ChildAdded:Connect(function(characterModel) task.wait(0.6) createAbilityBillboard(characterModel) end)
end

local function stopAbilityESP()
    if abilityESPConnection then abilityESPConnection:Disconnect() abilityESPConnection = nil end
    table.clear(_abilityCooldownEnd)
    local aliveFolder = Workspace:FindFirstChild("Alive")
    if aliveFolder then
        for _, characterModel in ipairs(aliveFolder:GetChildren()) do
            local head = characterModel:FindFirstChild("Head")
            local bb = head and head:FindFirstChild(ABILITY_BB)
            if bb then bb:Destroy() end
        end
    end
end

local noRenderEnabled = false
local noRenderConnection = nil
local NO_RENDER_KEEP = {
	"BallEmit", "Upgrade", "Arch2", "MaxHook", "Wave", "Totem", "TotemRange",
	"InfinityFX", "maxTransmission", "transmissionpart", "Tornado", "Barrier",
	"GUARDIAN_DRAGON", "DRAGON_POSITIONER", "SpiritDeflect", "Vanity", "dash",
	"Summon", "MaxBlink",
}

local function startNoRender()
	if noRenderConnection then noRenderConnection:Disconnect() noRenderConnection = nil end
	local Debris = game:GetService("Debris")
	local Runtime = Workspace:FindFirstChild("Runtime") or Workspace:WaitForChild("Runtime", 5)
	if not Runtime or not noRenderEnabled then return end
	noRenderConnection = Runtime.ChildAdded:Connect(function(child)
		if not noRenderEnabled then return end
		local name = child.Name
		if name:find("PortalFor_") or name:find("WaypointFor_") then return end
		if table.find(NO_RENDER_KEEP, name) then return end
		Debris:AddItem(child, 0)
	end)
end

local function stopNoRender()
	noRenderEnabled = false
	if noRenderConnection then noRenderConnection:Disconnect() noRenderConnection = nil end
end

local RT_NAMES = { NAME_BLOOM, "PYRA_DOF", NAME_RAYS, NAME_RTCC }
local rtOriginal = nil

local function setRaytracing(enabled)
    local Lighting = game:GetService("Lighting")
    for _, v in ipairs(Lighting:GetChildren()) do
        if table.find(RT_NAMES, v.Name) then v:Destroy() end
    end

    if enabled then
        if not rtOriginal then
            pcall(function()
                rtOriginal = {
                    diffuse = Lighting.EnvironmentDiffuseScale,
                    specular = Lighting.EnvironmentSpecularScale,
                    softness = Lighting.ShadowSoftness,
                }
            end)
        end

        local bloom = Instance.new("BloomEffect")
        bloom.Name = NAME_BLOOM
        bloom.Intensity = 0.7
        bloom.Size = 32
        bloom.Threshold = 0.82
        bloom.Parent = Lighting

        local rays = Instance.new("SunRaysEffect")
        rays.Name = NAME_RAYS
        rays.Intensity = 0.08
        rays.Spread = 0.7
        rays.Parent = Lighting

        local cc = Instance.new("ColorCorrectionEffect")
        cc.Name = NAME_RTCC
        cc.Brightness = 0.02
        cc.Contrast = 0.14
        cc.Saturation = 0.2
        cc.TintColor = Color3.fromRGB(255, 250, 244)
        cc.Parent = Lighting

        pcall(function()
            Lighting.EnvironmentDiffuseScale = 1
            Lighting.EnvironmentSpecularScale = 1
            Lighting.ShadowSoftness = 0.12
        end)
    elseif rtOriginal then
        local o = rtOriginal
        rtOriginal = nil
        pcall(function()
            Lighting.EnvironmentDiffuseScale = o.diffuse
            Lighting.EnvironmentSpecularScale = o.specular
            Lighting.ShadowSoftness = o.softness
        end)
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
    local cc = Lighting:FindFirstChild(NAME_FDCC)
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
        local cc = Lighting:FindFirstChild(NAME_FDCC)
        if not cc then cc = Instance.new("ColorCorrectionEffect"); cc.Name = NAME_FDCC; cc.Parent = Lighting end
        cc.Enabled = true; cc.Brightness = 0; cc.Contrast = 0.08; cc.Saturation = 0.15
    else
        setNormalLighting()
    end
    _settingLighting = false
end

trackConn(RunService.Heartbeat:Connect(function()
    if fullbrightEnabled then
        local Lighting = game:GetService("Lighting")
        if Lighting.Brightness ~= 2 then setFullbright(true) end
    elseif fulldarkEnabled then
        local Lighting = game:GetService("Lighting")
        if Lighting.ClockTime ~= 0 then setFulldark(true) end
    end
end))

local function setFOV(value)
    local c = Workspace.CurrentCamera
    if c then c.FieldOfView = value end
end

Extra:AddSection("Display")
local displayGroup = Extra:AddGroup()
displayGroup:AddSlider({
	Name = "Field of View",
	Flag = "field_of_view",
	Min = 40, Max = 140, Increment = 1, Default = 70,
	Callback = function(v) setFOV(v) end,
})
displayGroup:AddToggle({
	Name = "Ability ESP",
	Flag = "ability_esp",
	Default = false,
	Callback = function(s)
		abilityESPEnabled = s
		if s then startAbilityESP() else stopAbilityESP() end
	end,
})

Extra:AddSection("Player")
do
	local moveEnabled, moveSpeed = false, 25
	local antiSlow = false
	local orbitEnabled, orbitDistance, orbitHeight, orbitSpeed = false, 35, 0, 2.4
	local orbitAngle = 0

	local function realBall()
		return firstRealBall()
	end
	local function myAliveChar()
		local alive = Workspace:FindFirstChild("Alive")
		return alive and alive:FindFirstChild(player.Name) or nil
	end

	local playerGroup = Extra:AddGroup()
	local function subSection(group)
		if group.AddCollapsible then return group:AddCollapsible({ DefaultExpanded = false }) end
		return Extra:AddGroup({ Collapsible = true, DefaultExpanded = false })
	end

	local speedSection = subSection(playerGroup)
	speedSection:AddToggle({
		Name = "Change Speed",
		Flag = "speed_boost",
		Default = false,
		Callback = function(s)
			moveEnabled = s
			speedSection:SetExpanded(s)
		end,
	})
	speedSection.Body:AddSlider({
		Name = "Speed Boost",
		Flag = "boost_power",
		Min = 0, Max = 100, Increment = 1, Default = 25,
		Callback = function(v) moveSpeed = v end,
	})
	playerGroup:AddToggle({
		Name = "Anti-Slow",
		Flag = "anti_slow",
		Default = false,
		Callback = function(s) antiSlow = s end,
	})
	local orbitSection = subSection(playerGroup)
	orbitSection:AddToggle({
		Name = "Orbit Around Ball",
		Flag = "orbit_around_ball",
		Default = false,
		Callback = function(s)
			orbitEnabled = s
			orbitSection:SetExpanded(s)
			if not s then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then hrp.AssemblyAngularVelocity = Vector3.zero end
			end
		end,
	})
	orbitSection.Body:AddSlider({
		Name = "Orbit Distance",
		Flag = "orbit_distance",
		Min = 0, Max = 200, Increment = 1, Default = 35,
		Callback = function(v) orbitDistance = v end,
	})
	orbitSection.Body:AddSlider({
		Name = "Orbit Height",
		Flag = "orbit_height",
		Min = -100, Max = 200, Increment = 1, Default = 0,
		Callback = function(v) orbitHeight = v end,
	})
	orbitSection.Body:AddSlider({
		Name = "Orbit Speed",
		Flag = "orbit_speed",
		Min = 1, Max = 100, Increment = 1, Default = 2,
		Callback = function(v) orbitSpeed = math.max(0.1, v) end,
	})

	do
		local avatarUserId = nil

		local function weldAccessory(accessory, parent)
			local handle = accessory:FindFirstChild("Handle")
			if not handle then return end
			local attach = handle:FindFirstChildOfClass("Attachment")
			if not attach then return end
			local target = parent:FindFirstChild(attach.Name, true)
			if not target then return end
			local weld = Instance.new("Weld")
			weld.Name = "AccessoryWeld"
			weld.Part0 = handle
			weld.Part1 = target.Parent
			weld.C0 = attach.CFrame
			weld.C1 = target.CFrame
			weld.Parent = handle
			handle.Anchored = false
		end

		local function meshIdOf(part)
			if part:IsA("MeshPart") then return part.MeshId end
			local sm = part:FindFirstChildOfClass("SpecialMesh")
			return sm and sm.MeshId or ""
		end

		local function copyAttachments(from, to)
			for _, child in ipairs(from:GetChildren()) do
				if child:IsA("Attachment") then
					local existing = to:FindFirstChild(child.Name)
					if existing then
						existing.CFrame = child.CFrame
					else
						child:Clone().Parent = to
					end
				end
			end
		end

		local function applyAvatar(charModel)
			if not charModel or not avatarUserId then return end
			local humanoid = charModel:FindFirstChildOfClass("Humanoid") or charModel:WaitForChild("Humanoid", 3)
			if not humanoid then return end
			if charModel:GetAttribute("PyraAvatarApplied") == avatarUserId then return end
			charModel:SetAttribute("PyraAvatarApplied", avatarUserId)

			local ok, desc = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(avatarUserId)
			end)
			if not ok or not desc then charModel:SetAttribute("PyraAvatarApplied", nil) return end

			local equippedSword = player:GetAttribute("CurrentlyEquippedSword")
			for _, v in ipairs(charModel:GetChildren()) do
				if v:IsA("Accessory") then
					if v.Name ~= equippedSword then v:Destroy() end
				elseif v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
					v:Destroy()
				end
			end

			local ok2, model = pcall(function()
				return Players:CreateHumanoidModelFromDescription(desc, humanoid.RigType)
			end)
			if not ok2 or not model then charModel:SetAttribute("PyraAvatarApplied", nil) return end

			for _, v in ipairs(model:GetChildren()) do
				if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
					local part = charModel:FindFirstChild(v.Name)
					if part and meshIdOf(v) ~= meshIdOf(part) then
						local oldSM = part:FindFirstChildOfClass("SpecialMesh")
						if oldSM then oldSM:Destroy() end
						local newSM = v:FindFirstChildOfClass("SpecialMesh")
						if newSM then newSM:Clone().Parent = part end
						if v:IsA("MeshPart") and part:IsA("MeshPart") then
							part.MeshId = v.MeshId
							part.TextureID = v.TextureID
							copyAttachments(v, part)
						end
					end
				elseif v:IsA("CharacterMesh") then
					v:Clone().Parent = charModel
				end
			end

			for _, v in ipairs(model:GetChildren()) do
				if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then
					v:Clone().Parent = charModel
				elseif v:IsA("Accessory") then
					local clone = v:Clone()
					humanoid:AddAccessory(clone)
					weldAccessory(clone, charModel)
				end
			end

			local head = charModel:FindFirstChild("Head")
			local head2 = model:FindFirstChild("Head")
			if head and head2 then
				local d1 = head:FindFirstChildOfClass("Decal")
				local d2 = head2:FindFirstChildOfClass("Decal")
				if d2 then
					if d1 then d1.Texture = d2.Texture else d2:Clone().Parent = head end
				elseif d1 then d1:Destroy() end
			end

			model:Destroy()
		end

		table.insert(UI.Connections, player.CharacterAdded:Connect(function(c)
			if avatarUserId then task.wait(0.4) applyAvatar(c) end
		end))
		playerGroup:AddInput({
			Name = "Avatar Changer",
			Flag = "avatar_user",
			Placeholder = "UserID or username",
			Default = "",
			Callback = function(text)
				if not text or text == "" then
					avatarUserId = nil
					local c = player.Character
					if c then c:SetAttribute("PyraAvatarApplied", nil) end
					if UI.SetFooterAvatar then UI:SetFooterAvatar(nil) end
					return
				end
				local num = tonumber(text)
				if not num then
					local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(text) end)
					if ok then num = id end
				end
				if not num then UI:Notify("Avatar Changer", "Couldn't resolve that user.", 4) return end
				avatarUserId = num
				if UI.SetFooterAvatar then UI:SetFooterAvatar(num) end
				local c = player.Character
				if c then c:SetAttribute("PyraAvatarApplied", nil) task.spawn(applyAvatar, c) end
			end,
		})
	end

	do
		local _pcall, _type, _defer, _spawn, _insert, _tostring, _unpack = pcall, type, task.defer, task.spawn, table.insert, tostring, unpack
		local local_player = player
		local local_name = player.Name
		local replicated_storage = ReplicatedStorage
		local user_input_service = UserInputService
		local heartbeat = RunService.Heartbeat
		local http_service = game:GetService("HttpService")

		local config = {
			unlock_all = false,
			last_equipped_sword = "",
			last_equipped_explosion = "",
			favorite_swords = {},
			favorite_explosions = {},
			deleted_swords = {},
			deleted_explosions = {},
		}
		local UA_FILE = "Pyra_unlockall.json"
		_pcall(function()
			if isfile and readfile and isfile(UA_FILE) then
				local data = http_service:JSONDecode(readfile(UA_FILE))
				if _type(data) == "table" then
					for k, v in pairs(data) do
						if k ~= "unlock_all" and config[k] ~= nil then config[k] = v end
					end
				end
			end
		end)
		local cfg = {
			save = function()
				_pcall(function()
					if not writefile then return end
					local out = {}
					for k, v in pairs(config) do
						if k ~= "unlock_all" then out[k] = v end
					end
					writefile(UA_FILE, http_service:JSONEncode(out))
				end)
			end,
		}

		local unlockAllModule
		playerGroup:AddToggle({
			Name = "Unlock All Items",
			Flag = "unlock_all",
			Default = false,
			Callback = function(on)
				config.unlock_all = on
				if unlockAllModule then unlockAllModule:set_enabled(on) end
			end,
		})
		UI:OnDestroy(function()
			if unlockAllModule then _pcall(function() unlockAllModule:set_enabled(false) end) end
		end)

		task.spawn(function()
			local remotes = replicated_storage:WaitForChild('Remotes', 10)
			local native_sword_fx = {
				parry_connections = {},
				fire_sword_connections = {},
				play_parry = nil,
				sword_fn = nil,
			}

			if remotes and _type(getconnections) == 'function' then
				local parry_all = remotes:WaitForChild('ParrySuccessAll', 10)
				if parry_all then
					local ok, connections = _pcall(getconnections, parry_all.OnClientEvent)
					if ok and _type(connections) == 'table' then
						for _, connection in connections do
							local fn_ok, callback = _pcall(function()
								return connection.Function
							end)
							if fn_ok and _type(callback) == 'function' then
								_insert(native_sword_fx.parry_connections, connection)
								native_sword_fx.play_parry = callback
							end
						end
					end
				end
				local fire_sword = remotes:WaitForChild('FireSwordInfo', 10)
				if fire_sword then
					local ok, connections = _pcall(getconnections, fire_sword.OnClientEvent)
					if ok and _type(connections) == 'table' then
						for _, connection in connections do
							local fn_ok, callback = _pcall(function()
								return connection.Function
							end)
							if fn_ok and _type(callback) == 'function' then
								_insert(native_sword_fx.fire_sword_connections, connection)
								native_sword_fx.sword_fn = callback
							end
						end
					end
				end
			end

			local unlock_all = {
				enabled = config.unlock_all or false,
				ready = false,
				shop_controller = nil,
				shop_api = nil,
				shop = nil,
				swords = nil,
				sword_fn = native_sword_fx.sword_fn,
				selected_sword = nil,
				original_sword = nil,
				explosion_module = nil,
				explosion_original = nil,
				explosion_hooked = false,
				selected_explosion = nil,
				unlock_originals = setmetatable({}, { __mode = 'k' }),
				unlocked = {},
				shadow_connections = setmetatable({}, { __mode = 'k' }),
				page_connections = {},
				refresh_generation = {},
				modern_originals = setmetatable({}, { __mode = 'k' }),
				modern_tag = 'oxy_unlock_all',
				original_set_equipped = nil,
				original_buy_fns = {},
				parry_connections = native_sword_fx.parry_connections,
				fire_connections = native_sword_fx.fire_sword_connections,
				play_parry = native_sword_fx.play_parry,
				chroma_bound = false,
				character_connection = nil,
				added_connection = nil,
				sword_attr_connection = nil,
			}

			local function set_connection_enabled(connection, enabled)
				_pcall(function()
					if enabled then
						connection:Enable()
					else
						connection:Disable()
					end
				end)
			end

			function unlock_all:set_sword_override(enabled)
				for _, connection in self.parry_connections do
					set_connection_enabled(connection, not enabled)
				end
				for _, connection in self.fire_connections do
					set_connection_enabled(connection, not enabled)
				end
			end

			function unlock_all:apply_chroma(instance, model)
				local color_config = model.ColorConfig or model.TweenColorConfig
				if not color_config and (model.Name:find('Chroma') or model.Name:find('chroma')) then
					color_config = 'Chroma'
				end
				if color_config then
					instance:SetAttribute('ColorConfig', color_config)
					instance:AddTag('TweenColor')
				end
			end

			function unlock_all:slot_fav_visual(category, slot)
				if not slot or not slot:IsA('GuiObject') then
					return
				end
				local item_name = slot:GetAttribute('Name')
				if not item_name or item_name == '' then
					return
				end
				local is_fav = self:is_fav(category, item_name)
				local star = slot:FindFirstChild('Favorited')
				if star and star:IsA('ImageLabel') then
					star.Visible = is_fav
					if is_fav then
						star.Image = 'rbxassetid://15697987058'
					end
				end
				local shadow = slot:FindFirstChild('Shadow')
				if shadow and self.unlocked[category] then
					shadow.Enabled = false
				end
			end

			function unlock_all:native_fav_map()
				if self.native_map then
					return self.native_map
				end
				if not self.shop_controller or _type(self.shop_controller._inventoryPages) ~= 'table' then
					return nil
				end
				for _, page in self.shop_controller._inventoryPages do
					if _type(page) ~= 'table' or _type(page.MarkDirty) ~= 'function' then
						continue
					end
					local ok1, up1 = _pcall(debug.getupvalues, page.MarkDirty)
					if not ok1 or _type(up1) ~= 'table' then
						continue
					end
					for _, refresh_now in up1 do
						if _type(refresh_now) ~= 'function' then
							continue
						end
						local ok2, up2 = _pcall(debug.getupvalues, refresh_now)
						if not ok2 or _type(up2) ~= 'table' then
							continue
						end
						for _, update_sort in up2 do
							if _type(update_sort) ~= 'function' then
								continue
							end
							local ok3, up3 = _pcall(debug.getupvalues, update_sort)
							if not ok3 or _type(up3) ~= 'table' then
								continue
							end
							for _, fav_map in up3 do
								if _type(fav_map) == 'table' and fav_map.Sword ~= nil and fav_map.Explosion ~= nil and not fav_map._virtualItems then
									self.native_map = fav_map
									return fav_map
								end
							end
						end
					end
				end
				return nil
			end

			function unlock_all:sync_fav_map(category)
				local native_map = self:native_fav_map()
				if not native_map then
					return
				end
				local fav_table = native_map[category]
				if _type(fav_table) ~= 'table' then
					return
				end
				local saved_favs = category == 'Sword' and config.favorite_swords or (category == 'Explosion' and config.favorite_explosions) or {}
				for name in fav_table do
					if not saved_favs[name] then
						fav_table[name] = nil
					end
				end
				for name, is_fav in saved_favs do
					fav_table[name] = is_fav and true or nil
				end
			end

			function unlock_all:is_fav(category, name)
				if category == 'Sword' then
					return config.favorite_swords and config.favorite_swords[name] == true
				elseif category == 'Explosion' then
					return config.favorite_explosions and config.favorite_explosions[name] == true
				end
				return false
			end

			function unlock_all:is_deleted(category, name)
				if category == 'Sword' then
					return config.deleted_swords and config.deleted_swords[name] == true
				elseif category == 'Explosion' then
					return config.deleted_explosions and config.deleted_explosions[name] == true
				end
				return false
			end

			function unlock_all:refresh_shop_item(category, name, owned)
				local shop_list = self.shop_controller and self.shop_controller._virtualItems[category]
				local page = self.shop_controller and self.shop_controller._inventoryPages[category]
				if _type(shop_list) == 'table' then
					for _, value in shop_list do
						if value.Name ~= name then
							continue
						end
						value.Section = owned and 'Owned' or 'Unowned'
						if value.OwnsItem and _type(value.OwnsItem.Set) == 'function' then
							_pcall(value.OwnsItem.Set, value.OwnsItem, owned)
						end
						if not owned then
							value.IsFavorited = false
							value.Name_ = (value.Name_ or value.Name):gsub('^#', '')
							value.LayoutOrder = value.OriginalLayoutOrder or value.LayoutOrder or 0
						end
						if page and page.MarkDirty then
							page.MarkDirty(value, false, true)
						end
						break
					end
				end
				if page and page.MarkDirty then
					page.MarkDirty(nil, true, true)
				end
			end

			function unlock_all:delete_item(category, name)
				if category == 'Sword' then
					config.deleted_swords = config.deleted_swords or {}
					config.deleted_swords[name] = true
					if config.favorite_swords then
						config.favorite_swords[name] = nil
					end
					if self.selected_sword == name then
						self:restore_sword()
					end
				elseif category == 'Explosion' then
					config.deleted_explosions = config.deleted_explosions or {}
					config.deleted_explosions[name] = true
					if config.favorite_explosions then
						config.favorite_explosions[name] = nil
					end
					if self.selected_explosion == name then
						self.selected_explosion = nil
					end
				end
				_pcall(cfg.save)
				self:sync_fav_map(category)
				if self.shop_controller then
					self:refresh_shop_item(category, name, false)
				end
				self:refresh_selected()
			end

			function unlock_all:undelete_item(category, name)
				if category == 'Sword' and config.deleted_swords then
					config.deleted_swords[name] = nil
				elseif category == 'Explosion' and config.deleted_explosions then
					config.deleted_explosions[name] = nil
				end
				_pcall(cfg.save)
				self:sync_fav_map(category)
				if self.shop_controller then
					self:refresh_shop_item(category, name, true)
				end
				self:refresh_selected()
			end

			function unlock_all:toggle_fav(category, name)
				if self:is_deleted(category, name) then
					return
				end
				if category == 'Sword' then
					config.favorite_swords = config.favorite_swords or {}
					config.favorite_swords[name] = config.favorite_swords[name] and nil or true
				elseif category == 'Explosion' then
					config.favorite_explosions = config.favorite_explosions or {}
					config.favorite_explosions[name] = config.favorite_explosions[name] and nil or true
				end
				_pcall(cfg.save)
				self:sync_fav_map(category)
				local shop_list = self.shop_controller and self.shop_controller._virtualItems and self.shop_controller._virtualItems[category]
				local page = self.shop_controller and self.shop_controller._inventoryPages and self.shop_controller._inventoryPages[category]
				local is_fav = self:is_fav(category, name)
				if _type(shop_list) == 'table' then
					for _, value in shop_list do
						if value.Name ~= name then
							continue
						end
						value.IsFavorited = is_fav
						if value.OwnsItem and _type(value.OwnsItem.Set) == 'function' then
							_pcall(value.OwnsItem.Set, value.OwnsItem, true)
						end
						local original_order = value.OriginalLayoutOrder or value.LayoutOrder or 0
						value.OriginalLayoutOrder = original_order
						if is_fav then
							value.LayoutOrder = original_order - 1000
							value.Name_ = '#' .. (value.Name_ or value.Name):gsub('^#', '')
						else
							value.LayoutOrder = original_order
							value.Name_ = (value.Name_ or value.Name):gsub('^#', '')
						end
						break
					end
				end
				if page and page.MarkDirty then
					page.MarkDirty(nil, true, true)
				end
				self:refresh_selected()
			end

			function unlock_all:refresh_favs(category)
				if not self.shop_controller then
					return
				end
				self:sync_fav_map(category)
				local shop_list = self.shop_controller._virtualItems[category]
				local page = self.shop_controller._inventoryPages[category]
				if _type(shop_list) ~= 'table' then
					return
				end
				for _, value in shop_list do
					local is_fav = self:is_fav(category, value.Name)
					value.IsFavorited = is_fav
					if value.OwnsItem and _type(value.OwnsItem.Set) == 'function' then
						_pcall(value.OwnsItem.Set, value.OwnsItem, true)
					end
					local original_order = value.OriginalLayoutOrder or value.LayoutOrder or 0
					value.OriginalLayoutOrder = original_order
					if is_fav then
						value.LayoutOrder = original_order - 1000
						value.Name_ = '#' .. (value.Name_ or value.Name):gsub('^#', '')
					else
						value.LayoutOrder = original_order
						value.Name_ = (value.Name_ or value.Name):gsub('^#', '')
					end
				end
				if page and page.MarkDirty then
					page.MarkDirty(nil, true, true)
				end
			end

			function unlock_all:equip_sword(name, is_restore)
				if not self.swords then
					return false
				end
				if not is_restore and self:is_deleted('Sword', name) then
					self:undelete_item('Sword', name)
				end
				local model = self.swords:GetSword(name)
				if not model then
					return false
				end
				local character = local_player.Character
				if not character then
					return false
				end
				if not is_restore and not self.original_sword then
					self.original_sword = local_player:GetAttribute('CurrentlyEquippedSword') or character:GetAttribute('CurrentlyEquippedSword')
				end
				if is_restore then
					self.selected_sword = nil
				else
					self.selected_sword = model.Name
					config.last_equipped_sword = model.Name
					self:set_sword_override(true)
				end
				local_player:SetAttribute('CurrentlyEquippedSword', model.Name)
				character:SetAttribute('CurrentlyEquippedSword', model.Name)
				_pcall(function()
					local equip_to = self.swords.EquipSwordTo
					for index, value in debug.getupvalues(equip_to) do
						if value == true then
							debug.setupvalue(equip_to, index, false)
							break
						end
					end
				end)
				if not _pcall(function()
					self.swords:EquipSwordTo(character, model.Name)
				end) then
					return false
				end
				local instance = character:FindFirstChild(model.Name)
				if instance then
					self:apply_chroma(instance, model)
				end
				if self.sword_fn then
					_pcall(self.sword_fn, model.Name)
				end
				return true
			end

			function unlock_all:restore_sword()
				if self.original_sword and self.original_sword ~= '' then
					self:equip_sword(self.original_sword, true)
				else
					self.selected_sword = nil
				end
				self.original_sword = nil
				self:set_sword_override(false)
			end

			function unlock_all:ensure_explosion_wrap()
				if self.explosion_hooked or not self.explosion_module then
					return
				end
				self.explosion_hooked = true
				self.explosion_original = self.explosion_module.PlayExplosion
				self.explosion_module.PlayExplosion = function(controller, name, position, instance, character, attribution, kill)
					local explosion_name = name
					if unlock_all.enabled and unlock_all.selected_explosion and unlock_all.selected_explosion ~= '' and kill and attribution == local_player.Character then
						explosion_name = unlock_all.selected_explosion
					end
					return unlock_all.explosion_original(controller, explosion_name, position, instance, character, attribution, kill)
				end
			end

			function unlock_all:equip_explosion(name)
				if self:is_deleted('Explosion', name) then
					self:undelete_item('Explosion', name)
				end
				self.selected_explosion = name
				config.last_equipped_explosion = name
				self:ensure_explosion_wrap()
				return true
			end

			function unlock_all:bind_shadow(category, shadow)
				if self.shadow_connections[shadow] then
					return
				end
				local function update()
					if self.unlocked[category] and shadow.Parent and shadow.Enabled then
						shadow.Enabled = false
					end
				end
				self.shadow_connections[shadow] = shadow:GetPropertyChangedSignal('Enabled'):Connect(update)
				update()
			end

			function unlock_all:refresh_visuals(category)
				if not self.shop_controller then
					return
				end
				local page = self.shop_controller._inventoryPages[category]
				local shop_list = self.shop_controller._virtualItems[category]
				if not page or not page.Scroll or _type(shop_list) ~= 'table' then
					return
				end
				if not self.page_connections[category] and page.ScrollingFrame then
					self.page_connections[category] = page.ScrollingFrame.DescendantAdded:Connect(function(descendant)
						if descendant:IsA('GuiObject') then
							_defer(function()
								self:slot_fav_visual(category, descendant)
								local shadow = descendant:FindFirstChild('Shadow') or (descendant.Name == 'Shadow' and descendant)
								if shadow and self.unlocked[category] then
									self:bind_shadow(category, shadow)
								end
							end)
						end
					end)
				end
				_defer(function()
					for _, value in shop_list do
						local ok, slot = _pcall(page.Scroll.GetRenderedSlot, value)
						if ok and slot then
							self:slot_fav_visual(category, slot)
							local shadow = slot:FindFirstChild('Shadow')
							if shadow then
								if self.unlocked[category] then
									self:bind_shadow(category, shadow)
								else
									shadow.Enabled = not value.OwnsItem:Get()
								end
							end
						end
					end
				end)
			end

			function unlock_all:set_category_unlock(category, state)
				if not self.shop_controller then
					return
				end
				if state then
					self:sync_fav_map(category)
				end
				local shop_list = self.shop_controller._virtualItems[category]
				local page = self.shop_controller._inventoryPages[category]
				if _type(shop_list) ~= 'table' then
					return
				end
				if page and page.BeginBatch then
					page.BeginBatch()
				end
				if state then
					self.unlocked[category] = true
					local owned_names = {}
					for _, value in shop_list do
						if value.InventoryKey then
							owned_names[value.Name] = true
						end
					end
					for _, value in shop_list do
						local changed = false
						if not self.unlock_originals[value] then
							self.unlock_originals[value] = {
								Section = value.Section,
								ForceHide = value.ForceHide,
								OriginalLayoutOrder = value.OriginalLayoutOrder or value.LayoutOrder,
							}
						end
						local deleted = self:is_deleted(category, value.Name)
						local target_section = deleted and 'Unowned' or 'Owned'
						if value.Section ~= target_section then
							value.Section = target_section
							changed = true
						end
						if value.OwnsItem and _type(value.OwnsItem.Set) == 'function' then
							_pcall(value.OwnsItem.Set, value.OwnsItem, not deleted)
						end
						local is_fav = (not deleted) and self:is_fav(category, value.Name)
						value.IsFavorited = is_fav
						local original_order = value.OriginalLayoutOrder or value.LayoutOrder or 0
						value.OriginalLayoutOrder = original_order
						local target_order = original_order - (is_fav and 1000 or 0)
						if value.LayoutOrder ~= target_order then
							value.LayoutOrder = target_order
							changed = true
						end
						if is_fav then
							local desired = '#' .. (value.Name_ or value.Name):gsub('^#', '')
							if value.Name_ ~= desired then
								value.OriginalName_ = value.OriginalName_ or value.Name_
								value.Name_ = desired
								changed = true
							end
						else
							local desired = (value.Name_ or value.Name):gsub('^#', '')
							if value.Name_ ~= desired then
								value.Name_ = desired
								changed = true
							end
						end
						local target_hide = not value.InventoryKey and owned_names[value.Name] or false
						if value.ForceHide ~= target_hide then
							value.ForceHide = target_hide
							changed = true
						end
						if changed and page and page.MarkDirty then
							page.MarkDirty(value, false, true)
						end
					end
				else
					self.unlocked[category] = nil
					for _, value in shop_list do
						local original = self.unlock_originals[value]
						if original then
							local changed = false
							if value.Section ~= original.Section then
								value.Section = original.Section
								changed = true
							end
							if value.ForceHide ~= original.ForceHide then
								value.ForceHide = original.ForceHide
								changed = true
							end
							if changed and page and page.MarkDirty then
								page.MarkDirty(value, false, true)
							end
							self.unlock_originals[value] = nil
						end
					end
				end
				if page and page.MarkDirty then
					page.MarkDirty(nil, true, true)
				end
				if page and page.EndBatch then
					page.EndBatch()
				end
				self:refresh_visuals(category)
			end

			function unlock_all:expected_size(category)
				local count = 0
				if category == 'Sword' and self.swords then
					local ok, collection = _pcall(function()
						return self.swords:GetCollection()
					end)
					if ok and _type(collection) == 'table' then
						for _ in collection do
							count += 1
						end
					end
				elseif category == 'Explosion' then
					local misc = replicated_storage:FindFirstChild('Misc')
					local data_explosions = misc and misc:FindFirstChild('DataExplosions')
					if data_explosions then
						for _, explosion in data_explosions:GetChildren() do
							if not explosion:GetAttribute('Hidden') then
								count += 1
							end
						end
					end
				end
				return count
			end

			function unlock_all:schedule_refresh(category)
				self.refresh_generation[category] = (self.refresh_generation[category] or 0) + 1
				local generation = self.refresh_generation[category]
				if _type(self.shop_controller._loadInventoryPage) == 'function' then
					_pcall(self.shop_controller._loadInventoryPage, category)
				end
				_spawn(function()
					local expected = self:expected_size(category)
					local last_size = -1
					local stable = 0
					for _ = 1, 120 do
						heartbeat:Wait()
						if not self.enabled or not self.unlocked[category] or self.refresh_generation[category] ~= generation then
							return
						end
						local shop_list = self.shop_controller._virtualItems[category]
						local static_size = 0
						if _type(shop_list) == 'table' then
							for _, value in shop_list do
								if not value.InventoryKey then
									static_size += 1
								end
							end
						end
						if static_size == last_size and static_size > 0 then
							stable += 1
						else
							stable = 0
							last_size = static_size
						end
						if (expected > 0 and static_size >= expected) or (expected == 0 and stable >= 5) then
							heartbeat:Wait()
							self:set_category_unlock(category, true)
							return
						end
					end
					if self.enabled and self.unlocked[category] and self.refresh_generation[category] == generation then
						self:set_category_unlock(category, true)
					end
				end)
			end

			function unlock_all:refresh_selected()
				if not self.shop_controller or not self.shop then
					return
				end
				local selected = self.shop_controller._selectedItem
				if not selected then
					return
				end
				local buy_button = self.shop.Holder.InfoBG:FindFirstChild('BuyButton')
				local fav_button = self.shop.Holder:FindFirstChild('Favorite')
				local delete_button = self.shop.Holder.InfoBG:FindFirstChild('Delete')
				if self.enabled and self.unlocked[selected.type] and (selected.type == 'Sword' or selected.type == 'Explosion') then
					local virtual_item
					if self.shop_controller._virtualItems and self.shop_controller._virtualItems[selected.type] then
						virtual_item = self.shop_controller._virtualItems[selected.type][selected.key or selected.name]
					end
					if self:is_deleted(selected.type, selected.name) or (virtual_item and virtual_item.Section == 'Unowned') then
						if buy_button then
							buy_button.Visible = false
						end
						if fav_button then
							fav_button.Visible = false
						end
						if delete_button then
							delete_button.Visible = true
						end
					else
						if buy_button then
							buy_button.Visible = true
							if buy_button:FindFirstChild('PriceTag') and buy_button.PriceTag:FindFirstChild('TextLabel') then
								buy_button.PriceTag.TextLabel.Visible = true
								buy_button.PriceTag.TextLabel.Text = 'Equip'
							end
							if buy_button:FindFirstChild('PriceTag') and buy_button.PriceTag:FindFirstChild('Price') then
								buy_button.PriceTag.Price.Visible = false
							end
						end
						if fav_button then
							fav_button.Visible = true
							local is_fav = self:is_fav(selected.type, selected.name)
							fav_button.Image = is_fav and 'rbxassetid://15697987058' or 'rbxassetid://15697981750'
							fav_button.HoverImage = is_fav and 'rbxassetid://15697983062' or 'rbxassetid://15697987058'
						end
						if delete_button then
							delete_button.Visible = true
						end
					end
				end
			end

			function unlock_all:set_modern_unlock(category, state)
				local api = self.shop_api
				local owned_bases = api and api.OwnedBases and api.OwnedBases[category]
				if _type(owned_bases) ~= 'table' then
					return
				end
				for name, ownership in owned_bases do
					local owned_copies
					local parse_ok, item_key = _pcall(api.ParseItemKey, api, category, { Name = name })
					if parse_ok and item_key then
						local data_ok, item_data = _pcall(api.GetItemData, api, category, item_key)
						if data_ok and _type(item_data) == 'table' then
							owned_copies = item_data.OwnedCopies
						end
					end
					if state and owned_copies and _type(owned_copies.Get) == 'function' and _type(owned_copies.Set) == 'function' then
						if not self.modern_originals[owned_copies] then
							local get_ok, original_value = _pcall(owned_copies.Get, owned_copies)
							if get_ok then
								self.modern_originals[owned_copies] = { Value = original_value }
							end
						end
						local current_ok, current_value = _pcall(owned_copies.Get, owned_copies)
						if current_ok and (_type(current_value) ~= 'number' or current_value < 1) then
							_pcall(owned_copies.Set, owned_copies, 1)
						end
					end
					if ownership and _type(ownership.SetTag) == 'function' then
						_pcall(ownership.SetTag, ownership, self.modern_tag, state and true or nil)
					end
					if not state and owned_copies then
						local original = self.modern_originals[owned_copies]
						if original and _type(owned_copies.Set) == 'function' then
							local actually_owned = false
							local ownership_state = ownership and ownership.State
							if ownership_state and _type(ownership_state.Get) == 'function' then
								local state_ok, state_value = _pcall(ownership_state.Get, ownership_state)
								actually_owned = state_ok and state_value == true
							end
							if not actually_owned then
								_pcall(owned_copies.Set, owned_copies, original.Value)
							end
							self.modern_originals[owned_copies] = nil
						end
					end
				end
			end

			function unlock_all:hook_modern_shop()
				local api = self.shop_api
				if not api or self.original_set_equipped then
					return
				end
				if _type(api.SetEquipped) ~= 'function' then
					return
				end
				self.original_set_equipped = api.SetEquipped
				api.SetEquipped = function(controller, ...)
					local args = { ... }
					local item_type = args[1]
					local item_name = args[2]
					if _type(item_type) == 'table' then
						item_name = item_type.Name
						item_type = item_type.ItemType
					elseif _type(item_name) == 'table' then
						item_name = item_name.Name
					end
					local owned_bases = api.OwnedBases
					local category_bases = _type(owned_bases) == 'table' and owned_bases[item_type]
					local is_known = _type(category_bases) == 'table' and category_bases[item_name] ~= nil
					if unlock_all.enabled and (is_known or item_type == 'Sword' or item_type == 'Explosion') then
						if (item_type == 'Sword' or _tostring(item_type):lower():find('sword')) and unlock_all:equip_sword(item_name, false) then
							return true
						elseif item_type == 'Explosion' or _tostring(item_type):lower():find('explosion') then
							return unlock_all:equip_explosion(item_name)
						end
					end
					return unlock_all.original_set_equipped(controller, _unpack(args))
				end
			end

			function unlock_all:hook_shop()
				local player_gui = local_player:WaitForChild('PlayerGui')
				local shop = player_gui:FindFirstChild('Shop')
				local holder = shop and shop:FindFirstChild('Holder')
				local info_bg = holder and holder:FindFirstChild('InfoBG')
				local buy_button = info_bg and info_bg:FindFirstChild('BuyButton')
				if not shop or not buy_button then
					return false
				end
				self.shop = shop
				for _, connection in getconnections(buy_button.Activated) do
					if connection and connection.Function then
						_insert(self.original_buy_fns, connection.Function)
						connection:Disable()
					end
				end
				local fav_button = holder and holder:FindFirstChild('Favorite')
				if fav_button then
					for _, connection in getconnections(fav_button.Activated) do
						if connection and connection.Function then
							connection:Disable()
						end
					end
					fav_button.Activated:Connect(function()
						local selected = self.shop_controller and self.shop_controller._selectedItem
						if selected and self.enabled and (selected.type == 'Sword' or selected.type == 'Explosion') then
							self:toggle_fav(selected.type, selected.name)
						end
					end)
				end
				local delete_button = info_bg and info_bg:FindFirstChild('Delete')
				if delete_button then
					for _, connection in getconnections(delete_button.Activated) do
						if connection and connection.Function then
							connection:Disable()
						end
					end
					delete_button.Activated:Connect(function()
						local selected = self.shop_controller and self.shop_controller._selectedItem
						if not selected or not self.enabled or (selected.type ~= 'Sword' and selected.type ~= 'Explosion') then
							return
						end
						if self:is_deleted(selected.type, selected.name) then
							self:undelete_item(selected.type, selected.name)
						else
							self:delete_item(selected.type, selected.name)
						end
					end)
				end
				local gui_service = game:GetService('GuiService')
				gui_service:GetPropertyChangedSignal('SelectedObject'):Connect(function()
					if not self.enabled or not self.shop or not self.shop.Enabled then
						return
					end
					_defer(function()
						self:refresh_selected()
					end)
				end)
				user_input_service.InputBegan:Connect(function(input, processed)
					if processed or not self.enabled or not self.shop or not self.shop.Enabled or input.UserInputType ~= Enum.UserInputType.Gamepad1 then
						return
					end
					local selected = self.shop_controller and self.shop_controller._selectedItem
					if not selected then
						return
					end
					if input.KeyCode == Enum.KeyCode.ButtonY then
						if selected.type == 'Sword' or selected.type == 'Explosion' then
							self:toggle_fav(selected.type, selected.name)
						end
					elseif input.KeyCode == Enum.KeyCode.ButtonX then
						if selected.type == 'Sword' or selected.type == 'Explosion' then
							if self:is_deleted(selected.type, selected.name) then
								self:undelete_item(selected.type, selected.name)
							else
								self:delete_item(selected.type, selected.name)
							end
						end
					elseif input.KeyCode == Enum.KeyCode.ButtonA then
						local info = self.shop and self.shop:FindFirstChild('Holder') and self.shop.Holder:FindFirstChild('InfoBG')
						local buy_btn = info and info:FindFirstChild('BuyButton')
						if selected.type == 'Sword' then
							self:equip_sword(selected.name, false)
							if buy_btn and buy_btn:FindFirstChild('PriceTag') and buy_btn.PriceTag:FindFirstChild('TextLabel') then
								buy_btn.PriceTag.TextLabel.Text = 'Equipped'
							end
						elseif selected.type == 'Explosion' then
							self:equip_explosion(selected.name)
							if buy_btn and buy_btn:FindFirstChild('PriceTag') and buy_btn.PriceTag:FindFirstChild('TextLabel') then
								buy_btn.PriceTag.TextLabel.Text = 'Equipped'
							end
						end
					end
				end)
				self.shop_controller.itemSelected:Connect(function(selected)
					if selected and self.unlocked[selected.type] then
						self:set_category_unlock(selected.type, true)
					end
					_defer(function()
						self:refresh_selected()
					end)
				end)
				buy_button.Activated:Connect(function()
					local selected = self.shop_controller._selectedItem
					if not selected then
						return
					end
					if self.enabled and self.unlocked[selected.type] then
						if self:is_deleted(selected.type, selected.name) then
							self:undelete_item(selected.type, selected.name)
						end
						if selected.type == 'Sword' then
							if self:equip_sword(selected.name, false) then
								buy_button.PriceTag.TextLabel.Text = 'Equipped'
							end
							return
						elseif selected.type == 'Explosion' then
							self:equip_explosion(selected.name)
							buy_button.PriceTag.TextLabel.Text = 'Equipped'
							return
						end
					end
					for _, original_fn in self.original_buy_fns do
						_spawn(original_fn)
					end
				end)
				local function refresh_on_open()
					if not self.shop.Enabled or not self.enabled then
						return
					end
					for _, category in { 'Sword', 'Explosion' } do
						if self.unlocked[category] then
							self:schedule_refresh(category)
						end
					end
				end
				self.shop:GetPropertyChangedSignal('Enabled'):Connect(function()
					if self.shop.Enabled then
						_defer(refresh_on_open)
					end
				end)
				if self.shop.Enabled then
					_defer(refresh_on_open)
				end
				return true
			end

			function unlock_all:hook_sword_fx()
				local shared = replicated_storage:FindFirstChild('Shared')
				local replicated_instances = shared and shared:FindFirstChild('ReplicatedInstances')
				local swords_module = replicated_instances and replicated_instances:FindFirstChild('Swords')
				if swords_module then
					local ok, swords = _pcall(require, swords_module)
					if ok then
						self.swords = swords
					end
				end
				local root_remotes = replicated_storage:FindFirstChild('Remotes')
				local parry_all = root_remotes and root_remotes:FindFirstChild('ParrySuccessAll')
				if parry_all then
					parry_all.OnClientEvent:Connect(function(...)
						if not self.enabled or not self.selected_sword or not self.play_parry then
							return
						end
						local args = { ... }
						local sword = self.swords and self.swords:GetSword(self.selected_sword)
						if sword and args[4] and _tostring(args[4]) == local_name then
							args[1] = sword.SlashName
							args[3] = sword.Name
						end
						return self.play_parry(_unpack(args))
					end)
				end
			end

			function unlock_all:setup_character(character)
				if self.character_connection then
					_pcall(function()
						self.character_connection:Disconnect()
					end)
					self.character_connection = nil
				end
				if not character then
					return
				end
				if self.enabled and config.last_equipped_sword and config.last_equipped_sword ~= '' then
					_defer(function()
						if self.enabled and config.last_equipped_sword ~= '' then
							self:equip_sword(config.last_equipped_sword, false)
						end
					end)
				end
				local function on_child_added(child)
					if not self.enabled or not child:IsA('Model') or not self.swords or not self.selected_sword then
						return
					end
					local model = self.swords:GetSword(child.Name)
					if not model then
						return
					end
					if child.Name ~= self.selected_sword then
						local wanted = self.selected_sword
						_defer(function()
							if self.enabled and self.selected_sword == wanted then
								self:equip_sword(wanted, false)
							end
						end)
					else
						self:apply_chroma(child, model)
						if self.sword_fn then
							_defer(function()
								if self.enabled and self.selected_sword == child.Name then
									_pcall(self.sword_fn, child.Name)
								end
							end)
						end
					end
				end
				self.character_connection = character.ChildAdded:Connect(on_child_added)
				for _, child in character:GetChildren() do
					on_child_added(child)
				end
			end

			function unlock_all:hook_chroma()
				if self.chroma_bound then
					return
				end
				self.chroma_bound = true
				self.added_connection = local_player.CharacterAdded:Connect(function(character)
					self:setup_character(character)
				end)
				if local_player.Character then
					_defer(function()
						self:setup_character(local_player.Character)
					end)
				end
				self.sword_attr_connection = local_player:GetAttributeChangedSignal('CurrentlyEquippedSword'):Connect(function()
					local sword_name = self.selected_sword
					if not self.enabled or not sword_name or local_player:GetAttribute('CurrentlyEquippedSword') == sword_name then
						return
					end
					local_player:SetAttribute('CurrentlyEquippedSword', sword_name)
					if local_player.Character then
						local_player.Character:SetAttribute('CurrentlyEquippedSword', sword_name)
					end
					if self.sword_fn then
						_pcall(self.sword_fn, sword_name)
					end
				end)
			end

			function unlock_all:initialize()
				local ui_controllers = replicated_storage.Controllers:FindFirstChild('UI')
				local legacy_module = ui_controllers and ui_controllers:FindFirstChild('ShopController')
				local modern_module = ui_controllers and ui_controllers:FindFirstChild('ShopControllerAPI')
				local legacy_ok, shop_controller = _pcall(require, legacy_module)
				local modern_ok, shop_api = _pcall(require, modern_module)
				if not legacy_ok or _type(shop_controller) ~= 'table' then
					shop_controller = nil
				end
				if not modern_ok or _type(shop_api) ~= 'table' then
					shop_api = nil
				end
				if not shop_controller and not shop_api then
					warn('[oxy] unlock all: failed to load shop controllers')
					return
				end
				self.shop_controller = shop_controller
				self.shop_api = shop_api
				self:hook_sword_fx()
				self:hook_chroma()
				_pcall(function()
					self.explosion_module = require(replicated_storage.Controllers.VFXController)
				end)
				self:ensure_explosion_wrap()
				if self.shop_controller then
					self:hook_shop()
				end
				if self.shop_api then
					self:hook_modern_shop()
				end
				self.ready = true
				self:set_enabled(self.enabled)
				if self.enabled and config.last_equipped_sword and config.last_equipped_sword ~= '' then
					_defer(function()
						if self.enabled and config.last_equipped_sword ~= '' then
							self:equip_sword(config.last_equipped_sword, false)
						end
					end)
				end
				if self.enabled and config.last_equipped_explosion and config.last_equipped_explosion ~= '' then
					_defer(function()
						if self.enabled and config.last_equipped_explosion ~= '' then
							self:equip_explosion(config.last_equipped_explosion)
						end
					end)
				end
			end

			function unlock_all:set_enabled(state)
				self.enabled = state == true
				if not self.ready then
					return
				end
				for _, category in { 'Sword', 'Explosion' } do
					if self.enabled then
						if self.shop_controller then
							self:set_category_unlock(category, true)
							self:schedule_refresh(category)
						end
						self:set_modern_unlock(category, true)
					else
						if self.shop_controller then
							self.refresh_generation[category] = (self.refresh_generation[category] or 0) + 1
							self:set_category_unlock(category, false)
						end
						self:set_modern_unlock(category, false)
					end
				end
				if not self.enabled then
					self:restore_sword()
					self.selected_explosion = nil
				else
					self:refresh_selected()
				end
			end

			unlock_all:initialize()
			unlockAllModule = unlock_all
		end)
	end


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

end

Extra:AddSection("World")
local worldGroup = Extra:AddGroup()
worldGroup:AddToggle({
	Name = "No Render",
	Flag = "no_render",
	Default = false,
	Callback = function(s)
		noRenderEnabled = s
		if s then startNoRender() else stopNoRender() end
	end,
})
worldGroup:AddToggle({
	Name = "Raytracing",
	Flag = "raytracing",
	Default = false,
	Callback = function(s) raytracingEnabled = s; setRaytracing(s) end,
})
worldGroup:AddToggle({
	Name = "Dim World",
	Flag = "world_dim",
	Default = true,
	Callback = function(on) UI:SetWorldDim(on) end,
})
UI:SetWorldDimPersistent(true)
local fbHandle, fdHandle
fbHandle = worldGroup:AddToggle({
	Name = "Fullbright",
	Flag = "fullbright",
	Default = false,
	Callback = function(s)
		fullbrightEnabled = s
		if s and fulldarkEnabled then fulldarkEnabled = false; if fdHandle then fdHandle:Set(false, true) end; setFulldark(false) end
		setFullbright(s)
	end,
})
fdHandle = worldGroup:AddToggle({
	Name = "Fulldark",
	Flag = "fulldark",
	Default = false,
	Callback = function(s)
		fulldarkEnabled = s
		if s and fullbrightEnabled then fullbrightEnabled = false; if fbHandle then fbHandle:Set(false, true) end; setFullbright(false) end
		setFulldark(s)
	end,
})

Extra:AddSection("Autoplay")
do
	local apEnabled, apMode, apJump = false, "Dynamic", false

	local AP_PRESSURE = 20
	local AP = {
		CurrentTarget = nil, TargetTime = 0, State = "idle",
		LastPosition = nil, StuckTime = 0, StuckCheckTime = 0, Circle = 0,
	}
	local JB = { nextAt = 0, burst = 0, lastJump = 0, checkAt = 0, autoJumpOrig = nil }

	local function alivePlayers()
		local alive = Workspace:FindFirstChild("Alive")
		return alive and alive:GetChildren() or _NO_BALLS
	end
	local function realBall()
		return firstRealBall()
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
		Flag = "auto_play",
		Default = false,
		Callback = function(s)
			apEnabled = s
			if not s then
				AP.CurrentTarget = nil
				AP.State = "idle"
			end
		end,
	})
	apGroup:AddToggle({
		Name = "Auto Jump",
		Flag = "auto_jump",
		Default = false,
		Callback = function(s)
			apJump = s
			JB.burst = 0
			JB.nextAt = tick() + 0.25
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				if s then
					if JB.autoJumpOrig == nil then JB.autoJumpOrig = hum.AutoJumpEnabled end
					hum.AutoJumpEnabled = true
				elseif JB.autoJumpOrig ~= nil then
					hum.AutoJumpEnabled = JB.autoJumpOrig
					JB.autoJumpOrig = nil
				end
			end
		end,
	})
	apGroup:AddDropdown({
		Name = "Auto Play Mode",
		Flag = "auto_play_mode",
		Options = { "Aggressive", "Dynamic", "Safe" },
		Default = "Dynamic",
		Callback = function(v) apMode = v end,
	})

	local function jumpReady(hum)
		if hum.Sit or hum.PlatformStand then return false end
		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Freefall
			or st == Enum.HumanoidStateType.Jumping
			or st == Enum.HumanoidStateType.Dead
			or st == Enum.HumanoidStateType.Seated then
			return false
		end
		return hum.FloorMaterial ~= Enum.Material.Air
	end

	local function doJump(hum)
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
		hum.Jump = true
		JB.lastJump = tick()
	end

	local function nextDelay()
		return math.clamp(0.9 + (-math.log(1 - math.random())) * 1.3, 0.9, 6)
	end

	local function obstacleAhead(char, hrp, hum)
		local dir = hum.MoveDirection
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude < 0.1 then return false end
		flat = flat.Unit
		local rp = RaycastParams.new()
		rp.FilterDescendantsInstances = { char }
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local p = hrp.Position
		local ground = p.Y - (hum.HipHeight + hrp.Size.Y * 0.5)
		local low = Workspace:Raycast(Vector3.new(p.X, ground + 1.1, p.Z), flat * 3.4, rp)
		if not low or not low.Instance.CanCollide then return false end
		local high = Workspace:Raycast(Vector3.new(p.X, ground + 6, p.Z), flat * 3.4, rp)
		return high == nil
	end

	local function jumpBrain(char, hrp, hum)
		local now = tick()
		local moving = hum.MoveDirection.Magnitude > 0.1
		local solo = not apEnabled
		if not solo and not moving and JB.nextAt < now + 0.5 then
			JB.nextAt = now + 0.5 + math.random() * 0.8
		end
		if not jumpReady(hum) then return end
		if now - JB.lastJump < 0.3 then return end

		if moving and now >= JB.checkAt then
			JB.checkAt = now + 0.15
			if obstacleAhead(char, hrp, hum) then
				doJump(hum)
				return
			end
		end

		if apEnabled and AP.StuckTime >= 1 then
			doJump(hum)
			return
		end

		if (moving or solo) and now >= JB.nextAt then
			doJump(hum)
			if solo then
				JB.nextAt = now + 0.4 + math.random() * 0.5
			elseif JB.burst > 0 then
				JB.burst = JB.burst - 1
				JB.nextAt = now + 0.35 + math.random() * 0.25
			else
				JB.nextAt = now + nextDelay()
				if math.random() < 0.2 then JB.burst = math.random(1, 2) end
			end
		end
	end

	table.insert(UI.Connections, RunService.Heartbeat:Connect(function()
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp or hum.Health <= 0 then return end

		if apJump then jumpBrain(char, hrp, hum) end
		if not apEnabled then return end

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
end


UI:OnDestroy(function()
	pcall(stopAbilityESP)
	pcall(stopNoRender)
	local hadLightingOverride = fullbrightEnabled or fulldarkEnabled
	fullbrightEnabled = false
	fulldarkEnabled = false
	for _, c in ipairs(_pyraConns) do pcall(function() c:Disconnect() end) end
	table.clear(_pyraConns)
	if hadLightingOverride then pcall(setNormalLighting) end
	pcall(function() setRaytracing(false) end)
	pcall(function()
		local c = Workspace.CurrentCamera
		if c then c.FieldOfView = 70 end
	end)
end)
end

if type(UI.FitPanelToTab) == "function" then
	pcall(function() UI:FitPanelToTab("Combat") end)
end

-- ===== INTRO =====
do
	local TweenService = game:GetService("TweenService")
	local CoreGui = game:GetService("CoreGui")
	local ContentProvider = game:GetService("ContentProvider")

	local LOGO = {
		top = "rbxassetid://122332062249013",
		middle = "rbxassetid://119522826189269",
		bottom = "rbxassetid://121534632177131",
	}
	local LOGO_SIZE = 240

	local function runIntro(onDone)
		local gui = Instance.new("ScreenGui")
		gui.Name = "PyraIntro"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 999999
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
		pcall(_protectGui, gui)
		if not gui.Parent then
			local ok = pcall(function() gui.Parent = CoreGui end)
			if not ok then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
		end
		introGui = gui

		local function running()
			return gui.Parent ~= nil and not UI.Destroyed
		end

		local backdrop = Instance.new("Frame")
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		backdrop.BackgroundTransparency = 1
		backdrop.BorderSizePixel = 0
		backdrop.ZIndex = 1
		backdrop.Parent = gui

		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE)
		holder.BackgroundTransparency = 1
		holder.ZIndex = 2
		holder.Parent = gui

		local holderScale = Instance.new("UIScale")
		holderScale.Scale = 1
		holderScale.Parent = holder

		local pieces = {}
		local order = { "top", "middle", "bottom" }
		for i, key in ipairs(order) do
			local img = Instance.new("ImageLabel")
			img.Name = key
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.fromScale(1, 1)
			img.BackgroundTransparency = 1
			img.Image = LOGO[key]
			img.ImageTransparency = 1
			img.ZIndex = 2
			img.Parent = holder
			pieces[i] = img
		end

		TweenService:Create(backdrop, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.45 }):Play()

		local SPIN_TIME = 0.6
		local STAGGER = 0.14
		local startOffsets = {
			UDim2.new(0.5, 0, 0.5, -180),
			UDim2.new(0.5, -170, 0.5, 120),
			UDim2.new(0.5, 170, 0.5, 120),
		}
		local startRot = { -220, 200, -180 }

		for i, img in ipairs(pieces) do
			img.Position = startOffsets[i]
			img.Rotation = startRot[i]
			img.Size = UDim2.fromScale(1.4, 1.4)
			task.delay((i - 1) * STAGGER, function()
				if not img.Parent then return end
				local info = TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				TweenService:Create(img, info, {
					Position = UDim2.fromScale(0.5, 0.5),
					Rotation = 0,
					Size = UDim2.fromScale(1, 1),
					ImageTransparency = 0,
				}):Play()
			end)
		end

		local POP_SCALE = 1.18
		local POP_TIME = 0.22
		local POP_PEAK_AT = 0.13
		local SHRINK_TIME = 0.4

		local assembledAt = (#pieces - 1) * STAGGER + SPIN_TIME
		task.delay(assembledAt + 0.25, function()
			if not running() then return end
			TweenService:Create(holderScale, TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = POP_SCALE }):Play()

			task.delay(POP_PEAK_AT, function()
				if not running() then return end
				TweenService:Create(holderScale, TweenInfo.new(SHRINK_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
				TweenService:Create(backdrop, TweenInfo.new(SHRINK_TIME, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
				task.delay(SHRINK_TIME, function()
					if not running() then return end
					if onDone then onDone() end
					task.delay(0.15, function()
						if introGui == gui then introGui = nil end
						gui:Destroy()
					end)
				end)
			end)
		end)
	end

	local function preloadLogo()
		local holder = {}
		for _, id in pairs(LOGO) do
			local img = Instance.new("ImageLabel")
			img.Image = id
			holder[#holder + 1] = img
		end
		local fullLogo = Instance.new("ImageLabel")
		fullLogo.Image = "rbxassetid://138576850849681"
		holder[#holder + 1] = fullLogo
		local done = false
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, holder)
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 2.5 do task.wait() end
		for _, img in ipairs(holder) do img:Destroy() end
		for _ = 1, 8 do task.wait() end
	end

	preloadLogo()
	if not UI.Destroyed then
		runIntro(function()
			if not UI.Destroyed and not UI.Open then UI:Show() end
		end)
	end
end
