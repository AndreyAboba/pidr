local MovementEnhancements = {}

local Services = nil
local PlayerData = nil
local notify = nil
local LocalPlayerObj = nil
local core = nil

MovementEnhancements.Config = {
    Timer = {
        Enabled = false,
        Speed = 2.5,
        ToggleKey = nil
    },
    Disabler = {
        Enabled = false,
        ToggleKey = nil
    },
    Speed = {
        Enabled = false,
        AutoJump = false,
        Method = "CFrame",
        Speed = 16,
        JumpInterval = 0.3,
        PulseTPDist = 5,
        PulseTPDelay = 0.2,
        ToggleKey = nil,
        SmoothnessFactor = 0.2
    },
    Fly = {
        Enabled = false,
        Speed = 50,
        VerticalSpeed = 50,
        ToggleKey = nil,
        VerticalKeys = "E/Q",
        NoClip = true,
        UseBodyVelocity = false
    },
    InfStamina = {
        Enabled = false,
        SprintKey = Enum.KeyCode.LeftShift,
        AlwaysSprint = false,
        RestoreGui = true,
        ToggleKey = nil,
        WalkSpeed = 21,
        RunSpeed = 35
    },
    AntiAFK = {
        Enabled = false,
        CustomAFKTime = 60,
        ShowWarning = true,
        ToggleKey = nil,
        BlockAFKRemote = true,
        AutoReconnect = false
    }
}

-- Status tables
local TimerStatus = {
    Running = false,
    Connection = nil,
    Speed = MovementEnhancements.Config.Timer.Speed,
    Key = MovementEnhancements.Config.Timer.ToggleKey,
    Enabled = MovementEnhancements.Config.Timer.Enabled
}

local DisablerStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.Disabler.ToggleKey,
    Enabled = MovementEnhancements.Config.Disabler.Enabled
}

local SpeedStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.Speed.ToggleKey,
    Enabled = MovementEnhancements.Config.Speed.Enabled,
    Method = MovementEnhancements.Config.Speed.Method,
    Speed = MovementEnhancements.Config.Speed.Speed,
    AutoJump = MovementEnhancements.Config.Speed.AutoJump,
    LastJumpTime = 0,
    JumpCooldown = 0.5,
    JumpInterval = MovementEnhancements.Config.Speed.JumpInterval,
    PulseTPDistance = MovementEnhancements.Config.Speed.PulseTPDist,
    PulseTPFrequency = MovementEnhancements.Config.Speed.PulseTPDelay,
    SmoothnessFactor = MovementEnhancements.Config.Speed.SmoothnessFactor,
    CurrentMoveDirection = Vector3.new(0, 0, 0),
    LastPulseTPTime = 0
}

local FlyStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.Fly.ToggleKey,
    Enabled = MovementEnhancements.Config.Fly.Enabled,
    Speed = MovementEnhancements.Config.Fly.Speed,
    VerticalSpeed = MovementEnhancements.Config.Fly.VerticalSpeed,
    VerticalKeys = MovementEnhancements.Config.Fly.VerticalKeys,
    NoClip = MovementEnhancements.Config.Fly.NoClip,
    UseBodyVelocity = MovementEnhancements.Config.Fly.UseBodyVelocity,
    BodyVelocity = nil,
    BodyGyro = nil,
    BodyPosition = nil,
    CharacterConnection = nil
}

local InfStaminaStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.InfStamina.ToggleKey,
    Enabled = MovementEnhancements.Config.InfStamina.Enabled,
    SprintKey = MovementEnhancements.Config.InfStamina.SprintKey,
    AlwaysSprint = MovementEnhancements.Config.InfStamina.AlwaysSprint,
    RestoreGui = MovementEnhancements.Config.InfStamina.RestoreGui,
    WalkSpeed = MovementEnhancements.Config.InfStamina.WalkSpeed,
    RunSpeed = MovementEnhancements.Config.InfStamina.RunSpeed,
    IsSprinting = false,
    LastSentSpeed = nil,
    GuiMainProtectionConnection = nil,
    SpeedUpdateConnection = nil
}

local AntiAFKStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.AntiAFK.ToggleKey,
    Enabled = MovementEnhancements.Config.AntiAFK.Enabled,
    CustomAFKTime = MovementEnhancements.Config.AntiAFK.CustomAFKTime,
    ShowWarning = MovementEnhancements.Config.AntiAFK.ShowWarning,
    BlockAFKRemote = MovementEnhancements.Config.AntiAFK.BlockAFKRemote,
    AutoReconnect = MovementEnhancements.Config.AntiAFK.AutoReconnect,
    LastInputTime = os.time(),
    AFKRemoteBlocked = false,
    OriginalFireServer = nil,
    AFKWarningFrame = nil,
    InputConnection = nil,
    HeartbeatConnection = nil
}

-- Helper functions
local function getCharacterData()
    local character = LocalPlayerObj and LocalPlayerObj.Character
    if not character then return nil, nil end
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    return humanoid, rootPart
end

local function isCharacterValid(humanoid, rootPart)
    return humanoid and rootPart and humanoid.Health > 0
end

local function isInVehicle(rootPart)
    local currentPart = rootPart
    while currentPart do
        if currentPart:IsA("Seat") or currentPart:IsA("VehicleSeat") then
            return true
        end
        currentPart = currentPart.Parent
    end
    return false
end

local function isInputFocused()
    return Services and Services.UserInputService and Services.UserInputService:GetFocusedTextBox() ~= nil
end

local function getCustomMoveDirection()
    if not Services.UserInputService or not Services.Workspace.CurrentCamera then
        SpeedStatus.CurrentMoveDirection = Vector3.new(0, 0, 0)
        return Vector3.new(0, 0, 0)
    end

    local camera = Services.Workspace.CurrentCamera
    local cameraCFrame = camera.CFrame
    local flatCameraForward = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z)
    local flatCameraRight = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)
    if flatCameraForward.Magnitude == 0 or flatCameraRight.Magnitude == 0 then
        SpeedStatus.CurrentMoveDirection = Vector3.new(0, 0, 0)
        return Vector3.new(0, 0, 0)
    end
    flatCameraForward = flatCameraForward.Unit
    flatCameraRight = flatCameraRight.Unit

    local w = Services.UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0
    local s = Services.UserInputService:IsKeyDown(Enum.KeyCode.S) and -1 or 0
    local a = Services.UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0
    local d = Services.UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0

    local inputVector = Vector3.new(a + d, 0, w + s)
    local targetDirection = Vector3.new(0, 0, 0)
    if inputVector.Magnitude > 0 then
        inputVector = inputVector.Unit
        targetDirection = (flatCameraForward * inputVector.Z + flatCameraRight * inputVector.X)
        if targetDirection.Magnitude > 0 then
            targetDirection = targetDirection.Unit
        end
        local alpha = SpeedStatus.SmoothnessFactor
        SpeedStatus.CurrentMoveDirection = SpeedStatus.CurrentMoveDirection * (1 - alpha) + targetDirection * alpha
        if SpeedStatus.CurrentMoveDirection.Magnitude > 0 then
            SpeedStatus.CurrentMoveDirection = SpeedStatus.CurrentMoveDirection.Unit
        end
    else
        SpeedStatus.CurrentMoveDirection = Vector3.new(0, 0, 0)
    end
    return SpeedStatus.CurrentMoveDirection
