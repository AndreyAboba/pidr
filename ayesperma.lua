-- Ball Trajectory Visualizer v7 — Интегрированная версия с лоадером
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Модуль визуализации траектории
local TrajectoryVisualizer = {}

-- Конфигурация по умолчанию
TrajectoryVisualizer.Config = {
    Enabled = true,
    UseRaycast = true,
    VisualFPS = 60,
    
    -- Prediction
    PredSteps = 320,
    CurveMult = 38,
    DT = 1/60,
    Gravity = 110,
    Drag = 0.988,
    BounceXZ = 0.76,
    BounceY = 0.72,
    CurveFadeRate = 0.06,
    
    -- Raycast Settings
    RaycastLengthMult = 1.8,
    MinHitDistance = 0.05,
    
    -- Visual Settings
    MaxDrawDistance = 100,
    VisualSmoothness = 0.85,
    
    -- Performance
    PredUpdateMinVel = 15,
    MinTimeBetweenPred = 0.033,
    
    -- Colors
    TrajectoryColor = Color3.fromRGB(0, 150, 255),
    EndpointColor = Color3.fromRGB(255, 230, 0)
}

-- Статус
TrajectoryVisualizer.Status = {
    Running = false,
    RenderConnection = nil,
    InputConnection = nil,
    TrajLines = {},
    EndpointLines = {},
    
    -- Кэшированные данные
    CachedPoints = nil,
    CachedEndpoint = nil,
    LastBallVelMag = 0,
    LastPredictionTime = 0,
    LastBallPos = Vector3.zero,
    LastRenderTime = 0,
    RenderDelta = 1/60
}

-- Инициализация
function TrajectoryVisualizer.Init(UI, coreParam, notifyFunc)
    TrajectoryVisualizer.Core = coreParam
    TrajectoryVisualizer.Services = coreParam.Services
    TrajectoryVisualizer.PlayerData = coreParam.PlayerData
    TrajectoryVisualizer.Notify = notifyFunc
    
    -- Создание визуальных элементов
    TrajectoryVisualizer:InitializeVisuals()
    
    -- Настройка UI
    TrajectoryVisualizer:SetupUI(UI)
    
    -- Запуск, если включено
    if TrajectoryVisualizer.Config.Enabled then
        TrajectoryVisualizer.Start()
    end
end

-- Инициализация визуальных элементов
function TrajectoryVisualizer:InitializeVisuals()
    -- Очистка старых элементов
    self:ClearAllVisuals()
    
    -- Создание линий для endpoint (32 линии для плавности)
    self.Status.EndpointLines = {}
    for i = 1, 32 do
        local line = Drawing.new("Line")
        line.Thickness = 2.6
        line.Color = self.Config.EndpointColor
        line.Transparency = 0.55
        self.Status.EndpointLines[i] = line
    end
    
    -- Создание линий траектории с градиентом
    self.Status.TrajLines = {}
    for i = 1, self.Config.PredSteps do
        local line = Drawing.new("Line")
        line.Thickness = 2.0
        -- Плавный градиент
        local hue = (i / self.Config.PredSteps) * 0.7
        line.Color = Color3.fromHSV(hue, 0.85, 0.95)
        line.Transparency = 0.4 + (i / self.Config.PredSteps) * 0.3
        self.Status.TrajLines[i] = line
    end
    
    -- Кэш для игнорируемых моделей
    self.Status.IgnoredModels = {}
    self:InitIgnoredModels()
end

-- Инициализация игнорируемых моделей
function TrajectoryVisualizer:InitIgnoredModels()
    self.Status.IgnoredModels = {}
    
    local homePos = Workspace:FindFirstChild("HomePosition")
    local awayPos = Workspace:FindFirstChild("AwayPosition")
    
    if homePos and homePos:IsA("Model") then
        table.insert(self.Status.IgnoredModels, homePos)
    end
    if awayPos and awayPos:IsA("Model") then
        table.insert(self.Status.IgnoredModels, awayPos)
    end
end

-- Очистка визуальных элементов
function TrajectoryVisualizer:ClearAllVisuals()
    for _, line in pairs(self.Status.TrajLines or {}) do
        if line and line.Remove then
            line.Visible = false
        end
    end
    
    for _, line in pairs(self.Status.EndpointLines or {}) do
        if line and line.Remove then
            line.Visible = false
        end
    end
    
    self.Status.CachedPoints = nil
    self.Status.CachedEndpoint = nil
