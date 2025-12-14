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
            ESPMode = { Value = "2D", Default = "2D" }, -- Новый параметр: 2D или 3D
            EnemyColor = { Value = Color3.fromRGB(255, 0, 0), Default = Color3.fromRGB(255, 0, 0) },
            FriendColor = { Value = Color3.fromRGB(0, 255, 0), Default = Color3.fromRGB(0, 255, 0) },
            TeamCheck = { Value = true, Default = true },
            BoxSettings = {
                Thickness = { Value = 1, Default = 1 },
                Transparency = { Value = 0.2, Default = 0.2 },
                ShowBox = { Value = true, Default = true },
                ShowNames = { Value = true, Default = true },
                GradientEnabled = { Value = false, Default = false },
                FilledEnabled = { Value = false, Default = false },
                FilledTransparency = { Value = 0.5, Default = 0.5 },
                GradientSpeed = { Value = 2, Default = 2 }
            },
            TextSettings = {
                TextSize = { Value = 14, Default = 14 },
                TextFont = { Value = Drawing.Fonts.Plex, Default = Drawing.Fonts.Plex },
                TextMethod = { Value = "Drawing", Default = "Drawing" }
            },
            PlayerFilter = {
                MaxDistance = { Value = 500, Default = 500 },
                MinFOV = { Value = 30, Default = 30 }
            }
        },
        Elements = {},
        GuiElements = {},
        LastNotificationTime = 0,
        NotificationDelay = 5,
        CloseDistance = 300,
        NearFPS = 50,
        DefaultFPS = 30
    }

    local Cache = { 
        TextBounds = {}, 
        LastGradientUpdate = 0, 
        PlayerCache = {}, 
        LastUpdateTimes = {},
        PlayerBoxCache = {} -- Кэш для стабильных размеров боксов
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
            -- Mobile режим: меняем видимость Base frame
            if baseFrame then
                local isVisible = not baseFrame.Visible
                baseFrame.Visible = isVisible
                notify("Menu Button", "Menu " .. (isVisible and "Enabled" or "Disabled"), true)
                return isVisible
            else
                -- Если не нашли, пробуем найти снова
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
            -- Desktop режим: эмулируем RightControl
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
        -- Сохраняем текущую позицию
        local currentPos = buttonFrame.Position
        
        -- Очищаем старые эффекты Default v2
        for _, child in ipairs(buttonFrame:GetChildren()) do
            if child.Name ~= "UICorner" and child.Name ~= "MainIcon" then
                child:Destroy()
            end
        end
        
        -- Сбрасываем настройки
        buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        buttonFrame.BackgroundTransparency = 0.3
        buttonFrame.Size = UDim2.new(0, 50, 0, 50)
        buttonFrame.Position = currentPos -- Сохраняем позицию
        
        -- Восстанавливаем иконку
        buttonIcon.Visible = true
        buttonIcon.Size = UDim2.new(0, 30, 0, 30)
        buttonIcon.Position = UDim2.new(0.5, -15, 0.5, -15)
        buttonIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        
        -- Восстанавливаем скругление
        local corner = buttonFrame:FindFirstChild("UICorner")
        if corner then
            corner.CornerRadius = UDim.new(0.5, 0)
        else
            Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)
        end
    end

    local function applyDefaultV2Design()
        -- Сохраняем текущую позицию
        local currentPos = buttonFrame.Position
        
        -- Очищаем старые эффекты
        for _, child in ipairs(buttonFrame:GetChildren()) do
            if child.Name ~= "UICorner" and child.Name ~= "MainIcon" then
                child:Destroy()
            end
        end
        
        -- Скрываем основную иконку (но не удаляем)
        buttonIcon.Visible = false
        
        -- Устанавливаем размер и позицию
        buttonFrame.Size = UDim2.new(0, 48, 0, 48)
        buttonFrame.Position = currentPos
        buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        buttonFrame.BackgroundTransparency = 0.6
        
        -- Круглый фон
        local corner = buttonFrame:FindFirstChild("UICorner")
        if corner then
            corner.CornerRadius = UDim.new(0.5, 0)
        else
            Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)
        end
        
        -- Отдельный фрейм для иконки
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

    -- Функция для расчета 3D бокса
    local function calculate3DBoxCorners(character, camera)
        local corners = {}
        
        -- Получаем все части персонажа
        local parts = {}
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                table.insert(parts, part)
            end
        end
        
        if #parts == 0 then return nil end
        
        -- Находим минимальные и максимальные координаты
        local minX, minY, minZ = math.huge, math.huge, math.huge
        local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
        
        for _, part in pairs(parts) do
            local pos = part.Position
            local size = part.Size / 2
            
            minX = math.min(minX, pos.X - size.X)
            minY = math.min(minY, pos.Y - size.Y)
            minZ = math.min(minZ, pos.Z - size.Z)
            
            maxX = math.max(maxX, pos.X + size.X)
            maxY = math.max(maxY, pos.Y + size.Y)
            maxZ = math.max(maxZ, pos.Z + size.Z)
        end
        
        -- Определяем углы 3D бокса
        local corners3D = {
            Vector3.new(minX, minY, minZ), -- Нижний задний левый
            Vector3.new(maxX, minY, minZ), -- Нижний задний правый
            Vector3.new(maxX, maxY, minZ), -- Верхний задний правый
            Vector3.new(minX, maxY, minZ), -- Верхний задний левый
            Vector3.new(minX, minY, maxZ), -- Нижний передний левый
            Vector3.new(maxX, minY, maxZ), -- Нижний передний правый
            Vector3.new(maxX, maxY, maxZ), -- Верхний передний правый
            Vector3.new(minX, maxY, maxZ)  -- Верхний передний левый
        }
        
        -- Преобразуем в 2D координаты
        for i, corner3D in pairs(corners3D) do
            local corner2D, visible = camera:WorldToViewportPoint(corner3D)
            if not visible then return nil end
            corners[i] = Vector2.new(corner2D.X, corner2D.Y)
        end
        
        return corners
    end

    -- Функция для получения стабильных размеров бокса
    local function getStableBoxSize(player, character, camera)
        -- Используем кэшированные размеры если есть
        if Cache.PlayerBoxCache[player] then
            local cache = Cache.PlayerBoxCache[player]
            if tick() - cache.lastUpdate < 1 then -- Обновляем каждую секунду
                return cache.width, cache.height
            end
        end
        
        -- Получаем Humanoid для высоты
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            return 40, 80 -- Размеры по умолчанию
        end
        
        -- Стабильные размеры на основе высоты персонажа
        local height = humanoid.HipHeight * 2 + 4
        local width = height * 0.5
        
        -- Кэшируем результат
        Cache.PlayerBoxCache[player] = {
            width = width,
            height = height,
            lastUpdate = tick()
        }
        
        return width, height
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
            -- Линии для 3D бокса
            Box3DLines = {},
            Filled = supportsQuad and Drawing.new("Quad") or Drawing.new("Square"),
            NameDrawing = Drawing.new("Text"),
            NameGui = nil,
            LastPosition = nil,
            LastVisible = false,
            LastIsFriend = nil,
            LastFriendsList = nil
        }

        for _, line in pairs(esp.BoxLines) do
            line.Thickness = ESP.Settings.BoxSettings.Thickness.Value
            line.Transparency = 1 - ESP.Settings.BoxSettings.Transparency.Value
            line.Visible = false
        end

        -- Создаем линии для 3D бокса (12 линий для куба)
        if ESP.Settings.ESPMode.Value == "3D" then
            for i = 1, 12 do
                esp.Box3DLines[i] = Drawing.new("Line")
                esp.Box3DLines[i].Thickness = ESP.Settings.BoxSettings.Thickness.Value
                esp.Box3DLines[i].Transparency = 1 - ESP.Settings.BoxSettings.Transparency.Value
                esp.Box3DLines[i].Visible = false
            end
        end

        esp.Filled.Filled = true
        esp.Filled.Transparency = 1 - ESP.Settings.BoxSettings.FilledTransparency.Value
        esp.Filled.Visible = false

        esp.NameDrawing.Size = ESP.Settings.TextSettings.TextSize.Value
        esp.NameDrawing.Font = ESP.Settings.TextSettings.TextFont.Value
        esp.NameDrawing.Center = true
        esp.NameDrawing.Outline = true
        esp.NameDrawing.Visible = false

        if ESP.Settings.TextSettings.TextMethod.Value == "GUI" then
            esp.NameGui = Instance.new("TextLabel")
            esp.NameGui.Size = UDim2.new(0, 200, 0, 20)
            esp.NameGui.BackgroundTransparency = 1
            esp.NameGui.TextSize = ESP.Settings.TextSettings.TextSize.Value
            esp.NameGui.Font = Enum.Font.Gotham
            esp.NameGui.TextColor3 = Color3.fromRGB(255, 255, 255)
            esp.NameGui.TextStrokeTransparency = 0
            esp.NameGui.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            esp.NameGui.TextXAlignment = Enum.TextXAlignment.Center
            esp.NameGui.Visible = false
            esp.NameGui.Parent = ESPGui
            ESP.GuiElements[player] = esp.NameGui
        end

        ESP.Elements[player] = esp
    end

    local function removeESP(player)
        if not ESP.Elements[player] then return end
        for _, line in pairs(ESP.Elements[player].BoxLines) do line:Remove() end
        for _, line in pairs(ESP.Elements[player].Box3DLines or {}) do line:Remove() end
        ESP.Elements[player].Filled:Remove()
        ESP.Elements[player].NameDrawing:Remove()
        if ESP.Elements[player].NameGui then
            ESP.Elements[player].NameGui:Destroy()
            ESP.GuiElements[player] = nil
        end
        ESP.Elements[player] = nil
        Cache.PlayerCache[player] = nil
        Cache.LastUpdateTimes[player] = nil
        Cache.PlayerBoxCache[player] = nil
    end

    local function updateESP()
        if not ESP.Settings.Enabled.Value then
            for _, esp in pairs(ESP.Elements) do
                for _, line in pairs(esp.BoxLines) do line.Visible = false end
                for _, line in pairs(esp.Box3DLines or {}) do line.Visible = false end
                esp.Filled.Visible = false
                esp.NameDrawing.Visible = false
                if esp.NameGui then esp.NameGui.Visible = false end
                esp.LastVisible = false
            end
            return
        end

        local currentTime = tick()
        local camera = Core.PlayerData.Camera
        if not camera then return end

        local localPlayer = Core.PlayerData.LocalPlayer
        local localCharacter = localPlayer.Character
        local localRootPart = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
        if not localRootPart then return end

        local cameraPos = camera.CFrame.Position
        local viewportSize = camera.ViewportSize

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

            -- Проверка расстояния
            if rootPart then
                local distance = (rootPart.Position - cameraPos).Magnitude
                if distance > ESP.Settings.PlayerFilter.MaxDistance.Value then
                    if esp.LastVisible then
                        for _, line in pairs(esp.BoxLines) do line.Visible = false end
                        for _, line in pairs(esp.Box3DLines or {}) do line.Visible = false end
                        esp.Filled.Visible = false
                        esp.NameDrawing.Visible = false
                        if esp.NameGui then esp.NameGui.Visible = false end
                        esp.LastVisible = false
                    end
                    continue
                end
            end

            if not rootPart or not humanoid or humanoid.Health <= 0 then
                if esp.LastVisible then
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    for _, line in pairs(esp.Box3DLines or {}) do line.Visible = false end
                    esp.Filled.Visible = false
                    esp.NameDrawing.Visible = false
                    if esp.NameGui then esp.NameGui.Visible = false end
                    esp.LastVisible = false
                end
                continue
            end

            -- Обновление с интервалами для стабильности
            local updateInterval = 1 / 30 -- Фиксированный FPS для стабильности
            if currentTime - (Cache.LastUpdateTimes[player] or 0) < updateInterval then
                continue
            end
            Cache.LastUpdateTimes[player] = currentTime

            local rootPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            
            -- Проверка FOV
            if onScreen then
                local screenPos = Vector2.new(rootPos.X, rootPos.Y)
                local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
                local screenDist = (screenPos - screenCenter).Magnitude
                local fov = camera.FieldOfView
                local maxScreenDist = math.min(viewportSize.X, viewportSize.Y) * (fov / 180)
                
                if screenDist > maxScreenDist * (ESP.Settings.PlayerFilter.MinFOV.Value / 100) then
                    onScreen = false
                end
            end
            
            if not onScreen then
                if esp.LastVisible then
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    for _, line in pairs(esp.Box3DLines or {}) do line.Visible = false end
                    esp.Filled.Visible = false
                    esp.NameDrawing.Visible = false
                    if esp.NameGui then esp.NameGui.Visible = false end
                    esp.LastVisible = false
                end
                continue
            end

            esp.LastVisible = true
            esp.LastPosition = rootPos

            local isFriend = esp.LastIsFriend
            if esp.LastFriendsList ~= Core.Services.FriendsList or esp.LastIsFriend == nil then
                isFriend = Core.Services.FriendsList and Core.Services.FriendsList[player.Name:lower()] or false
                esp.LastIsFriend = isFriend
                esp.LastFriendsList = Core.Services.FriendsList
            end

            local baseColor = (isFriend and ESP.Settings.TeamCheck.Value) and ESP.Settings.FriendColor.Value or ESP.Settings.EnemyColor.Value
            local gradColor1, gradColor2 = Core.GradientColors.Color1.Value, (isFriend and ESP.Settings.TeamCheck.Value) and Color3.fromRGB(0, 255, 0) or Core.GradientColors.Color2.Value

            if ESP.Settings.ESPMode.Value == "3D" then
                -- 3D режим
                local corners = calculate3DBoxCorners(character, camera)
                if corners then
                    -- Определяем соединения для 3D куба (12 линий)
                    local connections = {
                        {1, 2}, {2, 3}, {3, 4}, {4, 1}, -- Задняя грань
                        {5, 6}, {6, 7}, {7, 8}, {8, 5}, -- Передняя грань
                        {1, 5}, {2, 6}, {3, 7}, {4, 8}  -- Соединительные линии
                    }
                    
                    local color = baseColor
                    if ESP.Settings.BoxSettings.GradientEnabled.Value then
                        local t = (math.sin(currentTime * ESP.Settings.BoxSettings.GradientSpeed.Value * 0.5) + 1) / 2
                        color = gradColor1:Lerp(gradColor2, t)
                    end
                    
                    for i, connection in pairs(connections) do
                        if esp.Box3DLines[i] then
                            esp.Box3DLines[i].From = corners[connection[1]]
                            esp.Box3DLines[i].To = corners[connection[2]]
                            esp.Box3DLines[i].Color = color
                            esp.Box3DLines[i].Thickness = ESP.Settings.BoxSettings.Thickness.Value
                            esp.Box3DLines[i].Transparency = 1 - ESP.Settings.BoxSettings.Transparency.Value
                            esp.Box3DLines[i].Visible = ESP.Settings.BoxSettings.ShowBox.Value
                        end
                    end
                    
                    -- Скрываем 2D линии
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    esp.Filled.Visible = false
                else
                    for _, line in pairs(esp.Box3DLines or {}) do line.Visible = false end
                end
            else
                -- 2D режим (оригинальный)
                local width, height = getStableBoxSize(player, character, camera)
                local headPos = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, height/2, 0))
                local feetPos = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, height/2, 0))
                
                local topLeft = Vector2.new(rootPos.X - width / 2, headPos.Y)
                local topRight = Vector2.new(rootPos.X + width / 2, headPos.Y)
                local bottomLeft = Vector2.new(rootPos.X - width / 2, feetPos.Y)
                local bottomRight = Vector2.new(rootPos.X + width / 2, feetPos.Y)

                if ESP.Settings.BoxSettings.ShowBox.Value then
                    local color = baseColor
                    if ESP.Settings.BoxSettings.GradientEnabled.Value then
                        local t = (math.sin(currentTime * ESP.Settings.BoxSettings.GradientSpeed.Value * 0.5) + 1) / 2
                        color = gradColor1:Lerp(gradColor2, t)
                    end

                    for _, line in pairs(esp.BoxLines) do
                        line.Color = color
                        line.Thickness = ESP.Settings.BoxSettings.Thickness.Value
                        line.Transparency = 1 - ESP.Settings.BoxSettings.Transparency.Value
                        line.Visible = true
                    end
                    
                    esp.BoxLines.Top.From = topLeft
                    esp.BoxLines.Top.To = topRight
                    esp.BoxLines.Bottom.From = bottomLeft
                    esp.BoxLines.Bottom.To = bottomRight
                    esp.BoxLines.Left.From = topLeft
                    esp.BoxLines.Left.To = bottomLeft
                    esp.BoxLines.Right.From = topRight
                    esp.BoxLines.Right.To = bottomRight

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
                        esp.Filled.Transparency = 1 - ESP.Settings.BoxSettings.FilledTransparency.Value
                        esp.Filled.Visible = true
                    else
                        esp.Filled.Visible = false
                    end
                    
                    -- Скрываем 3D линии
                    for _, line in pairs(esp.Box3DLines or {}) do line.Visible = false end
                else
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    for _, line in pairs(esp.Box3DLines or {}) do line.Visible = false end
                    esp.Filled.Visible = false
                end
            end

            if ESP.Settings.BoxSettings.ShowNames.Value then
                local t = ESP.Settings.BoxSettings.GradientEnabled.Value and (math.sin(currentTime * ESP.Settings.BoxSettings.GradientSpeed.Value * 0.5) + 1) / 2 or 0
                local nameColor = ESP.Settings.BoxSettings.GradientEnabled.Value and gradColor1:Lerp(gradColor2, t) or baseColor
                local nameY
                
                if ESP.Settings.ESPMode.Value == "3D" then
                    nameY = rootPos.Y - 30
                else
                    local width, height = getStableBoxSize(player, character, camera)
                    nameY = rootPos.Y - height/2 - 20
                end
                
                if ESP.Settings.TextSettings.TextMethod.Value == "Drawing" then
                    esp.NameDrawing.Text = player.Name
                    esp.NameDrawing.Position = Vector2.new(rootPos.X, nameY)
                    esp.NameDrawing.Color = nameColor
                    esp.NameDrawing.Size = ESP.Settings.TextSettings.TextSize.Value
                    esp.NameDrawing.Font = ESP.Settings.TextSettings.TextFont.Value
                    esp.NameDrawing.Visible = true
                    if esp.NameGui then esp.NameGui.Visible = false end
                elseif ESP.Settings.TextSettings.TextMethod.Value == "GUI" and esp.NameGui then
                    esp.NameGui.Text = player.Name
                    esp.NameGui.Position = UDim2.new(0, rootPos.X - 100, 0, nameY)
                    esp.NameGui.TextColor3 = nameColor
                    esp.NameGui.TextSize = ESP.Settings.TextSettings.TextSize.Value
                    esp.NameGui.Font = Enum.Font.Gotham
                    esp.NameGui.Visible = true
                    esp.NameDrawing.Visible = false
                end
            else
                esp.NameDrawing.Visible = false
                if esp.NameGui then esp.NameGui.Visible = false end
            end
        end
    end

    task.wait(1)
    for _, player in pairs(Core.Services.Players:GetPlayers()) do
        if player ~= Core.PlayerData.LocalPlayer then createESP(player) end
    end

    Core.Services.Players.PlayerAdded:Connect(function(player)
        if player ~= Core.PlayerData.LocalPlayer then createESP(player) end
    end)

    Core.Services.Players.PlayerRemoving:Connect(removeESP)
    Core.Services.RunService.RenderStepped:Connect(updateESP)

    -- UI Configuration (переработанная)
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

        -- ESP Section (переработанная)
        if UI.Sections and UI.Sections.ESP then
            -- MAIN SETTINGS SECTION
            UI.Sections.ESP:Header({ Name = "ESP - Main Settings" })
            
            UI.Sections.ESP:Toggle({
                Name = "ESP Enabled",
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
            
            UI.Sections.ESP:Divider()
            
            -- COLOR SETTINGS SECTION
            UI.Sections.ESP:Header({ Name = "Color Settings" })
            
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
                Name = "Friend Color",
                Default = ESP.Settings.FriendColor.Default,
                Callback = function(value)
                    ESP.Settings.FriendColor.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Friend Color updated", true)
                    end
                end
            }, 'FriendColor')
            
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
            
            -- BOX SETTINGS SECTION
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
                Name = "Box Thickness",
                Minimum = 1,
                Maximum = 5,
                Default = ESP.Settings.BoxSettings.Thickness.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.BoxSettings.Thickness.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        for _, line in pairs(esp.BoxLines) do line.Thickness = value end
                        for _, line in pairs(esp.Box3DLines or {}) do line.Thickness = value end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Box Thickness set to: " .. value)
                    end
                end
            }, 'ThicknessESP')
            
            UI.Sections.ESP:Slider({
                Name = "Box Transparency",
                Minimum = 0,
                Maximum = 1,
                Default = ESP.Settings.BoxSettings.Transparency.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.BoxSettings.Transparency.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        for _, line in pairs(esp.BoxLines) do line.Transparency = 1 - value end
                        for _, line in pairs(esp.Box3DLines or {}) do line.Transparency = 1 - value end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Box Transparency set to: " .. value)
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
                Name = "Gradient Effect",
                Default = ESP.Settings.BoxSettings.GradientEnabled.Default,
                Callback = function(value)
                    ESP.Settings.BoxSettings.GradientEnabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Gradient Effect " .. (value and "Enabled" or "Disabled"), true)
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
            
            -- TEXT SETTINGS SECTION
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
                        if esp.NameGui then esp.NameGui.TextSize = value end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Size set to: " .. value)
                    end
                end
            }, 'TextSize')
            
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
                Name = "Text Font",
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
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Font set to: " .. value, true)
                    end
                end
            }, 'TextFont')
            
            UI.Sections.ESP:Divider()
            
            -- FILTER SETTINGS SECTION
            UI.Sections.ESP:Header({ Name = "Filter Settings" })
            
            UI.Sections.ESP:Slider({
                Name = "Max Distance",
                Minimum = 100,
                Maximum = 1000,
                Default = ESP.Settings.PlayerFilter.MaxDistance.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.PlayerFilter.MaxDistance.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Max Distance set to: " .. value)
                    end
                end
            }, 'MaxDistanceESP')
            
            UI.Sections.ESP:Slider({
                Name = "Minimum FOV",
                Minimum = 10,
                Maximum = 100,
                Default = ESP.Settings.PlayerFilter.MinFOV.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.PlayerFilter.MinFOV.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Minimum FOV set to: " .. value .. "%")
                    end
                end
            }, 'MinFOVESP')
        end
    end
end

return Visuals
