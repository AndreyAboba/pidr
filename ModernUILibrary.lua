-- ==================== MODERN UI LIBRARY V3.0 ====================
-- На основе оригинального дизайна Chess Helper
-- Версия: 3.0 FINAL
-- Дата: 2026-02-12
-- ==================================================================

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local UI = {}
UI._VERSION = "3.0"

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
local notificationContainer = nil

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
local function createEnhancedGradient(frame, animated)
    animated = animated ~= false

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 80, 180)),
        ColorSequenceKeypoint.new(0.1, Color3.fromRGB(10, 90, 190)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(30, 110, 210)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 130, 230)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(70, 150, 250)),
        ColorSequenceKeypoint.new(0.9, Color3.fromRGB(90, 170, 255)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(0, 80, 180))
    }
    gradient.Transparency = NumberSequence.new{
        ColorSequenceKeypoint.new(0.0, 0.3),
        ColorSequenceKeypoint.new(0.2, 0.1),
        ColorSequenceKeypoint.new(0.5, 0),
        ColorSequenceKeypoint.new(0.8, 0.1),
        ColorSequenceKeypoint.new(1.0, 0.3)
    }
    gradient.Rotation = 0
    gradient.Offset = Vector2.new(-1, 0)
    gradient.Parent = frame

    if animated then
        local tween = TweenService:Create(gradient, TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Offset = Vector2.new(1, 0)})
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

local function applyStroke(frame, thickness, color, gradientStroke)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness or 1
    stroke.Color = color or Color3.fromRGB(60, 80, 120)
    stroke.Transparency = 0.3
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = frame

    if gradientStroke then
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

local function createAccentBar(parent, accentColor)
    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, -2)
    accentBar.Position = UDim2.new(0, 0, 0, 1)
    accentBar.BackgroundTransparency = 0.6
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = 2
    accentBar.Parent = parent

    local accentGradient = Instance.new("UIGradient")
    accentGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, accentColor),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    accentGradient.Rotation = 90
    accentGradient.Parent = accentBar

    return accentBar, accentGradient
end

-- ==================== NOTIFY (УВЕДОМЛЕНИЯ) ====================
function UI:Notify(config)
    config = config or {}

    local title = config.Title or "Уведомление"
    local text = config.Text or "Текст уведомления"
    local duration = config.Duration or 3
    local color = config.Color or UI.Colors.Primary

    if not notificationContainer or not notificationContainer.Parent then
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "NotificationContainer_" .. tick()
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.DisplayOrder = 999999
        screenGui.Parent = game:GetService("CoreGui")

        notificationContainer = Instance.new("Frame")
        notificationContainer.Size = UDim2.new(0, 350, 1, 0)
        notificationContainer.Position = UDim2.new(1, -360, 0, 10)
        notificationContainer.BackgroundTransparency = 1
        notificationContainer.Parent = screenGui

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 10)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
        listLayout.Parent = notificationContainer
    end

    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(1, 0, 0, 0)
    notification.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    notification.BackgroundTransparency = 0.1
    notification.BorderSizePixel = 0
    notification.ClipsDescendants = true
    notification.Parent = notificationContainer

    applyCorner(notification, 10)
    applyStroke(notification, 2, color, true)
    createEnhancedGradient(notification, false)

    local accentBar, accentGrad = createAccentBar(notification, color)

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, 0)
    contentFrame.Position = UDim2.new(0, 10, 0, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = notification

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -30, 0, 20)
    titleLabel.Position = UDim2.new(0, 10, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = color
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = contentFrame

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -30, 0, 0)
    textLabel.Position = UDim2.new(0, 10, 0, 30)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = UI.Colors.Light
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 11
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextWrapped = true
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.Parent = contentFrame

    local textSize = TextService:GetTextSize(text, 11, Enum.Font.Gotham, Vector2.new(310, 1000))
    local totalHeight = 40 + textSize.Y + 16

    notification.Size = UDim2.new(1, 0, 0, 0)
    local openTween = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, totalHeight)})
    openTween:Play()

    local progressBar = Instance.new("Frame")
    progressBar.Size = UDim2.new(1, 0, 0, 3)
    progressBar.Position = UDim2.new(0, 0, 1, -3)
    progressBar.BackgroundColor3 = color
    progressBar.BorderSizePixel = 0
    progressBar.Parent = notification

    local progressTween = TweenService:Create(progressBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)})
    progressTween:Play()

    task.delay(duration, function()
        local closeTween = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0)})
        closeTween:Play()
        closeTween.Completed:Connect(function()
            notification:Destroy()
        end)
    end)
end