end

-- Timer Module
local Timer = {}
Timer.Start = function()
    if TimerStatus.Running or not Services then return end
    local success = pcall(function()
        setfflag("SimEnableStepPhysics", "True")
        setfflag("SimEnableStepPhysicsSelective", "True")
    end)
    if not success then
        warn("Timer: Failed to enable physics flags")
        notify("Timer", "Failed to enable physics simulation.", true)
        return
    end
    TimerStatus.Running = true
    TimerStatus.Connection = Services.RunService.RenderStepped:Connect(function(dt)
        if not TimerStatus.Enabled or TimerStatus.Speed <= 1 then return end
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) then return end
        local success, err = pcall(function()
            Services.RunService:Pause()
            Services.Workspace:StepPhysics(dt * (TimerStatus.Speed - 1), {rootPart})
            Services.RunService:Run()
        end)
        if not success then
            warn("Timer physics step failed: " .. tostring(err))
            Timer.Stop()
            notify("Timer", "Physics step failed. Timer stopped.", true)
        end
    end)
    notify("Timer", "Started with speed: " .. TimerStatus.Speed, true)
end

Timer.Stop = function()
    if TimerStatus.Connection then
        TimerStatus.Connection:Disconnect()
        TimerStatus.Connection = nil
    end
    TimerStatus.Running = false
    notify("Timer", "Stopped", true)
end

Timer.SetSpeed = function(newSpeed)
    TimerStatus.Speed = math.clamp(newSpeed, 1, 15)
    MovementEnhancements.Config.Timer.Speed = TimerStatus.Speed
    notify("Timer", "Speed set to: " .. TimerStatus.Speed, false)
end

-- Disabler Module
local Disabler = {}
Disabler.DisableSignals = function(character)
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("CFrame"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("Velocity"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
end

Disabler.Start = function()
    if DisablerStatus.Running or not LocalPlayerObj then return end
    DisablerStatus.Running = true
    DisablerStatus.Connection = LocalPlayerObj.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        Disabler.DisableSignals(char)
    end)
    if LocalPlayerObj.Character then
        Disabler.DisableSignals(LocalPlayerObj.Character)
    end
    notify("Disabler", "Started", true)
end

Disabler.Stop = function()
    if DisablerStatus.Connection then
        DisablerStatus.Connection:Disconnect()
        DisablerStatus.Connection = nil
    end
    DisablerStatus.Running = false
    notify("Disabler", "Stopped", true)
end

-- Speed Module
local Speed = {}
Speed.UpdateMovement = function(humanoid, rootPart, moveDirection, currentTime, dt)
    if not isCharacterValid(humanoid, rootPart) then return end
    if SpeedStatus.Method == "CFrame" then
        if moveDirection.Magnitude > 0 then
            local newCFrame = rootPart.CFrame + (moveDirection * SpeedStatus.Speed * dt)
            rootPart.CFrame = CFrame.new(newCFrame.Position, newCFrame.Position + moveDirection)
        end
    elseif SpeedStatus.Method == "PulseTP" then
        if moveDirection.Magnitude > 0 and currentTime - SpeedStatus.LastPulseTPTime >= SpeedStatus.PulseTPFrequency then
            local scaledDistance = SpeedStatus.PulseTPDistance * (SpeedStatus.Speed / 16)
            local teleportVector = moveDirection.Unit * scaledDistance
            local destination = rootPart.Position + teleportVector
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {LocalPlayerObj.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local raycastResult = Services.Workspace:Raycast(rootPart.Position, teleportVector, raycastParams)
            if not raycastResult then
                rootPart.CFrame = CFrame.new(destination, destination + moveDirection)
                SpeedStatus.LastPulseTPTime = currentTime
            end
        end
    end
end

Speed.UpdateJumps = function(humanoid, rootPart, currentTime, moveDirection)
    if not isCharacterValid(humanoid, rootPart) then return end
    if SpeedStatus.AutoJump and moveDirection.Magnitude > 0 and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            SpeedStatus.LastJumpTime = currentTime
        end
    end
end

Speed.Start = function()
    if SpeedStatus.Running or not Services then return end
    SpeedStatus.Running = true
    SpeedStatus.Connection = Services.RunService.Heartbeat:Connect(function(dt)
        if not SpeedStatus.Enabled then
            SpeedStatus.Running = false
            return
        end
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) then return end
        local currentTime = tick()
        local moveDirection = getCustomMoveDirection()
        Speed.UpdateMovement(humanoid, rootPart, moveDirection, currentTime, dt)
        Speed.UpdateJumps(humanoid, rootPart, currentTime, moveDirection)
    end)
    notify("Speed", "Started with Method: " .. SpeedStatus.Method, true)
end

Speed.Stop = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end
    SpeedStatus.Running = false
    notify("Speed", "Stopped", true)
end

Speed.SetSpeed = function(newSpeed)
    SpeedStatus.Speed = math.clamp(newSpeed, 16, 250)
    MovementEnhancements.Config.Speed.Speed = SpeedStatus.Speed
    notify("Speed", "Speed set to: " .. SpeedStatus.Speed, false)
end

Speed.SetMethod = function(newMethod)
    SpeedStatus.Method = newMethod
    MovementEnhancements.Config.Speed.Method = newMethod
    notify("Speed", "Method set to: " .. newMethod, false)
    if SpeedStatus.Running then
        Speed.Stop()
        Speed.Start()
    end
end

Speed.SetPulseTPDistance = function(value)
    SpeedStatus.PulseTPDistance = math.clamp(value, 1, 20)
    MovementEnhancements.Config.Speed.PulseTPDist = SpeedStatus.PulseTPDistance
    notify("Speed", "Pulse TP Distance set to: " .. SpeedStatus.PulseTPDistance, false)
end

Speed.SetPulseTPFrequency = function(value)
    SpeedStatus.PulseTPFrequency = math.clamp(value, 0.1, 2)
    MovementEnhancements.Config.Speed.PulseTPDelay = SpeedStatus.PulseTPFrequency
    notify("Speed", "Pulse TP Frequency set to: " .. SpeedStatus.PulseTPFrequency, false)
end

Speed.SetSmoothnessFactor = function(value)
    SpeedStatus.SmoothnessFactor = math.clamp(value, 0, 1)
    MovementEnhancements.Config.Speed.SmoothnessFactor = SpeedStatus.SmoothnessFactor
    notify("Speed", "Smoothness Factor set to: " .. SpeedStatus.SmoothnessFactor, false)
end

-- Fly Module (ИСПРАВЛЕННЫЙ)
local Fly = {}
Fly.GetFlyDirection = function()
    local moveDirection = Vector3.new(0, 0, 0)
    
    if Services.UserInputService and Services.Workspace.CurrentCamera then
        local camera = Services.Workspace.CurrentCamera
        local cameraCFrame = camera.CFrame
        
        local cameraForward = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z)
        local cameraRight = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)
        
        if cameraForward.Magnitude > 0 then cameraForward = cameraForward.Unit end
        if cameraRight.Magnitude > 0 then cameraRight = cameraRight.Unit end
        
        local w = Services.UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0
        local s = Services.UserInputService:IsKeyDown(Enum.KeyCode.S) and -1 or 0
        local a = Services.UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0
        local d = Services.UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
        
        local inputVector = Vector3.new(a + d, 0, w + s)
        if inputVector.Magnitude > 0 then
            inputVector = inputVector.Unit
            moveDirection = (cameraForward * inputVector.Z + cameraRight * inputVector.X)
            if moveDirection.Magnitude > 0 then
                moveDirection = moveDirection.Unit
            end
        end
    end
    
    return moveDirection
