-- Universal UI Library v1.0
-- Автор: Ваше имя/ник
-- Описание: Универсальная библиотека для создания красивого UI с сохранением конфигураций
-- Требования: Эксплойт с функциями readfile, writefile, getcustomasset (опционально)

local UniversalUI = {
    Version = "1.0.0",
    Author = "Custom",
    Configs = {},
    Themes = {},
    Windows = {},
    CurrentTheme = "Dark",
    ConfigPath = "ui_configs/",
    Debug = false
}

-- Вспомогательные функции
local function DeepCopy(tab)
    local copy = {}
    for k, v in pairs(tab) do
        if type(v) == "table" then
            copy[k] = DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function ValidatePath(path)
    return path:gsub("[^%w_%-%.%/]", "_")
end

-- Основной класс окна
UniversalUI.Window = {}
UniversalUI.Window.__index = UniversalUI.Window

function UniversalUI.Window.new(name, options)
    local self = setmetatable({}, UniversalUI.Window)
    
    self.Name = name or "Window"
    self.Size = options.Size or UDim2.new(0, 400, 0, 300)
    self.Position = options.Position or UDim2.new(0.5, -200, 0.5, -150)
    self.Visible = options.Visible ~= false
    self.Minimized = false
    self.Draggable = true
    self.Resizable = options.Resizable or true
    self.Theme = options.Theme or UniversalUI.CurrentTheme
    self.Elements = {}
    self.Config = {}
    
    -- Создание GUI объектов
    self.Gui = Instance.new("ScreenGui")
    self.Gui.Name = ValidatePath("UI_" .. name)
    self.Gui.ResetOnSpawn = false
    self.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Name = "MainFrame"
    self.MainFrame.Size = self.Size
    self.MainFrame.Position = self.Position
    self.MainFrame.BackgroundColor3 = UniversalUI.Themes[self.Theme].Background
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.ClipsDescendants = true
    
    -- Заголовок окна
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 30)
    self.TitleBar.BackgroundColor3 = UniversalUI.Themes[self.Theme].TitleBar
    self.TitleBar.BorderSizePixel = 0
    
    self.TitleLabel = Instance.new("TextLabel")
    self.TitleLabel.Name = "TitleLabel"
    self.TitleLabel.Size = UDim2.new(1, -60, 1, 0)
    self.TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    self.TitleLabel.BackgroundTransparency = 1
    self.TitleLabel.Text = self.Name
    self.TitleLabel.TextColor3 = UniversalUI.Themes[self.Theme].Text
    self.TitleLabel.TextSize = 14
    self.TitleLabel.Font = Enum.Font.SourceSansSemibold
    self.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Кнопки управления
    self.CloseButton = self:CreateButton("X", UDim2.new(0, 30, 0, 30), UDim2.new(1, -30, 0, 0))
    self.MinimizeButton = self:CreateButton("_", UDim2.new(0, 30, 0, 30), UDim2.new(1, -60, 0, 0))
    
    -- Контейнер для элементов
    self.ContentFrame = Instance.new("Frame")
    self.ContentFrame.Name = "ContentFrame"
    self.ContentFrame.Size = UDim2.new(1, 0, 1, -30)
    self.ContentFrame.Position = UDim2.new(0, 0, 0, 30)
    self.ContentFrame.BackgroundTransparency = 1
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 5)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = self.ContentFrame
    
    -- Сборка иерархии
    self.TitleLabel.Parent = self.TitleBar
    self.CloseButton.Parent = self.TitleBar
    self.MinimizeButton.Parent = self.TitleBar
    self.TitleBar.Parent = self.MainFrame
    self.ContentFrame.Parent = self.MainFrame
    self.MainFrame.Parent = self.Gui
    
    -- Обработчики событий
    self:SetupDrag()
    self:SetupEvents()
    
    UniversalUI.Windows[name] = self
    return self
end

function UniversalUI.Window:SetupDrag()
    if not self.Draggable then return end
    
    local dragging = false
    local dragInput, dragStart, startPos
    
    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = self.MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    self.TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            self.MainFrame.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X,
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function UniversalUI.Window:SetupEvents()
    self.CloseButton.MouseButton1Click:Connect(function()
        self:Destroy()
    end)
    
    self.MinimizeButton.MouseButton1Click:Connect(function()
        self:Minimize()
    end)
