-- [v1.0] AUTO TACKLE + AUTO DRIBBLE + FULL GUI + UI INTEGRATION
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
    EagleEyeMaxDelay = 1.0,
    TackleDebugText = true
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
    DribbleDebugText = true
}

-- === STATUS ===
local AutoTackleStatus = {
    Running = false,
    HeartbeatConnection = nil,
    RenderConnection = nil,
    DebugText = AutoTackleConfig.TackleDebugText
}

local AutoDribbleStatus = {
    Running = false,
    HeartbeatConnection = nil,
    RenderConnection = nil,
    DebugText = AutoDribbleConfig.DribbleDebugText
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
local Gui = nil
local debug_pos = nil
local dragging_debug = false
local drag_start_pos = Vector2.new(0, 0)
local start_debug_pos = Vector2.new(0, 0)

local function SetupGui()
    local screenSize = Camera.ViewportSize
    debug_pos = Vector2.new(screenSize.X / 2 + 150, screenSize.Y * 0.6)

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
        TargetRingLines = {},
        TargetRings = {}
    }

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
        label.Visible = false  -- Will be set in Toggle functions
    end

    Gui.TackleWaitLabel.Color = Color3.fromRGB(255, 165, 0)
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

    UpdateDebugPositions()
end

local function UpdateDebugPositions()
    if not Gui or not debug_pos then return end
    local offsetTackleY = 0
    local offsetDribbleY = -50  -- Adjust as needed

    local tackleLabels = {Gui.TackleWaitLabel, Gui.TackleTargetLabel, Gui.TackleDribblingLabel, Gui.TackleTacklingLabel, Gui.EagleEyeLabel}
    for i, label in ipairs(tackleLabels) do
        label.Position = debug_pos + Vector2.new(0, offsetTackleY + (i-1)*15)
    end

    local dribbleLabels = {Gui.DribbleStatusLabel, Gui.DribbleTargetLabel, Gui.DribbleTacklingLabel, Gui.AutoDribbleLabel}
    for i, label in ipairs(dribbleLabels) do
        label.Position = debug_pos + Vector2.new(0, offsetDribbleY + (i-1)*15)
    end
end

local function ToggleTackleDebugText(value)
    local tackleLabels = {Gui.TackleWaitLabel, Gui.TackleTargetLabel, Gui.TackleDribblingLabel, Gui.TackleTacklingLabel, Gui.EagleEyeLabel}
    for _, label in ipairs(tackleLabels) do
        label.Visible = value
    end
end

local function ToggleDribbleDebugText(value)
    local dribbleLabels = {Gui.DribbleStatusLabel, Gui.DribbleTargetLabel, Gui.DribbleTacklingLabel, Gui.AutoDribbleLabel}
    for _, label in ipairs(dribbleLabels) do
        label.Visible = value
    end
end

-- Dragging logic for debug texts
UserInputService.InputBegan:Connect(function(input, gp)
    if gp or not (AutoTackleStatus.DebugText or AutoDribbleStatus.DebugText) then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local mousePos = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        -- Calculate bounding box (assume width 200, height based on labels)
        local height = 15 * 9  -- 9 labels approx
        local bbox_min = debug_pos - Vector2.new(100, 0)
        local bbox_max = debug_pos + Vector2.new(100, height)
        if mousePos.X >= bbox_min.X and mousePos.X <= bbox_max.X and mousePos.Y >= bbox_min.Y and mousePos.Y <= bbox_max.Y then
            dragging_debug = true
            drag_start_pos = mousePos
            start_debug_pos = debug_pos
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging_debug and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local mousePos = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        local delta = mousePos - drag_start_pos
        debug_pos = start_debug_pos + delta
        UpdateDebugPositions()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging_debug = false
    end
end)

-- === AUTO TACKLE MODULE ===
local AutoTackle = {}

