-- AutoTackle & AutoDribble Module
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local v_u_2 = Character
local v_u_4 = HumanoidRootPart
local v_u_13 = Humanoid

local ActionRemote = ReplicatedStorage.Remotes:WaitForChild("Action")
local SoftDisPlayerRemote = ReplicatedStorage.Remotes:WaitForChild("SoftDisPlayer")

local Animations = ReplicatedStorage:WaitForChild("Animations")
local DribbleAnims = Animations:WaitForChild("Dribble")
local TackleAnims = Animations:WaitForChild("TackleAnims")

local DribbleAnimIds = {}
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
    RotationMethod = "Snap",
    RotationType = "CFrame",
    MaxAngle = 360,
    EagleEyeExceptions = "OnlyDribble",
    DribbleDelay = "Delay",
    DribbleDelayTime = 0,
    EagleEyeMinDelay = 0.1,
    EagleEyeMaxDelay = 1.0
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
}

-- === STATUS ===
local AutoTackleStatus = {
    Running = false,
    Connection = nil
}

local AutoDribbleStatus = {
    Running = false,
    Connection = nil
}

-- === STATES ===
local DribbleStates = {}
local TackleStates = {}
local PrecomputedPlayers = {}
local HasBall = false
local CanDribbleNow = false
local EagleEyeWaitStart = nil
local EagleEyeWaitTime = 0

-- === GUI (Drawing) ===
local TackleGui = nil
local DribbleGui = nil
local Gui = nil
local TargetRingLines = nil
local TargetRings = {}

local function SetupTackleGui()
    TackleGui = {
        TackleWaitLabel = Drawing.new("Text"),
        TackleTargetLabel = Drawing.new("Text"),
        TackleDribblingLabel = Drawing.new("Text"),
        TackleTacklingLabel = Drawing.new("Text"),
        EagleEyeLabel = Drawing.new("Text")
    }
    local screenSize = Camera.ViewportSize
    local centerX = screenSize.X / 2 + 100  -- правее на 100
    local offsetY = screenSize.Y * 0.6
    local textLabels = {
        TackleGui.TackleWaitLabel, TackleGui.TackleTargetLabel, TackleGui.TackleDribblingLabel,
        TackleGui.TackleTacklingLabel, TackleGui.EagleEyeLabel
    }
    for _, label in ipairs(textLabels) do
        label.Size = 18
        label.Color = Color3.fromRGB(255, 255, 255)
        label.Outline = true
        label.Center = true
        label.Visible = true
    end
    TackleGui.TackleWaitLabel.Color = Color3.fromRGB(255, 165, 0)
    TackleGui.TackleWaitLabel.Position = Vector2.new(centerX, offsetY); offsetY += 15
    TackleGui.TackleTargetLabel.Position = Vector2.new(centerX, offsetY); offsetY += 15
    TackleGui.TackleDribblingLabel.Position = Vector2.new(centerX, offsetY); offsetY += 15
    TackleGui.TackleTacklingLabel.Position = Vector2.new(centerX, offsetY); offsetY += 15
    TackleGui.EagleEyeLabel.Position = Vector2.new(centerX, offsetY)
    TackleGui.TackleWaitLabel.Text = "Wait: 0.00"
    TackleGui.TackleTargetLabel.Text = "Target: None"
    TackleGui.TackleDribblingLabel.Text = "isDribbling: false"
    TackleGui.TackleTacklingLabel.Text = "isTackling: false"
    TackleGui.EagleEyeLabel.Text = "EagleEye: Idle"
end

