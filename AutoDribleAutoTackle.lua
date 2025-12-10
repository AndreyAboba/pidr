-- [v2.0] AUTO DRIBBLE + AUTO TACKLE + FULL GUI + UI INTEGRATION
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local ActionRemote = ReplicatedStorage.Remotes:WaitForChild("Action")
local SoftDisPlayerRemote = ReplicatedStorage.Remotes:WaitForChild("SoftDisPlayer")
local Animations = ReplicatedStorage:WaitForChild("Animations")
local DribbleAnims = Animations:WaitForChild("Dribble")

-- === АНИМАЦИИ ===
local DribbleAnimIds = {}
for _, anim in pairs(DribbleAnims:GetChildren()) do
    if anim:IsA("Animation") then
        table.insert(DribbleAnimIds, anim.AnimationId)
    end
end

-- === CONFIG ===
local AutoTackleConfig = {
    Enabled = false,
    Mode = "OnlyDribble", -- "OnlyDribble", "EagleEye", "ManualTackle"
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
    DribbleDelayTime = 0.3,
    EagleEyeMinDelay = 0.1,
    EagleEyeMaxDelay = 0.6,
    ManualTackleEnabled = true,
    ManualTackleKeybind = Enum.KeyCode.Q,
    ManualTackleCooldown = 0.5
}

local AutoDribbleConfig = {
    Enabled = false,
    MaxDribbleDistance = 30,
    DribbleActivationDistance = 16,
    MaxAngle = 360,
    PredictionTime = 0.098,
    MaxPredictionAngle = 38,
    TacklePredictionTime = 0.3,
    TackleAngleThreshold = 0.7
}

-- === STATES ===
local AutoTackleStatus = {
    Running = false,
    Connection = nil,
    HeartbeatConnection = nil,
    RenderConnection = nil,
    InputConnection = nil
}
local AutoDribbleStatus = {
    Running = false,
    Connection = nil
}

-- === SHARED STATES ===
local DribbleStates = {}
local TackleStates = {}
local PrecomputedPlayers = {}
local HasBall = false
local CanDribbleNow = false
local DribbleCooldownList = {}
local PowerShootingPlayers = {}
local EagleEyeTimers = {}
local IsTypingInChat = false
local LastManualTackleTime = 0
local CurrentTargetOwner = nil

local SPECIFIC_TACKLE_ID = "rbxassetid://14317040670"

-- === GUI (Drawing) ===
local Gui = nil
local function SetupGUI()
    Gui = {
        TackleWaitLabel = Drawing.new("Text"),
        TackleTargetLabel = Drawing.new("Text"),
        TackleDribblingLabel = Drawing.new("Text"),
        TackleTacklingLabel = Drawing.new("Text"),
        EagleEyeLabel = Drawing.new("Text"),
        DribbleStatusLabel = Drawing.new("Text"),
        DribbleTargetLabel = Drawing.new("Text"),
        DribbleTacklingLabel = Drawing.new("Text"),
        AutoDribbleLabel = Drawing.new("Text"),
        CooldownListLabel = Drawing.new("Text"),
        ModeLabel = Drawing.new("Text"),
        ManualTackleLabel = Drawing.new("Text"),
        TargetRingLines = {},
        TargetRings = {}
    }
    
    local screenSize = Camera.ViewportSize
    local centerX = screenSize.X / 2
    local tackleY = screenSize.Y * 0.6
    local offsetTackleY = tackleY + 30
    local offsetDribbleY = tackleY - 50
    
    local textLabels = {
        Gui.TackleWaitLabel, Gui.TackleTargetLabel, Gui.TackleDribblingLabel,
        Gui.TackleTacklingLabel, Gui.EagleEyeLabel, Gui.DribbleStatusLabel,
        Gui.DribbleTargetLabel, Gui.DribbleTacklingLabel, Gui.AutoDribbleLabel,
        Gui.CooldownListLabel, Gui.ModeLabel, Gui.ManualTackleLabel
    }
    
    for _, label in ipairs(textLabels) do
        label.Size = 16
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
    Gui.EagleEyeLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.CooldownListLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.ModeLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.ManualTackleLabel.Position = Vector2.new(centerX, offsetTackleY)
    
    Gui.DribbleStatusLabel.Position = Vector2.new(centerX, offsetDribbleY); offsetDribbleY += 15
    Gui.DribbleTargetLabel.Position = Vector2.new(centerX, offsetDribbleY); offsetDribbleY += 15
    Gui.DribbleTacklingLabel.Position = Vector2.new(centerX, offsetDribbleY); offsetDribbleY += 15
    Gui.AutoDribbleLabel.Position = Vector2.new(centerX, offsetDribbleY)
    
    Gui.TackleWaitLabel.Text = "Wait: 0.00"
    Gui.TackleTargetLabel.Text = "Target: None"
    Gui.TackleDribblingLabel.Text = "isDribbling: false"
    Gui.TackleTacklingLabel.Text = "isTackling: false"
    Gui.EagleEyeLabel.Text = "EagleEye: Idle"
    Gui.CooldownListLabel.Text = "CooldownList: 0"
    Gui.ModeLabel.Text = "Mode: " .. AutoTackleConfig.Mode
    Gui.ManualTackleLabel.Text = "ManualTackle: Ready [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
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

