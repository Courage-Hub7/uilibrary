-- Aster UI · client-side Roblox UI. No external assets or dependencies.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local Aster = {}
local App = {}; App.__index = App
local Window = {}; Window.__index = Window
local Tab = {}; Tab.__index = Tab
local Section = {}; Section.__index = Section

local C = {
	Background = Color3.fromRGB(14, 15, 20),
	Sidebar = Color3.fromRGB(18, 19, 26),
	Panel = Color3.fromRGB(23, 24, 32),
	Control = Color3.fromRGB(30, 31, 42),
	Hover = Color3.fromRGB(39, 40, 54),
	Line = Color3.fromRGB(43, 44, 58),
	Text = Color3.fromRGB(235, 236, 245),
	Muted = Color3.fromRGB(145, 147, 167),
	Accent = Color3.fromRGB(171, 151, 245),
}

local Themes = { Dark = C, Midnight = {
	Background = Color3.fromRGB(11, 17, 28), Sidebar = Color3.fromRGB(15, 23, 37),
	Panel = Color3.fromRGB(20, 29, 45), Control = Color3.fromRGB(28, 40, 59),
	Hover = Color3.fromRGB(36, 52, 76), Line = Color3.fromRGB(49, 65, 86),
	Text = Color3.fromRGB(229, 239, 252), Muted = Color3.fromRGB(143, 164, 189),
	Accent = Color3.fromRGB(112, 177, 249),
}, Light = {
	Background = Color3.fromRGB(240, 241, 247), Sidebar = Color3.fromRGB(231, 233, 241),
	Panel = Color3.fromRGB(250, 251, 255), Control = Color3.fromRGB(223, 226, 237),
	Hover = Color3.fromRGB(207, 212, 228), Line = Color3.fromRGB(188, 194, 213),
	Text = Color3.fromRGB(31, 35, 52), Muted = Color3.fromRGB(91, 100, 126),
	Accent = Color3.fromRGB(113, 81, 194),
} }
local windowsByGui = setmetatable({}, { __mode = "k" })
local function themeFor(parent)
	while parent do
		if windowsByGui[parent] then return windowsByGui[parent].Theme end
		parent = parent.Parent
	end
	return C
end

local function available(object)
	if not object.Parent then return false end
	while object do
		if object:IsA("GuiObject") and (not object.Visible or not object.Interactable) then return false end
		if object:IsA("LayerCollector") and not object.Enabled then return false end
		object = object.Parent
	end
	return true
end

local function make(class, props, parent)
	local object = Instance.new(class)
	for key, value in pairs(props) do object[key] = value end
	object.Parent = parent
	if object:IsA("GuiObject") and (object:IsA("GuiButton") or object:IsA("TextBox") or object.Active) then
		local ancestor = parent
		while ancestor do
			local window = windowsByGui[ancestor]
			if window then
				-- Focus works under custom GUI parents as well as PlayerGui.
				object.InputBegan:Connect(function() if available(object) then window:Focus() end end)
				break
			end
			ancestor = ancestor.Parent
		end
	end
	return object
end

