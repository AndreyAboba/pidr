-- [v35.43] AUTO SHOOT + AUTO PICKUP + FIXED DRAWING + DEBUG TEXT
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local BallAttachment = Character:WaitForChild("ball")
local Humanoid = Character:WaitForChild("Humanoid")

local Shooter = ReplicatedStorage.Remotes:WaitForChild("ShootTheBaII")
local PickupRemote
for _, r in ReplicatedStorage.Remotes:GetChildren() do
    if r:IsA("RemoteEvent") and r:GetAttribute("Attribute") then
        PickupRemote = r; break
    end
end

-- === АНИМАЦИЯ ===
local Animations = ReplicatedStorage:WaitForChild("Animations")
local RShootAnim = Humanoid:LoadAnimation(Animations:WaitForChild("RShoot"))
RShootAnim.Priority = Enum.AnimationPriority.Action4
local IsAnimating = false
local AnimationHoldTime = 0.6

-- === CONFIG ===
local AutoShootConfig = {
    Enabled = true,
    Legit = true,
    ManualShot = true,
    ShootKey = Enum.KeyCode.E,
    MaxDistance = 160,
    Inset = 2,
    Gravity = 110,
    MinPower = 4.0,
    MaxPower = 7.0,
    PowerPerStud = 0.025,
    MaxHeight = 100.0,
    DebugText = true  -- Новая настройка
}

local AutoPickupConfig = {
    Enabled = true,
    PickupDist = 180,
    SpoofValue = 2.8
}

-- === STATUS ===
local AutoShootStatus = {
    Running = false,
    Connection = nil,
    Key = AutoShootConfig.ShootKey,
    ManualShot = AutoShootConfig.ManualShot
}

local AutoPickupStatus = {
    Running = false,
    Connection = nil
}

-- === ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ДЛЯ DRAWING ===
local Gui = {}
local TargetCube, GoalCube, NoSpinCube = {}, {}, {}
local RenderConnection = nil
local HeartbeatConnection = nil

-- === ИНИЦИАЛИЗАЦИЯ GUI ===
local function SetupGUI()
    -- Очистка старого GUI
    for _, obj in pairs(Gui) do
        if obj and obj.Remove then
            pcall(function() obj:Remove() end)
        end
    end
    
    local s = Camera.ViewportSize
    local cx, y = s.X / 2, s.Y * 0.48
    Gui = {
        Status = Drawing.new("Text"), Dist = Drawing.new("Text"), Target = Drawing.new("Text"),
        Power = Drawing.new("Text"), Spin = Drawing.new("Text"), GK = Drawing.new("Text"),
        Debug = Drawing.new("Text"), Mode = Drawing.new("Text")
    }
    
    for i, v in ipairs({Gui.Status, Gui.Dist, Gui.Target, Gui.Power, Gui.Spin, Gui.GK, Gui.Debug, Gui.Mode}) do
        v.Size = 18
        v.Color = Color3.fromRGB(255, 255, 255)
        v.Outline = true
        v.Center = true
        v.Position = Vector2.new(cx, y + (i-1)*20)
        v.Visible = AutoShootConfig.DebugText
    end
    
    Gui.Status.Text = "v35.43: Ready"
    Gui.Dist.Text = "Dist: --"
    Gui.Target.Text = "Target: --"
    Gui.Power.Text = "Power: --"
    Gui.Spin.Text = "Spin: --"
    Gui.GK.Text = "GK: --"
    Gui.Debug.Text = "Debug: Active"
    UpdateModeText()
end

-- === ОЧИСТКА КУБОВ ===
local function ClearCubes()
    for i = 1, 12 do
        if TargetCube[i] then
            pcall(function() TargetCube[i]:Remove() end)
            TargetCube[i] = nil
        end
        if GoalCube[i] then
            pcall(function() GoalCube[i]:Remove() end)
            GoalCube[i] = nil
        end
        if NoSpinCube[i] then
            pcall(function() NoSpinCube[i]:Remove() end)
            NoSpinCube[i] = nil
        end
    end
end

-- === ИНИЦИАЛИЗАЦИЯ КУБОВ ===
local function InitializeCubes()
    ClearCubes()
    TargetCube = {}
    GoalCube = {}
    NoSpinCube = {}
    
    for i = 1, 12 do
        TargetCube[i] = Drawing.new("Line")
        GoalCube[i] = Drawing.new("Line")
        NoSpinCube[i] = Drawing.new("Line")
    end
    
    local function SetupCube(cube, color, thickness)
        for _, line in ipairs(cube) do
            if line then
                line.Color = color
                line.Thickness = thickness or 2
                line.Transparency = 0.7
                line.ZIndex = 1000
                line.Visible = false
            end
        end
    end
    
    SetupCube(TargetCube, Color3.fromRGB(0, 255, 0), 6)
    SetupCube(GoalCube, Color3.fromRGB(255, 0, 0), 4)
    SetupCube(NoSpinCube, Color3.fromRGB(0, 255, 255), 5)