-- ==================== ГЛАВНОЕ ОКНО ====================
function UI:CreateWindow(config)
    config = config or {}

    local window = {
        Tabs = {},
        CurrentTab = nil,
        Config = {
            Title = config.Title or "UI Library",
            Size = config.Size or UDim2.new(0, 700, 0, 550),
            Theme = config.Theme or UI.Colors.Primary,
            Draggable = config.Draggable ~= false,
            CloseButton = config.CloseButton ~= false,
            MinimizeButton = config.MinimizeButton ~= false
        }
    }

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ModernUI_" .. tick()
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")

    local mainContainer = Instance.new("Frame")
    mainContainer.Name = "MainContainer"
    mainContainer.Size = window.Config.Size
    mainContainer.Position = UDim2.new(0.5, -window.Config.Size.X.Offset/2, 0.5, -window.Config.Size.Y.Offset/2)
    mainContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    mainContainer.BackgroundTransparency = 0.2
    mainContainer.BorderSizePixel = 0
    mainContainer.ClipsDescendants = true
    mainContainer.Parent = screenGui

    createEnhancedGradient(mainContainer, true)
    applyCorner(mainContainer, 14)
    applyStroke(mainContainer, 3, window.Config.Theme, true)

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    header.BackgroundTransparency = 0.3
    header.BorderSizePixel = 0
    header.Parent = mainContainer

    applyCorner(header, 14)

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

    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, -170, 1, -60)
    contentContainer.Position = UDim2.new(0, 160, 0, 55)
    contentContainer.BackgroundTransparency = 1
    contentContainer.BorderSizePixel = 0
    contentContainer.Parent = mainContainer

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
                mainContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end))
    end

    window._screenGui = screenGui
    window._mainContainer = mainContainer
    window._tabsContainer = tabsContainer
    window._contentContainer = contentContainer

    function window:CreateTab(config)
        config = config or {}

        local tab = {
            Name = config.Name or "Tab",
            Icon = config.Icon,
            Elements = {},
            Visible = false
        }

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
        contentList.Padding = UDim.new(0, 12)
        contentList.SortOrder = Enum.SortOrder.LayoutOrder
        contentList.Parent = tabContent

        local contentPadding = Instance.new("UIPadding")
        contentPadding.PaddingLeft = UDim.new(0, 12)
        contentPadding.PaddingRight = UDim.new(0, 12)
        contentPadding.PaddingTop = UDim.new(0, 12)
        contentPadding.PaddingBottom = UDim.new(0, 12)
        contentPadding.Parent = tabContent

        addConnection(contentList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabContent.CanvasSize = UDim2.new(0, 0, 0, contentList.AbsoluteContentSize.Y + 24)
        end))

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

        if #window.Tabs == 0 then
            selectTab()
        end

        table.insert(window.Tabs, tab)

        tab.AddLabel = function(self, config) return UI:_CreateLabel(tabContent, config) end
        tab.AddToggle = function(self, config) return UI:_CreateToggle(tabContent, config) end
        tab.AddSlider = function(self, config) return UI:_CreateSlider(tabContent, config) end
        tab.AddDropdown = function(self, config) return UI:_CreateDropdown(tabContent, config, screenGui) end
        tab.AddButton = function(self, config) return UI:_CreateButton(tabContent, config) end
        tab.AddDivider = function(self, text) return UI:_CreateDivider(tabContent, text) end
        tab.AddIndicator = function(self, config) return UI:_CreateIndicator(tabContent, config) end
        tab.AddMultiLabel = function(self, config) return UI:_CreateMultiLabel(tabContent, config) end

        return tab
    end

    return window
end

print("✅ Modern UI Library V3.0 - Часть 1/4 загружена")

-- ==================== DIVIDER (РАЗДЕЛИТЕЛЬ) ====================
function UI:_CreateDivider(parent, text)
    local dividerContainer = Instance.new("Frame")

    if text then
        dividerContainer.Size = UDim2.new(1, 0, 0, 28)
    else
        dividerContainer.Size = UDim2.new(1, 0, 0, 2)
    end

    dividerContainer.BackgroundTransparency = 1
    dividerContainer.ClipsDescendants = true
    dividerContainer.Parent = parent

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 2)

    if text then
        divider.Position = UDim2.new(0, 0, 1, -1)
        divider.AnchorPoint = Vector2.new(0, 1)
    else
        divider.Position = UDim2.new(0, 0, 0.5, 0)
        divider.AnchorPoint = Vector2.new(0, 0.5)
    end

    divider.BackgroundTransparency = 0.7
    divider.BorderSizePixel = 0
    divider.Parent = dividerContainer

    local mainGradient = Instance.new("UIGradient")
    mainGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(50, 150, 255)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 200, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    mainGradient.Rotation = 0
    mainGradient.Offset = Vector2.new(-1, 0)
    mainGradient.Parent = divider

    local tween = TweenService:Create(mainGradient, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Offset = Vector2.new(1, 0)})
    addTween(tween)

    if text then
        local textContainer = Instance.new("Frame")
        textContainer.Size = UDim2.new(1, 0, 0, 18)
        textContainer.Position = UDim2.new(0, 0, 0, 0)
        textContainer.BackgroundTransparency = 1
        textContainer.Parent = dividerContainer

        local textBg = Instance.new("Frame")
        textBg.Size = UDim2.new(0, 0, 0, 14)
        textBg.Position = UDim2.new(0.5, 0, 0, 0)
        textBg.AnchorPoint = Vector2.new(0.5, 0)
        textBg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        textBg.BackgroundTransparency = 0.1
        textBg.ZIndex = 2
        textBg.Parent = textContainer

        local textBgCorner = Instance.new("UICorner")
        textBgCorner.CornerRadius = UDim.new(0, 4)
        textBgCorner.Parent = textBg

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextSize = 10
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.TextYAlignment = Enum.TextYAlignment.Center
        textLabel.ZIndex = 3
        textLabel.Parent = textBg

        local textSize = TextService:GetTextSize(text, 10, Enum.Font.Gotham, Vector2.new(1000, 14))
        textBg.Size = UDim2.new(0, textSize.X + 12, 0, 14)
    end

    return dividerContainer