local function round(object, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
	return object
end

local function frame(parent, props)
	local values = { BorderSizePixel = 0, BackgroundColor3 = themeFor(parent).Panel }
	for k, v in pairs(props or {}) do values[k] = v end
	return make("Frame", values, parent)
end

local function label(parent, text, props)
	local C = themeFor(parent)
	local values = {
		BackgroundTransparency = 1, BorderSizePixel = 0, Text = text,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for k, v in pairs(props or {}) do values[k] = v end
	return make("TextLabel", values, parent)
end

local function button(parent, text, props)
	local C = themeFor(parent)
	local values = {
		BorderSizePixel = 0, BackgroundColor3 = C.Control, Text = text,
		AutoButtonColor = false, Font = Enum.Font.GothamMedium,
		TextSize = 13, TextColor3 = C.Text, Size = UDim2.new(1, 0, 0, 34),
	}
	for k, v in pairs(props or {}) do values[k] = v end
	return round(make("TextButton", values, parent), 6)
end

local function padding(parent, value)
	make("UIPadding", {
		PaddingTop = UDim.new(0, value), PaddingBottom = UDim.new(0, value),
		PaddingLeft = UDim.new(0, value), PaddingRight = UDim.new(0, value),
	}, parent)
end

local function list(parent, gap)
	return make("UIListLayout", { Padding = UDim.new(0, gap or 8), SortOrder = Enum.SortOrder.LayoutOrder }, parent)
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function emit(callback, value)
	if callback then
		task.spawn(function()
			local ok, err = pcall(callback, value)
			if not ok then warn("[AsterUI callback] " .. tostring(err)) end
		end)
	end
end

function Window:_connect(signal, callback, scope)
	local connection = signal:Connect(callback)
	self.Connections[connection] = true
	scope = scope or self.BuildScope
	if scope then scope[connection] = true end
	return connection
end

function Window:_tween(object, props)
	local previous = self.Tweens[object]
	if previous then previous:Cancel(); self.Tweens[object] = nil end
	self.TweenGoals[object] = props
	if self.App.ReducedMotion then
		for key, value in pairs(props) do object[key] = value end
	else
		local tween = TweenService:Create(object, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		self.Tweens[object] = tween
		tween:Play()
	end
end

function Window:_hover(object)
	local C = self.Theme
	self:_connect(object.MouseEnter, function() self:_tween(object, { BackgroundColor3 = C.Hover }) end)
	self:_connect(object.MouseLeave, function() self:_tween(object, { BackgroundColor3 = C.Control }) end)
end

-- Capture one pointer, including releases outside the original control.
function Window:_drag(object, start, move, finish)
	local pointer
	self:_connect(object.InputBegan, function(input)
		if pointer or not available(object) or self.Dialog then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pointer = input
			self:Focus()
			start(input.Position)
		end
	end)
	self:_connect(Input.InputChanged, function(input)
		if not pointer then return end
		if not available(object) or self.Dialog then pointer = nil; if finish then finish() end; return end
		if input == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
			move(input.Position)
		end
	end)
	self:_connect(Input.InputEnded, function(input)
		if input == pointer then pointer = nil; if finish then finish() end end
	end)
end

function Aster.new(options)
	options = options or {}
	assert(RunService:IsClient(), "AsterUI requires a Roblox client runtime")
	assert(options.Parent == nil or typeof(options.Parent) == "Instance", "Parent must be an Instance")
	local app = setmetatable({
		Parent = options.Parent, CustomParent = options.Parent,
		ReducedMotion = options.ReducedMotion == true,
		Windows = {}, Order = options.DisplayOrder or 20, Destroyed = false,
		Started = os.clock(), Cleanups = {},
	}, App)
	app.FocusConnection = Input.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local container = app.Parent
		while container and not container:IsA("BasePlayerGui") do container = container.Parent end
		if not container then return end
		local ok, objects = pcall(function() return container:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) end)
		if not ok then return end
		local top = objects[1]
		if top then
			for _, window in ipairs(app.Windows) do
				if not window.Surface and top:IsDescendantOf(window.Root) then window:Focus(); break end
			end
		end
	end)
	return app
end

function App:_parentGui(gui)
	local function attach(parent)
		assert(typeof(parent) == "Instance", "GUI parent must be an Instance")
		gui.Parent = parent
		assert(gui.Parent == parent, "GUI parenting failed")
	end
	if self.CustomParent then
		local ok, err = pcall(attach, self.CustomParent)
		if not ok then gui:Destroy(); error("Cannot use explicit Parent: " .. tostring(err), 2) end
		return
	end
	-- SurfaceGui input is routed through PlayerGui; screen windows use the client UI container.
	if not gui:IsA("SurfaceGui") then
		if type(gethui) == "function" then
			local ok = pcall(function() attach(gethui()) end)
			if ok then self.Parent = gui.Parent; return end
		end
		local ok = pcall(function() attach(game:GetService("CoreGui")) end)
		if ok then self.Parent = gui.Parent; return end
	end
	local ok, err = pcall(function() attach(Players.LocalPlayer:WaitForChild("PlayerGui")) end)
	if not ok then gui:Destroy(); error("Cannot parent Aster GUI: " .. tostring(err), 2) end
	if not gui:IsA("SurfaceGui") then self.Parent = gui.Parent end
end

function App:CreateWindow(options)
	assert(not self.Destroyed, "App is destroyed")
	options = options or {}
	assert(Themes[options.Theme or "Dark"], "Unknown theme")
	local C = table.clone(Themes[options.Theme or "Dark"])
	C.Accent = options.Accent or C.Accent
	local surface = options.Adornee
	if surface then assert(surface:IsA("BasePart"), "Adornee must be a BasePart") end
	local window = setmetatable({
		App = self, Connections = {}, Tweens = {}, TweenGoals = {}, Tabs = {}, Controls = {}, Flags = {}, Surface = surface ~= nil,
		Theme = C,
		Accent = options.Accent or C.Accent, Width = math.max(560, (options.Size or Vector2.new(860, 560)).X),
		Height = math.max(360, (options.Size or Vector2.new(860, 560)).Y), Destroyed = false,
	}, Window)
	local guiProps = { Name = "Aster_" .. (options.Title or "Window"), ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }
	if surface then
		guiProps.Adornee = surface
		guiProps.Face = options.Face or Enum.NormalId.Front
		guiProps.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		guiProps.CanvasSize = Vector2.new(window.Width, window.Height)
		guiProps.LightInfluence = 0
		guiProps.AlwaysOnTop = options.AlwaysOnTop == true
		guiProps.Active = true
	else
		guiProps.ScreenInsets = Enum.ScreenInsets.None
		guiProps.DisplayOrder = self.Order
	end
	window.Gui = make(surface and "SurfaceGui" or "ScreenGui", guiProps)
	self:_parentGui(window.Gui)
	windowsByGui[window.Gui] = window
	window.Root = frame(window.Gui, { Name = "Window", BackgroundColor3 = C.Background, Active = true,
		Size = UDim2.fromOffset(window.Width, window.Height),
		Position = surface and UDim2.fromOffset(0, 0) or (options.Position or UDim2.fromOffset(80 + #self.Windows * 28, 80 + #self.Windows * 28)),
	})
	round(window.Root, 12)
	window.Stroke = make("UIStroke", { Color = C.Line, Transparency = 0.12 }, window.Root)
	window.Scale = make("UIScale", { Scale = 1 }, window.Root)
	local top = frame(window.Root, { Name = "Titlebar", BackgroundTransparency = 1, Size = UDim2.new(1, -90, 0, 56), Active = true })
	label(top, "✦", { Position = UDim2.fromOffset(20, 13), Size = UDim2.fromOffset(28, 30), TextSize = 25, TextColor3 = window.Accent })
	label(top, options.Title or "ASTER", { Position = UDim2.fromOffset(56, 12), Size = UDim2.new(1, -60, 0, 21), Font = Enum.Font.GothamBold, TextSize = 16 })
	label(top, options.Subtitle or "YOUR SPACE, REFINED", { Position = UDim2.fromOffset(56, 33), Size = UDim2.new(1, -60, 0, 14), TextSize = 9, TextColor3 = C.Muted })
	local minimize = button(window.Root, "−", { Position = UDim2.new(1, -80, 0, 15), Size = UDim2.fromOffset(28, 28) })
	local close = button(window.Root, "×", { Position = UDim2.new(1, -44, 0, 15), Size = UDim2.fromOffset(28, 28) })
	window:_hover(minimize); window:_hover(close)
	window.Body = frame(window.Root, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56) })
	frame(window.Body, { BackgroundColor3 = C.Line, Size = UDim2.new(1, 0, 0, 1) })
	local sidebar = frame(window.Body, { BackgroundColor3 = C.Sidebar, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(0, 175, 1, -2) })
	round(sidebar, 10)
	label(sidebar, "WORKSPACE", { Position = UDim2.fromOffset(18, 18), Size = UDim2.new(1, -36, 0, 18), TextColor3 = C.Muted, TextSize = 10 })
	window.Nav = make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 1, -105), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = C.Line }, sidebar)
	list(window.Nav, 6)
	frame(sidebar, { BackgroundColor3 = C.Line, Position = UDim2.new(0, 16, 1, -49), Size = UDim2.new(1, -32, 0, 1) })
	label(sidebar, options.Footer or "ASTER  /  UI LIBRARY", { Position = UDim2.new(0, 18, 1, -39), Size = UDim2.new(1, -36, 0, 24), TextSize = 10, TextColor3 = C.Muted })
	window.Content = frame(window.Body, { BackgroundTransparency = 1, Position = UDim2.fromOffset(194, 0), Size = UDim2.new(1, -212, 1, -14) })
	window.Breadcrumb = label(window.Content, "Workspace", { Position = UDim2.fromOffset(0, 13), Size = UDim2.new(0.5, -10, 0, 30), TextColor3 = C.Muted, TextSize = 12 })
	window.Search = round(make("TextBox", { Name = "Search", BackgroundColor3 = C.Control, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0, 13), Size = UDim2.new(0.5, 0, 0, 30), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.Text, PlaceholderText = "Search controls...", PlaceholderColor3 = C.Muted, Text = "", ClearTextOnFocus = false }, window.Content), 6)
	window.Resize = button(window.Root, "◢", { Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, TextColor3 = C.Muted, Visible = not window.Surface })
	window:_connect(window.Search:GetPropertyChangedSignal("Text"), function() window:_filter() end)
	window:_connect(minimize.Activated, function() window:Minimize(not window.Minimized) end)
	window:_connect(close.Activated, function() window:SetVisible(false) end)
	window:_connect(window.Root.InputBegan, function() window:Focus() end)
	if not surface then
		local origin, position
		window:_drag(top, function(p) origin = p; position = window.Root.AbsolutePosition end, function(p)
			local nextPosition = position + Vector2.new(p.X - origin.X, p.Y - origin.Y)
			window.Root.Position = UDim2.fromOffset(nextPosition.X, nextPosition.Y)
			window:_fit()
		end)
		local resizeOrigin, startSize, startScale
		window:_drag(window.Resize, function(p) resizeOrigin = p; startSize = Vector2.new(window.Width, window.Height); startScale = window.Scale.Scale end, function(p)
			window:SetSize(Vector2.new(startSize.X + (p.X - resizeOrigin.X) / startScale, startSize.Y + (p.Y - resizeOrigin.Y) / startScale))
		end)
		window:_connect(window.Gui:GetPropertyChangedSignal("AbsoluteSize"), function() window:_fit() end)
	end
	window:_connect(window.Gui.Destroying, function() window:Destroy() end)
	table.insert(self.Windows, window)
	window:_fit()
	window:Focus()
	return window
end

function Window:_fit()
	if self.Surface then return end
	local screen = self.Gui.AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then return end
	self.Scale.Scale = math.min(1, (screen.X - 16) / self.Width, (screen.Y - 16) / (self.Minimized and 56 or self.Height))
	local scale = self.Scale.Scale
	local pos = self.Root.AbsolutePosition
	self.Root.Position = UDim2.fromOffset(math.clamp(pos.X, 8, math.max(8, screen.X - self.Width * scale - 8)), math.clamp(pos.Y, 8, math.max(8, screen.Y - (self.Minimized and 56 or self.Height) * scale - 8)))
end

function Window:Focus()
	if self.Destroyed then return end
	for _, window in ipairs(self.App.Windows) do window.Stroke.Color = window.Theme.Line end
	self.Stroke.Color = self.Accent:Lerp(self.Theme.Line, 0.55)
	if not self.Surface then self.App.Order += 1; self.Gui.DisplayOrder = self.App.Order end
end

function Window:SetVisible(visible)
	if not visible and self.Dialog then self.Dialog:Close(false) end
	if self.Tooltip then self.Tooltip.Visible = false end
	self.Gui.Enabled = visible
	if visible then self:_fit(); self:Focus() end
end

function Window:Minimize(value)
	if value and self.Dialog then self.Dialog:Close(false) end
	if self.Tooltip then self.Tooltip.Visible = false end
	self.Minimized = value == true
	self.Body.Visible = not self.Minimized
	self.Resize.Visible = not self.Surface and not self.Minimized
	self:_tween(self.Root, { Size = UDim2.fromOffset(self.Width, self.Minimized and 56 or self.Height) })
	self:_fit()
end

function Window:SetSize(size)
	assert(finite(size.X) and finite(size.Y), "Size must be finite")
	self.Width, self.Height = math.max(560, size.X), math.max(360, size.Y)
	local tween = self.Tweens[self.Root]
	if tween then tween:Cancel(); self.Tweens[self.Root] = nil end
	self.Root.Size = UDim2.fromOffset(self.Width, self.Minimized and 56 or self.Height)
	if self.Surface then self.Gui.CanvasSize = Vector2.new(self.Width, self.Height) end
	for _, tab in ipairs(self.Tabs) do tab:_layout() end
	self:_fit()
end

