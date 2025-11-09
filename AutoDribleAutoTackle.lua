local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
print('2')
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
local Camera = workspace.CurrentCamera

local v_u_2 = Character
local v_u_4 = HumanoidRootPart
local v_u_13 = Humanoid

local ActionRemote = ReplicatedStorage.Remotes:WaitForChild("Action")
local SoftDisPlayerRemote = ReplicatedStorage.Remotes:WaitForChild("SoftDisPlayer")

local Animations = ReplicatedStorage:WaitForChild("Animations")
local DribbleAnims = Animations:WaitForChild("Dribble")
local TackleAnims = Animations:WaitForChild("TackleAnims")

local DribbleAnimIds = {}
local TackleAnimIds = {}

-- собираем только Dribble-анимации (для IsDribbling)
for _, anim in pairs(DribbleAnims:GetChildren()) do
    if anim:IsA("Animation") then
        table.insert(DribbleAnimIds, anim.AnimationId)
    end
end

-- === КОНФИГ ===
local AutoTackleConfig = {
    Enabled = true,
    MaxDistance = 20,
    TackleDistance = 0,
    OptimalDistanceMin = 3,
    OptimalDistanceMax = 15,
    TackleSpeed = 47,
    PredictionTime = 0.8,
    OnlyPlayer = true,
    RotationMethod = "Snap",
    RotationType = "CFrame",
    MaxAngle = 360,
    EagleEyeExceptions = "OnlyDribble",
    DribbleDelay = "Delay",
    DribbleDelayTime = 0,
    EagleEyeMinDelay = 0.1,
    EagleEyeMaxDelay = 1.0,
    DebugText = true,
    TextPosition = {X = 0.5, Y = 0.6}
}

local AutoDribbleConfig = {
    Enabled = true,
    MaxDribbleDistance = 30,
    DribbleActivationDistance = 16,
    MaxAngle = 360,
    MaxPredictionAngle = 38,
    TacklePredictionTime = 0.3,
    TackleAngleThreshold = 0.7,
    DebugText = true,
    TextPosition = {X = 0.5, Y = 0.55}
}

-- === СОСТОЯНИЯ ===
local AutoTackleStatus = {
    Running = false,
    Connection = nil,
    RenderConnection = nil,
    DebugText = AutoTackleConfig.DebugText
}

local AutoDribbleStatus = {
    Running = false,
    Connection = nil,
    RenderConnection = nil,
    DebugText = AutoDribbleConfig.DebugText
}

local DribbleStates = {}
local TackleStates = {}
local PrecomputedPlayers = {}
local HasBall = false
local CanDribbleNow = false
local EagleEyeWaitStart = nil
local EagleEyeWaitTime = 0

-- === GUI (Drawing) - ОТДЕЛЬНЫЕ ДЛЯ TACKLE И DRIBBLE ===
local TackleGui = {}
local DribbleGui = {}
local function SetupTackleGUI()
    TackleGui = {
        WaitLabel = Drawing.new("Text"),
        TargetLabel = Drawing.new("Text"),
        DribblingLabel = Drawing.new("Text"),
        TacklingLabel = Drawing.new("Text"),
        EagleEyeLabel = Drawing.new("Text")
    }
    
    local s = Camera.ViewportSize
    local cx = s.X * AutoTackleConfig.TextPosition.X
    local y = s.Y * AutoTackleConfig.TextPosition.Y
    
    for i, v in ipairs({TackleGui.WaitLabel, TackleGui.TargetLabel, TackleGui.DribblingLabel, TackleGui.TacklingLabel, TackleGui.EagleEyeLabel}) do
        v.Size = 18
        v.Color = Color3.fromRGB(255, 255, 255)
        v.Outline = true
        v.Center = true
        v.Position = Vector2.new(cx, y + (i-1)*20)
        v.Visible = AutoTackleStatus.DebugText
    end
    
    TackleGui.WaitLabel.Color = Color3.fromRGB(255, 165, 0)
    TackleGui.WaitLabel.Text = "Wait: 0.00"
    TackleGui.TargetLabel.Text = "Target: None"
    TackleGui.DribblingLabel.Text = "isDribbling: false"
    TackleGui.TacklingLabel.Text = "isTackling: false"
    TackleGui.EagleEyeLabel.Text = "EagleEye: Idle"
end

local function SetupDribbleGUI()
    DribbleGui = {
        StatusLabel = Drawing.new("Text"),
        TargetLabel = Drawing.new("Text"),
        TacklingLabel = Drawing.new("Text"),
        AutoDribbleLabel = Drawing.new("Text")
    }
    
    local s = Camera.ViewportSize
    local cx = s.X * AutoDribbleConfig.TextPosition.X
    local y = s.Y * AutoDribbleConfig.TextPosition.Y
    
    for i, v in ipairs({DribbleGui.StatusLabel, DribbleGui.TargetLabel, DribbleGui.TacklingLabel, DribbleGui.AutoDribbleLabel}) do
        v.Size = 18
        v.Color = Color3.fromRGB(255, 255, 255)
        v.Outline = true
        v.Center = true
        v.Position = Vector2.new(cx, y + (i-1)*20)
        v.Visible = AutoDribbleStatus.DebugText
    end
    
    DribbleGui.StatusLabel.Text = "Dribble: Ready"
    DribbleGui.TargetLabel.Text = "Targets: 0"
    DribbleGui.TacklingLabel.Text = "Nearest: None"
    DribbleGui.AutoDribbleLabel.Text = "AutoDribble: Idle"