end

Fly.GetVerticalDirection = function()
    local verticalDirection = 0
    local upKey, downKey = FlyStatus.VerticalKeys:match("(.+)/(.+)")
    if upKey and downKey then
        if Services.UserInputService:IsKeyDown(Enum.KeyCode[upKey]) then
            verticalDirection = 1
        elseif Services.UserInputService:IsKeyDown(Enum.KeyCode[downKey]) then
            verticalDirection = -1
        end
    end
    return verticalDirection
end

Fly.Cleanup = function()
    if FlyStatus.BodyVelocity then
        FlyStatus.BodyVelocity:Destroy()
        FlyStatus.BodyVelocity = nil
    end
    if FlyStatus.BodyGyro then
        FlyStatus.BodyGyro:Destroy()
        FlyStatus.BodyGyro = nil
    end
    if FlyStatus.BodyPosition then
        FlyStatus.BodyPosition:Destroy()
        FlyStatus.BodyPosition = nil
    end
    
    local humanoid = getCharacterData()
    if humanoid then
        humanoid.PlatformStand = false
    end
end

Fly.Start = function()
    if FlyStatus.Running or not Services then return end
    local humanoid, rootPart = getCharacterData()
    if not isCharacterValid(humanoid, rootPart) or isInVehicle(rootPart) then return end
    
    FlyStatus.Running = true
    
    -- Очистка перед запуском
    Fly.Cleanup()
    
    -- Настройка персонажа для полета
    humanoid.PlatformStand = true
    if FlyStatus.NoClip then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end
    
    -- Создаем физические объекты
    FlyStatus.BodyVelocity = Instance.new("BodyVelocity")
    FlyStatus.BodyVelocity.MaxForce = Vector3.new(40000, 40000, 40000)
    FlyStatus.BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    FlyStatus.BodyVelocity.P = 1250
    FlyStatus.BodyVelocity.Parent = rootPart
    
    FlyStatus.BodyGyro = Instance.new("BodyGyro")
    FlyStatus.BodyGyro.MaxTorque = Vector3.new(50000, 50000, 50000)
    FlyStatus.BodyGyro.P = 1000
    FlyStatus.BodyGyro.D = 200
    FlyStatus.BodyGyro.CFrame = rootPart.CFrame
    FlyStatus.BodyGyro.Parent = rootPart
    
    -- BodyPosition для плавного вертикального движения
    FlyStatus.BodyPosition = Instance.new("BodyPosition")
    FlyStatus.BodyPosition.MaxForce = Vector3.new(0, 40000, 0)
    FlyStatus.BodyPosition.Position = rootPart.Position
    FlyStatus.BodyPosition.P = 10000
    FlyStatus.BodyPosition.D = 1000
    FlyStatus.BodyPosition.Parent = rootPart
    
    -- Обработчик изменения персонажа
    FlyStatus.CharacterConnection = LocalPlayerObj.CharacterAdded:Connect(function()
        task.wait(0.5)
        if FlyStatus.Enabled then
            Fly.Stop()
            Fly.Start()
        end
    end)
    
    -- Основной цикл полета
    FlyStatus.Connection = Services.RunService.Heartbeat:Connect(function(dt)
        if not FlyStatus.Enabled then
            FlyStatus.Running = false
            return
        end
        
        local _, currentRootPart = getCharacterData()
        if not currentRootPart or not FlyStatus.BodyGyro or not FlyStatus.BodyVelocity then return end
        
        -- Получаем направления
        local flyDirection = Fly.GetFlyDirection()
        local verticalDirection = Fly.GetVerticalDirection()
        
        -- Обновляем BodyGyro для стабилизации
        local camera = Services.Workspace.CurrentCamera
        if camera then
            local lookVector = camera.CFrame.LookVector
            FlyStatus.BodyGyro.CFrame = CFrame.new(currentRootPart.Position, 
                currentRootPart.Position + Vector3.new(lookVector.X, 0, lookVector.Z))
        end
        
        -- Вычисляем скорость
        local velocity = flyDirection * FlyStatus.Speed
        
        -- Вертикальное движение через BodyPosition
        if verticalDirection ~= 0 then
            local newPosition = currentRootPart.Position + Vector3.new(0, verticalDirection * FlyStatus.VerticalSpeed * dt, 0)
            FlyStatus.BodyPosition.Position = Vector3.new(currentRootPart.Position.X, newPosition.Y, currentRootPart.Position.Z)
        else
            -- Удерживаем текущую высоту
            FlyStatus.BodyPosition.Position = Vector3.new(currentRootPart.Position.X, currentRootPart.Position.Y, currentRootPart.Position.Z)
        end
        
        -- Применяем горизонтальную скорость
        FlyStatus.BodyVelocity.Velocity = Vector3.new(velocity.X, 0, velocity.Z)
    end)
    
    notify("Fly", "Started with Speed: " .. FlyStatus.Speed, true)
end

Fly.Stop = function()
    if FlyStatus.Connection then
        FlyStatus.Connection:Disconnect()
        FlyStatus.Connection = nil
    end
    if FlyStatus.CharacterConnection then
        FlyStatus.CharacterConnection:Disconnect()
        FlyStatus.CharacterConnection = nil
    end
    
    Fly.Cleanup()
    FlyStatus.Running = false
    notify("Fly", "Stopped", true)
end

Fly.SetSpeed = function(newSpeed)
    FlyStatus.Speed = math.clamp(newSpeed, 10, 200)
    MovementEnhancements.Config.Fly.Speed = FlyStatus.Speed
    notify("Fly", "Speed set to: " .. FlyStatus.Speed, false)
end

Fly.SetVerticalSpeed = function(newSpeed)
    FlyStatus.VerticalSpeed = math.clamp(newSpeed, 10, 200)
    MovementEnhancements.Config.Fly.VerticalSpeed = FlyStatus.VerticalSpeed
    notify("Fly", "Vertical Speed set to: " .. FlyStatus.VerticalSpeed, false)
end

Fly.SetVerticalKeys = function(newKeys)
    FlyStatus.VerticalKeys = newKeys
    MovementEnhancements.Config.Fly.VerticalKeys = newKeys
    notify("Fly", "Vertical Keys set to: " .. newKeys, false)
end

Fly.SetNoClip = function(enabled)
    FlyStatus.NoClip = enabled
    MovementEnhancements.Config.Fly.NoClip = enabled
    notify("Fly", "NoClip " .. (enabled and "enabled" or "disabled"), false)
end

