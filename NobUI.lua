local NobUI = {}
NobUI.__index = NobUI

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Modern Theme
local Theme = {
    Background = Color3.fromRGB(10, 10, 10),
    Secondary = Color3.fromRGB(15, 15, 15),
    Tertiary = Color3.fromRGB(20, 20, 20),
    Accent = Color3.fromRGB(88, 101, 242), -- Discord-like accent
    AccentDark = Color3.fromRGB(71, 82, 196),
    Text = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(185, 187, 190),
    TextDim = Color3.fromRGB(114, 118, 125),
    Success = Color3.fromRGB(87, 242, 135),
    Error = Color3.fromRGB(237, 66, 69),
    Warning = Color3.fromRGB(255, 189, 68),
    Transparency = 0.1,
    BlurSize = 24
}

-- Utility Functions
local function CreateTween(obj, props, duration, style)
    return TweenService:Create(
        obj, 
        TweenInfo.new(
            duration or 0.3, 
            style or Enum.EasingStyle.Quart, 
            Enum.EasingDirection.Out
        ), 
        props
    )
end

local function AddBlur(parent, transparency)
    local blur = Instance.new("ImageLabel")
    blur.Name = "Blur"
    blur.Size = UDim2.new(1, 0, 1, 0)
    blur.Position = UDim2.new(0, 0, 0, 0)
    blur.Image = "rbxasset://textures/ui/LuaChat/9-slice/modular-circle-2.png"
    blur.ImageColor3 = Color3.fromRGB(0, 0, 0)
    blur.ImageTransparency = transparency or 0.5
    blur.ScaleType = Enum.ScaleType.Slice
    blur.SliceCenter = Rect.new(64, 64, 192, 192)
    blur.BackgroundTransparency = 1
    blur.Parent = parent
    return blur
end

local function MakeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- Main Init
function NobUI:Init(config)
    local self = setmetatable({}, NobUI)
    self.Windows = {}
    self.Config = config or {}
    self.CloudConfig = {}
    self.Keybinds = {}
    self.ActiveKeybindMenu = nil -- Track active keybind menu
    self.ActiveDropdown = nil -- Track active dropdown
    
    -- Create ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "NobUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.ScreenGui.IgnoreGuiInset = true
    self.ScreenGui.Parent = game:GetService("CoreGui") or Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Create separate ScreenGui for pinned windows
    self.PinnedGui = Instance.new("ScreenGui")
    self.PinnedGui.Name = "NobUI_Pinned"
    self.PinnedGui.ResetOnSpawn = false
    self.PinnedGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.PinnedGui.IgnoreGuiInset = true
    self.PinnedGui.Parent = game:GetService("CoreGui") or Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Create Navbar
    self:CreateNavbar(config)
    
    -- Add RightShift toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
            self.ScreenGui.Enabled = not self.ScreenGui.Enabled
            -- Pinned windows stay visible in their separate ScreenGui
        end
    end)
    
    -- Global keybind handler
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed then
            for name, keybind in pairs(self.Keybinds) do
                if keybind.key and input.KeyCode == keybind.key then
                    if keybind.callback then
                        keybind.callback()
                    end
                end
            end
        end
    end)
    
    -- Global click handler to close dropdowns
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Close active dropdown if clicking outside
            if self.ActiveDropdown then
                local mousePos = UserInputService:GetMouseLocation()
                local dropdownPos = self.ActiveDropdown.AbsolutePosition
                local dropdownSize = self.ActiveDropdown.AbsoluteSize
                
                -- Check if click is outside dropdown
                if mousePos.X < dropdownPos.X or mousePos.X > dropdownPos.X + dropdownSize.X or
                   mousePos.Y < dropdownPos.Y or mousePos.Y > dropdownPos.Y + dropdownSize.Y then
                    -- Close the dropdown
                    if self.CloseActiveDropdown then
                        self.CloseActiveDropdown()
                    end
                end
            end
        end
    end)
    
    return self
end