end

local function ToggleTackleDebugText(value)
    AutoTackleStatus.DebugText = value
    AutoTackleConfig.DebugText = value
    if TackleGui.WaitLabel then
        TackleGui.WaitLabel.Visible = value
        TackleGui.TargetLabel.Visible = value
        TackleGui.DribblingLabel.Visible = value
        TackleGui.TacklingLabel.Visible = value
        TackleGui.EagleEyeLabel.Visible = value
    end
end

local function ToggleDribbleDebugText(value)
    AutoDribbleStatus.DebugText = value
    AutoDribbleConfig.DebugText = value
    if DribbleGui.StatusLabel then
        DribbleGui.StatusLabel.Visible = value
        DribbleGui.TargetLabel.Visible = value
        DribbleGui.TacklingLabel.Visible = value
        DribbleGui.AutoDribbleLabel.Visible = value
    end
end

-- ФУНКЦИЯ ПЕРЕМЕЩЕНИЯ ТЕКСТА
local function UpdateTackleTextPosition(x, y)
    AutoTackleConfig.TextPosition.X = x
    AutoTackleConfig.TextPosition.Y = y
    local s = Camera.ViewportSize
    local cx = s.X * x
    local py = s.Y * y
    TackleGui.WaitLabel.Position = Vector2.new(cx, py)
    TackleGui.TargetLabel.Position = Vector2.new(cx, py + 20)
    TackleGui.DribblingLabel.Position = Vector2.new(cx, py + 40)
    TackleGui.TacklingLabel.Position = Vector2.new(cx, py + 60)
    TackleGui.EagleEyeLabel.Position = Vector2.new(cx, py + 80)
end

local function UpdateDribbleTextPosition(x, y)
    AutoDribbleConfig.TextPosition.X = x
    AutoDribbleConfig.TextPosition.Y = y
    local s = Camera.ViewportSize
    local cx = s.X * x
    local py = s.Y * y
    DribbleGui.StatusLabel.Position = Vector2.new(cx, py)
    DribbleGui.TargetLabel.Position = Vector2.new(cx, py + 20)
    DribbleGui.TacklingLabel.Position = Vector2.new(cx, py + 40)
    DribbleGui.AutoDribbleLabel.Position = Vector2.new(cx, py + 60)
end

-- === 3D RING ===
local TargetRingLines = {}
local function InitializeRing()
    for i = 1, 24 do
        if TargetRingLines[i] and TargetRingLines[i].Remove then TargetRingLines[i]:Remove() end
        TargetRingLines[i] = Drawing.new("Line")
        TargetRingLines[i].Thickness = 3
        TargetRingLines[i].Color = Color3.fromRGB(255, 0, 0)
        TargetRingLines[i].Visible = false
    end
end

local function UpdateTargetRing(ball, distance)
    for _, line in ipairs(TargetRingLines) do line.Visible = false end
    if not ball or not ball.Parent then return end
    local center = ball.Position - Vector3.new(0, 0.5, 0)
    local radius = 2
    local segments = 24
    local points = {}
    for i = 1, segments do
        local angle = (i - 1) * 2 * math.pi / segments
        local point = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        table.insert(points, point)
    end
    for i, line in ipairs(TargetRingLines) do
        local startPoint = points[i]
        local endPoint = points[i % segments + 1]
        local startScreen, startOnScreen = Camera:WorldToViewportPoint(startPoint)
        local endScreen, endOnScreen = Camera:WorldToViewportPoint(endPoint)
        if startOnScreen and endOnScreen and startScreen.Z > 0.1 and endScreen.Z > 0.1 then
            line.From = Vector2.new(startScreen.X, startScreen.Y)
            line.To = Vector2.new(endScreen.X, endScreen.Y)
            if distance <= AutoTackleConfig.TackleDistance then
                line.Color = Color3.fromRGB(0, 255, 0)
            elseif distance <= AutoTackleConfig.OptimalDistanceMax then
                line.Color = Color3.fromRGB(255, 165, 0)
            else
                line.Color = Color3.fromRGB(255, 0, 0)
            end
            line.Visible = true
        end
    end
end

-- === ОСНОВНЫЕ ФУНКЦИИ ===
local SPECIFIC_TACKLE_ID = "rbxassetid://14317040670"