end

-- ==================== LABEL (ТЕКСТОВАЯ МЕТКА) ====================
function UI:_CreateLabel(parent, config)
    config = config or {}

    local element = {
        Text = config.Text or "Label",
        Color = config.Color or UI.Colors.Light
    }

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 42)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    container.BackgroundTransparency = 0.15
    container.BorderSizePixel = 0
    container.Parent = parent

    createEnhancedGradient(container, false)
    applyCorner(container, 8)
    applyStroke(container, 1, nil, false)

    createAccentBar(container, element.Color)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 16, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = element.Text
    label.TextColor3 = Color3.fromRGB(240, 240, 255)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 10
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

    local height = element.Description and 68 or 50
    local titleHeight = 18
    local descriptionHeight = element.Description and 14 or 0

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, height)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    container.BackgroundTransparency = 0.15
    container.BorderSizePixel = 0
    container.Parent = parent

    createEnhancedGradient(container, true)
    applyCorner(container, 8)
    applyStroke(container, 1, nil, true)

    local accentBar, accentGrad = createAccentBar(container, element.Color)

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = container

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -70, 0, titleHeight)
    titleLabel.Position = UDim2.new(0, 16, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = element.Title
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Top
    titleLabel.Parent = contentFrame

    if element.Description then
        local divider = Instance.new("Frame")
        divider.Size = UDim2.new(1, -16, 0, 1)
        divider.Position = UDim2.new(0, 16, 0, titleHeight + 11)
        divider.BackgroundColor3 = element.Color
        divider.BackgroundTransparency = 0.5
        divider.BorderSizePixel = 0
        divider.ZIndex = 1
        divider.Parent = contentFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -70, 0, descriptionHeight)
        descLabel.Position = UDim2.new(0, 16, 0, titleHeight + 20)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = element.Description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 11
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.TextWrapped = true
        descLabel.Parent = contentFrame
    end

    local toggleYPos = element.Description and (titleHeight + descriptionHeight + 2) or (titleHeight + 1)

    local toggleContainer = Instance.new("Frame")
    toggleContainer.Size = UDim2.new(0, 48, 0, 24)
    toggleContainer.Position = UDim2.new(1, -16, 0, toggleYPos)
    toggleContainer.AnchorPoint = Vector2.new(1, 0)
    toggleContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    toggleContainer.ZIndex = 2
    toggleContainer.Parent = contentFrame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 12)
    toggleCorner.Parent = toggleContainer

    local toggleFill = Instance.new("Frame")
    toggleFill.Size = UDim2.new(0, 20, 0, 20)
    toggleFill.Position = UDim2.new(0, 2, 0.5, 0)
    toggleFill.AnchorPoint = Vector2.new(0, 0.5)
    toggleFill.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
    toggleFill.ZIndex = 3
    toggleFill.Parent = toggleContainer

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 10)
    fillCorner.Parent = toggleFill

    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Color3.fromRGB(60, 60, 80)
    toggleStroke.Thickness = 1
    toggleStroke.Parent = toggleContainer

    local function updateToggle()
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        local fillTween = TweenService:Create(toggleFill, tweenInfo, {
            Position = UDim2.new(element.Value and 1 or 0, element.Value and -22 or 2, 0.5, 0),
            BackgroundColor3 = element.Value and element.Color or Color3.fromRGB(100, 100, 120)
        })
        fillTween:Play()

        local bgTween = TweenService:Create(toggleContainer, tweenInfo, {
            BackgroundColor3 = element.Value and Color3.fromRGB(0, 100, 180) or Color3.fromRGB(40, 40, 50)
        })
        bgTween:Play()
    end

    updateToggle()

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1, 0, 1, 0)
    toggleButton.BackgroundTransparency = 1
    toggleButton.Text = ""
    toggleButton.ZIndex = 4
    toggleButton.Parent = toggleContainer

    addConnection(toggleButton.MouseButton1Click:Connect(function()
        element.Value = not element.Value
        updateToggle()
        task.spawn(element.Callback, element.Value)
    end))

    function element:SetValue(value)
        self.Value = value
        updateToggle()
    end

    function element:GetValue()
        return self.Value
    end

    return element
end

print("✅ Modern UI Library V3.0 - Часть 2/4 загружена (Divider, Label, Toggle)")

