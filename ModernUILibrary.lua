local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local UI = {}
UI._VERSION = "2.0"

-- ==================== ЦВЕТОВАЯ ПАЛИТРА ====================
UI.Colors = {
    Primary = Color3.fromRGB(0, 180, 255),
    Secondary = Color3.fromRGB(0, 255, 255),
    Success = Color3.fromRGB(46, 204, 113),
    Danger = Color3.fromRGB(231, 76, 60),
    Warning = Color3.fromRGB(255, 193, 7),
    Info = Color3.fromRGB(52, 152, 219),
    Purple = Color3.fromRGB(155, 89, 182),
    Gold = Color3.fromRGB(255, 215, 0),
    Dark = Color3.fromRGB(20, 20, 30),
    Light = Color3.fromRGB(240, 240, 255)
}

-- ==================== УПРАВЛЕНИЕ РЕСУРСАМИ ====================
local activeTweens = {}
local activeConnections = {}

local function addConnection(conn)
    table.insert(activeConnections, conn)
end

local function addTween(tween)
    table.insert(activeTweens, tween)
    tween:Play()
end

function UI:Cleanup()
    for _, tween in pairs(activeTweens) do
        pcall(function() tween:Cancel() end)
    end
    for _, conn in pairs(activeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    activeTweens = {}
    activeConnections = {}
end

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================
local function applyGradient(frame, animated)
    animated = animated ~= false

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 80, 180)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 130, 230)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(0, 80, 180))
    }
    gradient.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0.0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1.0, 0.3)
    }
    gradient.Rotation = 0
    gradient.Offset = Vector2.new(-1, 0)
    gradient.Parent = frame

    if animated then
        local tween = TweenService:Create(
            gradient,
            TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Offset = Vector2.new(1, 0)}
        )
        addTween(tween)
    end

    return gradient
end

local function applyCorner(frame, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = frame
    return corner
end

local function applyStroke(frame, thickness, color, gradient)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness or 1
    stroke.Color = color or Color3.fromRGB(60, 80, 120)
    stroke.Transparency = 0.3
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = frame

    if gradient then
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 50, 100)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 150, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 100))
        }
        grad.Rotation = 45
        grad.Parent = stroke
    end

    return stroke
end