-- InfStamina Module
local InfStamina = {}
InfStamina.GetStaminaGuiElements = function()
    local playerGui = LocalPlayerObj and LocalPlayerObj:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local staminaFrame = playerGui:FindFirstChild("Stamina")
    if not staminaFrame then return nil end
    
    local frame = staminaFrame:FindFirstChild("Frame")
    if not frame then return nil end
    
    return {
        Frame = frame,
        Speeds = frame:FindFirstChild("Speeds"),
        SpeedRemote = frame:FindFirstChild("Speed"),
        GreenBar = frame:FindFirstChild("GreenBar"),
        StaminaLabel = frame:FindFirstChild("Stamina"),
        Enabled = frame:FindFirstChild("Enabled"),
        GuiMain = frame:FindFirstChild("GuiMain"),
        Rest1 = frame:FindFirstChild("Rest1"),
        Rest2 = frame:FindFirstChild("Rest2")
    }
end

InfStamina.ForceDisableGuiMain = function()
    if not InfStaminaStatus.Enabled then return end
    
    local elements = InfStamina.GetStaminaGuiElements()
    if elements and elements.GuiMain then
        elements.GuiMain.Disabled = true
    end
end

InfStamina.UpdateStaminaValues = function()
    if not InfStaminaStatus.Enabled then return end
    
    local elements = InfStamina.GetStaminaGuiElements()
    if elements then
        if elements.Speeds then
            local walkSpeedVal = elements.Speeds:FindFirstChild("Walk")
            local runSpeedVal = elements.Speeds:FindFirstChild("Run")
            
            if walkSpeedVal then
                InfStaminaStatus.WalkSpeed = walkSpeedVal.Value
            end
            if runSpeedVal then
                InfStaminaStatus.RunSpeed = runSpeedVal.Value
            end
        end
        
        if InfStaminaStatus.RestoreGui and elements.GreenBar and elements.StaminaLabel then
            elements.GreenBar.Size = UDim2.new(1, 0, 0, 32)
            elements.GreenBar.Image = "rbxassetid://119528804"
            elements.StaminaLabel.Visible = true
            
            if elements.Rest1 then
                elements.Rest1.Visible = false
            end
            if elements.Rest2 then
                elements.Rest2.Visible = false
            end
        end
    end
end

InfStamina.Start = function()
    if InfStaminaStatus.Running or not Services then return end
    if not LocalPlayerObj then return end
    
    InfStaminaStatus.Running = true
    
    -- Защита GuiMain
    InfStaminaStatus.GuiMainProtectionConnection = Services.RunService.Heartbeat:Connect(function()
        if not InfStaminaStatus.Enabled then return end
        InfStamina.ForceDisableGuiMain()
    end)
    
    -- Обновление значений скорости
    InfStaminaStatus.SpeedUpdateConnection = Services.RunService.Heartbeat:Connect(function()
        if not InfStaminaStatus.Enabled then return end
        
        local humanoid = getCharacterData()
        if not humanoid then return end
        
        InfStamina.UpdateStaminaValues()
        
        local shouldSprint = InfStaminaStatus.AlwaysSprint or 
                           (Services.UserInputService and 
                            Services.UserInputService:IsKeyDown(InfStaminaStatus.SprintKey))
        
        local targetSpeed = shouldSprint and InfStaminaStatus.RunSpeed or InfStaminaStatus.WalkSpeed
        humanoid.WalkSpeed = targetSpeed
        
        local elements = InfStamina.GetStaminaGuiElements()
        if elements and elements.SpeedRemote and targetSpeed ~= InfStaminaStatus.LastSentSpeed then
            pcall(function()
                elements.SpeedRemote:FireServer(10525299, targetSpeed)
                InfStaminaStatus.LastSentSpeed = targetSpeed
            end)
        end
    end)
    
    -- Обработка ввода для спринта
    if Services.UserInputService then
        Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not InfStaminaStatus.Enabled or InfStaminaStatus.AlwaysSprint then return end
            
            if input.KeyCode == InfStaminaStatus.SprintKey then
                InfStaminaStatus.IsSprinting = true
            end
        end)
        
        Services.UserInputService.InputEnded:Connect(function(input, gameProcessed)
            if gameProcessed or not InfStaminaStatus.Enabled or InfStaminaStatus.AlwaysSprint then return end
            
            if input.KeyCode == InfStaminaStatus.SprintKey then
                InfStaminaStatus.IsSprinting = false
            end
        end)
    end
    
    -- Инициализация
    InfStamina.ForceDisableGuiMain()
    InfStamina.UpdateStaminaValues()
    
    notify("InfStamina", "Started", true)
end

InfStamina.Stop = function()
    if InfStaminaStatus.GuiMainProtectionConnection then
        InfStaminaStatus.GuiMainProtectionConnection:Disconnect()
        InfStaminaStatus.GuiMainProtectionConnection = nil
    end
    
    if InfStaminaStatus.SpeedUpdateConnection then
        InfStaminaStatus.SpeedUpdateConnection:Disconnect()
        InfStaminaStatus.SpeedUpdateConnection = nil
    end
    
    InfStaminaStatus.Running = false
    InfStaminaStatus.LastSentSpeed = nil
    notify("InfStamina", "Stopped", true)
end

InfStamina.SetSprintKey = function(newKey)
    local keyName = tostring(newKey)
    if keyName == "LeftShift" then
        InfStaminaStatus.SprintKey = Enum.KeyCode.LeftShift
    elseif keyName == "Space" then
        InfStaminaStatus.SprintKey = Enum.KeyCode.Space
    elseif keyName == "C" then
        InfStaminaStatus.SprintKey = Enum.KeyCode.C
    elseif keyName == "V" then
        InfStaminaStatus.SprintKey = Enum.KeyCode.V
    else
        InfStaminaStatus.SprintKey = Enum.KeyCode.LeftShift
    end
    
    MovementEnhancements.Config.InfStamina.SprintKey = InfStaminaStatus.SprintKey
    notify("InfStamina", "Sprint key set to: " .. tostring(InfStaminaStatus.SprintKey), false)
end

InfStamina.SetAlwaysSprint = function(enabled)
    InfStaminaStatus.AlwaysSprint = enabled
    MovementEnhancements.Config.InfStamina.AlwaysSprint = enabled
    notify("InfStamina", "Always sprint " .. (enabled and "enabled" or "disabled"), false)
end

InfStamina.SetRestoreGui = function(enabled)
    InfStaminaStatus.RestoreGui = enabled
    MovementEnhancements.Config.InfStamina.RestoreGui = enabled
    notify("InfStamina", "Restore GUI " .. (enabled and "enabled" or "disabled"), false)
end

-- AntiAFK Module
local AntiAFK = {}

-- Hook для перехвата FireServer
local function hookAFKRemote()
    if not Services or AntiAFKStatus.AFKRemoteBlocked then return end
    
    local success, remote = pcall(function()
        return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("AFKRemote")
    end)
    
    if success and remote then
        AntiAFKStatus.OriginalFireServer = hookfunction(remote.FireServer, function(self, ...)
            local args = {...}
            if AntiAFKStatus.BlockAFKRemote and AntiAFKStatus.Enabled then
                -- Блокируем AFK сигналы
                if args[1] == true then -- AFK активация
                    notify("AntiAFK", "Blocked AFK activation", false)
                    return nil
                end
            end
            -- Пропускаем остальные вызовы
            return AntiAFKStatus.OriginalFireServer(self, ...)
        end)
        AntiAFKStatus.AFKRemoteBlocked = true
        notify("AntiAFK", "AFK remote hooked successfully", false)
    end