AutoTackle.Start = function()
    if AutoTackleStatus.Running then return end
    AutoTackleStatus.Running = true

    if not Gui then SetupGui() end
    ToggleTackleDebugText(AutoTackleStatus.DebugText)

    AutoTackleStatus.HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not AutoTackleConfig.Enabled then return end
        pcall(PrecomputePlayers)
        pcall(function()
            local canTackle, ball, distance, owner = CanTackle()
            if not canTackle or not ball then
                if Gui then
                    Gui.TackleTargetLabel.Text = "Target: None"
                    Gui.TackleDribblingLabel.Text = "isDribbling: false"
                    Gui.TackleTacklingLabel.Text = "isTackling: false"
                    Gui.EagleEyeLabel.Text = "EagleEye: Idle"
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

    notify("AutoTackle", "Started", true)
end

AutoTackle.Stop = function()
    if AutoTackleStatus.HeartbeatConnection then AutoTackleStatus.HeartbeatConnection:Disconnect(); AutoTackleStatus.HeartbeatConnection = nil end
    AutoTackleStatus.Running = false
    ToggleTackleDebugText(false)
    notify("AutoTackle", "Stopped", true)
end

-- === AUTO DRIBBLE MODULE ===
local AutoDribble = {}

AutoDribble.Start = function()
    if AutoDribbleStatus.Running then return end
    AutoDribbleStatus.Running = true

    if not Gui then SetupGui() end
    ToggleDribbleDebugText(AutoDribbleStatus.DebugText)

    AutoDribbleStatus.HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not AutoDribbleConfig.Enabled then return end
        pcall(PrecomputePlayers)
    end)

    AutoDribbleStatus.RenderConnection = RunService.RenderStepped:Connect(function()
        if not AutoDribbleConfig.Enabled then return end
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
    if AutoDribbleStatus.HeartbeatConnection then AutoDribbleStatus.HeartbeatConnection:Disconnect(); AutoDribbleStatus.HeartbeatConnection = nil end
    if AutoDribbleStatus.RenderConnection then AutoDribbleStatus.RenderConnection:Disconnect(); AutoDribbleStatus.RenderConnection = nil end
    AutoDribbleStatus.Running = false
    ToggleDribbleDebugText(false)
    notify("AutoDribble", "Stopped", true)
end

-- === UI ===
local uiElements = {}
local function SetupUI(UI)
    if UI.Sections.AutoTackle then
        UI.Sections.AutoTackle:Header({ Name = "AutoTackle" })
        uiElements.AutoTackleEnabled = UI.Sections.AutoTackle:Toggle({
            Name = "Enabled", Default = AutoTackleConfig.Enabled,
            Callback = function(v) AutoTackleConfig.Enabled = v; if v then AutoTackle.Start() else AutoTackle.Stop() end end
        }, "AutoTackleEnabled")

        uiElements.AutoTackleMaxDistance = UI.Sections.AutoTackle:Slider({
            Name = "Max Distance", Minimum = 10, Maximum = 50, Default = AutoTackleConfig.MaxDistance, Precision = 1,
            Callback = function(v) AutoTackleConfig.MaxDistance = v end
        }, "AutoTackleMaxDistance")

        uiElements.AutoTackleTackleDistance = UI.Sections.AutoTackle:Slider({
            Name = "Tackle Distance", Minimum = 0, Maximum = 10, Default = AutoTackleConfig.TackleDistance, Precision = 1,
            Callback = function(v) AutoTackleConfig.TackleDistance = v end
        }, "AutoTackleTackleDistance")

        uiElements.AutoTackleOptimalMin = UI.Sections.AutoTackle:Slider({
            Name = "Optimal Min", Minimum = 0, Maximum = 20, Default = AutoTackleConfig.OptimalDistanceMin, Precision = 1,
            Callback = function(v) AutoTackleConfig.OptimalDistanceMin = v end
        }, "AutoTackleOptimalMin")

        uiElements.AutoTackleOptimalMax = UI.Sections.AutoTackle:Slider({
            Name = "Optimal Max", Minimum = 0, Maximum = 30, Default = AutoTackleConfig.OptimalDistanceMax, Precision = 1,
            Callback = function(v) AutoTackleConfig.OptimalDistanceMax = v end
        }, "AutoTackleOptimalMax")

        uiElements.AutoTackleSpeed = UI.Sections.AutoTackle:Slider({
            Name = "Tackle Speed", Minimum = 20, Maximum = 100, Default = AutoTackleConfig.TackleSpeed, Precision = 1,
            Callback = function(v) AutoTackleConfig.TackleSpeed = v end
        }, "AutoTackleSpeed")

        uiElements.AutoTacklePredictionTime = UI.Sections.AutoTackle:Slider({
            Name = "Prediction Time", Minimum = 0.1, Maximum = 2.0, Default = AutoTackleConfig.PredictionTime, Precision = 2,
            Callback = function(v) AutoTackleConfig.PredictionTime = v end
        }, "AutoTacklePredictionTime")

        uiElements.AutoTackleOnlyPlayer = UI.Sections.AutoTackle:Toggle({
            Name = "Only Player", Default = AutoTackleConfig.OnlyPlayer,
            Callback = function(v) AutoTackleConfig.OnlyPlayer = v end
        }, "AutoTackleOnlyPlayer")

        uiElements.AutoTackleRotationMethod = UI.Sections.AutoTackle:Dropdown({
            Name = "Rotation Method", Options = {"Snap"}, Default = AutoTackleConfig.RotationMethod,
            Callback = function(v) AutoTackleConfig.RotationMethod = v end
        }, "AutoTackleRotationMethod")

        uiElements.AutoTackleRotationType = UI.Sections.AutoTackle:Dropdown({
            Name = "Rotation Type", Options = {"CFrame"}, Default = AutoTackleConfig.RotationType,
            Callback = function(v) AutoTackleConfig.RotationType = v end
        }, "AutoTackleRotationType")

        uiElements.AutoTackleMaxAngle = UI.Sections.AutoTackle:Slider({
            Name = "Max Angle", Minimum = 0, Maximum = 360, Default = AutoTackleConfig.MaxAngle, Precision = 1,
            Callback = function(v) AutoTackleConfig.MaxAngle = v end
        }, "AutoTackleMaxAngle")

        uiElements.AutoTackleEagleEyeExceptions = UI.Sections.AutoTackle:Dropdown({
            Name = "EagleEye Exceptions", Options = {"None", "OnlyDribble", "Dribble", "Dribble&Tackle"}, Default = AutoTackleConfig.EagleEyeExceptions,
            Callback = function(v) AutoTackleConfig.EagleEyeExceptions = v end
        }, "AutoTackleEagleEyeExceptions")

        uiElements.AutoTackleDribbleDelay = UI.Sections.AutoTackle:Dropdown({
            Name = "Dribble Delay", Options = {"Delay", "Smart"}, Default = AutoTackleConfig.DribbleDelay,
            Callback = function(v) AutoTackleConfig.DribbleDelay = v end
        }, "AutoTackleDribbleDelay")

        uiElements.AutoTackleDribbleDelayTime = UI.Sections.AutoTackle:Slider({
            Name = "Dribble Delay Time", Minimum = 0, Maximum = 5, Default = AutoTackleConfig.DribbleDelayTime, Precision = 1,
            Callback = function(v) AutoTackleConfig.DribbleDelayTime = v end
        }, "AutoTackleDribbleDelayTime")

        uiElements.AutoTackleEagleEyeMinDelay = UI.Sections.AutoTackle:Slider({
            Name = "EagleEye Min Delay", Minimum = 0.0, Maximum = 1.0, Default = AutoTackleConfig.EagleEyeMinDelay, Precision = 2,
            Callback = function(v) AutoTackleConfig.EagleEyeMinDelay = v end
        }, "AutoTackleEagleEyeMinDelay")

        uiElements.AutoTackleEagleEyeMaxDelay = UI.Sections.AutoTackle:Slider({
            Name = "EagleEye Max Delay", Minimum = 0.0, Maximum = 2.0, Default = AutoTackleConfig.EagleEyeMaxDelay, Precision = 2,
            Callback = function(v) AutoTackleConfig.EagleEyeMaxDelay = v end
        }, "AutoTackleEagleEyeMaxDelay")

        uiElements.AutoTackleDebugText = UI.Sections.AutoTackle:Toggle({
            Name = "Tackle Debug Text", Default = AutoTackleConfig.TackleDebugText,
            Callback = function(v) AutoTackleStatus.DebugText = v; AutoTackleConfig.TackleDebugText = v; ToggleTackleDebugText(v) end
        }, "AutoTackleDebugText")
    end

    if UI.Sections.AutoDribble then
        UI.Sections.AutoDribble:Header({ Name = "AutoDribble" })
        uiElements.AutoDribbleEnabled = UI.Sections.AutoDribble:Toggle({
            Name = "Enabled", Default = AutoDribbleConfig.Enabled,
            Callback = function(v) AutoDribbleConfig.Enabled = v; if v then AutoDribble.Start() else AutoDribble.Stop() end end
        }, "AutoDribbleEnabled")

        uiElements.AutoDribbleMaxDistance = UI.Sections.AutoDribble:Slider({
            Name = "Max Dribble Distance", Minimum = 10, Maximum = 50, Default = AutoDribbleConfig.MaxDribbleDistance, Precision = 1,
            Callback = function(v) AutoDribbleConfig.MaxDribbleDistance = v end
        }, "AutoDribbleMaxDistance")

        uiElements.AutoDribbleActivationDistance = UI.Sections.AutoDribble:Slider({
            Name = "Activation Distance", Minimum = 5, Maximum = 30, Default = AutoDribbleConfig.DribbleActivationDistance, Precision = 1,
            Callback = function(v) AutoDribbleConfig.DribbleActivationDistance = v end
        }, "AutoDribbleActivationDistance")

        uiElements.AutoDribbleMaxAngle = UI.Sections.AutoDribble:Slider({
            Name = "Max Angle", Minimum = 0, Maximum = 360, Default = AutoDribbleConfig.MaxAngle, Precision = 1,
            Callback = function(v) AutoDribbleConfig.MaxAngle = v end
        }, "AutoDribbleMaxAngle")

        uiElements.AutoDribblePredictionTime = UI.Sections.AutoDribble:Slider({
            Name = "Prediction Time", Minimum = 0.01, Maximum = 1.0, Default = AutoDribbleConfig.PredictionTime, Precision = 2,
            Callback = function(v) AutoDribbleConfig.PredictionTime = v end
        }, "AutoDribblePredictionTime")

        uiElements.AutoDribbleMaxPredictionAngle = UI.Sections.AutoDribble:Slider({
            Name = "Max Prediction Angle", Minimum = 0, Maximum = 90, Default = AutoDribbleConfig.MaxPredictionAngle, Precision = 1,
            Callback = function(v) AutoDribbleConfig.MaxPredictionAngle = v end
        }, "AutoDribbleMaxPredictionAngle")

        uiElements.AutoDribbleTacklePredictionTime = UI.Sections.AutoDribble:Slider({
            Name = "Tackle Prediction Time", Minimum = 0.1, Maximum = 1.0, Default = AutoDribbleConfig.TacklePredictionTime, Precision = 2,
            Callback = function(v) AutoDribbleConfig.TacklePredictionTime = v end
        }, "AutoDribbleTacklePredictionTime")

        uiElements.AutoDribbleTackleAngleThreshold = UI.Sections.AutoDribble:Slider({
            Name = "Tackle Angle Threshold", Minimum = 0.1, Maximum = 1.0, Default = AutoDribbleConfig.TackleAngleThreshold, Precision = 2,
            Callback = function(v) AutoDribbleConfig.TackleAngleThreshold = v end
        }, "AutoDribbleTackleAngleThreshold")

        uiElements.AutoDribbleDebugText = UI.Sections.AutoDribble:Toggle({
            Name = "Dribble Debug Text", Default = AutoDribbleConfig.DribbleDebugText,
            Callback = function(v) AutoDribbleStatus.DebugText = v; AutoDribbleConfig.DribbleDebugText = v; ToggleDribbleDebugText(v) end
        }, "AutoDribbleDebugText")
    end

    local syncSection = UI.Tabs.Config:Section({ Name = "AutoTackle & AutoDribble Sync", Side = "Right" })
    syncSection:Header({ Name = "Sync" })
    syncSection:Button({ Name = "Sync Config", Callback = function()
        AutoTackleConfig.Enabled = uiElements.AutoTackleEnabled:GetState()
        AutoTackleConfig.MaxDistance = uiElements.AutoTackleMaxDistance:GetValue()
        AutoTackleConfig.TackleDistance = uiElements.AutoTackleTackleDistance:GetValue()
        AutoTackleConfig.OptimalDistanceMin = uiElements.AutoTackleOptimalMin:GetValue()
        AutoTackleConfig.OptimalDistanceMax = uiElements.AutoTackleOptimalMax:GetValue()
        AutoTackleConfig.TackleSpeed = uiElements.AutoTackleSpeed:GetValue()
        AutoTackleConfig.PredictionTime = uiElements.AutoTacklePredictionTime:GetValue()
        AutoTackleConfig.OnlyPlayer = uiElements.AutoTackleOnlyPlayer:GetState()
        AutoTackleConfig.RotationMethod = uiElements.AutoTackleRotationMethod:GetOptions() -- Assuming dropdown returns selected value
        AutoTackleConfig.RotationType = uiElements.AutoTackleRotationType:GetOptions()
        AutoTackleConfig.MaxAngle = uiElements.AutoTackleMaxAngle:GetValue()
        AutoTackleConfig.EagleEyeExceptions = uiElements.AutoTackleEagleEyeExceptions:GetOptions()
        AutoTackleConfig.DribbleDelay = uiElements.AutoTackleDribbleDelay:GetOptions()
        AutoTackleConfig.DribbleDelayTime = uiElements.AutoTackleDribbleDelayTime:GetValue()
        AutoTackleConfig.EagleEyeMinDelay = uiElements.AutoTackleEagleEyeMinDelay:GetValue()
        AutoTackleConfig.EagleEyeMaxDelay = uiElements.AutoTackleEagleEyeMaxDelay:GetValue()
        AutoTackleConfig.TackleDebugText = uiElements.AutoTackleDebugText:GetState()

        AutoDribbleConfig.Enabled = uiElements.AutoDribbleEnabled:GetState()
        AutoDribbleConfig.MaxDribbleDistance = uiElements.AutoDribbleMaxDistance:GetValue()
        AutoDribbleConfig.DribbleActivationDistance = uiElements.AutoDribbleActivationDistance:GetValue()
        AutoDribbleConfig.MaxAngle = uiElements.AutoDribbleMaxAngle:GetValue()
        AutoDribbleConfig.PredictionTime = uiElements.AutoDribblePredictionTime:GetValue()
        AutoDribbleConfig.MaxPredictionAngle = uiElements.AutoDribbleMaxPredictionAngle:GetValue()
        AutoDribbleConfig.TacklePredictionTime = uiElements.AutoDribbleTacklePredictionTime:GetValue()
        AutoDribbleConfig.TackleAngleThreshold = uiElements.AutoDribbleTackleAngleThreshold:GetValue()
        AutoDribbleConfig.DribbleDebugText = uiElements.AutoDribbleDebugText:GetState()

        AutoTackleStatus.DebugText = AutoTackleConfig.TackleDebugText
        AutoDribbleStatus.DebugText = AutoDribbleConfig.DribbleDebugText
        ToggleTackleDebugText(AutoTackleStatus.DebugText)
        ToggleDribbleDebugText(AutoDribbleStatus.DebugText)

        if AutoTackleConfig.Enabled then if not AutoTackleStatus.Running then AutoTackle.Start() end else if AutoTackleStatus.Running then AutoTackle.Stop() end end
        if AutoDribbleConfig.Enabled then if not AutoDribbleStatus.Running then AutoDribble.Start() end else if AutoDribbleStatus.Running then AutoDribble.Stop() end end

        notify("Syllinse", "AutoTackle & AutoDribble config synchronized!", true)
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
        if AutoTackleConfig.Enabled then AutoTackle.Start() end
        if AutoDribbleConfig.Enabled then AutoDribble.Start() end
    end)
end

function AutoTackleModule:Destroy()
    AutoTackle.Stop()
    AutoDribble.Stop()
end

return AutoTackleModule