local function ToggleGUI(value)
    if not Gui then return end
    for _, label in pairs(Gui) do
        if type(label) == "table" and label.Visible ~= nil then
            label.Visible = value
        end
    end
end

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function CheckIfTypingInChat()
    local success, result = pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        local chatGui = playerGui:FindFirstChild("Chat")
        
        if chatGui then
            local chatBar = chatGui:FindFirstChild("Frame") and chatGui.Frame:FindFirstChild("ChatBar")
            if chatBar then
                local container = chatBar:FindFirstChild("Container")
                if container then
                    local frame = container:FindFirstChild("Frame")
                    if frame then
                        local textBox = frame:FindFirstChild("TextBox")
                        if textBox then
                            return textBox:IsFocused()
                        end
                    end
                end
            end
        end
        
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name == "Chat" or gui.Name:find("Chat")) then
                local textBox = gui:FindFirstChild("TextBox", true)
                if textBox then
                    return textBox:IsFocused()
                end
            end
        end
        
        return false
    end)
    
    return success and result or false
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

local function IsPowerShooting(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local bools = targetPlayer.Character:FindFirstChild("Bools")
    if bools and bools:FindFirstChild("PowerShooting") then
        return bools.PowerShooting.Value
    end
    return false
end

local function UpdateDribbleStates()
    local currentTime = tick()
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Parent or player.TeamColor == LocalPlayer.TeamColor then continue end
        
        if not DribbleStates[player] then
            DribbleStates[player] = {
                IsDribbling = false,
                LastDribbleEnd = 0,
                HasUsedDribble = false,
                IsProcessingDelay = false
            }
        end
        
        local state = DribbleStates[player]
        local isDribblingNow = IsDribbling(player)
        PowerShootingPlayers[player] = IsPowerShooting(player)
        
        if isDribblingNow and not state.IsDribbling then
            state.IsDribbling = true
            state.IsProcessingDelay = false
            state.HasUsedDribble = true
            
        elseif not isDribblingNow and state.IsDribbling then
            state.IsDribbling = false
            state.LastDribbleEnd = currentTime
            state.IsProcessingDelay = true
            
        elseif state.IsProcessingDelay and not isDribblingNow then
            local timeSinceEnd = currentTime - state.LastDribbleEnd
            
            if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                DribbleCooldownList[player] = currentTime + 3.5
                state.IsProcessingDelay = false
            end
        end
    end
    
    local toRemove = {}
    for player, endTime in pairs(DribbleCooldownList) do
        if not player or not player.Parent then
            table.insert(toRemove, player)
        elseif currentTime >= endTime then
            table.insert(toRemove, player)
        end
    end
    
    for _, player in ipairs(toRemove) do
        DribbleCooldownList[player] = nil
        EagleEyeTimers[player] = nil
    end
    
    if Gui then
        Gui.CooldownListLabel.Text = "CooldownList: " .. tostring(table.count(DribbleCooldownList))
    end
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
        if Gui then
            Gui.DribbleStatusLabel.Text = bools.dribbleDebounce.Value and "Dribble: Cooldown" or "Dribble: Ready"
            Gui.DribbleStatusLabel.Color = bools.dribbleDebounce.Value and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
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

        TackleStates[player] = TackleStates[player] or { IsTackling = false }
        TackleStates[player].IsTackling = IsSpecificTackle(player)

        local distance = (targetRoot.Position - HumanoidRootPart.Position).Magnitude
        if distance > AutoDribbleConfig.MaxDribbleDistance then continue end

        if not Gui.TargetRings[player] then Gui.TargetRings[player] = CreateTargetRing() end

        local predictedPos = targetRoot.Position + targetRoot.AssemblyLinearVelocity * AutoDribbleConfig.PredictionTime

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
    local ball = Workspace:FindFirstChild("ball")
    if not ball or not ball.Parent then return false, nil, nil, nil end
    local hasOwner = ball:FindFirstChild("playerWeld") and ball:FindFirstChild("creator")
    local owner = hasOwner and ball.creator.Value or nil
    if AutoTackleConfig.OnlyPlayer and (not hasOwner or not owner or not owner.Parent) then
        return false, nil, nil, nil
    end
    local isEnemy = not owner or (owner and owner.TeamColor ~= LocalPlayer.TeamColor)
    if not isEnemy then return false, nil, nil, nil end
    if Workspace:FindFirstChild("Bools") and (Workspace.Bools.APG.Value == LocalPlayer or Workspace.Bools.HPG.Value == LocalPlayer) then
        return false, nil, nil, nil
    end
    local distance = (HumanoidRootPart.Position - ball.Position).Magnitude
    if distance > AutoTackleConfig.MaxDistance then
        return false, nil, nil, nil
    end
    if owner and owner.Character then
        local targetHumanoid = owner.Character:FindFirstChild("Humanoid")
        if targetHumanoid and targetHumanoid.HipHeight >= 4 then
            return false, nil, nil, nil
        end
    end
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if bools and (bools.TackleDebounce.Value or bools.Tackled.Value or Character:FindFirstChild("Bools") and Character.Bools.Debounce.Value) then
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
        HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position, targetPos)
    end