end

AntiAFK.CreateWarningFrame = function()
    if not AntiAFKStatus.ShowWarning or not Services then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AntiAFKWarning"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 60)
    frame.Position = UDim2.new(0.5, -100, 0.05, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Visible = false
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, -20)
    label.Position = UDim2.new(0, 10, 0, 10)
    label.BackgroundTransparency = 1
    label.Text = "Anti-AFK Active"
    label.TextColor3 = Color3.fromRGB(0, 255, 0)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.5
    label.Parent = frame
    
    frame.Parent = screenGui
    screenGui.Parent = Services.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    AntiAFKStatus.AFKWarningFrame = frame
end

AntiAFK.Start = function()
    if AntiAFKStatus.Running or not Services then return end
    
    AntiAFKStatus.Running = true
    AntiAFKStatus.LastInputTime = os.time()
    
    -- Хук AFK remote
    if AntiAFKStatus.BlockAFKRemote then
        hookAFKRemote()
    end
    
    -- Создаем предупреждение
    if AntiAFKStatus.ShowWarning then
        AntiAFK.CreateWarningFrame()
        if AntiAFKStatus.AFKWarningFrame then
            AntiAFKStatus.AFKWarningFrame.Visible = true
        end
    end
    
    -- Обработчик ввода
    AntiAFKStatus.InputConnection = Services.UserInputService.InputBegan:Connect(function()
        AntiAFKStatus.LastInputTime = os.time()
    end)
    
    -- Основной цикл
    AntiAFKStatus.HeartbeatConnection = Services.RunService.Heartbeat:Connect(function()
        if not AntiAFKStatus.Enabled then
            AntiAFKStatus.Running = false
            return
        end
        
        local currentTime = os.time()
        local timeSinceLastInput = currentTime - AntiAFKStatus.LastInputTime
        
        -- Если прошло больше времени AFK, симулируем ввод
        if timeSinceLastInput > AntiAFKStatus.CustomAFKTime then
            AntiAFKStatus.LastInputTime = currentTime
            
            -- Симуляция разных действий для обхода AFK
            if Services.UserInputService then
                -- Симулируем движение мыши
                Services.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                
                -- Симулируем нажатие клавиши (не вызывая реального действия)
                task.spawn(function()
                    local virtualInput = game:GetService("VirtualInputManager")
                    if virtualInput then
                        virtualInput:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        task.wait(0.1)
                        virtualInput:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                    end
                end)
            end
            
            -- Отправляем ложный сигнал не-AFK если remote не заблокирован
            if not AntiAFKStatus.BlockAFKRemote then
                local success, remote = pcall(function()
                    return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("AFKRemote")
                end)
                if success then
                    pcall(function()
                        remote:FireServer(false)
                    end)
                end
            end
            
            notify("AntiAFK", "Prevented AFK kick", false)
        end
    end)
    
    notify("AntiAFK", "Started (Timeout: " .. AntiAFKStatus.CustomAFKTime .. "s)", true)
end

AntiAFK.Stop = function()
    if AntiAFKStatus.InputConnection then
        AntiAFKStatus.InputConnection:Disconnect()
        AntiAFKStatus.InputConnection = nil
    end
    
    if AntiAFKStatus.HeartbeatConnection then
        AntiAFKStatus.HeartbeatConnection:Disconnect()
        AntiAFKStatus.HeartbeatConnection = nil
    end
    
    -- Удаляем предупреждение
    if AntiAFKStatus.AFKWarningFrame then
        AntiAFKStatus.AFKWarningFrame:Destroy()
        AntiAFKStatus.AFKWarningFrame = nil
    end
    
    -- Восстанавливаем оригинальный FireServer если был хук
    if AntiAFKStatus.OriginalFireServer and AntiAFKStatus.AFKRemoteBlocked then
        hookfunction(getrawmetatable(game:GetService("ReplicatedStorage").Remotes.AFKRemote).__namecall, AntiAFKStatus.OriginalFireServer)
        AntiAFKStatus.AFKRemoteBlocked = false
    end
    
    AntiAFKStatus.Running = false
    notify("AntiAFK", "Stopped", true)
end

AntiAFK.SetAFKTime = function(newTime)
    AntiAFKStatus.CustomAFKTime = math.clamp(newTime, 30, 300)
    MovementEnhancements.Config.AntiAFK.CustomAFKTime = AntiAFKStatus.CustomAFKTime
    notify("AntiAFK", "AFK time set to: " .. AntiAFKStatus.CustomAFKTime .. "s", false)
end

AntiAFK.SetShowWarning = function(enabled)
    AntiAFKStatus.ShowWarning = enabled
    MovementEnhancements.Config.AntiAFK.ShowWarning = enabled
    notify("AntiAFK", "Warning " .. (enabled and "enabled" or "disabled"), false)
end

AntiAFK.SetBlockAFKRemote = function(enabled)
    AntiAFKStatus.BlockAFKRemote = enabled
    MovementEnhancements.Config.AntiAFK.BlockAFKRemote = enabled
    notify("AntiAFK", "Block AFK remote " .. (enabled and "enabled" or "disabled"), false)
end