end

function UniversalUI.Window:CreateButton(text, size, position)
    local button = Instance.new("TextButton")
    button.Name = "Button_" .. text
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = UniversalUI.Themes[self.Theme].Button
    button.TextColor3 = UniversalUI.Themes[self.Theme].Text
    button.Text = text
    button.TextSize = 14
    button.Font = Enum.Font.SourceSans
    button.BorderSizePixel = 0
    
    -- Эффекты при наведении
    button.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(
            button,
            TweenInfo.new(0.2),
            {BackgroundColor3 = UniversalUI.Themes[self.Theme].ButtonHover}
        ):Play()
    end)
    
    button.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(
            button,
            TweenInfo.new(0.2),
            {BackgroundColor3 = UniversalUI.Themes[self.Theme].Button}
        ):Play()
    end)
    
    return button
end

function UniversalUI.Window:AddLabel(text, options)
    options = options or {}
    local label = Instance.new("TextLabel")
    label.Name = "Label_" .. text:gsub("%s+", "_")
    label.Size = options.Size or UDim2.new(1, -20, 0, 20)
    label.Position = options.Position
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = UniversalUI.Themes[self.Theme].Text
    label.TextSize = options.TextSize or 14
    label.Font = options.Font or Enum.Font.SourceSans
    label.TextXAlignment = options.Alignment or Enum.TextXAlignment.Left
    label.LayoutOrder = #self.Elements + 1
    label.Parent = self.ContentFrame
    
    table.insert(self.Elements, {
        Type = "Label",
        Name = label.Name,
        Properties = {
            Text = text,
            TextSize = label.TextSize,
            Alignment = label.TextXAlignment.Name
        }
    })
    
    return label
end

function UniversalUI.Window:AddButton(text, callback, options)
    options = options or {}
    local button = Instance.new("TextButton")
    button.Name = "Button_" .. text:gsub("%s+", "_")
    button.Size = options.Size or UDim2.new(1, -20, 0, 30)
    button.Position = options.Position
    button.BackgroundColor3 = UniversalUI.Themes[self.Theme].Button
    button.TextColor3 = UniversalUI.Themes[self.Theme].Text
    button.Text = text
    button.TextSize = 14
    button.Font = Enum.Font.SourceSans
    button.BorderSizePixel = 0
    button.LayoutOrder = #self.Elements + 1
    button.Parent = self.ContentFrame
    
    -- Закругление углов
    if options.Rounded then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button
    end
    
    button.MouseButton1Click:Connect(callback)
    
    -- Эффекты при наведении
    button.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(
            button,
            TweenInfo.new(0.2),
            {BackgroundColor3 = UniversalUI.Themes[self.Theme].ButtonHover}
        ):Play()
    end)
    
    button.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(
            button,
            TweenInfo.new(0.2),
            {BackgroundColor3 = UniversalUI.Themes[self.Theme].Button}
        ):Play()
    end)
    
    table.insert(self.Elements, {
        Type = "Button",
        Name = button.Name,
        Properties = {
            Text = text,
            Rounded = options.Rounded or false
        },
        Callback = callback
    })
    
    return button
end