end

-- === DrawOrientedCube ===
local function DrawOrientedCube(cube, cframe, size)
    if not cframe or not size then
        for _, line in ipairs(cube) do 
            if line then line.Visible = false end 
        end
        return
    end
    
    pcall(function()
        local half = size / 2
        local corners = {
            cframe * Vector3.new(-half.X, -half.Y, -half.Z),
            cframe * Vector3.new(half.X, -half.Y, -half.Z),
            cframe * Vector3.new(half.X, half.Y, -half.Z),
            cframe * Vector3.new(-half.X, half.Y, -half.Z),
            cframe * Vector3.new(-half.X, -half.Y, half.Z),
            cframe * Vector3.new(half.X, -half.Y, half.Z),
            cframe * Vector3.new(half.X, half.Y, half.Z),
            cframe * Vector3.new(-half.X, half.Y, half.Z)
        }
        local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
        
        for i, edge in ipairs(edges) do
            local a, b = corners[edge[1]], corners[edge[2]]
            local aScreen, aVis = Camera:WorldToViewportPoint(a)
            local bScreen, bVis = Camera:WorldToViewportPoint(b)
            local line = cube[i]
            if line and aVis and bVis and aScreen.Z > 0 and bScreen.Z > 0 then
                line.From = Vector2.new(aScreen.X, aScreen.Y)
                line.To = Vector2.new(bScreen.X, bScreen.Y)
                line.Visible = true
            else
                if line then line.Visible = false end
            end
        end
    end)
end

-- === GetKeyName + UpdateModeText ===
local function GetKeyName(key)
    if key == Enum.KeyCode.Unknown then return "None" end
    local name = tostring(key):match("KeyCode%.(.+)") or tostring(key)
    local pretty = {
        LeftMouse = "LMB", RightMouse = "RMB", MiddleMouse = "MMB",
        Space = "Space", LeftShift = "LShift", RightShift = "RShift",
        LeftControl = "LCtrl", RightControl = "RCtrl",
        LeftAlt = "LAlt", RightAlt = "RAlt"
    }
    return pretty[name] or name
end

function UpdateModeText()
    if not Gui.Mode then return end
    Gui.Mode.Text = AutoShootStatus.ManualShot and 
        string.format("Mode: Manual (%s)", GetKeyName(AutoShootStatus.Key)) or "Mode: Auto"
end

-- === ЛОГИКА ЦЕЛЕЙ (упрощенная) ===
local GoalCFrame, GoalWidth, GoalHeight
local TargetPoint, ShootDir, ShootVel, CurrentSpin, CurrentPower, CurrentType, NoSpinPoint
local LastShoot = 0
local CanShoot = true

local function GetMyTeam()
    local stats = Workspace:FindFirstChild("PlayerStats")
    if not stats then return nil, nil end
    if stats:FindFirstChild("Away") and stats.Away:FindFirstChild(LocalPlayer.Name) then return "Away", "HomeGoal"
    elseif stats:FindFirstChild("Home") and stats.Home:FindFirstChild(LocalPlayer.Name) then return "Home", "AwayGoal" end
    return nil, nil
end

local function UpdateGoal()
    local myTeam, enemyGoalName = GetMyTeam()
    if not enemyGoalName then return nil, nil end
    local goalFolder = Workspace:FindFirstChild(enemyGoalName)
    if not goalFolder then return nil, nil end
    local frame = goalFolder:FindFirstChild("Frame")
    if not frame then return nil, nil end
    local left, right, crossbar = frame:FindFirstChild("LeftPost"), frame:FindFirstChild("RightPost"), frame:FindFirstChild("Crossbar")
    if not (left and right and crossbar) then return nil, nil end
    local center = (left.Position + right.Position) / 2
    local forward = (center - crossbar.Position).Unit
    local up = crossbar.Position.Y > left.Position.Y and Vector3.yAxis or -Vector3.yAxis
    local rightDir = (right.Position - left.Position).Unit
    GoalCFrame = CFrame.fromMatrix(center, rightDir, up, -forward)
    GoalWidth = (left.Position - right.Position).Magnitude
    GoalHeight = math.abs(crossbar.Position.Y - left.Position.Y)
    return GoalWidth, GoalHeight