-- ==================== ГЛАВНОЕ ОКНО ====================
function UI:CreateWindow(config)
    config = config or {}

    local window = {
        Tabs = {},
        CurrentTab = nil,
        Config = {
            Title = config.Title or "UI Library",
            Size = config.Size or UDim2.new(0, 550, 0, 650),
            Theme = config.Theme or UI.Colors.Primary,
            Draggable = config.Draggable ~= false,
            CloseButton = config.CloseButton ~= false,
            MinimizeButton = config.MinimizeButton ~= false
        }
    }

    -- ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ModernUI_" .. tick()
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")

    -- Главный контейнер
    local mainContainer = Instance.new("Frame")
    mainContainer.Name = "MainContainer"
    mainContainer.Size = window.Config.Size
    mainContainer.Position = UDim2.new(0.5, -window.Config.Size.X.Offset/2, 0.5, -window.Config.Size.Y.Offset/2)
    mainContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    mainContainer.BorderSizePixel = 0
    mainContainer.ClipsDescendants = true
    mainContainer.Parent = screenGui

    applyCorner(mainContainer, 12)
    applyStroke(mainContainer, 2, window.Config.Theme, true)
    applyGradient(mainContainer, true)

    -- Заголовок
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    header.BackgroundTransparency = 0.3
    header.BorderSizePixel = 0
    header.Parent = mainContainer

    applyCorner(header, 12)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -120, 1, 0)
    titleLabel.Position = UDim2.new(0, 20, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = window.Config.Title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header

    -- Кнопки управления
    local buttonsContainer = Instance.new("Frame")
    buttonsContainer.Size = UDim2.new(0, 100, 0, 30)
    buttonsContainer.Position = UDim2.new(1, -110, 0.5, -15)
    buttonsContainer.BackgroundTransparency = 1
    buttonsContainer.Parent = header

    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonLayout.Padding = UDim.new(0, 8)
    buttonLayout.Parent = buttonsContainer

    if window.Config.MinimizeButton then
        local minimizeBtn = Instance.new("TextButton")
        minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
        minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        minimizeBtn.Text = "−"
        minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        minimizeBtn.Font = Enum.Font.GothamBold
        minimizeBtn.TextSize = 18
        minimizeBtn.Parent = buttonsContainer
        applyCorner(minimizeBtn, 6)

        local isMinimized = false
        addConnection(minimizeBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            local targetSize = isMinimized and UDim2.new(window.Config.Size.X.Scale, window.Config.Size.X.Offset, 0, 50) or window.Config.Size
            TweenService:Create(mainContainer, TweenInfo.new(0.3), {Size = targetSize}):Play()
            minimizeBtn.Text = isMinimized and "+" or "−"
        end))
    end

    if window.Config.CloseButton then
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        closeBtn.Text = "×"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 20
        closeBtn.Parent = buttonsContainer
        applyCorner(closeBtn, 6)

        addConnection(closeBtn.MouseButton1Click:Connect(function()
            UI:Cleanup()
            screenGui:Destroy()
        end))
    end

    -- Контейнер вкладок
    local tabsContainer = Instance.new("Frame")
    tabsContainer.Name = "TabsContainer"
    tabsContainer.Size = UDim2.new(0, 140, 1, -60)
    tabsContainer.Position = UDim2.new(0, 10, 0, 55)
    tabsContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    tabsContainer.BackgroundTransparency = 0.5
    tabsContainer.BorderSizePixel = 0
    tabsContainer.Parent = mainContainer

    applyCorner(tabsContainer, 8)
    applyStroke(tabsContainer, 1, Color3.fromRGB(40, 40, 60))

    local tabsList = Instance.new("UIListLayout")
    tabsList.Padding = UDim.new(0, 6)
    tabsList.Parent = tabsContainer

    local tabsPadding = Instance.new("UIPadding")
    tabsPadding.PaddingLeft = UDim.new(0, 8)
    tabsPadding.PaddingRight = UDim.new(0, 8)
    tabsPadding.PaddingTop = UDim.new(0, 8)
    tabsPadding.PaddingBottom = UDim.new(0, 8)
    tabsPadding.Parent = tabsContainer

    -- Контейнер контента
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, -170, 1, -60)
    contentContainer.Position = UDim2.new(0, 160, 0, 55)
    contentContainer.BackgroundTransparency = 1
    contentContainer.BorderSizePixel = 0
    contentContainer.Parent = mainContainer

    -- Draggable
    if window.Config.Draggable then
        local dragging, dragInput, dragStart, startPos

        addConnection(header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = mainContainer.Position

                addConnection(input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end))
            end
        end))

        addConnection(header.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                dragInput = input
            end
        end))

        addConnection(UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                mainContainer.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end))
    end

    window._screenGui = screenGui
    window._mainContainer = mainContainer
    window._tabsContainer = tabsContainer
    window._contentContainer = contentContainer

    -- Метод создания вкладки
    function window:CreateTab(config)
        config = config or {}

        local tab = {
            Name = config.Name or "Tab",
            Icon = config.Icon,
            Elements = {},
            Visible = false
        }

        -- Кнопка вкладки
        local tabButton = Instance.new("TextButton")
        tabButton.Size = UDim2.new(1, 0, 0, 40)
        tabButton.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
        tabButton.BackgroundTransparency = 0.3
        tabButton.Text = ""
        tabButton.AutoButtonColor = false
        tabButton.Parent = tabsContainer

        applyCorner(tabButton, 6)

        local tabLabel = Instance.new("TextLabel")
        tabLabel.Size = UDim2.new(1, tab.Icon and -40 or -16, 1, 0)
        tabLabel.Position = UDim2.new(0, tab.Icon and 40 or 8, 0, 0)
        tabLabel.BackgroundTransparency = 1
        tabLabel.Text = tab.Name
        tabLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
        tabLabel.Font = Enum.Font.GothamSemibold
        tabLabel.TextSize = 12
        tabLabel.TextXAlignment = Enum.TextXAlignment.Left
        tabLabel.Parent = tabButton

        if tab.Icon then
            local iconLabel = Instance.new("ImageLabel")
            iconLabel.Size = UDim2.new(0, 24, 0, 24)
            iconLabel.Position = UDim2.new(0, 8, 0.5, -12)
            iconLabel.BackgroundTransparency = 1
            iconLabel.Image = "rbxassetid://" .. tab.Icon
            iconLabel.ImageColor3 = Color3.fromRGB(180, 180, 200)
            iconLabel.ScaleType = Enum.ScaleType.Fit
            iconLabel.Parent = tabButton
        end

        -- Контейнер контента вкладки
        local tabContent = Instance.new("ScrollingFrame")
        tabContent.Size = UDim2.new(1, 0, 1, 0)
        tabContent.BackgroundTransparency = 1
        tabContent.BorderSizePixel = 0
        tabContent.ScrollBarThickness = 4
        tabContent.ScrollBarImageColor3 = window.Config.Theme
        tabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabContent.Visible = false
        tabContent.Parent = contentContainer

        local contentList = Instance.new("UIListLayout")
        contentList.Padding = UDim.new(0, 10)
        contentList.SortOrder = Enum.SortOrder.LayoutOrder
        contentList.Parent = tabContent

        local contentPadding = Instance.new("UIPadding")
        contentPadding.PaddingLeft = UDim.new(0, 10)
        contentPadding.PaddingRight = UDim.new(0, 10)
        contentPadding.PaddingTop = UDim.new(0, 10)
        contentPadding.PaddingBottom = UDim.new(0, 10)
        contentPadding.Parent = tabContent

        addConnection(contentList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabContent.CanvasSize = UDim2.new(0, 0, 0, contentList.AbsoluteContentSize.Y + 20)
        end))

        -- Переключение вкладки
        local function selectTab()
            for _, t in pairs(window.Tabs) do
                t._button.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
                t._button.BackgroundTransparency = 0.3
                t._label.TextColor3 = Color3.fromRGB(180, 180, 200)
                t._content.Visible = false
                if t._icon then
                    t._icon.ImageColor3 = Color3.fromRGB(180, 180, 200)
                end
            end

            tabButton.BackgroundColor3 = window.Config.Theme
            tabButton.BackgroundTransparency = 0.7
            tabLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            tabContent.Visible = true
            if tab.Icon then
                tabButton:FindFirstChildOfClass("ImageLabel").ImageColor3 = Color3.fromRGB(255, 255, 255)
            end

            window.CurrentTab = tab
        end

        addConnection(tabButton.MouseButton1Click:Connect(selectTab))

        tab._button = tabButton
        tab._label = tabLabel
        tab._content = tabContent
        tab._icon = tab.Icon and tabButton:FindFirstChildOfClass("ImageLabel")

        -- Если это первая вкладка, выбираем её
        if #window.Tabs == 0 then
            selectTab()
        end

        table.insert(window.Tabs, tab)

        -- МЕТОДЫ ДОБАВЛЕНИЯ ЭЛЕМЕНТОВ
        tab.AddLabel = function(self, config) return UI:_CreateLabel(tabContent, config) end
        tab.AddToggle = function(self, config) return UI:_CreateToggle(tabContent, config) end
        tab.AddSlider = function(self, config) return UI:_CreateSlider(tabContent, config) end
        tab.AddDropdown = function(self, config) return UI:_CreateDropdown(tabContent, config) end
        tab.AddButton = function(self, config) return UI:_CreateButton(tabContent, config) end
        tab.AddDivider = function(self, text) return UI:_CreateDivider(tabContent, text) end
        tab.AddIndicator = function(self, config) return UI:_CreateIndicator(tabContent, config) end
        tab.AddMultiLabel = function(self, config) return UI:_CreateMultiLabel(tabContent, config) end

        return tab
    end

    return window