function Window:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	if self.Dialog then self.Dialog:Close(false) end
	if self.Toasts then while #self.Toasts > 0 do self.Toasts[1]:Dismiss() end end
	while next(self.Controls) do next(self.Controls):Destroy() end
	for connection in pairs(self.Connections) do connection:Disconnect() end
	for _, tween in pairs(self.Tweens) do tween:Cancel() end
	table.clear(self.Connections); table.clear(self.Tweens); table.clear(self.TweenGoals)
	local index = table.find(self.App.Windows, self)
	if index then table.remove(self.App.Windows, index) end
	windowsByGui[self.Gui] = nil
	self.Gui:Destroy()
end

function App:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self.FocusConnection:Disconnect()
	while #self.Windows > 0 do self.Windows[#self.Windows]:Destroy() end
	for _, cleanup in ipairs(self.Cleanups) do
		local ok, err = pcall(cleanup)
		if not ok then warn("[AsterUI cleanup] " .. tostring(err)) end
	end
	table.clear(self.Cleanups)
end

function App:OnDestroy(callback)
	assert(not self.Destroyed and type(callback) == "function", "Expected a cleanup function on a live app")
	table.insert(self.Cleanups, callback)
end

function Window:AddTab(options)
	local C = self.Theme
	options = options or {}
	local tab = setmetatable({ Window = self, Title = options.Title or "Tab", Sections = {} }, Tab)
	tab.Button = button(self.Nav, "  " .. (options.Icon or "◇") .. "   " .. tab.Title, { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -2, 0, 38), BackgroundColor3 = C.Sidebar, LayoutOrder = #self.Tabs + 1 })
	tab.Marker = round(frame(tab.Button, { BackgroundColor3 = self.Accent, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(3, 18), Visible = false }), 2)
	tab.Page = make("ScrollingFrame", { Name = tab.Title, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.Line, Visible = false }, self.Content)
	tab.Columns = {}
	for i = 1, 2 do
		tab.Columns[i] = frame(tab.Page, { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y })
		list(tab.Columns[i], 12)
	end
	self:_connect(tab.Button.Activated, function() tab:Select() end)
	table.insert(self.Tabs, tab)
	tab:_layout()
	if #self.Tabs == 1 then tab:Select() end
	return tab
end

function Tab:_layout()
	local compact = self.Window.Width < 740
	self.Columns[1].Size = compact and UDim2.new(1, -6, 0, 0) or UDim2.new(0.5, -9, 0, 0)
	self.Columns[2].Size = UDim2.new(0.5, -9, 0, 0)
	self.Columns[2].Position = UDim2.new(0.5, 3, 0, 0)
	self.Columns[2].Visible = not compact
	for _, section in ipairs(self.Sections) do section.Frame.Parent = self.Columns[compact and 1 or section.Column] end
end

function Tab:Select()
	local window = self.Window
	local C = window.Theme
	if window.Tooltip then window.Tooltip.Visible = false end
	window.SelectedTab = self
	for _, tab in ipairs(window.Tabs) do
		local selected = tab == self
		tab.Page.Visible = selected
		tab.Marker.Visible = selected
		window:_tween(tab.Button, { BackgroundColor3 = selected and C.Control or C.Sidebar, TextColor3 = selected and C.Text or C.Muted })
	end
	window.Breadcrumb.Text = "Workspace  /  " .. self.Title
	window:_filter()
end

function Window:_filter()
	local query = string.lower(self.Search.Text)
	for _, tab in ipairs(self.Tabs) do
		for _, section in ipairs(tab.Sections) do
			local shown = 0
			for _, row in ipairs(section.Rows) do
				local matches = query == "" or string.find(string.lower(section.Title .. " " .. row.Title), query, 1, true) ~= nil
				row.Frame.Visible = not row.Hidden and (not section.Collapsed or query ~= "") and matches
				if row.Frame.Visible then shown += 1 end
			end
			section.Frame.Visible = not section.Hidden and (shown > 0 or query == "")
		end
	end
end

function Tab:AddSection(options)
	local C = self.Window.Theme
	options = options or {}
	local section = setmetatable({ Tab = self, Window = self.Window, Title = options.Title or "Section", Rows = {}, Column = options.Column == 2 and 2 or 1 }, Section)
	section.Frame = round(frame(self.Columns[1], { Name = section.Title, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = #self.Sections + 1 }), 8)
	make("UIStroke", { Color = C.Line, Transparency = 0.55 }, section.Frame)
	padding(section.Frame, 12)
	list(section.Frame, 6)
	local heading = label(section.Frame, string.upper(section.Title), { TextSize = 10, TextColor3 = self.Window.Accent, Font = Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0 })
	frame(heading, { BackgroundColor3 = C.Line, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1) })
	if options.Collapsible then
		local collapse = button(heading, "−", { BackgroundTransparency = 1, Position = UDim2.new(1, -24, 0, -2), Size = UDim2.fromOffset(24, 24) })
		section.CollapseButton = collapse
		self.Window:_connect(collapse.Activated, function() section:SetCollapsed(not section.Collapsed) end)
	end
	table.insert(self.Sections, section)
	self:_layout()
	section:SetCollapsed(options.Collapsed == true)
	return section
end

function Section:SetCollapsed(value)
	self.Collapsed = value == true
	if self.CollapseButton then self.CollapseButton.Text = self.Collapsed and "+" or "−" end
	self.Window:_filter()
end

function Section:SetVisible(value)
	self.Hidden = not value
	self.Window:_filter()
end

function Section:_row(title, height)
	local row = frame(self.Frame, { Name = title, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), LayoutOrder = #self.Rows + 1 })
	table.insert(self.Rows, { Frame = row, Title = title })
	self.Window:_filter()
	return row
end

function Section:AddLabel(options)
	local C = self.Window.Theme
	local row = self:_row(options.Text or "", options.Height or 42)
	local text = label(row, options.Text or "", { Size = UDim2.fromScale(1, 1), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextColor3 = C.Muted, TextSize = 12 })
	return { Instance = row, Set = function(_, value) text.Text = tostring(value) end }
end

function Section:AddButton(options)
	local C = self.Window.Theme
	local row = self:_row(options.Title or "Button", 36)
	local control = button(row, options.Title or "Button", { Size = UDim2.fromScale(1, 1), TextColor3 = options.Primary and C.Background or C.Text, BackgroundColor3 = options.Primary and self.Window.Accent or C.Control })
	if not options.Primary then self.Window:_hover(control) end
	self.Window:_connect(control.Activated, function() emit(options.Callback) end)
	return { Instance = row }
end

function Section:AddToggle(options)
	local C = self.Window.Theme
	local window = self.Window
	local row = self:_row(options.Title or "Toggle", 36)
	local hit = button(row, "", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	label(hit, options.Title or "Toggle", { Size = UDim2.new(1, -54, 1, 0) })
	local track = round(frame(hit, { BackgroundColor3 = C.Control, Position = UDim2.new(1, options.Checkbox and -22 or -38, 0.5, -10), Size = UDim2.fromOffset(options.Checkbox and 20 or 38, 20) }), options.Checkbox and 4 or 10)
	local knob = round(frame(track, { BackgroundColor3 = C.Muted, Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(14, 14), Visible = not options.Checkbox }), 7)
	local check = options.Checkbox and label(track, "✓", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Background })
	local value = options.Default == true
	local handle = { Instance = row }
	function handle:Get() return value end
	function handle:Set(nextValue, silent)
		assert(type(nextValue) == "boolean", "Toggle value must be boolean")
		local changed = value ~= nextValue; value = nextValue
		window:_tween(track, { BackgroundColor3 = value and window.Accent or C.Control })
		window:_tween(knob, { Position = UDim2.fromOffset(value and 21 or 3, 3), BackgroundColor3 = value and C.Text or C.Muted })
		if check then check.Visible = value end
		if changed and not silent then emit(options.Callback, value) end
	end
	window:_connect(hit.Activated, function() handle:Set(not value) end)
	handle:Set(value, true)
	return handle
end

function Section:AddSlider(options)
	local C = self.Window.Theme
	local min, max, step = options.Min or 0, options.Max or 100, options.Step or 1
	assert(finite(min) and finite(max) and max > min and finite(step) and step > 0, "Slider requires finite Min < Max and Step > 0")
	local window = self.Window
	local row = self:_row(options.Title or "Slider", 60)
	label(row, options.Title or "Slider", { Size = UDim2.new(1, -90, 0, 24) })
	local number = label(row, "", { Position = UDim2.new(1, -86, 0, 0), Size = UDim2.fromOffset(86, 24), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, TextColor3 = window.Accent })
	local minus = button(row, "−", { Position = UDim2.fromOffset(0, 30), Size = UDim2.fromOffset(24, 24) })
	local plus = button(row, "+", { Position = UDim2.new(1, -24, 0, 30), Size = UDim2.fromOffset(24, 24) })
	local hit = button(row, "", { Position = UDim2.fromOffset(34, 30), Size = UDim2.new(1, -68, 0, 24), BackgroundTransparency = 1 })
	local track = round(frame(hit, { Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C.Control }), 2)
	local fill = round(frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = window.Accent }), 2)
	local knob = round(frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.Text }), 5)
	local value
	local handle = { Instance = row }
	function handle:Get() return value end
	function handle:Set(nextValue, silent)
		assert(finite(nextValue), "Slider value must be finite")
		nextValue = math.clamp(nextValue, min, max)
		nextValue = nextValue == max and max or math.clamp(min + math.floor((nextValue - min) / step + 0.5) * step, min, max)
		local changed = value ~= nextValue; value = nextValue
		local alpha = (value - min) / (max - min)
		number.Text = string.format("%.6g", value) .. (options.Suffix or "")
		window:_tween(fill, { Size = UDim2.fromScale(alpha, 1) })
		window:_tween(knob, { Position = UDim2.fromScale(alpha, 0.5) })
		if changed and not silent then emit(options.Callback, value) end
	end
	local function update(p)
		if hit.AbsoluteSize.X > 0 then handle:Set(min + math.clamp((p.X - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1) * (max - min)) end
	end
	if not window.Surface then window:_drag(hit, update, update) end
	window:_connect(minus.Activated, function() handle:Set(value - step) end)
	window:_connect(plus.Activated, function() handle:Set(value + step) end)
	window:_connect(Input.InputBegan, function(input, processed)
		if processed or not available(row) or window.Dialog or GuiService.SelectedObject ~= hit then return end
		if input.KeyCode == Enum.KeyCode.Left then handle:Set(value - step)
		elseif input.KeyCode == Enum.KeyCode.Right then handle:Set(value + step) end
	end)
	handle:Set(options.Default or min, true)
	return handle
end

function Section:AddDropdown(options)
	local C, window = self.Window.Theme, self.Window
	local scope = window.BuildScope
	local row = self:_row(options.Title or "Dropdown", 64)
	label(row, options.Title or "Dropdown", { TextColor3 = C.Muted, TextSize = 12 })
	local hit = button(row, "", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 32), TextXAlignment = Enum.TextXAlignment.Left })
	padding(hit, 8)
	local menu = frame(row, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 192), Visible = false })
	local search = round(make("TextBox", { BackgroundColor3 = C.Control, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 28), Font = Enum.Font.Gotham, TextSize = 12, Text = "", PlaceholderText = "Filter options...", PlaceholderColor3 = C.Muted, TextColor3 = C.Text, ClearTextOnFocus = false }, menu), 6)
	local choices = make("ScrollingFrame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, menu)
	list(choices, 2)
	local items, value, open, choiceButtons = {}, options.Multi and {} or nil, false, {}
	local itemConnections = {}
	local handle = { Instance = row }
	local function expand(state)
		open = state; menu.Visible = state
		row.Size = UDim2.new(1, 0, 0, state and 262 or 64)
	end
	local function render()
		hit.Text = (options.Multi and (#value == 0 and "None" or table.concat(value, ", ")) or value or "None") .. "  ⌄"
		for item, option in pairs(choiceButtons) do
			local selected = options.Multi and table.find(value, item) ~= nil or value == item
			option.Text = (selected and "✓  " or "    ") .. item
			option.TextColor3 = selected and window.Accent or C.Text
			option.Visible = string.find(string.lower(item), string.lower(search.Text), 1, true) ~= nil
		end
	end
	function handle:Get() return options.Multi and table.clone(value) or value end
	function handle:Set(nextValue, silent)
		if options.Multi then
			assert(type(nextValue) == "table", "Multiselect value must be an array")
			local selected = {}
			for _, item in ipairs(nextValue) do assert(table.find(items, item), "Unknown dropdown item"); selected[item] = true end
			nextValue = {}
			for _, item in ipairs(items) do if selected[item] then table.insert(nextValue, item) end end
		else assert(nextValue == nil and #items == 0 or table.find(items, nextValue), "Unknown dropdown item") end
		local changed = options.Multi and table.concat(value, "\0") ~= table.concat(nextValue, "\0") or not options.Multi and value ~= nextValue
		value = nextValue; render()
		if not options.Multi then expand(false) end
		if changed and not silent then emit(options.Callback, self:Get()) end
	end
	function handle:SetItems(nextItems, silent)
		assert(type(nextItems) == "table", "Items must be an array")
		local unique = {}
		for _, item in ipairs(nextItems) do
			assert(type(item) == "string" and not unique[item] and not string.find(item, "\0", 1, true), "Items must be unique strings without null bytes")
			unique[item] = true
		end
		items = table.clone(nextItems)
		for _, connection in ipairs(itemConnections) do connection:Disconnect(); window.Connections[connection] = nil; if scope then scope[connection] = nil end end
		table.clear(itemConnections)
		for _, option in pairs(choiceButtons) do option:Destroy() end
		table.clear(choiceButtons)
		for index, item in ipairs(items) do
			local option = button(choices, item, { Size = UDim2.new(1, -4, 0, 30), LayoutOrder = index, TextXAlignment = Enum.TextXAlignment.Left })
			choiceButtons[item] = option
			table.insert(itemConnections, window:_connect(option.Activated, function()
				if options.Multi then
					local nextValue = handle:Get(); local found = table.find(nextValue, item)
					if found then table.remove(nextValue, found) else table.insert(nextValue, item) end
					handle:Set(nextValue)
				else handle:Set(item) end
			end, scope))
		end
		if options.Multi then
			local retained = {}; for _, item in ipairs(value) do if unique[item] then table.insert(retained, item) end end
			self:Set(retained, silent)
		else self:Set(unique[value] and value or items[1], silent) end
	end
	window:_hover(hit)
	window:_connect(hit.Activated, function() expand(not open) end)
	window:_connect(search:GetPropertyChangedSignal("Text"), render)
	handle:SetItems(options.Items or {}, true)
	if options.Default ~= nil then handle:Set(options.Default, true) end
	return handle
end

function Section:AddInput(options)
	local C, window = self.Window.Theme, self.Window
	local multiline = options.Multiline == true
	local height = multiline and (options.Height or 128) or 64
	local row = self:_row(options.Title or "Input", height)
	label(row, options.Title or "Input", { TextColor3 = C.Muted, TextSize = 12 })
	local box = round(make("TextBox", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -32), BackgroundColor3 = C.Control, BorderSizePixel = 0, Text = "", PlaceholderText = options.Placeholder or "Type here...", PlaceholderColor3 = C.Muted, TextColor3 = C.Text, Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center, MultiLine = multiline, TextWrapped = multiline }, row), 6)
	padding(box, 8)
	local border = make("UIStroke", { Color = C.Line, Transparency = 1 }, box)
	local value
	local handle = { Instance = row, TextBox = box }
	function handle:Get() return value end
	function handle:Set(nextValue, silent)
		nextValue = tostring(nextValue)
		if options.MaxLength then assert(utf8.len(nextValue) and utf8.len(nextValue) <= options.MaxLength, "Input exceeds MaxLength") end
		if options.Validate then
			local valid, reason = options.Validate(nextValue)
			assert(valid, reason or "Invalid input")
		end
		local changed = value ~= nextValue; value = nextValue; box.Text = value
		border.Transparency = 1; self.Error = nil
		if changed and not silent then emit(options.Callback, value) end
	end
	window:_connect(box.FocusLost, function()
		local ok, err = pcall(handle.Set, handle, box.Text)
		if not ok then
			handle.Error = tostring(err); box.Text = value
			border.Color = Color3.fromRGB(230, 108, 125); border.Transparency = 0
			emit(options.OnInvalid, handle.Error)
		end
	end)
	handle:Set(options.Default or "", true)
	return handle
end

function Section:AddViewport(options)
	local C = self.Window.Theme
	options = options or {}
	local window = self.Window
	local row = self:_row(options.Title or "Model preview", options.Height or 260)
	label(row, options.Title or "Model preview", { TextColor3 = C.Muted, TextSize = 12 })
	local viewport = round(make("ViewportFrame", { Name = "Viewport", BackgroundColor3 = C.Background, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -66), Ambient = Color3.fromRGB(165, 164, 190), LightColor = Color3.fromRGB(240, 230, 255), LightDirection = Vector3.new(-1, -1, -1), Active = true }, row), 8)
	local world = make("WorldModel", {}, viewport)
	local camera = make("Camera", { FieldOfView = 40 }, viewport)
	viewport.CurrentCamera = camera
	local hint = label(viewport, "No model", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Muted })
	local initialYaw = options.Yaw or 0.5
	local yaw, pitch, zoom, radius = initialYaw, 0.18, 1, 3
	local target = Vector3.zero
	local model, dragging, last
	local autoRotate = options.AutoRotate == true
	local handle = { Instance = row, Viewport = viewport, World = world, Camera = camera, StatusLabel = hint }
	local function draw()
		local aspect = viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y)
		local halfFov = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * math.min(1, aspect))
		local distance = radius / math.sin(math.max(0.01, halfFov)) * 1.12 * zoom
		local direction = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
		camera.CFrame = CFrame.lookAt(target + direction * distance, target)
		camera.Focus = CFrame.new(target)
	end
	function handle:SetModel(source)
		assert(source == nil or (typeof(source) == "Instance" and (source:IsA("Model") or source:IsA("BasePart"))), "Viewport expects a Model or BasePart")
		local clone
		if source then clone = source:Clone(); assert(clone, "Viewport source must be Archivable") end
		if model then model:Destroy(); model = nil end
		if clone then
			-- Strip executable descendants before parenting the clone anywhere live.
			for _, child in ipairs(clone:GetDescendants()) do
				if child:IsA("LuaSourceContainer") then child:Destroy()
				elseif child:IsA("BasePart") then child.Anchored = true; child.CanCollide = false end
			end
			model = make("Model", { Name = "PreviewModel" }, world)
			if clone:IsA("BasePart") then clone.Anchored = true; clone.CanCollide = false end
			clone.Parent = model
			local bounds, size = model:GetBoundingBox()
			target = bounds.Position; radius = math.max(0.1, size.Magnitude / 2)
		end
		hint.Visible = model == nil
		zoom = 1; draw()
	end
	function handle:SetAutoRotate(value) autoRotate = value == true end
	function handle:ResetCamera() yaw, pitch, zoom = initialYaw, 0.18, 1; draw() end
	local titles = { "↶", "↷", "−", "+", "Reset" }
	for index, title in ipairs(titles) do
		local control = button(row, title, { Position = UDim2.new((index - 1) / 5, 0, 1, -30), Size = UDim2.new(0.2, -4, 0, 28), TextSize = 12 })
		window:_hover(control)
		window:_connect(control.Activated, function()
			if index == 1 then yaw -= 0.25 elseif index == 2 then yaw += 0.25
			elseif index == 3 then zoom = math.min(4, zoom * 1.15)
			elseif index == 4 then zoom = math.max(0.65, zoom / 1.15)
			else handle:ResetCamera() end
			draw()
		end)
	end
	if not window.Surface then
		window:_drag(viewport, function(p) dragging = true; last = p end, function(p)
			yaw -= (p.X - last.X) * 0.01
			pitch = math.clamp(pitch + (p.Y - last.Y) * 0.01, -1.3, 1.3)
			last = p; draw()
		end, function() dragging = false end)
		window:_connect(viewport.InputChanged, function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then zoom = math.clamp(zoom * (0.9 ^ input.Position.Z), 0.65, 4); draw() end
		end)
	end
	window:_connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), draw)
	window:_connect(camera:GetPropertyChangedSignal("FieldOfView"), draw)
	window:_connect(RunService.RenderStepped, function(dt)
		if model and autoRotate and not dragging and not window.App.ReducedMotion and available(row) then
			yaw += dt * 0.35; draw()
		end
	end)
	handle:SetModel(options.Model)
	return handle
