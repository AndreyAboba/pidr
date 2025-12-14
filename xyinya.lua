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
            EnemyColor = { Value = Color3.fromRGB(255, 0, 0), Default = Color3.fromRGB(255, 0, 0) },
            FriendColor = { Value = Color3.fromRGB(0, 255, 0), Default = Color3.fromRGB(0, 255, 0) },
            TeamCheck = { Value = true, Default = true },
            Thickness = { Value = 1, Default = 1 },
            Transparency = { Value = 0.2, Default = 0.2 },
            TextSize = { Value = 14, Default = 14 },
            TextFont = { Value = Drawing.Fonts.Plex, Default = Drawing.Fonts.Plex },
            TextMethod = { Value = "Drawing", Default = "Drawing" },
            ShowBox = { Value = true, Default = true },
            ShowNames = { Value = true, Default = true },
            ShowHealth = { Value = true, Default = true },
            GradientEnabled = { Value = false, Default = false },
            FilledEnabled = { Value = false, Default = false },
            FilledTransparency = { Value = 0.5, Default = 0.5 },
            GradientSpeed = { Value = 2, Default = 2 },
            DrawMode = { Value = "2D", Default = "2D" }, -- Новое: режим отрисовки
            BoxStyle = { Value = "Standard", Default = "Standard" }, -- Новое: стиль бокса
            UpdateRate = { Value = 30, Default = 30 } -- Новое: частота обновления
        },
        Elements = {},
        GuiElements = {},
        LastNotificationTime = 0,
        NotificationDelay = 5
    }

    local Cache = { TextBounds = {}, LastGradientUpdate = 0, PlayerCache = {}, LastUpdateTimes = {} }
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
        buttonFrame.Size = UDim2.new(0, 48, 0, 48) -- Увеличиваем для круглого фона
        buttonFrame.Position = currentPos -- Сохраняем текущую позицию
        buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50) -- Более яркий синий
        buttonFrame.BackgroundTransparency = 0.6 -- Более прозрачный фон
        
        -- Круглый фон (как в Default)
        local corner = buttonFrame:FindFirstChild("UICorner")
        if corner then
            corner.CornerRadius = UDim.new(0.5, 0) -- Полностью круглый
        else
            Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)
        end
        
        -- Отдельный фрейм для иконки (круглый контейнер)
        local iconContainer = Instance.new("Frame")
        iconContainer.Name = "IconContainer"
        iconContainer.Size = UDim2.new(0, 40, 0, 40) -- Увеличиваем размер для лучшей видимости
        -- Центрирование: 20 = 40/2
        iconContainer.Position = UDim2.new(0.5, -20, 0.5, -20) -- Идеально по центру
        iconContainer.BackgroundColor3 = Color3.fromRGB(20, 30, 50) -- Яркий синий цвет
        iconContainer.BackgroundTransparency = 0.25 -- Почти непрозрачный
        iconContainer.BorderSizePixel = 0
        iconContainer.Parent = buttonFrame
        
        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0.5, 0) -- Полностью круглый
        iconCorner.Parent = iconContainer
        
        -- Тень/обводка для контейнера
        local uiStroke = Instance.new("UIStroke")
        uiStroke.Color = Color3.fromRGB(20, 30, 60)
        uiStroke.Thickness = 0.2
        uiStroke.Transparency = 0.9
        uiStroke.Parent = iconContainer
        
        -- Создаем новую иконку внутри контейнера
        local newIcon = Instance.new("ImageLabel")
        newIcon.Name = "DefaultV2Icon"
        newIcon.Size = UDim2.new(0, 28, 0, 28) -- Чуть меньше для 40x40 контейнера
        newIcon.Position = UDim2.new(0.5, -14, 0.5, -14) -- Центрируем в контейнере
        newIcon.BackgroundTransparency = 1
        newIcon.Image = "rbxassetid://73279554401260"
        newIcon.ImageColor3 = Color3.fromRGB(255, 255, 255) -- Белая иконка
        newIcon.Parent = iconContainer
        
        -- Локальная переменная для анимации
        local isAnimating = false
        local lastClickTime = 0
        local clickCooldown = 0.4 -- Задержка между кликами для предотвращения спама
        
        -- Функция анимации нажатия
        local function playClickAnimation()
            if isAnimating then return end
            
            isAnimating = true
            local startTime = tick()
            local animationDuration = 0.2
            
            -- Сохраняем оригинальные значения
            local originalSize = iconContainer.Size
            local originalPos = iconContainer.Position
            local originalBackgroundTransparency = iconContainer.BackgroundTransparency
            
            -- Анимация
            while tick() - startTime < animationDuration do
                if State.MenuButton.CurrentDesign ~= "Default v2" then break end
                
                local elapsed = tick() - startTime
                local progress = elapsed / animationDuration
                
                -- Эффект "пульсации" - сначала уменьшение, потом возврат
                local scale
                if progress < 0.5 then
                    scale = 1 - (progress * 0.2) -- Уменьшаем до 80%
                else
                    scale = 0.8 + ((progress - 0.5) * 0.4) -- Возвращаем к 100%
                end
                
                iconContainer.Size = UDim2.new(0, originalSize.X.Offset * scale, 0, originalSize.Y.Offset * scale)
                iconContainer.Position = UDim2.new(
                    0.5, -originalSize.X.Offset * scale / 2,
                    0.5, -originalSize.Y.Offset * scale / 2
                )
                
                -- Легкое изменение прозрачности
                iconContainer.BackgroundTransparency = originalBackgroundTransparency + (progress < 0.5 and progress * 0.1 or (0.1 - (progress - 0.5) * 0.2))
                
                task.wait()
            end
            
            -- Возвращаем к исходному состоянию
            iconContainer.Size = originalSize
            iconContainer.Position = originalPos
            iconContainer.BackgroundTransparency = originalBackgroundTransparency
            
            isAnimating = false
        end
        
        -- Обработчик нажатия для Default v2
        local connection
        connection = buttonFrame.InputBegan:Connect(function(input)
            if State.MenuButton.CurrentDesign == "Default v2" and 
               (input.UserInputType == Enum.UserInputType.MouseButton1 or 
                input.UserInputType == Enum.UserInputType.Touch) then
                
                -- Запускаем анимацию нажатия сразу
                playClickAnimation()
            end
        end)
        
        -- Сохраняем соединение для очистки
        State.MenuButton.DefaultV2Connection = connection
    end

    -- Применяем текущий дизайн
    local function applyDesign(designName)
        -- Очищаем старое соединение если было
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

    -- Изначально применяем дефолтный дизайн
    applyDesign("Default")

    -- Обработка нажатия на кнопку (основная логика)
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

    -- Функции для Watermark остаются без изменений
    -- ... (watermark функции такие же как в предыдущем коде)

    -- Новая ESP система с улучшенной стабильностью и 3D режимом
    local ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "notSPTextGui"
    ESPGui.ResetOnSpawn = false
    ESPGui.IgnoreGuiInset = true
    ESPGui.Parent = RobloxGui

    local supportsQuad = pcall(function()
        local test = Drawing.new("Quad")
        test:Remove()
    end)

    local function createESP(player)
        if ESP.Elements[player] then return end

        local esp = {
            -- 2D элементы
            BoxLines = {
                Top = Drawing.new("Line"),
                Bottom = Drawing.new("Line"),
                Left = Drawing.new("Line"),
                Right = Drawing.new("Line")
            },
            Filled = supportsQuad and Drawing.new("Quad") or Drawing.new("Square"),
            
            -- 3D элементы (для куба)
            CubeLines = {
                -- Передняя грань
                FrontTop = Drawing.new("Line"),
                FrontBottom = Drawing.new("Line"),
                FrontLeft = Drawing.new("Line"),
                FrontRight = Drawing.new("Line"),
                -- Задняя грань
                BackTop = Drawing.new("Line"),
                BackBottom = Drawing.new("Line"),
                BackLeft = Drawing.new("Line"),
                BackRight = Drawing.new("Line"),
                -- Соединяющие линии
                TopConnect = Drawing.new("Line"),
                BottomConnect = Drawing.new("Line"),
                LeftConnect = Drawing.new("Line"),
                RightConnect = Drawing.new("Line")
            },
            
            NameDrawing = Drawing.new("Text"),
            HealthDrawing = Drawing.new("Text"),
            NameGui = nil,
            HealthGui = nil,
            LastPosition = nil,
            LastHealth = nil,
            LastVisible = false,
            LastIsFriend = nil,
            LastFriendsList = nil,
            LastStableSize = Vector2.new(0, 0),
            SizeUpdateTime = 0
        }

        -- Инициализация 2D линий
        for _, line in pairs(esp.BoxLines) do
            line.Thickness = ESP.Settings.Thickness.Value
            line.Transparency = 1 - ESP.Settings.Transparency.Value
            line.Visible = false
        end

        -- Инициализация 3D линий
        for _, line in pairs(esp.CubeLines) do
            line.Thickness = ESP.Settings.Thickness.Value
            line.Transparency = 1 - (ESP.Settings.Transparency.Value * 0.7)
            line.Visible = false
        end

        esp.Filled.Filled = true
        esp.Filled.Transparency = 1 - ESP.Settings.FilledTransparency.Value
        esp.Filled.Visible = false

        esp.NameDrawing.Size = ESP.Settings.TextSize.Value
        esp.NameDrawing.Font = ESP.Settings.TextFont.Value
        esp.NameDrawing.Center = true
        esp.NameDrawing.Outline = true
        esp.NameDrawing.Visible = false

        esp.HealthDrawing.Size = ESP.Settings.TextSize.Value - 2
        esp.HealthDrawing.Font = ESP.Settings.TextFont.Value
        esp.HealthDrawing.Center = true
        esp.HealthDrawing.Outline = true
        esp.HealthDrawing.Visible = false

        if ESP.Settings.TextMethod.Value == "GUI" then
            esp.NameGui = Instance.new("TextLabel")
            esp.NameGui.Size = UDim2.new(0, 200, 0, 20)
            esp.NameGui.BackgroundTransparency = 1
            esp.NameGui.TextSize = ESP.Settings.TextSize.Value
            esp.NameGui.Font = Enum.Font.Gotham
            esp.NameGui.TextColor3 = Color3.fromRGB(255, 255, 255)
            esp.NameGui.TextStrokeTransparency = 0
            esp.NameGui.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            esp.NameGui.TextXAlignment = Enum.TextXAlignment.Center
            esp.NameGui.Visible = false
            esp.NameGui.Parent = ESPGui
            ESP.GuiElements[player] = esp.NameGui

            esp.HealthGui = Instance.new("TextLabel")
            esp.HealthGui.Size = UDim2.new(0, 100, 0, 18)
            esp.HealthGui.BackgroundTransparency = 1
            esp.HealthGui.TextSize = ESP.Settings.TextSize.Value - 2
            esp.HealthGui.Font = Enum.Font.Gotham
            esp.HealthGui.TextColor3 = Color3.fromRGB(255, 255, 255)
            esp.HealthGui.TextStrokeTransparency = 0
            esp.HealthGui.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            esp.HealthGui.TextXAlignment = Enum.TextXAlignment.Center
            esp.HealthGui.Visible = false
            esp.HealthGui.Parent = ESPGui
        end

        ESP.Elements[player] = esp
    end

    local function removeESP(player)
        if not ESP.Elements[player] then return end
        
        -- Удаляем 2D линии
        for _, line in pairs(ESP.Elements[player].BoxLines) do 
            line:Remove() 
        end
        
        -- Удаляем 3D линии
        for _, line in pairs(ESP.Elements[player].CubeLines) do 
            line:Remove() 
        end
        
        ESP.Elements[player].Filled:Remove()
        ESP.Elements[player].NameDrawing:Remove()
        ESP.Elements[player].HealthDrawing:Remove()
        
        if ESP.Elements[player].NameGui then
            ESP.Elements[player].NameGui:Destroy()
            ESP.Elements[player].HealthGui:Destroy()
            ESP.GuiElements[player] = nil
        end
        
        ESP.Elements[player] = nil
        Cache.PlayerCache[player] = nil
        Cache.LastUpdateTimes[player] = nil
    end

    -- Функция для расчета стабильного размера
    local function calculateStableSize(player, currentHeight, esp)
        local currentTime = tick()
        
        -- Если размер не менялся более 0.3 секунды, считаем его стабильным
        if currentTime - esp.SizeUpdateTime > 0.3 then
            esp.LastStableSize = Vector2.new(currentHeight * 0.5, currentHeight)
            esp.SizeUpdateTime = currentTime
        end
        
        -- Плавный переход к новому размеру
        local targetWidth = currentHeight * 0.5
        local targetHeight = currentHeight
        
        -- Используем стабильный размер с небольшим отставанием
        local currentWidth = esp.LastStableSize.X
        local currentStableHeight = esp.LastStableSize.Y
        
        local lerpSpeed = 0.15 -- Скорость перехода (меньше = плавнее)
        local newWidth = currentWidth + (targetWidth - currentWidth) * lerpSpeed
        local newHeight = currentStableHeight + (targetHeight - currentStableHeight) * lerpSpeed
        
        esp.LastStableSize = Vector2.new(newWidth, newHeight)
        
        return newWidth, newHeight
    end

    -- Функция для отрисовки 2D бокса
    local function draw2DBox(esp, topLeft, topRight, bottomLeft, bottomRight, color, character, humanoid)
        -- Основной бокс
        for _, line in pairs(esp.BoxLines) do
            line.Color = color
            line.Thickness = ESP.Settings.Thickness.Value
            line.Transparency = 1 - ESP.Settings.Transparency.Value
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

        -- Заполнение если включено
        if ESP.Settings.FilledEnabled.Value then
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
            esp.Filled.Transparency = 1 - ESP.Settings.FilledTransparency.Value
            esp.Filled.Visible = true
        else
            esp.Filled.Visible = false
        end
        
        -- Скрываем 3D линии
        for _, line in pairs(esp.CubeLines) do
            line.Visible = false
        end
        
        return topLeft, topRight, bottomLeft, bottomRight
    end

    -- Функция для отрисовки 3D куба
    local function draw3DCube(esp, headPos, feetPos, rootPos, width, height, color)
        local depth = width * 0.5 -- Глубина куба
        
        -- Передняя грань (ближняя к камере)
        local frontTopLeft = Vector2.new(rootPos.X - width/2, headPos.Y)
        local frontTopRight = Vector2.new(rootPos.X + width/2, headPos.Y)
        local frontBottomLeft = Vector2.new(rootPos.X - width/2, feetPos.Y)
        local frontBottomRight = Vector2.new(rootPos.X + width/2, feetPos.Y)
        
        -- Задняя грань (дальняя от камеры)
        local backTopLeft = Vector2.new(rootPos.X - width/2 + depth, headPos.Y - depth/2)
        local backTopRight = Vector2.new(rootPos.X + width/2 + depth, headPos.Y - depth/2)
        local backBottomLeft = Vector2.new(rootPos.X - width/2 + depth, feetPos.Y - depth/2)
        local backBottomRight = Vector2.new(rootPos.X + width/2 + depth, feetPos.Y - depth/2)
        
        -- Устанавливаем цвет и толщину для всех линий куба
        for _, line in pairs(esp.CubeLines) do
            line.Color = color
            line.Thickness = ESP.Settings.Thickness.Value
            line.Transparency = 1 - (ESP.Settings.Transparency.Value * 0.7)
            line.Visible = true
        end
        
        -- Передняя грань
        esp.CubeLines.FrontTop.From = frontTopLeft
        esp.CubeLines.FrontTop.To = frontTopRight
        
        esp.CubeLines.FrontBottom.From = frontBottomLeft
        esp.CubeLines.FrontBottom.To = frontBottomRight
        
        esp.CubeLines.FrontLeft.From = frontTopLeft
        esp.CubeLines.FrontLeft.To = frontBottomLeft
        
        esp.CubeLines.FrontRight.From = frontTopRight
        esp.CubeLines.FrontRight.To = frontBottomRight
        
        -- Задняя грань
        esp.CubeLines.BackTop.From = backTopLeft
        esp.CubeLines.BackTop.To = backTopRight
        
        esp.CubeLines.BackBottom.From = backBottomLeft
        esp.CubeLines.BackBottom.To = backBottomRight
        
        esp.CubeLines.BackLeft.From = backTopLeft
        esp.CubeLines.BackLeft.To = backBottomLeft
        
        esp.CubeLines.BackRight.From = backTopRight
        esp.CubeLines.BackRight.To = backBottomRight
        
        -- Соединяющие линии
        esp.CubeLines.TopConnect.From = frontTopLeft
        esp.CubeLines.TopConnect.To = backTopLeft
        
        esp.CubeLines.BottomConnect.From = frontBottomLeft
        esp.CubeLines.BottomConnect.To = backBottomLeft
        
        esp.CubeLines.LeftConnect.From = frontTopLeft
        esp.CubeLines.LeftConnect.To = backTopLeft
        
        esp.CubeLines.RightConnect.From = frontTopRight
        esp.CubeLines.RightConnect.To = backTopRight
        
        -- Скрываем 2D линии
        for _, line in pairs(esp.BoxLines) do
            line.Visible = false
        end
        esp.Filled.Visible = false
        
        return frontTopLeft, frontBottomRight
    end

    local function updateESP()
        if not ESP.Settings.Enabled.Value then
            for _, esp in pairs(ESP.Elements) do
                for _, line in pairs(esp.BoxLines) do line.Visible = false end
                for _, line in pairs(esp.CubeLines) do line.Visible = false end
                esp.Filled.Visible = false
                esp.NameDrawing.Visible = false
                esp.HealthDrawing.Visible = false
                if esp.NameGui then 
                    esp.NameGui.Visible = false 
                    esp.HealthGui.Visible = false
                end
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

        -- Используем фиксированную частоту обновления
        local updateInterval = 1 / ESP.Settings.UpdateRate.Value
        
        for _, player in pairs(Core.Services.Players:GetPlayers()) do
            if player == localPlayer then continue end

            if not ESP.Elements[player] then
                createESP(player)
            end

            local esp = ESP.Elements[player]
            if not esp then continue end

            -- Проверяем время обновления
            if currentTime - (Cache.LastUpdateTimes[player] or 0) < updateInterval then
                continue
            end
            Cache.LastUpdateTimes[player] = currentTime

            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChild("Humanoid")
            local head = character and character:FindFirstChild("Head")

            if not rootPart or not humanoid or humanoid.Health <= 0 then
                if esp.LastVisible then
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    for _, line in pairs(esp.CubeLines) do line.Visible = false end
                    esp.Filled.Visible = false
                    esp.NameDrawing.Visible = false
                    esp.HealthDrawing.Visible = false
                    if esp.NameGui then 
                        esp.NameGui.Visible = false 
                        esp.HealthGui.Visible = false
                    end
                    esp.LastVisible = false
                end
                continue
            end

            local rootPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            if not onScreen then
                if esp.LastVisible then
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    for _, line in pairs(esp.CubeLines) do line.Visible = false end
                    esp.Filled.Visible = false
                    esp.NameDrawing.Visible = false
                    esp.HealthDrawing.Visible = false
                    if esp.NameGui then 
                        esp.NameGui.Visible = false 
                        esp.HealthGui.Visible = false
                    end
                    esp.LastVisible = false
                end
                continue
            end

            esp.LastVisible = true
            esp.LastPosition = rootPos
            esp.LastHealth = humanoid.Health

            -- Стабильное позиционирование
            local headPos = head and camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y / 2 + 0.5, 0)) 
                            or camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2, 0))
            
            local feetPos = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
            
            -- Используем стабильный расчет размера
            local rawHeight = math.abs(headPos.Y - feetPos.Y)
            local width, height = calculateStableSize(player, rawHeight, esp)
            
            width = math.min(width, 100) -- Ограничение максимальной ширины
            height = math.min(height, 200) -- Ограничение максимальной высоты

            local isFriend = esp.LastIsFriend
            if esp.LastFriendsList ~= Core.Services.FriendsList or esp.LastIsFriend == nil then
                isFriend = Core.Services.FriendsList and Core.Services.FriendsList[player.Name:lower()] or false
                esp.LastIsFriend = isFriend
                esp.LastFriendsList = Core.Services.FriendsList
            end

            local baseColor = (isFriend and ESP.Settings.TeamCheck.Value) and ESP.Settings.FriendColor.Value or ESP.Settings.EnemyColor.Value
            local gradColor1, gradColor2 = Core.GradientColors.Color1.Value, (isFriend and ESP.Settings.TeamCheck.Value) and Color3.fromRGB(0, 255, 0) or Core.GradientColors.Color2.Value
            
            local color = baseColor
            if ESP.Settings.GradientEnabled.Value then
                local t = (math.sin(currentTime * ESP.Settings.GradientSpeed.Value * 0.5) + 1) / 2
                color = gradColor1:Lerp(gradColor2, t)
            end

            local topLeft, topRight, bottomLeft, bottomRight
            
            -- Выбираем режим отрисовки
            if ESP.Settings.DrawMode.Value == "3D" and ESP.Settings.ShowBox.Value then
                -- 3D режим
                local frontTopLeft, frontBottomRight = draw3DCube(esp, headPos, feetPos, rootPos, width, height, color)
                topLeft = frontTopLeft
                bottomRight = frontBottomRight
            elseif ESP.Settings.ShowBox.Value then
                -- 2D режим
                topLeft = Vector2.new(rootPos.X - width / 2, headPos.Y)
                topRight = Vector2.new(rootPos.X + width / 2, headPos.Y)
                bottomLeft = Vector2.new(rootPos.X - width / 2, feetPos.Y)
                bottomRight = Vector2.new(rootPos.X + width / 2, feetPos.Y)
                
                draw2DBox(esp, topLeft, topRight, bottomLeft, bottomRight, color, character, humanoid)
            else
                -- Бокс отключен
                for _, line in pairs(esp.BoxLines) do line.Visible = false end
                for _, line in pairs(esp.CubeLines) do line.Visible = false end
                esp.Filled.Visible = false
            end

            -- Отображение имени и здоровья
            if ESP.Settings.ShowNames.Value or ESP.Settings.ShowHealth.Value then
                local nameY = headPos.Y - 25
                local healthY = headPos.Y - 40
                
                if ESP.Settings.ShowNames.Value then
                    if ESP.Settings.TextMethod.Value == "Drawing" then
                        esp.NameDrawing.Text = player.Name
                        esp.NameDrawing.Position = Vector2.new(rootPos.X, nameY)
                        esp.NameDrawing.Color = color
                        esp.NameDrawing.Size = ESP.Settings.TextSize.Value
                        esp.NameDrawing.Font = ESP.Settings.TextFont.Value
                        esp.NameDrawing.Visible = true
                    elseif ESP.Settings.TextMethod.Value == "GUI" and esp.NameGui then
                        esp.NameGui.Text = player.Name
                        esp.NameGui.Position = UDim2.new(0, rootPos.X - 100, 0, nameY)
                        esp.NameGui.TextColor3 = color
                        esp.NameGui.TextSize = ESP.Settings.TextSize.Value
                        esp.NameGui.Font = Enum.Font.Gotham
                        esp.NameGui.Visible = true
                    end
                else
                    esp.NameDrawing.Visible = false
                    if esp.NameGui then esp.NameGui.Visible = false end
                end
                
                if ESP.Settings.ShowHealth.Value then
                    local healthPercent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
                    local healthText = healthPercent .. "%"
                    local healthColor = Color3.fromRGB(
                        255 * (1 - healthPercent/100),
                        255 * (healthPercent/100),
                        0
                    )
                    
                    if ESP.Settings.TextMethod.Value == "Drawing" then
                        esp.HealthDrawing.Text = healthText
                        esp.HealthDrawing.Position = Vector2.new(rootPos.X, healthY)
                        esp.HealthDrawing.Color = healthColor
                        esp.HealthDrawing.Size = ESP.Settings.TextSize.Value - 2
                        esp.HealthDrawing.Font = ESP.Settings.TextFont.Value
                        esp.HealthDrawing.Visible = true
                    elseif ESP.Settings.TextMethod.Value == "GUI" and esp.HealthGui then
                        esp.HealthGui.Text = healthText
                        esp.HealthGui.Position = UDim2.new(0, rootPos.X - 50, 0, healthY)
                        esp.HealthGui.TextColor3 = healthColor
                        esp.HealthGui.TextSize = ESP.Settings.TextSize.Value - 2
                        esp.HealthGui.Font = Enum.Font.Gotham
                        esp.HealthGui.Visible = true
                    end
                else
                    esp.HealthDrawing.Visible = false
                    if esp.HealthGui then esp.HealthGui.Visible = false end
                end
            else
                esp.NameDrawing.Visible = false
                esp.HealthDrawing.Visible = false
                if esp.NameGui then 
                    esp.NameGui.Visible = false 
                    esp.HealthGui.Visible = false
                end
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
    
    -- Используем фиксированный интервал обновления
    local lastUpdate = 0
    Core.Services.RunService.RenderStepped:Connect(function()
        local currentTime = tick()
        if currentTime - lastUpdate >= (1 / ESP.Settings.UpdateRate.Value) then
            updateESP()
            lastUpdate = currentTime
        end
    end)

    if UI.Tabs and UI.Tabs.Visuals then
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
                Name = "Mobile",
                Default = State.MenuButton.Mobile,
                Callback = function(value)
                    State.MenuButton.Mobile = value
                    notify("Menu Button", "Mobile mode " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'MobileMode')
            
            UI.Sections.MenuButton:Dropdown({
                Name = "Design",
                Options = {"Default", "Default v2"},
                Default = "Default",
                Callback = function(value)
                    applyDesign(value)
                    notify("Menu Button", "Design changed to: " .. value, true)
                end
            }, 'MenuButtonDesign')
        end

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

        if UI.Sections and UI.Sections.ESP then
            -- БАЗОВЫЕ НАСТРОЙКИ ESP
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
            
            UI.Sections.ESP:Divider()
            
            -- НАСТРОЙКИ ОТОБРАЖЕНИЯ
            UI.Sections.ESP:Header({ Name = "Display Settings" })
            
            UI.Sections.ESP:Toggle({
                Name = "Show Box",
                Default = ESP.Settings.ShowBox.Default,
                Callback = function(value)
                    ESP.Settings.ShowBox.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Box " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowBoxESP')
            
            UI.Sections.ESP:Toggle({
                Name = "Show Names",
                Default = ESP.Settings.ShowNames.Default,
                Callback = function(value)
                    ESP.Settings.ShowNames.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Names " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowNamesESP')
            
            UI.Sections.ESP:Toggle({
                Name = "Show Health",
                Default = ESP.Settings.ShowHealth.Default,
                Callback = function(value)
                    ESP.Settings.ShowHealth.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Health " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowHealthESP')
            
            UI.Sections.ESP:Toggle({
                Name = "Filled Box",
                Default = ESP.Settings.FilledEnabled.Default,
                Callback = function(value)
                    ESP.Settings.FilledEnabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Filled " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'FilledESP')
            
            UI.Sections.ESP:Toggle({
                Name = "Friend Check",
                Default = ESP.Settings.TeamCheck.Default,
                Callback = function(value)
                    ESP.Settings.TeamCheck.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Friend Check " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'FriendCheckESP')
            
            UI.Sections.ESP:Divider()
            
            -- НАСТРОЙКИ РЕЖИМА ОТРИСОВКИ
            UI.Sections.ESP:Header({ Name = "Render Mode" })
            
            UI.Sections.ESP:Dropdown({
                Name = "Draw Mode",
                Options = {"2D", "3D"},
                Default = ESP.Settings.DrawMode.Default,
                Callback = function(value)
                    ESP.Settings.DrawMode.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Draw Mode set to: " .. value, true)
                    end
                end
            }, 'DrawModeESP')
            
            UI.Sections.ESP:Dropdown({
                Name = "Text Method",
                Options = {"Drawing", "GUI"},
                Default = ESP.Settings.TextMethod.Default,
                Callback = function(value)
                    ESP.Settings.TextMethod.Value = value
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
            }, 'TextMethodESP')
            
            UI.Sections.ESP:Slider({
                Name = "Update Rate",
                Minimum = 10,
                Maximum = 60,
                Default = ESP.Settings.UpdateRate.Default,
                Precision = 0,
                Tooltip = "Higher values = smoother but more CPU usage",
                Callback = function(value)
                    ESP.Settings.UpdateRate.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Update Rate set to: " .. value .. " FPS")
                    end
                end
            }, 'UpdateRateESP')
            
            UI.Sections.ESP:Divider()
            
            -- НАСТРОЙКИ ВНЕШНЕГО ВИДА
            UI.Sections.ESP:Header({ Name = "Appearance Settings" })
            
            UI.Sections.ESP:Colorpicker({
                Name = "Enemy Color",
                Default = ESP.Settings.EnemyColor.Default,
                Callback = function(value)
                    ESP.Settings.EnemyColor.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Enemy Color updated")
                    end
                end
            }, 'EnemyColorESP')
            
            UI.Sections.ESP:Colorpicker({
                Name = "Friend Color",
                Default = ESP.Settings.FriendColor.Default,
                Callback = function(value)
                    ESP.Settings.FriendColor.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Friend Color updated")
                    end
                end
            }, 'FriendColorESP')
            
            UI.Sections.ESP:Slider({
                Name = "Line Thickness",
                Minimum = 1,
                Maximum = 5,
                Default = ESP.Settings.Thickness.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.Thickness.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        for _, line in pairs(esp.BoxLines) do line.Thickness = value end
                        for _, line in pairs(esp.CubeLines) do line.Thickness = value end
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
                Default = ESP.Settings.Transparency.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.Transparency.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        for _, line in pairs(esp.BoxLines) do line.Transparency = 1 - value end
                        for _, line in pairs(esp.CubeLines) do line.Transparency = 1 - (value * 0.7) end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Transparency set to: " .. value)
                    end
                end
            }, 'TransparencyESP')
            
            UI.Sections.ESP:Slider({
                Name = "Filled Transparency",
                Minimum = 0,
                Maximum = 1,
                Default = ESP.Settings.FilledTransparency.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.FilledTransparency.Value = value
                    for _, esp in pairs(ESP.Elements) do 
                        esp.Filled.Transparency = 1 - value 
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Filled Transparency set to: " .. value)
                    end
                end
            }, 'FilledTransparencyESP')
            
            UI.Sections.ESP:Divider()
            
            -- НАСТРОЙКИ ТЕКСТА
            UI.Sections.ESP:Header({ Name = "Text Settings" })
            
            UI.Sections.ESP:Slider({
                Name = "Text Size",
                Minimum = 10,
                Maximum = 30,
                Default = ESP.Settings.TextSize.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.TextSize.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        esp.NameDrawing.Size = value
                        esp.HealthDrawing.Size = value - 2
                        if esp.NameGui then 
                            esp.NameGui.TextSize = value
                            esp.HealthGui.TextSize = value - 2
                        end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Size set to: " .. value)
                    end
                end
            }, 'TextSizeESP')
            
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
                    ESP.Settings.TextFont.Value = fontMap[value] or Drawing.Fonts.Plex
                    for _, esp in pairs(ESP.Elements) do 
                        esp.NameDrawing.Font = ESP.Settings.TextFont.Value 
                        esp.HealthDrawing.Font = ESP.Settings.TextFont.Value
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Font set to: " .. value)
                    end
                end
            }, 'TextFontESP')
            
            UI.Sections.ESP:Divider()
            
            -- ДОПОЛНИТЕЛЬНЫЕ ЭФФЕКТЫ
            UI.Sections.ESP:Header({ Name = "Effects" })
            
            UI.Sections.ESP:Toggle({
                Name = "Gradient Effect",
                Default = ESP.Settings.GradientEnabled.Default,
                Callback = function(value)
                    ESP.Settings.GradientEnabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Gradient " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'GradientESP')
            
            UI.Sections.ESP:Slider({
                Name = "Gradient Speed",
                Minimum = 1,
                Maximum = 5,
                Default = ESP.Settings.GradientSpeed.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.GradientSpeed.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Gradient Speed set to: " .. value)
                    end
                end
            }, 'GradientSpeedESP')
            
            UI.Sections.ESP:Divider()
            
            -- КНОПКА СБРОСА
            UI.Sections.ESP:Button({
                Name = "Reset All ESP Settings",
                Callback = function()
                    -- Сбрасываем все настройки ESP к значениям по умолчанию
                    for settingName, settingData in pairs(ESP.Settings) do
                        if settingData.Default ~= nil then
                            settingData.Value = settingData.Default
                        end
                    end
                    
                    -- Обновляем UI элементы
                    for elementName, element in pairs(UI.Sections.ESP.Elements) do
                        if element.SetValue and ESP.Settings[elementName:gsub("ESP$", "")] then
                            local settingKey = elementName:gsub("ESP$", "")
                            if ESP.Settings[settingKey] then
                                element.SetValue(ESP.Settings[settingKey].Default)
                            end
                        end
                    end
                    
                    notify("ESP", "All settings reset to default", true)
                end
            }, 'ResetESPSettings')
        end
    end
end

return Visuals