-- UI Setup
local function SetupUI(UI)
    local uiElements = {}
    
    -- Timer Section
    if UI.Sections.Timer then
        UI.Sections.Timer:Header({ Name = "Timer" })
        uiElements.TimerEnabled = UI.Sections.Timer:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Timer.Enabled,
            Callback = function(value)
                TimerStatus.Enabled = value
                MovementEnhancements.Config.Timer.Enabled = value
                if value then Timer.Start() else Timer.Stop() end
            end
        }, "TimerEnabled")
        
        uiElements.TimerSpeed = UI.Sections.Timer:Slider({
            Name = "Speed",
            Minimum = 1,
            Maximum = 15,
            Default = MovementEnhancements.Config.Timer.Speed,
            Precision = 1,
            Callback = function(value)
                Timer.SetSpeed(value)
            end
        }, "TimerSpeed")
        
        uiElements.TimerKey = UI.Sections.Timer:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Timer.ToggleKey,
            Callback = function(value)
                TimerStatus.Key = value
                MovementEnhancements.Config.Timer.ToggleKey = value
                if isInputFocused() then return end
                if TimerStatus.Enabled then
                    if TimerStatus.Running then Timer.Stop() else Timer.Start() end
                else
                    notify("Timer", "Enable Timer to use keybind.", true)
                end
            end
        }, "TimerKey")
    end

    -- Disabler Section
    if UI.Sections.Disabler then
        UI.Sections.Disabler:Header({ Name = "Disabler" })
        uiElements.DisablerEnabled = UI.Sections.Disabler:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Disabler.Enabled,
            Callback = function(value)
                DisablerStatus.Enabled = value
                MovementEnhancements.Config.Disabler.Enabled = value
                if value then Disabler.Start() else Disabler.Stop() end
            end
        }, "DisablerEnabled")
        
        uiElements.DisablerKey = UI.Sections.Disabler:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Disabler.ToggleKey,
            Callback = function(value)
                DisablerStatus.Key = value
                MovementEnhancements.Config.Disabler.ToggleKey = value
                if isInputFocused() then return end
                if DisablerStatus.Enabled then
                    if DisablerStatus.Running then Disabler.Stop() else Disabler.Start() end
                else
                    notify("Disabler", "Enable Disabler to use keybind.", true)
                end
            end
        }, "DisablerKey")
    end

    -- Speed Section
    if UI.Sections.Speed then
        UI.Sections.Speed:Header({ Name = "Speed" })
        uiElements.SpeedEnabled = UI.Sections.Speed:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Speed.Enabled,
            Callback = function(value)
                SpeedStatus.Enabled = value
                MovementEnhancements.Config.Speed.Enabled = value
                if value then Speed.Start() else Speed.Stop() end
            end
        }, "SpeedEnabled")
        
        uiElements.SpeedAutoJump = UI.Sections.Speed:Toggle({
            Name = "Auto Jump",
            Default = MovementEnhancements.Config.Speed.AutoJump,
            Callback = function(value)
                SpeedStatus.AutoJump = value
                MovementEnhancements.Config.Speed.AutoJump = value
            end
        }, "SpeedAutoJump")
        
        uiElements.SpeedMethod = UI.Sections.Speed:Dropdown({
            Name = "Method",
            Options = {"CFrame", "PulseTP"},
            Default = MovementEnhancements.Config.Speed.Method,
            Callback = function(value)
                Speed.SetMethod(value)
            end
        }, "SpeedMethod")
        
        uiElements.Speed = UI.Sections.Speed:Slider({
            Name = "Speed",
            Minimum = 16,
            Maximum = 250,
            Default = MovementEnhancements.Config.Speed.Speed,
            Precision = 1,
            Callback = function(value)
                Speed.SetSpeed(value)
            end
        }, "Speed")
        
        uiElements.SpeedJumpInterval = UI.Sections.Speed:Slider({
            Name = "Jump Interval",
            Minimum = 0.1,
            Maximum = 2,
            Default = MovementEnhancements.Config.Speed.JumpInterval,
            Precision = 2,
            Callback = function(value)
                SpeedStatus.JumpInterval = value
                MovementEnhancements.Config.Speed.JumpInterval = value
                notify("Speed", "Jump Interval set to: " .. value, false)
            end
        }, "SpeedJumpInterval")
        
        uiElements.SpeedPulseTPDistance = UI.Sections.Speed:Slider({
            Name = "Pulse TP Distance",
            Minimum = 1,
            Maximum = 20,
            Default = MovementEnhancements.Config.Speed.PulseTPDist,
            Precision = 1,
            Callback = function(value)
                Speed.SetPulseTPDistance(value)
            end
        }, "SpeedPulseTPDistance")
        
        uiElements.SpeedPulseTPFrequency = UI.Sections.Speed:Slider({
            Name = "Pulse TP Frequency",
            Minimum = 0.1,
            Maximum = 2,
            Default = MovementEnhancements.Config.Speed.PulseTPDelay,
            Precision = 2,
            Callback = function(value)
                Speed.SetPulseTPFrequency(value)
            end
        }, "SpeedPulseTPFrequency")
        
        uiElements.SpeedSmoothnessFactor = UI.Sections.Speed:Slider({
            Name = "Smoothness Factor",
            Minimum = 0,
            Maximum = 1,
            Default = MovementEnhancements.Config.Speed.SmoothnessFactor,
            Precision = 2,
            Callback = function(value)
                Speed.SetSmoothnessFactor(value)
            end
        }, "SpeedSmoothnessFactor")
        
        uiElements.SpeedKey = UI.Sections.Speed:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Speed.ToggleKey,
            Callback = function(value)
                SpeedStatus.Key = value
                MovementEnhancements.Config.Speed.ToggleKey = value
                if isInputFocused() then return end
                if SpeedStatus.Enabled then
                    if SpeedStatus.Running then Speed.Stop() else Speed.Start() end
                else
                    notify("Speed", "Enable Speed to use keybind.", true)
                end
            end
        }, "SpeedKey")
    end

    -- Fly Section
    if UI.Sections.Fly then
        UI.Sections.Fly:Header({ Name = "Fly" })
        uiElements.FlyEnabled = UI.Sections.Fly:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Fly.Enabled,
            Callback = function(value)
                FlyStatus.Enabled = value
                MovementEnhancements.Config.Fly.Enabled = value
                if value then Fly.Start() else Fly.Stop() end
            end
        }, "FlyEnabled")
        
        uiElements.FlySpeed = UI.Sections.Fly:Slider({
            Name = "Speed",
            Minimum = 10,
            Maximum = 200,
            Default = MovementEnhancements.Config.Fly.Speed,
            Precision = 1,
            Callback = function(value)
                Fly.SetSpeed(value)
            end
        }, "FlySpeed")
        
        uiElements.FlyVerticalSpeed = UI.Sections.Fly:Slider({
            Name = "Vertical Speed",
            Minimum = 10,
            Maximum = 200,
            Default = MovementEnhancements.Config.Fly.VerticalSpeed,
            Precision = 1,
            Callback = function(value)
                Fly.SetVerticalSpeed(value)
            end
        }, "FlyVerticalSpeed")
        
        uiElements.FlyVerticalKeys = UI.Sections.Fly:Dropdown({
            Name = "Vertical Keys",
            Options = {"E/Q", "Space/LeftControl"},
            Default = MovementEnhancements.Config.Fly.VerticalKeys,
            Callback = function(value)
                Fly.SetVerticalKeys(value)
            end
        }, "FlyVerticalKeys")
        
        uiElements.FlyNoClip = UI.Sections.Fly:Toggle({
            Name = "NoClip",
            Default = MovementEnhancements.Config.Fly.NoClip,
            Callback = function(value)
                Fly.SetNoClip(value)
            end
        }, "FlyNoClip")
        
        uiElements.FlyKey = UI.Sections.Fly:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Fly.ToggleKey,
            Callback = function(value)
                FlyStatus.Key = value
                MovementEnhancements.Config.Fly.ToggleKey = value
                if isInputFocused() then return end
                if FlyStatus.Enabled then
                    if FlyStatus.Running then Fly.Stop() else Fly.Start() end
                else
                    notify("Fly", "Enable Fly to use keybind.", true)
                end
            end
        }, "FlyKey")
    end

    -- InfStamina Section
    if UI.Sections.InfStamina then
        UI.Sections.InfStamina:Header({ Name = "Infinity Stamina" })
        
        uiElements.InfStaminaEnabled = UI.Sections.InfStamina:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.InfStamina.Enabled,
            Callback = function(value)
                InfStaminaStatus.Enabled = value
                MovementEnhancements.Config.InfStamina.Enabled = value
                if value then InfStamina.Start() else InfStamina.Stop() end
            end
        }, "InfStaminaEnabled")
        
        uiElements.InfStaminaAlwaysSprint = UI.Sections.InfStamina:Toggle({
            Name = "Always Sprint",
            Default = MovementEnhancements.Config.InfStamina.AlwaysSprint,
            Callback = function(value)
                InfStamina.SetAlwaysSprint(value)
            end
        }, "InfStaminaAlwaysSprint")
        
        uiElements.InfStaminaRestoreGui = UI.Sections.InfStamina:Toggle({
            Name = "Restore GUI",
            Default = MovementEnhancements.Config.InfStamina.RestoreGui,
            Callback = function(value)
                InfStamina.SetRestoreGui(value)
            end
        }, "InfStaminaRestoreGui")
        
        uiElements.InfStaminaSprintKey = UI.Sections.InfStamina:Dropdown({
            Name = "Sprint Key",
            Options = {"LeftShift", "Space", "C", "V"},
            Default = "LeftShift",
            Callback = function(value)
                InfStamina.SetSprintKey(value)
            end
        }, "InfStaminaSprintKey")
        
        uiElements.InfStaminaKey = UI.Sections.InfStamina:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.InfStamina.ToggleKey,
            Callback = function(value)
                InfStaminaStatus.Key = value
                MovementEnhancements.Config.InfStamina.ToggleKey = value
                if isInputFocused() then return end
                if InfStaminaStatus.Enabled then
                    if InfStaminaStatus.Running then InfStamina.Stop() else InfStamina.Start() end
                else
                    notify("InfStamina", "Enable InfStamina to use keybind.", true)
                end
            end
        }, "InfStaminaKey")
    end

    -- AntiAFK Section
    if UI.Sections.AntiAFK then
        UI.Sections.AntiAFK:Header({ Name = "Anti-AFK" })
        
        uiElements.AntiAFKEnabled = UI.Sections.AntiAFK:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.AntiAFK.Enabled,
            Callback = function(value)
                AntiAFKStatus.Enabled = value
                MovementEnhancements.Config.AntiAFK.Enabled = value
                if value then AntiAFK.Start() else AntiAFK.Stop() end
            end
        }, "AntiAFKEnabled")
        
        uiElements.AntiAFKTime = UI.Sections.AntiAFK:Slider({
            Name = "AFK Time (seconds)",
            Minimum = 30,
            Maximum = 300,
            Default = MovementEnhancements.Config.AntiAFK.CustomAFKTime,
            Precision = 1,
            Callback = function(value)
                AntiAFK.SetAFKTime(value)
            end
        }, "AntiAFKTime")
        
        uiElements.AntiAFKShowWarning = UI.Sections.AntiAFK:Toggle({
            Name = "Show Warning",
            Default = MovementEnhancements.Config.AntiAFK.ShowWarning,
            Callback = function(value)
                AntiAFK.SetShowWarning(value)
            end
        }, "AntiAFKShowWarning")
        
        uiElements.AntiAFKBlockRemote = UI.Sections.AntiAFK:Toggle({
            Name = "Block AFK Remote",
            Default = MovementEnhancements.Config.AntiAFK.BlockAFKRemote,
            Callback = function(value)
                AntiAFK.SetBlockAFKRemote(value)
            end
        }, "AntiAFKBlockRemote")
        
        uiElements.AntiAFKKey = UI.Sections.AntiAFK:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.AntiAFK.ToggleKey,
            Callback = function(value)
                AntiAFKStatus.Key = value
                MovementEnhancements.Config.AntiAFK.ToggleKey = value
                if isInputFocused() then return end
                if AntiAFKStatus.Enabled then
                    if AntiAFKStatus.Running then AntiAFK.Stop() else AntiAFK.Start() end
                else
                    notify("AntiAFK", "Enable AntiAFK to use keybind.", true)
                end
            end
        }, "AntiAFKKey")
    end

    -- Config Sync Section
    local localconfigSection = UI.Tabs.Config:Section({ Name = "Movement Enhancements Sync", Side = "Right" })
    localconfigSection:Header({ Name = "LocalPlayer Settings Sync" })
    localconfigSection:Button({
        Name = "Sync Config",
        Callback = function()
            -- Timer
            if uiElements.TimerEnabled then
                MovementEnhancements.Config.Timer.Enabled = uiElements.TimerEnabled:GetState()
                MovementEnhancements.Config.Timer.Speed = uiElements.TimerSpeed:GetValue()
                MovementEnhancements.Config.Timer.ToggleKey = uiElements.TimerKey:GetBind()
            end

            -- Disabler
            if uiElements.DisablerEnabled then
                MovementEnhancements.Config.Disabler.Enabled = uiElements.DisablerEnabled:GetState()
                MovementEnhancements.Config.Disabler.ToggleKey = uiElements.DisablerKey:GetBind()
            end

            -- Speed
            if uiElements.SpeedEnabled then
                MovementEnhancements.Config.Speed.Enabled = uiElements.SpeedEnabled:GetState()
                MovementEnhancements.Config.Speed.AutoJump = uiElements.SpeedAutoJump:GetState()
                if uiElements.SpeedMethod then
                    local speedMethodOptions = uiElements.SpeedMethod:GetOptions()
                    for option, selected in pairs(speedMethodOptions) do
                        if selected then
                            MovementEnhancements.Config.Speed.Method = option
                            break
                        end
                    end
                end
                MovementEnhancements.Config.Speed.Speed = uiElements.Speed:GetValue()
                MovementEnhancements.Config.Speed.JumpInterval = uiElements.SpeedJumpInterval:GetValue()
                MovementEnhancements.Config.Speed.PulseTPDist = uiElements.SpeedPulseTPDistance:GetValue()
                MovementEnhancements.Config.Speed.PulseTPDelay = uiElements.SpeedPulseTPFrequency:GetValue()
                MovementEnhancements.Config.Speed.SmoothnessFactor = uiElements.SpeedSmoothnessFactor:GetValue()
                MovementEnhancements.Config.Speed.ToggleKey = uiElements.SpeedKey:GetBind()
            end

            -- Fly
            if uiElements.FlyEnabled then
                MovementEnhancements.Config.Fly.Enabled = uiElements.FlyEnabled:GetState()
                MovementEnhancements.Config.Fly.Speed = uiElements.FlySpeed:GetValue()
                MovementEnhancements.Config.Fly.VerticalSpeed = uiElements.FlyVerticalSpeed:GetValue()
                if uiElements.FlyVerticalKeys then
                    local flyVerticalKeysOptions = uiElements.FlyVerticalKeys:GetOptions()
                    for option, selected in pairs(flyVerticalKeysOptions) do
                        if selected then
                            MovementEnhancements.Config.Fly.VerticalKeys = option
                            break
                        end
                    end
                end
                MovementEnhancements.Config.Fly.NoClip = uiElements.FlyNoClip:GetState()
                MovementEnhancements.Config.Fly.ToggleKey = uiElements.FlyKey:GetBind()
            end

            -- InfStamina
            if uiElements.InfStaminaEnabled then
                MovementEnhancements.Config.InfStamina.Enabled = uiElements.InfStaminaEnabled:GetState()
                MovementEnhancements.Config.InfStamina.AlwaysSprint = uiElements.InfStaminaAlwaysSprint:GetState()
                MovementEnhancements.Config.InfStamina.RestoreGui = uiElements.InfStaminaRestoreGui:GetState()
                if uiElements.InfStaminaSprintKey then
                    local sprintKeyOptions = uiElements.InfStaminaSprintKey:GetOptions()
                    for option, selected in pairs(sprintKeyOptions) do
                        if selected then
                            MovementEnhancements.Config.InfStamina.SprintKey = Enum.KeyCode[option]
                            break
                        end
                    end
                end
                MovementEnhancements.Config.InfStamina.ToggleKey = uiElements.InfStaminaKey:GetBind()
            end

            -- AntiAFK
            if uiElements.AntiAFKEnabled then
                MovementEnhancements.Config.AntiAFK.Enabled = uiElements.AntiAFKEnabled:GetState()
                MovementEnhancements.Config.AntiAFK.CustomAFKTime = uiElements.AntiAFKTime:GetValue()
                MovementEnhancements.Config.AntiAFK.ShowWarning = uiElements.AntiAFKShowWarning:GetState()
                MovementEnhancements.Config.AntiAFK.BlockAFKRemote = uiElements.AntiAFKBlockRemote:GetState()
                MovementEnhancements.Config.AntiAFK.ToggleKey = uiElements.AntiAFKKey:GetBind()
            end

            -- Apply changes
            TimerStatus.Enabled = MovementEnhancements.Config.Timer.Enabled
            TimerStatus.Speed = MovementEnhancements.Config.Timer.Speed
            TimerStatus.Key = MovementEnhancements.Config.Timer.ToggleKey
            if TimerStatus.Enabled then
                if not TimerStatus.Running then Timer.Start() end
            else
                if TimerStatus.Running then Timer.Stop() end
            end

            DisablerStatus.Enabled = MovementEnhancements.Config.Disabler.Enabled
            DisablerStatus.Key = MovementEnhancements.Config.Disabler.ToggleKey
            if DisablerStatus.Enabled then
                if not DisablerStatus.Running then Disabler.Start() end
            else
                if DisablerStatus.Running then Disabler.Stop() end
            end

            SpeedStatus.Enabled = MovementEnhancements.Config.Speed.Enabled
            SpeedStatus.AutoJump = MovementEnhancements.Config.Speed.AutoJump
            SpeedStatus.Method = MovementEnhancements.Config.Speed.Method
            SpeedStatus.Speed = MovementEnhancements.Config.Speed.Speed
            SpeedStatus.JumpInterval = MovementEnhancements.Config.Speed.JumpInterval
            SpeedStatus.PulseTPDistance = MovementEnhancements.Config.Speed.PulseTPDist
            SpeedStatus.PulseTPFrequency = MovementEnhancements.Config.Speed.PulseTPDelay
            SpeedStatus.SmoothnessFactor = MovementEnhancements.Config.Speed.SmoothnessFactor
            SpeedStatus.Key = MovementEnhancements.Config.Speed.ToggleKey
            if SpeedStatus.Enabled then
                if not SpeedStatus.Running then Speed.Start() end
            else
                if SpeedStatus.Running then Speed.Stop() end
            end

            FlyStatus.Enabled = MovementEnhancements.Config.Fly.Enabled
            FlyStatus.Speed = MovementEnhancements.Config.Fly.Speed
            FlyStatus.VerticalSpeed = MovementEnhancements.Config.Fly.VerticalSpeed
            FlyStatus.VerticalKeys = MovementEnhancements.Config.Fly.VerticalKeys
            FlyStatus.NoClip = MovementEnhancements.Config.Fly.NoClip
            FlyStatus.Key = MovementEnhancements.Config.Fly.ToggleKey
            if FlyStatus.Enabled then
                if not FlyStatus.Running then 
                    Fly.Stop()
                    Fly.Start()
                end
            else
                if FlyStatus.Running then Fly.Stop() end
            end

            InfStaminaStatus.Enabled = MovementEnhancements.Config.InfStamina.Enabled
            InfStaminaStatus.AlwaysSprint = MovementEnhancements.Config.InfStamina.AlwaysSprint
            InfStaminaStatus.RestoreGui = MovementEnhancements.Config.InfStamina.RestoreGui
            InfStaminaStatus.SprintKey = MovementEnhancements.Config.InfStamina.SprintKey
            InfStaminaStatus.Key = MovementEnhancements.Config.InfStamina.ToggleKey
            if InfStaminaStatus.Enabled then
                if not InfStaminaStatus.Running then InfStamina.Start() end
            else
                if InfStaminaStatus.Running then InfStamina.Stop() end
            end

            AntiAFKStatus.Enabled = MovementEnhancements.Config.AntiAFK.Enabled
            AntiAFKStatus.CustomAFKTime = MovementEnhancements.Config.AntiAFK.CustomAFKTime
            AntiAFKStatus.ShowWarning = MovementEnhancements.Config.AntiAFK.ShowWarning
            AntiAFKStatus.BlockAFKRemote = MovementEnhancements.Config.AntiAFK.BlockAFKRemote
            AntiAFKStatus.Key = MovementEnhancements.Config.AntiAFK.ToggleKey
            if AntiAFKStatus.Enabled then
                if not AntiAFKStatus.Running then AntiAFK.Start() end
            else
                if AntiAFKStatus.Running then AntiAFK.Stop() end
            end

            notify("Syllinse", "Config synchronized!", true)
        end
    })