function UniversalUI.Window:AddToggle(name, defaultValue, callback, options)
    options = options or {}
    local toggleState = defaultValue or false
    
    local container = Instance.new("Frame")
    container.Name = "Toggle_" .. name:gsub("%s+", "_")
    container.Size = options.Size or UDim2.new(1, -20, 0, 30)
    container.BackgroundTransparency = 1
    container.LayoutOrder = #self.Elements + 1
    container.Parent = self.ContentFrame
    
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = UniversalUI.Themes[self.Theme].Text
    label.TextSize = 14
    label.Font = Enum.Font.SourceSans
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "ToggleFrame"
    toggleFrame.Size = UDim2.new(0, 50, 0, 20)
    toggleFrame.Position = UDim2.new(1, -50, 0.5, -10)
    toggleFrame.AnchorPoint = Vector2.new(1, 0.5)
    toggleFrame.BackgroundColor3 = UniversalUI.Themes[self.Theme].ToggleOff
    toggleFrame.BorderSizePixel = 0
    
    local toggleCircle = Instance.new("Frame")
    toggleCircle.Name = "ToggleCircle"
    toggleCircle.Size = UDim2.new(0, 16, 0, 16)
    toggleCircle.Position = toggleState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    toggleCircle.AnchorPoint = Vector2.new(0, 0.5)
    toggleCircle.BackgroundColor3 = UniversalUI.Themes[self.Theme].ToggleKnob
    toggleCircle.BorderSizePixel = 0
    
    -- Закругления
    local corner1 = Instance.new("UICorner")
    corner1.CornerRadius = UDim.new(0, 10)
    corner1.Parent = toggleFrame
    
    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(1, 0)
    corner2.Parent = toggleCircle
    
    toggleCircle.Parent = toggleFrame
    toggleFrame.Parent = container
    
    local function updateToggle()
        if toggleState then
            toggleFrame.BackgroundColor3 = UniversalUI.Themes[self.Theme].ToggleOn
            game:GetService("TweenService"):Create(
                toggleCircle,
                TweenInfo.new(0.2),
                {Position = UDim2.new(1, -18, 0.5, -8)}
            ):Play()
        else
            toggleFrame.BackgroundColor3 = UniversalUI.Themes[self.Theme].ToggleOff
            game:GetService("TweenService"):Create(
                toggleCircle,
                TweenInfo.new(0.2),
                {Position = UDim2.new(0, 2, 0.5, -8)}
            ):Play()
        end
        callback(toggleState)
    end
    
    toggleFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            toggleState = not toggleState
            updateToggle()
        end
    end)
    
    updateToggle()
    
    table.insert(self.Elements, {
        Type = "Toggle",
        Name = container.Name,
        Properties = {
            Name = name,
            State = toggleState
        },
        Callback = callback
    })
    
    return container
end

function UniversalUI.Window:AddSlider(name, minValue, maxValue, defaultValue, callback, options)
    options = options or {}
    local currentValue = defaultValue or minValue
    
    local container = Instance.new("Frame")
    container.Name = "Slider_" .. name:gsub("%s+", "_")
    container.Size = options.Size or UDim2.new(1, -20, 0, 50)
    container.BackgroundTransparency = 1
    container.LayoutOrder = #self.Elements + 1
    container.Parent = self.ContentFrame
    
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. currentValue
    label.TextColor3 = UniversalUI.Themes[self.Theme].Text
    label.TextSize = 14
    label.Font = Enum.Font.SourceSans
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local sliderTrack = Instance.new("Frame")
    sliderTrack.Name = "SliderTrack"
    sliderTrack.Size = UDim2.new(1, 0, 0, 4)
    sliderTrack.Position = UDim2.new(0, 0, 1, -15)
    sliderTrack.BackgroundColor3 = UniversalUI.Themes[self.Theme].SliderTrack
    sliderTrack.BorderSizePixel = 0
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Size = UDim2.new((currentValue - minValue) / (maxValue - minValue), 0, 1, 0)
    sliderFill.BackgroundColor3 = UniversalUI.Themes[self.Theme].SliderFill
    sliderFill.BorderSizePixel = 0
    
    local sliderKnob = Instance.new("Frame")
    sliderKnob.Name = "SliderKnob"
    sliderKnob.Size = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position = UDim2.new(sliderFill.Size.X.Scale, -8, 0.5, -8)
    sliderKnob.AnchorPoint = Vector2.new(0, 0.5)
    sliderKnob.BackgroundColor3 = UniversalUI.Themes[self.Theme].SliderKnob
    sliderKnob.BorderSizePixel = 0
    
    -- Закругления
    local corner1 = Instance.new("UICorner")
    corner1.CornerRadius = UDim.new(0, 2)
    corner1.Parent = sliderTrack
    
    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(0, 2)
    corner2.Parent = sliderFill
    
    local corner3 = Instance.new("UICorner")
    corner3.CornerRadius = UDim.new(1, 0)
    corner3.Parent = sliderKnob
    
    sliderFill.Parent = sliderTrack
    sliderTrack.Parent = container
    sliderKnob.Parent = container
    
    local dragging = false
    
    local function updateSlider(value)
        currentValue = math.clamp(value, minValue, maxValue)
        local ratio = (currentValue - minValue) / (maxValue - minValue)
        
        sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
        sliderKnob.Position = UDim2.new(ratio, -8, 0.5, -8)
        label.Text = name .. ": " .. math.floor(currentValue * 100) / 100
        
        callback(currentValue)
    end
    
    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local xPos = input.Position.X - sliderTrack.AbsolutePosition.X
            local ratio = math.clamp(xPos / sliderTrack.AbsoluteSize.X, 0, 1)
            updateSlider(minValue + ratio * (maxValue - minValue))
        end
    end)
    
    sliderTrack.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local xPos = input.Position.X - sliderTrack.AbsolutePosition.X
            local ratio = math.clamp(xPos / sliderTrack.AbsoluteSize.X, 0, 1)
            updateSlider(minValue + ratio * (maxValue - minValue))
        end
    end)
    
    table.insert(self.Elements, {
        Type = "Slider",
        Name = container.Name,
        Properties = {
            Name = name,
            Min = minValue,
            Max = maxValue,
            Value = currentValue
        },
        Callback = callback
    })
    
    return container