-- ==================== SLIDER ====================
function UI:_CreateSlider(parent, config)
    config = config or {}

    local element = {
        Title = config.Title or "Slider",
        Description = config.Description,
        Min = config.Min or 0,
        Max = config.Max or 100,
        Default = config.Default or 50,
        Step = config.Step or 1,
        Callback = config.Callback or function() end,
        Color = config.Color or UI.Colors.Primary,
        AllowInput = config.AllowInput ~= false,
        Decimals = config.Decimals or 0,
        Value = config.Default or config.Min or 0
    }

    local height = element.Description and 86 or 70
    local titleHeight = 18
    local descriptionHeight = element.Description and 14 or 0

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, height)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    container.BackgroundTransparency = 0.15
    container.BorderSizePixel = 0
    container.Parent = parent

    createEnhancedGradient(container, true)
    applyCorner(container, 8)
    applyStroke(container, 1, nil, true)

    createAccentBar(container, element.Color)

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = container

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, element.AllowInput and -60 or 0, 0, titleHeight)
    titleLabel.Position = UDim2.new(0, 16, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = element.Title
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = contentFrame

    if element.Description then
        local divider = Instance.new("Frame")
        divider.Size = UDim2.new(1, -16, 0, 1)
        divider.Position = UDim2.new(0, 16, 0, titleHeight + 11)
        divider.BackgroundColor3 = element.Color
        divider.BackgroundTransparency = 0.5
        divider.BorderSizePixel = 0
        divider.ZIndex = 1
        divider.Parent = contentFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, element.AllowInput and -60 or 0, 0, descriptionHeight)
        descLabel.Position = UDim2.new(0, 16, 0, titleHeight + 20)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = element.Description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 11
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.TextWrapped = true
        descLabel.Parent = contentFrame
    end

    local sliderYPos = element.Description and (titleHeight + descriptionHeight + 32) or (titleHeight + 28)

    local savedValue = tostring(element.Default or element.Min)

    local function formatValue(val)
        if element.Decimals == 0 then
            return tostring(math.floor(val + 0.5))
        else
            local format = "%." .. element.Decimals .. "f"
            return string.format(format, val)
        end
    end

    local valueDisplay
    if element.AllowInput then
        valueDisplay = Instance.new("TextBox")
        valueDisplay.Size = UDim2.new(0, 50, 0, 24)
        valueDisplay.Position = UDim2.new(1, -58, 0, sliderYPos - 10)
        valueDisplay.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        valueDisplay.BackgroundTransparency = 0.2
        valueDisplay.TextColor3 = Color3.fromRGB(220, 220, 255)
        valueDisplay.Font = Enum.Font.Gotham
        valueDisplay.TextSize = 11
        valueDisplay.Text = formatValue(element.Value)
        valueDisplay.ClearTextOnFocus = false
        valueDisplay.ZIndex = 2
        valueDisplay.Parent = contentFrame

        applyCorner(valueDisplay, 4)

        local valuePadding = Instance.new("UIPadding")
        valuePadding.PaddingLeft = UDim.new(0, 6)
        valuePadding.PaddingRight = UDim.new(0, 6)
        valuePadding.Parent = valueDisplay

        addConnection(valueDisplay.Focused:Connect(function()
            savedValue = valueDisplay.Text
            valueDisplay.Text = ""
        end))
    else
        valueDisplay = Instance.new("TextLabel")
        valueDisplay.Size = UDim2.new(0, 50, 0, 24)
        valueDisplay.Position = UDim2.new(1, -78, 0, sliderYPos - 10)
        valueDisplay.BackgroundTransparency = 1
        valueDisplay.TextColor3 = Color3.fromRGB(200, 200, 255)
        valueDisplay.Font = Enum.Font.Gotham
        valueDisplay.TextSize = 11
        valueDisplay.Text = formatValue(element.Value)
        valueDisplay.TextXAlignment = Enum.TextXAlignment.Right
        valueDisplay.Parent = contentFrame
    end

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -84, 0, 6)
    sliderBar.Position = UDim2.new(0, 16, 0, sliderYPos)
    sliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    sliderBar.ZIndex = 2
    sliderBar.Parent = contentFrame

    applyCorner(sliderBar, 3)

    local fillBar = Instance.new("Frame")
    fillBar.Size = UDim2.new(0, 0, 1, 0)
    fillBar.BackgroundColor3 = element.Color
    fillBar.ZIndex = 3
    fillBar.Parent = sliderBar

    applyCorner(fillBar, 3)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, -7, 0.5, 0)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.ZIndex = 5
    knob.Parent = sliderBar

    applyCorner(knob, 7)

    local knobGradient = Instance.new("UIGradient")
    knobGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 235, 245))
    }
    knobGradient.Rotation = 90
    knobGradient.Parent = knob

    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = Color3.fromRGB(180, 180, 200)
    knobStroke.Thickness = 1.2
    knobStroke.Transparency = 0.3
    knobStroke.Parent = knob

    local innerShadow = Instance.new("Frame")
    innerShadow.Size = UDim2.new(0, 8, 0, 8)
    innerShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    innerShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    innerShadow.BackgroundColor3 = Color3.fromRGB(200, 200, 220)
    innerShadow.BackgroundTransparency = 0.7
    innerShadow.ZIndex = 6
    innerShadow.Parent = knob

    applyCorner(innerShadow, 4)

    local isDragging = false

    local function roundToStep(num)
        return math.round(num / element.Step) * element.Step
    end

    local function updateValue(newValue, skipCallback)
        newValue = math.clamp(roundToStep(newValue), element.Min, element.Max)
        if newValue == element.Value then return end

        element.Value = newValue
        local progress = (element.Value - element.Min) / (element.Max - element.Min)

        fillBar.Size = UDim2.new(progress, 0, 1, 0)
        knob.Position = UDim2.new(progress, -7, 0.5, 0)

        local displayText = formatValue(element.Value)
        if element.AllowInput then
            valueDisplay.Text = displayText
            savedValue = displayText
        else
            valueDisplay.Text = displayText
        end

        if not skipCallback then
            task.spawn(element.Callback, element.Value)
        end
    end

    updateValue(element.Value, true)

    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(1, -84, 0, 20)
    sliderButton.Position = UDim2.new(0, 16, 0, sliderYPos - 7)
    sliderButton.BackgroundTransparency = 1
    sliderButton.Text = ""
    sliderButton.ZIndex = 7
    sliderButton.Parent = contentFrame

    addConnection(sliderButton.MouseButton1Down:Connect(function()
        isDragging = true
    end))

    addConnection(UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = input.Position
            local barAbsPos = sliderBar.AbsolutePosition
            local barAbsSize = sliderBar.AbsoluteSize.X

            local relativeX = (mousePos.X - barAbsPos.X) / barAbsSize
            relativeX = math.clamp(relativeX, 0, 1)

            local newValue = element.Min + (element.Max - element.Min) * relativeX
            updateValue(newValue, false)
        end
    end))

    addConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end))

    if element.AllowInput then
        addConnection(valueDisplay.FocusLost:Connect(function(enterPressed)
            if valueDisplay.Text == "" then
                valueDisplay.Text = savedValue
            else
                local num = tonumber(valueDisplay.Text)
                if num then
                    updateValue(num, false)
                else
                    valueDisplay.Text = savedValue
                end
            end
        end))
    end

    addConnection(sliderButton.MouseButton1Click:Connect(function()
        local mousePos = UserInputService:GetMouseLocation()
        local barAbsPos = sliderBar.AbsolutePosition
        local barAbsSize = sliderBar.AbsoluteSize.X

        local relativeX = (mousePos.X - barAbsPos.X) / barAbsSize
        relativeX = math.clamp(relativeX, 0, 1)

        local newValue = element.Min + (element.Max - element.Min) * relativeX
        updateValue(newValue, false)
    end))

    function element:SetValue(value)
        updateValue(value, false)
    end

    function element:GetValue()
        return self.Value
    end

    return element