end

-- ==================== DIVIDER (РАЗДЕЛИТЕЛЬ) ====================
function UI:_CreateDivider(parent, text)
    local divider = Instance.new("Frame")
    divider.Size = text and UDim2.new(1, 0, 0, 30) or UDim2.new(1, 0, 0, 2)
    divider.BackgroundTransparency = 1
    divider.Parent = parent

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.Position = text and UDim2.new(0, 0, 1, -1) or UDim2.new(0, 0, 0.5, 0)
    line.AnchorPoint = text and Vector2.new(0, 1) or Vector2.new(0, 0.5)
    line.BackgroundTransparency = 0.5
    line.BorderSizePixel = 0
    line.Parent = divider

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, UI.Colors.Primary),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    gradient.Offset = Vector2.new(-1, 0)
    gradient.Parent = line

    local tween = TweenService:Create(gradient, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Offset = Vector2.new(1, 0)})
    addTween(tween)

    if text then
        local textBg = Instance.new("Frame")
        textBg.Size = UDim2.new(0, 0, 0, 16)
        textBg.Position = UDim2.new(0.5, 0, 0, 0)
        textBg.AnchorPoint = Vector2.new(0.5, 0)
        textBg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
        textBg.BackgroundTransparency = 0.1
        textBg.Parent = divider
        applyCorner(textBg, 4)

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextSize = 11
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.Parent = textBg

        local textSize = TextService:GetTextSize(text, 11, Enum.Font.Gotham, Vector2.new(1000, 16))
        textBg.Size = UDim2.new(0, textSize.X + 16, 0, 16)
    end

    return divider