end

function UniversalUI.Window:AddDropdown(name, options, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Name = "Dropdown_" .. name:gsub("%s+", "_")
    container.Size = UDim2.new(1, -20, 0, 30)
    container.BackgroundTransparency = 1
    container.LayoutOrder = #self.Elements + 1
    container.ClipsDescendants = true
    container.Parent = self.ContentFrame
    
    local currentOption = defaultValue or options[1]
    local isOpen = false
    
    local mainButton = Instance.new("TextButton")
    mainButton.Name = "MainButton"
    mainButton.Size = UDim2.new(1, 0, 0, 30)
    mainButton.BackgroundColor3 = UniversalUI.Themes[self.Theme].Dropdown
    mainButton.TextColor3 = UniversalUI.Themes[self.Theme].Text
    mainButton.Text = name .. ": " .. currentOption
    mainButton.TextSize = 14
    mainButton.Font = Enum.Font.SourceSans
    mainButton.BorderSizePixel = 0
    mainButton.TextXAlignment = Enum.TextXAlignment.Left
    
    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -20, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.TextColor3 = UniversalUI.Themes[self.Theme].Text
    arrow.TextSize = 12
    arrow.Font = Enum.Font.SourceSans
    
    arrow.Parent = mainButton
    mainButton.Parent = container
    
    local optionsFrame = Instance.new("Frame")
    optionsFrame.Name = "OptionsFrame"
    optionsFrame.Size = UDim2.new(1, 0, 0, 0)
    optionsFrame.Position = UDim2.new(0, 0, 0, 30)
    optionsFrame.BackgroundColor3 = UniversalUI.Themes[self.Theme].Dropdown
    optionsFrame.BorderSizePixel = 0
    optionsFrame.Visible = false
    
    local optionsList = Instance.new("UIListLayout")
    optionsList.Padding = UDim.new(0, 1)
    optionsList.SortOrder = Enum.SortOrder.LayoutOrder
    optionsList.Parent = optionsFrame
    
    for i, option in ipairs(options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Name = "Option_" .. option
        optionButton.Size = UDim2.new(1, 0, 0, 25)
        optionButton.BackgroundColor3 = UniversalUI.Themes[self.Theme].DropdownOption
        optionButton.TextColor3 = UniversalUI.Themes[self.Theme].Text
        optionButton.Text = option
        optionButton.TextSize = 12
        optionButton.Font = Enum.Font.SourceSans
        optionButton.BorderSizePixel = 0
        optionButton.LayoutOrder = i
        
        optionButton.MouseButton1Click:Connect(function()
            currentOption = option
            mainButton.Text = name .. ": " .. currentOption
            callback(currentOption)
            toggleDropdown()
        end)
        
        optionButton.Parent = optionsFrame
    end
    
    optionsFrame.Parent = container
    
    local function toggleDropdown()
        isOpen = not isOpen
        optionsFrame.Visible = isOpen
        
        if isOpen then
            optionsFrame.Size = UDim2.new(1, 0, 0, #options * 25 + (#options - 1))
            container.Size = UDim2.new(1, -20, 0, 30 + #options * 25 + (#options - 1))
            arrow.Text = "▲"
        else
            optionsFrame.Size = UDim2.new(1, 0, 0, 0)
            container.Size = UDim2.new(1, -20, 0, 30)
            arrow.Text = "▼"
        end
    end
    
    mainButton.MouseButton1Click:Connect(toggleDropdown)
    
    table.insert(self.Elements, {
        Type = "Dropdown",
        Name = container.Name,
        Properties = {
            Name = name,
            Options = options,
            Selected = currentOption
        },
        Callback = callback
    })
    
    return container
end

function UniversalUI.Window:Minimize()
    self.Minimized = not self.Minimized
    if self.Minimized then
        self.ContentFrame.Visible = false
        self.MainFrame.Size = UDim2.new(self.MainFrame.Size.X, UDim.new(0, 30))
        self.MinimizeButton.Text = "+"
    else
        self.ContentFrame.Visible = true
        self.MainFrame.Size = self.Size
        self.MinimizeButton.Text = "_"
    end
end

function UniversalUI.Window:Show()
    self.Gui.Parent = game:GetService("CoreGui")
    self.Visible = true
end

function UniversalUI.Window:Hide()
    self.Gui.Parent = nil
    self.Visible = false
end

function UniversalUI.Window:Destroy()
    self.Gui:Destroy()
    UniversalUI.Windows[self.Name] = nil
end

function UniversalUI.Window:SaveConfig(configName)
    local config = {
        Window = {
            Name = self.Name,
            Size = {self.Size.X.Scale, self.Size.X.Offset, self.Size.Y.Scale, self.Size.Y.Offset},
            Position = {self.Position.X.Scale, self.Position.X.Offset, self.Position.Y.Scale, self.Position.Y.Offset},
            Minimized = self.Minimized,
            Theme = self.Theme
        },
        Elements = {}
    }
    
    for _, element in ipairs(self.Elements) do
        table.insert(config.Elements, DeepCopy(element))
    end
    
    local jsonConfig = game:GetService("HttpService"):JSONEncode(config)
    
    if writefile then
        local path = UniversalUI.ConfigPath .. ValidatePath(configName) .. ".json"
        writefile(path, jsonConfig)
        print("Конфиг сохранен: " .. path)
    else
        UniversalUI.Configs[configName] = config
        print("Конфиг сохранен в памяти: " .. configName)
    end
end

function UniversalUI.Window:LoadConfig(configName)
    local config
    
    if readfile then
        local path = UniversalUI.ConfigPath .. ValidatePath(configName) .. ".json"
        if isfile and isfile(path) then
            local success, result = pcall(function()
                return game:GetService("HttpService"):JSONDecode(readfile(path))
            end)
            if success then
                config = result
            end
        end
    else
        config = UniversalUI.Configs[configName]
    end
    
    if config then
        -- Восстановление состояния окна
        if config.Window then
            self.MainFrame.Size = UDim2.new(
                config.Window.Size[1], config.Window.Size[2],
                config.Window.Size[3], config.Window.Size[4]
            )
            self.Position = UDim2.new(
                config.Window.Position[1], config.Window.Position[2],
                config.Window.Position[3], config.Window.Position[4]
            )
            self.Theme = config.Window.Theme or self.Theme
            self:ApplyTheme()
            
            if config.Window.Minimized then
                self:Minimize()
            end
        end
        
        -- Восстановление элементов
        if config.Elements then
            for _, savedElement in ipairs(config.Elements) do
                for _, currentElement in ipairs(self.Elements) do
                    if currentElement.Name == savedElement.Name then
                        if currentElement.Type == "Toggle" and savedElement.Properties.State ~= nil then
                            -- Для тогглов нужно вызвать callback
                            if currentElement.Callback then
                                currentElement.Callback(savedElement.Properties.State)
                            end
                        elseif currentElement.Type == "Slider" and savedElement.Properties.Value ~= nil then
                            if currentElement.Callback then
                                currentElement.Callback(savedElement.Properties.Value)
                            end
                        elseif currentElement.Type == "Dropdown" and savedElement.Properties.Selected ~= nil then
                            if currentElement.Callback then
                                currentElement.Callback(savedElement.Properties.Selected)
                            end
                        end
                    end
                end
            end
        end
        
        print("Конфиг загружен: " .. configName)
        return true
    end
    
    print("Конфиг не найден: " .. configName)
    return false
end

function UniversalUI.Window:ApplyTheme()
    local theme = UniversalUI.Themes[self.Theme]
    
    self.MainFrame.BackgroundColor3 = theme.Background
    self.TitleBar.BackgroundColor3 = theme.TitleBar
    self.TitleLabel.TextColor3 = theme.Text
    
    -- Обновление всех элементов
    for _, child in ipairs(self.Gui:GetDescendants()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            if child.Name:find("Button") then
                child.BackgroundColor3 = theme.Button
                child.TextColor3 = theme.Text
            elseif child.Name:find("Toggle") then
                -- Логика обновления тогглов
            end
        end
    end
end

-- Инициализация библиотеки
function UniversalUI.Init()
    -- Стандартные темы
    UniversalUI.Themes["Dark"] = {
        Background = Color3.fromRGB(30, 30, 40),
        TitleBar = Color3.fromRGB(50, 50, 60),
        Text = Color3.fromRGB(220, 220, 220),
        Button = Color3.fromRGB(70, 70, 80),
        ButtonHover = Color3.fromRGB(90, 90, 100),
        ToggleOn = Color3.fromRGB(0, 170, 255),
        ToggleOff = Color3.fromRGB(60, 60, 70),
        ToggleKnob = Color3.fromRGB(240, 240, 240),
        SliderTrack = Color3.fromRGB(60, 60, 70),
        SliderFill = Color3.fromRGB(0, 170, 255),
        SliderKnob = Color3.fromRGB(240, 240, 240),
        Dropdown = Color3.fromRGB(70, 70, 80),
        DropdownOption = Color3.fromRGB(60, 60, 70)
    }
    
    UniversalUI.Themes["Light"] = {
        Background = Color3.fromRGB(240, 240, 240),
        TitleBar = Color3.fromRGB(220, 220, 220),
        Text = Color3.fromRGB(30, 30, 30),
        Button = Color3.fromRGB(200, 200, 210),
        ButtonHover = Color3.fromRGB(180, 180, 190),
        ToggleOn = Color3.fromRGB(0, 150, 255),
        ToggleOff = Color3.fromRGB(180, 180, 190),
        ToggleKnob = Color3.fromRGB(250, 250, 250),
        SliderTrack = Color3.fromRGB(200, 200, 210),
        SliderFill = Color3.fromRGB(0, 150, 255),
        SliderKnob = Color3.fromRGB(250, 250, 250),
        Dropdown = Color3.fromRGB(220, 220, 220),
        DropdownOption = Color3.fromRGB(200, 200, 210)
    }
    
    UniversalUI.Themes["Blue"] = {
        Background = Color3.fromRGB(25, 35, 50),
        TitleBar = Color3.fromRGB(40, 60, 90),
        Text = Color3.fromRGB(220, 230, 240),
        Button = Color3.fromRGB(50, 80, 120),
        ButtonHover = Color3.fromRGB(70, 100, 140),
        ToggleOn = Color3.fromRGB(0, 200, 255),
        ToggleOff = Color3.fromRGB(40, 60, 80),
        ToggleKnob = Color3.fromRGB(240, 240, 240),
        SliderTrack = Color3.fromRGB(40, 60, 80),
        SliderFill = Color3.fromRGB(0, 200, 255),
        SliderKnob = Color3.fromRGB(240, 240, 240),
        Dropdown = Color3.fromRGB(50, 70, 100),
        DropdownOption = Color3.fromRGB(40, 60, 80)
    }
    
    print(string.format("Universal UI Library v%s инициализирована", UniversalUI.Version))
    return UniversalUI
end

-- Экспорт библиотеки
return UniversalUI.Init()