end

local buildToggle, buildDropdown, buildInput, buildViewport = Section.AddToggle, Section.AddDropdown, Section.AddInput, Section.AddViewport

function Section:AddCheckbox(options)
	options = table.clone(options); options.Checkbox = true
	return buildToggle(self, options)
end

function Section:AddMultiDropdown(options)
	options = table.clone(options); options.Multi = true
	return buildDropdown(self, options)
end

function Section:AddTextArea(options)
	options = table.clone(options); options.Multiline = true
	return buildInput(self, options)
end

function Section:AddNumberInput(options)
	local low, high, step = options.Min or -1e9, options.Max or 1e9, options.Step or 1
	assert(finite(low) and finite(high) and high > low and finite(step) and step > 0, "Number input requires finite Min < Max, Step > 0")
	local opts = table.clone(options)
	opts.Default = tostring(options.Default or math.clamp(0, low, high))
	opts.Validate = function(text)
		local value = tonumber(text)
		return finite(value), "Enter a finite number"
	end
	opts.Callback = function(value) emit(options.Callback, tonumber(value)) end
	local handle = buildInput(self, opts)
	local get, set = handle.Get, handle.Set
	function handle:Get() return tonumber(get(self)) end
	function handle:Set(value, silent)
		value = tonumber(value); assert(finite(value), "Enter a finite number")
		value = math.clamp(value, low, high)
		value = value == high and high or math.clamp(low + math.floor((value - low) / step + 0.5) * step, low, high)
		set(self, string.format("%.12g", value), silent)
	end
	handle.TextBox.Size = UDim2.new(1, -64, 1, -32)
	for index, sign in ipairs({ -1, 1 }) do
		local hit = button(handle.Instance, sign == 1 and "+" or "−", { Position = UDim2.new(1, -64 + index * 30 - 26, 0, 28), Size = UDim2.fromOffset(26, 32) })
		self.Window:_connect(hit.Activated, function() handle:Set(handle:Get() + sign * step) end)
	end
	handle:Set(options.Default or math.clamp(0, low, high), true)
	return handle
