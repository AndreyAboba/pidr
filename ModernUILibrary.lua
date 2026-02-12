-- ==================== MODERN UI LIBRARY ====================
-- Версия: 1.0
-- Описание: Полнофункциональная библиотека UI для Roblox

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local UI = {}

-- ==================== ЦВЕТОВАЯ ПАЛИТРА ====================
UI.BlueColorLight = Color3.fromRGB(0, 180, 255)
UI.CyanColor = Color3.fromRGB(0, 255, 255)
UI.BlueColorMedium = Color3.fromRGB(0, 120, 220)
UI.PurpleTint = Color3.fromRGB(120, 0, 220)
UI.BlueColorDark = Color3.fromRGB(0, 70, 180)
UI.NavyColor = Color3.fromRGB(0, 20, 100)
UI.DarkOutlineColor = Color3.fromRGB(50, 50, 100)
UI.GoldColor = Color3.fromRGB(255, 215, 0)
UI.GreenColor = Color3.fromRGB(46, 204, 113)
UI.RedColor = Color3.fromRGB(231, 76, 60)

-- ==================== УПРАВЛЕНИЕ РЕСУРСАМИ ====================
local activeTweens = {}
local activeConnections = {}

local function safeDisconnect(connection)
    if connection and typeof(connection) == "RBXScriptConnection" then
        pcall(function() connection:Disconnect() end)
    end
end

function UI.CleanupTweens()
    for _, tween in pairs(activeTweens) do
        pcall(function() tween:Cancel() end)
    end
    activeTweens = {}
end

function UI.CleanupConnections()
    for _, connection in ipairs(activeConnections) do
        safeDisconnect(connection)
    end
    activeConnections = {}
end

function UI.Cleanup()
    UI.CleanupTweens()
    UI.CleanupConnections()
end

-- ==================== БАЗОВЫЕ ЭЛЕМЕНТЫ ====================

function UI.CreateEnhancedGradient(frame)
    local uiGradient = Instance.new("UIGradient")

    uiGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 80, 180)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 130, 230)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(0, 80, 180))
    }

    uiGradient.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0.0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1.0, 0.3)
    }

    uiGradient.Rotation = 0
    uiGradient.Offset = Vector2.new(-1, 0)
    uiGradient.Parent = frame

    local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local tween = TweenService:Create(uiGradient, tweenInfo, {Offset = Vector2.new(1, 0)})
    activeTweens[uiGradient] = tween
    tween:Play()

    return uiGradient
end

function UI.AddModernStyle(frame, cornerRadius, strokeThickness, gradientStroke)
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, cornerRadius or 12)
    uiCorner.Parent = frame

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Thickness = strokeThickness or 2
    uiStroke.Transparency = 0.3
    uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    uiStroke.Parent = frame

    if gradientStroke then
        local strokeGradient = Instance.new("UIGradient")
        strokeGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0.0, UI.DarkOutlineColor),
            ColorSequenceKeypoint.new(0.5, UI.BlueColorMedium),
            ColorSequenceKeypoint.new(1.0, UI.BlueColorLight)
        }
        strokeGradient.Rotation = 45
        strokeGradient.Parent = uiStroke
    else
        uiStroke.Color = UI.DarkOutlineColor
    end

    return uiStroke
end

function UI.CreateTabDivider(text)
    local dividerContainer = Instance.new("Frame")
    dividerContainer.Size = text and UDim2.new(1, 0, 0, 28) or UDim2.new(1, 0, 0, 2)
    dividerContainer.BackgroundTransparency = 1
    dividerContainer.ClipsDescendants = true

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 2)
    divider.Position = text and UDim2.new(0, 0, 1, -1) or UDim2.new(0, 0, 0.5, 0)
    divider.AnchorPoint = text and Vector2.new(0, 1) or Vector2.new(0, 0.5)
    divider.BackgroundTransparency = 0.7
    divider.BorderSizePixel = 0
    divider.Parent = dividerContainer

    local mainGradient = Instance.new("UIGradient")
    mainGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 200, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    mainGradient.Rotation = 0
    mainGradient.Offset = Vector2.new(-1, 0)
    mainGradient.Parent = divider

    local tween = TweenService:Create(mainGradient, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Offset = Vector2.new(1, 0)})
    activeTweens[mainGradient] = tween
    tween:Play()

    if text then
        local textBg = Instance.new("Frame")
        textBg.Size = UDim2.new(0, 0, 0, 14)
        textBg.Position = UDim2.new(0.5, 0, 0, 0)
        textBg.AnchorPoint = Vector2.new(0.5, 0)
        textBg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        textBg.BackgroundTransparency = 0.1
        textBg.ZIndex = 2
        textBg.Parent = dividerContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = textBg

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextSize = 10
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.ZIndex = 3
        textLabel.Parent = textBg

        local textSize = TextService:GetTextSize(text, 10, Enum.Font.Gotham, Vector2.new(1000, 14))
        textBg.Size = UDim2.new(0, textSize.X + 12, 0, 14)
    end

    return dividerContainer
