-- [v1.0] AUTO TACKLE + AUTO DRIBBLE (РАБОЧАЯ ВЕРСИЯ С ИСПРАВЛЕНИЯМИ)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local ActionRemote = ReplicatedStorage.Remotes:WaitForChild("Action")
local SoftDisPlayerRemote = ReplicatedStorage.Remotes:WaitForChild("SoftDisPlayer")

local Animations = ReplicatedStorage:WaitForChild("Animations")
local DribbleAnims = Animations:WaitForChild("Dribble")

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
    EagleEyeMaxDelay = 1.0,
    DebugText = true,
    DebugOffsetX = 10,  -- Чуть правее по умолчанию
    DebugOffsetY = 0
}

local AutoDribbleConfig = {
    Enabled = true,
    MaxDribbleDistance = 30,
    DribbleActivationDistance = 16,
    MaxAngle = 360,
    PredictionTime = 0.098,
    MaxPredictionAngle = 38,
    TacklePredictionTime = 0.3,
    TackleAngleThreshold = 0.7,
    DebugText = true
}

-- === STATUS ===
local AutoTackleStatus = {
    Running = false,
    Connection = nil,
    RenderConnection = nil,
    DebugText = AutoTackleConfig.DebugText,
    DebugOffsetX = AutoTackleConfig.DebugOffsetX,
    DebugOffsetY = AutoTackleConfig.DebugOffsetY
}

local AutoDribbleStatus = {
    Running = false,
    Connection = nil,
    DebugText = AutoDribbleConfig.DebugText
}

-- === GUI (Drawing) ===
local Gui = nil
local function SetupGUI()
    Gui = {
        TackleWait = Drawing.new("Text"),
        TackleTarget = Drawing.new("Text"),
        TackleDribbling = Drawing.new("Text"),
        TackleTackling = Drawing.new("Text"),
        EagleEye = Drawing.new("Text"),
        DribbleStatus = Drawing.new("Text"),
        DribbleTarget = Drawing.new("Text"),
        DribbleTackling = Drawing.new("Text"),
        AutoDribble = Drawing.new("Text"),
        TargetRingLines = {},
        TargetRings = {}
    }
    local s = Camera.ViewportSize
    local cx = s.X / 2 + AutoTackleStatus.DebugOffsetX
    local yTackle = s.Y * 0.6 + AutoTackleStatus.DebugOffsetY
    local yDribble = yTackle - 50 + AutoTackleStatus.DebugOffsetY
    for i, v in ipairs({Gui.TackleWait, Gui.TackleTarget, Gui.TackleDribbling, Gui.TackleTackling, Gui.EagleEye, Gui.DribbleStatus, Gui.DribbleTarget, Gui.DribbleTackling, Gui.AutoDribble}) do
        v.Size = 18; v.Color = Color3.fromRGB(255, 255, 255); v.Outline = true; v.Center = true
        v.Visible = AutoTackleStatus.DebugText
    end
    Gui.TackleWait.Color = Color3.fromRGB(255, 165, 0)
    Gui.TackleWait.Position = Vector2.new(cx, yTackle); yTackle = yTackle + 15
    Gui.TackleTarget.Position = Vector2.new(cx, yTackle); yTackle = yTackle + 15
    Gui.TackleDribbling.Position = Vector2.new(cx, yTackle); yTackle = yTackle + 15
    Gui.TackleTackling.Position = Vector2.new(cx, yTackle); yTackle = yTackle + 15
    Gui.EagleEye.Position = Vector2.new(cx, yTackle)
    Gui.DribbleStatus.Position = Vector2.new(cx, yDribble); yDribble = yDribble + 15
    Gui.DribbleTarget.Position = Vector2.new(cx, yDribble); yDribble = yDribble + 15
    Gui.DribbleTackling.Position = Vector2.new(cx, yDribble); yDribble = yDribble + 15
    Gui.AutoDribble.Position = Vector2.new(cx, yDribble)
    Gui.TackleWait.Text = "Wait: 0.00"
    Gui.TackleTarget.Text = "Target: None"
    Gui.TackleDribbling.Text = "isDribbling: false"
    Gui.TackleTackling.Text = "isTackling: false"
    Gui.EagleEye.Text = "EagleEye: Idle"
    Gui.DribbleStatus.Text = "Dribble: Ready"
    Gui.DribbleTarget.Text = "Targets: 0"
    Gui.DribbleTackling.Text = "Nearest: None"
    Gui.AutoDribble.Text = "AutoDribble: Idle"
    for i = 1, 24 do
        local line = Drawing.new("Line")
        line.Thickness = 3; line.Color = Color3.fromRGB(255, 0, 0); line.Visible = false
        table.insert(Gui.TargetRingLines, line)
    end