end

local function CalculateTarget()
    local width = UpdateGoal()
    if not GoalCFrame or not width then 
        TargetPoint = nil; NoSpinPoint = nil
        if Gui.Target then Gui.Target.Text = "Target: --" end
        if Gui.Power then Gui.Power.Text = "Power: --" end
        if Gui.Spin then Gui.Spin.Text = "Spin: --" end
        return 
    end

    local dist = (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude
    if Gui.Dist then Gui.Dist.Text = string.format("Dist: %.1f (Max: %.1f)", dist, AutoShootConfig.MaxDistance) end
    if dist > AutoShootConfig.MaxDistance then 
        TargetPoint = nil; NoSpinPoint = nil
        if Gui.Target then Gui.Target.Text = "Target: --" end
        if Gui.Power then Gui.Power.Text = "Power: --" end
        if Gui.Spin then Gui.Spin.Text = "Spin: --" end
        return 
    end

    local halfWidth = (GoalWidth / 2) - AutoShootConfig.Inset
    local targetSide = 1  -- Простая логика
    local x = targetSide * halfWidth * 0.9
    local power = math.clamp(AutoShootConfig.MinPower + dist * AutoShootConfig.PowerPerStud, AutoShootConfig.MinPower, AutoShootConfig.MaxPower)
    local height = 5 + dist * 0.05
    local spin = dist >= 110 and (targetSide > 0 and "Right" or "Left") or "None"

    local worldPos = GoalCFrame * Vector3.new(x, height, 0)
    local noSpinPos = GoalCFrame * Vector3.new(x, height, 0)

    TargetPoint = worldPos
    NoSpinPoint = noSpinPos
    CurrentSpin = spin
    CurrentType = "Smart"
    CurrentPower = power
    ShootDir = (worldPos - HumanoidRootPart.Position).Unit
    ShootVel = ShootDir * (power * 1400)

    if Gui.Target then Gui.Target.Text = "Target: " .. CurrentType end
    if Gui.Power then Gui.Power.Text = "Power: " .. string.format("%.2f", power) end
    if Gui.Spin then Gui.Spin.Text = "Spin: " .. spin end
end

-- === AUTO SHOOT ===
local AutoShoot = {}

AutoShoot.Start = function()
    if AutoShootStatus.Running then return end
    AutoShootStatus.Running = true

    -- Инициализация Drawing
    if AutoShootConfig.DebugText then
        SetupGUI()
        InitializeCubes()
    end

    -- Heartbeat для логики
    HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not AutoShootConfig.Enabled then return end
        
        pcall(CalculateTarget)

        local ball = Workspace:FindFirstChild("ball")
        local hasBall = ball and ball:FindFirstChild("playerWeld") and ball.creator.Value == LocalPlayer
        local dist = GoalCFrame and (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude or 999

        -- Обновление статуса
        if AutoShootConfig.DebugText and Gui.Status then
            if hasBall and TargetPoint and dist <= AutoShootConfig.MaxDistance then
                Gui.Status.Text = AutoShootStatus.ManualShot and 
                    "Ready (Press " .. GetKeyName(AutoShootStatus.Key) .. ")" or "Aiming..."
                Gui.Status.Color = Color3.fromRGB(0,255,0)
            elseif hasBall then
                Gui.Status.Text = dist > AutoShootConfig.MaxDistance and "Too Far" or "No Target"
                Gui.Status.Color = Color3.fromRGB(255,100,0)
            else
                Gui.Status.Text = "No Ball"
                Gui.Status.Color = Color3.fromRGB(255,165,0)
            end
        end

        -- Авто-выстрел
        if hasBall and TargetPoint and dist <= AutoShootConfig.MaxDistance and not AutoShootStatus.ManualShot and tick() - LastShoot >= 0.3 then
            if AutoShootConfig.Legit and not IsAnimating then
                IsAnimating = true
                RShootAnim:Play()
                task.delay(AnimationHoldTime, function() IsAnimating = false end)
            end
            pcall(function()
                Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
            end)
            LastShoot = tick()
            if AutoShootConfig.DebugText and Gui.Status then
                Gui.Status.Text = "AUTO SHOT! [" .. CurrentType .. "]"
                Gui.Status.Color = Color3.fromRGB(0,255,0)
            end
        end
    end)

    -- RenderStepped для кубов
    RenderConnection = RunService.RenderStepped:Connect(function()
        if not AutoShootConfig.DebugText then return end
        local width = UpdateGoal()
        if GoalCFrame and width and GoalCube[1] then 
            DrawOrientedCube(GoalCube, GoalCFrame, Vector3.new(width, GoalHeight, 2)) 
        end
        if TargetPoint and TargetCube[1] then 
            DrawOrientedCube(TargetCube, CFrame.new(TargetPoint), Vector3.new(4,4,4)) 
        end
        if NoSpinPoint and NoSpinCube[1] then 
            DrawOrientedCube(NoSpinCube, CFrame.new(NoSpinPoint), Vector3.new(3,3,3)) 
        end
    end)

    -- Ручной выстрел
    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp or not AutoShootConfig.Enabled or not AutoShootStatus.ManualShot or not CanShoot then return end
        if inp.KeyCode == AutoShootStatus.Key then
            local ball = Workspace:FindFirstChild("ball")
            local hasBall = ball and ball:FindFirstChild("playerWeld") and ball.creator.Value == LocalPlayer
            if hasBall and TargetPoint then
                pcall(CalculateTarget)
                if ShootDir then
                    if AutoShootConfig.Legit and not IsAnimating then
                        IsAnimating = true
                        RShootAnim:Play()
                        task.delay(AnimationHoldTime, function() IsAnimating = false end)
                    end
                    pcall(function()
                        Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
                    end)
                    LastShoot = tick()
                    CanShoot = false
                    task.delay(0.3, function() CanShoot = true end)
                    if AutoShootConfig.DebugText and Gui.Status then
                        Gui.Status.Text = "MANUAL SHOT! [" .. CurrentType .. "]"
                        Gui.Status.Color = Color3.fromRGB(0,255,0)
                    end
                end
            end
        end
    end)

    notify("AutoShoot", "Started", true)