end

function UI.CreateLabel(parent, textLabel, options)
    options = options or {}
    local subtitle = options.subtitle or ""
    local accentColor = options.accentColor or UI.CyanColor
    local gradient = options.gradient or false

    local height = subtitle ~= "" and 56 or 42

    local bgFrame = Instance.new("Frame")
    bgFrame.Size = UDim2.new(1, 0, 0, height)
    bgFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    bgFrame.BackgroundTransparency = 0.15
    bgFrame.Parent = parent

    if gradient then UI.CreateEnhancedGradient(bgFrame) end
    UI.AddModernStyle(bgFrame, 8, 1, options.gradientStroke)

    local mainContent = Instance.new("Frame")
    mainContent.Size = UDim2.new(1, 0, 1, 0)
    mainContent.BackgroundTransparency = 1
    mainContent.Parent = bgFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 16)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = mainContent

    if subtitle ~= "" then
        local subtitleLabel = Instance.new("TextLabel")
        subtitleLabel.Size = UDim2.new(1, 0, 0, 16)
        subtitleLabel.Position = UDim2.new(0, 0, 0, 8)
        subtitleLabel.BackgroundTransparency = 1
        subtitleLabel.Text = subtitle
        subtitleLabel.TextColor3 = options.subtitleColor or Color3.fromRGB(180, 180, 200)
        subtitleLabel.Font = Enum.Font.Gotham
        subtitleLabel.TextSize = 12
        subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        subtitleLabel.Parent = mainContent

        textLabel.Size = UDim2.new(1, 0, 0, 24)
        textLabel.Position = UDim2.new(0, 0, 0, 28)
        textLabel.TextSize = 10
    else
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.TextSize = 10
    end

    textLabel.BackgroundTransparency = 1
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Font = Enum.Font.GothamSemibold
    textLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
    textLabel.TextWrapped = true
    textLabel.Parent = mainContent

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, -2)
    accentBar.Position = UDim2.new(0, 0, 0, 1)
    accentBar.BackgroundTransparency = 0.6
    accentBar.BorderSizePixel = 0
    accentBar.Parent = bgFrame

    local accentGrad = Instance.new("UIGradient")
    accentGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, accentColor),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    accentGrad.Rotation = 90
    accentGrad.Parent = accentBar

    return bgFrame
end

function UI.CreateToggle(parent, title, default, callback, options)
    options = options or {}
    local description = options.description or ""
    local accentColor = options.accentColor or UI.BlueColorLight
    local height = description ~= "" and 68 or 50

    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(1, 0, 0, height)
    toggleBg.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    toggleBg.BackgroundTransparency = 0.15
    toggleBg.Parent = parent

    UI.CreateEnhancedGradient(toggleBg)
    UI.AddModernStyle(toggleBg, 8, 1, true)

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = toggleBg

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -70, 0, 18)
    titleLabel.Position = UDim2.new(0, 16, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = contentFrame

    if description ~= "" then
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -70, 0, 14)
        descLabel.Position = UDim2.new(0, 16, 0, 38)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 11
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextWrapped = true
        descLabel.Parent = contentFrame
    end

    local toggleContainer = Instance.new("Frame")
    toggleContainer.Size = UDim2.new(0, 48, 0, 24)
    toggleContainer.Position = UDim2.new(1, -16, 0, description ~= "" and 20 or 19)
    toggleContainer.AnchorPoint = Vector2.new(1, 0)
    toggleContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    toggleContainer.Parent = contentFrame

    UI.AddModernStyle(toggleContainer, 12, 1, false)

    local toggleFill = Instance.new("Frame")
    toggleFill.Size = UDim2.new(0, 20, 0, 20)
    toggleFill.Position = UDim2.new(0, 2, 0.5, 0)
    toggleFill.AnchorPoint = Vector2.new(0, 0.5)
    toggleFill.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
    toggleFill.Parent = toggleContainer

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 10)
    fillCorner.Parent = toggleFill

    local isOn = default or false

    local function updateToggle()
        local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(toggleFill, info, {
            Position = UDim2.new(isOn and 1 or 0, isOn and -22 or 2, 0.5, 0),
            BackgroundColor3 = isOn and accentColor or Color3.fromRGB(100, 100, 120)
        }):Play()
        TweenService:Create(toggleContainer, info, {
            BackgroundColor3 = isOn and Color3.fromRGB(0, 100, 180) or Color3.fromRGB(40, 40, 50)
        }):Play()
    end
    updateToggle()

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = toggleContainer

    local conn = button.MouseButton1Click:Connect(function()
        isOn = not isOn
        updateToggle()
        if callback then task.spawn(callback, isOn) end
    end)
    table.insert(activeConnections, conn)

    return toggleBg, function() return isOn end, function(v) isOn = v; updateToggle() end
