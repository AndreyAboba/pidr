-- [v1.0] AUTO TACKLE + AUTO DRIBBLE + FULL GUI + UI INTEGRATION (РАБОЧАЯ ВЕРСИЯ С ИСПРАВЛЕНИЯМИ)
--[[
    AutoDribble – только при анимации rbxassetid://14317040670
    DribbleHelper полностью удалён
    Всё работает через эксплоит (полный клиентский контроль)
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

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
local TackleAnims = Animations:WaitForChild("TackleAnims")   -- оставляем, но не собираем ID

local DribbleAnimIds = {}
local TackleAnimIds = {}   -- больше не заполняем

-- собираем только Dribble-анимации (для IsDribbling)
for _, anim in pairs(DribbleAnims:GetChildren()) do
    if anim:IsA("Animation") then
        table.insert(DribbleAnimIds, anim.AnimationId)
    end
end

-- === CONFIG ===
local AutoTackleConfig = {
    Enabled = true,
    MaxDistance = 20,
    TackleDistance = 0,
    OptimalDistanceMin = 3,
    OptimalDistanceMax = 15,
    TackleSpeed = 47,
    PredictionTime = 0.8,
    OnlyPlayer = true,
    RotationMethod = "Snap",  -- Убрали "Always"
    RotationType = "CFrame",
    MaxAngle = 360,
    EagleEyeExceptions = "OnlyDribble",
    DribbleDelay = "Delay",
    DribbleDelayTime = 0,
    EagleEyeMinDelay = 0.1,
    EagleEyeMaxDelay = 1.0,
    DebugTextXOffset = 100,  -- Новый: смещение debug-текста по X (чуть правее по умолчанию)
    DebugTextYOffset = 0     -- Новый: смещение по Y
}

local AutoDribbleConfig = {
    Enabled = true,
    MaxDribbleDistance = 30,
    DribbleActivationDistance = 16,
    MaxAngle = 360,
    PredictionTime = 0.098,
    MaxPredictionAngle = 38,
    TacklePredictionTime = 0.3,
    TackleAngleThreshold = 0.7
    -- DribbleHelper полностью удалён
}

-- === STATUS ===
local AutoTackleStatus = {
    Running = false,
    Connection = nil,
    RenderConnection = nil
}
local AutoDribbleStatus = {
    Running = false,
    Connection = nil
}

-- СОСТОЯНИЯ
local DribbleStates = {}
local TackleStates = {}
local PrecomputedPlayers = {}
local HasBall = false
local CanDribbleNow = false
local EagleEyeWaitStart = nil
local EagleEyeWaitTime = 0

-- GUI
local Gui = {
    TackleWaitLabel = Drawing.new("Text"),
    TackleTargetLabel = Drawing.new("Text"),
    TackleDribblingLabel = Drawing.new("Text"),
    TackleTacklingLabel = Drawing.new("Text"),
    EagleEyeLabel = Drawing.new("Text"),
    DribbleStatusLabel = Drawing.new("Text"),
    DribbleTargetLabel = Drawing.new("Text"),
    DribbleTacklingLabel = Drawing.new("Text"),
    AutoDribbleLabel = Drawing.new("Text"),
    TargetRingLines = {},
    TargetRings = {}
}

local function SetupGui()
    local screenSize = Camera.ViewportSize
    local centerX = screenSize.X / 2 + AutoTackleConfig.DebugTextXOffset  -- Чуть правее по умолчанию
    local tackleY = screenSize.Y * 0.6 + AutoTackleConfig.DebugTextYOffset
    local offsetTackleY = tackleY + 30
    local offsetDribbleY = tackleY - 50

    local textLabels = {
        Gui.TackleWaitLabel, Gui.TackleTargetLabel, Gui.TackleDribblingLabel,
        Gui.TackleTacklingLabel, Gui.EagleEyeLabel, Gui.DribbleStatusLabel,
        Gui.DribbleTargetLabel, Gui.DribbleTacklingLabel, Gui.AutoDribbleLabel
    }

    for _, label in ipairs(textLabels) do
        label.Size = 18
        label.Color = Color3.fromRGB(255, 255, 255)
        label.Outline = true
        label.Center = true
        label.Visible = true
    end

    Gui.TackleWaitLabel.Color = Color3.fromRGB(255, 165, 0)
    Gui.TackleWaitLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.TackleTargetLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.TackleDribblingLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.TackleTacklingLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.EagleEyeLabel.Position = Vector2.new(centerX, offsetTackleY)

    Gui.DribbleStatusLabel.Position = Vector2.new(centerX, offsetDribbleY); offsetDribbleY += 15
    Gui.DribbleTargetLabel.Position = Vector2.new(centerX, offsetDribbleY); offsetDribbleY += 15
    Gui.DribbleTacklingLabel.Position = Vector2.new(centerX, offsetDribbleY); offsetDribbleY += 15
    Gui.AutoDribbleLabel.Position = Vector2.new(centerX, offsetDribbleY)

    Gui.TackleWaitLabel.Text = "Wait: 0.00"
    Gui.TackleTargetLabel.Text = "Target: None"
    Gui.TackleDribblingLabel.Text = "isDribbling: false"
    Gui.TackleTacklingLabel.Text = "isTackling: false"
    Gui.EagleEyeLabel.Text = "EagleEye: Idle"
    Gui.DribbleStatusLabel.Text = "Dribble: Ready"
    Gui.DribbleTargetLabel.Text = "Targets: 0"
    Gui.DribbleTacklingLabel.Text = "Nearest: None"
    Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"

    for i = 1, 24 do
        local line = Drawing.new("Line")
        line.Thickness = 3
        line.Color = Color3.fromRGB(255, 0, 0)
        line.Visible = false
        table.insert(Gui.TargetRingLines, line)
    end
end

local function CreateTargetRing()
    local ring = {}
    for i = 1, 24 do
        local line = Drawing.new("Line")
        line.Thickness = 3
        line.Color = Color3.fromRGB(255, 0, 0)
        line.Visible = false
        table.insert(ring, line)
    end
    return ring
end

local function UpdateTargetRing(ball, distance)
    for _, line in ipairs(Gui.TargetRingLines) do line.Visible = false end
    if not ball or not ball.Parent then return end
    local center = ball.Position - Vector3.new(0, 0.5, 0)
    local radius = 2
    local segments = #Gui.TargetRingLines
    local points = {}
    for i = 1, segments do
        local angle = (i - 1) * 2 * math.pi / segments
        local point = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        table.insert(points, point)
    end
    for i, line in ipairs(Gui.TargetRingLines) do
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

local function UpdateTargetRings()
    for player, ring in pairs(Gui.TargetRings) do
        for _, line in ipairs(ring) do line.Visible = false end
    end
    for player, data in pairs(PrecomputedPlayers) do
        if not data.IsValid or not TackleStates[player].IsTackling then continue end
        local targetRoot = data.RootPart
        if not targetRoot then continue end
        local center = targetRoot.Position - Vector3.new(0, 0.5, 0)
        local radius = 2
        local segments = 24
        local points = {}
        for i = 1, segments do
            local angle = (i - 1) * 2 * math.pi / segments
            local point = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            table.insert(points, point)
        end
        local ring = Gui.TargetRings[player]
        for i, line in ipairs(ring) do
            local startPoint = points[i]
            local endPoint = points[i % segments + 1]
            local startScreen, startOnScreen = Camera:WorldToViewportPoint(startPoint)
            local endScreen, endOnScreen = Camera:WorldToViewportPoint(endPoint)
            if startOnScreen and endOnScreen and startScreen.Z > 0.1 and endScreen.Z > 0.1 then
                line.From = Vector2.new(startScreen.X, startScreen.Y)
                line.To = Vector2.new(endScreen.X, endScreen.Y)
                if data.Distance <= AutoDribbleConfig.DribbleActivationDistance then
                    line.Color = Color3.fromRGB(0, 255, 0)
                elseif data.Distance <= AutoDribbleConfig.MaxDribbleDistance then
                    line.Color = Color3.fromRGB(255, 165, 0)
                else
                    line.Color = Color3.fromRGB(255, 0, 0)
                end
                line.Visible = true
            end
        end
    end
end

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

-- НОВАЯ проверка: только конкретный tackle-ID
local SPECIFIC_TACKLE_ID = "rbxassetid://14317040670"

local function IsSpecificTackle(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Parent or targetPlayer.TeamColor == LocalPlayer.TeamColor then
        return false
    end
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
        Gui.DribbleStatusLabel.Text = bools.dribbleDebounce.Value and "Dribble: Cooldown" or "Dribble: Ready"
        Gui.DribbleStatusLabel.Color = bools.dribbleDebounce.Value and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
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
        TackleStates[player].IsTackling = IsSpecificTackle(player)   -- ТОЛЬКО нужный ID

        local distance = (targetRoot.Position - v_u_4.Position).Magnitude
        if distance > AutoDribbleConfig.MaxDribbleDistance then continue end

        if not Gui.TargetRings[player] then Gui.TargetRings[player] = CreateTargetRing() end

        local predictedPos = targetRoot.Position + targetRoot.AssemblyLinearVelocity * AutoDribbleConfig.PredictionTime
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

Players.PlayerRemoving:Connect(function(player)
    DribbleStates[player] = nil
    PrecomputedPlayers[player] = nil
    TackleStates[player] = nil
    if Gui.TargetRings[player] then
        for _, line in ipairs(Gui.TargetRings[player]) do line:Remove() end
        Gui.TargetRings[player] = nil
    end
end)

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
    if AutoTackleConfig.RotationType == "CFrame" then
        v_u_4.CFrame = CFrame.new(v_u_4.Position, targetPos)
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
    Gui.DribbleStatusLabel.Text = "Dribble: Cooldown"
    Gui.DribbleStatusLabel.Color = Color3.fromRGB(255, 0, 0)
    Gui.AutoDribbleLabel.Text = "AutoDribble: DEKE (Slide Tackle!)"
end

local function EagleEye(ball, owner)
    if not owner or not owner.Character or not ball then
        Gui.TackleTargetLabel.Text = "Target: None"
        Gui.TackleDribblingLabel.Text = "isDribbling: false"
        Gui.TackleTacklingLabel.Text = "isTackling: false"
        Gui.EagleEyeLabel.Text = "EagleEye: Idle"
        UpdateTargetRing(nil, math.huge)
        return
    end

    local targetRoot = owner.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local predictedPos = PredictBallPosition(ball) or ball.Position
    local distance = (v_u_4.Position - predictedPos).Magnitude

    -- Убрали "Always" из RotationMethod
    if AutoTackleConfig.RotationMethod == "Snap" and distance <= AutoTackleConfig.MaxDistance then
        RotateToTarget(predictedPos)
    end

    local state = DribbleStates[owner] or { IsDribbling = false, LastDribbleEnd = 0, CooldownUntil = 0, DelayTriggered = false }
    local isDribbling = state.IsDribbling
    local inCooldown = tick() < state.CooldownUntil
    local timeSinceEnd = tick() - state.LastDribbleEnd
    local isTacklingNow = IsSpecificTackle(owner)   -- используем ту же проверку

    Gui.TackleTargetLabel.Text = "Target: " .. owner.Name
    Gui.TackleDribblingLabel.Text = "isDribbling: " .. tostring(isDribbling)
    Gui.TackleTacklingLabel.Text = "isTackling: " .. tostring(isTacklingNow)

    local mode = AutoTackleConfig.EagleEyeExceptions
    local shouldTackle = false
    local waitTime = 0
    local reason = ""

    if mode == "None" then
        shouldTackle = true
        reason = "None"

    elseif mode == "OnlyDribble" then
        if inCooldown then
            if state.DelayTriggered then
                shouldTackle = true
                reason = "Cooldown"
            else
                if AutoTackleConfig.DribbleDelay == "Smart" then
                    if not isDribbling then
                        if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                            state.DelayTriggered = true
                            shouldTackle = true
                            reason = "Smart+Delay"
                        else
                            waitTime = AutoTackleConfig.DribbleDelayTime - timeSinceEnd
                            reason = "DelayWait"
                        end
                    else
                        waitTime = 999
                        reason = "WaitDribble"
                    end
                else
                    if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                        state.DelayTriggered = true
                        shouldTackle = true
                        reason = "DelayEnd"
                    else
                        waitTime = AutoTackleConfig.DribbleDelayTime - timeSinceEnd
                        reason = "DelayWait"
                    end
                end
            end
        end

    elseif mode == "Dribble" then
        if isDribbling then
            shouldTackle = true
            reason = "Dribbling"
        elseif inCooldown then
            if state.DelayTriggered then
                shouldTackle = true
                reason = "Cooldown"
            else
                if AutoTackleConfig.DribbleDelay == "Smart" then
                    if not isDribbling then
                        if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                            state.DelayTriggered = true
                            shouldTackle = true
                            reason = "Smart+Delay"
                        else
                            waitTime = AutoTackleConfig.DribbleDelayTime - timeSinceEnd
                            reason = "DelayWait"
                        end
                    else
                        waitTime = 999
                        reason = "WaitDribble"
                    end
                else
                    if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                        state.DelayTriggered = true
                        shouldTackle = true
                        reason = "DelayEnd"
                    else
                        waitTime = AutoTackleConfig.DribbleDelayTime - timeSinceEnd
                        reason = "DelayWait"
                    end
                end
            end
        end

    elseif mode == "Dribble&Tackle" then
        if isDribbling or isTacklingNow then
            shouldTackle = true
            reason = isDribbling and "Dribbling" or "Tackling"
        elseif inCooldown then
            if state.DelayTriggered then
                shouldTackle = true
                reason = "Cooldown"
            else
                if AutoTackleConfig.DribbleDelay == "Smart" then
                    if not isDribbling then
                        if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                            state.DelayTriggered = true
                            shouldTackle = true
                            reason = "Smart+Delay"
                        else
                            waitTime = AutoTackleConfig.DribbleDelayTime - timeSinceEnd
                            reason = "DelayWait"
                        end
                    else
                        waitTime = 999
                        reason = "WaitDribble"
                    end
                else
                    if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                        state.DelayTriggered = true
                        shouldTackle = true
                        reason = "DelayEnd"
                    else
                        waitTime = AutoTackleConfig.DribbleDelayTime - timeSinceEnd
                        reason = "DelayWait"
                    end
                end
            end
        end
    end

    if shouldTackle and waitTime <= 0 and mode ~= "None" and not inCooldown and not isDribbling then
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

    if waitTime > 0 then
        Gui.EagleEyeLabel.Text = "EagleEye: " .. reason
        Gui.TackleWaitLabel.Text = string.format("Wait: %.2f", waitTime)
    else
        Gui.EagleEyeLabel.Text = "EagleEye: Tackling (" .. reason .. ")"
        Gui.TackleWaitLabel.Text = "Wait: 0.00"
    end

    UpdateTargetRing(ball, distance)

    if shouldTackle and waitTime <= 0 then
        local canTackle, _, _, _ = CanTackle()
        if canTackle then
            PerformTackle(ball, owner)
            if reason ~= "Cooldown" then
                EagleEyeWaitStart = nil
            end
        end
    end
end

-- === AUTO TACKLE ===
local AutoTackle = {}
AutoTackle.Start = function()
    if AutoTackleStatus.Running then return end
    AutoTackleStatus.Running = true
    SetupGui()
    AutoTackleStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoTackleConfig.Enabled then return end
        pcall(function()
            local canTackle, ball, distance, owner = CanTackle()
            if not canTackle or not ball then
                Gui.TackleTargetLabel.Text = "Target: None"
                Gui.TackleDribblingLabel.Text = "isDribbling: false"
                Gui.TackleTacklingLabel.Text = "isTackling: false"
                Gui.EagleEyeLabel.Text = "EagleEye: Idle"
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
        pcall(UpdateTargetRings)
    end)
    notify("AutoTackle", "Started", true)
end
AutoTackle.Stop = function()
    if AutoTackleStatus.Connection then AutoTackleStatus.Connection:Disconnect(); AutoTackleStatus.Connection = nil end
    if AutoTackleStatus.RenderConnection then AutoTackleStatus.RenderConnection:Disconnect(); AutoTackleStatus.RenderConnection = nil end
    AutoTackleStatus.Running = false
    for _, label in pairs(Gui) do
        if type(label) == "table" then
            for _, item in pairs(label) do if item.Remove then item:Remove() end end
        elseif label.Remove then label:Remove() end
    end
    Gui = nil
    notify("AutoTackle", "Stopped", true)
end

-- === AUTO DRIBBLE ===
local AutoDribble = {}
AutoDribble.Start = function()
    if AutoDribbleStatus.Running then return end
    AutoDribbleStatus.Running = true
    AutoDribbleStatus.Connection = RunService.RenderStepped:Connect(function()
        if not AutoDribbleConfig.Enabled then
            Gui.DribbleTargetLabel.Text = "Targets: 0"
            Gui.DribbleTacklingLabel.Text = "Nearest: None"
            Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"
            return
        end

        pcall(function()
            -- Находим ближайшего игрока с нужным tackle-ID
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

            Gui.DribbleTargetLabel.Text = "Targets: " .. targetCount
            Gui.DribbleTacklingLabel.Text = specificTarget and string.format("Tackle: %.1f", minDist) or "Tackle: None"

            if HasBall and CanDribbleNow and specificTarget and minDist <= AutoDribbleConfig.DribbleActivationDistance then
                PerformDribble()
            else
                Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"
            end
        end)
    end)
    notify("AutoDribble", "Started", true)
end
AutoDribble.Stop = function()
    if AutoDribbleStatus.Connection then AutoDribbleStatus.Connection:Disconnect(); AutoDribbleStatus.Connection = nil end
    AutoDribbleStatus.Running = false
    notify("AutoDribble", "Stopped", true)
end

-- === UI ===
local uiElements = {}
local function SetupUI(UI)
    if UI.Sections.AutoTackle then
        UI.Sections.AutoTackle:Header({ Name = "AutoTackle" })
        UI.Sections.AutoTackle:Divider()
        uiElements.AutoTackleEnabled = UI.Sections.AutoTackle:Toggle({ Name = "Enabled", Default = AutoTackleConfig.Enabled, Callback = function(v) AutoTackleConfig.Enabled = v; if v then AutoTackle.Start() else AutoTackle.Stop() end end }, "AutoTackleEnabled")
        uiElements.AutoTackleMaxDistance = UI.Sections.AutoTackle:Slider({ Name = "Max Distance", Minimum = 5, Maximum = 50, Default = AutoTackleConfig.MaxDistance, Precision = 1, Callback = function(v) AutoTackleConfig.MaxDistance = v end }, "AutoTackleMaxDistance")
        uiElements.AutoTackleTackleDistance = UI.Sections.AutoTackle:Slider({ Name = "Tackle Distance", Minimum = 0, Maximum = 20, Default = AutoTackleConfig.TackleDistance, Precision = 1, Callback = function(v) AutoTackleConfig.TackleDistance = v end }, "AutoTackleTackleDistance")
        uiElements.AutoTackleOptimalDistanceMin = UI.Sections.AutoTackle:Slider({ Name = "Optimal Distance Min", Minimum = 1, Maximum = 10, Default = AutoTackleConfig.OptimalDistanceMin, Precision = 1, Callback = function(v) AutoTackleConfig.OptimalDistanceMin = v end }, "AutoTackleOptimalDistanceMin")
        uiElements.AutoTackleOptimalDistanceMax = UI.Sections.AutoTackle:Slider({ Name = "Optimal Distance Max", Minimum = 5, Maximum = 30, Default = AutoTackleConfig.OptimalDistanceMax, Precision = 1, Callback = function(v) AutoTackleConfig.OptimalDistanceMax = v end }, "AutoTackleOptimalDistanceMax")
        uiElements.AutoTackleTackleSpeed = UI.Sections.AutoTackle:Slider({ Name = "Tackle Speed", Minimum = 20, Maximum = 100, Default = AutoTackleConfig.TackleSpeed, Precision = 1, Callback = function(v) AutoTackleConfig.TackleSpeed = v end }, "AutoTackleTackleSpeed")
        uiElements.AutoTacklePredictionTime = UI.Sections.AutoTackle:Slider({ Name = "Prediction Time", Minimum = 0.1, Maximum = 2.0, Default = AutoTackleConfig.PredictionTime, Precision = 2, Callback = function(v) AutoTackleConfig.PredictionTime = v end }, "AutoTacklePredictionTime")
        uiElements.AutoTackleOnlyPlayer = UI.Sections.AutoTackle:Toggle({ Name = "Only Player", Default = AutoTackleConfig.OnlyPlayer, Callback = function(v) AutoTackleConfig.OnlyPlayer = v end }, "AutoTackleOnlyPlayer")
        uiElements.AutoTackleRotationMethod = UI.Sections.AutoTackle:Dropdown({ Name = "Rotation Method", Options = {"Snap"}, Default = AutoTackleConfig.RotationMethod, Callback = function(v) AutoTackleConfig.RotationMethod = v end }, "AutoTackleRotationMethod")
        uiElements.AutoTackleRotationType = UI.Sections.AutoTackle:Dropdown({ Name = "Rotation Type", Options = {"CFrame"}, Default = AutoTackleConfig.RotationType, Callback = function(v) AutoTackleConfig.RotationType = v end }, "AutoTackleRotationType")
        uiElements.AutoTackleMaxAngle = UI.Sections.AutoTackle:Slider({ Name = "Max Angle", Minimum = 0, Maximum = 360, Default = AutoTackleConfig.MaxAngle, Precision = 1, Callback = function(v) AutoTackleConfig.MaxAngle = v end }, "AutoTackleMaxAngle")
        uiElements.AutoTackleEagleEyeExceptions = UI.Sections.AutoTackle:Dropdown({ Name = "EagleEye Exceptions", Options = {"None", "OnlyDribble", "Dribble", "Dribble&Tackle"}, Default = AutoTackleConfig.EagleEyeExceptions, Callback = function(v) AutoTackleConfig.EagleEyeExceptions = v end }, "AutoTackleEagleEyeExceptions")
        uiElements.AutoTackleDribbleDelay = UI.Sections.AutoTackle:Dropdown({ Name = "Dribble Delay", Options = {"Delay", "Smart"}, Default = AutoTackleConfig.DribbleDelay, Callback = function(v) AutoTackleConfig.DribbleDelay = v end }, "AutoTackleDribbleDelay")
        uiElements.AutoTackleDribbleDelayTime = UI.Sections.AutoTackle:Slider({ Name = "Dribble Delay Time", Minimum = 0, Maximum = 5, Default = AutoTackleConfig.DribbleDelayTime, Precision = 1, Callback = function(v) AutoTackleConfig.DribbleDelayTime = v end }, "AutoTackleDribbleDelayTime")
        uiElements.AutoTackleEagleEyeMinDelay = UI.Sections.AutoTackle:Slider({ Name = "EagleEye Min Delay", Minimum = 0.0, Maximum = 2.0, Default = AutoTackleConfig.EagleEyeMinDelay, Precision = 2, Callback = function(v) AutoTackleConfig.EagleEyeMinDelay = v end }, "AutoTackleEagleEyeMinDelay")
        uiElements.AutoTackleEagleEyeMaxDelay = UI.Sections.AutoTackle:Slider({ Name = "EagleEye Max Delay", Minimum = 0.0, Maximum = 2.0, Default = AutoTackleConfig.EagleEyeMaxDelay, Precision = 2, Callback = function(v) AutoTackleConfig.EagleEyeMaxDelay = v end }, "AutoTackleEagleEyeMaxDelay")
        uiElements.AutoTackleDebugTextXOffset = UI.Sections.AutoTackle:Slider({ Name = "Debug Text X Offset", Minimum = -500, Maximum = 500, Default = AutoTackleConfig.DebugTextXOffset, Precision = 1, Callback = function(v) AutoTackleConfig.DebugTextXOffset = v; SetupGui() end }, "AutoTackleDebugTextXOffset")
        uiElements.AutoTackleDebugTextYOffset = UI.Sections.AutoTackle:Slider({ Name = "Debug Text Y Offset", Minimum = -500, Maximum = 500, Default = AutoTackleConfig.DebugTextYOffset, Precision = 1, Callback = function(v) AutoTackleConfig.DebugTextYOffset = v; SetupGui() end }, "AutoTackleDebugTextYOffset")
    end

    if UI.Sections.AutoDribble then
        UI.Sections.AutoDribble:Header({ Name = "AutoDribble" })
        UI.Sections.AutoDribble:Divider()
        uiElements.AutoDribbleEnabled = UI.Sections.AutoDribble:Toggle({ Name = "Enabled", Default = AutoDribbleConfig.Enabled, Callback = function(v) AutoDribbleConfig.Enabled = v; if v then AutoDribble.Start() else AutoDribble.Stop() end end }, "AutoDribbleEnabled")
        uiElements.AutoDribbleMaxDribbleDistance = UI.Sections.AutoDribble:Slider({ Name = "Max Dribble Distance", Minimum = 10, Maximum = 50, Default = AutoDribbleConfig.MaxDribbleDistance, Precision = 1, Callback = function(v) AutoDribbleConfig.MaxDribbleDistance = v end }, "AutoDribbleMaxDribbleDistance")
        uiElements.AutoDribbleDribbleActivationDistance = UI.Sections.AutoDribble:Slider({ Name = "Dribble Activation Distance", Minimum = 5, Maximum = 30, Default = AutoDribbleConfig.DribbleActivationDistance, Precision = 1, Callback = function(v) AutoDribbleConfig.DribbleActivationDistance = v end }, "AutoDribbleDribbleActivationDistance")
        uiElements.AutoDribbleMaxAngle = UI.Sections.AutoDribble:Slider({ Name = "Max Angle", Minimum = 0, Maximum = 360, Default = AutoDribbleConfig.MaxAngle, Precision = 1, Callback = function(v) AutoDribbleConfig.MaxAngle = v end }, "AutoDribbleMaxAngle")
        uiElements.AutoDribblePredictionTime = UI.Sections.AutoDribble:Slider({ Name = "Prediction Time", Minimum = 0.01, Maximum = 1.0, Default = AutoDribbleConfig.PredictionTime, Precision = 2, Callback = function(v) AutoDribbleConfig.PredictionTime = v end }, "AutoDribblePredictionTime")
        uiElements.AutoDribbleMaxPredictionAngle = UI.Sections.AutoDribble:Slider({ Name = "Max Prediction Angle", Minimum = 0, Maximum = 180, Default = AutoDribbleConfig.MaxPredictionAngle, Precision = 1, Callback = function(v) AutoDribbleConfig.MaxPredictionAngle = v end }, "AutoDribbleMaxPredictionAngle")
        uiElements.AutoDribbleTacklePredictionTime = UI.Sections.AutoDribble:Slider({ Name = "Tackle Prediction Time", Minimum = 0.1, Maximum = 1.0, Default = AutoDribbleConfig.TacklePredictionTime, Precision = 2, Callback = function(v) AutoDribbleConfig.TacklePredictionTime = v end }, "AutoDribbleTacklePredictionTime")
        uiElements.AutoDribbleTackleAngleThreshold = UI.Sections.AutoDribble:Slider({ Name = "Tackle Angle Threshold", Minimum = 0.1, Maximum = 1.0, Default = AutoDribbleConfig.TackleAngleThreshold, Precision = 2, Callback = function(v) AutoDribbleConfig.TackleAngleThreshold = v end }, "AutoDribbleTackleAngleThreshold")
    end

    local syncSection = UI.Tabs.Config:Section({ Name = "AutoTackle & AutoDribble Sync", Side = "Right" })
    syncSection:Header({ Name = "AutoTackle/AutoDribble" })
    syncSection:Button({ Name = "Sync Config", Callback = function()
        AutoTackleConfig.Enabled = uiElements.AutoTackleEnabled:GetState()
        AutoTackleConfig.MaxDistance = uiElements.AutoTackleMaxDistance:GetValue()
        AutoTackleConfig.TackleDistance = uiElements.AutoTackleTackleDistance:GetValue()
        AutoTackleConfig.OptimalDistanceMin = uiElements.AutoTackleOptimalDistanceMin:GetValue()
        AutoTackleConfig.OptimalDistanceMax = uiElements.AutoTackleOptimalDistanceMax:GetValue()
        AutoTackleConfig.TackleSpeed = uiElements.AutoTackleTackleSpeed:GetValue()
        AutoTackleConfig.PredictionTime = uiElements.AutoTacklePredictionTime:GetValue()
        AutoTackleConfig.OnlyPlayer = uiElements.AutoTackleOnlyPlayer:GetState()
        AutoTackleConfig.RotationMethod = uiElements.AutoTackleRotationMethod:GetValue()
        AutoTackleConfig.RotationType = uiElements.AutoTackleRotationType:GetValue()
        AutoTackleConfig.MaxAngle = uiElements.AutoTackleMaxAngle:GetValue()
        AutoTackleConfig.EagleEyeExceptions = uiElements.AutoTackleEagleEyeExceptions:GetValue()
        AutoTackleConfig.DribbleDelay = uiElements.AutoTackleDribbleDelay:GetValue()
        AutoTackleConfig.DribbleDelayTime = uiElements.AutoTackleDribbleDelayTime:GetValue()
        AutoTackleConfig.EagleEyeMinDelay = uiElements.AutoTackleEagleEyeMinDelay:GetValue()
        AutoTackleConfig.EagleEyeMaxDelay = uiElements.AutoTackleEagleEyeMaxDelay:GetValue()
        AutoTackleConfig.DebugTextXOffset = uiElements.AutoTackleDebugTextXOffset:GetValue()
        AutoTackleConfig.DebugTextYOffset = uiElements.AutoTackleDebugTextYOffset:GetValue()
        AutoDribbleConfig.Enabled = uiElements.AutoDribbleEnabled:GetState()
        AutoDribbleConfig.MaxDribbleDistance = uiElements.AutoDribbleMaxDribbleDistance:GetValue()
        AutoDribbleConfig.DribbleActivationDistance = uiElements.AutoDribbleDribbleActivationDistance:GetValue()
        AutoDribbleConfig.MaxAngle = uiElements.AutoDribbleMaxAngle:GetValue()
        AutoDribbleConfig.PredictionTime = uiElements.AutoDribblePredictionTime:GetValue()
        AutoDribbleConfig.MaxPredictionAngle = uiElements.AutoDribbleMaxPredictionAngle:GetValue()
        AutoDribbleConfig.TacklePredictionTime = uiElements.AutoDribbleTacklePredictionTime:GetValue()
        AutoDribbleConfig.TackleAngleThreshold = uiElements.AutoDribbleTackleAngleThreshold:GetValue()
        SetupGui()  -- Обновляем GUI после синхронизации
        if AutoTackleConfig.Enabled then if not AutoTackleStatus.Running then AutoTackle.Start() end else if AutoTackleStatus.Running then AutoTackle.Stop() end end
        if AutoDribbleConfig.Enabled then if not AutoDribbleStatus.Running then AutoDribble.Start() end else if AutoDribbleStatus.Running then AutoDribble.Stop() end end
        notify("Syllinse", "Config synchronized!", true)
    end })
end

-- === МОДУЛЬ ===
local AutoTackleModule = {}
function AutoTackleModule.Init(UI, coreParam, notifyFunc)
    core = coreParam
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer
    SetupUI(UI)
    LocalPlayerObj.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        v_u_2 = newChar
        v_u_4 = newChar:WaitForChild("HumanoidRootPart")
        v_u_13 = newChar:WaitForChild("Humanoid")
        EagleEyeWaitStart = nil
        if AutoTackleConfig.Enabled then AutoTackle.Start() end
        if AutoDribbleConfig.Enabled then AutoDribble.Start() end
    end)
end
function AutoTackleModule:Destroy()
    AutoTackle.Stop()
    AutoDribble.Stop()
end
return AutoTackleModule