end

AutoShoot.Stop = function()
    if HeartbeatConnection then HeartbeatConnection:Disconnect(); HeartbeatConnection = nil end
    if RenderConnection then RenderConnection:Disconnect(); RenderConnection = nil end
    AutoShootStatus.Running = false
    
    -- Полная очистка Drawing
    for _, obj in pairs(Gui) do
        if obj and obj.Remove then
            pcall(function() obj:Remove() end)
        end
    end
    ClearCubes()
    
    notify("AutoShoot", "Stopped", true)
end

-- === AUTO PICKUP ===
local AutoPickup = {}
AutoPickup.Start = function()
    if AutoPickupStatus.Running then return end
    AutoPickupStatus.Running = true
    AutoPickupStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoPickupConfig.Enabled or not PickupRemote then return end
        local ball = Workspace:FindFirstChild("ball")
        if not ball or ball:FindFirstChild("playerWeld") then return end
        if (HumanoidRootPart.Position - ball.Position).Magnitude <= AutoPickupConfig.PickupDist then
            pcall(function() PickupRemote:FireServer(AutoPickupConfig.SpoofValue) end)
        end
    end)
    notify("AutoPickup", "Started", true)
end

AutoPickup.Stop = function()
    if AutoPickupStatus.Connection then AutoPickupStatus.Connection:Disconnect(); AutoPickupStatus.Connection = nil end
    AutoPickupStatus.Running = false
    notify("AutoPickup", "Stopped", true)
end