end

-- Проверка игнорирования части
function TrajectoryVisualizer:ShouldIgnorePart(part)
    if not part or not part:IsA("BasePart") then
        return true
    end
    
    -- Проверка принадлежности к игнорируемым моделям
    for _, model in ipairs(self.Status.IgnoredModels or {}) do
        if part:IsDescendantOf(model) then
            return true
        end
    end
    
    -- Проверка прозрачности
    if part.Transparency > 0.9 then
        return true
    end
    
    -- Игнорирование декоративных объектов
    if part.Name:find("Decal") or part.Name:find("Texture") then
        return true
    end
    
    -- Проверка CanCollide
    return not part.CanCollide
end

-- Плавная отрисовка endpoint
function TrajectoryVisualizer:DrawSmoothEndpoint(pos)
    local endpointLines = self.Status.EndpointLines
    if not endpointLines or not pos then
        for _, line in pairs(endpointLines or {}) do
            if line then line.Visible = false end
        end
        return
    end
    
    local cam = Workspace.CurrentCamera
    if not cam then return end
    
    local step = (math.pi * 2) / 32
    local offsetY = math.sin(tick() * 2) * 0.3
    local radius = 3.8
    
    for i = 1, 32 do
        local line = endpointLines[i]
        if not line then continue end
        
        local angle1 = (i-1) * step
        local angle2 = i * step
        
        local p1 = pos + Vector3.new(
            math.cos(angle1) * radius,
            offsetY,
            math.sin(angle1) * radius
        )
        
        local p2 = pos + Vector3.new(
            math.cos(angle2) * radius,
            offsetY,
            math.sin(angle2) * radius
        )
        
        local screen1 = cam:WorldToViewportPoint(p1)
        local screen2 = cam:WorldToViewportPoint(p2)
        
        if screen1.Z > 0 and screen2.Z > 0 then
            line.From = Vector2.new(screen1.X, screen1.Y)
            line.To = Vector2.new(screen2.X, screen2.Y)
            line.Visible = true
        else
            line.Visible = false
        end
    end
end

-- Предсказание траектории
function TrajectoryVisualizer:PredictTrajectory(ball)
    local points = {}
    local pos, vel = ball.Position, ball.Velocity
    
    if vel.Magnitude < 8 then
        return {pos}
    end
    
    local cfg = self.Config
    local dt = cfg.DT
    local gravity = Vector3.new(0, -cfg.Gravity, 0)
    local drag = cfg.Drag
    
    -- Эффекты спина
    local spinEffect = Vector3.new(0, 0, 0)
    pcall(function()
        if Workspace.Bools and Workspace.Bools.Curve and Workspace.Bools.Curve.Value then
            spinEffect = ball.CFrame.RightVector * cfg.CurveMult * 0.025
        end
        if Workspace.Bools and Workspace.Bools.Header and Workspace.Bools.Header.Value then
            spinEffect = spinEffect + Vector3.new(0, 22, 0)
        end
    end)
    
    -- Параметры Raycast
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true
    rayParams.IgnoreWater = true
    
    local maxBounces = 4
    local bounceCount = 0
    local pointIndex = 0
    
    for step = 1, cfg.PredSteps do
        -- Добавление точки
        if step % 4 == 1 or step == 1 then
            pointIndex = pointIndex + 1
            points[pointIndex] = pos
        end
        
        -- Обновление скорости
        local spinMultiplier = math.max(0, 1 - (step / cfg.PredSteps) * cfg.CurveFadeRate)
        spinMultiplier = spinMultiplier * math.clamp(vel.Magnitude / 80, 0.3, 1)
        
        vel = vel * drag + (spinEffect * spinMultiplier * dt)
        vel = vel + (gravity * dt)
        
        -- Рассчет новой позиции
        local newPos = pos + (vel * dt)
        local rayDirection = newPos - pos
        
        if cfg.UseRaycast and rayDirection.Magnitude > cfg.MinHitDistance then
            rayParams.FilterDescendantsInstances = {ball}
            
            local rayResult = Workspace:Raycast(
                pos,
                rayDirection.Unit * rayDirection.Magnitude * cfg.RaycastLengthMult,
                rayParams
            )
            
            if rayResult and rayResult.Instance then
                if not self:ShouldIgnorePart(rayResult.Instance) then
                    local normal = rayResult.Normal
                    local hitPos = rayResult.Position
                    
                    pos = hitPos + (normal * 0.05)
                    
                    local normalDot = vel:Dot(normal)
                    if normalDot < 0 then
                        vel = vel - (normal * normalDot * 2.1)
                        vel = vel * 0.74
                        
                        bounceCount = bounceCount + 1
                        if bounceCount >= maxBounces then
                            vel = vel * 0.4
                        end
                    else
                        pos = newPos
                    end
                else
                    pos = newPos
                end
            else
                pos = newPos
            end
        else
            pos = newPos
        end
        
        -- Столкновение с землей
        if pos.Y < 0.3 then
            pos = Vector3.new(pos.X, 0.3, pos.Z)
            
            if math.abs(vel.Y) > 4 then
                vel = Vector3.new(
                    vel.X * cfg.BounceXZ,
                    math.abs(vel.Y) * cfg.BounceY,
                    vel.Z * cfg.BounceXZ
                )
                bounceCount = bounceCount + 1
                
                pointIndex = pointIndex + 1
                points[pointIndex] = pos
            else
                vel = Vector3.new(vel.X * 0.4, 0, vel.Z * 0.4)
                
                if vel.Magnitude < 2 then
                    pointIndex = pointIndex + 1
                    points[pointIndex] = pos
                    break
                end
            end
        end
        
        -- Остановка при выходе за пределы
        if pos.Y > 200 or pos.Magnitude > 500 then
            break
        end
    end
    
    return points