end

-- ==================== LABEL (ТЕКСТОВАЯ МЕТКА) ====================
function UI:_CreateLabel(parent, config)
    config = config or {}

    local element = {
        Text = config.Text or "Label",
        Color = config.Color or UI.Colors.Light
    }

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 40)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = parent

    applyCorner(container, 8)
    applyStroke(container, 1)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = element.Text
    label.TextColor3 = element.Color
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = container

    function element:SetText(text)
        self.Text = text
        label.Text = text
    end

    return element
end

-- ==================== TOGGLE (ПЕРЕКЛЮЧАТЕЛЬ) ====================
function UI:_CreateToggle(parent, config)
    config = config or {}

    local element = {
        Title = config.Title or "Toggle",
        Description = config.Description,
        Default = config.Default or false,
        Callback = config.Callback or function() end,
        Color = config.Color or UI.Colors.Primary,
        Value = config.Default or false
    }

    local height = element.Description and 70 or 50

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, height)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.Parent = parent

    applyCorner(container, 8)
    applyStroke(container, 1)
    applyGradient(container, false)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -80, 0, 20)
    titleLabel.Position = UDim2.new(0, 15, 0, element.Description and 12 or 15)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = element.Title
    titleLabel.TextColor3 = UI.Colors.Light
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    if element.Description then
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -80, 0, 16)
        descLabel.Position = UDim2.new(0, 15, 0, 36)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = element.Description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 10
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextWrapped = true
        descLabel.Parent = container
    end

    local toggleContainer = Instance.new("Frame")
    toggleContainer.Size = UDim2.new(0, 48, 0, 24)
    toggleContainer.Position = UDim2.new(1, -60, 0.5, -12)
    toggleContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    toggleContainer.Parent = container
    applyCorner(toggleContainer, 12)

    local toggleKnob = Instance.new("Frame")
    toggleKnob.Size = UDim2.new(0, 20, 0, 20)
    toggleKnob.Position = UDim2.new(0, 2, 0.5, -10)
    toggleKnob.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
    toggleKnob.Parent = toggleContainer
    applyCorner(toggleKnob, 10)

    local function updateToggle(animate)
        animate = animate ~= false
        local info = TweenInfo.new(animate and 0.2 or 0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        TweenService:Create(toggleKnob, info, {
            Position = element.Value and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10),
            BackgroundColor3 = element.Value and element.Color or Color3.fromRGB(100, 100, 120)
        }):Play()

        TweenService:Create(toggleContainer, info, {
            BackgroundColor3 = element.Value and Color3.fromRGB(0, 100, 180) or Color3.fromRGB(40, 40, 50)
        }):Play()
    end

    updateToggle(false)

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = toggleContainer

    addConnection(button.MouseButton1Click:Connect(function()
        element.Value = not element.Value
        updateToggle(true)
        task.spawn(element.Callback, element.Value)
    end))

    function element:SetValue(value)
        self.Value = value
        updateToggle(true)
    end

    function element:GetValue()
        return self.Value
    end

    return element
end