end

print("✅ Modern UI Library V3.0 - Часть 3/4 загружена (Slider)")

-- ==================== DROPDOWN (ВЫПАДАЮЩИЙ СПИСОК) ====================
function UI:_CreateDropdown(parent, config, screenGui)
    config = config or {}

    local element = {
        Title = config.Title or "Dropdown",
        Description = config.Description,
        Options = config.Options or {"Option 1", "Option 2", "Option 3"},
        Default = config.Default or 1,
        Callback = config.Callback or function() end,
        Color = config.Color or UI.Colors.Primary,
        Value = nil,
        SelectedIndex = config.Default or 1
    }

    element.Value = element.Options[element.SelectedIndex] or element.Options[1]

    local height = element.Description and 94 or 52
    local titleHeight = 18
    local descriptionHeight = element.Description and 16 or 0

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, height)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    container.BackgroundTransparency = 0.15
    container.BorderSizePixel = 0
    container.ClipsDescendants = false
    container.Parent = parent

    createEnhancedGradient(container, true)
    applyCorner(container, 8)
    applyStroke(container, 1, nil, true)

    createAccentBar(container, element.Color)

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = container

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, titleHeight)
    titleLabel.Position = UDim2.new(0, 16, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = element.Title
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = contentFrame

    if element.Description then
        local divider = Instance.new("Frame")
        divider.Size = UDim2.new(1, -16, 0, 1)
        divider.Position = UDim2.new(0, 16, 0, titleHeight + 10)
        divider.BackgroundColor3 = element.Color
        divider.BackgroundTransparency = 0.5
        divider.BorderSizePixel = 0
        divider.ZIndex = 1
        divider.Parent = contentFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, 0, 0, descriptionHeight)
        descLabel.Position = UDim2.new(0, 16, 0, titleHeight + 26)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = element.Description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 11
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.TextWrapped = true
        descLabel.Parent = contentFrame
    end

    local selectedYPos = element.Description and (titleHeight + descriptionHeight + 28) or (titleHeight + 10)

    local selectedFrame = Instance.new("Frame")
    selectedFrame.Size = UDim2.new(1, -32, 0, 30)
    selectedFrame.Position = UDim2.new(0, 16, 0, selectedYPos)
    selectedFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
    selectedFrame.BackgroundTransparency = 0.1
    selectedFrame.ZIndex = 2
    selectedFrame.Parent = contentFrame

    applyCorner(selectedFrame, 6)

    local selectedStroke = Instance.new("UIStroke")
    selectedStroke.Color = Color3.fromRGB(60, 80, 120)
    selectedStroke.Thickness = 1
    selectedStroke.Transparency = 0.5
    selectedStroke.Parent = selectedFrame

    local selectedLabel = Instance.new("TextLabel")
    selectedLabel.Size = UDim2.new(1, -50, 1, 0)
    selectedLabel.Position = UDim2.new(0, 12, 0, 0)
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.Text = element.Value
    selectedLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
    selectedLabel.Font = Enum.Font.GothamSemibold
    selectedLabel.TextSize = 11
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.TextYAlignment = Enum.TextYAlignment.Center
    selectedLabel.ZIndex = 4
    selectedLabel.Parent = selectedFrame

    -- ОРИГИНАЛЬНЫЙ ИНДИКАТОР С КРУГАМИ
    local indicatorButton = Instance.new("Frame")
    indicatorButton.Size = UDim2.new(0, 24, 0, 24)
    indicatorButton.Position = UDim2.new(1, -27, 0.5, 0)
    indicatorButton.AnchorPoint = Vector2.new(0, 0.5)
    indicatorButton.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
    indicatorButton.BackgroundTransparency = 0.3
    indicatorButton.ZIndex = 4
    indicatorButton.Parent = selectedFrame

    applyCorner(indicatorButton, 12)

    local innerIndicator = Instance.new("Frame")
    innerIndicator.Size = UDim2.new(0, 14, 0, 14)
    innerIndicator.Position = UDim2.new(0.5, 0, 0.5, 0)
    innerIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
    innerIndicator.BackgroundColor3 = Color3.fromRGB(110, 120, 140)
    innerIndicator.BackgroundTransparency = 0
    innerIndicator.ZIndex = 5
    innerIndicator.Parent = indicatorButton

    applyCorner(innerIndicator, 7)

    local innerStroke = Instance.new("UIStroke")
    innerStroke.Color = Color3.fromRGB(70, 80, 100)
    innerStroke.Thickness = 1
    innerStroke.Transparency = 0.5
    innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    innerStroke.Parent = innerIndicator

    local innerGradient = Instance.new("UIGradient")
    innerGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 150, 170)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 90, 110))
    }
    innerGradient.Rotation = 90
    innerGradient.Parent = innerIndicator

    -- СПИСОК (ПОВЕРХ ВСЕХ ЭЛЕМЕНТОВ)
    local dropdownList = Instance.new("ScrollingFrame")
    dropdownList.Size = UDim2.new(1, -32, 0, 0)
    dropdownList.Position = UDim2.new(0, 16, 1, 5)
    dropdownList.BackgroundColor3 = Color3.fromRGB(25, 32, 50)
    dropdownList.BackgroundTransparency = 0.05
    dropdownList.BorderSizePixel = 0
    dropdownList.Visible = false
    dropdownList.ScrollBarThickness = 4
    dropdownList.ScrollBarImageColor3 = element.Color
    dropdownList.ScrollBarImageTransparency = 0.3
    dropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
    dropdownList.ZIndex = 100
    dropdownList.ClipsDescendants = true
    dropdownList.Parent = container

    applyCorner(dropdownList, 6)

    local listStroke = Instance.new("UIStroke")
    listStroke.Color = element.Color
    listStroke.Thickness = 1.5
    listStroke.Transparency = 0.4
    listStroke.Parent = dropdownList

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = dropdownList

    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingLeft = UDim.new(0, 4)
    listPadding.PaddingRight = UDim.new(0, 4)
    listPadding.PaddingTop = UDim.new(0, 4)
    listPadding.PaddingBottom = UDim.new(0, 4)
    listPadding.Parent = dropdownList

    local isOpen = false

    local function updateList()
        local totalHeight = 8
        for _, child in ipairs(dropdownList:GetChildren()) do
            if child:IsA("TextButton") then
                totalHeight = totalHeight + child.Size.Y.Offset + 2
            end
        end

        dropdownList.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
        return math.min(totalHeight, 160)
    end

    local function closeDropdown()
        if not isOpen then return end
        isOpen = false

        innerIndicator.BackgroundColor3 = Color3.fromRGB(110, 120, 140)
        innerStroke.Color = Color3.fromRGB(70, 80, 100)
        innerStroke.Transparency = 0.5

        local closeTween = TweenService:Create(dropdownList, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -32, 0, 0)
        })
        closeTween:Play()
        closeTween.Completed:Connect(function()
            if not isOpen then
                dropdownList.Visible = false
            end
        end)
    end

    local function openDropdown()
        if isOpen then return end
        isOpen = true
        dropdownList.Visible = true

        local targetHeight = updateList()

        innerIndicator.BackgroundColor3 = Color3.fromRGB(130, 190, 255)
        innerStroke.Color = Color3.fromRGB(90, 150, 230)
        innerStroke.Transparency = 0.3

        local openTween = TweenService:Create(dropdownList, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -32, 0, targetHeight)
        })
        openTween:Play()
    end

    -- СОЗДАНИЕ ОПЦИЙ
    for i, opt in ipairs(element.Options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, 0, 0, 28)
        optionButton.BackgroundColor3 = element.SelectedIndex == i and Color3.fromRGB(50, 70, 110) or Color3.fromRGB(35, 45, 65)
        optionButton.BackgroundTransparency = 0.2
        optionButton.AutoButtonColor = false
        optionButton.Text = ""
        optionButton.LayoutOrder = i
        optionButton.ZIndex = 101
        optionButton.Parent = dropdownList

        applyCorner(optionButton, 4)

        local optionLabel = Instance.new("TextLabel")
        optionLabel.Size = UDim2.new(1, -16, 1, 0)
        optionLabel.Position = UDim2.new(0, 8, 0, 0)
        optionLabel.BackgroundTransparency = 1
        optionLabel.Text = opt
        optionLabel.TextColor3 = Color3.fromRGB(230, 235, 255)
        optionLabel.Font = Enum.Font.Gotham
        optionLabel.TextSize = 11
        optionLabel.TextXAlignment = Enum.TextXAlignment.Left
        optionLabel.TextYAlignment = Enum.TextYAlignment.Center
        optionLabel.ZIndex = 102
        optionLabel.Parent = optionButton

        addConnection(optionButton.MouseEnter:Connect(function()
            if element.SelectedIndex ~= i then
                TweenService:Create(optionButton, TweenInfo.new(0.12), {
                    BackgroundColor3 = Color3.fromRGB(50, 60, 80),
                    BackgroundTransparency = 0.15
                }):Play()
            end
        end))

        addConnection(optionButton.MouseLeave:Connect(function()
            if element.SelectedIndex ~= i then
                TweenService:Create(optionButton, TweenInfo.new(0.12), {
                    BackgroundColor3 = Color3.fromRGB(35, 45, 65),
                    BackgroundTransparency = 0.2
                }):Play()
            end
        end))

        addConnection(optionButton.MouseButton1Click:Connect(function()
            for _, child in ipairs(dropdownList:GetChildren()) do
                if child:IsA("TextButton") and child ~= optionButton then
                    child.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
                end
            end

            element.SelectedIndex = i
            element.Value = opt
            optionButton.BackgroundColor3 = Color3.fromRGB(50, 70, 110)
            selectedLabel.Text = opt
            closeDropdown()
            task.spawn(element.Callback, i, opt)
        end))
    end

    addConnection(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if isOpen then
            local targetHeight = updateList()
            dropdownList.Size = UDim2.new(1, -32, 0, targetHeight)
        end
    end))

    local dropdownButton = Instance.new("TextButton")
    dropdownButton.Size = UDim2.new(1, 0, 1, 0)
    dropdownButton.BackgroundTransparency = 1
    dropdownButton.Text = ""
    dropdownButton.ZIndex = 7
    dropdownButton.Parent = selectedFrame

    addConnection(dropdownButton.MouseButton1Click:Connect(function()
        if isOpen then
            closeDropdown()
        else
            openDropdown()
        end
    end))

    addConnection(UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and isOpen then
            local mousePos = input.Position
            local absPos = dropdownList.AbsolutePosition
            local absSize = dropdownList.AbsoluteSize
            local buttonAbsPos = selectedFrame.AbsolutePosition
            local buttonAbsSize = selectedFrame.AbsoluteSize

            local isInList = mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
                           mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y
            local isInButton = mousePos.X >= buttonAbsPos.X and mousePos.X <= buttonAbsPos.X + buttonAbsSize.X and
                             mousePos.Y >= buttonAbsPos.Y and mousePos.Y <= buttonAbsPos.Y + buttonAbsSize.Y

            if not isInList and not isInButton then
                closeDropdown()
            end
        end
    end))

    function element:SetValue(value)
        for i, opt in ipairs(self.Options) do
            if opt == value then
                self.SelectedIndex = i
                self.Value = value
                selectedLabel.Text = value

                for _, child in ipairs(dropdownList:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
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

print("✅ Modern UI Library V3.0 - Часть 4/4 загружена (Dropdown)")

-- ==================== BUTTON ====================
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
    button.Size = UDim2.new(1, 0, 0, 44)
    button.Position = UDim2.new(0, 0, 0.5, -22)
    button.BackgroundColor3 = element.Color
    button.BackgroundTransparency = 0.1
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = container

    createEnhancedGradient(button, false)
    applyCorner(button, 8)
    applyStroke(button, 2, element.Color, true)

    local buttonLabel = Instance.new("TextLabel")
    buttonLabel.Size = UDim2.new(1, 0, 1, 0)
    buttonLabel.BackgroundTransparency = 1
    buttonLabel.Text = element.Title
    buttonLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    buttonLabel.Font = Enum.Font.GothamBold
    buttonLabel.TextSize = 12
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
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end))

    addConnection(button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
    end))

    return element