end

function Section:AddKeybind(options)
	local window, app = self.Window, self.Window.App
	assert(options.Mode == nil or options.Mode == "Press" or options.Mode == "Hold" or options.Mode == "Toggle", "Keybind Mode must be Press, Hold, or Toggle")
	local row = self:_row(options.Title or "Keybind", 36)
	label(row, options.Title or "Keybind", { Size = UDim2.new(1, -108, 1, 0) })
	local hit = button(row, "", { Position = UDim2.new(1, -102, 0, 2), Size = UDim2.fromOffset(102, 32) })
	local key, state = Enum.KeyCode.Unknown, false
	local handle = { Instance = row }
	local function stop()
		if state and options.Mode == "Hold" then state = false; emit(options.Callback, false) end
		if app.Capturing == handle then app.Capturing = nil; hit.Text = key == Enum.KeyCode.Unknown and "Unbound" or key.Name end
	end
	function handle:Get() return key end
	function handle:GetState() return state end
	function handle:Set(nextKey, silent)
		assert(typeof(nextKey) == "EnumItem" and nextKey.EnumType == Enum.KeyCode, "Keybind requires Enum.KeyCode")
		stop(); local changed = key ~= nextKey; key = nextKey
		hit.Text = key == Enum.KeyCode.Unknown and "Unbound" or key.Name
		if changed and not silent then emit(options.OnChanged, key) end
	end
	handle.OnDisabled = stop
	window:_connect(row.Destroying, stop)
	window:_connect(hit.Activated, function()
		if app.Capturing and app.Capturing ~= handle then app.Capturing:CancelCapture() end
		app.Capturing = handle; hit.Text = "Press a key..."
	end)
	function handle:CancelCapture() stop() end
	window:_connect(Input.InputBegan, function(input, processed)
		if app.CaptureInput == input then return end
		if app.Capturing then
			if app.Capturing ~= handle or Input:GetFocusedTextBox() or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			app.CaptureInput = input
			if input.KeyCode == Enum.KeyCode.Escape then stop()
			else handle:Set(input.KeyCode == Enum.KeyCode.Backspace and Enum.KeyCode.Unknown or input.KeyCode) end
			return
		end
		if processed or Input:GetFocusedTextBox() or window.Dialog or not row.Interactable or (options.Global == false and not available(row)) or key == Enum.KeyCode.Unknown or input.KeyCode ~= key then return end
		if options.Mode == "Toggle" then state = not state; emit(options.Callback, state)
		elseif options.Mode == "Hold" then if not state then state = true; emit(options.Callback, true) end
		else emit(options.Callback, true) end
	end)
	window:_connect(Input.InputEnded, function(input) if input.KeyCode == key and options.Mode == "Hold" then stop() end end)
	window:_connect(Input.WindowFocusReleased, stop)
	handle:Set(options.Default or Enum.KeyCode.Unknown, true)
	return handle
end