-- Modern Navbar Creation
function NobUI:CreateNavbar(config)
    -- Calculate navbar width based on modules
    local moduleCount = config.Modules and #config.Modules or 3
    local navbarWidth = math.max(400, moduleCount * 120 + 300) -- Dynamic width
    
    -- Main navbar container (centered)
    local navbarContainer = Instance.new("Frame")
    navbarContainer.Name = "NavbarContainer"
    navbarContainer.Size = UDim2.new(0, navbarWidth, 0, 65)
    navbarContainer.Position = UDim2.new(0.5, -navbarWidth/2, 0, 20)
    navbarContainer.BackgroundTransparency = 1
    navbarContainer.Parent = self.ScreenGui
    
    -- Navbar background with glass effect
    local navbar = Instance.new("Frame")
    navbar.Name = "Navbar"
    navbar.Size = UDim2.new(1, 0, 1, 0)
    navbar.BackgroundColor3 = Theme.Background
    navbar.BackgroundTransparency = Theme.Transparency
    navbar.Parent = navbarContainer
    
    -- Add blur background
    AddBlur(navbar, 0.95)
    
    -- Rounded corners
    local navCorner = Instance.new("UICorner")
    navCorner.CornerRadius = UDim.new(0, 16)
    navCorner.Parent = navbar
    
    -- Subtle border
    local navStroke = Instance.new("UIStroke")
    navStroke.Color = Theme.Accent
    navStroke.Transparency = 0.95
    navStroke.Thickness = 1
    navStroke.Parent = navbar
    
    -- Shadow effect
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 1
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.BackgroundTransparency = 1
    shadow.ZIndex = 0
    shadow.Parent = navbarContainer
    
    -- Logo section (left)
    local logoSection = Instance.new("Frame")
    logoSection.Size = UDim2.new(0, 100, 1, 0)
    logoSection.BackgroundTransparency = 1
    logoSection.Parent = navbar
    
    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.new(1, -20, 1, 0)
    logoText.Position = UDim2.new(0, 20, 0, 0)
    logoText.BackgroundTransparency = 1
    logoText.Text = "nob.gg"
    logoText.TextColor3 = Theme.Accent
    logoText.Font = Enum.Font.GothamBold
    logoText.TextSize = 20
    logoText.TextXAlignment = Enum.TextXAlignment.Left
    logoText.Parent = logoSection
    
    -- Module buttons container (center)
    local moduleContainer = Instance.new("Frame")
    moduleContainer.Size = UDim2.new(1, -300, 1, -20)
    moduleContainer.Position = UDim2.new(0, 100, 0, 10)
    moduleContainer.BackgroundTransparency = 1
    moduleContainer.Parent = navbar
    
    local moduleLayout = Instance.new("UIListLayout")
    moduleLayout.FillDirection = Enum.FillDirection.Horizontal
    moduleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    moduleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    moduleLayout.Padding = UDim.new(0, 8)
    moduleLayout.Parent = moduleContainer
    
    -- Profile box (right)
    local profileBox = Instance.new("Frame")
    profileBox.Size = UDim2.new(0, 180, 0, 45)
    profileBox.Position = UDim2.new(1, -190, 0.5, -22.5)
    profileBox.BackgroundColor3 = Theme.Secondary
    profileBox.BackgroundTransparency = 0.3
    profileBox.Parent = navbar
    
    local profileCorner = Instance.new("UICorner")
    profileCorner.CornerRadius = UDim.new(0, 12)
    profileCorner.Parent = profileBox
    
    local profileStroke = Instance.new("UIStroke")
    profileStroke.Color = Theme.Accent
    profileStroke.Transparency = 0.9
    profileStroke.Thickness = 1
    profileStroke.Parent = profileBox
    
    -- Username label
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Size = UDim2.new(1, -20, 0, 20)
    usernameLabel.Position = UDim2.new(0, 10, 0, 5)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = string.format("%s (%s)", config.Username or "User", config.UID or "0")
    usernameLabel.TextColor3 = Theme.Text
    usernameLabel.Font = Enum.Font.GothamSemibold
    usernameLabel.TextSize = 14
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
    usernameLabel.Parent = profileBox
    
    -- Role label
    local roleLabel = Instance.new("TextLabel")
    roleLabel.Size = UDim2.new(1, -20, 0, 15)
    roleLabel.Position = UDim2.new(0, 10, 0, 25)
    roleLabel.BackgroundTransparency = 1
    roleLabel.Text = config.Role or "User"
    roleLabel.TextColor3 = Theme.TextSecondary
    roleLabel.Font = Enum.Font.Gotham
    roleLabel.TextSize = 12
    roleLabel.TextXAlignment = Enum.TextXAlignment.Left
    roleLabel.Parent = profileBox
    
    -- Add role color based on rank
    if config.Role == "SUPERADMIN" then
        roleLabel.TextColor3 = Theme.Error
    elseif config.Role == "ADMIN" then
        roleLabel.TextColor3 = Theme.Warning
    elseif config.Role == "PREMIUM" then
        roleLabel.TextColor3 = Theme.Accent
    end
    
    -- Create module buttons
    if config.Modules then
        for _, module in ipairs(config.Modules) do
            self:CreateModernNavButton(moduleContainer, module)
        end
    end
    
    -- Add Keybind Icon (right side, before profile box)
    local keybindIcon = Instance.new("TextButton")
    keybindIcon.Size = UDim2.new(0, 40, 0, 40)
    keybindIcon.Position = UDim2.new(1, -50, 0, 0)
    keybindIcon.BackgroundColor3 = Theme.Tertiary
    keybindIcon.BackgroundTransparency = 0.7
    keybindIcon.Text = "⌨"
    keybindIcon.TextColor3 = Theme.TextSecondary
    keybindIcon.Font = Enum.Font.Gotham
    keybindIcon.TextSize = 20
    keybindIcon.AutoButtonColor = false
    keybindIcon.Parent = navbar
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 10)
    iconCorner.Parent = keybindIcon
    
    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = Theme.Accent
    iconStroke.Transparency = 1
    iconStroke.Thickness = 1
    iconStroke.Parent = keybindIcon
    
    -- Keybind List Window (separate from navbar)
    local keybindWindow = Instance.new("Frame")
    keybindWindow.Size = UDim2.new(0, 250, 0, 300)
    keybindWindow.Position = UDim2.new(0, 100, 0, 100)
    keybindWindow.BackgroundColor3 = Theme.Background
    keybindWindow.BackgroundTransparency = 0.2
    keybindWindow.Visible = false
    keybindWindow.Parent = self.ScreenGui
    
    -- Add blur to window
    AddBlur(keybindWindow, 0.95)
    
    local windowCorner = Instance.new("UICorner")
    windowCorner.CornerRadius = UDim.new(0, 12)
    windowCorner.Parent = keybindWindow
    
    local windowStroke = Instance.new("UIStroke")
    windowStroke.Color = Theme.Accent
    windowStroke.Transparency = 0.9
    windowStroke.Thickness = 1
    windowStroke.Parent = keybindWindow
    
    -- Window shadow
    local windowShadow = Instance.new("ImageLabel")
    windowShadow.Size = UDim2.new(1, 20, 1, 20)
    windowShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    windowShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    windowShadow.Image = "rbxassetid://1316045217"
    windowShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    windowShadow.ImageTransparency = 0.7
    windowShadow.ScaleType = Enum.ScaleType.Slice
    windowShadow.SliceCenter = Rect.new(10, 10, 118, 118)
    windowShadow.BackgroundTransparency = 1
    windowShadow.ZIndex = -1
    windowShadow.Parent = keybindWindow
    
    -- Header (draggable)
    local listHeader = Instance.new("Frame")
    listHeader.Size = UDim2.new(1, 0, 0, 35)
    listHeader.BackgroundColor3 = Theme.Secondary
    listHeader.BackgroundTransparency = 0.5
    listHeader.Parent = keybindWindow
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = listHeader
    
    local headerBottom = Instance.new("Frame")
    headerBottom.Size = UDim2.new(1, 0, 0, 12)
    headerBottom.Position = UDim2.new(0, 0, 1, -12)
    headerBottom.BackgroundColor3 = Theme.Secondary
    headerBottom.BackgroundTransparency = 0.5
    headerBottom.BorderSizePixel = 0
    headerBottom.Parent = listHeader
    
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.new(1, -40, 1, 0)
    headerLabel.Position = UDim2.new(0, 10, 0, 0)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Text = "Active Keybinds"
    headerLabel.TextColor3 = Theme.Text
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextSize = 14
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.Parent = listHeader
    
    -- Keybind items container with scroll (create before pin button)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -45)
    scrollFrame.Position = UDim2.new(0, 10, 0, 40)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 2
    scrollFrame.ScrollBarImageColor3 = Theme.Accent
    scrollFrame.ScrollBarImageTransparency = 0.5
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = keybindWindow
    
    local itemsContainer = Instance.new("Frame")
    itemsContainer.Size = UDim2.new(1, 0, 0, 0)
    itemsContainer.BackgroundTransparency = 1
    itemsContainer.AutomaticSize = Enum.AutomaticSize.Y
    itemsContainer.Parent = scrollFrame
    
    local itemsLayout = Instance.new("UIListLayout")
    itemsLayout.Padding = UDim.new(0, 5)
    itemsLayout.Parent = itemsContainer
    
    local itemsPadding = Instance.new("UIPadding")
    itemsPadding.PaddingBottom = UDim.new(0, 10)
    itemsPadding.Parent = itemsContainer
    
    -- No keybinds label (separate)
    local noKeybindsLabel = Instance.new("TextLabel")
    noKeybindsLabel.Size = UDim2.new(1, 0, 0, 40)
    noKeybindsLabel.Position = UDim2.new(0, 0, 0, 0)
    noKeybindsLabel.BackgroundTransparency = 1
    noKeybindsLabel.Text = "No active keybinds"
    noKeybindsLabel.TextColor3 = Theme.TextDim
    noKeybindsLabel.Font = Enum.Font.Gotham
    noKeybindsLabel.TextSize = 12
    noKeybindsLabel.Visible = true
    noKeybindsLabel.Parent = itemsContainer
    
    -- Update canvas size
    itemsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, itemsLayout.AbsoluteContentSize.Y)
    end)
    
    -- Update function for keybind list (move this before pin button creation)
    local keybindItems = {} -- Store references to items
    
    local function updateKeybindList()
        -- Clear existing keybind items (but not the no keybinds label)
        for _, item in pairs(keybindItems) do
            item:Destroy()
        end
        keybindItems = {}
        
        -- Add active keybinds
        local hasKeybinds = false
        for name, keybind in pairs(self.Keybinds) do
            if keybind.key then
                hasKeybinds = true
                
                local keybindItem = Instance.new("Frame")
                keybindItem.Size = UDim2.new(1, 0, 0, 28)
                keybindItem.BackgroundColor3 = Theme.Tertiary
                keybindItem.BackgroundTransparency = 0.8 -- 80% transparent
                keybindItem.Parent = itemsContainer
                
                local itemCorner = Instance.new("UICorner")
                itemCorner.CornerRadius = UDim.new(0, 6)
                itemCorner.Parent = keybindItem
                
                -- Determine if it's a toggle and its state
                local isToggle = name:find("Toggle_")
                local isButton = name:find("Button_")
                local displayName = name:gsub("Toggle_", ""):gsub("Button_", ""):gsub("_", " ")
                
                -- Function name with color based on type
                local functionLabel = Instance.new("TextLabel")
                functionLabel.Size = UDim2.new(1, -60, 1, 0)
                functionLabel.Position = UDim2.new(0, 8, 0, 0)
                functionLabel.BackgroundTransparency = 1
                functionLabel.Text = displayName
                functionLabel.TextColor3 = isToggle and Theme.TextSecondary or Theme.TextSecondary
                functionLabel.Font = Enum.Font.Gotham
                functionLabel.TextSize = 12
                functionLabel.TextXAlignment = Enum.TextXAlignment.Left
                functionLabel.TextTruncate = Enum.TextTruncate.AtEnd
                functionLabel.Parent = keybindItem
                
                -- Store reference for toggle state updates
                if isToggle then
                    keybind.label = functionLabel
                end
                
                -- Key
                local keyLabel = Instance.new("TextLabel")
                keyLabel.Size = UDim2.new(0, 50, 1, 0)
                keyLabel.Position = UDim2.new(1, -55, 0, 0)
                keyLabel.BackgroundTransparency = 1
                keyLabel.Text = keybind.key.Name
                keyLabel.TextColor3 = Theme.Accent
                keyLabel.Font = Enum.Font.GothamMedium
                keyLabel.TextSize = 12
                keyLabel.TextXAlignment = Enum.TextXAlignment.Right
                keyLabel.Parent = keybindItem
                
                -- Button flash effect
                if isButton and keybind.callback then
                    local originalCallback = keybind.callback
                    keybind.callback = function()
                        -- Flash green
                        CreateTween(functionLabel, {TextColor3 = Theme.Success}, 0.1):Play()
                        task.wait(0.1)
                        CreateTween(functionLabel, {TextColor3 = Theme.TextSecondary}, 0.3):Play()
                        originalCallback()
                    end
                end
                
                -- Hover effect
                keybindItem.MouseEnter:Connect(function()
                    CreateTween(keybindItem, {BackgroundTransparency = 0.6}):Play()
                end)
                
                keybindItem.MouseLeave:Connect(function()
                    CreateTween(keybindItem, {BackgroundTransparency = 0.8}):Play()
                end)
                
                table.insert(keybindItems, keybindItem)
            end
        end
        
        -- Show/hide no keybinds message
        noKeybindsLabel.Visible = not hasKeybinds
        
        -- Update pinned window if exists
        if self.UpdatePinnedKeybinds then
            self.UpdatePinnedKeybinds()
        end
    end
    
    -- Store update function
    self.UpdateKeybindList = updateKeybindList
    
    -- Pin button (now created after scrollFrame)
    local isPinned = false
    local pinButton = Instance.new("TextButton")
    pinButton.Size = UDim2.new(0, 25, 0, 25)
    pinButton.Position = UDim2.new(1, -30, 0.5, -12.5)
    pinButton.BackgroundColor3 = Theme.Tertiary
    pinButton.BackgroundTransparency = 0.7
    pinButton.Text = "📌"
    pinButton.TextColor3 = Theme.TextSecondary
    pinButton.Font = Enum.Font.Gotham
    pinButton.TextSize = 14
    pinButton.AutoButtonColor = false
    pinButton.Parent = listHeader
    
    local pinCorner = Instance.new("UICorner")
    pinCorner.CornerRadius = UDim.new(0, 6)
    pinCorner.Parent = pinButton
    
    -- Create separate pinned window that stays in PinnedGui
    local pinnedWindow = Instance.new("Frame")
    pinnedWindow.Size = keybindWindow.Size
    pinnedWindow.Position = keybindWindow.Position
    pinnedWindow.BackgroundColor3 = Theme.Background
    pinnedWindow.BackgroundTransparency = 0.2
    pinnedWindow.Visible = false
    pinnedWindow.Parent = self.PinnedGui -- Changed to PinnedGui instead of CoreGui
    
    -- Clone appearance for pinned window
    local pinnedBlur = AddBlur(pinnedWindow, 0.95)
    local pinnedCorner = windowCorner:Clone()
    pinnedCorner.Parent = pinnedWindow
    local pinnedStroke = windowStroke:Clone()
    pinnedStroke.Parent = pinnedWindow
    local pinnedShadow = windowShadow:Clone()
    pinnedShadow.Parent = pinnedWindow
    
    -- Clone header for pinned window
    local pinnedHeader = listHeader:Clone()
    pinnedHeader.Parent = pinnedWindow
    pinnedHeader:FindFirstChild("TextLabel").Text = "Active Keybinds (Pinned)"
    
    -- Remove pin button from pinned header and add unpin button
    local pinnedPinButton = pinnedHeader:FindFirstChild("TextButton")
    if pinnedPinButton then
        pinnedPinButton.Text = "📍"
        pinnedPinButton.TextColor3 = Theme.Accent
        pinnedPinButton.BackgroundTransparency = 0.3
    end
    
    -- Clone scroll frame for pinned window
    local pinnedScroll = scrollFrame:Clone()
    pinnedScroll.Parent = pinnedWindow
    
    -- Make pinned window draggable
    MakeDraggable(pinnedWindow, pinnedHeader)
    
    -- Store reference to pinned window
    self.PinnedKeybindWindow = pinnedWindow
    
    -- Pin button functionality
    pinButton.MouseButton1Click:Connect(function()
        print("[DEBUG] Pin button clicked! Current isPinned state:", isPinned)
        isPinned = not isPinned
        
        if isPinned then
            print("[DEBUG] Pinning window...")
            -- Pin the window
            pinButton.TextColor3 = Theme.Accent
            pinButton.BackgroundTransparency = 0.3
            
            -- Copy current content to pinned window
            pinnedWindow.Position = keybindWindow.Position
            pinnedScroll:ClearAllChildren()
            
            -- Re-create container structure in pinned scroll
            local pinnedItemsContainer = Instance.new("Frame")
            pinnedItemsContainer.Size = UDim2.new(1, 0, 0, 0)
            pinnedItemsContainer.BackgroundTransparency = 1
            pinnedItemsContainer.AutomaticSize = Enum.AutomaticSize.Y
            pinnedItemsContainer.Parent = pinnedScroll
            
            local pinnedItemsLayout = Instance.new("UIListLayout")
            pinnedItemsLayout.Padding = UDim.new(0, 5)
            pinnedItemsLayout.Parent = pinnedItemsContainer
            
            local pinnedItemsPadding = Instance.new("UIPadding")
            pinnedItemsPadding.PaddingBottom = UDim.new(0, 10)
            pinnedItemsPadding.Parent = pinnedItemsContainer
            
            -- Update canvas size for pinned scroll
            pinnedItemsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                pinnedScroll.CanvasSize = UDim2.new(0, 0, 0, pinnedItemsLayout.AbsoluteContentSize.Y)
            end)
            
            -- Copy all children from itemsContainer
            for _, child in ipairs(itemsContainer:GetChildren()) do
                if child:IsA("Frame") or child:IsA("TextLabel") then
                    local clone = child:Clone()
                    clone.Parent = pinnedItemsContainer
                end
            end
            
            pinnedWindow.Visible = true
            
            -- Close the regular keybind window when pinning
            keybindWindow.Visible = false
            isOpen = false
            CreateTween(keybindIcon, {BackgroundTransparency = 0.7}):Play()
            CreateTween(iconStroke, {Transparency = 1}):Play()
            CreateTween(keybindIcon, {TextColor3 = Theme.TextSecondary}):Play()
            
            print("[DEBUG] Pinned window should now be visible")
            print("[DEBUG] Pinned window parent:", pinnedWindow.Parent)
            print("[DEBUG] Pinned window visible:", pinnedWindow.Visible)
            
            -- Update pinned window when keybinds change
            self.UpdatePinnedKeybinds = function()
                if isPinned and pinnedItemsContainer then
                    print("[DEBUG] Updating pinned keybinds...")
                    pinnedItemsContainer:ClearAllChildren()
                    
                    -- Re-create layout
                    local layout = Instance.new("UIListLayout")
                    layout.Padding = UDim.new(0, 5)
                    layout.Parent = pinnedItemsContainer
                    
                    local padding = Instance.new("UIPadding")
                    padding.PaddingBottom = UDim.new(0, 10)
                    padding.Parent = pinnedItemsContainer
                    
                    -- Copy all children
                    for _, child in ipairs(itemsContainer:GetChildren()) do
                        if child:IsA("Frame") or child:IsA("TextLabel") then
                            local clone = child:Clone()
                            clone.Parent = pinnedItemsContainer
                        end
                    end
                end
            end
        else
            print("[DEBUG] Unpinning window...")
            -- Unpin the window
            pinButton.TextColor3 = Theme.TextSecondary
            pinButton.BackgroundTransparency = 0.7
            pinnedWindow.Visible = false
            self.UpdatePinnedKeybinds = nil
            
            -- Automatically show the regular window again
            keybindWindow.Visible = true
            isOpen = true
            updateKeybindList()
            CreateTween(keybindIcon, {BackgroundTransparency = 0.3}):Play()
            CreateTween(iconStroke, {Transparency = 0.3}):Play()
            CreateTween(keybindIcon, {TextColor3 = Theme.Accent}):Play()
            
            print("[DEBUG] Regular window should now be visible")
        end
    end)
    
    -- Unpin button functionality for pinned window
    if pinnedPinButton then
        pinnedPinButton.MouseButton1Click:Connect(function()
            print("[DEBUG] Unpin button clicked on pinned window")
            isPinned = false
            pinButton.TextColor3 = Theme.TextSecondary
            pinButton.BackgroundTransparency = 0.7
            pinnedWindow.Visible = false
            self.UpdatePinnedKeybinds = nil
            
            -- Also show the regular window when unpinning from pinned window
            keybindWindow.Visible = true
            isOpen = true
            updateKeybindList()
            CreateTween(keybindIcon, {BackgroundTransparency = 0.3}):Play()
            CreateTween(iconStroke, {Transparency = 0.3}):Play()
            CreateTween(keybindIcon, {TextColor3 = Theme.Accent}):Play()
            
            print("[DEBUG] Unpinned from pinned window button")
        end)
    end
    
    -- Pin button hover effect
    pinButton.MouseEnter:Connect(function()
        if not isPinned then
            CreateTween(pinButton, {BackgroundTransparency = 0.5, TextColor3 = Theme.Text}):Play()
        end
    end)
    
    pinButton.MouseLeave:Connect(function()
        if not isPinned then
            CreateTween(pinButton, {BackgroundTransparency = 0.7, TextColor3 = Theme.TextSecondary}):Play()
        end
    end)
    
    -- Make window draggable
    MakeDraggable(keybindWindow, listHeader)
    
    -- Toggle keybind list
    local isOpen = false
    keybindIcon.MouseButton1Click:Connect(function()
        -- Don't open regular window if pinned window is active
        if isPinned then
            -- Toggle pinned window instead
            pinnedWindow.Visible = not pinnedWindow.Visible
            return
        end
        
        isOpen = not isOpen
        keybindWindow.Visible = isOpen
        
        if isOpen then
            updateKeybindList()
            CreateTween(keybindIcon, {BackgroundTransparency = 0.3}):Play()
            CreateTween(iconStroke, {Transparency = 0.3}):Play()
            CreateTween(keybindIcon, {TextColor3 = Theme.Accent}):Play()
        else
            CreateTween(keybindIcon, {BackgroundTransparency = 0.7}):Play()
            CreateTween(iconStroke, {Transparency = 1}):Play()
            CreateTween(keybindIcon, {TextColor3 = Theme.TextSecondary}):Play()
        end
    end)
    
    -- Hover effects for icon
    keybindIcon.MouseEnter:Connect(function()
        if not isOpen then
            CreateTween(keybindIcon, {BackgroundTransparency = 0.5}):Play()
            CreateTween(iconStroke, {Transparency = 0.7}):Play()
            CreateTween(keybindIcon, {TextColor3 = Theme.Text}):Play()
        end
    end)
    
    keybindIcon.MouseLeave:Connect(function()
        if not isOpen then
            CreateTween(keybindIcon, {BackgroundTransparency = 0.7}):Play()
            CreateTween(iconStroke, {Transparency = 1}):Play()
            CreateTween(keybindIcon, {TextColor3 = Theme.TextSecondary}):Play()
        end
    end)