end

-- ==================== INDICATOR (ИНДИКАТОР СТАТУСА) ====================
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
    applyStroke(container, 1, nil, false)

    local accentBar, accentGrad = createAccentBar(container, element.Color)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -130, 0, 18)
    titleLabel.Position = UDim2.new(0, 15, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = element.Title
    titleLabel.TextColor3 = UI.Colors.Light
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    local statusContainer = Instance.new("Frame")
    statusContainer.Size = UDim2.new(0, 110, 0, 26)
    statusContainer.Position = UDim2.new(1, -120, 0.5, -13)
    statusContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    statusContainer.BackgroundTransparency = 0.3
    statusContainer.BorderSizePixel = 0
    statusContainer.Parent = container

    applyCorner(statusContainer, 6)
    local statusStroke = applyStroke(statusContainer, 1, element.Color, false)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 10, 0.5, -4)
    dot.BackgroundColor3 = element.Color
    dot.BorderSizePixel = 0
    dot.Parent = statusContainer

    applyCorner(dot, 4)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -26, 1, 0)
    statusLabel.Position = UDim2.new(0, 22, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = element.Status
    statusLabel.TextColor3 = element.Color
    statusLabel.Font = Enum.Font.GothamSemibold
    statusLabel.TextSize = 10
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusContainer

    local pulseTween = TweenService:Create(dot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.5})
    addTween(pulseTween)

    function element:SetStatus(status, color)
        self.Status = status
        if color then self.Color = color end

        statusLabel.Text = status
        statusLabel.TextColor3 = self.Color
        dot.BackgroundColor3 = self.Color
        statusStroke.Color = self.Color
        accentGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, self.Color),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
        }
    end

    return element