function Section:AddColorPicker(options)
	local window = self.Window
	local row = self:_row(options.Title or "Color", 34)
	local hit = button(row, options.Title or "Color", { Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Left })
	padding(hit, 8)
	local swatch = round(frame(hit, { Position = UDim2.new(1, -28, 0, -1), Size = UDim2.fromOffset(26, 20) }), 4)
	swatch:SetAttribute("AsterCustomColor", true)
	local body = frame(row, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 256), Visible = false })
	list(body, 4)
	local nested = setmetatable({ Window = window, Tab = self.Tab, Frame = body, Rows = {} }, Section)
	local value, hue, saturation, brightness, hex
	local handle = { Instance = row }
	function handle:Get() return value end
	function handle:Set(color, silent)
		assert(typeof(color) == "Color3" and finite(color.R) and finite(color.G) and finite(color.B), "Color picker expects Color3")
		color = Color3.new(math.clamp(color.R, 0, 1), math.clamp(color.G, 0, 1), math.clamp(color.B, 0, 1))
		local changed = value ~= color; value = color; swatch.BackgroundColor3 = color
		if hue then
			local h, s, v = color:ToHSV()
			hue:Set(h * 360, true); saturation:Set(s * 100, true); brightness:Set(v * 100, true)
			hex:Set("#" .. color:ToHex():upper(), true)
		end
		if changed and not silent then emit(options.Callback, color) end
	end
	local function fromSliders() handle:Set(Color3.fromHSV(hue:Get() / 360, saturation:Get() / 100, brightness:Get() / 100)) end
	hue = nested:AddSlider({ Title = "Hue", Min = 0, Max = 360, Callback = fromSliders })
	saturation = nested:AddSlider({ Title = "Saturation", Min = 0, Max = 100, Callback = fromSliders })
	brightness = nested:AddSlider({ Title = "Brightness", Min = 0, Max = 100, Callback = fromSliders })
	hex = nested:AddInput({ Title = "Hex", Default = "#FFFFFF", Validate = function(text) return string.match(text, "^#?%x%x%x%x%x%x$") ~= nil, "Use six hex digits" end, Callback = function(text) handle:Set(Color3.fromHex(text)) end })
	window:_connect(hit.Activated, function() body.Visible = not body.Visible; row.Size = UDim2.new(1, 0, 0, body.Visible and 302 or 34) end)
	handle:Set(options.Default or window.Accent, true)
	return handle
end