-- ==================== SLIDER (ПОЛЗУНОК) ====================
function UI:_CreateSlider(parent, config)
    config = config or {}

    local element = {
        Title = config.Title or "Slider",
        Description = config.Description,
        Min = config.Min or 0,
        Max = config.Max or 100,
        Default = config.Default or 50,
        Step = config.Step or 1,
        Decimals = config.Decimals or 0,
        Callback = config.Callback or function() end,
        Color = config.Color or UI.Colors.Primary,
        Value = config.Default or 50
    }

    local height = element.Description and 90 or 70

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, height)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.Parent = parent

    applyCorner(container, 8)
    applyStroke(container, 1)
    applyGradient(container, false)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -80, 0, 20)
    titleLabel.Position = UDim2.new(0, 15, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = element.Title
    titleLabel.TextColor3 = UI.Colors.Light
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    if element.Description then
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -80, 0, 14)
        descLabel.Position = UDim2.new(0, 15, 0, 34)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = element.Description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 10
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextWrapped = true
        descLabel.Parent = container
    end

    local function formatValue(val)
        if element.Decimals == 0 then
            return tostring(math.floor(val + 0.5))
        else
            return string.format("%." .. element.Decimals .. "f", val)
        end
    end

    local valueInput = Instance.new("TextBox")
    valueInput.Size = UDim2.new(0, 60, 0, 26)
    valueInput.Position = UDim2.new(1, -70, 0, element.Description and 48 or 36)
    valueInput.AnchorPoint = Vector2.new(0, 0.5)
    valueInput.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    valueInput.BackgroundTransparency = 0.3
    valueInput.TextColor3 = UI.Colors.Light
    valueInput.Font = Enum.Font.GothamMedium
    valueInput.TextSize = 12
    valueInput.Text = formatValue(element.Value)
    valueInput.TextXAlignment = Enum.TextXAlignment.Center
    valueInput.TextYAlignment = Enum.TextYAlignment.Center
    valueInput.ClearTextOnFocus = false
    valueInput.Parent = container

    applyCorner(valueInput, 6)
    applyStroke(valueInput, 1, Color3.fromRGB(60, 60, 80))

    local savedValue = valueInput.Text

    addConnection(valueInput.Focused:Connect(function()
        savedValue = valueInput.Text
        valueInput.Text = ""
    end))

    addConnection(valueInput.FocusLost:Connect(function()
        if valueInput.Text == "" then
            valueInput.Text = savedValue
        else
            local num = tonumber(valueInput.Text)
            if num then
                element:SetValue(num)
            else
                valueInput.Text = savedValue
            end
        end
    end))

    local sliderYPos = element.Description and 68 or 48

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -100, 0, 6)
    sliderBar.Position = UDim2.new(0, 15, 0, sliderYPos)
    sliderBar.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = container
    applyCorner(sliderBar, 3)

    local fillBar = Instance.new("Frame")
    fillBar.Size = UDim2.new(0, 0, 1, 0)
    fillBar.BackgroundColor3 = element.Color
    fillBar.BorderSizePixel = 0
    fillBar.Parent = sliderBar
    applyCorner(fillBar, 3)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, -8, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = sliderBar
    applyCorner(knob, 8)
    applyStroke(knob, 2, element.Color)

    local isDragging = false

    local function updateSlider(animate)
        local value = math.clamp(math.round(element.Value / element.Step) * element.Step, element.Min, element.Max)
        element.Value = value

        local progress = (value - element.Min) / (element.Max - element.Min)

        local info = TweenInfo.new(animate and 0.1 or 0, Enum.EasingStyle.Quad)
        TweenService:Create(fillBar, info, {Size = UDim2.new(progress, 0, 1, 0)}):Play()
        TweenService:Create(knob, info, {Position = UDim2.new(progress, -8, 0.5, -8)}):Play()

        valueInput.Text = formatValue(value)
        savedValue = valueInput.Text
    end

    updateSlider(false)

    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(1, 0, 0, 24)
    sliderButton.Position = UDim2.new(0, 0, 0.5, -12)
    sliderButton.BackgroundTransparency = 1
    sliderButton.Text = ""
    sliderButton.Parent = sliderBar

    addConnection(sliderButton.MouseButton1Down:Connect(function()
        isDragging = true
    end))

    addConnection(UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local pos = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
            element.Value = element.Min + (element.Max - element.Min) * pos
            updateSlider(true)
            task.spawn(element.Callback, element.Value)
        end
    end))

    addConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end))

    addConnection(sliderButton.MouseButton1Click:Connect(function()
        local pos = math.clamp((UserInputService:GetMouseLocation().X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
        element.Value = element.Min + (element.Max - element.Min) * pos
        updateSlider(true)
        task.spawn(element.Callback, element.Value)
    end))

    function element:SetValue(value)
        self.Value = math.clamp(value, self.Min, self.Max)
        updateSlider(true)
        task.spawn(self.Callback, self.Value)
    end

    function element:GetValue()
        return self.Value
    end

    return element
end

-- ==================== DROPDOWN (ВЫПАДАЮЩИЙ СПИСОК) ====================
function UI:_CreateDropdown(parent, config)
    config = config or {}

    local element = {
        Title = config.Title or "Dropdown",
        Description = config.Description,
        Options = config.Options or {"Option 1", "Option 2"},
        Default = config.Default or 1,
        Callback = config.Callback or function() end,
        Color = config.Color or UI.Colors.Primary,
        Value = config.Options[config.Default or 1] or config.Options[1],
        SelectedIndex = config.Default or 1
    }

    local height = element.Description and 90 or 70

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, height)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.ClipsDescendants = false
    container.Parent = parent

    applyCorner(container, 8)
    applyStroke(container, 1)
    applyGradient(container, false)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 20)
    titleLabel.Position = UDim2.new(0, 15, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = element.Title
    titleLabel.TextColor3 = UI.Colors.Light
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    if element.Description then
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -20, 0, 14)
        descLabel.Position = UDim2.new(0, 15, 0, 34)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = element.Description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 10
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextWrapped = true
        descLabel.Parent = container
    end

    local dropdownYPos = element.Description and 52 or 38

    local dropdownButton = Instance.new("TextButton")
    dropdownButton.Size = UDim2.new(1, -30, 0, 32)
    dropdownButton.Position = UDim2.new(0, 15, 0, dropdownYPos)
    dropdownButton.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    dropdownButton.BackgroundTransparency = 0.2
    dropdownButton.Text = ""
    dropdownButton.AutoButtonColor = false
    dropdownButton.Parent = container

    applyCorner(dropdownButton, 6)
    applyStroke(dropdownButton, 1, Color3.fromRGB(60, 80, 120))

    local selectedLabel = Instance.new("TextLabel")
    selectedLabel.Size = UDim2.new(1, -40, 1, 0)
    selectedLabel.Position = UDim2.new(0, 12, 0, 0)
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.Text = element.Value
    selectedLabel.TextColor3 = UI.Colors.Light
    selectedLabel.Font = Enum.Font.GothamSemibold
    selectedLabel.TextSize = 11
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.Parent = dropdownButton

    local arrowIcon = Instance.new("TextLabel")
    arrowIcon.Size = UDim2.new(0, 24, 0, 24)
    arrowIcon.Position = UDim2.new(1, -28, 0.5, -12)
    arrowIcon.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    arrowIcon.BackgroundTransparency = 0.3
    arrowIcon.Text = "▼"
    arrowIcon.TextColor3 = UI.Colors.Light
    arrowIcon.Font = Enum.Font.GothamBold
    arrowIcon.TextSize = 10
    arrowIcon.Parent = dropdownButton

    applyCorner(arrowIcon, 12)

    local dropdownList = Instance.new("ScrollingFrame")
    dropdownList.Size = UDim2.new(1, -30, 0, 0)
    dropdownList.Position = UDim2.new(0, 15, 1, 5)
    dropdownList.BackgroundColor3 = Color3.fromRGB(25, 32, 50)
    dropdownList.BackgroundTransparency = 0.1
    dropdownList.BorderSizePixel = 0
    dropdownList.Visible = false
    dropdownList.ScrollBarThickness = 4
    dropdownList.ScrollBarImageColor3 = element.Color
    dropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
    dropdownList.ZIndex = 100
    dropdownList.Parent = container

    applyCorner(dropdownList, 6)
    applyStroke(dropdownList, 1.5, Color3.fromRGB(70, 100, 160))

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = dropdownList

    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingLeft = UDim.new(0, 6)
    listPadding.PaddingRight = UDim.new(0, 6)
    listPadding.PaddingTop = UDim.new(0, 6)
    listPadding.PaddingBottom = UDim.new(0, 6)
    listPadding.Parent = dropdownList

    local isOpen = false
    local activeTweensLocal = {}

    local function closeDropdown()
        if not isOpen then return end
        isOpen = false

        for _, t in pairs(activeTweensLocal) do
            pcall(function() t:Cancel() end)
        end
        activeTweensLocal = {}

        arrowIcon.Text = "▼"
        local tween = TweenService:Create(dropdownList, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -30, 0, 0)})
        tween:Play()
        tween.Completed:Connect(function()
            if not isOpen then dropdownList.Visible = false end
        end)
    end

    local function openDropdown()
        if isOpen then return end
        isOpen = true
        dropdownList.Visible = true

        for _, t in pairs(activeTweensLocal) do
            pcall(function() t:Cancel() end)
        end
        activeTweensLocal = {}

        local targetHeight = math.min(listLayout.AbsoluteContentSize.Y + 12, 180)

        arrowIcon.Text = "▲"
        local tween = TweenService:Create(dropdownList, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -30, 0, targetHeight)})
        activeTweensLocal.openTween = tween
        tween:Play()
    end

    for i, option in ipairs(element.Options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, 0, 0, 30)
        optionButton.BackgroundColor3 = element.SelectedIndex == i and Color3.fromRGB(50, 70, 110) or Color3.fromRGB(35, 45, 65)
        optionButton.BackgroundTransparency = 0.2
        optionButton.AutoButtonColor = false
        optionButton.Text = ""
        optionButton.Parent = dropdownList

        applyCorner(optionButton, 4)

        local optionLabel = Instance.new("TextLabel")
        optionLabel.Size = UDim2.new(1, -16, 1, 0)
        optionLabel.Position = UDim2.new(0, 8, 0, 0)
        optionLabel.BackgroundTransparency = 1
        optionLabel.Text = option
        optionLabel.TextColor3 = Color3.fromRGB(230, 235, 255)
        optionLabel.Font = Enum.Font.Gotham
        optionLabel.TextSize = 11
        optionLabel.TextXAlignment = Enum.TextXAlignment.Left
        optionLabel.Parent = optionButton

        addConnection(optionButton.MouseEnter:Connect(function()
            if element.SelectedIndex ~= i then
                TweenService:Create(optionButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(45, 60, 95)}):Play()
            end
        end))

        addConnection(optionButton.MouseLeave:Connect(function()
            if element.SelectedIndex ~= i then
                TweenService:Create(optionButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(35, 45, 65)}):Play()
            end
        end))

        addConnection(optionButton.MouseButton1Click:Connect(function()
            for _, btn in pairs(dropdownList:GetChildren()) do
                if btn:IsA("TextButton") then
                    btn.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
                    btn.BackgroundTransparency = 0.2
                end
            end

            optionButton.BackgroundColor3 = Color3.fromRGB(50, 70, 110)
            element.SelectedIndex = i
            element.Value = option
            selectedLabel.Text = option

            closeDropdown()
            task.spawn(element.Callback, option, i)
        end))
    end

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        dropdownList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
    end)

    addConnection(dropdownButton.MouseButton1Click:Connect(function()
        if isOpen then
            closeDropdown()
        else
            openDropdown()
        end
    end))

    function element:SetValue(value)
        for i, opt in ipairs(self.Options) do
            if opt == value then
                self.SelectedIndex = i
                self.Value = value
                selectedLabel.Text = value

                for _, btn in pairs(dropdownList:GetChildren()) do
                    if btn:IsA("TextButton") then
                        btn.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
                    end
                end

                local targetBtn = dropdownList:GetChildren()[i + 2]
                if targetBtn and targetBtn:IsA("TextButton") then
                    targetBtn.BackgroundColor3 = Color3.fromRGB(50, 70, 110)
                end
                break
            end
        end
    end

    function element:GetValue()
        return self.Value
    end

    return element