end

-- Modern Nav Button
function NobUI:CreateModernNavButton(parent, module)
    local button = Instance.new("TextButton")
    button.Name = module.Name
    button.Size = UDim2.new(0, 110, 0, 35)
    button.BackgroundColor3 = Theme.Tertiary
    button.BackgroundTransparency = 0.7
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Accent
    stroke.Transparency = 1
    stroke.Thickness = 2
    stroke.Parent = button
    
    -- Button content container
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Parent = button
    
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.FillDirection = Enum.FillDirection.Horizontal
    contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    contentLayout.Padding = UDim.new(0, 6)
    contentLayout.Parent = content
    
    -- Icon (using text for now)
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.BackgroundTransparency = 1
    icon.Text = module.Icon == "Eye" and "👁" or module.Icon == "Flask" and "⚗" or "⚙"
    icon.TextColor3 = Theme.TextSecondary
    icon.Font = Enum.Font.Gotham
    icon.TextSize = 16
    icon.Parent = content
    
    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 60, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = module.Name
    label.TextColor3 = Theme.TextSecondary
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 14
    label.Parent = content
    
    -- Toggle state
    local isActive = false
    
    button.MouseButton1Click:Connect(function()
        isActive = not isActive
        
        if isActive then
            CreateTween(button, {BackgroundTransparency = 0.3}):Play()
            CreateTween(stroke, {Transparency = 0.3}):Play()
            CreateTween(label, {TextColor3 = Theme.Text}):Play()
            CreateTween(icon, {TextColor3 = Theme.Accent}):Play()
            
            if self.Windows[module.Window] then
                self.Windows[module.Window].Main.Visible = true
            end
        else
            CreateTween(button, {BackgroundTransparency = 0.7}):Play()
            CreateTween(stroke, {Transparency = 1}):Play()
            CreateTween(label, {TextColor3 = Theme.TextSecondary}):Play()
            CreateTween(icon, {TextColor3 = Theme.TextSecondary}):Play()
            
            if self.Windows[module.Window] then
                self.Windows[module.Window].Main.Visible = false
            end
        end
    end)
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        if not isActive then
            CreateTween(button, {BackgroundTransparency = 0.5}):Play()
            CreateTween(stroke, {Transparency = 0.7}):Play()
            CreateTween(label, {TextColor3 = Theme.Text}):Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        if not isActive then
            CreateTween(button, {BackgroundTransparency = 0.7}):Play()
            CreateTween(stroke, {Transparency = 1}):Play()
            CreateTween(label, {TextColor3 = Theme.TextSecondary}):Play()
        end
    end)
end