local function SetupDribbleGui()
    DribbleGui = {
        DribbleStatusLabel = Drawing.new("Text"),
        DribbleTargetLabel = Drawing.new("Text"),
        DribbleTacklingLabel = Drawing.new("Text"),
        AutoDribbleLabel = Drawing.new("Text")
    }
    local screenSize = Camera.ViewportSize
    local centerX = screenSize.X / 2 + 100  -- правее на 100
    local offsetY = screenSize.Y * 0.6 - 50
    local textLabels = {
        DribbleGui.DribbleStatusLabel, DribbleGui.DribbleTargetLabel, DribbleGui.DribbleTacklingLabel, DribbleGui.AutoDribbleLabel
    }
    for _, label in ipairs(textLabels) do
        label.Size = 18
        label.Color = Color3.fromRGB(255, 255, 255)
        label.Outline = true
        label.Center = true
        label.Visible = true
    end
    DribbleGui.DribbleStatusLabel.Position = Vector2.new(centerX, offsetY); offsetY += 15
    DribbleGui.DribbleTargetLabel.Position = Vector2.new(centerX, offsetY); offsetY += 15
    DribbleGui.DribbleTacklingLabel.Position = Vector2.new(centerX, offsetY); offsetY += 15
    DribbleGui.AutoDribbleLabel.Position = Vector2.new(centerX, offsetY)
    DribbleGui.DribbleStatusLabel.Text = "Dribble: Ready"
    DribbleGui.DribbleTargetLabel.Text = "Targets: 0"
    DribbleGui.DribbleTacklingLabel.Text = "Nearest: None"
    DribbleGui.AutoDribbleLabel.Text = "AutoDribble: Idle"
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
    if not TargetRingLines then
        TargetRingLines = {}
        for i = 1, 24 do
            local line = Drawing.new("Line")
            line.Thickness = 3
            line.Color = Color3.fromRGB(255, 0, 0)
            line.Visible = false
            table.insert(TargetRingLines, line)
        end
    end
    for _, line in ipairs(TargetRingLines) do line.Visible = false end
    if not ball or not ball.Parent then return end
    local center = ball.Position - Vector3.new(0, 0.5, 0)
    local radius = 2
    local segments = #TargetRingLines
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

local function UpdateTargetRings()
    for player, ring in pairs(TargetRings) do
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
        local ring = TargetRings[player]
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
        if DribbleGui then
            DribbleGui.DribbleStatusLabel.Text = bools.dribbleDebounce.Value and "Dribble: Cooldown" or "Dribble: Ready"
            DribbleGui.DribbleStatusLabel.Color = bools.dribbleDebounce.Value and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
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

        if not TargetRings[player] then TargetRings[player] = CreateTargetRing() end

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
    if TargetRings[player] then
        for _, line in ipairs(TargetRings[player]) do line:Remove() end
        TargetRings[player] = nil
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
    pcall(function() ActionRemote:FireServer("Tackle") end)
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Parent = v_u_4
    bodyVelocity.Velocity = v_u_4.CFrame.LookVector * AutoTackleConfig.TackleSpeed
    bodyVelocity.MaxForce = Vector3.new(50000000, 0, 50000000)
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Parent = v_u_4
    bodyGyro.Name = "TackleGyro"
    bodyGyro.P = 2000000
    bodyGyro.MaxTorque = Vector3.new(0, 300000, 0)
    bodyGyro.CFrame = v_u_4.CFrame
    Debris:AddItem(bodyVelocity, 0.7)
    Debris:AddItem(bodyGyro, 0.7)
    if owner and ball:FindFirstChild("playerWeld") then
        local distance = (v_u_4.Position - ball.Position).Magnitude
        pcall(function() SoftDisPlayerRemote:FireServer(owner, distance, false, ball.Size) end)
    end
end

local function PerformDribble()
    local bools = workspace:FindFirstChild(LocalPlayer.Name) and workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.dribbleDebounce.Value then return end
    pcall(function() ActionRemote:FireServer("Deke") end)
    if DribbleGui then
        DribbleGui.DribbleStatusLabel.Text = "Dribble: Cooldown"
        DribbleGui.DribbleStatusLabel.Color = Color3.fromRGB(255, 0, 0)
        DribbleGui.AutoDribbleLabel.Text = "AutoDribble: DEKE (Slide Tackle!)"
    end
end

local function EagleEye(ball, owner)
    if not owner or not owner.Character or not ball then
        if TackleGui then
            TackleGui.TackleTargetLabel.Text = "Target: None"
            TackleGui.TackleDribblingLabel.Text = "isDribbling: false"
            TackleGui.TackleTacklingLabel.Text = "isTackling: false"
            TackleGui.EagleEyeLabel.Text = "EagleEye: Idle"
        end
        UpdateTargetRing(nil, math.huge)
        return
    end

    local targetRoot = owner.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local predictedPos = PredictBallPosition(ball) or ball.Position
    local distance = (v_u_4.Position - predictedPos).Magnitude

    if AutoTackleConfig.RotationMethod == "Snap" and distance <= AutoTackleConfig.MaxDistance then
        RotateToTarget(predictedPos)
    end

    local state = DribbleStates[owner] or { IsDribbling = false, LastDribbleEnd = 0, CooldownUntil = 0, DelayTriggered = false }
    local isDribbling = state.IsDribbling
    local inCooldown = tick() < state.CooldownUntil
    local timeSinceEnd = tick() - state.LastDribbleEnd
    local isTacklingNow = IsSpecificTackle(owner)

    if TackleGui then
        TackleGui.TackleTargetLabel.Text = "Target: " .. owner.Name
        TackleGui.TackleDribblingLabel.Text = "isDribbling: " .. tostring(isDribbling)
        TackleGui.TackleTacklingLabel.Text = "isTackling: " .. tostring(isTacklingNow)
    end

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

    if TackleGui then
        if waitTime > 0 then
            TackleGui.EagleEyeLabel.Text = "EagleEye: " .. reason
            TackleGui.TackleWaitLabel.Text = string.format("Wait: %.2f", waitTime)
        else
            TackleGui.EagleEyeLabel.Text = "EagleEye: Tackling (" .. reason .. ")"
            TackleGui.TackleWaitLabel.Text = "Wait: 0.00"
        end
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