end

-- ==================== BUTTON (КНОПКА) ====================
function UI:_CreateButton(parent, config)
    config = config or {}

    local element = {
        Title = config.Title or "Button",
        Callback = config.Callback or function() end,
        Color = config.Color or UI.Colors.Primary
    }

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 56)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -30, 0, 42)
    button.Position = UDim2.new(0, 15, 0.5, -21)
    button.BackgroundColor3 = element.Color
    button.BackgroundTransparency = 0.2
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = container

    applyCorner(button, 8)
    applyStroke(button, 2, element.Color)
    applyGradient(button, false)

    local buttonLabel = Instance.new("TextLabel")
    buttonLabel.Size = UDim2.new(1, 0, 1, 0)
    buttonLabel.BackgroundTransparency = 1
    buttonLabel.Text = element.Title
    buttonLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    buttonLabel.Font = Enum.Font.GothamBold
    buttonLabel.TextSize = 13
    buttonLabel.Parent = button

    local originalText = element.Title

    addConnection(button.MouseButton1Click:Connect(function()
        buttonLabel.Text = "✓ " .. originalText
        button.BackgroundColor3 = UI.Colors.Success

        task.spawn(element.Callback)

        task.wait(1)
        buttonLabel.Text = originalText
        button.BackgroundColor3 = element.Color
    end))

    addConnection(button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
    end))

    addConnection(button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
    end))

    return element
