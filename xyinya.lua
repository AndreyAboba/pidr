local Visuals = {}
print('4')

function Visuals.Init(UI, Core, notify)
    local State = {
        MenuButton = { 
            Enabled = false, 
            Dragging = false, 
            DragStart = nil, 
            StartPos = nil, 
            TouchStartTime = 0, 
            TouchThreshold = 0.2,
            CurrentDesign = "Default",
            Mobile = true
        },
        Watermark = { 
            Enabled = true, 
            GradientTime = 0, 
            FrameCount = 0, 
            AccumulatedTime = 0, 
            Dragging = false, 
            DragStart = nil, 
            StartPos = nil, 
            LastTimeUpdate = 0, 
            TimeUpdateInterval = 1 
        }
    }

    local WatermarkConfig = {
        gradientSpeed = 2,
        segmentCount = 12,
        showFPS = true,
        showTime = true,
        updateInterval = 0.5,
        gradientUpdateInterval = 0.1
    }

    local ESP = {
        Settings = {
            Enabled = { Value = false, Default = false },
            ESPMode = { Value = "2D", Default = "2D" },
            EnemyColor = { Value = Color3.fromRGB(255, 0, 0), Default = Color3.fromRGB(255, 0, 0) },
            TeamColor = { Value = Color3.fromRGB(0, 255, 0), Default = Color3.fromRGB(0, 255, 0) },
            TeamCheck = { Value = true, Default = true },
            UseTeamColor = { Value = false, Default = false },
            BoxSettings = {
                Thickness = { Value = 1, Default = 1 },
                Transparency = { Value = 0.2, Default = 0.2 },
                ShowBox = { Value = true, Default = true },
                ShowNames = { Value = true, Default = true },
                ShowCountry = { Value = true, Default = true },
                ShowDevice = { Value = true, Default = true },
                ShowDribbleCD = { Value = true, Default = true }, -- Новое: показ кулдауна дриблинга
                ShowTackleCD = { Value = true, Default = true }, -- Новое: показ кулдауна текла
                InfoPosition = { Value = "Bottom", Default = "Bottom" },
                HPBarStyle = { Value = "Default", Default = "Default" }, -- Новое: стиль HP бара
                HPBarColor = { Value = Color3.fromRGB(0, 255, 0), Default = Color3.fromRGB(0, 255, 0) }, -- Новое: цвет HP бара
                GradientEnabled = { Value = false, Default = false },
                FilledEnabled = { Value = false, Default = false },
                FilledTransparency = { Value = 0.5, Default = 0.5 },
                GradientSpeed = { Value = 2, Default = 2 }
            },
            TextSettings = {
                TextSize = { Value = 14, Default = 14 },
                TextFont = { Value = Drawing.Fonts.Plex, Default = Drawing.Fonts.Plex },
                TextMethod = { Value = "Drawing", Default = "Drawing" },
                TextScale = { Value = 1.0, Default = 1.0 } -- Новое: масштабирование текста
            }
        },
        Elements = {},
        GuiElements = {},
        LastNotificationTime = 0,
        NotificationDelay = 5,
        UpdateInterval = 1 / 60,
        LastUpdateTime = 0,
        
        -- Новые данные для игроков
        PlayerData = {
            -- Структура: [player] = { dribbleCD = 0, tackleCD = 0, lastUpdate = 0 }
        }
    }

    local Cache = { 
        TextBounds = {}, 
        LastGradientUpdate = 0, 
        PlayerCache = {},
        PlayerBoxCache = {}
    }
    
    local Elements = { Watermark = {} }

    -- Получаем CoreGui и RobloxGui
    local CoreGui = game:GetService("CoreGui")
    local RobloxGui = CoreGui:WaitForChild("RobloxGui")
    
    -- Ищем Base frame в RobloxGui
    local function findBaseFrame()
        for _, child in ipairs(RobloxGui:GetDescendants()) do
            if child:IsA("Frame") and child.Name == "Base" then
                return child
            end
        end
        return nil
    end

    local baseFrame = findBaseFrame()
    
    -- Функция для эмуляции нажатия RightControl
    local function emulateRightControl()
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
            task.wait()
            vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
        end)
    end
    
    -- Функция для показа/скрытия меню
    local function toggleMenuVisibility()
        if State.MenuButton.Mobile then
            if baseFrame then
                local isVisible = not baseFrame.Visible
                baseFrame.Visible = isVisible
                notify("Menu Button", "Menu " .. (isVisible and "Enabled" or "Disabled"), true)
                return isVisible
            else
                baseFrame = findBaseFrame()
                if baseFrame then
                    local isVisible = not baseFrame.Visible
                    baseFrame.Visible = isVisible
                    notify("Menu Button", "Menu " .. (isVisible and "Enabled" or "Disabled"), true)
                    return isVisible
                else
                    notify("Menu Button", "Base frame not found!", false)
                    return false
                end
            end
        else
            emulateRightControl()
            notify("Menu Button", "Menu toggled (RightControl emulated)", true)
            return true
        end
    end

    -- Создаем кнопку меню
    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "MenuToggleButtonGui"
    buttonGui.Parent = RobloxGui
    buttonGui.ResetOnSpawn = false
    buttonGui.IgnoreGuiInset = false

    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0, 50, 0, 50)
    buttonFrame.Position = UDim2.new(0, 100, 0, 100)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    buttonFrame.BackgroundTransparency = 0.3
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Visible = State.MenuButton.Enabled
    buttonFrame.Parent = buttonGui

    Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)

    local buttonIcon = Instance.new("ImageLabel")
    buttonIcon.Name = "MainIcon"
    buttonIcon.Size = UDim2.new(0, 30, 0, 30)
    buttonIcon.Position = UDim2.new(0.5, -15, 0.5, -15)
    buttonIcon.BackgroundTransparency = 1
    buttonIcon.Image = "rbxassetid://73279554401260"
    buttonIcon.Parent = buttonFrame

    -- Функции для разных дизайнов кнопки
    local function applyDefaultDesign()
        local currentPos = buttonFrame.Position
        
        for _, child in ipairs(buttonFrame:GetChildren()) do
            if child.Name ~= "UICorner" and child.Name ~= "MainIcon" then
                child:Destroy()
            end
        end
        
        buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        buttonFrame.BackgroundTransparency = 0.3
        buttonFrame.Size = UDim2.new(0, 50, 0, 50)
        buttonFrame.Position = currentPos
        
        buttonIcon.Visible = true
        buttonIcon.Size = UDim2.new(0, 30, 0, 30)
        buttonIcon.Position = UDim2.new(0.5, -15, 0.5, -15)
        buttonIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        
        local corner = buttonFrame:FindFirstChild("UICorner")
        if corner then
            corner.CornerRadius = UDim.new(0.5, 0)
        else
            Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)
        end
    end

    local function applyDefaultV2Design()
        local currentPos = buttonFrame.Position
        
        for _, child in ipairs(buttonFrame:GetChildren()) do
            if child.Name ~= "UICorner" and child.Name ~= "MainIcon" then
                child:Destroy()
            end
        end
        
        buttonIcon.Visible = false
        
        buttonFrame.Size = UDim2.new(0, 48, 0, 48)
        buttonFrame.Position = currentPos
        buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        buttonFrame.BackgroundTransparency = 0.6
        
        local corner = buttonFrame:FindFirstChild("UICorner")
        if corner then
            corner.CornerRadius = UDim.new(0.5, 0)
        else
            Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)
        end
        
        local iconContainer = Instance.new("Frame")
        iconContainer.Name = "IconContainer"
        iconContainer.Size = UDim2.new(0, 40, 0, 40)
        iconContainer.Position = UDim2.new(0.5, -20, 0.5, -20)
        iconContainer.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        iconContainer.BackgroundTransparency = 0.25
        iconContainer.BorderSizePixel = 0
        iconContainer.Parent = buttonFrame
        
        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0.5, 0)
        iconCorner.Parent = iconContainer
        
        local uiStroke = Instance.new("UIStroke")
        uiStroke.Color = Color3.fromRGB(20, 30, 60)
        uiStroke.Thickness = 0.2
        uiStroke.Transparency = 0.9
        uiStroke.Parent = iconContainer
        
        local newIcon = Instance.new("ImageLabel")
        newIcon.Name = "DefaultV2Icon"
        newIcon.Size = UDim2.new(0, 28, 0, 28)
        newIcon.Position = UDim2.new(0.5, -14, 0.5, -14)
        newIcon.BackgroundTransparency = 1
        newIcon.Image = "rbxassetid://73279554401260"
        newIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        newIcon.Parent = iconContainer
        
        local isAnimating = false
        local lastClickTime = 0
        local clickCooldown = 0.4
        
        local function playClickAnimation()
            if isAnimating then return end
            
            isAnimating = true
            local startTime = tick()
            local animationDuration = 0.2
            
            local originalSize = iconContainer.Size
            local originalPos = iconContainer.Position
            local originalBackgroundTransparency = iconContainer.BackgroundTransparency
            
            while tick() - startTime < animationDuration do
                if State.MenuButton.CurrentDesign ~= "Default v2" then break end
                
                local elapsed = tick() - startTime
                local progress = elapsed / animationDuration
                
                local scale
                if progress < 0.5 then
                    scale = 1 - (progress * 0.2)
                else
                    scale = 0.8 + ((progress - 0.5) * 0.4)
                end
                
                iconContainer.Size = UDim2.new(0, originalSize.X.Offset * scale, 0, originalSize.Y.Offset * scale)
                iconContainer.Position = UDim2.new(
                    0.5, -originalSize.X.Offset * scale / 2,
                    0.5, -originalSize.Y.Offset * scale / 2
                )
                
                iconContainer.BackgroundTransparency = originalBackgroundTransparency + (progress < 0.5 and progress * 0.1 or (0.1 - (progress - 0.5) * 0.2))
                
                task.wait()
            end
            
            iconContainer.Size = originalSize
            iconContainer.Position = originalPos
            iconContainer.BackgroundTransparency = originalBackgroundTransparency
            
            isAnimating = false
        end
        
        local connection
        connection = buttonFrame.InputBegan:Connect(function(input)
            if State.MenuButton.CurrentDesign == "Default v2" and 
               (input.UserInputType == Enum.UserInputType.MouseButton1 or 
                input.UserInputType == Enum.UserInputType.Touch) then
                playClickAnimation()
            end
        end)
        
        State.MenuButton.DefaultV2Connection = connection
    end

    -- Применяем текущий дизайн
    local function applyDesign(designName)
        if State.MenuButton.DefaultV2Connection then
            State.MenuButton.DefaultV2Connection:Disconnect()
            State.MenuButton.DefaultV2Connection = nil
        end
        
        State.MenuButton.CurrentDesign = designName
        
        if designName == "Default" then
            applyDefaultDesign()
        elseif designName == "Default v2" then
            applyDefaultV2Design()
        end
    end

    applyDesign("Default")

    -- Обработка нажатия на кнопку
    buttonFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            State.MenuButton.TouchStartTime = tick()
            local mousePos
            if input.UserInputType == Enum.UserInputType.Touch then
                mousePos = Vector2.new(input.Position.X, input.Position.Y)
            else
                mousePos = Core.Services.UserInputService:GetMouseLocation()
            end
            
            if mousePos then
                State.MenuButton.Dragging = true
                State.MenuButton.DragStart = mousePos
                State.MenuButton.StartPos = buttonFrame.Position
            end
        end
    end)

    Core.Services.UserInputService.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and State.MenuButton.Dragging then
            local mousePos
            if input.UserInputType == Enum.UserInputType.Touch then
                mousePos = Vector2.new(input.Position.X, input.Position.Y)
            else
                mousePos = Core.Services.UserInputService:GetMouseLocation()
            end
            
            if mousePos and State.MenuButton.DragStart and State.MenuButton.StartPos then
                local delta = mousePos - State.MenuButton.DragStart
                buttonFrame.Position = UDim2.new(0, State.MenuButton.StartPos.X.Offset + delta.X, 0, State.MenuButton.StartPos.Y.Offset + delta.Y)
            end
        end
    end)

    buttonFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            State.MenuButton.Dragging = false
            if tick() - State.MenuButton.TouchStartTime < State.MenuButton.TouchThreshold then
                toggleMenuVisibility()
            end
        end
    end)

    -- Функции для Watermark
    local function createFrameWithPadding(parent, size, backgroundColor, transparency)
        local frame = Instance.new("Frame")
        frame.Size = size
        frame.BackgroundColor3 = backgroundColor
        frame.BackgroundTransparency = transparency
        frame.BorderSizePixel = 0
        frame.Parent = parent
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 5)
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 5)
        padding.PaddingRight = UDim.new(0, 5)
        padding.Parent = frame
        return frame
    end

    local function initWatermark()
        local elements = Elements.Watermark
        local savedPosition = elements.Container and elements.Container.Position or UDim2.new(0, 350, 0, 10)
        if elements.Gui then elements.Gui:Destroy() end
        elements = {}
        Elements.Watermark = elements

        local gui = Instance.new("ScreenGui")
        gui.Name = "WaterMarkGui"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = State.Watermark.Enabled
        gui.Parent = RobloxGui
        elements.Gui = gui

        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 0, 0, 30)
        container.Position = savedPosition
        container.BackgroundTransparency = 1
        container.Parent = gui
        elements.Container = container

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 5)
        layout.Parent = container

        local logoBackground = createFrameWithPadding(container, UDim2.new(0, 28, 0, 28), Color3.fromRGB(20, 30, 50), 0.3)
        elements.LogoBackground = logoBackground

        local logoFrame = Instance.new("Frame")
        logoFrame.Size = UDim2.new(0, 20, 0, 20)
        logoFrame.Position = UDim2.new(0.5, -10, 0.5, -10)
        logoFrame.BackgroundTransparency = 1
        logoFrame.Parent = logoBackground
        elements.LogoFrame = logoFrame

        local logoConstraint = Instance.new("UISizeConstraint")
        logoConstraint.MaxSize = Vector2.new(28, 28)
        logoConstraint.MinSize = Vector2.new(28, 28)
        logoConstraint.Parent = logoBackground

        elements.LogoSegments = {}
        local segmentCount = math.max(1, WatermarkConfig.segmentCount)
        for i = 1, segmentCount do
            local segment = Instance.new("ImageLabel")
            segment.Size = UDim2.new(1, 0, 1, 0)
            segment.BackgroundTransparency = 1
            segment.Image = "rbxassetid://7151778302"
            segment.ImageTransparency = 0.4
            segment.Rotation = (i - 1) * (360 / segmentCount)
            segment.Parent = logoFrame
            Instance.new("UICorner", segment).CornerRadius = UDim.new(0.5, 0)
            local gradient = Instance.new("UIGradient")
            gradient.Color = ColorSequence.new(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value)
            gradient.Rotation = (i - 1) * (360 / segmentCount)
            gradient.Parent = segment
            elements.LogoSegments[i] = { Segment = segment, Gradient = gradient }
        end

        local playerNameFrame = createFrameWithPadding(container, UDim2.new(0, 0, 0, 20), Color3.fromRGB(20, 30, 50), 0.3)
        elements.PlayerNameFrame = playerNameFrame

        local playerNameLabel = Instance.new("TextLabel")
        playerNameLabel.Size = UDim2.new(0, 0, 1, 0)
        playerNameLabel.BackgroundTransparency = 1
        playerNameLabel.Text = Core.PlayerData.LocalPlayer.Name
        playerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        playerNameLabel.TextSize = 14
        playerNameLabel.Font = Enum.Font.GothamBold
        playerNameLabel.TextXAlignment = Enum.TextXAlignment.Center
        playerNameLabel.Parent = playerNameFrame
        elements.PlayerNameLabel = playerNameLabel
        Cache.TextBounds.PlayerName = playerNameLabel.TextBounds.X

        if WatermarkConfig.showFPS then
            local fpsFrame = createFrameWithPadding(container, UDim2.new(0, 0, 0, 20), Color3.fromRGB(20, 30, 50), 0.3)
            elements.FPSFrame = fpsFrame

            local fpsContainer = Instance.new("Frame")
            fpsContainer.Size = UDim2.new(0, 0, 0, 20)
            fpsContainer.BackgroundTransparency = 1
            fpsContainer.Parent = fpsFrame
            elements.FPSContainer = fpsContainer

            local fpsLayout = Instance.new("UIListLayout")
            fpsLayout.FillDirection = Enum.FillDirection.Horizontal
            fpsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            fpsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            fpsLayout.Padding = UDim.new(0, 4)
            fpsLayout.Parent = fpsContainer

            local fpsIcon = Instance.new("ImageLabel")
            fpsIcon.Size = UDim2.new(0, 14, 0, 14)
            fpsIcon.BackgroundTransparency = 1
            fpsIcon.Image = "rbxassetid://8587689304"
            fpsIcon.ImageTransparency = 0.3
            fpsIcon.Parent = fpsContainer
            elements.FPSIcon = fpsIcon

            local fpsLabel = Instance.new("TextLabel")
            fpsLabel.BackgroundTransparency = 1
            fpsLabel.Text = "0 FPS"
            fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            fpsLabel.TextSize = 14
            fpsLabel.Font = Enum.Font.Gotham
            fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
            fpsLabel.Size = UDim2.new(0, 0, 0, 20)
            fpsLabel.Parent = fpsContainer
            elements.FPSLabel = fpsLabel
            Cache.TextBounds.FPS = fpsLabel.TextBounds.X
        end

        if WatermarkConfig.showTime then
            local timeFrame = createFrameWithPadding(container, UDim2.new(0, 0, 0, 20), Color3.fromRGB(20, 30, 50), 0.3)
            elements.TimeFrame = timeFrame

            local timeContainer = Instance.new("Frame")
            timeContainer.Size = UDim2.new(0, 0, 0, 20)
            timeContainer.BackgroundTransparency = 1
            timeContainer.Parent = timeFrame
            elements.TimeContainer = timeContainer

            local timeLayout = Instance.new("UIListLayout")
            timeLayout.FillDirection = Enum.FillDirection.Horizontal
            timeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            timeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            timeLayout.Padding = UDim.new(0, 4)
            timeLayout.Parent = timeContainer

            local timeIcon = Instance.new("ImageLabel")
            timeIcon.Size = UDim2.new(0, 14, 0, 14)
            timeIcon.BackgroundTransparency = 1
            timeIcon.Image = "rbxassetid://4034150594"
            timeIcon.ImageTransparency = 0.3
            timeIcon.Parent = timeContainer
            elements.TimeIcon = timeIcon

            local timeLabel = Instance.new("TextLabel")
            timeLabel.Size = UDim2.new(0, 0, 0, 20)
            timeLabel.BackgroundTransparency = 1
            timeLabel.Text = "00:00:00"
            timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            timeLabel.TextSize = 14
            timeLabel.Font = Enum.Font.Gotham
            timeLabel.TextXAlignment = Enum.TextXAlignment.Left
            timeLabel.Parent = timeContainer
            elements.TimeLabel = timeLabel
            Cache.TextBounds.Time = timeLabel.TextBounds.X
        end

        local function updateSizes()
            local playerNameWidth = Cache.TextBounds.PlayerName or elements.PlayerNameLabel.TextBounds.X
            elements.PlayerNameLabel.Size = UDim2.new(0, playerNameWidth, 1, 0)
            elements.PlayerNameFrame.Size = UDim2.new(0, playerNameWidth + 10, 0, 20)

            if WatermarkConfig.showFPS and elements.FPSContainer then
                local fpsWidth = Cache.TextBounds.FPS or elements.FPSLabel.TextBounds.X
                elements.FPSLabel.Size = UDim2.new(0, fpsWidth, 0, 20)
                local fpsContainerWidth = elements.FPSIcon.Size.X.Offset + fpsWidth + elements.FPSContainer:FindFirstChild("UIListLayout").Padding.Offset
                elements.FPSContainer.Size = UDim2.new(0, fpsContainerWidth, 0, 20)
                elements.FPSFrame.Size = UDim2.new(0, fpsContainerWidth + 30, 0, 20)
            end

            if WatermarkConfig.showTime and elements.TimeContainer then
                local timeWidth = Cache.TextBounds.Time or elements.TimeLabel.TextBounds.X
                elements.TimeLabel.Size = UDim2.new(0, timeWidth, 0, 20)
                local timeContainerWidth = elements.TimeIcon.Size.X.Offset + timeWidth + elements.TimeContainer:FindFirstChild("UIListLayout").Padding.Offset
                elements.TimeContainer.Size = UDim2.new(0, timeContainerWidth, 0, 20)
                elements.TimeFrame.Size = UDim2.new(0, timeContainerWidth + 10, 0, 20)
            end

            local totalWidth, visibleChildren = 0, 0
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible then
                    totalWidth = totalWidth + child.Size.X.Offset
                    visibleChildren = visibleChildren + 1
                end
            end
            totalWidth = totalWidth + (layout.Padding.Offset * math.max(0, visibleChildren - 1))
            container.Size = UDim2.new(0, totalWidth, 0, 30)
        end

        updateSizes()
        for _, label in pairs({elements.PlayerNameLabel, elements.FPSLabel, elements.TimeLabel}) do
            if label then
                label:GetPropertyChangedSignal("TextBounds"):Connect(function()
                    Cache.TextBounds[label.Name] = label.TextBounds.X
                    updateSizes()
                end)
            end
        end
    end

    local function updateGradientCircle(deltaTime)
        if not State.Watermark.Enabled or not Elements.Watermark.LogoSegments then return end
        Cache.LastGradientUpdate = Cache.LastGradientUpdate + deltaTime
        if Cache.LastGradientUpdate < WatermarkConfig.gradientUpdateInterval then return end

        State.Watermark.GradientTime = State.Watermark.GradientTime + Cache.LastGradientUpdate
        Cache.LastGradientUpdate = 0
        local t = (math.sin(State.Watermark.GradientTime / WatermarkConfig.gradientSpeed * 2 * math.pi) + 1) / 2
        local color1, color2 = Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value
        for _, segmentData in ipairs(Elements.Watermark.LogoSegments) do
            segmentData.Gradient.Color = ColorSequence.new(color1:Lerp(color2, t), color2:Lerp(color1, t))
        end
    end

    local function setWatermarkVisibility(visible)
        State.Watermark.Enabled = visible
        if Elements.Watermark.Gui then Elements.Watermark.Gui.Enabled = visible end
    end

    local function handleWatermarkInput(input)
        local target, element = State.Watermark, Elements.Watermark.Container
        local mousePos

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if input.UserInputState == Enum.UserInputState.Begin then
                mousePos = Core.Services.UserInputService:GetMouseLocation()
                if element and mousePos.X >= element.Position.X.Offset and mousePos.X <= element.Position.X.Offset + element.Size.X.Offset and
                   mousePos.Y >= element.Position.Y.Offset and mousePos.Y <= element.Position.Y.Offset + element.Size.Y.Offset then
                    target.Dragging = true
                    target.DragStart = mousePos
                    target.StartPos = element.Position
                end
            elseif input.UserInputState == Enum.UserInputState.End then
                target.Dragging = false
            end
        elseif input.UserInputType == Enum.UserInputType.MouseMovement and target.Dragging then
            mousePos = Core.Services.UserInputService:GetMouseLocation()
            local delta = mousePos - target.DragStart
            element.Position = UDim2.new(0, target.StartPos.X.Offset + delta.X, 0, target.StartPos.Y.Offset + delta.Y)
        elseif input.UserInputType == Enum.UserInputType.Touch then
            mousePos = Vector2.new(input.Position.X, input.Position.Y)
            if input.UserInputState == Enum.UserInputState.Begin then
                if element and mousePos.X >= element.Position.X.Offset and mousePos.X <= element.Position.X.Offset + element.Size.X.Offset and
                   mousePos.Y >= element.Position.Y.Offset and mousePos.Y <= element.Position.Y.Offset + element.Size.Y.Offset then
                    target.Dragging = true
                    target.DragStart = mousePos
                    target.StartPos = element.Position
                end
            elseif input.UserInputState == Enum.UserInputState.Change and target.Dragging then
                local delta = mousePos - target.DragStart
                element.Position = UDim2.new(0, target.StartPos.X.Offset + delta.X, 0, target.StartPos.Y.Offset + delta.Y)
            elseif input.UserInputState == Enum.UserInputState.End then
                target.Dragging = false
            end
        end
    end

    Core.Services.UserInputService.InputBegan:Connect(handleWatermarkInput)
    Core.Services.UserInputService.InputChanged:Connect(handleWatermarkInput)
    Core.Services.UserInputService.InputEnded:Connect(handleWatermarkInput)

    task.defer(initWatermark)

    Core.Services.RunService.Heartbeat:Connect(function(deltaTime)
        if not State.Watermark.Enabled then return end
        updateGradientCircle(deltaTime)
        if WatermarkConfig.showFPS and Elements.Watermark.FPSLabel then
            State.Watermark.FrameCount = State.Watermark.FrameCount + 1
            State.Watermark.AccumulatedTime = State.Watermark.AccumulatedTime + deltaTime
            if State.Watermark.AccumulatedTime >= WatermarkConfig.updateInterval then
                Elements.Watermark.FPSLabel.Text = tostring(math.floor(State.Watermark.FrameCount / State.Watermark.AccumulatedTime)) .. " FPS"
                State.Watermark.FrameCount = 0
                State.Watermark.AccumulatedTime = 0
            end
        end
        if WatermarkConfig.showTime and Elements.Watermark.TimeLabel then
            local currentTime = tick()
            if currentTime - State.Watermark.LastTimeUpdate >= State.Watermark.TimeUpdateInterval then
                local timeData = os.date("*t")
                Elements.Watermark.TimeLabel.Text = string.format("%02d:%02d:%02d", timeData.hour, timeData.min, timeData.sec)
                State.Watermark.LastTimeUpdate = currentTime
            end
        end
    end)

    -- ESP системы
    local ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "notSPTextGui"
    ESPGui.ResetOnSpawn = false
    ESPGui.IgnoreGuiInset = true
    ESPGui.Parent = RobloxGui

    local supportsQuad = pcall(function()
        local test = Drawing.new("Quad")
        test:Remove()
    end)

    -- Функция для проверки команды
    local function getPlayerTeam(player)
        if player and player.Team then
            return player.Team
        end
        return nil
    end

    -- Функция для проверки совпадения команд
    local function isSameTeam(player1, player2)
        local team1 = getPlayerTeam(player1)
        local team2 = getPlayerTeam(player2)
        
        if team1 and team2 then
            return team1 == team2
        end
        return false
    end

    -- Функция для получения страны игрока
    local function getPlayerCountry(player)
        if player and player:FindFirstChild("OriginalCountry") then
            local countryData = player.OriginalCountry.Value
            if countryData and type(countryData) == "string" then
                return countryData
            end
        end
        return "🌐"
    end

    -- Функция для получения устройства игрока
    local function getPlayerDevice(player)
        if player.isMobile and player.isMobile.Value then
            return "📱"
        else
            local deviceType = player.deviceType and player.deviceType.Value
            if deviceType == "PC" then
                return "💻"
            elseif deviceType == "Unknown" or deviceType == "Unkown" then
                return "🎮"
            else
                return "❓"
            end
        end
    end

    -- Функция для получения кулдаунов игрока
    local function getPlayerCooldowns(player)
        local currentTime = tick()
        local playerData = ESP.PlayerData[player]
        
        if not playerData then
            playerData = {
                dribbleCD = 0,
                tackleCD = 0,
                lastUpdate = currentTime,
                isDribbling = false,
                isTackling = false
            }
            ESP.PlayerData[player] = playerData
        end
        
        -- Обновляем таймеры
        local deltaTime = currentTime - playerData.lastUpdate
        playerData.lastUpdate = currentTime
        
        if playerData.dribbleCD > 0 then
            playerData.dribbleCD = math.max(0, playerData.dribbleCD - deltaTime)
        end
        
        if playerData.tackleCD > 0 then
            playerData.tackleCD = math.max(0, playerData.tackleCD - deltaTime)
        end
        
        -- Проверяем состояния анимаций (здесь должна быть интеграция с вашим скриптом AutoDribble)
        local character = player.Character
        if character then
            -- Проверка дриблинга (нужно интегрировать с вашим скриптом)
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                local animator = humanoid:FindFirstChild("Animator")
                if animator then
                    -- Здесь должна быть проверка анимаций дриблинга
                    -- Для примера: если обнаружена анимация дриблинга, устанавливаем кулдаун
                end
            end
        end
        
        return playerData
    end

    -- Функция для форматирования времени
    local function formatTime(seconds)
        if seconds <= 0 then
            return ""
        end
        return string.format("%.1fs", seconds)
    end

    -- Функция для получения размеров персонажа
    local function getCharacterSize(character)
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            -- Для 2D: высота больше
            if ESP.Settings.ESPMode.Value == "2D" then
                local height = humanoid.HipHeight * 3.2 + 4.0 -- Еще выше
                local width = height * 0.4 -- Нормальная пропорция
                return Vector3.new(width, height, 1)
            else
                -- Для 3D: немного ниже
                local height = humanoid.HipHeight * 1.8 + 2.8 -- Немного ниже чем раньше
                return Vector3.new(2.8, height, 2.8)
            end
        end
        -- Размеры по умолчанию
        if ESP.Settings.ESPMode.Value == "2D" then
            return Vector3.new(4.0, 10, 1) -- Выше для 2D
        else
            return Vector3.new(3, 6, 3) -- Немного ниже для 3D
        end
    end

    -- Функция для расчета 3D точек (с измененным Y)
    local function get3DBoxPoints(character, camera)
        local size = getCharacterSize(character)
        local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head") or character:FindFirstChild("Torso")
        if not rootPart then return nil end
        
        local cf = rootPart.CFrame
        local points = {}
        
        -- Смещаем бокс ниже по Y (отрицательное значение)
        local yOffset = Vector3.new(0, -0.5, 0) -- Смещаем немного ниже
        
        -- 8 углов куба со смещением по Y
        local corners = {
            Vector3.new(-size.X/2, -size.Y/2, -size.Z/2) + yOffset,
            Vector3.new(size.X/2, -size.Y/2, -size.Z/2) + yOffset,
            Vector3.new(size.X/2, size.Y/2, -size.Z/2) + yOffset,
            Vector3.new(-size.X/2, size.Y/2, -size.Z/2) + yOffset,
            Vector3.new(-size.X/2, -size.Y/2, size.Z/2) + yOffset,
            Vector3.new(size.X/2, -size.Y/2, size.Z/2) + yOffset,
            Vector3.new(size.X/2, size.Y/2, size.Z/2) + yOffset,
            Vector3.new(-size.X/2, size.Y/2, size.Z/2) + yOffset
        }
        
        -- Преобразуем в мировые координаты и затем в 2D
        for i, corner in ipairs(corners) do
            local worldPos = cf:PointToWorldSpace(corner)
            local screenPos, visible = camera:WorldToViewportPoint(worldPos)
            if not visible then return nil end
            points[i] = Vector2.new(screenPos.X, screenPos.Y)
        end
        
        return points
    end

    -- Функция для расчета масштаба текста в зависимости от расстояния
    local function calculateTextScale(distance)
        local minDistance = 10
        local maxDistance = 100
        local minScale = 0.7
        local maxScale = 1.0
        
        if distance <= minDistance then
            return maxScale
        elseif distance >= maxDistance then
            return minScale
        else
            local normalized = (distance - minDistance) / (maxDistance - minDistance)
            return maxScale - (normalized * (maxScale - minScale))
        end
    end

    local function createESP(player)
        if ESP.Elements[player] then return end

        local esp = {
            BoxLines = {
                Top = Drawing.new("Line"),
                Bottom = Drawing.new("Line"),
                Left = Drawing.new("Line"),
                Right = Drawing.new("Line")
            },
            Box3DLines = {},
            Filled = supportsQuad and Drawing.new("Quad") or Drawing.new("Square"),
            NameDrawing = Drawing.new("Text"),
            CountryDrawing = Drawing.new("Text"),
            DeviceDrawing = Drawing.new("Text"),
            DribbleCDDrawing = Drawing.new("Text"), -- Новое: текст кулдауна дриблинга
            TackleCDDrawing = Drawing.new("Text"), -- Новое: текст кулдауна текла
            NameGui = nil,
            CountryGui = nil,
            DeviceGui = nil,
            DribbleCDGui = nil, -- Новое: GUI для кулдауна дриблинга
            TackleCDGui = nil, -- Новое: GUI для кулдауна текла
            HPBarLeft = nil, -- Новое: левый HP бар
            HPBarRight = nil, -- Новое: правый HP бар
            LastPosition = nil,
            LastVisible = false,
            LastIsSameTeam = nil
        }

        for _, line in pairs(esp.BoxLines) do
            line.Thickness = ESP.Settings.BoxSettings.Thickness.Value
            line.Transparency = 1 - ESP.Settings.BoxSettings.Transparency.Value
            line.Visible = false
        end

        -- Создаем 12 линий для 3D куба
        for i = 1, 12 do
            esp.Box3DLines[i] = Drawing.new("Line")
            esp.Box3DLines[i].Thickness = ESP.Settings.BoxSettings.Thickness.Value
            esp.Box3DLines[i].Transparency = 1 - ESP.Settings.BoxSettings.Transparency.Value
            esp.Box3DLines[i].Visible = false
        end

        esp.Filled.Filled = true
        esp.Filled.Transparency = 1 - ESP.Settings.BoxSettings.FilledTransparency.Value
        esp.Filled.Visible = false

        -- Настройки текста для имени
        esp.NameDrawing.Size = ESP.Settings.TextSettings.TextSize.Value
        esp.NameDrawing.Font = ESP.Settings.TextSettings.TextFont.Value
        esp.NameDrawing.Center = true
        esp.NameDrawing.Outline = true
        esp.NameDrawing.Visible = false

        -- Настройки текста для страны
        esp.CountryDrawing.Size = math.floor(ESP.Settings.TextSettings.TextSize.Value * 0.8)
        esp.CountryDrawing.Font = ESP.Settings.TextSettings.TextFont.Value
        esp.CountryDrawing.Center = true
        esp.CountryDrawing.Outline = true
        esp.CountryDrawing.Visible = false

        -- Настройки текста для устройства
        esp.DeviceDrawing.Size = math.floor(ESP.Settings.TextSettings.TextSize.Value * 0.8)
        esp.DeviceDrawing.Font = ESP.Settings.TextSettings.TextFont.Value
        esp.DeviceDrawing.Center = true
        esp.DeviceDrawing.Outline = true
        esp.DeviceDrawing.Visible = false

        -- Настройки текста для кулдауна дриблинга
        esp.DribbleCDDrawing.Size = math.floor(ESP.Settings.TextSettings.TextSize.Value * 0.7)
        esp.DribbleCDDrawing.Font = ESP.Settings.TextSettings.TextFont.Value
        esp.DribbleCDDrawing.Center = true
        esp.DribbleCDDrawing.Outline = true
        esp.DribbleCDDrawing.Visible = false

        -- Настройки текста для кулдауна текла
        esp.TackleCDDrawing.Size = math.floor(ESP.Settings.TextSettings.TextSize.Value * 0.7)
        esp.TackleCDDrawing.Font = ESP.Settings.TextSettings.TextFont.Value
        esp.TackleCDDrawing.Center = true
        esp.TackleCDDrawing.Outline = true
        esp.TackleCDDrawing.Visible = false

        -- Создаем GUI элементы
        local function createGuiElement(textSize, name)
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0, 200, 0, 20)
            label.BackgroundTransparency = 1
            label.TextSize = textSize
            label.Font = Enum.Font.Gotham
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextStrokeTransparency = 0
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.TextXAlignment = Enum.TextXAlignment.Center
            label.Visible = false
            label.Parent = ESPGui
            return label
        end

        -- Создаем GUI элементы для кулдаунов
        local function createCDGuiElement(textSize, name)
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0, 60, 0, 18)
            label.BackgroundTransparency = 1
            label.TextSize = textSize
            label.Font = Enum.Font.GothamBold
            label.TextStrokeTransparency = 0
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.TextXAlignment = Enum.TextXAlignment.Center
            label.Visible = false
            label.Parent = ESPGui
            return label
        end

        -- Создаем HP бар
        local function createHPBar(isLeft)
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0, 4, 0, 0)
            frame.BackgroundColor3 = ESP.Settings.BoxSettings.HPBarColor.Value
            frame.BorderSizePixel = 0
            frame.Visible = false
            frame.Parent = ESPGui
            
            if isLeft then
                frame.AnchorPoint = Vector2.new(1, 0)
            end
            
            return frame
        end

        esp.NameGui = createGuiElement(ESP.Settings.TextSettings.TextSize.Value, "Name")
        esp.CountryGui = createGuiElement(math.floor(ESP.Settings.TextSettings.TextSize.Value * 0.8), "Country")
        esp.DeviceGui = createGuiElement(math.floor(ESP.Settings.TextSettings.TextSize.Value * 0.8), "Device")
        esp.DribbleCDGui = createCDGuiElement(math.floor(ESP.Settings.TextSettings.TextSize.Value * 0.7), "DribbleCD")
        esp.TackleCDGui = createCDGuiElement(math.floor(ESP.Settings.TextSettings.TextSize.Value * 0.7), "TackleCD")
        
        -- Создаем HP бары
        if ESP.Settings.BoxSettings.HPBarStyle.Value ~= "Default" then
            esp.HPBarLeft = createHPBar(true)
            esp.HPBarRight = createHPBar(false)
        end

        ESP.Elements[player] = esp
    end

    local function removeESP(player)
        if not ESP.Elements[player] then return end
        for _, line in pairs(ESP.Elements[player].BoxLines) do line:Remove() end
        for _, line in pairs(ESP.Elements[player].Box3DLines or {}) do line:Remove() end
        ESP.Elements[player].Filled:Remove()
        ESP.Elements[player].NameDrawing:Remove()
        ESP.Elements[player].CountryDrawing:Remove()
        ESP.Elements[player].DeviceDrawing:Remove()
        ESP.Elements[player].DribbleCDDrawing:Remove()
        ESP.Elements[player].TackleCDDrawing:Remove()
        
        if ESP.Elements[player].NameGui then ESP.Elements[player].NameGui:Destroy() end
        if ESP.Elements[player].CountryGui then ESP.Elements[player].CountryGui:Destroy() end
        if ESP.Elements[player].DeviceGui then ESP.Elements[player].DeviceGui:Destroy() end
        if ESP.Elements[player].DribbleCDGui then ESP.Elements[player].DribbleCDGui:Destroy() end
        if ESP.Elements[player].TackleCDGui then ESP.Elements[player].TackleCDGui:Destroy() end
        if ESP.Elements[player].HPBarLeft then ESP.Elements[player].HPBarLeft:Destroy() end
        if ESP.Elements[player].HPBarRight then ESP.Elements[player].HPBarRight:Destroy() end
        
        ESP.Elements[player] = nil
        Cache.PlayerCache[player] = nil
        Cache.PlayerBoxCache[player] = nil
    end

    -- Основная функция обновления ESP
    local function updateESP()
        local currentTime = tick()
        
        -- Проверяем интервал для 60 FPS
        if currentTime - ESP.LastUpdateTime < ESP.UpdateInterval then
            return
        end
        ESP.LastUpdateTime = currentTime
        
        if not ESP.Settings.Enabled.Value then
            for _, esp in pairs(ESP.Elements) do
                for _, line in pairs(esp.BoxLines) do line.Visible = false end
                for _, line in pairs(esp.Box3DLines) do line.Visible = false end
                esp.Filled.Visible = false
                esp.NameDrawing.Visible = false
                esp.CountryDrawing.Visible = false
                esp.DeviceDrawing.Visible = false
                esp.DribbleCDDrawing.Visible = false
                esp.TackleCDDrawing.Visible = false
                if esp.NameGui then esp.NameGui.Visible = false end
                if esp.CountryGui then esp.CountryGui.Visible = false end
                if esp.DeviceGui then esp.DeviceGui.Visible = false end
                if esp.DribbleCDGui then esp.DribbleCDGui.Visible = false end
                if esp.TackleCDGui then esp.TackleCDGui.Visible = false end
                if esp.HPBarLeft then esp.HPBarLeft.Visible = false end
                if esp.HPBarRight then esp.HPBarRight.Visible = false end
                esp.LastVisible = false
            end
            return
        end

        local camera = Core.PlayerData.Camera
        if not camera then return end

        local localPlayer = Core.PlayerData.LocalPlayer
        local localTeam = getPlayerTeam(localPlayer)

        for _, player in pairs(Core.Services.Players:GetPlayers()) do
            if player == localPlayer then continue end

            if not ESP.Elements[player] then
                createESP(player)
            end

            local esp = ESP.Elements[player]
            if not esp then continue end

            local character = player.Character
            local humanoid = character and character:FindFirstChild("Humanoid")
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")

            if not character or not humanoid or not rootPart or humanoid.Health <= 0 then
                if esp.LastVisible then
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    for _, line in pairs(esp.Box3DLines) do line.Visible = false end
                    esp.Filled.Visible = false
                    esp.NameDrawing.Visible = false
                    esp.CountryDrawing.Visible = false
                    esp.DeviceDrawing.Visible = false
                    esp.DribbleCDDrawing.Visible = false
                    esp.TackleCDDrawing.Visible = false
                    if esp.NameGui then esp.NameGui.Visible = false end
                    if esp.CountryGui then esp.CountryGui.Visible = false end
                    if esp.DeviceGui then esp.DeviceGui.Visible = false end
                    if esp.DribbleCDGui then esp.DribbleCDGui.Visible = false end
                    if esp.TackleCDGui then esp.TackleCDGui.Visible = false end
                    if esp.HPBarLeft then esp.HPBarLeft.Visible = false end
                    if esp.HPBarRight then esp.HPBarRight.Visible = false end
                    esp.LastVisible = false
                end
                continue
            end

            local rootPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            
            if not onScreen then
                if esp.LastVisible then
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    for _, line in pairs(esp.Box3DLines) do line.Visible = false end
                    esp.Filled.Visible = false
                    esp.NameDrawing.Visible = false
                    esp.CountryDrawing.Visible = false
                    esp.DeviceDrawing.Visible = false
                    esp.DribbleCDDrawing.Visible = false
                    esp.TackleCDDrawing.Visible = false
                    if esp.NameGui then esp.NameGui.Visible = false end
                    if esp.CountryGui then esp.CountryGui.Visible = false end
                    if esp.DeviceGui then esp.DeviceGui.Visible = false end
                    if esp.DribbleCDGui then esp.DribbleCDGui.Visible = false end
                    if esp.TackleCDGui then esp.TackleCDGui.Visible = false end
                    if esp.HPBarLeft then esp.HPBarLeft.Visible = false end
                    if esp.HPBarRight then esp.HPBarRight.Visible = false end
                    esp.LastVisible = false
                end
                continue
            end

            esp.LastVisible = true
            esp.LastPosition = rootPos

            -- Определяем цвет в зависимости от команды
            local playerTeam = getPlayerTeam(player)
            local isSameTeam = false
            
            if ESP.Settings.TeamCheck.Value and localTeam and playerTeam then
                isSameTeam = (localTeam == playerTeam)
                esp.LastIsSameTeam = isSameTeam
            else
                isSameTeam = esp.LastIsSameTeam or false
            end

            -- Определяем базовый цвет
            local baseColor
            if ESP.Settings.UseTeamColor.Value and playerTeam then
                baseColor = playerTeam.TeamColor.Color
            else
                if isSameTeam then
                    baseColor = ESP.Settings.TeamColor.Value
                else
                    baseColor = ESP.Settings.EnemyColor.Value
                end
            end
            
            local gradColor1, gradColor2 = Core.GradientColors.Color1.Value, Color3.fromRGB(0, 255, 0)

            local color = baseColor
            if ESP.Settings.BoxSettings.GradientEnabled.Value then
                local t = (math.sin(currentTime * ESP.Settings.BoxSettings.GradientSpeed.Value * 0.5) + 1) / 2
                color = gradColor1:Lerp(gradColor2, t)
            end

            -- Получаем данные игрока
            local playerData = getPlayerCooldowns(player)
            local dribbleCDText = formatTime(playerData.dribbleCD)
            local tackleCDText = formatTime(playerData.tackleCD)

            if ESP.Settings.ESPMode.Value == "3D" then
                -- 3D ESP
                local points = get3DBoxPoints(character, camera)
                
                if points and ESP.Settings.BoxSettings.ShowBox.Value then
                    local connections = {
                        {1, 2}, {2, 3}, {3, 4}, {4, 1},
                        {5, 6}, {6, 7}, {7, 8}, {8, 5},
                        {1, 5}, {2, 6}, {3, 7}, {4, 8}
                    }
                    
                    for i, conn in ipairs(connections) do
                        if esp.Box3DLines[i] then
                            esp.Box3DLines[i].From = points[conn[1]]
                            esp.Box3DLines[i].To = points[conn[2]]
                            esp.Box3DLines[i].Color = color
                            esp.Box3DLines[i].Visible = true
                        end
                    end
                    
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    esp.Filled.Visible = false
                else
                    for _, line in pairs(esp.Box3DLines) do line.Visible = false end
                end
            else
                -- 2D ESP
                for _, line in pairs(esp.Box3DLines) do line.Visible = false end
                
                if ESP.Settings.BoxSettings.ShowBox.Value then
                    local headPos = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3.5, 0))
                    local feetPos = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3.5, 0))
                    
                    local height = math.abs(headPos.Y - feetPos.Y)
                    local width = height * 0.4 -- Нормальная пропорция (40%)
                    
                    local topLeft = Vector2.new(rootPos.X - width/2, headPos.Y)
                    local topRight = Vector2.new(rootPos.X + width/2, headPos.Y)
                    local bottomLeft = Vector2.new(rootPos.X - width/2, feetPos.Y)
                    local bottomRight = Vector2.new(rootPos.X + width/2, feetPos.Y)
                    
                    esp.BoxLines.Top.From = topLeft
                    esp.BoxLines.Top.To = topRight
                    esp.BoxLines.Bottom.From = bottomLeft
                    esp.BoxLines.Bottom.To = bottomRight
                    esp.BoxLines.Left.From = topLeft
                    esp.BoxLines.Left.To = bottomLeft
                    esp.BoxLines.Right.From = topRight
                    esp.BoxLines.Right.To = bottomRight
                    
                    for _, line in pairs(esp.BoxLines) do
                        line.Color = color
                        line.Visible = true
                    end
                    
                    if ESP.Settings.BoxSettings.FilledEnabled.Value then
                        if supportsQuad then
                            esp.Filled.PointA = topLeft
                            esp.Filled.PointB = topRight
                            esp.Filled.PointC = bottomRight
                            esp.Filled.PointD = bottomLeft
                        else
                            esp.Filled.Position = Vector2.new(topLeft.X, topLeft.Y)
                            esp.Filled.Size = Vector2.new(bottomRight.X - topLeft.X, bottomRight.Y - topLeft.Y)
                        end
                        esp.Filled.Color = color
                        esp.Filled.Visible = true
                    else
                        esp.Filled.Visible = false
                    end
                    
                    -- Отображение HP бара
                    if ESP.Settings.BoxSettings.HPBarStyle.Value ~= "Default" and esp.HPBarLeft and esp.HPBarRight then
                        local hp = humanoid.Health
                        local maxHp = humanoid.MaxHealth
                        local hpPercent = hp / maxHp
                        local hpBarHeight = height * 0.8
                        local hpBarYOffset = hpBarHeight * (1 - hpPercent)
                        
                        if ESP.Settings.BoxSettings.HPBarStyle.Value == "Left" or ESP.Settings.BoxSettings.HPBarStyle.Value == "Both" then
                            esp.HPBarLeft.Position = UDim2.new(0, topLeft.X - 6, 0, topLeft.Y + hpBarYOffset)
                            esp.HPBarLeft.Size = UDim2.new(0, 4, 0, hpBarHeight * hpPercent)
                            esp.HPBarLeft.BackgroundColor3 = Color3.fromRGB(
                                math.floor(255 * (1 - hpPercent)),
                                math.floor(255 * hpPercent),
                                0
                            )
                            esp.HPBarLeft.Visible = true
                        end
                        
                        if ESP.Settings.BoxSettings.HPBarStyle.Value == "Right" or ESP.Settings.BoxSettings.HPBarStyle.Value == "Both" then
                            esp.HPBarRight.Position = UDim2.new(0, topRight.X + 2, 0, topLeft.Y + hpBarYOffset)
                            esp.HPBarRight.Size = UDim2.new(0, 4, 0, hpBarHeight * hpPercent)
                            esp.HPBarRight.BackgroundColor3 = Color3.fromRGB(
                                math.floor(255 * (1 - hpPercent)),
                                math.floor(255 * hpPercent),
                                0
                            )
                            esp.HPBarRight.Visible = true
                        end
                    end
                else
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    esp.Filled.Visible = false
                    if esp.HPBarLeft then esp.HPBarLeft.Visible = false end
                    if esp.HPBarRight then esp.HPBarRight.Visible = false end
                end
            end

            -- Расчет позиций для текстовой информации
            local nameY, infoY
            
            -- Масштаб текста в зависимости от расстояния
            local distance = (camera.CFrame.Position - rootPart.Position).Magnitude
            local textScale = calculateTextScale(distance) * ESP.Settings.TextSettings.TextScale.Value
            
            if ESP.Settings.ESPMode.Value == "3D" then
                local points = get3DBoxPoints(character, camera)
                if points then
                    local minY = math.huge
                    for i = 1, 8 do
                        if points[i].Y < minY then minY = points[i].Y end
                    end
                    
                    if ESP.Settings.BoxSettings.InfoPosition.Value == "Top" then
                        -- Информация сверху: под именем
                        nameY = minY - 25 * textScale
                    else
                        -- Информация снизу: под боксом
                        local maxY = -math.huge
                        for i = 1, 8 do
                            if points[i].Y > maxY then maxY = points[i].Y end
                        end
                        nameY = maxY + 10 * textScale
                    end
                else
                    nameY = rootPos.Y - 35 * textScale
                end
            else
                local headPos = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3.5, 0))
                local feetPos = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3.5, 0))
                
                if ESP.Settings.BoxSettings.InfoPosition.Value == "Top" then
                    -- Информация сверху: под именем
                    nameY = headPos.Y - 35 * textScale
                else
                    -- Информация снизу: под боксом
                    nameY = feetPos.Y + 10 * textScale
                end
            end
            
            -- Позиция для дополнительной информации (страна, устройство, кулдауны)
            infoY = nameY + 15 * textScale

            -- Проверяем, чтобы текст не уходил за пределы экрана
            local screenHeight = Core.Services.UserInputService:GetMouseLocation().Y * 2
            if nameY < 20 then nameY = 20 end
            if infoY < 35 then infoY = 35 end
            if nameY > screenHeight - 60 then nameY = screenHeight - 60 end
            if infoY > screenHeight - 45 then infoY = screenHeight - 45 end

            -- Отображение имени
            if ESP.Settings.BoxSettings.ShowNames.Value then
                local nameColor = ESP.Settings.BoxSettings.GradientEnabled.Value and color or baseColor
                local actualTextSize = math.floor(ESP.Settings.TextSettings.TextSize.Value * textScale)
                
                if ESP.Settings.TextSettings.TextMethod.Value == "Drawing" then
                    esp.NameDrawing.Text = player.Name
                    esp.NameDrawing.Size = actualTextSize
                    esp.NameDrawing.Position = Vector2.new(rootPos.X, nameY)
                    esp.NameDrawing.Color = nameColor
                    esp.NameDrawing.Visible = true
                    if esp.NameGui then esp.NameGui.Visible = false end
                elseif ESP.Settings.TextSettings.TextMethod.Value == "GUI" and esp.NameGui then
                    esp.NameGui.Text = player.Name
                    esp.NameGui.Position = UDim2.new(0, rootPos.X - 100, 0, nameY)
                    esp.NameGui.TextSize = actualTextSize
                    esp.NameGui.TextColor3 = nameColor
                    esp.NameGui.Visible = true
                    esp.NameDrawing.Visible = false
                end
            else
                esp.NameDrawing.Visible = false
                if esp.NameGui then esp.NameGui.Visible = false end
            end

            -- Собираем информацию для отображения в одну строку
            local infoParts = {}
            
            if ESP.Settings.BoxSettings.ShowCountry.Value then
                table.insert(infoParts, getPlayerCountry(player))
            end
            
            if ESP.Settings.BoxSettings.ShowDevice.Value then
                table.insert(infoParts, getPlayerDevice(player))
            end
            
            if ESP.Settings.BoxSettings.ShowDribbleCD.Value and dribbleCDText ~= "" then
                table.insert(infoParts, "D:" .. dribbleCDText)
            end
            
            if ESP.Settings.BoxSettings.ShowTackleCD.Value and tackleCDText ~= "" then
                table.insert(infoParts, "T:" .. tackleCDText)
            end
            
            local infoText = table.concat(infoParts, " ")
            
            if infoText ~= "" then
                local infoColor = ESP.Settings.BoxSettings.GradientEnabled.Value and color or Color3.fromRGB(200, 200, 200)
                local actualInfoSize = math.floor(ESP.Settings.TextSettings.TextSize.Value * 0.8 * textScale)
                
                if ESP.Settings.TextSettings.TextMethod.Value == "Drawing" then
                    esp.CountryDrawing.Text = infoText
                    esp.CountryDrawing.Size = actualInfoSize
                    esp.CountryDrawing.Position = Vector2.new(rootPos.X, infoY)
                    esp.CountryDrawing.Color = infoColor
                    esp.CountryDrawing.Visible = true
                    if esp.CountryGui then esp.CountryGui.Visible = false end
                elseif ESP.Settings.TextSettings.TextMethod.Value == "GUI" and esp.CountryGui then
                    esp.CountryGui.Text = infoText
                    esp.CountryGui.Position = UDim2.new(0, rootPos.X - 100, 0, infoY)
                    esp.CountryGui.TextSize = actualInfoSize
                    esp.CountryGui.TextColor3 = infoColor
                    esp.CountryGui.Visible = true
                    esp.CountryDrawing.Visible = false
                end
            else
                esp.CountryDrawing.Visible = false
                esp.DeviceDrawing.Visible = false
                esp.DribbleCDDrawing.Visible = false
                esp.TackleCDDrawing.Visible = false
                if esp.CountryGui then esp.CountryGui.Visible = false end
                if esp.DeviceGui then esp.DeviceGui.Visible = false end
                if esp.DribbleCDGui then esp.DribbleCDGui.Visible = false end
                if esp.TackleCDGui then esp.TackleCDGui.Visible = false end
            end
        end
    end

    -- Инициализация ESP
    task.wait(1)
    for _, player in pairs(Core.Services.Players:GetPlayers()) do
        if player ~= Core.PlayerData.LocalPlayer then createESP(player) end
    end

    Core.Services.Players.PlayerAdded:Connect(function(player)
        if player ~= Core.PlayerData.LocalPlayer then createESP(player) end
    end)

    Core.Services.Players.PlayerRemoving:Connect(removeESP)
    
    -- Запускаем ESP с фиксированным FPS
    local function runESP()
        while true do
            updateESP()
            task.wait(ESP.UpdateInterval)
        end
    end
    
    task.spawn(runESP)

    -- UI Configuration
    if UI.Tabs and UI.Tabs.Visuals then
        -- Меню Button Section
        if UI.Sections and UI.Sections.MenuButton then
            UI.Sections.MenuButton:Header({ Name = "Menu Button Settings" })
            UI.Sections.MenuButton:Toggle({
                Name = "Enabled",
                Default = State.MenuButton.Enabled,
                Callback = function(value)
                    State.MenuButton.Enabled = value
                    buttonFrame.Visible = value
                    notify("Menu Button", "Menu Button " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'EnabledMS')
            
            UI.Sections.MenuButton:Toggle({
                Name = "Mobile Mode",
                Default = State.MenuButton.Mobile,
                Callback = function(value)
                    State.MenuButton.Mobile = value
                    notify("Menu Button", "Mobile mode " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'MobileMode')
            
            UI.Sections.MenuButton:Dropdown({
                Name = "Button Design",
                Options = {"Default", "Default v2"},
                Default = "Default",
                Callback = function(value)
                    applyDesign(value)
                    notify("Menu Button", "Design changed to: " .. value, true)
                end
            }, 'MenuButtonDesign')
        end

        -- Watermark Section
        if UI.Sections and UI.Sections.Watermark then
            UI.Sections.Watermark:Header({ Name = "Watermark Settings" })
            UI.Sections.Watermark:Toggle({
                Name = "Enabled",
                Default = State.Watermark.Enabled,
                Callback = function(value)
                    setWatermarkVisibility(value)
                    notify("Watermark", "Watermark " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'EnabledWM')
            
            UI.Sections.Watermark:Slider({
                Name = "Gradient Speed",
                Minimum = 0.1,
                Maximum = 3.5,
                Default = WatermarkConfig.gradientSpeed,
                Precision = 1,
                Callback = function(value)
                    WatermarkConfig.gradientSpeed = value
                    notify("Watermark", "Gradient Speed set to: " .. value)
                end
            }, 'GradientSpeedWM')
            
            UI.Sections.Watermark:Slider({
                Name = "Segment Count",
                Minimum = 8,
                Maximum = 16,
                Default = WatermarkConfig.segmentCount,
                Precision = 0,
                Callback = function(value)
                    WatermarkConfig.segmentCount = value
                    task.defer(initWatermark)
                    notify("Watermark", "Segment Count set to: " .. value)
                end
            }, 'SegmentCount')
            
            UI.Sections.Watermark:Toggle({
                Name = "Show FPS",
                Default = WatermarkConfig.showFPS,
                Callback = function(value)
                    WatermarkConfig.showFPS = value
                    task.defer(initWatermark)
                    notify("Watermark", "Show FPS " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'ShowFPS')
            
            UI.Sections.Watermark:Toggle({
                Name = "Show Time",
                Default = WatermarkConfig.showTime,
                Callback = function(value)
                    WatermarkConfig.showTime = value
                    task.defer(initWatermark)
                    notify("Watermark", "Show Time " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'ShowTime')
        end

        -- ESP Section
        if UI.Sections and UI.Sections.ESP then
            -- MAIN SETTINGS
            UI.Sections.ESP:Header({ Name = "ESP Settings" })
            
            UI.Sections.ESP:Toggle({
                Name = "Enabled",
                Default = ESP.Settings.Enabled.Default,
                Callback = function(value)
                    ESP.Settings.Enabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "ESP " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'EnabledESP')
            
            UI.Sections.ESP:Dropdown({
                Name = "ESP Mode",
                Options = {"2D", "3D"},
                Default = ESP.Settings.ESPMode.Default,
                Callback = function(value)
                    ESP.Settings.ESPMode.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "ESP Mode changed to: " .. value, true)
                    end
                end
            }, 'ESPMode')
            
            UI.Sections.ESP:Toggle({
                Name = "Use Team Color",
                Default = ESP.Settings.UseTeamColor.Default,
                Callback = function(value)
                    ESP.Settings.UseTeamColor.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Use Team Color " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'UseTeamColorESP')
            
            UI.Sections.ESP:Divider()
            
            -- COLOR SETTINGS
            UI.Sections.ESP:Header({ Name = "Colors" })
            
            UI.Sections.ESP:Colorpicker({
                Name = "Enemy Color",
                Default = ESP.Settings.EnemyColor.Default,
                Callback = function(value)
                    ESP.Settings.EnemyColor.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Enemy Color updated", true)
                    end
                end
            }, 'EnemyColor')
            
            UI.Sections.ESP:Colorpicker({
                Name = "Team Color",
                Default = ESP.Settings.TeamColor.Default,
                Callback = function(value)
                    ESP.Settings.TeamColor.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Team Color updated", true)
                    end
                end
            }, 'TeamColor')
            
            UI.Sections.ESP:Toggle({
                Name = "Team Check",
                Default = ESP.Settings.TeamCheck.Default,
                Callback = function(value)
                    ESP.Settings.TeamCheck.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Team Check " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'TeamCheckESP')
            
            UI.Sections.ESP:Divider()
            
            -- BOX SETTINGS
            UI.Sections.ESP:Header({ Name = "Box Settings" })
            
            UI.Sections.ESP:Toggle({
                Name = "Show Box",
                Default = ESP.Settings.BoxSettings.ShowBox.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.ShowBox.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Box " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowBox')
            
            UI.Sections.ESP:Slider({
                Name = "Thickness",
                Minimum = 1,
                Maximum = 5,
                Default = ESP.Settings.BoxSettings.Thickness.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.BoxSettings.Thickness.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        for _, line in pairs(esp.BoxLines) do line.Thickness = value end
                        for _, line in pairs(esp.Box3DLines) do line.Thickness = value end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Thickness set to: " .. value)
                    end
                end
            }, 'ThicknessESP')
            
            UI.Sections.ESP:Slider({
                Name = "Transparency",
                Minimum = 0,
                Maximum = 1,
                Default = ESP.Settings.BoxSettings.Transparency.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.BoxSettings.Transparency.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        for _, line in pairs(esp.BoxLines) do line.Transparency = 1 - value end
                        for _, line in pairs(esp.Box3DLines) do line.Transparency = 1 - value end
                        esp.Filled.Transparency = 1 - ESP.Settings.BoxSettings.FilledTransparency.Value
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Transparency set to: " .. value)
                    end
                end
            }, 'TransparencyESP')
            
            UI.Sections.ESP:Toggle({
                Name = "Filled Box",
                Default = ESP.Settings.BoxSettings.FilledEnabled.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.FilledEnabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Filled Box " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'FilledEnabled')
            
            UI.Sections.ESP:Slider({
                Name = "Filled Transparency",
                Minimum = 0,
                Maximum = 1,
                Default = ESP.Settings.BoxSettings.FilledTransparency.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.BoxSettings.FilledTransparency.Value = value
                    for _, esp in pairs(ESP.Elements) do 
                        esp.Filled.Transparency = 1 - value 
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Filled Transparency set to: " .. value)
                    end
                end
            }, 'FilledTransparency')
            
            UI.Sections.ESP:Toggle({
                Name = "Gradient",
                Default = ESP.Settings.BoxSettings.GradientEnabled.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.GradientEnabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Gradient " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'GradientEnabledESP')
            
            UI.Sections.ESP:Slider({
                Name = "Gradient Speed",
                Minimum = 1,
                Maximum = 5,
                Default = ESP.Settings.BoxSettings.GradientSpeed.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.BoxSettings.GradientSpeed.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Gradient Speed set to: " .. value)
                    end
                end
            }, 'GradientSpeed')
            
            UI.Sections.ESP:Divider()
            
            -- INFO SETTINGS
            UI.Sections.ESP:Header({ Name = "Info Settings" })
            
            UI.Sections.ESP:Toggle({
                Name = "Show Country",
                Default = ESP.Settings.BoxSettings.ShowCountry.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.ShowCountry.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Country display " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowCountry')
            
            UI.Sections.ESP:Toggle({
                Name = "Show Device",
                Default = ESP.Settings.BoxSettings.ShowDevice.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.ShowDevice.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Device display " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowDevice')
            
            UI.Sections.ESP:Toggle({
                Name = "Show Dribble CD",
                Default = ESP.Settings.BoxSettings.ShowDribbleCD.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.ShowDribbleCD.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Dribble CD display " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowDribbleCD')
            
            UI.Sections.ESP:Toggle({
                Name = "Show Tackle CD",
                Default = ESP.Settings.BoxSettings.ShowTackleCD.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.ShowTackleCD.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Tackle CD display " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowTackleCD')
            
            UI.Sections.ESP:Dropdown({
                Name = "Info Position",
                Options = {"Bottom", "Top"},
                Default = ESP.Settings.BoxSettings.InfoPosition.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.InfoPosition.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Info Position set to: " .. value, true)
                    end
                end
            }, 'InfoPosition')
            
            UI.Sections.ESP:Dropdown({
                Name = "HP Bar Style",
                Options = {"Default", "Left", "Right", "Both"},
                Default = ESP.Settings.BoxSettings.HPBarStyle.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.HPBarStyle.Value = value
                    -- Пересоздаем ESP для всех игроков с новым стилем HP бара
                    for _, player in pairs(Core.Services.Players:GetPlayers()) do
                        if player ~= Core.PlayerData.LocalPlayer then
                            removeESP(player)
                            createESP(player)
                        end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "HP Bar Style set to: " .. value, true)
                    end
                end
            }, 'HPBarStyle')
            
            UI.Sections.ESP:Colorpicker({
                Name = "HP Bar Color",
                Default = ESP.Settings.BoxSettings.HPBarColor.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.HPBarColor.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        if esp.HPBarLeft then esp.HPBarLeft.BackgroundColor3 = value end
                        if esp.HPBarRight then esp.HPBarRight.BackgroundColor3 = value end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "HP Bar Color updated", true)
                    end
                end
            }, 'HPBarColor')
            
            UI.Sections.ESP:Divider()
            
            -- TEXT SETTINGS
            UI.Sections.ESP:Header({ Name = "Text Settings" })
            
            UI.Sections.ESP:Toggle({
                Name = "Show Names",
                Default = ESP.Settings.BoxSettings.ShowNames.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.ShowNames.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Names " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowNamesESP')
            
            UI.Sections.ESP:Slider({
                Name = "Text Size",
                Minimum = 10,
                Maximum = 30,
                Default = ESP.Settings.TextSettings.TextSize.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.TextSettings.TextSize.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        esp.NameDrawing.Size = value
                        esp.CountryDrawing.Size = math.floor(value * 0.8)
                        esp.DeviceDrawing.Size = math.floor(value * 0.8)
                        esp.DribbleCDDrawing.Size = math.floor(value * 0.7)
                        esp.TackleCDDrawing.Size = math.floor(value * 0.7)
                        if esp.NameGui then esp.NameGui.TextSize = value end
                        if esp.CountryGui then esp.CountryGui.TextSize = math.floor(value * 0.8) end
                        if esp.DeviceGui then esp.DeviceGui.TextSize = math.floor(value * 0.8) end
                        if esp.DribbleCDGui then esp.DribbleCDGui.TextSize = math.floor(value * 0.7) end
                        if esp.TackleCDGui then esp.TackleCDGui.TextSize = math.floor(value * 0.7) end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Size set to: " .. value)
                    end
                end
            }, 'TextSize')
            
            UI.Sections.ESP:Slider({
                Name = "Text Scale",
                Minimum = 0.5,
                Maximum = 1.5,
                Default = ESP.Settings.TextSettings.TextScale.Default,
                Precision = 2,
                Callback = function(value)
                    ESP.Settings.TextSettings.TextScale.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Scale set to: " .. value)
                    end
                end
            }, 'TextScale')
            
            UI.Sections.ESP:Dropdown({
                Name = "Text Method",
                Options = {"Drawing", "GUI"},
                Default = ESP.Settings.TextSettings.TextMethod.Default,
                Callback = function(value)
                    ESP.Settings.TextSettings.TextMethod.Value = value
                    for _, player in pairs(Core.Services.Players:GetPlayers()) do
                        if player ~= Core.PlayerData.LocalPlayer then
                            removeESP(player)
                            createESP(player)
                        end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Method set to: " .. value, true)
                    end
                end
            }, 'TextMethod')
            
            UI.Sections.ESP:Dropdown({
                Name = "Font",
                Options = {"UI", "System", "Plex", "Monospace"},
                Default = "Plex",
                Callback = function(value)
                    local fontMap = { 
                        ["UI"] = Drawing.Fonts.UI, 
                        ["System"] = Drawing.Fonts.System, 
                        ["Plex"] = Drawing.Fonts.Plex, 
                        ["Monospace"] = Drawing.Fonts.Monospace 
                    }
                    ESP.Settings.TextSettings.TextFont.Value = fontMap[value] or Drawing.Fonts.Plex
                    for _, esp in pairs(ESP.Elements) do 
                        esp.NameDrawing.Font = ESP.Settings.TextSettings.TextFont.Value 
                        esp.CountryDrawing.Font = ESP.Settings.TextSettings.TextFont.Value 
                        esp.DeviceDrawing.Font = ESP.Settings.TextSettings.TextFont.Value 
                        esp.DribbleCDDrawing.Font = ESP.Settings.TextSettings.TextFont.Value 
                        esp.TackleCDDrawing.Font = ESP.Settings.TextSettings.TextFont.Value 
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Font set to: " .. value, true)
                    end
                end
            }, 'TextFont')
        end
    end
end

return Visuals