end

-- ==================== MULTILABEL (МНОГОСТРОЧНЫЙ ЛЕЙБЛ) ====================
function UI:_CreateMultiLabel(parent, config)
    config = config or {}

    local element = {
        Title = config.Title or "Info",
        Lines = config.Lines or {"Line 1", "Line 2", "Line 3"},
        Color = config.Color or UI.Colors.Primary
    }

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 140)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    container.BackgroundTransparency = 0.1
    container.BorderSizePixel = 0
    container.Parent = parent

    createEnhancedGradient(container, false)
    applyCorner(container, 12)
    applyStroke(container, 2, nil, true)

    createAccentBar(container, element.Color)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 16)
    padding.PaddingRight = UDim.new(0, 16)
    padding.PaddingTop = UDim.new(0, 16)
    padding.PaddingBottom = UDim.new(0, 16)
    padding.Parent = container

    local titleContainer = Instance.new("Frame")
    titleContainer.Size = UDim2.new(1, 0, 0, 30)
    titleContainer.BackgroundTransparency = 1
    titleContainer.Parent = container

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -40, 1, 0)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = element.Color
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 12
    titleLabel.Text = element.Title
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 2
    titleLabel.Parent = titleContainer

    local titleDivider = Instance.new("Frame")
    titleDivider.Size = UDim2.new(1, 0, 0, 2)
    titleDivider.Position = UDim2.new(0, 0, 1, 0)
    titleDivider.BackgroundTransparency = 0.3
    titleDivider.BorderSizePixel = 0
    titleDivider.ZIndex = 1
    titleDivider.Parent = titleContainer

    local lineGradient = Instance.new("UIGradient")
    lineGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, element.Color),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    lineGradient.Parent = titleDivider

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = container

    local contentContainer = Instance.new("Frame")
    contentContainer.Size = UDim2.new(1, 0, 0, 100)
    contentContainer.Position = UDim2.new(0, 0, 0, 40)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = container

    local contentListLayout = Instance.new("UIListLayout")
    contentListLayout.Padding = UDim.new(0, 6)
    contentListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentListLayout.Parent = contentContainer

    local lineLabels = {}
    for i, lineText in ipairs(element.Lines) do
        local lineContainer = Instance.new("Frame")
        lineContainer.Size = UDim2.new(1, 0, 0, 22)
        lineContainer.BackgroundTransparency = 1
        lineContainer.LayoutOrder = i
        lineContainer.Parent = contentContainer

        local bullet = Instance.new("Frame")
        bullet.Size = UDim2.new(0, 5, 0, 5)
        bullet.Position = UDim2.new(0, 0, 0.5, -2.5)
        bullet.AnchorPoint = Vector2.new(0, 0.5)
        bullet.BackgroundColor3 = element.Color
        bullet.BorderSizePixel = 0
        bullet.Parent = lineContainer

        applyCorner(bullet, 2.5)

        local lineLabel = Instance.new("TextLabel")
        lineLabel.Size = UDim2.new(1, -15, 1, 0)
        lineLabel.Position = UDim2.new(0, 15, 0, 0)
        lineLabel.BackgroundTransparency = 1
        lineLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
        lineLabel.Font = Enum.Font.Gotham
        lineLabel.TextSize = 10
        lineLabel.Text = lineText
        lineLabel.TextXAlignment = Enum.TextXAlignment.Left
        lineLabel.TextYAlignment = Enum.TextYAlignment.Center
        lineLabel.TextWrapped = true
        lineLabel.Parent = lineContainer

        table.insert(lineLabels, lineLabel)
    end

    addConnection(contentListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h = contentListLayout.AbsoluteContentSize.Y
        contentContainer.Size = UDim2.new(1, 0, 0, h)
        container.Size = UDim2.new(1, 0, 0, 72 + h)
    end))

    element.Labels = lineLabels

    function element:UpdateLine(index, text)
        if lineLabels[index] then
            lineLabels[index].Text = text
        end
    end

    return element
end

-- ==================== ФИНАЛИЗАЦИЯ ====================
print("✅ Modern UI Library V3.0 - Часть 5/5 загружена (Button, Indicator, MultiLabel)")
print("=" .. string.rep("=", 68))
print("✅ БИБЛИОТЕКА ПОЛНОСТЬЮ ЗАГРУЖЕНА!")
print("=" .. string.rep("=", 68))
print("📦 Версия: 3.0 FINAL")
print("📅 Дата: 2026-02-12")
print("🎨 Дизайн: На основе Chess Helper")
print("=" .. string.rep("=", 68))

return UI