end

-- ==================== INDICATOR (ИНДИКАТОР СОСТОЯНИЯ) ====================
function UI:_CreateIndicator(parent, config)
    config = config or {}

    local element = {
        Title = config.Title or "Status",
        Status = config.Status or "Offline",
        Color = config.Color or UI.Colors.Danger
    }

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 46)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = parent

    applyCorner(container, 8)
    applyStroke(container, 1)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -120, 0, 18)
    titleLabel.Position = UDim2.new(0, 15, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = element.Title
    titleLabel.TextColor3 = UI.Colors.Light
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    local statusContainer = Instance.new("Frame")
    statusContainer.Size = UDim2.new(0, 100, 0, 24)
    statusContainer.Position = UDim2.new(1, -110, 0.5, -12)
    statusContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    statusContainer.BackgroundTransparency = 0.3
    statusContainer.BorderSizePixel = 0
    statusContainer.Parent = container

    applyCorner(statusContainer, 6)
    local statusStroke = applyStroke(statusContainer, 1, element.Color)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 8, 0.5, -4)
    dot.BackgroundColor3 = element.Color
    dot.BorderSizePixel = 0
    dot.Parent = statusContainer

    applyCorner(dot, 4)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -24, 1, 0)
    statusLabel.Position = UDim2.new(0, 20, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = element.Status
    statusLabel.TextColor3 = element.Color
    statusLabel.Font = Enum.Font.GothamSemibold
    statusLabel.TextSize = 10
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusContainer

    -- Пульсирующая анимация точки
    local pulseTween = TweenService:Create(
        dot,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BackgroundTransparency = 0.5}
    )
    addTween(pulseTween)

    function element:SetStatus(status, color)
        self.Status = status
        if color then self.Color = color end

        statusLabel.Text = status
        statusLabel.TextColor3 = self.Color
        dot.BackgroundColor3 = self.Color
        statusStroke.Color = self.Color
    end

    return element