end

local function PerformTackle(ball, owner)
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.TackleDebounce.Value or bools.Tackled.Value or Character:FindFirstChild("Bools") and Character.Bools.Debounce.Value then return end
    if AutoTackleConfig.RotationMethod == "Snap" and ball then
        local predictedPos = PredictBallPosition(ball) or ball.Position
        RotateToTarget(predictedPos)
    end
    pcall(function() ActionRemote:FireServer("TackIe") end)
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Parent = HumanoidRootPart
    bodyVelocity.Velocity = HumanoidRootPart.CFrame.LookVector * AutoTackleConfig.TackleSpeed
    bodyVelocity.MaxForce = Vector3.new(50000000, 0, 50000000)
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Parent = HumanoidRootPart
    bodyGyro.Name = "TackleGyro"
    bodyGyro.P = 950000
    bodyGyro.MaxTorque = Vector3.new(0, 100000, 0)
    bodyGyro.CFrame = HumanoidRootPart.CFrame
    Debris:AddItem(bodyVelocity, 0.65)
    Debris:AddItem(bodyGyro, 0.65)
    if owner and ball:FindFirstChild("playerWeld") then
        local distance = (HumanoidRootPart.Position - ball.Position).Magnitude
        pcall(function() SoftDisPlayerRemote:FireServer(owner, distance, false, ball.Size) end)
    end
end

local function PerformDribble()
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.dribbleDebounce.Value then return end
    pcall(function() ActionRemote:FireServer("Deke") end)
    if Gui then
        Gui.DribbleStatusLabel.Text = "Dribble: Cooldown"
        Gui.DribbleStatusLabel.Color = Color3.fromRGB(255, 0, 0)
        Gui.AutoDribbleLabel.Text = "AutoDribble: DEKE (Slide Tackle!)"
    end
end

local function ManualTackleAction()
    local currentTime = tick()
    if currentTime - LastManualTackleTime < AutoTackleConfig.ManualTackleCooldown then 
        return false 
    end
    
    local canTackle, ball, distance, owner
    
    if AutoTackleConfig.Mode == "ManualTackle" then
        canTackle, ball, distance, owner = CanTackle()
    else
        if CurrentTargetOwner and CurrentTargetOwner.Parent then
            local canTackleTemp, ballTemp, distanceTemp, _ = CanTackle()
            if canTackleTemp and ballTemp and ballTemp.creator and ballTemp.creator.Value == CurrentTargetOwner then
                canTackle = canTackleTemp
                ball = ballTemp
                distance = distanceTemp
                owner = CurrentTargetOwner
            else
                canTackle, ball, distance, owner = CanTackle()
            end
        else
            canTackle, ball, distance, owner = CanTackle()
        end
    end
    
    if canTackle then
        LastManualTackleTime = currentTime
        PerformTackle(ball, owner)
        if Gui then
            Gui.ManualTackleLabel.Text = "ManualTackle: EXECUTED! [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
            Gui.ManualTackleLabel.Color = Color3.fromRGB(0, 255, 0)
        end
        
        task.delay(0.3, function()
            if Gui then
                Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 255, 255)
            end
        end)
        return true
    else
        if Gui then
            Gui.ManualTackleLabel.Text = "ManualTackle: FAILED [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
            Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 0, 0)
        end
        
        task.delay(0.3, function()
            if Gui then
                Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 255, 255)
            end
        end)
        return false
    end