end

local function ToggleDebugText(value)
    if not Gui then return end
    for _, v in pairs(Gui) do
        if typeof(v) == "table" then
            for _, l in ipairs(v) do
                if l.Remove then l.Visible = value end
            end
        else
            v.Visible = value
        end
    end
end

local function SetDebugOffsetX(value)
    AutoTackleStatus.DebugOffsetX = value
    AutoTackleConfig.DebugOffsetX = value
    if Gui then SetupGUI() end
end

local function SetDebugOffsetY(value)
    AutoTackleStatus.DebugOffsetY = value
    AutoTackleConfig.DebugOffsetY = value
    if Gui then SetupGUI() end
end

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local DribbleStates = {}
local TackleStates = {}
local PrecomputedPlayers = {}
local HasBall = false
local CanDribbleNow = false
local EagleEyeWaitStart = nil
local EagleEyeWaitTime = 0

local SPECIFIC_TACKLE_ID = "rbxassetid://14317040670"

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
        local a, b = points[i], points[i % segments + 1]
        local aScreen, aVis = Camera:WorldToViewportPoint(a)
        local bScreen, bVis = Camera:WorldToViewportPoint(b)
        if aVis and bVis and aScreen.Z > 0.1 and bScreen.Z > 0.1 then
            line.From = Vector2.new(aScreen.X, aScreen.Y)
            line.To = Vector2.new(bScreen.X, bScreen.Y)
            line.Color = (distance <= AutoTackleConfig.TackleDistance and Color3.fromRGB(0, 255, 0)) or (distance <= AutoTackleConfig.OptimalDistanceMax and Color3.fromRGB(255, 165, 0)) or Color3.fromRGB(255, 0, 0)
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
            local a, b = points[i], points[i % segments + 1]
            local aScreen, aVis = Camera:WorldToViewportPoint(a)
            local bScreen, bVis = Camera:WorldToViewportPoint(b)
            if aVis and bVis and aScreen.Z > 0.1 and bScreen.Z > 0.1 then
                line.From = Vector2.new(aScreen.X, aScreen.Y)
                line.To = Vector2.new(bScreen.X, bScreen.Y)
                line.Color = (data.Distance <= AutoDribbleConfig.DribbleActivationDistance and Color3.fromRGB(0, 255, 0)) or (data.Distance <= AutoDribbleConfig.MaxDribbleDistance and Color3.fromRGB(255, 165, 0)) or Color3.fromRGB(255, 0, 0)
                line.Visible = true
            end
        end
    end
end