end

-- ==================== MULTILABEL (СПИСОК С МАРКЕРАМИ) ====================
function UI:_CreateMultiLabel(parent, config)
    config = config or {}

    local element = {
        Title = config.Title or "Info",
        Lines = config.Lines or {"Line 1", "Line 2"},
        Color = config.Color or UI.Colors.Primary
    }

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 120)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.Parent = parent

    applyCorner(container, 10)
    applyStroke(container, 1.5)
    applyGradient(container, false)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -30, 0, 28)
    titleLabel.Position = UDim2.new(0, 15, 0, 12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = element.Title
    titleLabel.TextColor3 = element.Color
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -30, 0, 2)
    divider.Position = UDim2.new(0, 15, 0, 42)
    divider.BackgroundColor3 = element.Color
    divider.BackgroundTransparency = 0.5
    divider.BorderSizePixel = 0
    divider.Parent = container

    local linesContainer = Instance.new("Frame")
    linesContainer.Size = UDim2.new(1, -30, 0, 0)
    linesContainer.Position = UDim2.new(0, 15, 0, 50)
    linesContainer.BackgroundTransparency = 1
    linesContainer.Parent = container

    local linesList = Instance.new("UIListLayout")
    linesList.Padding = UDim.new(0, 6)
    linesList.Parent = linesContainer

    local lineLabels = {}

    for _, lineText in ipairs(element.Lines) do
        local lineFrame = Instance.new("Frame")
        lineFrame.Size = UDim2.new(1, 0, 0, 20)
        lineFrame.BackgroundTransparency = 1
        lineFrame.Parent = linesContainer

        local bullet = Instance.new("Frame")
        bullet.Size = UDim2.new(0, 6, 0, 6)
        bullet.Position = UDim2.new(0, 0, 0.5, -3)
        bullet.BackgroundColor3 = element.Color
        bullet.BorderSizePixel = 0
        bullet.Parent = lineFrame
        applyCorner(bullet, 3)

        local lineLabel = Instance.new("TextLabel")
        lineLabel.Size = UDim2.new(1, -14, 1, 0)
        lineLabel.Position = UDim2.new(0, 14, 0, 0)
        lineLabel.BackgroundTransparency = 1
        lineLabel.Text = lineText
        lineLabel.TextColor3 = UI.Colors.Light
        lineLabel.Font = Enum.Font.Gotham
        lineLabel.TextSize = 11
        lineLabel.TextXAlignment = Enum.TextXAlignment.Left
        lineLabel.TextWrapped = true
        lineLabel.Parent = lineFrame

        table.insert(lineLabels, lineLabel)
    end

    addConnection(linesList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h = linesList.AbsoluteContentSize.Y
        linesContainer.Size = UDim2.new(1, -30, 0, h)
        container.Size = UDim2.new(1, 0, 0, 65 + h)
    end))

    element.Labels = lineLabels

    function element:UpdateLine(index, text)
        if lineLabels[index] then
            lineLabels[index].Text = text
        end
    end

    return element
end

-- ==================== ФИНАЛ ====================
print("stuppp11")
return UI