end

local function ProcessEagleEyeMode(owner, ball)
    if not owner then return false, 0, "NoTarget" end
    
    local state = DribbleStates[owner] or {
        IsDribbling = false,
        LastDribbleEnd = 0,
        HasUsedDribble = false,
        IsProcessingDelay = false
    }
    
    local currentTime = tick()
    local isDribbling = state.IsDribbling
    local inCooldownList = DribbleCooldownList[owner] ~= nil
    local isPowerShooting = PowerShootingPlayers[owner] or false
    local timeSinceEnd = currentTime - state.LastDribbleEnd
    
    if isPowerShooting then
        return true, 0, "PowerShooting"
    end
    
    if inCooldownList then
        return true, 0, "InCooldownList"
    end
    
    if isDribbling or state.IsProcessingDelay then
        if state.IsProcessingDelay then
            if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                if not EagleEyeTimers[owner] then
                    EagleEyeTimers[owner] = {
                        startTime = currentTime,
                        waitTime = AutoTackleConfig.EagleEyeMinDelay + 
                                   math.random() * (AutoTackleConfig.EagleEyeMaxDelay - AutoTackleConfig.EagleEyeMinDelay)
                    }
                end
                
                local timer = EagleEyeTimers[owner]
                local eagleElapsed = currentTime - timer.startTime
                
                if eagleElapsed >= timer.waitTime then
                    return true, 0, "EagleEyeReady"
                else
                    return false, timer.waitTime - eagleElapsed, "EagleEyeWaiting"
                end
            else
                return false, AutoTackleConfig.DribbleDelayTime - timeSinceEnd, "WaitingDribbleDelay"
            end
        else
            return false, 999, "StillDribbling"
        end
    end
    
    if not EagleEyeTimers[owner] then
        EagleEyeTimers[owner] = {
            startTime = currentTime,
            waitTime = AutoTackleConfig.EagleEyeMinDelay + 
                       math.random() * (AutoTackleConfig.EagleEyeMaxDelay - AutoTackleConfig.EagleEyeMinDelay)
        }
    end
    
    local timer = EagleEyeTimers[owner]
    local eagleElapsed = currentTime - timer.startTime
    
    if eagleElapsed >= timer.waitTime then
        return true, 0, "EagleEyeReady"
    else
        return false, timer.waitTime - eagleElapsed, "EagleEyeWaiting"
    end
end

local function ProcessOnlyDribbleMode(owner, ball)
    if not owner then return false, 0, "NoTarget" end
    
    local state = DribbleStates[owner] or {
        IsDribbling = false,
        LastDribbleEnd = 0,
        HasUsedDribble = false,
        IsProcessingDelay = false
    }
    
    local currentTime = tick()
    local isDribbling = state.IsDribbling
    local inCooldownList = DribbleCooldownList[owner] ~= nil
    local isPowerShooting = PowerShootingPlayers[owner] or false
    local timeSinceEnd = currentTime - state.LastDribbleEnd
    
    if isPowerShooting then
        return true, 0, "PowerShooting"
    end
    
    if inCooldownList then
        return true, 0, "InCooldownList"
    end
    
    if isDribbling or state.IsProcessingDelay then
        if state.IsProcessingDelay then
            if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                return true, 0, "DribbleDelayEnded"
            else
                return false, AutoTackleConfig.DribbleDelayTime - timeSinceEnd, "WaitingDribbleDelay"
            end
        else
            return false, 999, "StillDribbling"
        end
    end
    
    return false, 0, "NotApplicable"
end

local function ProcessManualTackleMode(owner, ball)
    if not owner then return false, 0, "Press " .. tostring(AutoTackleConfig.ManualTackleKeybind) .. " to tackle" end
    
    local canTackle, _, distance, _ = CanTackle()
    
    if canTackle then
        if Gui then
            Gui.ManualTackleLabel.Text = "ManualTackle: READY [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
            Gui.ManualTackleLabel.Color = Color3.fromRGB(0, 255, 0)
        end
        return false, 0, "Ready - Press " .. tostring(AutoTackleConfig.ManualTackleKeybind)
    else
        if Gui then
            Gui.ManualTackleLabel.Text = "ManualTackle: NOT READY [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
            Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 0, 0)
        end
        return false, 0, "Cannot tackle now"
    end