end

-- Main Initialization
function MovementEnhancements.Init(UI, coreParam, notifyFunc)
    core = coreParam
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer

    -- Global functions
    _G.setTimerSpeed = Timer.SetSpeed
    _G.setSpeed = Speed.SetSpeed
    _G.setFlySpeed = Fly.SetSpeed
    _G.setFlyVerticalSpeed = Fly.SetVerticalSpeed
    _G.setFlyVerticalKeys = Fly.SetVerticalKeys
    _G.setInfStaminaSprintKey = InfStamina.SetSprintKey
    _G.setAntiAFKTime = AntiAFK.SetAFKTime

    -- Character added connections
    if LocalPlayerObj then
        local function handleCharacterChange()
            task.wait(0.5)
            
            if DisablerStatus.Enabled then
                Disabler.DisableSignals(LocalPlayerObj.Character)
            end
            if SpeedStatus.Enabled then
                Speed.Start()
            end
            if FlyStatus.Enabled then
                Fly.Stop()
                task.wait(0.2)
                Fly.Start()
            end
            if InfStaminaStatus.Enabled then
                task.wait(1)
                InfStamina.Start()
            end
        end
        
        LocalPlayerObj.CharacterAdded:Connect(handleCharacterChange)
        
        -- Handle initial character
        if LocalPlayerObj.Character then
            task.spawn(handleCharacterChange)
        end
    end

    SetupUI(UI)
end

-- Cleanup function
function MovementEnhancements:Destroy()
    -- Timer
    Timer.Stop()
    
    -- Disabler
    Disabler.Stop()
    
    -- Speed
    Speed.Stop()
    
    -- Fly
    Fly.Stop()
    
    -- InfStamina
    InfStamina.Stop()
    
    -- AntiAFK
    AntiAFK.Stop()
    
    notify("MovementEnhancements", "All modules stopped", true)
end

return MovementEnhancements