-- === UI SETUP ===
local uiElements = {}
local function SetupUI(UI)
    if UI.Sections.AutoShoot then
        UI.Sections.AutoShoot:Header({ Name = "AutoShoot" })
        uiElements.AutoShootEnabled = UI.Sections.AutoShoot:Toggle({
            Name = "Enabled",
            Default = AutoShootConfig.Enabled,
            Callback = function(v) 
                AutoShootConfig.Enabled = v
                if v then AutoShoot.Start() else AutoShoot.Stop() end 
            end
        }, "AutoShootEnabled")

        uiElements.AutoShootDebug = UI.Sections.AutoShoot:Toggle({
            Name = "Debug Text",
            Default = AutoShootConfig.DebugText,
            Callback = function(v)
                AutoShootConfig.DebugText = v
                if AutoShootStatus.Running then
                    AutoShoot.Stop()
                    AutoShoot.Start()
                end
            end
        }, "AutoShootDebug")

        uiElements.AutoShootLegit = UI.Sections.AutoShoot:Toggle({
            Name = "Legit Animation",
            Default = AutoShootConfig.Legit,
            Callback = function(v) AutoShootConfig.Legit = v end
        }, "AutoShootLegit")

        uiElements.AutoShootManual = UI.Sections.AutoShoot:Toggle({
            Name = "Manual Shot",
            Default = AutoShootConfig.ManualShot,
            Callback = function(v)
                AutoShootStatus.ManualShot = v
                AutoShootConfig.ManualShot = v
                UpdateModeText()
            end
        }, "AutoShootManual")

        uiElements.AutoShootKey = UI.Sections.AutoShoot:Keybind({
            Name = "Shoot Key",
            Default = AutoShootConfig.ShootKey,
            Callback = function(v)
                AutoShootStatus.Key = v
                AutoShootConfig.ShootKey = v
                UpdateModeText()  -- СРАЗУ обновляем текст
            end
        }, "AutoShootKey")

        uiElements.AutoShootMaxDist = UI.Sections.AutoShoot:Slider({
            Name = "Max Distance",
            Minimum = 50, Maximum = 300, Default = AutoShootConfig.MaxDistance, Precision = 1,
            Callback = function(v) AutoShootConfig.MaxDistance = v end
        }, "AutoShootMaxDist")
    end

    if UI.Sections.AutoPickup then
        UI.Sections.AutoPickup:Header({ Name = "AutoPickup" })
        uiElements.AutoPickupEnabled = UI.Sections.AutoPickup:Toggle({
            Name = "Enabled",
            Default = AutoPickupConfig.Enabled,
            Callback = function(v) 
                AutoPickupConfig.Enabled = v
                if v then AutoPickup.Start() else AutoPickup.Stop() end 
            end
        }, "AutoPickupEnabled")
        uiElements.AutoPickupDist = UI.Sections.AutoPickup:Slider({
            Name = "Pickup Distance", Minimum = 50, Maximum = 300, Default = AutoPickupConfig.PickupDist, Precision = 1,
            Callback = function(v) AutoPickupConfig.PickupDist = v end
        }, "AutoPickupDist")
        uiElements.AutoPickupSpoof = UI.Sections.AutoPickup:Slider({
            Name = "Spoof Value", Minimum = 0.1, Maximum = 5.0, Default = AutoPickupConfig.SpoofValue, Precision = 2,
            Callback = function(v) AutoPickupConfig.SpoofValue = v end
        }, "AutoPickupSpoof")
    end

    -- Sync
    local syncSection = UI.Tabs.Config:Section({ Name = "AutoShoot Sync", Side = "Right" })
    syncSection:Button({
        Name = "Sync Config",
        Callback = function()
            AutoShootConfig.Enabled = uiElements.AutoShootEnabled:GetState()
            AutoShootConfig.DebugText = uiElements.AutoShootDebug:GetState()
            AutoShootConfig.Legit = uiElements.AutoShootLegit:GetState()
            AutoShootConfig.ManualShot = uiElements.AutoShootManual:GetState()
            AutoShootConfig.ShootKey = uiElements.AutoShootKey:GetBind()
            AutoShootConfig.MaxDistance = uiElements.AutoShootMaxDist:GetValue()

            AutoPickupConfig.Enabled = uiElements.AutoPickupEnabled:GetState()
            AutoPickupConfig.PickupDist = uiElements.AutoPickupDist:GetValue()
            AutoPickupConfig.SpoofValue = uiElements.AutoPickupSpoof:GetValue()

            AutoShootStatus.Key = AutoShootConfig.ShootKey
            AutoShootStatus.ManualShot = AutoShootConfig.ManualShot
            UpdateModeText()

            if AutoShootConfig.Enabled then AutoShoot.Start() else AutoShoot.Stop() end
            if AutoPickupConfig.Enabled then AutoPickup.Start() else AutoPickup.Stop() end

            notify("Syllinse", "Config synchronized!", true)
        end
    })
end

-- === МОДУЛЬ ===
local AutoShootModule = {}

function AutoShootModule.Init(UI, coreParam, notifyFunc)
    core = coreParam
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer

    SetupUI(UI)

    LocalPlayerObj.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
        BallAttachment = newChar:WaitForChild("ball")
        RShootAnim = Humanoid:LoadAnimation(Animations:WaitForChild("RShoot"))
        RShootAnim.Priority = Enum.AnimationPriority.Action4
        GoalCFrame = nil; TargetPoint = nil; NoSpinPoint = nil
        LastShoot = 0; IsAnimating = false; CanShoot = true
    end)
end

function AutoShootModule:Destroy()
    AutoShoot.Stop()
    AutoPickup.Stop()
end

return AutoShootModule