end

function UI.CreateMultiLabel(parent, title, lines, options)
    options = options or {}
    local accentColor = options.accentColor or Color3.fromRGB(255, 100, 100)

    local multiBg = Instance.new("Frame")
    multiBg.Size = UDim2.new(1, 0, 0, 140)
    multiBg.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    multiBg.BackgroundTransparency = 0.1
    multiBg.Parent = parent

    if options.gradient then UI.CreateEnhancedGradient(multiBg) end
    UI.AddModernStyle(multiBg, 12, 2, options.gradientStroke)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 16)
    padding.PaddingRight = UDim.new(0, 16)
    padding.PaddingTop = UDim.new(0, 16)
    padding.PaddingBottom = UDim.new(0, 16)
    padding.Parent = multiBg

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = accentColor
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = multiBg

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = multiBg

    local contentContainer = Instance.new("Frame")
    contentContainer.Size = UDim2.new(1, 0, 0, 100)
    contentContainer.Position = UDim2.new(0, 0, 0, 40)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = multiBg

    local contentList = Instance.new("UIListLayout")
    contentList.Padding = UDim.new(0, 6)
    contentList.Parent = contentContainer

    local lineLabels = {}
    for i, text in ipairs(lines) do
        local lineFrame = Instance.new("Frame")
        lineFrame.Size = UDim2.new(1, 0, 0, 22)
        lineFrame.BackgroundTransparency = 1
        lineFrame.Parent = contentContainer

        local bullet = Instance.new("Frame")
        bullet.Size = UDim2.new(0, 5, 0, 5)
        bullet.Position = UDim2.new(0, 0, 0.5, -2.5)
        bullet.BackgroundColor3 = accentColor
        bullet.BorderSizePixel = 0
        bullet.Parent = lineFrame

        local bulletCorner = Instance.new("UICorner")
        bulletCorner.CornerRadius = UDim.new(1, 0)
        bulletCorner.Parent = bullet

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -15, 1, 0)
        label.Position = UDim2.new(0, 15, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(240, 240, 255)
        label.Font = Enum.Font.Gotham
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextWrapped = true
        label.Parent = lineFrame

        table.insert(lineLabels, label)
    end

    local conn = contentList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h = contentList.AbsoluteContentSize.Y
        contentContainer.Size = UDim2.new(1, 0, 0, h)
        multiBg.Size = UDim2.new(1, 0, 0, 56 + h)
    end)
    table.insert(activeConnections, conn)

    return multiBg, lineLabels, titleLabel
end

