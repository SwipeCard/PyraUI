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

local function getGuiParent()
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui end
	end
	local ok = pcall(function() return CoreGui:GetChildren() end)
	if ok then return CoreGui end
	return player:WaitForChild("PlayerGui")
end

local function protect(gui)
	if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
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
	local lastT, lastCF, lastPos, lastSize, lastVpY, cachedInset
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
		local aPos, aSize = frame.AbsolutePosition, frame.AbsoluteSize
		if cf == lastCF and aPos == lastPos and aSize == lastSize then return end
		lastCF, lastPos, lastSize = cf, aPos, aSize

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
		tween(bar, 0.25, { Position = self.MonitorHome + UDim2.fromOffset(0, -10) })
		task.delay(0.25, function()
			local still = false
			for _, it in ipairs(self.MonitorOrder) do if it.shown then still = true break end end
			if not still then
				bar.Visible = false
				bar.Position = self.MonitorHome
			end
		end)
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
	local env = (type(getgenv) == "function") and getgenv() or nil
	local fn = setfpscap
		or set_fps_cap
		or setfpslimit
		or set_fps_limit
		or (env and (env.setfpscap or env.set_fps_cap or env.setfpslimit or env.set_fps_limit))
		or (syn and syn.set_fps_cap)
		or (fluxus and (fluxus.setfpscap or fluxus.set_fps_cap))
	if type(fn) ~= "function" then return false end
	n = tonumber(n) or 0
	if n <= 0 then n = 1e6 end
	local ok = pcall(fn, n)
	return ok
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