-- Window Creation with modern design
function NobUI:CreateWindow(name)
    local window = {}
    window.Tabs = {}
    window.ActiveTab = nil
    
    -- Store reference to NobUI instance
    local nobUI = self
    
    -- Main window frame
    local main = Instance.new("Frame")
    main.Name = name
    main.Size = UDim2.new(0, 520, 0, 420)
    main.Position = UDim2.new(0.5, -260, 0.5, -180)
    main.BackgroundColor3 = Theme.Background
    main.BackgroundTransparency = Theme.Transparency
    main.Visible = false
    main.Parent = self.ScreenGui
    
    window.Main = main
    
    -- Add blur
    AddBlur(main, 0.98)
    
    -- Window effects
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = main
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Accent
    stroke.Transparency = 0.95
    stroke.Thickness = 1
    stroke.Parent = main
    
    -- Shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 40, 1, 40)
    shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 1
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.BackgroundTransparency = 1
    shadow.ZIndex = -1
    shadow.Parent = main
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 45)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = main
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 1, 0)  -- Changed from "1, -50" to give more space for title
    titleLabel.Position = UDim2.new(0, 20, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = name:gsub("Window", "")
    titleLabel.TextColor3 = Theme.Text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 18
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Close button removed - windows only close via navbar
    
    -- Tab container
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, -40, 0, 35)
    tabContainer.Position = UDim2.new(0, 20, 0, 50)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = main
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.Parent = tabContainer
    
    -- Content container
    local contentContainer = Instance.new("Frame")
    contentContainer.Size = UDim2.new(1, -40, 1, -105)
    contentContainer.Position = UDim2.new(0, 20, 0, 95)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = main
    
    window.TabContainer = tabContainer
    window.ContentContainer = contentContainer
    
    -- Make draggable
    MakeDraggable(main, titleBar)
    
    -- Add resize handle (bottom-right corner)
    local resizeHandle = Instance.new("Frame")
    resizeHandle.Size = UDim2.new(0, 20, 0, 20)
    resizeHandle.Position = UDim2.new(1, -20, 1, -20)
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.Parent = main
    
    -- Visual indicator for resize area
    local resizeIcon = Instance.new("ImageLabel")
    resizeIcon.Size = UDim2.new(1, 0, 1, 0)
    resizeIcon.BackgroundTransparency = 1
    resizeIcon.Image = "rbxassetid://4641038120" -- Corner resize icon
    resizeIcon.ImageColor3 = Theme.TextDim
    resizeIcon.ImageTransparency = 0.5
    resizeIcon.ScaleType = Enum.ScaleType.Fit
    resizeIcon.Parent = resizeHandle
    
    -- Alternative: Create custom resize indicator with frames
    local resizeLine1 = Instance.new("Frame")
    resizeLine1.Size = UDim2.new(0, 10, 0, 2)
    resizeLine1.Position = UDim2.new(1, -12, 1, -4)
    resizeLine1.BackgroundColor3 = Theme.TextDim
    resizeLine1.BackgroundTransparency = 0.5
    resizeLine1.BorderSizePixel = 0
    resizeLine1.Parent = resizeHandle
    
    local resizeLine2 = Instance.new("Frame")
    resizeLine2.Size = UDim2.new(0, 2, 0, 10)
    resizeLine2.Position = UDim2.new(1, -4, 1, -12)
    resizeLine2.BackgroundColor3 = Theme.TextDim
    resizeLine2.BackgroundTransparency = 0.5
    resizeLine2.BorderSizePixel = 0
    resizeLine2.Parent = resizeHandle
    
    local resizeLine3 = Instance.new("Frame")
    resizeLine3.Size = UDim2.new(0, 6, 0, 2)
    resizeLine3.Position = UDim2.new(1, -8, 1, -8)
    resizeLine3.BackgroundColor3 = Theme.TextDim
    resizeLine3.BackgroundTransparency = 0.5
    resizeLine3.BorderSizePixel = 0
    resizeLine3.Parent = resizeHandle
    
    -- Resize functionality
    local resizing = false
    local startSize = nil
    local startPos = nil
    local minSize = Vector2.new(400, 300) -- Minimum window size
    local maxSize = Vector2.new(800, 600) -- Maximum window size
    
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            startSize = main.AbsoluteSize
            startPos = UserInputService:GetMouseLocation()
            
            -- Show resize feedback
            CreateTween(resizeLine1, {BackgroundTransparency = 0.2}):Play()
            CreateTween(resizeLine2, {BackgroundTransparency = 0.2}):Play()
            CreateTween(resizeLine3, {BackgroundTransparency = 0.2}):Play()
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local currentPos = UserInputService:GetMouseLocation()
            local delta = currentPos - startPos
            
            -- Calculate new size
            local newWidth = math.clamp(startSize.X + delta.X, minSize.X, maxSize.X)
            local newHeight = math.clamp(startSize.Y + delta.Y, minSize.Y, maxSize.Y)
            
            -- Apply new size
            main.Size = UDim2.new(0, newWidth, 0, newHeight)
            
            -- Update content container size if needed
            if window.ContentContainer then
                window.ContentContainer.Size = UDim2.new(1, -40, 1, -105)
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
            
            -- Hide resize feedback
            CreateTween(resizeLine1, {BackgroundTransparency = 0.5}):Play()
            CreateTween(resizeLine2, {BackgroundTransparency = 0.5}):Play()
            CreateTween(resizeLine3, {BackgroundTransparency = 0.5}):Play()
        end
    end)
    
    -- Hover effects for resize handle
    resizeHandle.MouseEnter:Connect(function()
        if not resizing then
            CreateTween(resizeLine1, {BackgroundTransparency = 0.3}):Play()
            CreateTween(resizeLine2, {BackgroundTransparency = 0.3}):Play()
            CreateTween(resizeLine3, {BackgroundTransparency = 0.3}):Play()
        end
    end)
    
    resizeHandle.MouseLeave:Connect(function()
        if not resizing then
            CreateTween(resizeLine1, {BackgroundTransparency = 0.5}):Play()
            CreateTween(resizeLine2, {BackgroundTransparency = 0.5}):Play()
            CreateTween(resizeLine3, {BackgroundTransparency = 0.5}):Play()
        end
    end)
    
    -- Store window
    self.Windows[name] = window
    
    -- Add Tab Method
    function window:AddTab(tabName)
        local tab = {}
        tab.Sections = {}
        
        -- Tab button
        local tabButton = Instance.new("TextButton")
        tabButton.Size = UDim2.new(0, 100, 1, 0)
        tabButton.BackgroundColor3 = Theme.Tertiary
        tabButton.BackgroundTransparency = 0.8
        tabButton.Text = tabName
        tabButton.TextColor3 = Theme.TextSecondary
        tabButton.Font = Enum.Font.GothamMedium
        tabButton.TextSize = 14
        tabButton.AutoButtonColor = false
        tabButton.Parent = window.TabContainer
        
        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 8)
        tabCorner.Parent = tabButton
        
        -- Tab content
        local tabContent = Instance.new("ScrollingFrame")
        tabContent.Size = UDim2.new(1, 0, 1, 0)
        tabContent.BackgroundTransparency = 1
        tabContent.BorderSizePixel = 0
        tabContent.ScrollBarThickness = 3
        tabContent.ScrollBarImageColor3 = Theme.Accent
        tabContent.ScrollBarImageTransparency = 0.5
        tabContent.Visible = false
        tabContent.Parent = window.ContentContainer
        
        local contentLayout = Instance.new("UIListLayout")
        contentLayout.Padding = UDim.new(0, 12)
        contentLayout.Parent = tabContent
        
        tab.Button = tabButton
        tab.Content = tabContent
        
        -- Tab click
        tabButton.MouseButton1Click:Connect(function()
            -- Hide all tabs
            for _, t in pairs(window.Tabs) do
                t.Content.Visible = false
                t.Button.TextColor3 = Theme.TextSecondary
                t.Button.BackgroundTransparency = 0.8
            end
            
            -- Show this tab
            tab.Content.Visible = true
            tab.Button.TextColor3 = Theme.Text
            tab.Button.BackgroundTransparency = 0.3
            window.ActiveTab = tab
        end)
        
        -- Auto select first tab
        if #window.Tabs == 0 then
            -- Instead of Fire(), directly execute the click logic
            tab.Content.Visible = true
            tab.Button.TextColor3 = Theme.Text
            tab.Button.BackgroundTransparency = 0.3
            window.ActiveTab = tab
        end
        
        -- Add Section Method
        function tab:AddSection(sectionName)
            local section = {}
            
            -- Section frame
            local sectionFrame = Instance.new("Frame")
            sectionFrame.Size = UDim2.new(1, 0, 0, 0)
            sectionFrame.BackgroundColor3 = Theme.Secondary
            sectionFrame.BackgroundTransparency = 0.5
            sectionFrame.AutomaticSize = Enum.AutomaticSize.Y
            sectionFrame.Parent = tab.Content
            
            local sectionCorner = Instance.new("UICorner")
            sectionCorner.CornerRadius = UDim.new(0, 12)
            sectionCorner.Parent = sectionFrame
            
            local sectionStroke = Instance.new("UIStroke")
            sectionStroke.Color = Theme.Tertiary
            sectionStroke.Transparency = 0.5
            sectionStroke.Thickness = 1
            sectionStroke.Parent = sectionFrame
            
            -- Section title
            local sectionTitle = Instance.new("TextLabel")
            sectionTitle.Size = UDim2.new(1, -30, 0, 30)
            sectionTitle.Position = UDim2.new(0, 15, 0, 8)
            sectionTitle.BackgroundTransparency = 1
            sectionTitle.Text = sectionName
            sectionTitle.TextColor3 = Theme.Text
            sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
            sectionTitle.Font = Enum.Font.GothamSemibold
            sectionTitle.TextSize = 16
            sectionTitle.Parent = sectionFrame
            
            -- Content container
            local sectionContent = Instance.new("Frame")
            sectionContent.Size = UDim2.new(1, -30, 0, 0)
            sectionContent.Position = UDim2.new(0, 15, 0, 40)
            sectionContent.BackgroundTransparency = 1
            sectionContent.AutomaticSize = Enum.AutomaticSize.Y
            sectionContent.Parent = sectionFrame
            
            local sectionLayout = Instance.new("UIListLayout")
            sectionLayout.Padding = UDim.new(0, 10)
            sectionLayout.Parent = sectionContent
            
            local sectionPadding = Instance.new("UIPadding")
            sectionPadding.PaddingBottom = UDim.new(0, 15)
            sectionPadding.Parent = sectionContent
            
            -- Fix AutomaticSize update
            sectionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                tab.Content.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y)
            end)
            
            -- Define all methods before adding them to section
            local methods = {}
            
            -- Add Toggle Method
            methods.AddToggle = function(self, text, default, callback)
                local toggleFrame = Instance.new("Frame")
                toggleFrame.Size = UDim2.new(1, 0, 0, 35)
                toggleFrame.BackgroundTransparency = 1
                toggleFrame.Parent = sectionContent
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -60, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = text
                label.TextColor3 = Theme.Text
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Font = Enum.Font.Gotham
                label.TextSize = 14
                label.Parent = toggleFrame
                
                local toggle = Instance.new("TextButton")
                toggle.Size = UDim2.new(0, 50, 0, 25)
                toggle.Position = UDim2.new(1, -55, 0.5, -12.5)
                toggle.BackgroundColor3 = Theme.Tertiary
                toggle.AutoButtonColor = false
                toggle.Text = ""
                toggle.Parent = toggleFrame
                
                local toggleCorner = Instance.new("UICorner")
                toggleCorner.CornerRadius = UDim.new(1, 0)
                toggleCorner.Parent = toggle
                
                local toggleDot = Instance.new("Frame")
                toggleDot.Size = UDim2.new(0, 19, 0, 19)
                toggleDot.Position = UDim2.new(0, 3, 0.5, -9.5)
                toggleDot.BackgroundColor3 = Theme.TextSecondary
                toggleDot.Parent = toggle
                
                local dotCorner = Instance.new("UICorner")
                dotCorner.CornerRadius = UDim.new(1, 0)
                dotCorner.Parent = toggleDot
                
                local enabled = default or false
                local toggleKeybind = nil
                
                local function updateToggle()
                    if enabled then
                        CreateTween(toggle, {BackgroundColor3 = Theme.Accent}):Play()
                        CreateTween(toggleDot, {Position = UDim2.new(1, -22, 0.5, -9.5), BackgroundColor3 = Theme.Text}):Play()
                        -- Update keybind list color if exists
                        if nobUI.Keybinds["Toggle_" .. text] and nobUI.Keybinds["Toggle_" .. text].label then
                            nobUI.Keybinds["Toggle_" .. text].label.TextColor3 = Theme.Success
                        end
                    else
                        CreateTween(toggle, {BackgroundColor3 = Theme.Tertiary}):Play()
                        CreateTween(toggleDot, {Position = UDim2.new(0, 3, 0.5, -9.5), BackgroundColor3 = Theme.TextSecondary}):Play()
                        -- Update keybind list color if exists
                        if nobUI.Keybinds["Toggle_" .. text] and nobUI.Keybinds["Toggle_" .. text].label then
                            nobUI.Keybinds["Toggle_" .. text].label.TextColor3 = Theme.TextSecondary
                        end
                    end
                    if callback then callback(enabled) end
                end
                
                updateToggle()
                
                toggle.MouseButton1Click:Connect(function()
                    enabled = not enabled
                    updateToggle()
                end)
                
                -- Right-click keybind menu
                toggle.MouseButton2Click:Connect(function()
                    -- Close any existing keybind menu
                    if nobUI.ActiveKeybindMenu then
                        nobUI.ActiveKeybindMenu:Destroy()
                        nobUI.ActiveKeybindMenu = nil
                    end
                    
                    -- Create keybind menu container
                    local menuContainer = Instance.new("Frame")
                    menuContainer.Size = UDim2.new(1, 0, 1, 0)
                    menuContainer.BackgroundTransparency = 1
                    menuContainer.Parent = nobUI.ScreenGui
                    nobUI.ActiveKeybindMenu = menuContainer
                    
                    -- Invisible background to detect clicks outside
                    local backgroundButton = Instance.new("TextButton")
                    backgroundButton.Size = UDim2.new(1, 0, 1, 0)
                    backgroundButton.BackgroundTransparency = 1
                    backgroundButton.Text = ""
                    backgroundButton.Parent = menuContainer
                    
                    -- Create keybind menu
                    local keybindMenu = Instance.new("Frame")
                    keybindMenu.Size = UDim2.new(0, 150, 0, 60)
                    keybindMenu.Position = UDim2.new(0, toggle.AbsolutePosition.X - 100, 0, toggle.AbsolutePosition.Y + 30)
                    keybindMenu.BackgroundColor3 = Theme.Secondary
                    keybindMenu.BackgroundTransparency = 0.1
                    keybindMenu.Parent = menuContainer
                    
                    local menuCorner = Instance.new("UICorner")
                    menuCorner.CornerRadius = UDim.new(0, 8)
                    menuCorner.Parent = keybindMenu
                    
                    local menuStroke = Instance.new("UIStroke")
                    menuStroke.Color = Theme.Accent
                    menuStroke.Transparency = 0.8
                    menuStroke.Thickness = 1
                    menuStroke.Parent = keybindMenu
                    
                    local menuShadow = Instance.new("ImageLabel")
                    menuShadow.Size = UDim2.new(1, 20, 1, 20)
                    menuShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
                    menuShadow.AnchorPoint = Vector2.new(0.5, 0.5)
                    menuShadow.Image = "rbxassetid://1316045217"
                    menuShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
                    menuShadow.ImageTransparency = 0.7
                    menuShadow.ScaleType = Enum.ScaleType.Slice
                    menuShadow.SliceCenter = Rect.new(10, 10, 118, 118)
                    menuShadow.BackgroundTransparency = 1
                    menuShadow.ZIndex = -1
                    menuShadow.Parent = keybindMenu
                    
                    local hotkeyLabel = Instance.new("TextLabel")
                    hotkeyLabel.Size = UDim2.new(1, -20, 0, 20)
                    hotkeyLabel.Position = UDim2.new(0, 10, 0, 8)
                    hotkeyLabel.BackgroundTransparency = 1
                    hotkeyLabel.Text = "Hotkey:"
                    hotkeyLabel.TextColor3 = Theme.TextSecondary
                    hotkeyLabel.Font = Enum.Font.Gotham
                    hotkeyLabel.TextSize = 12
                    hotkeyLabel.TextXAlignment = Enum.TextXAlignment.Left
                    hotkeyLabel.Parent = keybindMenu
                    
                    local keybindButton = Instance.new("TextButton")
                    keybindButton.Size = UDim2.new(1, -45, 0, 25)
                    keybindButton.Position = UDim2.new(0, 10, 0, 28)
                    keybindButton.BackgroundColor3 = Theme.Tertiary
                    keybindButton.BackgroundTransparency = 0.3
                    keybindButton.Text = toggleKeybind and toggleKeybind.Name or "None"
                    keybindButton.TextColor3 = Theme.Text
                    keybindButton.Font = Enum.Font.Gotham
                    keybindButton.TextSize = 12
                    keybindButton.AutoButtonColor = false
                    keybindButton.Parent = keybindMenu
                    
                    local keybindCorner = Instance.new("UICorner")
                    keybindCorner.CornerRadius = UDim.new(0, 6)
                    keybindCorner.Parent = keybindButton
                    
                    -- Add X button to clear keybind
                    local clearButton = Instance.new("TextButton")
                    clearButton.Size = UDim2.new(0, 25, 0, 25)
                    clearButton.Position = UDim2.new(1, -35, 0, 28)
                    clearButton.BackgroundColor3 = Theme.Tertiary
                    clearButton.BackgroundTransparency = 0.3
                    clearButton.Text = "×"
                    clearButton.TextColor3 = Theme.Error
                    clearButton.Font = Enum.Font.GothamBold
                    clearButton.TextSize = 16
                    clearButton.AutoButtonColor = false
                    clearButton.Parent = keybindMenu
                    
                    local clearCorner = Instance.new("UICorner")
                    clearCorner.CornerRadius = UDim.new(0, 6)
                    clearCorner.Parent = clearButton
                    
                    -- Clear button hover effect
                    clearButton.MouseEnter:Connect(function()
                        CreateTween(clearButton, {BackgroundColor3 = Theme.Error, BackgroundTransparency = 0.7, TextColor3 = Theme.Text}):Play()
                    end)
                    
                    clearButton.MouseLeave:Connect(function()
                        CreateTween(clearButton, {BackgroundColor3 = Theme.Tertiary, BackgroundTransparency = 0.3, TextColor3 = Theme.Error}):Play()
                    end)
                    
                    -- Clear button functionality
                    clearButton.MouseButton1Click:Connect(function()
                        toggleKeybind = nil
                        keybindButton.Text = "None"
                        keybindButton.TextColor3 = Theme.Text
                        nobUI.Keybinds["Toggle_" .. text] = nil
                        
                        -- Update keybind list
                        if nobUI.UpdateKeybindList then
                            nobUI.UpdateKeybindList()
                        end
                        
                        -- Visual feedback
                        CreateTween(clearButton, {BackgroundTransparency = 0.1}, 0.1):Play()
                        task.wait(0.1)
                        CreateTween(clearButton, {BackgroundTransparency = 0.3}, 0.1):Play()
                    end)
                    
                    local listening = false
                    local keybindConnection
                    
                    -- Click on background closes menu
                    backgroundButton.MouseButton1Click:Connect(function()
                        if not listening then
                            menuContainer:Destroy()
                            nobUI.ActiveKeybindMenu = nil
                            if keybindConnection then
                                keybindConnection:Disconnect()
                            end
                        end
                    end)
                    
                    keybindButton.MouseButton1Click:Connect(function()
                        if listening then
                            -- If already listening, cancel
                            listening = false
                            keybindButton.Text = toggleKeybind and toggleKeybind.Name or "None"
                            keybindButton.TextColor3 = Theme.Text
                        else
                            -- Start listening for key
                            listening = true
                            keybindButton.Text = "..."
                            keybindButton.TextColor3 = Theme.Accent
                        end
                    end)
                    
                    -- Handle keybind assignment
                    keybindConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                        if listening and not gameProcessed then
                            if input.KeyCode ~= Enum.KeyCode.Unknown then
                                toggleKeybind = input.KeyCode
                                keybindButton.Text = toggleKeybind.Name
                                keybindButton.TextColor3 = Theme.Text
                                listening = false
                                
                                -- Store toggle keybind
                                nobUI.Keybinds["Toggle_" .. text] = {
                                    key = toggleKeybind, 
                                    callback = function()
                                        enabled = not enabled
                                        updateToggle()
                                        -- Update color in keybind list
                                        if nobUI.Keybinds["Toggle_" .. text].label then
                                            nobUI.Keybinds["Toggle_" .. text].label.TextColor3 = enabled and Theme.Success or Theme.TextSecondary
                                        end
                                    end
                                }
                                
                                -- Update keybind list
                                if nobUI.UpdateKeybindList then
                                    nobUI.UpdateKeybindList()
                                end
                                
                                -- Auto close menu after setting keybind
                                wait(0.5)
                                if menuContainer and menuContainer.Parent then
                                    menuContainer:Destroy()
                                    nobUI.ActiveKeybindMenu = nil
                                    keybindConnection:Disconnect()
                                end
                            end
                        end
                    end)
                end)
            end
            
            -- Add Slider Method
            methods.AddSlider = function(self, text, min, max, default, callback)
                local sliderFrame = Instance.new("Frame")
                sliderFrame.Size = UDim2.new(1, 0, 0, 55)
                sliderFrame.BackgroundTransparency = 1
                sliderFrame.Parent = sectionContent
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -60, 0, 20)
                label.BackgroundTransparency = 1
                label.Text = text
                label.TextColor3 = Theme.Text
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Font = Enum.Font.Gotham
                label.TextSize = 14
                label.Parent = sliderFrame
                
                local valueLabel = Instance.new("TextLabel")
                valueLabel.Size = UDim2.new(0, 50, 0, 20)
                valueLabel.Position = UDim2.new(1, -55, 0, 0)
                valueLabel.BackgroundTransparency = 1
                valueLabel.Text = tostring(default or min)
                valueLabel.TextColor3 = Theme.Accent
                valueLabel.TextXAlignment = Enum.TextXAlignment.Right
                valueLabel.Font = Enum.Font.GothamMedium
                valueLabel.TextSize = 14
                valueLabel.Parent = sliderFrame
                
                local sliderBg = Instance.new("Frame")
                sliderBg.Size = UDim2.new(1, 0, 0, 8)
                sliderBg.Position = UDim2.new(0, 25, 0.5, -3)
                sliderBg.BackgroundColor3 = Theme.Tertiary
                sliderBg.Parent = sliderFrame
                
                local sliderCorner = Instance.new("UICorner")
                sliderCorner.CornerRadius = UDim.new(1, 0)
                sliderCorner.Parent = sliderBg
                
                local sliderFill = Instance.new("Frame")
                sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
                sliderFill.BackgroundColor3 = Theme.Accent
                sliderFill.Parent = sliderBg
                
                local fillCorner = Instance.new("UICorner")
                fillCorner.CornerRadius = UDim.new(1, 0)
                fillCorner.Parent = sliderFill
                
                local sliderDot = Instance.new("Frame")
                sliderDot.Size = UDim2.new(0, 16, 0, 16)
                sliderDot.Position = UDim2.new((default - min) / (max - min), -8, 0.5, -8)
                sliderDot.BackgroundColor3 = Theme.Text
                sliderDot.Parent = sliderBg
                
                local dotCorner = Instance.new("UICorner")
                dotCorner.CornerRadius = UDim.new(1, 0)
                dotCorner.Parent = sliderDot
                
                local dragging = false
                
                sliderBg.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                    end
                end)
                
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
                
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        local mousePos = UserInputService:GetMouseLocation()
                        local relativeX = mousePos.X - sliderBg.AbsolutePosition.X
                        local percentage = math.clamp(relativeX / sliderBg.AbsoluteSize.X, 0, 1)
                        local value = math.floor(min + (max - min) * percentage)
                        
                        sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
                        sliderDot.Position = UDim2.new(percentage, -8, 0.5, -8)
                        valueLabel.Text = tostring(value)
                        
                        if callback then callback(value) end
                    end
                end)
                
                return {SetValue = function(val) 
                    local percentage = (val - min) / (max - min)
                    sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
                    sliderDot.Position = UDim2.new(percentage, -8, 0.5, -8)
                    valueLabel.Text = tostring(val)
                end}
            end
            
            -- Add Button Method
            methods.AddButton = function(self, text, callback)
                local button = Instance.new("TextButton")
                button.Size = UDim2.new(1, 0, 0, 40)
                button.BackgroundColor3 = Theme.Accent
                button.BackgroundTransparency = 0.8
                button.Text = text
                button.TextColor3 = Theme.Text
                button.Font = Enum.Font.GothamMedium
                button.TextSize = 14
                button.AutoButtonColor = false
                button.Parent = sectionContent
                
                local buttonCorner = Instance.new("UICorner")
                buttonCorner.CornerRadius = UDim.new(0, 10)
                buttonCorner.Parent = button
                
                local buttonKeybind = nil
                
                button.MouseButton1Click:Connect(function()
                    CreateTween(button, {BackgroundTransparency = 0.6}, 0.1):Play()
                    wait(0.1)
                    CreateTween(button, {BackgroundTransparency = 0.8}, 0.1):Play()
                    if callback then callback() end
                end)
                
                button.MouseEnter:Connect(function()
                    CreateTween(button, {BackgroundTransparency = 0.7}):Play()
                end)
                
                button.MouseLeave:Connect(function()
                    CreateTween(button, {BackgroundTransparency = 0.8}):Play()
                end)
                
                -- Right-click keybind menu
                button.MouseButton2Click:Connect(function()
                    -- Close any existing keybind menu
                    if nobUI.ActiveKeybindMenu then
                        nobUI.ActiveKeybindMenu:Destroy()
                        nobUI.ActiveKeybindMenu = nil
                    end
                    
                    -- Create keybind menu container
                    local menuContainer = Instance.new("Frame")
                    menuContainer.Size = UDim2.new(1, 0, 1, 0)
                    menuContainer.BackgroundTransparency = 1
                    menuContainer.Parent = nobUI.ScreenGui
                    nobUI.ActiveKeybindMenu = menuContainer
                    
                    -- Invisible background to detect clicks outside
                    local backgroundButton = Instance.new("TextButton")
                    backgroundButton.Size = UDim2.new(1, 0, 1, 0)
                    backgroundButton.BackgroundTransparency = 1
                    backgroundButton.Text = ""
                    backgroundButton.Parent = menuContainer
                    
                    -- Create keybind menu
                    local keybindMenu = Instance.new("Frame")
                    keybindMenu.Size = UDim2.new(0, 150, 0, 60)
                    keybindMenu.Position = UDim2.new(0, button.AbsolutePosition.X + button.AbsoluteSize.X/2 - 75, 0, button.AbsolutePosition.Y + 45)
                    keybindMenu.BackgroundColor3 = Theme.Secondary
                    keybindMenu.BackgroundTransparency = 0.1
                    keybindMenu.Parent = menuContainer
                    
                    local menuCorner = Instance.new("UICorner")
                    menuCorner.CornerRadius = UDim.new(0, 8)
                    menuCorner.Parent = keybindMenu
                    
                    local menuStroke = Instance.new("UIStroke")
                    menuStroke.Color = Theme.Accent
                    menuStroke.Transparency = 0.8
                    menuStroke.Thickness = 1
                    menuStroke.Parent = keybindMenu
                    
                    local menuShadow = Instance.new("ImageLabel")
                    menuShadow.Size = UDim2.new(1, 20, 1, 20)
                    menuShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
                    menuShadow.AnchorPoint = Vector2.new(0.5, 0.5)
                    menuShadow.Image = "rbxassetid://1316045217"
                    menuShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
                    menuShadow.ImageTransparency = 0.7
                    menuShadow.ScaleType = Enum.ScaleType.Slice
                    menuShadow.SliceCenter = Rect.new(10, 10, 118, 118)
                    menuShadow.BackgroundTransparency = 1
                    menuShadow.ZIndex = -1
                    menuShadow.Parent = keybindMenu
                    
                    local hotkeyLabel = Instance.new("TextLabel")
                    hotkeyLabel.Size = UDim2.new(1, -20, 0, 20)
                    hotkeyLabel.Position = UDim2.new(0, 10, 0, 8)
                    hotkeyLabel.BackgroundTransparency = 1
                    hotkeyLabel.Text = "Hotkey:"
                    hotkeyLabel.TextColor3 = Theme.TextSecondary
                    hotkeyLabel.Font = Enum.Font.Gotham
                    hotkeyLabel.TextSize = 12
                    hotkeyLabel.TextXAlignment = Enum.TextXAlignment.Left
                    hotkeyLabel.Parent = keybindMenu
                    
                    local keybindButton = Instance.new("TextButton")
                    keybindButton.Size = UDim2.new(1, -45, 0, 25)
                    keybindButton.Position = UDim2.new(0, 10, 0, 28)
                    keybindButton.BackgroundColor3 = Theme.Tertiary
                    keybindButton.BackgroundTransparency = 0.3
                    keybindButton.Text = buttonKeybind and buttonKeybind.Name or "None"
                    keybindButton.TextColor3 = Theme.Text
                    keybindButton.Font = Enum.Font.Gotham
                    keybindButton.TextSize = 12
                    keybindButton.AutoButtonColor = false
                    keybindButton.Parent = keybindMenu
                    
                    local keybindCorner = Instance.new("UICorner")
                    keybindCorner.CornerRadius = UDim.new(0, 6)
                    keybindCorner.Parent = keybindButton
                    
                    -- Add X button to clear keybind
                    local clearButton = Instance.new("TextButton")
                    clearButton.Size = UDim2.new(0, 25, 0, 25)
                    clearButton.Position = UDim2.new(1, -35, 0, 28)
                    clearButton.BackgroundColor3 = Theme.Tertiary
                    clearButton.BackgroundTransparency = 0.3
                    clearButton.Text = "×"
                    clearButton.TextColor3 = Theme.Error
                    clearButton.Font = Enum.Font.GothamBold
                    clearButton.TextSize = 16
                    clearButton.AutoButtonColor = false
                    clearButton.Parent = keybindMenu
                    
                    local clearCorner = Instance.new("UICorner")
                    clearCorner.CornerRadius = UDim.new(0, 6)
                    clearCorner.Parent = clearButton
                    
                    -- Clear button hover effect
                    clearButton.MouseEnter:Connect(function()
                        CreateTween(clearButton, {BackgroundColor3 = Theme.Error, BackgroundTransparency = 0.7, TextColor3 = Theme.Text}):Play()
                    end)
                    
                    clearButton.MouseLeave:Connect(function()
                        CreateTween(clearButton, {BackgroundColor3 = Theme.Tertiary, BackgroundTransparency = 0.3, TextColor3 = Theme.Error}):Play()
                    end)
                    
                    -- Clear button functionality
                    clearButton.MouseButton1Click:Connect(function()
                        buttonKeybind = nil
                        keybindButton.Text = "None"
                        keybindButton.TextColor3 = Theme.Text
                        nobUI.Keybinds["Button_" .. text] = nil
                        
                        -- Update keybind list
                        if nobUI.UpdateKeybindList then
                            nobUI.UpdateKeybindList()
                        end
                        
                        -- Visual feedback
                        CreateTween(clearButton, {BackgroundTransparency = 0.1}, 0.1):Play()
                        task.wait(0.1)
                        CreateTween(clearButton, {BackgroundTransparency = 0.3}, 0.1):Play()
                    end)
                    
                    local listening = false
                    local keybindConnection
                    
                    -- Click on background closes menu
                    backgroundButton.MouseButton1Click:Connect(function()
                        if not listening then
                            menuContainer:Destroy()
                            nobUI.ActiveKeybindMenu = nil
                            if keybindConnection then
                                keybindConnection:Disconnect()
                            end
                        end
                    end)
                    
                    keybindButton.MouseButton1Click:Connect(function()
                        if listening then
                            -- If already listening, cancel
                            listening = false
                            keybindButton.Text = buttonKeybind and buttonKeybind.Name or "None"
                            keybindButton.TextColor3 = Theme.Text
                        else
                            -- Start listening for key
                            listening = true
                            keybindButton.Text = "..."
                            keybindButton.TextColor3 = Theme.Accent
                        end
                    end)
                    
                    -- Handle keybind assignment
                    keybindConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                        if listening and not gameProcessed then
                            if input.KeyCode ~= Enum.KeyCode.Unknown then
                                buttonKeybind = input.KeyCode
                                keybindButton.Text = buttonKeybind.Name
                                keybindButton.TextColor3 = Theme.Text
                                listening = false
                                
                                -- Store button keybind
                                nobUI.Keybinds["Button_" .. text] = {
                                    key = buttonKeybind, 
                                    callback = function()
                                        CreateTween(button, {BackgroundTransparency = 0.6}, 0.1):Play()
                                        task.wait(0.1)
                                        CreateTween(button, {BackgroundTransparency = 0.8}, 0.1):Play()
                                        if callback then callback() end
                                    end
                                }
                                
                                -- Update keybind list
                                if nobUI.UpdateKeybindList then
                                    nobUI.UpdateKeybindList()
                                end
                                
                                -- Auto close menu after setting keybind
                                wait(0.5)
                                if menuContainer and menuContainer.Parent then
                                    menuContainer:Destroy()
                                    nobUI.ActiveKeybindMenu = nil
                                    keybindConnection:Disconnect()
                                end
                            end
                        end
                    end)
                end)
            end
            
            -- Add Dropdown Method
            methods.AddDropdown = function(self, text, options, default, callback)
                -- Deep copy options to prevent reference issues
                local optionsCopy = {}
                if type(options) == "table" and #options > 0 then
                    for i, v in ipairs(options) do
                        optionsCopy[i] = tostring(v)
                    end
                else
                    optionsCopy = {"No options"}
                end
                
                -- Validate and set default
                local currentValue = default
                if not currentValue or type(currentValue) ~= "string" then
                    currentValue = optionsCopy[1]
                end
                
                -- Validate that default exists in options
                local defaultExists = false
                for _, opt in ipairs(optionsCopy) do
                    if opt == currentValue then
                        defaultExists = true
                        break
                    end
                end
                
                if not defaultExists then
                    currentValue = optionsCopy[1]
                end
                
                -- Main dropdown container that will expand
                local dropdownContainer = Instance.new("Frame")
                dropdownContainer.Size = UDim2.new(1, 0, 0, 35)
                dropdownContainer.BackgroundTransparency = 1
                dropdownContainer.AutomaticSize = Enum.AutomaticSize.Y
                dropdownContainer.Parent = sectionContent
                
                -- Top frame with label and dropdown button
                local dropdownFrame = Instance.new("Frame")
                dropdownFrame.Size = UDim2.new(1, 0, 0, 35)
                dropdownFrame.BackgroundTransparency = 1
                dropdownFrame.Parent = dropdownContainer
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(0.4, -5, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = text
                label.TextColor3 = Theme.Text
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Font = Enum.Font.Gotham
                label.TextSize = 14
                label.Parent = dropdownFrame
                
                local dropdown = Instance.new("TextButton")
                dropdown.Size = UDim2.new(0.6, -5, 1, 0)
                dropdown.Position = UDim2.new(0.4, 5, 0, 0)
                dropdown.BackgroundColor3 = Theme.Tertiary
                dropdown.BackgroundTransparency = 0.3
                dropdown.Text = currentValue
                dropdown.TextColor3 = Theme.Text
                dropdown.Font = Enum.Font.Gotham
                dropdown.TextSize = 14
                dropdown.AutoButtonColor = false
                dropdown.Parent = dropdownFrame
                
                local dropdownCorner = Instance.new("UICorner")
                dropdownCorner.CornerRadius = UDim.new(0, 8)
                dropdownCorner.Parent = dropdown
                
                local dropdownIcon = Instance.new("TextLabel")
                dropdownIcon.Size = UDim2.new(0, 25, 1, 0)
                dropdownIcon.Position = UDim2.new(1, -30, 0, 0)
                dropdownIcon.BackgroundTransparency = 1
                dropdownIcon.Text = "▼"
                dropdownIcon.TextColor3 = Theme.TextSecondary
                dropdownIcon.Font = Enum.Font.Gotham
                dropdownIcon.TextSize = 12
                dropdownIcon.Parent = dropdown
                
                -- Options container that will expand
                local optionsContainer = Instance.new("Frame")
                optionsContainer.Size = UDim2.new(0.6, -5, 0, 0)
                optionsContainer.Position = UDim2.new(0.4, 5, 0, 40)
                optionsContainer.BackgroundColor3 = Theme.Secondary
                optionsContainer.BackgroundTransparency = 0.3
                optionsContainer.ClipsDescendants = true
                optionsContainer.Visible = false
                optionsContainer.Parent = dropdownContainer
                
                local optionsCorner = Instance.new("UICorner")
                optionsCorner.CornerRadius = UDim.new(0, 8)
                optionsCorner.Parent = optionsContainer

                local optionsStroke = Instance.new("UIStroke")
                optionsStroke.Color = Theme.Tertiary
                optionsStroke.Transparency = 0.5
                optionsStroke.Thickness = 1
                optionsStroke.Parent = optionsContainer
                
                -- Search bar (only if more than 5 options)
                local searchBar = nil
                local searchInput = nil
                local optionsStartY = 5
                
                if #optionsCopy > 5 then
                    searchBar = Instance.new("Frame")
                    searchBar.Size = UDim2.new(1, -10, 0, 30)
                    searchBar.Position = UDim2.new(0, 5, 0, 5)
                    searchBar.BackgroundTransparency = 1
                    searchBar.Parent = optionsContainer
                    
                    searchInput = Instance.new("TextBox")
                    searchInput.Size = UDim2.new(1, 0, 1, 0)
                    searchInput.BackgroundColor3 = Theme.Tertiary
                    searchInput.BackgroundTransparency = 0.5
                    searchInput.Text = ""
                    searchInput.PlaceholderText = "Search..."
                    searchInput.PlaceholderColor3 = Theme.TextDim
                    searchInput.TextColor3 = Theme.Text
                    searchInput.Font = Enum.Font.Gotham
                    searchInput.TextSize = 12
                    searchInput.ClearTextOnFocus = false
                    searchInput.Parent = searchBar
                    
                    local searchCorner = Instance.new("UICorner")
                    searchCorner.CornerRadius = UDim.new(0, 6)
                    searchCorner.Parent = searchInput
                    
                    optionsStartY = 40
                end
                
                -- Scrolling frame for options
                local optionsFrame = Instance.new("ScrollingFrame")
                optionsFrame.Size = UDim2.new(1, -10, 1, -optionsStartY - 5)
                optionsFrame.Position = UDim2.new(0, 5, 0, optionsStartY)
                optionsFrame.BackgroundTransparency = 1
                optionsFrame.BorderSizePixel = 0
                optionsFrame.ScrollBarThickness = 2
                optionsFrame.ScrollBarImageColor3 = Theme.Accent
                optionsFrame.ScrollBarImageTransparency = 0.5
                optionsFrame.Parent = optionsContainer
                
                local optionsLayout = Instance.new("UIListLayout")
                optionsLayout.Parent = optionsFrame
                
                local isOpen = false
                local optionButtons = {}
                
                -- Function to filter options
                local function filterOptions(searchText)
                    searchText = searchText:lower()
                    for _, optionData in ipairs(optionButtons) do
                        local optionText = optionData.text:lower()
                        local visible = searchText == "" or optionText:find(searchText, 1, true)
                        optionData.button.Visible = visible
                    end
                    
                    -- Update canvas size
                    local visibleHeight = 0
                    for _, optionData in ipairs(optionButtons) do
                        if optionData.button.Visible then
                            visibleHeight = visibleHeight + 32
                        end
                    end
                    optionsFrame.CanvasSize = UDim2.new(0, 0, 0, visibleHeight)
                end
                
                -- Create option buttons
                for i, option in ipairs(optionsCopy) do
                    local optionValue = tostring(option)
                    local optionButton = Instance.new("TextButton")
                    optionButton.Size = UDim2.new(1, 0, 0, 32)
                    optionButton.BackgroundTransparency = 1
                    optionButton.Text = ""
                    optionButton.Parent = optionsFrame
                    
                    local optionFrame = Instance.new("Frame")
                    optionFrame.Size = UDim2.new(1, 0, 1, 0)
                    optionFrame.BackgroundTransparency = 1
                    optionFrame.Parent = optionButton
                    
                    local optionLabel = Instance.new("TextLabel")
                    optionLabel.Size = UDim2.new(1, -10, 1, 0)
                    optionLabel.Position = UDim2.new(0, 5, 0, 0)
                    optionLabel.BackgroundTransparency = 1
                    optionLabel.Text = optionValue
                    optionLabel.TextColor3 = Theme.TextSecondary
                    optionLabel.TextXAlignment = Enum.TextXAlignment.Left
                    optionLabel.Font = Enum.Font.Gotham
                    optionLabel.TextSize = 14
                    optionLabel.Parent = optionFrame
                    
                    table.insert(optionButtons, {
                        button = optionButton,
                        text = optionValue,
                        label = optionLabel,
                        frame = optionFrame
                    })
                    
                    optionButton.MouseButton1Click:Connect(function()
                        currentValue = optionValue
                        dropdown.Text = currentValue
                        
                        -- Close dropdown
                        isOpen = false
                        CreateTween(optionsContainer, {Size = UDim2.new(0.6, -5, 0, 0)}, 0.2):Play()
                        CreateTween(dropdownIcon, {Rotation = 0}):Play()
                        task.wait(0.2)
                        optionsContainer.Visible = false
                        
                        if callback then callback(currentValue) end
                    end)
                    
                    optionButton.MouseEnter:Connect(function()
                        CreateTween(optionFrame, {BackgroundTransparency = 0.9}):Play()
                        CreateTween(optionLabel, {TextColor3 = Theme.Text}):Play()
                    end)
                    
                    optionButton.MouseLeave:Connect(function()
                        CreateTween(optionFrame, {BackgroundTransparency = 1}):Play()
                        CreateTween(optionLabel, {TextColor3 = Theme.TextSecondary}):Play()
                    end)
                end
                
                -- Set initial canvas size
                optionsFrame.CanvasSize = UDim2.new(0, 0, 0, #optionsCopy * 32)
                
                -- Search functionality
                if searchInput then
                    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
                        filterOptions(searchInput.Text)
                    end)
                end
                
                -- Dropdown click handler
                dropdown.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        optionsContainer.Visible = true
                        local targetHeight = math.min(150, #optionsCopy * 32 + optionsStartY + 10)
                        CreateTween(optionsContainer, {Size = UDim2.new(0.6, -5, 0, targetHeight)}, 0.2):Play()
                        CreateTween(dropdownIcon, {Rotation = 180}):Play()
                        
                        -- Focus search if exists
                        if searchInput then
                            searchInput:CaptureFocus()
                        end
                    else
                        CreateTween(optionsContainer, {Size = UDim2.new(0.6, -5, 0, 0)}, 0.2):Play()
                        CreateTween(dropdownIcon, {Rotation = 0}):Play()
                        task.wait(0.2)
                        optionsContainer.Visible = false
                        
                        -- Clear search
                        if searchInput then
                            searchInput.Text = ""
                            filterOptions("")
                        end
                    end
                end)
                
                return {
                    SetValue = function(val) 
                        currentValue = val
                        dropdown.Text = currentValue
                    end,
                    GetValue = function()
                        return currentValue
                    end,
                    Close = function()
                        if isOpen then
                            isOpen = false
                            CreateTween(optionsContainer, {Size = UDim2.new(0.6, -5, 0, 0)}, 0.2):Play()
                            CreateTween(dropdownIcon, {Rotation = 0}):Play()
                            task.wait(0.2)
                            optionsContainer.Visible = false
                            
                            -- Clear search
                            if searchInput then
                                searchInput.Text = ""
                                filterOptions("")
                            end
                        end
                    end
                }
            end
            
            -- Add Multi Select Method
            methods.AddMultiDropdown = function(self, text, options, defaults, callback)
                -- Deep copy options
                local optionsCopy = {}
                if type(options) == "table" and #options > 0 then
                    for i, v in ipairs(options) do
                        optionsCopy[i] = tostring(v)
                    end
                else
                    optionsCopy = {"No options"}
                end
                
                -- Track selected options
                local selectedOptions = {}
                if defaults and type(defaults) == "table" then
                    for _, default in ipairs(defaults) do
                        selectedOptions[tostring(default)] = true
                    end
                end
                
                -- Main dropdown container
                local dropdownContainer = Instance.new("Frame")
                dropdownContainer.Size = UDim2.new(1, 0, 0, 35)
                dropdownContainer.BackgroundTransparency = 1
                dropdownContainer.AutomaticSize = Enum.AutomaticSize.Y
                dropdownContainer.Parent = sectionContent
                
                -- Top frame with label and dropdown button
                local dropdownFrame = Instance.new("Frame")
                dropdownFrame.Size = UDim2.new(1, 0, 0, 35)
                dropdownFrame.BackgroundTransparency = 1
                dropdownFrame.Parent = dropdownContainer
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(0.4, -5, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = text
                label.TextColor3 = Theme.Text
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Font = Enum.Font.Gotham
                label.TextSize = 14
                label.Parent = dropdownFrame
                
                local dropdown = Instance.new("TextButton")
                dropdown.Size = UDim2.new(0.6, -5, 1, 0)
                dropdown.Position = UDim2.new(0.4, 5, 0, 0)
                dropdown.BackgroundColor3 = Theme.Tertiary
                dropdown.BackgroundTransparency = 0.3
                dropdown.Text = "Select options..."
                dropdown.TextColor3 = Theme.Text
                dropdown.Font = Enum.Font.Gotham
                dropdown.TextSize = 14
                dropdown.AutoButtonColor = false
                dropdown.Parent = dropdownFrame
                
                -- Update display text based on selections
                local function updateDisplayText()
                    local selected = {}
                    for option, isSelected in pairs(selectedOptions) do
                        if isSelected then
                            table.insert(selected, option)
                        end
                    end
                    
                    if #selected == 0 then
                        dropdown.Text = "Select options..."
                    elseif #selected == 1 then
                        dropdown.Text = selected[1]
                    else
                        dropdown.Text = #selected .. " selected"
                    end
                end
                
                updateDisplayText()
                
                local dropdownCorner = Instance.new("UICorner")
                dropdownCorner.CornerRadius = UDim.new(0, 8)
                dropdownCorner.Parent = dropdown
                
                local dropdownIcon = Instance.new("TextLabel")
                dropdownIcon.Size = UDim2.new(0, 25, 1, 0)
                dropdownIcon.Position = UDim2.new(1, -30, 0, 0)
                dropdownIcon.BackgroundTransparency = 1
                dropdownIcon.Text = "▼"
                dropdownIcon.TextColor3 = Theme.TextSecondary
                dropdownIcon.Font = Enum.Font.Gotham
                dropdownIcon.TextSize = 12
                dropdownIcon.Parent = dropdown
                
                -- Options container that will expand
                local optionsContainer = Instance.new("Frame")
                optionsContainer.Size = UDim2.new(0.6, -5, 0, 0)
                optionsContainer.Position = UDim2.new(0.4, 5, 0, 40)
                optionsContainer.BackgroundColor3 = Theme.Secondary
                optionsContainer.BackgroundTransparency = 0.3
                optionsContainer.ClipsDescendants = true
                optionsContainer.Visible = false
                optionsContainer.Parent = dropdownContainer
                
                local optionsCorner = Instance.new("UICorner")
                optionsCorner.CornerRadius = UDim.new(0, 8)
                optionsCorner.Parent = optionsContainer

                local optionsStroke = Instance.new("UIStroke")
                optionsStroke.Color = Theme.Tertiary
                optionsStroke.Transparency = 0.5
                optionsStroke.Thickness = 1
                optionsStroke.Parent = optionsContainer
                
                -- Search bar (only if more than 5 options)
                local searchBar = nil
                local searchInput = nil
                local optionsStartY = 5
                
                if #optionsCopy > 5 then
                    searchBar = Instance.new("Frame")
                    searchBar.Size = UDim2.new(1, -10, 0, 30)
                    searchBar.Position = UDim2.new(0, 5, 0, 5)
                    searchBar.BackgroundTransparency = 1
                    searchBar.Parent = optionsContainer
                    
                    searchInput = Instance.new("TextBox")
                    searchInput.Size = UDim2.new(1, 0, 1, 0)
                    searchInput.BackgroundColor3 = Theme.Tertiary
                    searchInput.BackgroundTransparency = 0.5
                    searchInput.Text = ""
                    searchInput.PlaceholderText = "Search..."
                    searchInput.PlaceholderColor3 = Theme.TextDim
                    searchInput.TextColor3 = Theme.Text
                    searchInput.Font = Enum.Font.Gotham
                    searchInput.TextSize = 12
                    searchInput.ClearTextOnFocus = false
                    searchInput.Parent = searchBar
                    
                    local searchCorner = Instance.new("UICorner")
                    searchCorner.CornerRadius = UDim.new(0, 6)
                    searchCorner.Parent = searchInput
                    
                    optionsStartY = 40
                end
                
                -- Scrolling frame for options
                local optionsFrame = Instance.new("ScrollingFrame")
                optionsFrame.Size = UDim2.new(1, -10, 1, -optionsStartY - 5)
                optionsFrame.Position = UDim2.new(0, 5, 0, optionsStartY)
                optionsFrame.BackgroundTransparency = 1
                optionsFrame.BorderSizePixel = 0
                optionsFrame.ScrollBarThickness = 2
                optionsFrame.ScrollBarImageColor3 = Theme.Accent
                optionsFrame.ScrollBarImageTransparency = 0.5
                optionsFrame.Parent = optionsContainer
                
                local optionsLayout = Instance.new("UIListLayout")
                optionsLayout.Parent = optionsFrame
                
                local isOpen = false
                local optionButtons = {}
                
                -- Function to filter options
                local function filterOptions(searchText)
                    searchText = searchText:lower()
                    for _, optionData in ipairs(optionButtons) do
                        local optionText = optionData.text:lower()
                        local visible = searchText == "" or optionText:find(searchText, 1, true)
                        optionData.button.Visible = visible
                    end
                    
                    -- Update canvas size
                    local visibleHeight = 0
                    for _, optionData in ipairs(optionButtons) do
                        if optionData.button.Visible then
                            visibleHeight = visibleHeight + 32
                        end
                    end
                    optionsFrame.CanvasSize = UDim2.new(0, 0, 0, visibleHeight)
                end
                
                -- Create option buttons with checkboxes
                for i, option in ipairs(optionsCopy) do
                    local optionValue = tostring(option)
                    local optionButton = Instance.new("TextButton")
                    optionButton.Size = UDim2.new(1, 0, 0, 32)
                    optionButton.BackgroundTransparency = 1
                    optionButton.Text = ""
                    optionButton.Parent = optionsFrame
                    
                    local optionFrame = Instance.new("Frame")
                    optionFrame.Size = UDim2.new(1, 0, 1, 0)
                    optionFrame.BackgroundTransparency = 1
                    optionFrame.Parent = optionButton
                    
                    -- Checkbox
                    local checkbox = Instance.new("Frame")
                    checkbox.Size = UDim2.new(0, 18, 0, 18)
                    checkbox.Position = UDim2.new(0, 5, 0.5, -9)
                    checkbox.BackgroundColor3 = Theme.Tertiary
                    checkbox.BackgroundTransparency = 0.3
                    checkbox.Parent = optionFrame
                    
                    local checkboxCorner = Instance.new("UICorner")
                    checkboxCorner.CornerRadius = UDim.new(0, 4)
                    checkboxCorner.Parent = checkbox
                    
                    local checkmark = Instance.new("TextLabel")
                    checkmark.Size = UDim2.new(1, 0, 1, 0)
                    checkmark.BackgroundTransparency = 1
                    checkmark.Text = "✓"
                    checkmark.TextColor3 = Theme.Accent
                    checkmark.Font = Enum.Font.GothamBold
                    checkmark.TextSize = 14
                    checkmark.Visible = selectedOptions[optionValue] == true
                    checkmark.Parent = checkbox
                    
                    local optionLabel = Instance.new("TextLabel")
                    optionLabel.Size = UDim2.new(1, -35, 1, 0)
                    optionLabel.Position = UDim2.new(0, 30, 0, 0)
                    optionLabel.BackgroundTransparency = 1
                    optionLabel.Text = optionValue
                    optionLabel.TextColor3 = selectedOptions[optionValue] and Theme.Text or Theme.TextSecondary
                    optionLabel.TextXAlignment = Enum.TextXAlignment.Left
                    optionLabel.Font = Enum.Font.Gotham
                    optionLabel.TextSize = 14
                    optionLabel.Parent = optionFrame
                    
                    table.insert(optionButtons, {
                        button = optionButton,
                        text = optionValue,
                        label = optionLabel,
                        frame = optionFrame,
                        checkbox = checkbox,
                        checkmark = checkmark
                    })
                    
                    optionButton.MouseButton1Click:Connect(function()
                        selectedOptions[optionValue] = not selectedOptions[optionValue]
                        checkmark.Visible = selectedOptions[optionValue]
                        optionLabel.TextColor3 = selectedOptions[optionValue] and Theme.Text or Theme.TextSecondary
                        
                        updateDisplayText()
                        
                        -- Get selected list
                        local selected = {}
                        for opt, isSelected in pairs(selectedOptions) do
                            if isSelected then
                                table.insert(selected, opt)
                            end
                        end
                        
                        if callback then callback(selected) end
                    end)
                    
                    optionButton.MouseEnter:Connect(function()
                        CreateTween(optionFrame, {BackgroundTransparency = 0.9}):Play()
                        if not selectedOptions[optionValue] then
                            CreateTween(optionLabel, {TextColor3 = Theme.Text}):Play()
                        end
                    end)
                    
                    optionButton.MouseLeave:Connect(function()
                        CreateTween(optionFrame, {BackgroundTransparency = 1}):Play()
                        if not selectedOptions[optionValue] then
                            CreateTween(optionLabel, {TextColor3 = Theme.TextSecondary}):Play()
                        end
                    end)
                end
                
                -- Set initial canvas size
                optionsFrame.CanvasSize = UDim2.new(0, 0, 0, #optionsCopy * 32)
                
                -- Search functionality
                if searchInput then
                    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
                        filterOptions(searchInput.Text)
                    end)
                end
                
                -- Dropdown click handler
                dropdown.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        optionsContainer.Visible = true
                        local targetHeight = math.min(200, #optionsCopy * 32 + optionsStartY + 10)
                        CreateTween(optionsContainer, {Size = UDim2.new(0.6, -5, 0, targetHeight)}, 0.2):Play()
                        CreateTween(dropdownIcon, {Rotation = 180}):Play()
                        
                        -- Focus search if exists
                        if searchInput then
                            searchInput:CaptureFocus()
                        end
                    else
                        CreateTween(optionsContainer, {Size = UDim2.new(0.6, -5, 0, 0)}, 0.2):Play()
                        CreateTween(dropdownIcon, {Rotation = 0}):Play()
                        task.wait(0.2)
                        optionsContainer.Visible = false
                        
                        -- Clear search
                        if searchInput then
                            searchInput.Text = ""
                            filterOptions("")
                        end
                    end
                end)
                
                return {
                    SetValues = function(values) 
                        selectedOptions = {}
                        for _, val in ipairs(values) do
                            selectedOptions[tostring(val)] = true
                        end
                        updateDisplayText()
                        
                        -- Update checkmarks
                        for _, optionData in ipairs(optionButtons) do
                            local isSelected = selectedOptions[optionData.text] == true
                            optionData.checkmark.Visible = isSelected
                            optionData.label.TextColor3 = isSelected and Theme.Text or Theme.TextSecondary
                        end
                    end,
                    GetValues = function()
                        local selected = {}
                        for opt, isSelected in pairs(selectedOptions) do
                            if isSelected then
                                table.insert(selected, opt)
                            end
                        end
                        return selected
                    end,
                    Close = function()
                        if isOpen then
                            isOpen = false
                            CreateTween(optionsContainer, {Size = UDim2.new(0.6, -5, 0, 0)}, 0.2):Play()
                            CreateTween(dropdownIcon, {Rotation = 0}):Play()
                            task.wait(0.2)
                            optionsContainer.Visible = false
                        end
                    end
                }
            end
            
            -- Add Color Picker Method
            methods.AddColorPicker = function(self, text, default, callback)
                -- Main color picker container that will expand
                local colorContainer = Instance.new("Frame")
                colorContainer.Size = UDim2.new(1, 0, 0, 35)
                colorContainer.BackgroundTransparency = 1
                colorContainer.AutomaticSize = Enum.AutomaticSize.Y
                colorContainer.Parent = sectionContent
                
                -- Top frame with label and color display
                local colorFrame = Instance.new("Frame")
                colorFrame.Size = UDim2.new(1, 0, 0, 35)
                colorFrame.BackgroundTransparency = 1
                colorFrame.Parent = colorContainer
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -60, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = text
                label.TextColor3 = Theme.Text
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Font = Enum.Font.Gotham
                label.TextSize = 14
                label.Parent = colorFrame
                
                local colorDisplay = Instance.new("Frame")
                colorDisplay.Size = UDim2.new(0, 50, 0, 25)
                colorDisplay.Position = UDim2.new(1, -55, 0.5, -12.5)
                colorDisplay.BackgroundColor3 = default or Color3.fromRGB(255, 255, 255)
                colorDisplay.Parent = colorFrame
                
                local colorCorner = Instance.new("UICorner")
                colorCorner.CornerRadius = UDim.new(0, 6)
                colorCorner.Parent = colorDisplay
                
                local colorStroke = Instance.new("UIStroke")
                colorStroke.Color = Theme.Tertiary
                colorStroke.Transparency = 0.5
                colorStroke.Thickness = 1
                colorStroke.Parent = colorDisplay
                
                local colorButton = Instance.new("TextButton")
                colorButton.Size = UDim2.new(1, 0, 1, 0)
                colorButton.BackgroundTransparency = 1
                colorButton.Text = ""
                colorButton.Parent = colorDisplay
                
                local currentColor = default or Color3.fromRGB(255, 255, 255)
                
                -- Picker container that will expand
                local pickerContainer = Instance.new("Frame")
                pickerContainer.Size = UDim2.new(1, 0, 0, 0)
                pickerContainer.Position = UDim2.new(0, 0, 0, 40)
                pickerContainer.BackgroundColor3 = Theme.Secondary
                pickerContainer.BackgroundTransparency = 0.3
                pickerContainer.ClipsDescendants = true
                pickerContainer.Visible = false
                pickerContainer.Parent = colorContainer
                
                local pickerCorner = Instance.new("UICorner")
                pickerCorner.CornerRadius = UDim.new(0, 8)
                pickerCorner.Parent = pickerContainer
                
                local pickerStroke = Instance.new("UIStroke")
                pickerStroke.Color = Theme.Tertiary
                pickerStroke.Transparency = 0.5
                pickerStroke.Thickness = 1
                pickerStroke.Parent = pickerContainer
                
                -- Inner picker frame with padding
                local pickerFrame = Instance.new("Frame")
                pickerFrame.Size = UDim2.new(1, -20, 1, -20)
                pickerFrame.Position = UDim2.new(0, 10, 0, 10)
                pickerFrame.BackgroundTransparency = 1
                pickerFrame.Parent = pickerContainer
                
                -- Color preview
                local previewFrame = Instance.new("Frame")
                previewFrame.Size = UDim2.new(1, 0, 0, 30)
                previewFrame.Position = UDim2.new(0, 0, 0, 0)
                previewFrame.BackgroundColor3 = currentColor
                previewFrame.Parent = pickerFrame
                
                local previewCorner = Instance.new("UICorner")
                previewCorner.CornerRadius = UDim.new(0, 6)
                previewCorner.Parent = previewFrame
                
                -- RGB Sliders
                local function createSlider(name, position, value)
                    local sliderFrame = Instance.new("Frame")
                    sliderFrame.Size = UDim2.new(1, 0, 0, 30)
                    sliderFrame.Position = UDim2.new(0, 0, 0, position)
                    sliderFrame.BackgroundTransparency = 1
                    sliderFrame.Parent = pickerFrame
                    
                    local sliderLabel = Instance.new("TextLabel")
                    sliderLabel.Size = UDim2.new(0, 20, 1, 0)
                    sliderLabel.BackgroundTransparency = 1
                    sliderLabel.Text = name
                    sliderLabel.TextColor3 = Theme.Text
                    sliderLabel.Font = Enum.Font.Gotham
                    sliderLabel.TextSize = 12
                    sliderLabel.Parent = sliderFrame
                    
                    local sliderBg = Instance.new("Frame")
                    sliderBg.Size = UDim2.new(1, -80, 0, 6)
                    sliderBg.Position = UDim2.new(0, 25, 0.5, -3)
                    sliderBg.BackgroundColor3 = Theme.Tertiary
                    sliderBg.Parent = sliderFrame
                    
                    local sliderBgCorner = Instance.new("UICorner")
                    sliderBgCorner.CornerRadius = UDim.new(1, 0)
                    sliderBgCorner.Parent = sliderBg
                    
                    local sliderFill = Instance.new("Frame")
                    sliderFill.Size = UDim2.new(value/255, 0, 1, 0)
                    sliderFill.BackgroundColor3 = name == "R" and Color3.fromRGB(255, 0, 0) or name == "G" and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(0, 0, 255)
                    sliderFill.Parent = sliderBg
                    
                    local fillCorner = Instance.new("UICorner")
                    fillCorner.CornerRadius = UDim.new(1, 0)
                    fillCorner.Parent = sliderFill
                    
                    local sliderDot = Instance.new("Frame")
                    sliderDot.Size = UDim2.new(0, 12, 0, 12)
                    sliderDot.Position = UDim2.new(value/255, -6, 0.5, -6)
                    sliderDot.BackgroundColor3 = Theme.Text
                    sliderDot.Parent = sliderBg
                    
                    local dotCorner = Instance.new("UICorner")
                    dotCorner.CornerRadius = UDim.new(1, 0)
                    dotCorner.Parent = sliderDot
                    
                    local valueLabel = Instance.new("TextLabel")
                    valueLabel.Size = UDim2.new(0, 40, 1, 0)
                    valueLabel.Position = UDim2.new(1, -40, 0, 0)
                    valueLabel.BackgroundTransparency = 1
                    valueLabel.Text = tostring(math.floor(value))
                    valueLabel.TextColor3 = Theme.TextSecondary
                    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
                    valueLabel.Font = Enum.Font.Gotham
                    valueLabel.TextSize = 12
                    valueLabel.Parent = sliderFrame
                    
                    return {
                        SetValue = function(val)
                            sliderFill.Size = UDim2.new(val/255, 0, 1, 0)
                            sliderDot.Position = UDim2.new(val/255, -6, 0.5, -6)
                            valueLabel.Text = tostring(math.floor(val))
                        end,
                        Bg = sliderBg,
                        Dot = sliderDot,
                        Value = valueLabel
                    }
                end
                
                local rSlider = createSlider("R", 40, currentColor.R * 255)
                local gSlider = createSlider("G", 75, currentColor.G * 255)
                local bSlider = createSlider("B", 110, currentColor.B * 255)
                
                -- Hex input
                local hexFrame = Instance.new("Frame")
                hexFrame.Size = UDim2.new(1, 0, 0, 30)
                hexFrame.Position = UDim2.new(0, 0, 0, 150)
                hexFrame.BackgroundTransparency = 1
                hexFrame.Parent = pickerFrame
                
                local hexLabel = Instance.new("TextLabel")
                hexLabel.Size = UDim2.new(0, 35, 1, 0)
                hexLabel.BackgroundTransparency = 1
                hexLabel.Text = "Hex:"
                hexLabel.TextColor3 = Theme.Text
                hexLabel.Font = Enum.Font.Gotham
                hexLabel.TextSize = 12
                hexLabel.Parent = hexFrame
                
                local hexInput = Instance.new("TextBox")
                hexInput.Size = UDim2.new(1, -40, 1, 0)
                hexInput.Position = UDim2.new(0, 40, 0, 0)
                hexInput.BackgroundColor3 = Theme.Tertiary
                hexInput.BackgroundTransparency = 0.3
                hexInput.Text = string.format("#%02X%02X%02X", currentColor.R * 255, currentColor.G * 255, currentColor.B * 255)
                hexInput.TextColor3 = Theme.Text
                hexInput.Font = Enum.Font.Gotham
                hexInput.TextSize = 12
                hexInput.ClearTextOnFocus = false
                hexInput.Parent = hexFrame
                
                local hexCorner = Instance.new("UICorner")
                hexCorner.CornerRadius = UDim.new(0, 6)
                hexCorner.Parent = hexInput
                
                -- Apply button
                local applyButton = Instance.new("TextButton")
                applyButton.Size = UDim2.new(1, 0, 0, 30)
                applyButton.Position = UDim2.new(0, 0, 0, 190)
                applyButton.BackgroundColor3 = Theme.Accent
                applyButton.BackgroundTransparency = 0.3
                applyButton.Text = "Apply"
                applyButton.TextColor3 = Theme.Text
                applyButton.Font = Enum.Font.GothamMedium
                applyButton.TextSize = 14
                applyButton.AutoButtonColor = false
                applyButton.Parent = pickerFrame
                
                local applyCorner = Instance.new("UICorner")
                applyCorner.CornerRadius = UDim.new(0, 6)
                applyCorner.Parent = applyButton
                
                local pickerOpen = false
                
                -- Slider functionality
                local function handleSlider(slider, updateFunc)
                    local dragging = false
                    
                    slider.Bg.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging = true
                        end
                    end)
                    
                    UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging = false
                        end
                    end)
                    
                    UserInputService.InputChanged:Connect(function(input)
                        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                            local mousePos = UserInputService:GetMouseLocation()
                            local relativeX = mousePos.X - slider.Bg.AbsolutePosition.X
                            local percentage = math.clamp(relativeX / slider.Bg.AbsoluteSize.X, 0, 1)
                            local value = percentage * 255
                            
                            slider.SetValue(value)
                            updateFunc(value)
                        end
                    end)
                end
                
                local function updateColor()
                    local r = tonumber(rSlider.Value.Text) / 255
                    local g = tonumber(gSlider.Value.Text) / 255
                    local b = tonumber(bSlider.Value.Text) / 255
                    
                    currentColor = Color3.new(r, g, b)
                    previewFrame.BackgroundColor3 = currentColor
                    hexInput.Text = string.format("#%02X%02X%02X", r * 255, g * 255, b * 255)
                end
                
                handleSlider(rSlider, function(value) updateColor() end)
                handleSlider(gSlider, function(value) updateColor() end)
                handleSlider(bSlider, function(value) updateColor() end)
                
                -- Hex input handling
                hexInput.FocusLost:Connect(function()
                    local hex = hexInput.Text:gsub("#", "")
                    if #hex == 6 then
                        local r = tonumber(hex:sub(1, 2), 16)
                        local g = tonumber(hex:sub(3, 4), 16)
                        local b = tonumber(hex:sub(5, 6), 16)
                        
                        if r and g and b then
                            rSlider.SetValue(r)
                            gSlider.SetValue(g)
                            bSlider.SetValue(b)
                            updateColor()
                        end
                    end
                end)
                
                -- Apply button
                applyButton.MouseButton1Click:Connect(function()
                    colorDisplay.BackgroundColor3 = currentColor
                    pickerOpen = false
                    CreateTween(pickerContainer, {Size = UDim2.new(1, 0, 0, 0)}, 0.2):Play()
                    task.wait(0.2)
                    pickerContainer.Visible = false
                    
                    if callback then callback(currentColor) end
                end)
                
                -- Apply button hover
                applyButton.MouseEnter:Connect(function()
                    CreateTween(applyButton, {BackgroundTransparency = 0.2}):Play()
                end)
                
                applyButton.MouseLeave:Connect(function()
                    CreateTween(applyButton, {BackgroundTransparency = 0.3}):Play()
                end)
                
                -- Open/close picker
                colorButton.MouseButton1Click:Connect(function()
                    pickerOpen = not pickerOpen
                    if pickerOpen then
                        pickerContainer.Visible = true
                        CreateTween(pickerContainer, {Size = UDim2.new(1, 0, 0, 240)}, 0.2):Play()
                    else
                        CreateTween(pickerContainer, {Size = UDim2.new(1, 0, 0, 0)}, 0.2):Play()
                        task.wait(0.2)
                        pickerContainer.Visible = false
                    end
                end)
                
                return {
                    SetColor = function(color)
                        currentColor = color
                        colorDisplay.BackgroundColor3 = color
                        rSlider.SetValue(color.R * 255)
                        gSlider.SetValue(color.G * 255)
                        bSlider.SetValue(color.B * 255)
                        updateColor()
                    end,
                    GetColor = function()
                        return currentColor
                    end,
                    Close = function()
                        if pickerOpen then
                            pickerOpen = false
                            CreateTween(pickerContainer, {Size = UDim2.new(1, 0, 0, 0)}, 0.2):Play()
                            task.wait(0.2)
                            pickerContainer.Visible = false
                        end
                    end
                }
            end
            
            -- Add Keybind Method
            methods.AddKeybind = function(self, text, default, callback)
                local keybindFrame = Instance.new("Frame")
                keybindFrame.Size = UDim2.new(1, 0, 0, 35)
                keybindFrame.BackgroundTransparency = 1
                keybindFrame.Parent = sectionContent
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -100, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = text
                label.TextColor3 = Theme.Text
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Font = Enum.Font.Gotham
                label.TextSize = 14
                label.Parent = keybindFrame
                
                local keybindButton = Instance.new("TextButton")
                keybindButton.Size = UDim2.new(0, 90, 0, 25)
                keybindButton.Position = UDim2.new(1, -95, 0.5, -12.5)
                keybindButton.BackgroundColor3 = Theme.Tertiary
                keybindButton.BackgroundTransparency = 0.3
                keybindButton.Text = default and default.Name or "None"
                keybindButton.TextColor3 = Theme.Text
                keybindButton.Font = Enum.Font.Gotham
                keybindButton.TextSize = 12
                keybindButton.AutoButtonColor = false
                keybindButton.Parent = keybindFrame
                
                local keybindCorner = Instance.new("UICorner")
                keybindCorner.CornerRadius = UDim.new(0, 6)
                keybindCorner.Parent = keybindButton
                
                local currentKey = default
                local listening = false
                
                keybindButton.MouseButton1Click:Connect(function()
                    if listening then
                        listening = false
                        keybindButton.Text = currentKey and currentKey.Name or "None"
                        keybindButton.TextColor3 = Theme.Text
                    else
                        listening = true
                        keybindButton.Text = "..."
                        keybindButton.TextColor3 = Theme.Accent
                        
                        local connection
                        connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                            if not gameProcessed and input.KeyCode ~= Enum.KeyCode.Unknown then
                                currentKey = input.KeyCode
                                keybindButton.Text = currentKey.Name
                                keybindButton.TextColor3 = Theme.Text
                                listening = false
                                connection:Disconnect()
                                
                                -- Store in global keybinds
                                nobUI.Keybinds["Keybind_" .. text] = {
                                    key = currentKey,
                                    callback = function()
                                        if callback then callback(currentKey) end
                                    end
                                }
                                
                                -- Update keybind list
                                if nobUI.UpdateKeybindList then
                                    nobUI.UpdateKeybindList()
                                end
                            end
                        end)
                    end
                end)
                
                -- Hover effect
                keybindButton.MouseEnter:Connect(function()
                    CreateTween(keybindButton, {BackgroundTransparency = 0.2}):Play()
                end)
                
                keybindButton.MouseLeave:Connect(function()
                    CreateTween(keybindButton, {BackgroundTransparency = 0.3}):Play()
                end)
                
                return {
                    SetKey = function(key)
                        currentKey = key
                        keybindButton.Text = key and key.Name or "None"
                    end,
                    GetKey = function()
                        return currentKey
                    end
                }
            end
            
            -- Add TextBox Method
            methods.AddTextBox = function(self, text, default, callback)
                local textBoxFrame = Instance.new("Frame")
                textBoxFrame.Size = UDim2.new(1, 0, 0, 35)
                textBoxFrame.BackgroundTransparency = 1
                textBoxFrame.Parent = sectionContent
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(0.4, -5, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = text
                label.TextColor3 = Theme.Text
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Font = Enum.Font.Gotham
                label.TextSize = 14
                label.Parent = textBoxFrame
                
                local textBox = Instance.new("TextBox")
                textBox.Size = UDim2.new(0.6, -5, 1, 0)
                textBox.Position = UDim2.new(0.4, 5, 0, 0)
                textBox.BackgroundColor3 = Theme.Tertiary
                textBox.BackgroundTransparency = 0.3
                textBox.Text = default or ""
                textBox.TextColor3 = Theme.Text
                textBox.Font = Enum.Font.Gotham
                textBox.TextSize = 14
                textBox.ClearTextOnFocus = false
                textBox.Parent = textBoxFrame
                
                local textBoxCorner = Instance.new("UICorner")
                textBoxCorner.CornerRadius = UDim.new(0, 8)
                textBoxCorner.Parent = textBox
                
                textBox.FocusLost:Connect(function()
                    if callback then callback(textBox.Text) end
                end)
                
                return {
                    SetText = function(txt)
                        textBox.Text = txt
                    end,
                    GetText = function()
                        return textBox.Text
                    end
                }
            end
            
            -- Add Label Method
            methods.AddLabel = function(self, text)
                local labelFrame = Instance.new("Frame")
                labelFrame.Size = UDim2.new(1, 0, 0, 20)
                labelFrame.BackgroundTransparency = 1
                labelFrame.Parent = sectionContent
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = text
                label.TextColor3 = Theme.TextSecondary
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Font = Enum.Font.Gotham
                label.TextSize = 13
                label.Parent = labelFrame
                
                return {
                    SetText = function(txt)
                        label.Text = txt
                    end
                }
            end
            
            -- Add Paragraph Method
            methods.AddParagraph = function(self, title, text)
                local paragraphFrame = Instance.new("Frame")
                paragraphFrame.Size = UDim2.new(1, 0, 0, 0)
                paragraphFrame.BackgroundTransparency = 1
                paragraphFrame.AutomaticSize = Enum.AutomaticSize.Y
                paragraphFrame.Parent = sectionContent
                
                local titleLabel = Instance.new("TextLabel")
                titleLabel.Size = UDim2.new(1, 0, 0, 20)
                titleLabel.BackgroundTransparency = 1
                titleLabel.Text = title
                titleLabel.TextColor3 = Theme.Text
                titleLabel.TextXAlignment = Enum.TextXAlignment.Left
                titleLabel.Font = Enum.Font.GothamBold
                titleLabel.TextSize = 14
                titleLabel.Parent = paragraphFrame
                
                local textLabel = Instance.new("TextLabel")
                textLabel.Size = UDim2.new(1, 0, 0, 0)
                textLabel.Position = UDim2.new(0, 0, 0, 25)
                textLabel.BackgroundTransparency = 1
                textLabel.Text = text
                textLabel.TextColor3 = Theme.TextSecondary
                textLabel.TextXAlignment = Enum.TextXAlignment.Left
                textLabel.Font = Enum.Font.Gotham
                textLabel.TextSize = 13
                textLabel.TextWrapped = true
                textLabel.AutomaticSize = Enum.AutomaticSize.Y
                textLabel.Parent = paragraphFrame
                
                return {
                    SetTitle = function(txt)
                        titleLabel.Text = txt
                    end,
                    SetText = function(txt)
                        textLabel.Text = txt
                    end
                }
            end
            
            -- Add Divider Method
            methods.AddDivider = function(self)
                local divider = Instance.new("Frame")
                divider.Size = UDim2.new(1, 0, 0, 1)
                divider.BackgroundColor3 = Theme.Tertiary
                divider.BackgroundTransparency = 0.7
                divider.Parent = sectionContent
                
                local dividerPadding = Instance.new("Frame")
                dividerPadding.Size = UDim2.new(1, 0, 0, 10)
                dividerPadding.BackgroundTransparency = 1
                dividerPadding.Parent = sectionContent
            end
            
            -- Add Image Method
            methods.AddImage = function(self, imageId, size)
                local imageFrame = Instance.new("Frame")
                imageFrame.Size = UDim2.new(1, 0, 0, size or 100)
                imageFrame.BackgroundTransparency = 1
                imageFrame.Parent = sectionContent
                
                local image = Instance.new("ImageLabel")
                image.Size = UDim2.new(0, size or 100, 0, size or 100)
                image.Position = UDim2.new(0.5, -(size or 100)/2, 0, 0)
                image.BackgroundTransparency = 1
                image.Image = imageId
                image.ScaleType = Enum.ScaleType.Fit
                image.Parent = imageFrame
                
                return {
                    SetImage = function(id)
                        image.Image = id
                    end
                }
            end
            
            -- Assign all methods to section
            for methodName, method in pairs(methods) do
                section[methodName] = method
            end
            
            -- Debug: Verify methods are assigned
            print("[DEBUG] Section methods:", section.AddToggle, section.AddSlider, section.AddButton, section.AddDropdown, section.AddColorPicker, section.AddKeybind, section.AddTextBox, section.AddLabel, section.AddParagraph)
            
            table.insert(tab.Sections, section)
            return section
        end
        
        table.insert(window.Tabs, tab)
        return tab
    end
    
    return window
end

-- Cloud Config System
NobUI.CloudConfig = {}

function NobUI.CloudConfig:Save(name)
    local config = {}
    if writefile then
        writefile("NobUI_" .. name .. ".json", HttpService:JSONEncode(config))
    end
end

function NobUI.CloudConfig:Load(name)
    if readfile and isfile("NobUI_" .. name .. ".json") then
        local config = HttpService:JSONDecode(readfile("NobUI_" .. name .. ".json"))
    end
end

return NobUI