end

local function ProcessTackle(ball, owner)
    if not owner or not owner.Character or not ball then
        if Gui then
            Gui.TackleTargetLabel.Text = "Target: None"
            Gui.TackleDribblingLabel.Text = "isDribbling: false"
            Gui.TackleTacklingLabel.Text = "isTackling: false"
            Gui.TackleWaitLabel.Text = "Wait: 0.00"
            Gui.ManualTackleLabel.Text = "ManualTackle: NO TARGET [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
        end
        UpdateTargetRing(nil, math.huge)
        CurrentTargetOwner = nil
        return false
    end

    local targetRoot = owner.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end

    local predictedPos = PredictBallPosition(ball) or ball.Position
    local distance = (HumanoidRootPart.Position - predictedPos).Magnitude

    if AutoTackleConfig.RotationMethod == "Always" and distance <= AutoTackleConfig.MaxDistance then
        RotateToTarget(predictedPos)
    end

    local state = DribbleStates[owner] or {
        IsDribbling = false,
        LastDribbleEnd = 0,
        HasUsedDribble = false,
        IsProcessingDelay = false
    }
    
    local isDribbling = state.IsDribbling
    local isTacklingNow = IsSpecificTackle(owner)

    if Gui then
        Gui.TackleTargetLabel.Text = "Target: " .. owner.Name
        Gui.TackleDribblingLabel.Text = "isDribbling: " .. tostring(isDribbling)
        Gui.TackleTacklingLabel.Text = "isTackling: " .. tostring(isTacklingNow)
    end

    local shouldTackle = false
    local waitTime = 0
    local reason = ""
    
    CurrentTargetOwner = owner
    
    if AutoTackleConfig.Mode == "EagleEye" then
        shouldTackle, waitTime, reason = ProcessEagleEyeMode(owner, ball)
    elseif AutoTackleConfig.Mode == "OnlyDribble" then
        shouldTackle, waitTime, reason = ProcessOnlyDribbleMode(owner, ball)
    elseif AutoTackleConfig.Mode == "ManualTackle" then
        shouldTackle, waitTime, reason = ProcessManualTackleMode(owner, ball)
    end
    
    if waitTime > 0 and waitTime < 999 then
        if Gui then
            Gui.TackleWaitLabel.Text = string.format("Wait: %.2f", waitTime)
            Gui.EagleEyeLabel.Text = "Status: " .. reason
        end
    else
        if Gui then
            Gui.TackleWaitLabel.Text = "Wait: 0.00"
            Gui.EagleEyeLabel.Text = "Status: " .. reason
        end
    end
    
    UpdateTargetRing(ball, distance)
    
    if shouldTackle and AutoTackleConfig.Mode ~= "ManualTackle" then
        local canTackle, _, _, _ = CanTackle()
        if canTackle then
            PerformTackle(ball, owner)
            EagleEyeTimers[owner] = nil
            return true
        end
    end
    
    return false
end

-- === AUTO TACKLE MODULE ===
local AutoTackle = {}
AutoTackle.Start = function()
    if AutoTackleStatus.Running then return end
    AutoTackleStatus.Running = true
    
    SetupGUI()
    
    -- Heartbeat для обновления состояний
    AutoTackleStatus.HeartbeatConnection = RunService.Heartbeat:Connect(function()
        pcall(UpdateDribbleStates)
        pcall(PrecomputePlayers)
        pcall(UpdateTargetRings)
        IsTypingInChat = CheckIfTypingInChat()
    end)
    
    -- Heartbeat для логики такла
    AutoTackleStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoTackleConfig.Enabled then return end
        
        pcall(function()
            local canTackle, ball, distance, owner = CanTackle()
            if not canTackle or not ball then
                if Gui then
                    Gui.TackleTargetLabel.Text = "Target: None"
                    Gui.TackleDribblingLabel.Text = "isDribbling: false"
                    Gui.TackleTacklingLabel.Text = "isTackling: false"
                    Gui.TackleWaitLabel.Text = "Wait: 0.00"
                    if AutoTackleConfig.Mode == "ManualTackle" then
                        Gui.ManualTackleLabel.Text = "ManualTackle: NO TARGET [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
                        Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 0, 0)
                    end
                end
                UpdateTargetRing(nil, math.huge)
                CurrentTargetOwner = nil
                return
            end
            
            if distance <= AutoTackleConfig.TackleDistance then
                PerformTackle(ball, owner)
            else
                ProcessTackle(ball, owner)
            end
        end)
    end)
    
    -- Обработчик ручного такла
    AutoTackleStatus.InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not AutoTackleConfig.Enabled then return end
        if not AutoTackleConfig.ManualTackleEnabled then return end
        
        if IsTypingInChat then return end
        
        if input.KeyCode == AutoTackleConfig.ManualTackleKeybind then
            ManualTackleAction()
        end
    end)
    
    notify("AutoTackle", "Started", true)