local function IsDribbling(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Parent or targetPlayer.Team == LocalPlayer.Team then return false end
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
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Parent or targetPlayer.Team == LocalPlayer.Team then return false end
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
    local ball = Workspace:FindFirstChild("ball")
    if ball and ball:FindFirstChild("playerWeld") and ball:FindFirstChild("creator") then
        HasBall = ball.creator.Value == LocalPlayer
    end
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if bools then
        CanDribbleNow = not bools.dribbleDebounce.Value
        Gui.DribbleStatus.Text = bools.dribbleDebounce.Value and "Dribble: Cooldown" or "Dribble: Ready"
        Gui.DribbleStatus.Color = bools.dribbleDebounce.Value and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Parent or player.Team == LocalPlayer.Team then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.HipHeight >= 4 then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        if not DribbleStates[player] then DribbleStates[player] = { IsDribbling = false, LastDribbleEnd = 0, CooldownUntil = 0, DelayTriggered = false } end
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
        local dist = (hrp.Position - HumanoidRootPart.Position).Magnitude
        if dist > AutoDribbleConfig.MaxDribbleDistance then continue end
        if not Gui.TargetRings[player] then Gui.TargetRings[player] = CreateTargetRing() end
        local predPos = hrp.Position + hrp.AssemblyLinearVelocity * AutoDribbleConfig.PredictionTime
        PrecomputedPlayers[player] = { Distance = dist, PredictedPos = predPos, IsValid = true, IsTackling = TackleStates[player].IsTackling, RootPart = hrp }
    end
end

local function CanTackle()
    local ball = Workspace:FindFirstChild("ball")
    if not ball or not ball.Parent then return false, nil, nil, nil end
    local hasOwner = ball:FindFirstChild("playerWeld") and ball:FindFirstChild("creator")
    local owner = hasOwner and ball.creator.Value or nil
    if AutoTackleConfig.OnlyPlayer and (not hasOwner or not owner or not owner.Parent) then return false, nil, nil, nil end
    local isEnemy = not owner or (owner and owner.Team ~= LocalPlayer.Team)
    if not isEnemy then return false, nil, nil, nil end
    if Workspace:FindFirstChild("Bools") and (Workspace.Bools.APG.Value == LocalPlayer or Workspace.Bools.HPG.Value == LocalPlayer) then return false, nil, nil, nil end
    local dist = (HumanoidRootPart.Position - ball.Position).Magnitude
    if dist > AutoTackleConfig.MaxDistance then return false, nil, nil, nil end
    if owner and owner.Character then
        local targetHum = owner.Character:FindFirstChild("Humanoid")
        if targetHum and targetHum.HipHeight >= 4 then return false, nil, nil, nil end
    end
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if bools and (bools.TackleDebounce.Value or bools.Tackled.Value or Character:FindFirstChild("Bools") and Character.Bools.Debounce.Value) then return false, nil, nil, nil end
    return true, ball, dist, owner
end

local function PredictBallPosition(ball)
    if not ball or not ball.Parent then return nil end
    return ball.Position + ball.AssemblyLinearVelocity * AutoTackleConfig.PredictionTime
end

local function RotateToTarget(targetPos)
    if AutoTackleConfig.RotationType == "CFrame" then
        HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position, targetPos)
    end
end

local function PerformTackle(ball, owner)
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.TackleDebounce.Value or bools.Tackled.Value or Character:FindFirstChild("Bools") and Character.Bools.Debounce.Value then return end
    if AutoTackleConfig.RotationMethod == "Snap" and ball then
        local predPos = PredictBallPosition(ball) or ball.Position
        RotateToTarget(predPos)
    end
    pcall(function() ActionRemote:FireServer("TackIe") end)
    local bv = Instance.new("BodyVelocity")
    bv.Parent = HumanoidRootPart
    bv.Velocity = HumanoidRootPart.CFrame.LookVector * AutoTackleConfig.TackleSpeed
    bv.MaxForce = Vector3.new(50000000, 0, 50000000)
    local bg = Instance.new("BodyGyro")
    bg.Parent = HumanoidRootPart
    bg.Name = "TackleGyro"
    bg.P = 950000
    bg.MaxTorque = Vector3.new(0, 100000, 0)
    bg.CFrame = HumanoidRootPart.CFrame
    Debris:AddItem(bv, 0.65)
    Debris:AddItem(bg, 0.65)
    if owner and ball:FindFirstChild("playerWeld") then
        local dist = (HumanoidRootPart.Position - ball.Position).Magnitude
        pcall(function() SoftDisPlayerRemote:FireServer(owner, dist, false, ball.Size) end)
    end
end