local function IsDribbling(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Parent or targetPlayer.TeamColor == LocalPlayer.TeamColor then return false end
    local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
    if not targetHumanoid then return false end
    local animator = targetHumanoid:FindFirstChild("Animator")
    if not animator then return false end
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Animation and table.find(DribbleAnimIds, track.Animation.AnimationId) then
            return true
        end
    end
    return false
end

local function IsSpecificTackle(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Parent or targetPlayer.TeamColor == LocalPlayer.TeamColor then return false end
    local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    local animator = humanoid:FindFirstChild("Animator")
    if not animator then return false end
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Animation and track.Animation.AnimationId == SPECIFIC_TACKLE_ID then
            return true
        end
    end
    return false
end

local function PrecomputePlayers()
    PrecomputedPlayers = {}
    HasBall = false
    CanDribbleNow = false

    local ball = workspace:FindFirstChild("ball")
    if ball and ball:FindFirstChild("playerWeld") and ball:FindFirstChild("creator") then
        HasBall = ball.creator.Value == LocalPlayer
    end

    local bools = workspace:FindFirstChild(LocalPlayer.Name) and workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if bools then
        CanDribbleNow = not bools.dribbleDebounce.Value
        if AutoDribbleStatus.DebugText and DribbleGui.StatusLabel then
            DribbleGui.StatusLabel.Text = bools.dribbleDebounce.Value and "Dribble: Cooldown" or "Dribble: Ready"
            DribbleGui.StatusLabel.Color = bools.dribbleDebounce.Value and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
        end
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Parent or player.TeamColor == LocalPlayer.TeamColor then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.HipHeight >= 4 then continue end
        local targetRoot = character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then continue end

        if not DribbleStates[player] then
            DribbleStates[player] = { IsDribbling = false, LastDribbleEnd = 0, CooldownUntil = 0, DelayTriggered = false }
        end
        local state = DribbleStates[player]
        local isDribblingNow = IsDribbling(player)
        if isDribblingNow and not state.IsDribbling then
            state.IsDribbling = true
        elseif not isDribblingNow and state.IsDribbling then
            state.LastDribbleEnd = tick()
            state.CooldownUntil = state.LastDribbleEnd + 3.0
            state.IsDribbling = false
            state.DelayTriggered = false
        end

        TackleStates[player] = TackleStates[player] or { IsTackling = false }
        TackleStates[player].IsTackling = IsSpecificTackle(player)

        local distance = (targetRoot.Position - v_u_4.Position).Magnitude
        if distance > AutoDribbleConfig.MaxDribbleDistance then continue end

        local predictedPos = targetRoot.Position + targetRoot.AssemblyLinearVelocity * AutoDribbleConfig.TacklePredictionTime
        local directionToPlayer = (v_u_4.Position - targetRoot.Position).Unit

        PrecomputedPlayers[player] = {
            Distance = distance,
            PredictedPos = predictedPos,
            IsValid = true,
            IsTackling = TackleStates[player].IsTackling,
            RootPart = targetRoot
        }
    end
end

local function CanTackle()
    local ball = workspace:FindFirstChild("ball")
    if not ball or not ball.Parent then return false, nil, nil, nil end
    local hasOwner = ball:FindFirstChild("playerWeld") and ball:FindFirstChild("creator")
    local owner = hasOwner and ball.creator.Value or nil
    if AutoTackleConfig.OnlyPlayer and (not hasOwner or not owner or not owner.Parent) then
        return false, nil, nil, nil
    end
    local isEnemy = not owner or (owner and owner.TeamColor ~= LocalPlayer.TeamColor)
    if not isEnemy then return false, nil, nil, nil end
    if workspace:FindFirstChild("Bools") and (workspace.Bools.APG.Value == LocalPlayer or workspace.Bools.HPG.Value == LocalPlayer) then
        return false, nil, nil, nil
    end
    local distance = (v_u_4.Position - ball.Position).Magnitude
    if distance > AutoTackleConfig.MaxDistance then
        return false, nil, nil, nil
    end
    if owner and owner.Character then
        local targetHumanoid = owner.Character:FindFirstChild("Humanoid")
        if targetHumanoid and targetHumanoid.HipHeight >= 4 then
            return false, nil, nil, nil
        end
    end
    local bools = workspace:FindFirstChild(LocalPlayer.Name) and workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if bools and (bools.TackleDebounce.Value or bools.Tackled.Value or v_u_2:FindFirstChild("Bools") and v_u_2.Bools.Debounce.Value) then
        return false, nil, nil, nil
    end
    return true, ball, distance, owner
end

local function PredictBallPosition(ball)
    if not ball or not ball.Parent then return nil end
    return ball.Position + ball.AssemblyLinearVelocity * AutoTackleConfig.PredictionTime
end

local function RotateToTarget(targetPos)
    local currentLook = v_u_4.CFrame.LookVector
    local targetDir = (targetPos - v_u_4.Position).Unit
    local angle = math.deg(math.acos(math.clamp(currentLook:Dot(targetDir), -1, 1)))
    if angle <= AutoTackleConfig.MaxAngle then
        if AutoTackleConfig.RotationType == "CFrame" then
            v_u_4.CFrame = CFrame.new(v_u_4.Position, targetPos)
        end
    end
end

local function PerformTackle(ball, owner)
    local bools = workspace:FindFirstChild(LocalPlayer.Name) and workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.TackleDebounce.Value or bools.Tackled.Value or v_u_2:FindFirstChild("Bools") and v_u_2.Bools.Debounce.Value then return end
    if AutoTackleConfig.RotationMethod == "Snap" and ball then
        local predictedPos = PredictBallPosition(ball) or ball.Position
        RotateToTarget(predictedPos)
    end
    pcall(function() ActionRemote:FireServer("TackIe") end)
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Parent = v_u_4
    bodyVelocity.Velocity = v_u_4.CFrame.LookVector * AutoTackleConfig.TackleSpeed
    bodyVelocity.MaxForce = Vector3.new(50000000, 0, 50000000)
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Parent = v_u_4
    bodyGyro.Name = "TackleGyro"
    bodyGyro.P = 950000
    bodyGyro.MaxTorque = Vector3.new(0, 100000, 0)
    bodyGyro.CFrame = v_u_4.CFrame
    Debris:AddItem(bodyVelocity, 0.65)
    Debris:AddItem(bodyGyro, 0.65)
    if owner and ball:FindFirstChild("playerWeld") then
        local distance = (v_u_4.Position - ball.Position).Magnitude
        pcall(function() SoftDisPlayerRemote:FireServer(owner, distance, false, ball.Size) end)
    end
end

local function PerformDribble()
    local bools = workspace:FindFirstChild(LocalPlayer.Name) and workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.dribbleDebounce.Value then return end
    pcall(function() ActionRemote:FireServer("Deke") end)
    if AutoDribbleStatus.DebugText and DribbleGui.StatusLabel then
        DribbleGui.StatusLabel.Text = "Dribble: Cooldown"
        DribbleGui.StatusLabel.Color = Color3.fromRGB(255, 0, 0)
    end
    if AutoDribbleStatus.DebugText and DribbleGui.AutoDribbleLabel then
        DribbleGui.AutoDribbleLabel.Text = "AutoDribble: DEKE (Slide Tackle!)"
    end
end

local function EagleEye(ball, owner)
    if not owner or not owner.Character or not ball then
        if AutoTackleStatus.DebugText then
            TackleGui.TargetLabel.Text = "Target: None"
            TackleGui.DribblingLabel.Text = "isDribbling: false"
            TackleGui.TacklingLabel.Text = "isTackling: false"
            TackleGui.EagleEyeLabel.Text = "EagleEye: Idle"
        end
        UpdateTargetRing(nil, math.huge)
        return
    end

    local targetRoot = owner.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local predictedPos = PredictBallPosition(ball) or ball.Position
    local distance = (v_u_4.Position - predictedPos).Magnitude

    if AutoTackleConfig.RotationMethod == "Always" and distance <= AutoTackleConfig.MaxDistance then
        RotateToTarget(predictedPos)
    end

    local state = DribbleStates[owner] or { IsDribbling = false, LastDribbleEnd = 0, CooldownUntil = 0, DelayTriggered = false }
    local isDribbling = state.IsDribbling
    local inCooldown = tick() < state.CooldownUntil
    local timeSinceEnd = tick() - state.LastDribbleEnd
    local isTacklingNow = IsSpecificTackle(owner)

    if AutoTackleStatus.DebugText then
        TackleGui.TargetLabel.Text = "Target: " .. owner.Name
        TackleGui.DribblingLabel.Text = "isDribbling: " .. tostring(isDribbling)
        TackleGui.TacklingLabel.Text = "isTackling: " .. tostring(isTacklingNow)
    end

    -- Новая логика: PowerShooting - немедленный tackle
    local powerShootingBools = workspace:FindFirstChild(owner.Name) and workspace[owner.Name]:FindFirstChild("Bools")
    local powerShooting = powerShootingBools and powerShootingBools:FindFirstChild("PowerShooting") and powerShootingBools.PowerShooting.Value
    if powerShooting then
        local shouldTackle = true
        local waitTime = 0
        local reason = "PowerShooting"
        if AutoTackleStatus.DebugText then
            TackleGui.EagleEyeLabel.Text = "EagleEye: Tackling (" .. reason .. ")"
            TackleGui.WaitLabel.Text = "Wait: 0.00"
        end
        UpdateTargetRing(ball, distance)
        local canTackle, _, _, _ = CanTackle()
        if canTackle then
            PerformTackle(ball, owner)
        end
        return
    end

    local mode = AutoTackleConfig.EagleEyeExceptions
    local shouldTackle = false
    local waitTime = 0
    local reason = ""

    -- Базовая логика: если нет dribble и нет cooldown — tackle сразу
    if not isDribbling and not inCooldown then
        shouldTackle = true
        reason = "Direct"
    end

    -- Mode-специфичная логика
    if mode == "None" then
        shouldTackle = true
        reason = "None"
    elseif mode == "OnlyDribble" then
        if isDribbling then
            shouldTackle = true
            reason = "Dribbling"
        else
            shouldTackle = false
            reason = "NoDribble"
        end
    elseif mode == "Dribble" then
        if isDribbling then
            shouldTackle = true
            reason = "Dribbling"
        elseif inCooldown or (not state.DelayTriggered) then
            -- Delay логика
            if AutoTackleConfig.DribbleDelay == "Delay" then
                if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                    state.DelayTriggered = true
                    shouldTackle = true
                    reason = "DelayEnd"
                else
                    waitTime = AutoTackleConfig.DribbleDelayTime - timeSinceEnd
                    reason = "DelayWait"
                end
            elseif AutoTackleConfig.DribbleDelay == "Smart" then
                if tick() >= state.CooldownUntil then
                    state.DelayTriggered = true
                    shouldTackle = true
                    reason = "SmartEnd"
                else
                    waitTime = state.CooldownUntil - tick()
                    reason = "SmartWait"
                end
            end
        else
            shouldTackle = true
            reason = "PostDelay"
        end
    end

    -- EagleEye delay (если shouldTackle true и mode не None)
    if shouldTackle and waitTime <= 0 and mode ~= "None" then
        if not EagleEyeWaitStart then
            waitTime = AutoTackleConfig.EagleEyeMinDelay + math.random() * (AutoTackleConfig.EagleEyeMaxDelay - AutoTackleConfig.EagleEyeMinDelay)
            EagleEyeWaitStart = os.clock()
            EagleEyeWaitTime = waitTime
            reason = "EagleEye"
        else
            local elapsed = os.clock() - EagleEyeWaitStart
            if elapsed >= EagleEyeWaitTime then
                shouldTackle = true
            else
                shouldTackle = false
                waitTime = EagleEyeWaitTime - elapsed
            end
        end
    end

    if AutoTackleStatus.DebugText then
        if waitTime > 0 then
            TackleGui.EagleEyeLabel.Text = "EagleEye: " .. reason
            TackleGui.WaitLabel.Text = string.format("Wait: %.2f", waitTime)
        else
            TackleGui.EagleEyeLabel.Text = "EagleEye: Tackling (" .. reason .. ")"
            TackleGui.WaitLabel.Text = "Wait: 0.00"
        end
    end

    UpdateTargetRing(ball, distance)

    if shouldTackle and waitTime <= 0 then
        local canTackle, _, _, _ = CanTackle()
        if canTackle then
            PerformTackle(ball, owner)
            if reason ~= "PostDelay" then  -- Сброс delay только если не в post-delay
                state.DelayTriggered = false
            end
            EagleEyeWaitStart = nil
        end
    end
end

-- === AUTO TACKLE ===
local AutoTackle = {}
AutoTackle.Start = function()
    if AutoTackleStatus.Running then return end
    AutoTackleStatus.Running = true
    SetupTackleGUI()
    InitializeRing()
    ToggleTackleDebugText(AutoTackleStatus.DebugText)
    
    AutoTackleStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoTackleConfig.Enabled then return end
        pcall(function()
            local canTackle, ball, distance, owner = CanTackle()
            if not canTackle or not ball then
                if AutoTackleStatus.DebugText then
                    TackleGui.TargetLabel.Text = "Target: None"
                    TackleGui.DribblingLabel.Text = "isDribbling: false"
                    TackleGui.TacklingLabel.Text = "isTackling: false"
                    TackleGui.EagleEyeLabel.Text = "EagleEye: Idle"
                end
                UpdateTargetRing(nil, math.huge)
                return
            end
            if distance <= AutoTackleConfig.TackleDistance then
                PerformTackle(ball, owner)
            else
                EagleEye(ball, owner)
            end
        end)
    end)
    
    AutoTackleStatus.RenderConnection = RunService.Heartbeat:Connect(function()
        pcall(PrecomputePlayers)
    end)
end

AutoTackle.Stop = function()
    if AutoTackleStatus.Connection then AutoTackleStatus.Connection:Disconnect(); AutoTackleStatus.Connection = nil end
    if AutoTackleStatus.RenderConnection then AutoTackleStatus.RenderConnection:Disconnect(); AutoTackleStatus.RenderConnection = nil end
    AutoTackleStatus.Running = false
    
    for _, v in pairs(TackleGui) do if v.Remove then v:Remove() end end
    for _, line in ipairs(TargetRingLines) do if line.Remove then line:Remove() end end
end

-- === AUTO DRIBBLE ===
local AutoDribble = {}
AutoDribble.Start = function()
    if AutoDribbleStatus.Running then return end
    AutoDribbleStatus.Running = true
    SetupDribbleGUI()
    ToggleDribbleDebugText(AutoDribbleStatus.DebugText)
    
    AutoDribbleStatus.Connection = RunService.RenderStepped:Connect(function()
        if not AutoDribbleConfig.Enabled then
            if AutoDribbleStatus.DebugText then
                DribbleGui.TargetLabel.Text = "Targets: 0"
                DribbleGui.TacklingLabel.Text = "Nearest: None"
                DribbleGui.AutoDribbleLabel.Text = "AutoDribble: Idle"
            end
            return
        end

        pcall(function()
            local specificTarget = nil
            local minDist = math.huge
            local targetCount = 0

            for player, data in pairs(PrecomputedPlayers) do
                if data.IsValid and TackleStates[player].IsTackling then
                    targetCount += 1
                    if data.Distance < minDist then
                        minDist = data.Distance
                        specificTarget = player
                    end
                end
            end

            if AutoDribbleStatus.DebugText then
                DribbleGui.TargetLabel.Text = "Targets: " .. targetCount
                DribbleGui.TacklingLabel.Text = specificTarget and string.format("Tackle: %.1f", minDist) or "Tackle: None"

                if HasBall and CanDribbleNow and specificTarget and minDist <= AutoDribbleConfig.DribbleActivationDistance then
                    PerformDribble()
                else
                    DribbleGui.AutoDribbleLabel.Text = "AutoDribble: Idle"
                end
            end

            if HasBall and CanDribbleNow and specificTarget and minDist <= AutoDribbleConfig.DribbleActivationDistance then
                PerformDribble()
            end
        end)
    end)
end

AutoDribble.Stop = function()
    if AutoDribbleStatus.Connection then AutoDribbleStatus.Connection:Disconnect(); AutoDribbleStatus.Connection = nil end
    AutoDribbleStatus.Running = false
    
    for _, v in pairs(DribbleGui) do if v.Remove then v:Remove() end end
end


-- === UI ИНТЕГРАЦИЯ ===
local uiElements = {}
local AutoTackleDribbleModule = {}

function AutoTackleDribbleModule.Init(UI, coreParam, notifyFunc)
    core = coreParam
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer
    
    -- AutoTackle Section
    if UI.Sections.AutoTackle then
        UI.Sections.AutoTackle:Header({ Name = "AutoTackle" })
        UI.Sections.AutoTackle:Divider()
        uiElements.AutoTackleEnabled = UI.Sections.AutoTackle:Toggle({ 
            Name = "Enabled", 
            Default = AutoTackleConfig.Enabled, 
            Callback = function(v) 
                AutoTackleConfig.Enabled = v
                if v then AutoTackle.Start() else AutoTackle.Stop() end
            end 
        }, "AutoTackleEnabled")
        
        uiElements.AutoTackleDebugText = UI.Sections.AutoTackle:Toggle({ 
            Name = "Debug Text", 
            Default = AutoTackleConfig.DebugText, 
            Callback = function(v) AutoTackle.SetDebugText(v) end 
        }, "AutoTackleDebugText")
        
        UI.Sections.AutoTackle:Divider()
        uiElements.AutoTackleMaxDistance = UI.Sections.AutoTackle:Slider({ 
            Name = "Max Distance", 
            Minimum = 10, Maximum = 50, Default = AutoTackleConfig.MaxDistance, Precision = 1,
            Callback = function(v) AutoTackleConfig.MaxDistance = v end 
        }, "AutoTackleMaxDistance")
        
        uiElements.AutoTackleTackleDistance = UI.Sections.AutoTackle:Slider({ 
            Name = "Tackle Distance", 
            Minimum = 0, Maximum = 10, Default = AutoTackleConfig.TackleDistance, Precision = 1,
            Callback = function(v) AutoTackleConfig.TackleDistance = v end 
        }, "AutoTackleTackleDistance")
        
        uiElements.AutoTackleOptimalMin = UI.Sections.AutoTackle:Slider({ 
            Name = "Optimal Distance Min", 
            Minimum = 1, Maximum = 10, Default = AutoTackleConfig.OptimalDistanceMin, Precision = 1,
            Callback = function(v) AutoTackleConfig.OptimalDistanceMin = v end 
        }, "AutoTackleOptimalMin")
        
        uiElements.AutoTackleOptimalMax = UI.Sections.AutoTackle:Slider({ 
            Name = "Optimal Distance Max", 
            Minimum = 10, Maximum = 30, Default = AutoTackleConfig.OptimalDistanceMax, Precision = 1,
            Callback = function(v) AutoTackleConfig.OptimalDistanceMax = v end 
        }, "AutoTackleOptimalMax")
        
        UI.Sections.AutoTackle:Divider()
        uiElements.AutoTackleTackleSpeed = UI.Sections.AutoTackle:Slider({ 
            Name = "Tackle Speed", 
            Minimum = 30, Maximum = 70, Default = AutoTackleConfig.TackleSpeed, Precision = 1,
            Callback = function(v) AutoTackleConfig.TackleSpeed = v end 
        }, "AutoTackleTackleSpeed")
        
        uiElements.AutoTacklePredictionTime = UI.Sections.AutoTackle:Slider({ 
            Name = "Prediction Time", 
            Minimum = 0.1, Maximum = 2.0, Default = AutoTackleConfig.PredictionTime, Precision = 2,
            Callback = function(v) AutoTackleConfig.PredictionTime = v end 
        }, "AutoTacklePredictionTime")
        
        UI.Sections.AutoTackle:Divider()
        uiElements.AutoTackleOnlyPlayer = UI.Sections.AutoTackle:Toggle({ 
            Name = "Only Player", 
            Default = AutoTackleConfig.OnlyPlayer,
            Callback = function(v) AutoTackleConfig.OnlyPlayer = v end 
        }, "AutoTackleOnlyPlayer")
        
        uiElements.AutoTackleRotationMethod = UI.Sections.AutoTackle:Dropdown({ 
            Name = "Rotation Method", 
            Options = {"Snap", "Always"}, 
            Default = AutoTackleConfig.RotationMethod,
            Callback = function(v) AutoTackleConfig.RotationMethod = v end 
        }, "AutoTackleRotationMethod")
        
        uiElements.AutoTackleRotationType = UI.Sections.AutoTackle:Dropdown({ 
            Name = "Rotation Type", 
            Options = {"CFrame"}, 
            Default = AutoTackleConfig.RotationType,
            Callback = function(v) AutoTackleConfig.RotationType = v end 
        }, "AutoTackleRotationType")
        
        UI.Sections.AutoTackle:Divider()
        uiElements.AutoTackleEagleEyeExceptions = UI.Sections.AutoTackle:Dropdown({ 
            Name = "EagleEye Exceptions", 
            Options = {"None", "OnlyDribble", "Dribble", "Dribble&Tackle"}, 
            Default = AutoTackleConfig.EagleEyeExceptions,
            Callback = function(v) AutoTackleConfig.EagleEyeExceptions = v end 
        }, "AutoTackleEagleEyeExceptions")
        
        uiElements.AutoTackleDribbleDelay = UI.Sections.AutoTackle:Dropdown({ 
            Name = "Dribble Delay", 
            Options = {"Delay", "Smart"}, 
            Default = AutoTackleConfig.DribbleDelay,
            Callback = function(v) AutoTackleConfig.DribbleDelay = v end 
        }, "AutoTackleDribbleDelay")
        
        uiElements.AutoTackleDribbleDelayTime = UI.Sections.AutoTackle:Slider({ 
            Name = "Dribble Delay Time", 
            Minimum = 0, Maximum = 5, Default = AutoTackleConfig.DribbleDelayTime, Precision = 2,
            Callback = function(v) AutoTackleConfig.DribbleDelayTime = v end 
        }, "AutoTackleDribbleDelayTime")
        
        uiElements.AutoTackleEagleEyeMinDelay = UI.Sections.AutoTackle:Slider({ 
            Name = "EagleEye Min Delay", 
            Minimum = 0, Maximum = 1, Default = AutoTackleConfig.EagleEyeMinDelay, Precision = 2,
            Callback = function(v) AutoTackleConfig.EagleEyeMinDelay = v end 
        }, "AutoTackleEagleEyeMinDelay")
        
        uiElements.AutoTackleEagleEyeMaxDelay = UI.Sections.AutoTackle:Slider({ 
            Name = "EagleEye Max Delay", 
            Minimum = 0, Maximum = 2, Default = AutoTackleConfig.EagleEyeMaxDelay, Precision = 2,
            Callback = function(v) AutoTackleConfig.EagleEyeMaxDelay = v end 
        }, "AutoTackleEagleEyeMaxDelay")
        
        UI.Sections.AutoTackle:Divider()
        uiElements.TackleTextX = UI.Sections.AutoTackle:Slider({ 
            Name = "Text X", 
            Minimum = 0, Maximum = 1, Default = AutoTackleConfig.TextPosition.X, Precision = 2,
            Callback = function(v) UpdateTackleTextPosition(v, AutoTackleConfig.TextPosition.Y) end 
        }, "TackleTextX")
        
        uiElements.TackleTextY = UI.Sections.AutoTackle:Slider({ 
            Name = "Text Y", 
            Minimum = 0, Maximum = 1, Default = AutoTackleConfig.TextPosition.Y, Precision = 2,
            Callback = function(v) UpdateTackleTextPosition(AutoTackleConfig.TextPosition.X, v) end 
        }, "TackleTextY")
    end
    
    -- AutoDribble Section
    if UI.Sections.AutoDribble then
        UI.Sections.AutoDribble:Header({ Name = "AutoDribble" })
        UI.Sections.AutoDribble:Divider()
        uiElements.AutoDribbleEnabled = UI.Sections.AutoDribble:Toggle({ 
            Name = "Enabled", 
            Default = AutoDribbleConfig.Enabled, 
            Callback = function(v) 
                AutoDribbleConfig.Enabled = v
                if v then AutoDribble.Start() else AutoDribble.Stop() end
            end 
        }, "AutoDribbleEnabled")
        
        uiElements.AutoDribbleDebugText = UI.Sections.AutoDribble:Toggle({ 
            Name = "Debug Text", 
            Default = AutoDribbleConfig.DebugText, 
            Callback = function(v) AutoDribble.SetDebugText(v) end 
        }, "AutoDribbleDebugText")
        
        UI.Sections.AutoDribble:Divider()
        uiElements.AutoDribbleMaxDistance = UI.Sections.AutoDribble:Slider({ 
            Name = "Max Dribble Distance", 
            Minimum = 20, Maximum = 50, Default = AutoDribbleConfig.MaxDribbleDistance, Precision = 1,
            Callback = function(v) AutoDribbleConfig.MaxDribbleDistance = v end 
        }, "AutoDribbleMaxDistance")
        
        uiElements.AutoDribbleActivationDistance = UI.Sections.AutoDribble:Slider({ 
            Name = "Dribble Activation Distance", 
            Minimum = 10, Maximum = 25, Default = AutoDribbleConfig.DribbleActivationDistance, Precision = 1,
            Callback = function(v) AutoDribbleConfig.DribbleActivationDistance = v end 
        }, "AutoDribbleActivationDistance")
        
        uiElements.AutoDribbleMaxAngle = UI.Sections.AutoDribble:Slider({ 
            Name = "Max Angle", 
            Minimum = 0, Maximum = 360, Default = AutoDribbleConfig.MaxAngle, Precision = 1,
            Callback = function(v) AutoDribbleConfig.MaxAngle = v end 
        }, "AutoDribbleMaxAngle")
        
        uiElements.AutoDribbleTacklePredictionTime = UI.Sections.AutoDribble:Slider({ 
            Name = "Tackle Prediction Time", 
            Minimum = 0.1, Maximum = 1.0, Default = AutoDribbleConfig.TacklePredictionTime, Precision = 2,
            Callback = function(v) AutoDribbleConfig.TacklePredictionTime = v end 
        }, "AutoDribbleTacklePredictionTime")
        
        uiElements.AutoDribbleTackleAngleThreshold = UI.Sections.AutoDribble:Slider({ 
            Name = "Tackle Angle Threshold", 
            Minimum = 0.1, Maximum = 1.0, Default = AutoDribbleConfig.TackleAngleThreshold, Precision = 2,
            Callback = function(v) AutoDribbleConfig.TackleAngleThreshold = v end 
        }, "AutoDribbleTackleAngleThreshold")
        
        UI.Sections.AutoDribble:Divider()
        uiElements.DribbleTextX = UI.Sections.AutoDribble:Slider({ 
            Name = "Text X", 
            Minimum = 0, Maximum = 1, Default = AutoDribbleConfig.TextPosition.X, Precision = 2,
            Callback = function(v) UpdateDribbleTextPosition(v, AutoDribbleConfig.TextPosition.Y) end 
        }, "DribbleTextX")
        
        uiElements.DribbleTextY = UI.Sections.AutoDribble:Slider({ 
            Name = "Text Y", 
            Minimum = 0, Maximum = 1, Default = AutoDribbleConfig.TextPosition.Y, Precision = 2,
            Callback = function(v) UpdateDribbleTextPosition(AutoDribbleConfig.TextPosition.X, v) end 
        }, "DribbleTextY")
    end
    
    -- Sync Button
    if UI.Tabs.Config then
        local syncSection = UI.Tabs.Config:Section({ Name = "AutoTackle & AutoDribble Sync", Side = "Right" })
        syncSection:Button({ 
            Name = "Sync Config", 
            Callback = function()
                -- Sync AutoTackle
                AutoTackleConfig.Enabled = uiElements.AutoTackleEnabled:GetState()
                AutoTackleConfig.DebugText = uiElements.AutoTackleDebugText:GetState()
                AutoTackleConfig.MaxDistance = uiElements.AutoTackleMaxDistance:GetValue()
                AutoTackleConfig.TackleDistance = uiElements.AutoTackleTackleDistance:GetValue()
                AutoTackleConfig.OptimalDistanceMin = uiElements.AutoTackleOptimalMin:GetValue()
                AutoTackleConfig.OptimalDistanceMax = uiElements.AutoTackleOptimalMax:GetValue()
                AutoTackleConfig.TackleSpeed = uiElements.AutoTackleTackleSpeed:GetValue()
                AutoTackleConfig.PredictionTime = uiElements.AutoTacklePredictionTime:GetValue()
                AutoTackleConfig.OnlyPlayer = uiElements.AutoTackleOnlyPlayer:GetState()
                AutoTackleConfig.RotationMethod = uiElements.AutoTackleRotationMethod:GetSelectedOption()
                AutoTackleConfig.RotationType = uiElements.AutoTackleRotationType:GetSelectedOption()
                AutoTackleConfig.EagleEyeExceptions = uiElements.AutoTackleEagleEyeExceptions:GetSelectedOption()
                AutoTackleConfig.DribbleDelay = uiElements.AutoTackleDribbleDelay:GetSelectedOption()
                AutoTackleConfig.DribbleDelayTime = uiElements.AutoTackleDribbleDelayTime:GetValue()
                AutoTackleConfig.EagleEyeMinDelay = uiElements.AutoTackleEagleEyeMinDelay:GetValue()
                AutoTackleConfig.EagleEyeMaxDelay = uiElements.AutoTackleEagleEyeMaxDelay:GetValue()
                AutoTackleConfig.TextPosition.X = uiElements.TackleTextX:GetValue()
                AutoTackleConfig.TextPosition.Y = uiElements.TackleTextY:GetValue()
                
                -- Sync AutoDribble
                AutoDribbleConfig.Enabled = uiElements.AutoDribbleEnabled:GetState()
                AutoDribbleConfig.DebugText = uiElements.AutoDribbleDebugText:GetState()
                AutoDribbleConfig.MaxDribbleDistance = uiElements.AutoDribbleMaxDistance:GetValue()
                AutoDribbleConfig.DribbleActivationDistance = uiElements.AutoDribbleActivationDistance:GetValue()
                AutoDribbleConfig.MaxAngle = uiElements.AutoDribbleMaxAngle:GetValue()
                AutoDribbleConfig.TacklePredictionTime = uiElements.AutoDribbleTacklePredictionTime:GetValue()
                AutoDribbleConfig.TackleAngleThreshold = uiElements.AutoDribbleTackleAngleThreshold:GetValue()
                AutoDribbleConfig.TextPosition.X = uiElements.DribbleTextX:GetValue()
                AutoDribbleConfig.TextPosition.Y = uiElements.DribbleTextY:GetValue()
                
                -- Update statuses
                AutoTackleStatus.DebugText = AutoTackleConfig.DebugText
                AutoDribbleStatus.DebugText = AutoDribbleConfig.DebugText
                
                -- Restart modules if needed
                if AutoTackleConfig.Enabled then if not AutoTackleStatus.Running then AutoTackle.Start() end else if AutoTackleStatus.Running then AutoTackle.Stop() end end
                if AutoDribbleConfig.Enabled then if not AutoDribbleStatus.Running then AutoDribble.Start() end else if AutoDribbleStatus.Running then AutoDribble.Stop() end end
                
                -- Update text positions
                UpdateTackleTextPosition(AutoTackleConfig.TextPosition.X, AutoTackleConfig.TextPosition.Y)
                UpdateDribbleTextPosition(AutoDribbleConfig.TextPosition.X, AutoDribbleConfig.TextPosition.Y)
                
                ToggleTackleDebugText(AutoTackleStatus.DebugText)
                ToggleDribbleDebugText(AutoDribbleStatus.DebugText)
                
                notify("AutoTackleDribble", "Config synchronized!", true)
            end 
        })
    end
    
    -- Auto-start if enabled
    if AutoTackleConfig.Enabled then AutoTackle.Start() end
    if AutoDribbleConfig.Enabled then AutoDribble.Start() end
    
    LocalPlayerObj.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        v_u_2 = newChar
        v_u_4 = newChar:WaitForChild("HumanoidRootPart")
        v_u_13 = newChar:WaitForChild("Humanoid")
        if AutoTackleConfig.Enabled then AutoTackle.Start() end
        if AutoDribbleConfig.Enabled then AutoDribble.Start() end
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        DribbleStates[player] = nil
        PrecomputedPlayers[player] = nil
        TackleStates[player] = nil
    end)
end

function AutoTackleDribbleModule:Destroy()
    AutoTackle.Stop()
    AutoDribble.Stop()
end

-- Добавляем методы для UI
function AutoTackle.SetDebugText(value)
    ToggleTackleDebugText(value)
    notify("AutoTackle", "Debug Text " .. (value and "Enabled" or "Disabled"), true)
end

function AutoDribble.SetDebugText(value)
    ToggleDribbleDebugText(value)
    notify("AutoDribble", "Debug Text " .. (value and "Enabled" or "Disabled"), true)
end

return AutoTackleDribbleModule