end

AutoTackle.Stop = function()
    if AutoTackleStatus.Connection then AutoTackleStatus.Connection:Disconnect(); AutoTackleStatus.Connection = nil end
    if AutoTackleStatus.HeartbeatConnection then AutoTackleStatus.HeartbeatConnection:Disconnect(); AutoTackleStatus.HeartbeatConnection = nil end
    if AutoTackleStatus.InputConnection then AutoTackleStatus.InputConnection:Disconnect(); AutoTackleStatus.InputConnection = nil end
    if AutoTackleStatus.RenderConnection then AutoTackleStatus.RenderConnection:Disconnect(); AutoTackleStatus.RenderConnection = nil end
    AutoTackleStatus.Running = false
    
    if Gui then
        for _, v in pairs(Gui) do
            if type(v) == "table" and v.Remove then
                v:Remove()
            end
        end
        Gui = nil
    end
    
    notify("AutoTackle", "Stopped", true)
end

-- === AUTO DRIBBLE MODULE ===
local AutoDribble = {}
AutoDribble.Start = function()
    if AutoDribbleStatus.Running then return end
    AutoDribbleStatus.Running = true
    
    AutoDribbleStatus.Connection = RunService.RenderStepped:Connect(function()
        if not AutoDribbleConfig.Enabled then
            if Gui then
                Gui.DribbleTargetLabel.Text = "Targets: 0"
                Gui.DribbleTacklingLabel.Text = "Nearest: None"
                Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"
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

            if Gui then
                Gui.DribbleTargetLabel.Text = "Targets: " .. targetCount
                Gui.DribbleTacklingLabel.Text = specificTarget and string.format("Tackle: %.1f", minDist) or "Tackle: None"
            end

            if HasBall and CanDribbleNow and specificTarget and minDist <= AutoDribbleConfig.DribbleActivationDistance then
                PerformDribble()
            else
                if Gui then
                    Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"
                end
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
    -- Секция AutoTackle
    if UI.Sections.AutoTackle then
        UI.Sections.AutoTackle:Header({ Name = "AutoTackle" })
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleEnabled = UI.Sections.AutoTackle:Toggle({ 
            Name = "Enabled", 
            Default = AutoTackleConfig.Enabled, 
            Callback = function(v) 
                AutoTackleConfig.Enabled = v
                if v then 
                    AutoTackle.Start() 
                else 
                    AutoTackle.Stop() 
                end
            end
        }, "AutoTackleEnabled")
        
        uiElements.AutoTackleMode = UI.Sections.AutoTackle:Dropdown({
            Name = "Mode",
            Default = AutoTackleConfig.Mode,
            Options = {"OnlyDribble", "EagleEye", "ManualTackle"},
            Callback = function(v)
                AutoTackleConfig.Mode = v
                if Gui then
                    Gui.ModeLabel.Text = "Mode: " .. v
                end
            end
        }, "AutoTackleMode")
        
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleMaxDistance = UI.Sections.AutoTackle:Slider({
            Name = "Max Distance",
            Minimum = 5,
            Maximum = 50,
            Default = AutoTackleConfig.MaxDistance,
            Precision = 1,
            Callback = function(v) AutoTackleConfig.MaxDistance = v end
        }, "AutoTackleMaxDistance")
        
        uiElements.AutoTackleTackleSpeed = UI.Sections.AutoTackle:Slider({
            Name = "Tackle Speed",
            Minimum = 10,
            Maximum = 100,
            Default = AutoTackleConfig.TackleSpeed,
            Precision = 1,
            Callback = function(v) AutoTackleConfig.TackleSpeed = v end
        }, "AutoTackleTackleSpeed")
        
        uiElements.AutoTacklePredictionTime = UI.Sections.AutoTackle:Slider({
            Name = "Prediction Time",
            Minimum = 0.1,
            Maximum = 2.0,
            Default = AutoTackleConfig.PredictionTime,
            Precision = 2,
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
            Default = AutoTackleConfig.RotationMethod,
            Options = {"Snap", "Always", "None"},
            Callback = function(v) AutoTackleConfig.RotationMethod = v end
        }, "AutoTackleRotationMethod")
        
        uiElements.AutoTackleRotationType = UI.Sections.AutoTackle:Dropdown({
            Name = "Rotation Type",
            Default = AutoTackleConfig.RotationType,
            Options = {"CFrame", "BodyGyro"},
            Callback = function(v) AutoTackleConfig.RotationType = v end
        }, "AutoTackleRotationType")
        
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleDribbleDelayTime = UI.Sections.AutoTackle:Slider({
            Name = "Dribble Delay Time",
            Minimum = 0.0,
            Maximum = 2.0,
            Default = AutoTackleConfig.DribbleDelayTime,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.DribbleDelayTime = v end
        }, "AutoTackleDribbleDelayTime")
        
        uiElements.AutoTackleEagleEyeMinDelay = UI.Sections.AutoTackle:Slider({
            Name = "EagleEye Min Delay",
            Minimum = 0.0,
            Maximum = 2.0,
            Default = AutoTackleConfig.EagleEyeMinDelay,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.EagleEyeMinDelay = v end
        }, "AutoTackleEagleEyeMinDelay")
        
        uiElements.AutoTackleEagleEyeMaxDelay = UI.Sections.AutoTackle:Slider({
            Name = "EagleEye Max Delay",
            Minimum = 0.0,
            Maximum = 2.0,
            Default = AutoTackleConfig.EagleEyeMaxDelay,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.EagleEyeMaxDelay = v end
        }, "AutoTackleEagleEyeMaxDelay")
        
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleManualTackleEnabled = UI.Sections.AutoTackle:Toggle({
            Name = "Manual Tackle Enabled",
            Default = AutoTackleConfig.ManualTackleEnabled,
            Callback = function(v) AutoTackleConfig.ManualTackleEnabled = v end
        }, "AutoTackleManualTackleEnabled")
        
        uiElements.AutoTackleManualTackleKeybind = UI.Sections.AutoTackle:Keybind({
            Name = "Manual Tackle Key",
            Default = AutoTackleConfig.ManualTackleKeybind,
            Callback = function(v) AutoTackleConfig.ManualTackleKeybind = v end
        }, "AutoTackleManualTackleKeybind")
        
        uiElements.AutoTackleManualTackleCooldown = UI.Sections.AutoTackle:Slider({
            Name = "Manual Tackle Cooldown",
            Minimum = 0.1,
            Maximum = 2.0,
            Default = AutoTackleConfig.ManualTackleCooldown,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.ManualTackleCooldown = v end
        }, "AutoTackleManualTackleCooldown")
        
        UI.Sections.AutoTackle:Divider()
        UI.Sections.AutoTackle:Paragraph({
            Header = "Information",
            Body = "OnlyDribble: Tackle when enemy dribble is on cooldown\nEagleEye: Random delay + dribble cooldown tracking\nManualTackle: Only tackle when you press the key"
        })
    end
    
    -- Секция AutoDribble
    if UI.Sections.AutoDribble then
        UI.Sections.AutoDribble:Header({ Name = "AutoDribble" })
        UI.Sections.AutoDribble:Divider()
        
        uiElements.AutoDribbleEnabled = UI.Sections.AutoDribble:Toggle({ 
            Name = "Enabled", 
            Default = AutoDribbleConfig.Enabled, 
            Callback = function(v) 
                AutoDribbleConfig.Enabled = v
                if v then 
                    AutoDribble.Start() 
                else 
                    AutoDribble.Stop() 
                end
            end
        }, "AutoDribbleEnabled")
        
        UI.Sections.AutoDribble:Divider()
        
        uiElements.AutoDribbleMaxDistance = UI.Sections.AutoDribble:Slider({
            Name = "Max Dribble Distance",
            Minimum = 10,
            Maximum = 50,
            Default = AutoDribbleConfig.MaxDribbleDistance,
            Precision = 1,
            Callback = function(v) AutoDribbleConfig.MaxDribbleDistance = v end
        }, "AutoDribbleMaxDistance")
        
        uiElements.AutoDribbleActivationDistance = UI.Sections.AutoDribble:Slider({
            Name = "Activation Distance",
            Minimum = 5,
            Maximum = 30,
            Default = AutoDribbleConfig.DribbleActivationDistance,
            Precision = 1,
            Callback = function(v) AutoDribbleConfig.DribbleActivationDistance = v end
        }, "AutoDribbleActivationDistance")
        
        uiElements.AutoDribblePredictionTime = UI.Sections.AutoDribble:Slider({
            Name = "Prediction Time",
            Minimum = 0.01,
            Maximum = 0.5,
            Default = AutoDribbleConfig.PredictionTime,
            Precision = 3,
            Callback = function(v) AutoDribbleConfig.PredictionTime = v end
        }, "AutoDribblePredictionTime")
        
        UI.Sections.AutoDribble:Divider()
        UI.Sections.AutoDribble:Paragraph({
            Header = "Information",
            Body = "AutoDribble: Automatically use Deke when enemy is using specific tackle animation"
        })
    end
    
    -- Секция синхронизации
    local syncSection = UI.Tabs.Config:Section({ Name = "AutoDribble & AutoTackle Sync", Side = "Right" })
    syncSection:Header({ Name = "AutoDribble/AutoTackle" })
    syncSection:Button({ Name = "Sync Config", Callback = function()
        AutoTackleConfig.Enabled = uiElements.AutoTackleEnabled:GetState()
        AutoTackleConfig.Mode = uiElements.AutoTackleMode:GetValue()
        AutoTackleConfig.MaxDistance = uiElements.AutoTackleMaxDistance:GetValue()
        AutoTackleConfig.TackleSpeed = uiElements.AutoTackleTackleSpeed:GetValue()
        AutoTackleConfig.PredictionTime = uiElements.AutoTacklePredictionTime:GetValue()
        AutoTackleConfig.OnlyPlayer = uiElements.AutoTackleOnlyPlayer:GetState()
        AutoTackleConfig.RotationMethod = uiElements.AutoTackleRotationMethod:GetValue()
        AutoTackleConfig.RotationType = uiElements.AutoTackleRotationType:GetValue()
        AutoTackleConfig.DribbleDelayTime = uiElements.AutoTackleDribbleDelayTime:GetValue()
        AutoTackleConfig.EagleEyeMinDelay = uiElements.AutoTackleEagleEyeMinDelay:GetValue()
        AutoTackleConfig.EagleEyeMaxDelay = uiElements.AutoTackleEagleEyeMaxDelay:GetValue()
        AutoTackleConfig.ManualTackleEnabled = uiElements.AutoTackleManualTackleEnabled:GetState()
        AutoTackleConfig.ManualTackleKeybind = uiElements.AutoTackleManualTackleKeybind:GetBind()
        AutoTackleConfig.ManualTackleCooldown = uiElements.AutoTackleManualTackleCooldown:GetValue()
        
        AutoDribbleConfig.Enabled = uiElements.AutoDribbleEnabled:GetState()
        AutoDribbleConfig.MaxDribbleDistance = uiElements.AutoDribbleMaxDistance:GetValue()
        AutoDribbleConfig.DribbleActivationDistance = uiElements.AutoDribbleActivationDistance:GetValue()
        AutoDribbleConfig.PredictionTime = uiElements.AutoDribblePredictionTime:GetValue()
        
        if Gui then
            Gui.ModeLabel.Text = "Mode: " .. AutoTackleConfig.Mode
        end
        
        if AutoTackleConfig.Enabled then
            if not AutoTackleStatus.Running then
                AutoTackle.Start()
            end
        else
            if AutoTackleStatus.Running then
                AutoTackle.Stop()
            end
        end
        
        if AutoDribbleConfig.Enabled then
            if not AutoDribbleStatus.Running then
                AutoDribble.Start()
            end
        else
            if AutoDribbleStatus.Running then
                AutoDribble.Stop()
            end
        end
        
        notify("Syllinse", "Config synchronized!", true)
    end })
end

-- === МОДУЛЬ ===
local AutoDribbleTackleModule = {}
function AutoDribbleTackleModule.Init(UI, coreParam, notifyFunc)
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
        
        DribbleStates = {}
        TackleStates = {}
        PrecomputedPlayers = {}
        DribbleCooldownList = {}
        PowerShootingPlayers = {}
        EagleEyeTimers = {}
        CurrentTargetOwner = nil
        
        if AutoTackleConfig.Enabled then
            if not AutoTackleStatus.Running then
                AutoTackle.Start()
            end
        end
        
        if AutoDribbleConfig.Enabled then
            if not AutoDribbleStatus.Running then
                AutoDribble.Start()
            end
        end
    end)
end

function AutoDribbleTackleModule:Destroy()
    AutoTackle.Stop()
    AutoDribble.Stop()
end

return AutoDribbleTackleModule