function Section:AddSegmented(options)
	assert(type(options.Items) == "table" and #options.Items > 0, "Segmented control needs Items")
	local items, unique = table.clone(options.Items), {}
	for _, item in ipairs(items) do assert(type(item) == "string" and not unique[item], "Items must be unique strings"); unique[item] = true end
	local row = self:_row(options.Title or "Selection", options.Radio and 28 + #items * 34 or 64)
	label(row, options.Title or "Selection", { TextSize = 12, TextColor3 = self.Window.Theme.Muted })
	local choices, value = {}, nil
	local handle = { Instance = row }
	local window = self.Window
	function handle:Get() return value end
	function handle:Set(nextValue, silent)
		assert(unique[nextValue], "Unknown selection")
		local changed = value ~= nextValue; value = nextValue
		for item, hit in pairs(choices) do
			window:_tween(hit, { BackgroundColor3 = item == value and window.Accent or window.Theme.Control, TextColor3 = item == value and window.Theme.Background or window.Theme.Text })
			if options.Radio then hit.Text = (item == value and "●  " or "○  ") .. item end
		end
		if changed and not silent then emit(options.Callback, value) end
	end
	for index, item in ipairs(items) do
		local hit = button(row, item, { Position = UDim2.new((index - 1) / #items, 0, 0, 28), Size = UDim2.new(1 / #items, -4, 0, 32), TextSize = 11 })
		if options.Radio then hit.Position = UDim2.fromOffset(0, 28 + (index - 1) * 34); hit.Size = UDim2.new(1, 0, 0, 30) end
		choices[item] = hit
		window:_connect(hit.Activated, function() handle:Set(item) end)
	end
	handle:Set(options.Default or items[1], true)
	return handle
end

local buildSegmented = Section.AddSegmented
function Section:AddRadioGroup(options)
	options = table.clone(options); options.Radio = true
	return buildSegmented(self, options)
end

function Section:AddDivider(options)
	local row = self:_row(options.Title or "Divider", options.Title and 24 or 10)
	if options.Title then label(row, options.Title, { TextSize = 10, TextColor3 = self.Window.Theme.Muted }) end
	frame(row, { BackgroundColor3 = self.Window.Theme.Line, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1) })
	return { Instance = row }
end

function Section:AddProgress(options)
	local row = self:_row(options.Title or "Progress", 46)
	local text = label(row, "", { Size = UDim2.new(1, 0, 0, 26) })
	local track = round(frame(row, { BackgroundColor3 = self.Window.Theme.Control, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 6) }), 3)
	local fill = round(frame(track, { BackgroundColor3 = self.Window.Accent, Size = UDim2.fromScale(0, 1) }), 3)
	local window, value = self.Window, 0
	local handle = { Instance = row }
	function handle:Get() return value end
	function handle:Set(nextValue)
		assert(finite(nextValue), "Progress must be finite")
		value = math.clamp(nextValue, 0, 1)
		text.Text = (options.Title or "Progress") .. "  ·  " .. math.floor(value * 100 + 0.5) .. "%"
		window:_tween(fill, { Size = UDim2.fromScale(value, 1) })
	end
	handle:Set(options.Default or 0)
	return handle
end

function Section:AddImage(options)
	local row = self:_row(options.Title or "Image", options.Height or 160)
	local picture = round(make("ImageLabel", { BackgroundColor3 = self.Window.Theme.Background, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Image = options.Image or "", ScaleType = options.ScaleType or Enum.ScaleType.Fit }, row), 8)
	return { Instance = row, Image = picture, Set = function(_, content) picture.Image = content end }
end

function Section:AddTable(options)
	assert(type(options.Columns) == "table" and #options.Columns > 0, "Table needs Columns")
	local columns = table.clone(options.Columns)
	local row = self:_row(options.Title or "Table", options.Height or 200)
	local header = frame(row, { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = self.Window.Theme.Control })
	local body = make("ScrollingFrame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, row)
	list(body, 2)
	for index, name in ipairs(columns) do label(header, tostring(name), { Position = UDim2.new((index - 1) / #columns, 6, 0, 0), Size = UDim2.new(1 / #columns, -10, 1, 0), TextSize = 11 }) end
	local handle = { Instance = row }
	function handle:SetRows(rows)
		assert(type(rows) == "table", "Rows must be an array")
		for _, cells in ipairs(rows) do assert(type(cells) == "table", "Each row must be an array") end
		for _, child in ipairs(body:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
		for index, cells in ipairs(rows) do
			local line = frame(body, { Size = UDim2.new(1, -4, 0, 28), BackgroundTransparency = index % 2 == 0 and 0.5 or 1, LayoutOrder = index })
			for col = 1, #columns do label(line, tostring(cells[col] or ""), { Position = UDim2.new((col - 1) / #columns, 6, 0, 0), Size = UDim2.new(1 / #columns, -10, 1, 0), TextSize = 11 }) end
		end
	end
	handle:SetRows(options.Rows or {})
	return handle
end

function Section:AddStats(options)
	local window = self.Window
	local items = options.Items or { "FPS", "Ping", "Session" }
	local supported = { FPS = true, Ping = true, Memory = true, Players = true, Clock = true, Session = true }
	local seen = {}
	for _, name in ipairs(items) do assert(supported[name] and not seen[name], "Unknown or duplicate stat"); seen[name] = true end
	local interval = options.Interval or 0.5
	assert(finite(interval) and interval >= 0.1, "Stats interval must be at least 0.1 seconds")
	local row = self:_row(options.Title or "Live stats", 26 + #items * 30)
	label(row, options.Title or "LIVE STATS", { TextSize = 10, TextColor3 = window.Accent })
	local labels, values = {}, {}
	for index, name in ipairs(items) do
		label(row, name, { Position = UDim2.fromOffset(0, 26 + (index - 1) * 30), Size = UDim2.new(0.45, 0, 0, 28), TextColor3 = window.Theme.Muted, TextSize = 12 })
		labels[name] = label(row, "—", { Position = UDim2.new(0.45, 0, 0, 26 + (index - 1) * 30), Size = UDim2.new(0.55, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12 })
	end
	local elapsed, frames = 0, 0
	window:_connect(RunService.RenderStepped, function(dt)
		elapsed += dt; frames += 1
		if elapsed < interval then return end
		values.FPS = math.floor(frames / elapsed + 0.5)
		elapsed, frames = 0, 0
		if not available(row) then return end
		if seen.Ping then
			local ok, ping = pcall(Players.LocalPlayer.GetNetworkPing, Players.LocalPlayer)
			values.Ping = ok and finite(ping) and math.floor(ping * 1000 + 0.5) or nil
		end
		if seen.Memory then
			local ok, memory = pcall(Stats.GetTotalMemoryUsageMb, Stats)
			values.Memory = ok and finite(memory) and memory or nil
		end
		values.Players = #Players:GetPlayers()
		values.Clock = os.date("%H:%M:%S")
		local seconds = math.floor(os.clock() - window.App.Started)
		values.Session = string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
		for name, text in pairs(labels) do
			local value = values[name]
			text.Text = value == nil and "Unavailable" or (name == "Memory" and string.format("%.1f MB", value) or tostring(value) .. (name == "Ping" and " ms" or ""))
		end
	end)
	return { Instance = row, GetStats = function() return table.clone(values) end }
end

local buildStats = Section.AddStats
function Section:AddFPSCounter(options)
	options = table.clone(options); options.Items = { "FPS" }; options.Title = options.Title or "Performance"
	return buildStats(self, options)
end

function Section:AddPlayerCard(options)
	local row = self:_row(options.Title or "Player", 64)
	local image = round(make("ImageLabel", { BackgroundColor3 = self.Window.Theme.Control, BorderSizePixel = 0, Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(0, 5), Image = "" }, row), 10)
	local title = label(row, "", { Position = UDim2.fromOffset(66, 8), Size = UDim2.new(1, -66, 0, 24), Font = Enum.Font.GothamMedium })
	local subtitle = label(row, "", { Position = UDim2.fromOffset(66, 32), Size = UDim2.new(1, -66, 0, 24), TextSize = 11, TextColor3 = self.Window.Theme.Muted })
	local revision = 0
	local handle = { Instance = row, Image = image }
	function handle:SetPlayer(player)
		assert(typeof(player) == "Instance" and player:IsA("Player"), "Expected Player")
		revision += 1; local request = revision
		title.Text = player.DisplayName; subtitle.Text = "@" .. player.Name; image.Image = ""
		self.Status, self.Error = "Loading", nil
		task.spawn(function()
			local ok, content, ready = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			if handle.Destroyed or not row.Parent or request ~= revision then return end
			if ok and ready then image.Image = content; handle.Status = "Ready"
			else handle.Status = "Error"; handle.Error = ok and "Thumbnail is not ready; call SetPlayer to retry" or tostring(content) end
		end)
	end
	handle:SetPlayer(options.Player or Players.LocalPlayer)
	return handle
end

function Section:AddAvatarPreview(options)
	local opts = table.clone(options); opts.Model = nil; opts.Title = options.Title or "Avatar preview"; opts.Yaw = options.Yaw or math.pi + 0.3
	local handle = buildViewport(self, opts)
	local player = options.Player or Players.LocalPlayer
	local userId = options.UserId or player.UserId
	local revision = 0
	function handle:SetUserId(id)
		assert(finite(id) and id % 1 == 0, "UserId must be an integer")
		userId = id; revision += 1; local request = revision
		self.Status, self.Error = "Loading", nil
		self:SetModel(nil)
		self.StatusLabel.Text = "Loading avatar..."; self.StatusLabel.Visible = true
		task.spawn(function()
			local ok, result = pcall(function()
				-- Studio test players can have nonpositive IDs; live character descriptions still work.
				if id == player.UserId and player.Character and options.UserId == nil then
					local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local description = humanoid:GetAppliedDescription()
						local success, model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, humanoid.RigType)
						description:Destroy()
						if not success then error(model) end
						return model
					end
				end
				assert(id > 0, "Avatar unavailable until this player has a character")
				return Players:CreateHumanoidModelFromUserIdAsync(id)
			end)
			if handle.Destroyed or not handle.Instance.Parent or request ~= revision then
				if ok then result:Destroy() end
				return
			end
			if ok then
				local loaded, err = pcall(handle.SetModel, handle, result)
				result:Destroy()
				if loaded then handle.Status = "Ready"; emit(options.OnLoaded, handle); return end
				result = err
			end
			handle.Status, handle.Error = "Error", tostring(result)
			handle.StatusLabel.Text = "Avatar unavailable · refresh to retry"
			handle.StatusLabel.Visible = true
			emit(options.OnError, handle.Error)
		end)
	end
	function handle:Refresh() self:SetUserId(userId) end
	if options.UserId == nil and options.FollowPlayer ~= false then
		self.Window:_connect(player.CharacterAppearanceLoaded, function() handle:Refresh() end)
	end
	handle:SetUserId(userId)
	return handle
end

function Window:SetTheme(nameOrColors)
	local nextTheme = type(nameOrColors) == "string" and Themes[nameOrColors] or nameOrColors
	assert(type(nextTheme) == "table", "Expected theme name or color table")
	for key, color in pairs(nextTheme) do assert(C[key] and typeof(color) == "Color3", "Unknown theme token or non-Color3 value") end
	local old = table.clone(self.Theme)
	for object, tween in pairs(self.Tweens) do
		tween:Cancel()
		if object.Parent then for key, value in pairs(self.TweenGoals[object] or {}) do object[key] = value end end
	end
	table.clear(self.Tweens)
	for key, color in pairs(nextTheme) do self.Theme[key] = color end
	self.Accent = self.Theme.Accent
	local function recolor(object, property)
		local color = object[property]
		for token, previous in pairs(old) do if color == previous then object[property] = self.Theme[token]; break end end
	end
	for _, object in ipairs(self.Gui:GetDescendants()) do
		if object:IsA("GuiObject") then
			if not object:GetAttribute("AsterCustomColor") then recolor(object, "BackgroundColor3") end
			if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then recolor(object, "TextColor3") end
			if object:IsA("TextBox") then recolor(object, "PlaceholderColor3") end
			if object:IsA("ScrollingFrame") then recolor(object, "ScrollBarImageColor3") end
		elseif object:IsA("UIStroke") then recolor(object, "Color") end
	end
	table.clear(self.TweenGoals)
	self:Focus()
end

local function disconnectScope(window, scope)
	for connection in pairs(scope) do connection:Disconnect(); window.Connections[connection] = nil end
	table.clear(scope)
end

function Window:Notify(options)
	assert(not self.Destroyed, "Window is destroyed")
	options = options or {}
	local duration = options.Duration == nil and 4 or options.Duration
	assert(finite(duration) and duration >= 0, "Duration must be finite and nonnegative")
	if not self.ToastStack then
		self.Toasts = {}
		self.ToastStack = frame(self.Root, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -16), Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 50 })
		local layout = list(self.ToastStack, 8); layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
	while #self.Toasts >= 4 do self.Toasts[1]:Dismiss() end
	local scope, window = {}, self
	local card = round(frame(self.ToastStack, { Size = UDim2.new(1, 0, 0, 88), BackgroundColor3 = self.Theme.Control, Active = true }), 8)
	make("UIStroke", { Color = self.Accent, Transparency = 0.45 }, card)
	label(card, options.Title or "Notice", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -48, 0, 22), Font = Enum.Font.GothamMedium })
	label(card, options.Text or "", { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 46), TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextColor3 = self.Theme.Muted })
	local close = button(card, "×", { Position = UDim2.new(1, -32, 0, 6), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1 })
	local handle = { Instance = card }
	local timer
	function handle:Dismiss()
		if self.Dismissed then return end
		self.Dismissed = true; disconnectScope(window, scope)
		if timer and timer ~= coroutine.running() then task.cancel(timer) end
		timer = nil
		local index = table.find(window.Toasts, self); if index then table.remove(window.Toasts, index) end
		card:Destroy()
	end
	self:_connect(close.Activated, function() handle:Dismiss() end, scope)
	self:_connect(card.Destroying, function() handle:Dismiss() end, scope)
	table.insert(self.Toasts, handle)
	if duration > 0 then timer = task.delay(duration, function() handle:Dismiss() end) end
	return handle
end

function Window:ShowDialog(options)
	assert(not self.Destroyed, "Window is destroyed")
	options = options or {}
	if self.Dialog then self.Dialog:Close(false) end
	local window, scope = self, {}
	local overlay = button(self.Root, "", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 100, Selectable = false })
	overlay:SetAttribute("AsterCustomColor", true)
	local panel = round(frame(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.8, 0, 0, 210), Active = true }), 10)
	label(panel, options.Title or "Confirm", { Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 28), Font = Enum.Font.GothamBold, TextSize = 16 })
	label(panel, options.Text or "", { Position = UDim2.fromOffset(20, 52), Size = UDim2.new(1, -40, 0, 88), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextColor3 = self.Theme.Muted })
	local cancel = button(panel, options.CancelText or "Cancel", { Position = UDim2.new(0, 20, 1, -54), Size = UDim2.new(0.5, -26, 0, 34) })
	local confirm = button(panel, options.ConfirmText or "Confirm", { Position = UDim2.new(0.5, 6, 1, -54), Size = UDim2.new(0.5, -26, 0, 34), BackgroundColor3 = self.Accent, TextColor3 = self.Theme.Background })
	local previousSelection = GuiService.SelectedObject
	local handle = { Instance = overlay }
	function handle:Close(accepted)
		if self.Closed then return end
		self.Closed = true; disconnectScope(window, scope); window.Dialog = nil
		overlay:Destroy()
		if previousSelection and previousSelection.Parent and available(previousSelection) then GuiService.SelectedObject = previousSelection else GuiService.SelectedObject = nil end
		if not window.Destroyed then emit(options.Callback, accepted == true) end
	end
	self:_connect(cancel.Activated, function() handle:Close(false) end, scope)
	self:_connect(confirm.Activated, function() handle:Close(true) end, scope)
	self:_connect(Input.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then handle:Close(false) end
	end, scope)
	cancel.NextSelectionRight = confirm; confirm.NextSelectionLeft = cancel
	cancel.NextSelectionUp = cancel; cancel.NextSelectionDown = cancel
	confirm.NextSelectionUp = confirm; confirm.NextSelectionDown = confirm
	cancel.NextSelectionLeft = confirm; confirm.NextSelectionRight = cancel
	self.Dialog = handle
	self:SetVisible(true); self:Minimize(false)
	GuiService.SelectedObject = cancel
	return handle
end

function Window:_tooltip(row, text, scope)
	if not self.Tooltip then
		self.Tooltip = round(label(self.Root, "", { BackgroundColor3 = self.Theme.Control, BackgroundTransparency = 0, Size = UDim2.fromOffset(280, 56), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextSize = 12, ZIndex = 90, Visible = false }), 6)
		padding(self.Tooltip, 8)
	end
	local function hide() if self.TooltipOwner == row then self.Tooltip.Visible = false; self.TooltipOwner = nil end end
	local function show()
		if not available(row) or self.Dialog then return end
		local position = (row.AbsolutePosition - self.Root.AbsolutePosition) / self.Scale.Scale
		self.Tooltip.Position = UDim2.fromOffset(math.clamp(position.X, 8, self.Width - 288), math.clamp(position.Y + row.AbsoluteSize.Y / self.Scale.Scale + 6, 8, self.Height - 64))
		self.Tooltip.Text = text; self.Tooltip.Visible = true; self.TooltipOwner = row
	end
	self:_connect(row.MouseEnter, show, scope)
	self:_connect(row.MouseLeave, hide, scope)
	self:_connect(row:GetPropertyChangedSignal("Visible"), hide, scope)
	self:_connect(row.Destroying, hide, scope)
end

local function encodeValue(value)
	if typeof(value) == "Color3" then return { Type = "Color3", Hex = value:ToHex() } end
	if typeof(value) == "EnumItem" then return { Type = "KeyCode", Name = value.Name } end
	return value
end

local function decodeValue(value)
	if type(value) == "table" and value.Type then
		if value.Type == "Color3" then
			assert(type(value.Hex) == "string" and value.Hex:match("^%x%x%x%x%x%x$"), "Invalid color in config")
			return Color3.fromHex(value.Hex)
		end
		assert(value.Type == "KeyCode" and type(value.Name) == "string", "Unknown config value type")
		return Enum.KeyCode[value.Name]
	end
	return value
end

function Window:ExportConfig()
	local values = {}
	for id, handle in pairs(self.Flags) do values[id] = encodeValue(handle:Get()) end
	return HttpService:JSONEncode({ Version = 1, Values = values })
end

function Window:ImportConfig(json, silent)
	local config = HttpService:JSONDecode(json)
	assert(type(config) == "table" and config.Version == 1 and type(config.Values) == "table", "Invalid Aster config")
	local updates, previous = {}, {}
	for id, encoded in pairs(config.Values) do
		local handle = self.Flags[id]
		assert(handle, "Unknown config ID: " .. tostring(id))
		local value = decodeValue(encoded)
		assert(typeof(value) == typeof(handle:Get()), "Wrong config type for " .. id)
		updates[id] = value; previous[id] = handle:Get()
	end
	local ok, err = pcall(function() for id, value in pairs(updates) do self.Flags[id]:Set(value, true) end end)
	if not ok then
		for id, value in pairs(previous) do self.Flags[id]:Set(value, true) end
		error("Config rejected; values restored: " .. tostring(err), 2)
	end
	if silent == false then
		for id, old in pairs(previous) do
			local handle = self.Flags[id]
			if HttpService:JSONEncode(encodeValue(old)) ~= HttpService:JSONEncode(encodeValue(handle:Get())) then emit(handle.ChangeCallback, handle:Get()) end
		end
	end
end

-- Give every widget the same lifecycle. Nested widgets get their own connection scopes.
for name, builder in pairs(table.clone(Section)) do
	if string.sub(name, 1, 3) == "Add" then
		Section[name] = function(self, options)
			options = options or {}
			local window = self.Window
			assert(not window.Destroyed, "Window is destroyed")
			if options.Id then assert(type(options.Id) == "string" and options.Id ~= "" and not window.Flags[options.Id], "Control ID must be a unique nonempty string") end
			local scope, previousScope, rowCount = {}, window.BuildScope, #self.Rows
			window.BuildScope = scope
			local ok, handle = pcall(builder, self, options)
			window.BuildScope = previousScope
			if not ok then
				disconnectScope(window, scope)
				while #self.Rows > rowCount do local entry = table.remove(self.Rows); entry.Frame:Destroy() end
				error(handle, 2)
			end
			local row, section = handle.Instance, self
			local entry
			for _, item in ipairs(self.Rows) do if item.Frame == row then entry = item; break end end
			local interactions = setmetatable({}, { __mode = "k" })
			window.Controls[handle] = true
			function handle:Destroy()
				if self.Destroyed then return end
				self.Destroyed = true
				if self.OnDisabled then self.OnDisabled() end
				if window.TooltipOwner == row then window.Tooltip.Visible = false; window.TooltipOwner = nil end
				disconnectScope(window, scope)
				window.Controls[self] = nil
				if options.Id then window.Flags[options.Id] = nil end
				for object, tween in pairs(window.Tweens) do
					if object == row or object:IsDescendantOf(row) then tween:Cancel(); window.Tweens[object] = nil; window.TweenGoals[object] = nil end
				end
				for object in pairs(window.TweenGoals) do if object == row or object:IsDescendantOf(row) then window.TweenGoals[object] = nil end end
				local index = table.find(section.Rows, entry); if index then table.remove(section.Rows, index) end
				row:Destroy()
				if not window.Destroyed then window:_filter() end
			end
			function handle:SetVisible(value)
				assert(not self.Destroyed, "Control is destroyed")
				entry.Hidden = not value; window:_filter()
			end
			local function applyInteraction(object)
				if object:IsA("GuiObject") then
					if handle.Disabled then
						if interactions[object] == nil then interactions[object] = object.Interactable end
						object.Interactable = false
					elseif interactions[object] ~= nil then object.Interactable = interactions[object]; interactions[object] = nil end
				end
			end
			function handle:SetDisabled(value)
				assert(not self.Destroyed, "Control is destroyed")
				self.Disabled = value == true
				applyInteraction(row)
				for _, object in ipairs(row:GetDescendants()) do applyInteraction(object) end
				if self.Disabled and self.OnDisabled then self.OnDisabled() end
			end
			window:_connect(row.DescendantAdded, applyInteraction, scope)
			window:_connect(row.Destroying, function() handle:Destroy() end, scope)
			if handle.Set then
				local originalSet = handle.Set
				handle.Set = function(control, ...)
					assert(not control.Destroyed, "Control is destroyed")
					return originalSet(control, ...)
				end
			end
			if handle.Get and handle.Set then
				local default = handle:Get()
				function handle:Reset(silent) self:Set(default, silent) end
			end
			handle.ChangeCallback = name == "AddKeybind" and options.OnChanged or options.Callback
			if options.Id then
				if not handle.Get or not handle.Set then handle:Destroy(); error("Only value controls accept Id", 2) end
				window.Flags[options.Id] = handle
			end
			if options.Tooltip then window:_tooltip(row, options.Tooltip, scope) end
			handle:SetDisabled(options.Disabled == true)
			if options.Visible == false then handle:SetVisible(false) end
			return handle
		end
	end
end

return Aster