local function PerformDribble()
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.dribbleDebounce.Value then return end
    pcall(function() ActionRemote:FireServer("Deke") end)
    Gui.DribbleStatus.Text = "Dribble: Cooldown"
    Gui.DribbleStatus.Color = Color3.fromRGB(255, 0, 0)
    Gui.AutoDribble.Text = "AutoDribble: DEKE (Slide Tackle!)"
end

local function EagleEye(ball, owner)
    if not owner or not owner.Character or not ball then
        Gui.TackleTarget.Text = "Target: None"
        Gui.TackleDribbling.Text = "isDribbling: false"
        Gui.TackleTackling.Text = "isTackling: false"
        Gui.EagleEye.Text = "EagleEye: Idle"
        UpdateTargetRing(nil, math.huge)
        return
    end
    local targetRoot = owner.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    local predPos = PredictBallPosition(ball) or ball.Position
    local dist = (HumanoidRootPart.Position - predPos).Magnitude
    if AutoTackleConfig.RotationMethod == "Snap" and dist <= AutoTackleConfig.MaxDistance then
        RotateToTarget(predPos)
    end
    local state = DribbleStates[owner] or { IsDribbling = false, LastDribbleEnd = 0, CooldownUntil = 0, DelayTriggered = false }
    local isDribbling = state.IsDribbling
    local inCooldown = tick() < state.CooldownUntil
    local timeSinceEnd = tick() - state.LastDribbleEnd
    local isTacklingNow = IsSpecificTackle(owner)
    Gui.TackleTarget.Text = "Target: " .. owner.Name
    Gui.TackleDribbling.Text = "isDribbling: " .. tostring(isDribbling)
    Gui.TackleTackling.Text = "isTackling: " .. tostring(isTacklingNow)
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
            EagleEyeWaitStart = tick()
            EagleEyeWaitTime = waitTime
            reason = "EagleEye"
        else
            local elapsed = tick() - EagleEyeWaitStart
            if elapsed >= EagleEyeWaitTime then
                shouldTackle = true
            else
                shouldTackle = false
                waitTime = EagleEyeWaitTime - elapsed
            end
        end
    end
    if waitTime > 0 then
        Gui.EagleEye.Text = "EagleEye: " .. reason
        Gui.TackleWait.Text = string.format("Wait: %.2f", waitTime)
    else
        Gui.EagleEye.Text = "EagleEye: Tackling (" .. reason .. ")"
        Gui.TackleWait.Text = "Wait: 0.00"
    end
    UpdateTargetRing(ball, dist)
    if shouldTackle and waitTime <= 0 then
        local can, _, _, _ = CanTackle()
        if can then
            PerformTackle(ball, owner)
            if reason ~= "Cooldown" then EagleEyeWaitStart = nil end
        end
    end
end

-- === AUTO TACKLE ===
local AutoTackle = {}
AutoTackle.Start = function()
    if AutoTackleStatus.Running then return end
    AutoTackleStatus.Running = true
    SetupGUI()
    AutoTackleStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoTackleConfig.Enabled then return end
        pcall(PrecomputePlayers)
        pcall(function()
            local can, ball, dist, owner = CanTackle()
            if not can or not ball then
                Gui.TackleTarget.Text = "Target: None"
                Gui.TackleDribbling.Text = "isDribbling: false"
                Gui.TackleTackling.Text = "isTackling: false"
                Gui.EagleEye.Text = "EagleEye: Idle"
                UpdateTargetRing(nil, math.huge)
                return
            end
            if dist <= AutoTackleConfig.TackleDistance then
                PerformTackle(ball, owner)
            else
                EagleEye(ball, owner)
            end
        end)
    end)
    AutoTackleStatus.RenderConnection = RunService.RenderStepped:Connect(function()
        pcall(UpdateTargetRings)
    end)
    notify("AutoTackle", "Started", true)