end

-- Плавная отрисовка траектории
function TrajectoryVisualizer:RenderSmoothTrajectory(points)
    if not points or #points < 2 then
        self:ClearAllVisuals()
        return
    end
    
    local cam = Workspace.CurrentCamera
    if not cam then return end
    
    local ball = Workspace:FindFirstChild("ball")
    if not ball then return end
    
    local timeOffset = tick() * 0.5
    local pulse = 0.5 + math.sin(timeOffset) * 0.3
    local visibleLines = 0
    local lastScreenPos = nil
    
    for i = 1, math.min(#points - 1, #self.Status.TrajLines) do
        local line = self.Status.TrajLines[i]
        if not line then continue end
        
        local point1 = points[i]
        local point2 = points[i + 1]
        
        -- Проверка расстояния до мяча
        if (point1 - ball.Position).Magnitude > self.Config.MaxDrawDistance then
            line.Visible = false
            break
        end
        
        local screenPos1 = cam:WorldToViewportPoint(point1)
        local screenPos2 = cam:WorldToViewportPoint(point2)
        
        if screenPos1.Z > 0 and screenPos2.Z > 0 then
            local fromPos, toPos
            if lastScreenPos then
                local smoothness = self.Config.VisualSmoothness
                fromPos = Vector2.new(
                    lastScreenPos.X * (1 - smoothness) + screenPos1.X * smoothness,
                    lastScreenPos.Y * (1 - smoothness) + screenPos1.Y * smoothness
                )
            else
                fromPos = Vector2.new(screenPos1.X, screenPos1.Y)
            end
            
            toPos = Vector2.new(screenPos2.X, screenPos2.Y)
            
            line.From = fromPos
            line.To = toPos
            line.Visible = true
            
            -- Динамическая толщина
            local distanceFactor = 1 - (i / #self.Status.TrajLines) * 0.7
            line.Thickness = 1.8 + (distanceFactor * pulse * 0.8)
            
            visibleLines = visibleLines + 1
            lastScreenPos = screenPos2
        else
            line.Visible = false
            lastScreenPos = nil
        end
    end
    
    -- Скрытие неиспользованных линий
    for i = visibleLines + 1, #self.Status.TrajLines do
        local line = self.Status.TrajLines[i]
        if line then
            line.Visible = false
        end
    end
    
    -- Отрисовка endpoint
    if visibleLines > 3 and points[#points] then
        self:DrawSmoothEndpoint(points[#points])
        self.Status.CachedEndpoint = points[#points]
    else
        self:DrawSmoothEndpoint(nil)
        self.Status.CachedEndpoint = nil
    end
end

-- Главный цикл рендеринга
function TrajectoryVisualizer.RenderLoop()
    local self = TrajectoryVisualizer
    local status = self.Status
    
    if not self.Config.Enabled then
        if status.TrajLines[1] and status.TrajLines[1].Visible then
            self:ClearAllVisuals()
        end
        return
    end
    
    -- Обновление времени рендеринга
    local currentTime = tick()
    local timeSinceLastRender = currentTime - status.LastRenderTime
    status.LastRenderTime = currentTime
    status.RenderDelta = math.min(timeSinceLastRender, 1/30)
    
    local ball = Workspace:FindFirstChild("ball")
    if not ball then
        if status.CachedPoints then
            self:ClearAllVisuals()
            status.CachedPoints = nil
            status.CachedEndpoint = nil
        end
        return
    end
    
    -- Проверка состояния мяча
    local hasWeld = ball:FindFirstChild("playerWeld")
    local owner = ball:FindFirstChild("creator") and ball.creator.Value
    local isShot = not hasWeld and owner
    local ballVel = ball.Velocity
    local ballSpeed = ballVel.Magnitude
    
    -- Детект нового удара
    if ballSpeed > 20 and status.LastBallVelMag <= 20 then
        status.CachedPoints = nil
        self:ClearAllVisuals()
    end
    status.LastBallVelMag = ballSpeed
    
    -- Обновление предикта
    if isShot and ballSpeed > self.Config.PredUpdateMinVel then
        local shouldUpdate = false
        
        if not status.CachedPoints then
            shouldUpdate = true
        elseif (ball.Position - status.LastBallPos).Magnitude > 0.3 then
            local timeSinceLastPred = currentTime - status.LastPredictionTime
            if timeSinceLastPred > self.Config.MinTimeBetweenPred then
                shouldUpdate = true
            end
        end
        
        if shouldUpdate then
            status.CachedPoints = self:PredictTrajectory(ball)
            status.LastPredictionTime = currentTime
            status.LastBallPos = ball.Position
        end
    elseif status.CachedPoints then
        status.CachedPoints = nil
        status.CachedEndpoint = nil
        self:ClearAllVisuals()
    end
    
    -- Отрисовка
    if status.CachedPoints and #status.CachedPoints > 1 then
        self:RenderSmoothTrajectory(status.CachedPoints)
    else
        self:ClearAllVisuals()
    end
end

-- Запуск визуализатора
function TrajectoryVisualizer.Start()
    if TrajectoryVisualizer.Status.Running then return end
    
    TrajectoryVisualizer.Status.Running = true
    
    -- Подписка на рендер
    TrajectoryVisualizer.Status.RenderConnection = RunService.RenderStepped:Connect(function()
        pcall(TrajectoryVisualizer.RenderLoop)
    end)
    
    -- Подписка на ввод
    TrajectoryVisualizer.Status.InputConnection = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Insert then
            TrajectoryVisualizer.Config.Enabled = not TrajectoryVisualizer.Config.Enabled
            if not TrajectoryVisualizer.Config.Enabled then
                TrajectoryVisualizer:ClearAllVisuals()
                TrajectoryVisualizer.Status.CachedPoints = nil
                TrajectoryVisualizer.Status.CachedEndpoint = nil
            end
            TrajectoryVisualizer.Notify("Trajectory", "Визуализация " .. (TrajectoryVisualizer.Config.Enabled and "ВКЛ" or "ВЫКЛ"), true)
        elseif input.KeyCode == Enum.KeyCode.R then
            TrajectoryVisualizer.Config.UseRaycast = not TrajectoryVisualizer.Config.UseRaycast
            TrajectoryVisualizer.Status.CachedPoints = nil
            TrajectoryVisualizer.Notify("Trajectory", "Raycast: " .. (TrajectoryVisualizer.Config.UseRaycast and "ВКЛ" or "ВЫКЛ"), true)
        end
    end)
    
    TrajectoryVisualizer.Notify("Trajectory", "Запущена визуализация траектории", true)
end

-- Остановка визуализатора
function TrajectoryVisualizer.Stop()
    if TrajectoryVisualizer.Status.RenderConnection then
        TrajectoryVisualizer.Status.RenderConnection:Disconnect()
        TrajectoryVisualizer.Status.RenderConnection = nil
    end
    
    if TrajectoryVisualizer.Status.InputConnection then
        TrajectoryVisualizer.Status.InputConnection:Disconnect()
        TrajectoryVisualizer.Status.InputConnection = nil
    end
    
    TrajectoryVisualizer:ClearAllVisuals()
    TrajectoryVisualizer.Status.Running = false
    
    TrajectoryVisualizer.Notify("Trajectory", "Визуализация траектории остановлена", true)
end

-- Настройка UI
function TrajectoryVisualizer:SetupUI(UI)
    -- Секция Trajectory Prediction
    if UI.Tabs.Main:Section then
        local trajSection = UI.Tabs.Main:Section({
            Name = "Trajectory Prediction",
            Side = "Left"
        })
        
        trajSection:Header({ Name = "Trajectory Visualizer v7" })
        trajSection:Divider()
        
        -- Основные настройки
        self.UIElements = {}
        self.UIElements.Enabled = trajSection:Toggle({
            Name = "Enabled",
            Default = self.Config.Enabled,
            Callback = function(value)
                self.Config.Enabled = value
                if value then
                    self.Start()
                else
                    self.Stop()
                end
            end
        }, "TrajectoryEnabled")
        
        self.UIElements.UseRaycast = trajSection:Toggle({
            Name = "Use Raycast",
            Default = self.Config.UseRaycast,
            Callback = function(value)
                self.Config.UseRaycast = value
            end
        }, "TrajectoryRaycast")
        
        trajSection:Divider()
        
        -- Настройки предсказания
        trajSection:Header({ Name = "Prediction Settings" })
        
        self.UIElements.PredSteps = trajSection:Slider({
            Name = "Prediction Steps",
            Minimum = 50,
            Maximum = 500,
            Default = self.Config.PredSteps,
            Precision = 0,
            Callback = function(value)
                self.Config.PredSteps = value
                -- Пересоздаем линии с новым количеством
                self:InitializeVisuals()
            end
        }, "TrajectoryPredSteps")
        
        self.UIElements.CurveMult = trajSection:Slider({
            Name = "Curve Multiplier",
            Minimum = 10,
            Maximum = 100,
            Default = self.Config.CurveMult,
            Precision = 0,
            Callback = function(value)
                self.Config.CurveMult = value
            end
        }, "TrajectoryCurveMult")
        
        self.UIElements.Gravity = trajSection:Slider({
            Name = "Gravity",
            Minimum = 50,
            Maximum = 200,
            Default = self.Config.Gravity,
            Precision = 0,
            Callback = function(value)
                self.Config.Gravity = value
            end
        }, "TrajectoryGravity")
        
        self.UIElements.Drag = trajSection:Slider({
            Name = "Drag",
            Minimum = 0.9,
            Maximum = 1.0,
            Default = self.Config.Drag,
            Precision = 3,
            Callback = function(value)
                self.Config.Drag = value
            end
        }, "TrajectoryDrag")
        
        trajSection:Divider()
        
        -- Настройки визуализации
        trajSection:Header({ Name = "Visual Settings" })
        
        self.UIElements.MaxDrawDistance = trajSection:Slider({
            Name = "Max Draw Distance",
            Minimum = 50,
            Maximum = 300,
            Default = self.Config.MaxDrawDistance,
            Precision = 0,
            Callback = function(value)
                self.Config.MaxDrawDistance = value
            end
        }, "TrajectoryMaxDistance")
        
        self.UIElements.VisualSmoothness = trajSection:Slider({
            Name = "Visual Smoothness",
            Minimum = 0.5,
            Maximum = 1.0,
            Default = self.Config.VisualSmoothness,
            Precision = 2,
            Callback = function(value)
                self.Config.VisualSmoothness = value
            end
        }, "TrajectorySmoothness")
        
        trajSection:Divider()
        
        -- Настройки цветов
        trajSection:Header({ Name = "Color Settings" })
        
        self.UIElements.TrajectoryColor = trajSection:Colorpicker({
            Name = "Trajectory Color",
            Default = self.Config.TrajectoryColor,
            Callback = function(value)
                self.Config.TrajectoryColor = value
                -- Обновляем цвет линий траектории
                for i, line in ipairs(self.Status.TrajLines or {}) do
                    if line then
                        local hue = (i / self.Config.PredSteps) * 0.7
                        line.Color = Color3.fromHSV(hue, 0.85, 0.95):Lerp(value, 0.3)
                    end
                end
            end
        }, "TrajectoryColorPicker")
        
        self.UIElements.EndpointColor = trajSection:Colorpicker({
            Name = "Endpoint Color",
            Default = self.Config.EndpointColor,
            Callback = function(value)
                self.Config.EndpointColor = value
                -- Обновляем цвет линий endpoint
                for _, line in ipairs(self.Status.EndpointLines or {}) do
                    if line then
                        line.Color = value
                    end
                end
            end
        }, "EndpointColorPicker")
        
        trajSection:Divider()
        
        -- Кнопка сброса настроек
        trajSection:Button({
            Name = "Reset to Default",
            Callback = function()
                self.Config = {
                    Enabled = true,
                    UseRaycast = true,
                    VisualFPS = 60,
                    PredSteps = 320,
                    CurveMult = 38,
                    DT = 1/60,
                    Gravity = 110,
                    Drag = 0.988,
                    BounceXZ = 0.76,
                    BounceY = 0.72,
                    CurveFadeRate = 0.06,
                    RaycastLengthMult = 1.8,
                    MinHitDistance = 0.05,
                    MaxDrawDistance = 100,
                    VisualSmoothness = 0.85,
                    PredUpdateMinVel = 15,
                    MinTimeBetweenPred = 0.033,
                    TrajectoryColor = Color3.fromRGB(0, 150, 255),
                    EndpointColor = Color3.fromRGB(255, 230, 0)
                }
                
                -- Обновляем UI элементы
                if self.UIElements then
                    self.UIElements.Enabled:SetState(self.Config.Enabled)
                    self.UIElements.UseRaycast:SetState(self.Config.UseRaycast)
                    self.UIElements.PredSteps:SetValue(self.Config.PredSteps)
                    self.UIElements.CurveMult:SetValue(self.Config.CurveMult)
                    self.UIElements.Gravity:SetValue(self.Config.Gravity)
                    self.UIElements.Drag:SetValue(self.Config.Drag)
                    self.UIElements.MaxDrawDistance:SetValue(self.Config.MaxDrawDistance)
                    self.UIElements.VisualSmoothness:SetValue(self.Config.VisualSmoothness)
                    self.UIElements.TrajectoryColor:SetColor(self.Config.TrajectoryColor)
                    self.UIElements.EndpointColor:SetColor(self.Config.EndpointColor)
                end
                
                -- Переинициализируем визуалы
                self:InitializeVisuals()
                
                self.Notify("Trajectory", "Настройки сброшены к значениям по умолчанию", true)
            end
        })
    end
    
    -- Секция Sync в Config табе
    if UI.Tabs.Config and UI.Tabs.Config:Section then
        local syncSection = UI.Tabs.Config:Section({
            Name = "Trajectory Sync",
            Side = "Right"
        })
        
        syncSection:Header({ Name = "Trajectory Visualizer" })
        syncSection:Button({
            Name = "Sync Config",
            Callback = function()
                if self.UIElements then
                    self.Config.Enabled = self.UIElements.Enabled:GetState()
                    self.Config.UseRaycast = self.UIElements.UseRaycast:GetState()
                    self.Config.PredSteps = self.UIElements.PredSteps:GetValue()
                    self.Config.CurveMult = self.UIElements.CurveMult:GetValue()
                    self.Config.Gravity = self.UIElements.Gravity:GetValue()
                    self.Config.Drag = self.UIElements.Drag:GetValue()
                    self.Config.MaxDrawDistance = self.UIElements.MaxDrawDistance:GetValue()
                    self.Config.VisualSmoothness = self.UIElements.VisualSmoothness:GetValue()
                    self.Config.TrajectoryColor = self.UIElements.TrajectoryColor:GetColor()
                    self.Config.EndpointColor = self.UIElements.EndpointColor:GetColor()
                    
                    -- Применяем изменения
                    if self.Config.Enabled then
                        if not self.Status.Running then
                            self.Start()
                        end
                    else
                        if self.Status.Running then
                            self.Stop()
                        end
                    end
                    
                    -- Обновляем цвета
                    for _, line in ipairs(self.Status.EndpointLines or {}) do
                        if line then
                            line.Color = self.Config.EndpointColor
                        end
                    end
                    
                    self.Notify("Trajectory", "Конфигурация синхронизирована!", true)
                end
            end
        })
    end
end

-- Уничтожение модуля
function TrajectoryVisualizer:Destroy()
    self.Stop()
    self:ClearAllVisuals()
    
    -- Удаление Drawing объектов
    for _, line in pairs(self.Status.TrajLines or {}) do
        if line and line.Remove then
            line:Remove()
        end
    end
    
    for _, line in pairs(self.Status.EndpointLines or {}) do
        if line and line.Remove then
            line:Remove()
        end
    end
    
    self.Status.TrajLines = {}
    self.Status.EndpointLines = {}
end

return TrajectoryVisualizer