function UI.CreateSlider(parent, title, min, max, default, step, allowInput, callback, options)
    options = options or {}
    local description = options.description or ""
    local accentColor = options.accentColor or UI.BlueColorLight
    local decimals = options.decimals or 0
    local height = description ~= "" and 86 or 70

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, 0, 0, height)
    sliderBg.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    sliderBg.BackgroundTransparency = 0.15
    sliderBg.Parent = parent

    UI.CreateEnhancedGradient(sliderBg)
    UI.AddModernStyle(sliderBg, 8, 1, true)

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = sliderBg

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -60, 0, 18)
    titleLabel.Position = UDim2.new(0, 16, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = contentFrame

    if description ~= "" then
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -60, 0, 14)
        descLabel.Position = UDim2.new(0, 16, 0, 38)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 11
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextWrapped = true
        descLabel.Parent = contentFrame
    end

    local sliderYPos = description ~= "" and 60 or 46

    local function formatValue(val)
        if decimals == 0 then
            return tostring(math.floor(val + 0.5))
        else
            return string.format("%." .. decimals .. "f", val)
        end
    end

    local valueDisplay = Instance.new(allowInput and "TextBox" or "TextLabel")
    valueDisplay.Size = UDim2.new(0, 50, 0, 24)
    valueDisplay.Position = UDim2.new(1, -58, 0, sliderYPos - 10)
    valueDisplay.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    valueDisplay.BackgroundTransparency = allowInput and 0.2 or 1
    valueDisplay.TextColor3 = Color3.fromRGB(220, 220, 255)
    valueDisplay.Font = Enum.Font.Gotham
    valueDisplay.TextSize = 11
    valueDisplay.Text = formatValue(default or min)
    valueDisplay.TextXAlignment = Enum.TextXAlignment.Right
    if allowInput then valueDisplay.ClearTextOnFocus = false end
    valueDisplay.Parent = contentFrame

    if allowInput then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = valueDisplay
    end

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -84, 0, 6)
    sliderBar.Position = UDim2.new(0, 16, 0, sliderYPos)
    sliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    sliderBar.Parent = contentFrame

    UI.AddModernStyle(sliderBar, 3, 0, false)

    local fillBar = Instance.new("Frame")
    fillBar.Size = UDim2.new(0, 0, 1, 0)
    fillBar.BackgroundColor3 = accentColor
    fillBar.Parent = sliderBar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 3)
    fillCorner.Parent = fillBar

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, -7, 0.5, 0)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = sliderBar

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local value = default or min
    step = step or 1
    local isDragging = false

    local function updateValue(newValue, skipCallback)
        newValue = math.clamp(math.round(newValue / step) * step, min, max)
        if newValue == value then return end

        value = newValue
        local progress = (value - min) / (max - min)

        fillBar.Size = UDim2.new(progress, 0, 1, 0)
        knob.Position = UDim2.new(progress, -7, 0.5, 0)
        valueDisplay.Text = formatValue(value)

        if not skipCallback and callback then
            task.spawn(callback, value)
        end
    end

    updateValue(value, true)

    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(1, -84, 0, 20)
    sliderButton.Position = UDim2.new(0, 16, 0, sliderYPos - 7)
    sliderButton.BackgroundTransparency = 1
    sliderButton.Text = ""
    sliderButton.Parent = contentFrame

    local conn1 = sliderButton.MouseButton1Down:Connect(function() isDragging = true end)
    table.insert(activeConnections, conn1)

    local conn2 = UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
            updateValue(min + (max - min) * rel)
        end
    end)
    table.insert(activeConnections, conn2)

    local conn3 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
    end)
    table.insert(activeConnections, conn3)

    if allowInput then
        local conn4 = valueDisplay.FocusLost:Connect(function()
            local num = tonumber(valueDisplay.Text)
            if num then updateValue(num) else valueDisplay.Text = formatValue(value) end
        end)
        table.insert(activeConnections, conn4)
    end

    return sliderBg, function() return value end, function(v) updateValue(v, false) end
end

function UI.CreateButton(parent, text, callback, options)
    options = options or {}
    local accentColor = options.accentColor or UI.BlueColorMedium
    local height = options.height or 44

    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, 0, 0, height + 16)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = parent

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -24, 0, height)
    button.Position = UDim2.new(0, 12, 0, 8)
    button.BackgroundColor3 = accentColor
    button.BackgroundTransparency = 0.1
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.Parent = buttonContainer

    if options.gradient ~= false then UI.CreateEnhancedGradient(button) end
    UI.AddModernStyle(button, 8, 2, true)

    local conn = button.MouseButton1Click:Connect(function()
        button.BackgroundColor3 = UI.GreenColor
        button.Text = "✓ " .. text
        if callback then task.spawn(callback) end
        task.delay(1, function()
            button.BackgroundColor3 = accentColor
            button.Text = text
        end)
    end)
    table.insert(activeConnections, conn)

    return buttonContainer, button
end

print("✅ Modern UI Library v1.0 loaded!")
return UI