-- ЦИКЛЫ
RunService.Heartbeat:Connect(function()
    pcall(PrecomputePlayers)
    pcall(UpdateTargetRings)
end)

RunService.Heartbeat:Connect(function()
    if not AutoTackleConfig.Enabled then return end
    pcall(function()
        local canTackle, ball, distance, owner = CanTackle()
        if not canTackle or not ball then
            if TackleGui then
                TackleGui.TackleTargetLabel.Text = "Target: None"
                TackleGui.TackleDribblingLabel.Text = "isDribbling: false"
                TackleGui.TackleTacklingLabel.Text = "isTackling: false"
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

RunService.RenderStepped:Connect(function()
    if not AutoDribbleConfig.Enabled then
        if DribbleGui then
            DribbleGui.DribbleTargetLabel.Text = "Targets: 0"
            DribbleGui.DribbleTacklingLabel.Text = "Nearest: None"
            DribbleGui.AutoDribbleLabel.Text = "AutoDribble: Idle"
        end
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

        if DribbleGui then
            DribbleGui.DribbleTargetLabel.Text = "Targets: " .. targetCount
            DribbleGui.DribbleTacklingLabel.Text = specificTarget and string.format("Tackle: %.1f", minDist) or "Tackle: None"
        end

        if HasBall and CanDribbleNow and specificTarget and minDist <= AutoDribbleConfig.DribbleActivationDistance then
            PerformDribble()
        else
            if DribbleGui then
                DribbleGui.AutoDribbleLabel.Text = "AutoDribble: Idle"
            end
        end
    end)
end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
    v_u_2 = newChar
    v_u_4 = newChar:WaitForChild("HumanoidRootPart")
    v_u_13 = newChar:WaitForChild("Humanoid")
end)

local function SetupUI(UI)
    if UI.Sections.AutoTackle then
        UI.Sections.AutoTackle:Header({ Name = "AutoTackle" })
        uiElements.AutoTackleEnabled = UI.Sections.AutoTackle:Toggle({
            Name = "Enabled",
            Default = AutoTackleConfig.Enabled,
            Callback = function(value)
                AutoTackleConfig.Enabled = value
                if value then AutoTackle.Start() else AutoTackle.Stop() end
            end
        }, "AutoTackleEnabled")

        uiElements.AutoTackleMaxDistance = UI.Sections.AutoTackle:Slider({
            Name = "Max Distance",
            Minimum = 10,
            Maximum = 50,
            Default = AutoTackleConfig.MaxDistance,
            Precision = 1,
            Callback = function(value)
                AutoTackleConfig.MaxDistance = value
            end
        }, "AutoTackleMaxDistance")

        uiElements.AutoTackleTackleDistance = UI.Sections.AutoTackle:Slider({
            Name = "Tackle Distance",
            Minimum = 0,
            Maximum = 10,
            Default = AutoTackleConfig.TackleDistance,
            Precision = 1,
            Callback = function(value)
                AutoTackleConfig.TackleDistance = value
            end
        }, "AutoTackleTackleDistance")

        uiElements.AutoTackleOptimalMin = UI.Sections.AutoTackle:Slider({
            Name = "Optimal Distance Min",
            Minimum = 1,
            Maximum = 10,
            Default = AutoTackleConfig.OptimalDistanceMin,
            Precision = 1,
            Callback = function(value)
                AutoTackleConfig.OptimalDistanceMin = value
            end
        }, "AutoTackleOptimalMin")

        uiElements.AutoTackleOptimalMax = UI.Sections.AutoTackle:Slider({
            Name = "Optimal Distance Max",
            Minimum = 5,
            Maximum = 20,
            Default = AutoTackleConfig.OptimalDistanceMax,
            Precision = 1,
            Callback = function(value)
                AutoTackleConfig.OptimalDistanceMax = value
            end
        }, "AutoTackleOptimalMax")

        uiElements.AutoTackleTackleSpeed = UI.Sections.AutoTackle:Slider({
            Name = "Tackle Speed",
            Minimum = 20,
            Maximum = 100,
            Default = AutoTackleConfig.TackleSpeed,
            Precision = 1,
            Callback = function(value)
                AutoTackleConfig.TackleSpeed = value
            end
        }, "AutoTackleTackleSpeed")

        uiElements.AutoTacklePredictionTime = UI.Sections.AutoTackle:Slider({
            Name = "Prediction Time",
            Minimum = 0.1,
            Maximum = 2.0,
            Default = AutoTackleConfig.PredictionTime,
            Precision = 2,
            Callback = function(value)
                AutoTackleConfig.PredictionTime = value
            end
        }, "AutoTacklePredictionTime")

        uiElements.AutoTackleOnlyPlayer = UI.Sections.AutoTackle:Toggle({
            Name = "Only Player",
            Default = AutoTackleConfig.OnlyPlayer,
            Callback = function(value)
                AutoTackleConfig.OnlyPlayer = value
            end
        }, "AutoTackleOnlyPlayer")

        uiElements.AutoTackleRotationMethod = UI.Sections.AutoTackle:Dropdown({
            Name = "Rotation Method",
            Options = {"Snap", "Other"},
            Default = AutoTackleConfig.RotationMethod,
            Callback = function(value)
                AutoTackleConfig.RotationMethod = value
            end
        }, "AutoTackleRotationMethod")

        uiElements.AutoTackleRotationType = UI.Sections.AutoTackle:Dropdown({
            Name = "Rotation Type",
            Options = {"CFrame"},
            Default = AutoTackleConfig.RotationType,
            Callback = function(value)
                AutoTackleConfig.RotationType = value
            end
        }, "AutoTackleRotationType")

        uiElements.AutoTackleMaxAngle = UI.Sections.AutoTackle:Slider({
            Name = "Max Angle",
            Minimum = 0,
            Maximum = 360,
            Default = AutoTackleConfig.MaxAngle,
            Precision = 1,
            Callback = function(value)
                AutoTackleConfig.MaxAngle = value
            end
        }, "AutoTackleMaxAngle")

        uiElements.AutoTackleEagleEyeExceptions = UI.Sections.AutoTackle:Dropdown({
            Name = "EagleEye Exceptions",
            Options = {"None", "OnlyDribble", "Dribble", "Dribble&Tackle"},
            Default = AutoTackleConfig.EagleEyeExceptions,
            Callback = function(value)
                AutoTackleConfig.EagleEyeExceptions = value
            end
        }, "AutoTackleEagleEyeExceptions")

        uiElements.AutoTackleDribbleDelay = UI.Sections.AutoTackle:Dropdown({
            Name = "Dribble Delay",
            Options = {"Delay", "Smart"},
            Default = AutoTackleConfig.DribbleDelay,
            Callback = function(value)
                AutoTackleConfig.DribbleDelay = value
            end
        }, "AutoTackleDribbleDelay")

        uiElements.AutoTackleDribbleDelayTime = UI.Sections.AutoTackle:Slider({
            Name = "Dribble Delay Time",
            Minimum = 0,
            Maximum = 5,
            Default = AutoTackleConfig.DribbleDelayTime,
            Precision = 2,
            Callback = function(value)
                AutoTackleConfig.DribbleDelayTime = value
            end
        }, "AutoTackleDribbleDelayTime")

        uiElements.AutoTackleEagleEyeMinDelay = UI.Sections.AutoTackle:Slider({
            Name = "EagleEye Min Delay",
            Minimum = 0.0,
            Maximum = 2.0,
            Default = AutoTackleConfig.EagleEyeMinDelay,
            Precision = 2,
            Callback = function(value)
                AutoTackleConfig.EagleEyeMinDelay = value
            end
        }, "AutoTackleEagleEyeMinDelay")

        uiElements.AutoTackleEagleEyeMaxDelay = UI.Sections.AutoTackle:Slider({
            Name = "EagleEye Max Delay",
            Minimum = 0.0,
            Maximum = 2.0,
            Default = AutoTackleConfig.EagleEyeMaxDelay,
            Precision = 2,
            Callback = function(value)
                AutoTackleConfig.EagleEyeMaxDelay = value
            end
        }, "AutoTackleEagleEyeMaxDelay")
    end

    if UI.Sections.AutoDribble then
        UI.Sections.AutoDribble:Header({ Name = "AutoDribble" })
        uiElements.AutoDribbleEnabled = UI.Sections.AutoDribble:Toggle({
            Name = "Enabled",
            Default = AutoDribbleConfig.Enabled,
            Callback = function(value)
                AutoDribbleConfig.Enabled = value
                if value then AutoDribble.Start() else AutoDribble.Stop() end
            end
        }, "AutoDribbleEnabled")

        uiElements.AutoDribbleMaxDribbleDistance = UI.Sections.AutoDribble:Slider({
            Name = "Max Dribble Distance",
            Minimum = 10,
            Maximum = 50,
            Default = AutoDribbleConfig.MaxDribbleDistance,
            Precision = 1,
            Callback = function(value)
                AutoDribbleConfig.MaxDribbleDistance = value
            end
        }, "AutoDribbleMaxDribbleDistance")

        uiElements.AutoDribbleDribbleActivationDistance = UI.Sections.AutoDribble:Slider({
            Name = "Dribble Activation Distance",
            Minimum = 5,
            Maximum = 30,
            Default = AutoDribbleConfig.DribbleActivationDistance,
            Precision = 1,
            Callback = function(value)
                AutoDribbleConfig.DribbleActivationDistance = value
            end
        }, "AutoDribbleDribbleActivationDistance")

        uiElements.AutoDribbleMaxAngle = UI.Sections.AutoDribble:Slider({
            Name = "Max Angle",
            Minimum = 0,
            Maximum = 360,
            Default = AutoDribbleConfig.MaxAngle,
            Precision = 1,
            Callback = function(value)
                AutoDribbleConfig.MaxAngle = value
            end
        }, "AutoDribbleMaxAngle")

        uiElements.AutoDribblePredictionTime = UI.Sections.AutoDribble:Slider({
            Name = "Prediction Time",
            Minimum = 0.01,
            Maximum = 1.0,
            Default = AutoDribbleConfig.PredictionTime,
            Precision = 3,
            Callback = function(value)
                AutoDribbleConfig.PredictionTime = value
            end
        }, "AutoDribblePredictionTime")

        uiElements.AutoDribbleMaxPredictionAngle = UI.Sections.AutoDribble:Slider({
            Name = "Max Prediction Angle",
            Minimum = 0,
            Maximum = 180,
            Default = AutoDribbleConfig.MaxPredictionAngle,
            Precision = 1,
            Callback = function(value)
                AutoDribbleConfig.MaxPredictionAngle = value
            end
        }, "AutoDribbleMaxPredictionAngle")

        uiElements.AutoDribbleTacklePredictionTime = UI.Sections.AutoDribble:Slider({
            Name = "Tackle Prediction Time",
            Minimum = 0.1,
            Maximum = 1.0,
            Default = AutoDribbleConfig.TacklePredictionTime,
            Precision = 2,
            Callback = function(value)
                AutoDribbleConfig.TacklePredictionTime = value
            end
        }, "AutoDribbleTacklePredictionTime")

        uiElements.AutoDribbleTackleAngleThreshold = UI.Sections.AutoDribble:Slider({
            Name = "Tackle Angle Threshold",
            Minimum = 0.1,
            Maximum = 1.0,
            Default = AutoDribbleConfig.TackleAngleThreshold,
            Precision = 2,
            Callback = function(value)
                AutoDribbleConfig.TackleAngleThreshold = value
            end
        }, "AutoDribbleTackleAngleThreshold")
    end

    local syncSection = UI.Tabs.Config:Section({ Name = "AutoTackle & AutoDribble Sync", Side = "Right" })
    syncSection:Header({ Name = "Sync" })
    syncSection:Button({ Name = "Sync Config", Callback = function()
        AutoTackleConfig.Enabled = uiElements.AutoTackleEnabled:GetState()
        AutoTackleConfig.MaxDistance = uiElements.AutoTackleMaxDistance:GetValue()
        AutoTackleConfig.TackleDistance = uiElements.AutoTackleTackleDistance:GetValue()
        AutoTackleConfig.OptimalDistanceMin = uiElements.AutoTackleOptimalMin:GetValue()
        AutoTackleConfig.OptimalDistanceMax = uiElements.AutoTackleOptimalMax:GetValue()
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

        AutoDribbleConfig.Enabled = uiElements.AutoDribbleEnabled:GetState()
        AutoDribbleConfig.MaxDribbleDistance = uiElements.AutoDribbleMaxDribbleDistance:GetValue()
        AutoDribbleConfig.DribbleActivationDistance = uiElements.AutoDribbleDribbleActivationDistance:GetValue()
        AutoDribbleConfig.MaxAngle = uiElements.AutoDribbleMaxAngle:GetValue()
        AutoDribbleConfig.PredictionTime = uiElements.AutoDribblePredictionTime:GetValue()
        AutoDribbleConfig.MaxPredictionAngle = uiElements.AutoDribbleMaxPredictionAngle:GetValue()
        AutoDribbleConfig.TacklePredictionTime = uiElements.AutoDribbleTacklePredictionTime:GetValue()
        AutoDribbleConfig.TackleAngleThreshold = uiElements.AutoDribbleTackleAngleThreshold:GetValue()

        if AutoTackleConfig.Enabled then if not AutoTackleStatus.Running then AutoTackle.Start() end else if AutoTackleStatus.Running then AutoTackle.Stop() end end
        if AutoDribbleConfig.Enabled then if not AutoDribbleStatus.Running then AutoDribble.Start() end else if AutoDribbleStatus.Running then AutoDribble.Stop() end end

        notify("Syllinse", "Config synchronized!", true)
    end })
end

-- === AUTO TACKLE ===
local AutoTackle = {}

AutoTackle.Start = function()
    if AutoTackleStatus.Running then return end
    AutoTackleStatus.Running = true
    SetupTackleGui()
    AutoTackleStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoTackleConfig.Enabled then return end
        pcall(function()
            local canTackle, ball, distance, owner = CanTackle()
            if not canTackle or not ball then
                TackleGui.TackleTargetLabel.Text = "Target: None"
                TackleGui.TackleDribblingLabel.Text = "isDribbling: false"
                TackleGui.TackleTacklingLabel.Text = "isTackling: false"
                TackleGui.EagleEyeLabel.Text = "EagleEye: Idle"
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
    notify("AutoTackle", "Started", true)
end

AutoTackle.Stop = function()
    if AutoTackleStatus.Connection then
        AutoTackleStatus.Connection:Disconnect()
        AutoTackleStatus.Connection = nil
    end
    AutoTackleStatus.Running = false
    if TackleGui then
        for _, label in pairs(TackleGui) do
            label:Remove()
        end
        TackleGui = nil
    end
    notify("AutoTackle", "Stopped", true)
end

-- === AUTO DRIBBLE ===
local AutoDribble = {}

AutoDribble.Start = function()
    if AutoDribbleStatus.Running then return end
    AutoDribbleStatus.Running = true
    SetupDribbleGui()
    AutoDribbleStatus.Connection = RunService.RenderStepped:Connect(function()
        if not AutoDribbleConfig.Enabled then return end
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

            DribbleGui.DribbleTargetLabel.Text = "Targets: " .. targetCount
            DribbleGui.DribbleTacklingLabel.Text = specificTarget and string.format("Tackle: %.1f", minDist) or "Tackle: None"

            if HasBall and CanDribbleNow and specificTarget and minDist <= AutoDribbleConfig.DribbleActivationDistance then
                PerformDribble()
            else
                DribbleGui.AutoDribbleLabel.Text = "AutoDribble: Idle"
            end
        end)
    end)
    notify("AutoDribble", "Started", true)
end

AutoDribble.Stop = function()
    if AutoDribbleStatus.Connection then
        AutoDribbleStatus.Connection:Disconnect()
        AutoDribbleStatus.Connection = nil
    end
    AutoDribbleStatus.Running = false
    if DribbleGui then
        for _, label in pairs(DribbleGui) do
            label:Remove()
        end
        DribbleGui = nil
    end
    notify("AutoDribble", "Stopped", true)
end

-- === МОДУЛЬ ===
local AutoTackleDribbleModule = {}

function AutoTackleDribbleModule.Init(UI, coreParam, notifyFunc)
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
        v_u_2 = newChar
        v_u_4 = HumanoidRootPart
        v_u_13 = Humanoid
        if AutoTackleConfig.Enabled then AutoTackle.Start() end
        if AutoDribbleConfig.Enabled then AutoDribble.Start() end
    end)
end

function AutoTackleDribbleModule:Destroy()
    AutoTackle.Stop()
    AutoDribble.Stop()
    for player, ring in pairs(TargetRings) do
        for _, line in ipairs(ring) do line:Remove() end
    end
    TargetRings = {}
end

return AutoTackleDribbleModule