end
AutoTackle.Stop = function()
    if AutoTackleStatus.Connection then AutoTackleStatus.Connection:Disconnect(); AutoTackleStatus.Connection = nil end
    if AutoTackleStatus.RenderConnection then AutoTackleStatus.RenderConnection:Disconnect(); AutoTackleStatus.RenderConnection = nil end
    AutoTackleStatus.Running = false
    if Gui then
        for _, v in pairs(Gui) do
            if typeof(v) == "table" then
                for _, l in ipairs(v) do if l.Remove then l:Remove() end
            else
                if v.Remove then v:Remove() end
            end
        end
        Gui = nil
    end
    notify("AutoTackle", "Stopped", true)
end
AutoTackle.SetDebugText = function(value)
    AutoTackleStatus.DebugText = value
    AutoTackleConfig.DebugText = value
    ToggleDebugText(value)
    notify("AutoTackle", "Debug Text " .. (value and "Enabled" or "Disabled"), true)
end

-- === AUTO DRIBBLE ===
local AutoDribble = {}
AutoDribble.Start = function()
    if AutoDribbleStatus.Running then return end
    AutoDribbleStatus.Running = true
    AutoDribbleStatus.Connection = RunService.RenderStepped:Connect(function()
        if not AutoDribbleConfig.Enabled then
            Gui.DribbleTarget.Text = "Targets: 0"
            Gui.DribbleTackling.Text = "Nearest: None"
            Gui.AutoDribble.Text = "AutoDribble: Idle"
            return
        end
        pcall(function()
            local specificTarget = nil
            local minDist = math.huge
            local targetCount = 0
            for player, data in pairs(PrecomputedPlayers) do
                if data.IsValid and TackleStates[player].IsTackling then
                    targetCount = targetCount + 1
                    if data.Distance < minDist then
                        minDist = data.Distance
                        specificTarget = player
                    end
                end
            end
            Gui.DribbleTarget.Text = "Targets: " .. targetCount
            Gui.DribbleTackling.Text = specificTarget and string.format("Tackle: %.1f", minDist) or "Tackle: None"
            if HasBall and CanDribbleNow and specificTarget and minDist <= AutoDribbleConfig.DribbleActivationDistance then
                PerformDribble()
            else
                Gui.AutoDribble.Text = "AutoDribble: Idle"
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
        uiElements.AutoTackleMaxDist = UI.Sections.AutoTackle:Slider({ Name = "Max Distance", Minimum = 10, Maximum = 50, Default = AutoTackleConfig.MaxDistance, Precision = 1, Callback = function(v) AutoTackleConfig.MaxDistance = v end }, "AutoTackleMaxDist")
        uiElements.AutoTackleTackleDist = UI.Sections.AutoTackle:Slider({ Name = "Tackle Distance", Minimum = 0, Maximum = 10, Default = AutoTackleConfig.TackleDistance, Precision = 1, Callback = function(v) AutoTackleConfig.TackleDistance = v end }, "AutoTackleTackleDist")
        uiElements.AutoTackleOptimalMin = UI.Sections.AutoTackle:Slider({ Name = "Optimal Dist Min", Minimum = 1, Maximum = 10, Default = AutoTackleConfig.OptimalDistanceMin, Precision = 1, Callback = function(v) AutoTackleConfig.OptimalDistanceMin = v end }, "AutoTackleOptimalMin")
        uiElements.AutoTackleOptimalMax = UI.Sections.AutoTackle:Slider({ Name = "Optimal Dist Max", Minimum = 10, Maximum = 30, Default = AutoTackleConfig.OptimalDistanceMax, Precision = 1, Callback = function(v) AutoTackleConfig.OptimalDistanceMax = v end }, "AutoTackleOptimalMax")
        uiElements.AutoTackleSpeed = UI.Sections.AutoTackle:Slider({ Name = "Tackle Speed", Minimum = 20, Maximum = 100, Default = AutoTackleConfig.TackleSpeed, Precision = 1, Callback = function(v) AutoTackleConfig.TackleSpeed = v end }, "AutoTackleSpeed")
        uiElements.AutoTacklePredTime = UI.Sections.AutoTackle:Slider({ Name = "Prediction Time", Minimum = 0.1, Maximum = 2.0, Default = AutoTackleConfig.PredictionTime, Precision = 2, Callback = function(v) AutoTackleConfig.PredictionTime = v end }, "AutoTacklePredTime")
        uiElements.AutoTackleOnlyPlayer = UI.Sections.AutoTackle:Toggle({ Name = "Only Player", Default = AutoTackleConfig.OnlyPlayer, Callback = function(v) AutoTackleConfig.OnlyPlayer = v end }, "AutoTackleOnlyPlayer")
        uiElements.AutoTackleRotationMethod = UI.Sections.AutoTackle:Dropdown({ Name = "Rotation Method", Options = {"Snap"}, Default = AutoTackleConfig.RotationMethod, Callback = function(v) AutoTackleConfig.RotationMethod = v end }, "AutoTackleRotationMethod")
        uiElements.AutoTackleRotationType = UI.Sections.AutoTackle:Dropdown({ Name = "Rotation Type", Options = {"CFrame"}, Default = AutoTackleConfig.RotationType, Callback = function(v) AutoTackleConfig.RotationType = v end }, "AutoTackleRotationType")
        uiElements.AutoTackleMaxAngle = UI.Sections.AutoTackle:Slider({ Name = "Max Angle", Minimum = 0, Maximum = 360, Default = AutoTackleConfig.MaxAngle, Precision = 1, Callback = function(v) AutoTackleConfig.MaxAngle = v end }, "AutoTackleMaxAngle")
        uiElements.AutoTackleEagleEyeExceptions = UI.Sections.AutoTackle:Dropdown({ Name = "EagleEye Exceptions", Options = {"None", "OnlyDribble", "Dribble", "Dribble&Tackle"}, Default = AutoTackleConfig.EagleEyeExceptions, Callback = function(v) AutoTackleConfig.EagleEyeExceptions = v end }, "AutoTackleEagleEyeExceptions")
        uiElements.AutoTackleDribbleDelay = UI.Sections.AutoTackle:Dropdown({ Name = "Dribble Delay", Options = {"Delay", "Smart"}, Default = AutoTackleConfig.DribbleDelay, Callback = function(v) AutoTackleConfig.DribbleDelay = v end }, "AutoTackleDribbleDelay")
        uiElements.AutoTackleDribbleDelayTime = UI.Sections.AutoTackle:Slider({ Name = "Dribble Delay Time", Minimum = 0, Maximum = 5, Default = AutoTackleConfig.DribbleDelayTime, Precision = 1, Callback = function(v) AutoTackleConfig.DribbleDelayTime = v end }, "AutoTackleDribbleDelayTime")
        uiElements.AutoTackleEagleEyeMinDelay = UI.Sections.AutoTackle:Slider({ Name = "EagleEye Min Delay", Minimum = 0.0, Maximum = 1.0, Default = AutoTackleConfig.EagleEyeMinDelay, Precision = 2, Callback = function(v) AutoTackleConfig.EagleEyeMinDelay = v end }, "AutoTackleEagleEyeMinDelay")
        uiElements.AutoTackleEagleEyeMaxDelay = UI.Sections.AutoTackle:Slider({ Name = "EagleEye Max Delay", Minimum = 0.0, Maximum = 2.0, Default = AutoTackleConfig.EagleEyeMaxDelay, Precision = 2, Callback = function(v) AutoTackleConfig.EagleEyeMaxDelay = v end }, "AutoTackleEagleEyeMaxDelay")
        uiElements.AutoTackleDebugText = UI.Sections.AutoTackle:Toggle({ Name = "Debug Text", Default = AutoTackleConfig.DebugText, Callback = function(v) AutoTackle.SetDebugText(v) end }, "AutoTackleDebugText")
        uiElements.AutoTackleDebugOffsetX = UI.Sections.AutoTackle:Slider({ Name = "Debug Offset X", Minimum = -200, Maximum = 200, Default = AutoTackleConfig.DebugOffsetX, Precision = 1, Callback = SetDebugOffsetX }, "AutoTackleDebugOffsetX")
        uiElements.AutoTackleDebugOffsetY = UI.Sections.AutoTackle:Slider({ Name = "Debug Offset Y", Minimum = -200, Maximum = 200, Default = AutoTackleConfig.DebugOffsetY, Precision = 1, Callback = SetDebugOffsetY }, "AutoTackleDebugOffsetY")
    end

    if UI.Sections.AutoDribble then
        UI.Sections.AutoDribble:Header({ Name = "AutoDribble" })
        UI.Sections.AutoDribble:Divider()
        uiElements.AutoDribbleEnabled = UI.Sections.AutoDribble:Toggle({ Name = "Enabled", Default = AutoDribbleConfig.Enabled, Callback = function(v) AutoDribbleConfig.Enabled = v; if v then AutoDribble.Start() else AutoDribble.Stop() end end }, "AutoDribbleEnabled")
        uiElements.AutoDribbleMaxDist = UI.Sections.AutoDribble:Slider({ Name = "Max Dribble Distance", Minimum = 10, Maximum = 50, Default = AutoDribbleConfig.MaxDribbleDistance, Precision = 1, Callback = function(v) AutoDribbleConfig.MaxDribbleDistance = v end }, "AutoDribbleMaxDist")
        uiElements.AutoDribbleActivationDist = UI.Sections.AutoDribble:Slider({ Name = "Activation Distance", Minimum = 5, Maximum = 30, Default = AutoDribbleConfig.DribbleActivationDistance, Precision = 1, Callback = function(v) AutoDribbleConfig.DribbleActivationDistance = v end }, "AutoDribbleActivationDist")
        uiElements.AutoDribbleMaxAngle = UI.Sections.AutoDribble:Slider({ Name = "Max Angle", Minimum = 0, Maximum = 360, Default = AutoDribbleConfig.MaxAngle, Precision = 1, Callback = function(v) AutoDribbleConfig.MaxAngle = v end }, "AutoDribbleMaxAngle")
        uiElements.AutoDribblePredTime = UI.Sections.AutoDribble:Slider({ Name = "Prediction Time", Minimum = 0.01, Maximum = 0.5, Default = AutoDribbleConfig.PredictionTime, Precision = 2, Callback = function(v) AutoDribbleConfig.PredictionTime = v end }, "AutoDribblePredTime")
        uiElements.AutoDribbleMaxPredAngle = UI.Sections.AutoDribble:Slider({ Name = "Max Prediction Angle", Minimum = 10, Maximum = 90, Default = AutoDribbleConfig.MaxPredictionAngle, Precision = 1, Callback = function(v) AutoDribbleConfig.MaxPredictionAngle = v end }, "AutoDribbleMaxPredAngle")
        uiElements.AutoDribbleTacklePredTime = UI.Sections.AutoDribble:Slider({ Name = "Tackle Prediction Time", Minimum = 0.1, Maximum = 1.0, Default = AutoDribbleConfig.TacklePredictionTime, Precision = 2, Callback = function(v) AutoDribbleConfig.TacklePredictionTime = v end }, "AutoDribbleTacklePredTime")
        uiElements.AutoDribbleTackleAngleThreshold = UI.Sections.AutoDribble:Slider({ Name = "Tackle Angle Threshold", Minimum = 0.1, Maximum = 1.0, Default = AutoDribbleConfig.TackleAngleThreshold, Precision = 2, Callback = function(v) AutoDribbleConfig.TackleAngleThreshold = v end }, "AutoDribbleTackleAngleThreshold")
    end

    local syncSection = UI.Tabs.Config:Section({ Name = "AutoTackle & AutoDribble Sync", Side = "Right" })
    syncSection:Header({ Name = "AutoTackle/AutoDribble" })
    syncSection:Button({ Name = "Sync Config", Callback = function()
        AutoTackleConfig.Enabled = uiElements.AutoTackleEnabled:GetState()
        AutoTackleConfig.MaxDistance = uiElements.AutoTackleMaxDist:GetValue()
        AutoTackleConfig.TackleDistance = uiElements.AutoTackleTackleDist:GetValue()
        AutoTackleConfig.OptimalDistanceMin = uiElements.AutoTackleOptimalMin:GetValue()
        AutoTackleConfig.OptimalDistanceMax = uiElements.AutoTackleOptimalMax:GetValue()
        AutoTackleConfig.TackleSpeed = uiElements.AutoTackleSpeed:GetValue()
        AutoTackleConfig.PredictionTime = uiElements.AutoTacklePredTime:GetValue()
        AutoTackleConfig.OnlyPlayer = uiElements.AutoTackleOnlyPlayer:GetState()
        AutoTackleConfig.RotationMethod = uiElements.AutoTackleRotationMethod:GetValue()
        AutoTackleConfig.RotationType = uiElements.AutoTackleRotationType:GetValue()
        AutoTackleConfig.MaxAngle = uiElements.AutoTackleMaxAngle:GetValue()
        AutoTackleConfig.EagleEyeExceptions = uiElements.AutoTackleEagleEyeExceptions:GetValue()
        AutoTackleConfig.DribbleDelay = uiElements.AutoTackleDribbleDelay:GetValue()
        AutoTackleConfig.DribbleDelayTime = uiElements.AutoTackleDribbleDelayTime:GetValue()
        AutoTackleConfig.EagleEyeMinDelay = uiElements.AutoTackleEagleEyeMinDelay:GetValue()
        AutoTackleConfig.EagleEyeMaxDelay = uiElements.AutoTackleEagleEyeMaxDelay:GetValue()
        AutoTackleConfig.DebugText = uiElements.AutoTackleDebugText:GetState()
        AutoTackleConfig.DebugOffsetX = uiElements.AutoTackleDebugOffsetX:GetValue()
        AutoTackleConfig.DebugOffsetY = uiElements.AutoTackleDebugOffsetY:GetValue()
        AutoDribbleConfig.Enabled = uiElements.AutoDribbleEnabled:GetState()
        AutoDribbleConfig.MaxDribbleDistance = uiElements.AutoDribbleMaxDist:GetValue()
        AutoDribbleConfig.DribbleActivationDistance = uiElements.AutoDribbleActivationDist:GetValue()
        AutoDribbleConfig.MaxAngle = uiElements.AutoDribbleMaxAngle:GetValue()
        AutoDribbleConfig.PredictionTime = uiElements.AutoDribblePredTime:GetValue()
        AutoDribbleConfig.MaxPredictionAngle = uiElements.AutoDribbleMaxPredAngle:GetValue()
        AutoDribbleConfig.TacklePredictionTime = uiElements.AutoDribbleTacklePredTime:GetValue()
        AutoDribbleConfig.TackleAngleThreshold = uiElements.AutoDribbleTackleAngleThreshold:GetValue()
        AutoTackleStatus.DebugText = AutoTackleConfig.DebugText
        AutoTackleStatus.DebugOffsetX = AutoTackleConfig.DebugOffsetX
        AutoTackleStatus.DebugOffsetY = AutoTackleConfig.DebugOffsetY
        ToggleDebugText(AutoTackleStatus.DebugText)
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
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
        if AutoTackleConfig.Enabled then AutoTackle.Start() end
        if AutoDribbleConfig.Enabled then AutoDribble.Start() end
    end)
    Players.PlayerRemoving:Connect(function(player)
        DribbleStates[player] = nil
        PrecomputedPlayers[player] = nil
        TackleStates[player] = nil
        if Gui and Gui.TargetRings[player] then
            for _, line in ipairs(Gui.TargetRings[player]) do line:Remove() end
            Gui.TargetRings[player] = nil
        end
    end)
end
function AutoTackleModule:Destroy()
    AutoTackle.Stop()
    AutoDribble.Stop()
end
return AutoTackleModule
