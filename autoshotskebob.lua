print('1')
local AutoShoot = {}

function AutoShoot.Init(UI, Core, notify)
    -- === СЕРВИСЫ ===
    local Players = Core.Services.Players
    local RunService = Core.Services.RunService
    local ReplicatedStorage = Core.Services.ReplicatedStorage
    local Workspace = Core.Services.Workspace
    local Camera = Workspace.CurrentCamera
    local UserInputService = Core.Services.UserInputService

    local LocalPlayer = Core.PlayerData.LocalPlayer
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    local BallAttachment = Character:WaitForChild("ball")
    local Humanoid = Character:WaitForChild("Humanoid")

    local Shooter = ReplicatedStorage.Remotes:WaitForChild("ShootTheBaII")
    local PickupRemote
    for _, r in ReplicatedStorage.Remotes:GetChildren() do
        if r:IsA("RemoteEvent") and r:GetAttribute("Attribute") then
            PickupRemote = r
            break
        end
    end

    -- === АНИМАЦИЯ ===
    local Animations = ReplicatedStorage:WaitForChild("Animations")
    local RShootAnim = Humanoid:LoadAnimation(Animations:WaitForChild("RShoot"))
    RShootAnim.Priority = Enum.AnimationPriority.Action4
    local IsAnimating = false

    -- === КОНФИГ (ПРОСТЫЕ ПЕРЕМЕННЫЕ, НЕ ТАБЛИЦА С .Value) ===
    local Enabled = true
    local ManualShot = true
    local ShootKey = Enum.KeyCode.E
    local Legit = true
    local AnimationHoldTime = 0.6
    local AutoPickup = true
    local PickupDist = 180
    local SpoofValue = 2.8
    local MaxDistance = 160
    local MinPower = 4.0
    local MaxPower = 7.0
    local PowerPerStud = 0.025
    local Gravity = 110
    local Inset = 2
    local MaxHeight = 100.0

    -- === АТАКИ (включены/выключены через UI) ===
    local Attacks = {
        SideRicochet = { Enabled = true, MinDist = 0, MaxDist = 60, Power = 3.5, XMult = 0.8, Spin = "None", HeightMult = 1.0, BaseHeightRange = {Min = 0.15, Max = 0.34}, DerivationMult = 0.0, ZOffset = 2.0 },
        CloseSpin = { Enabled = true, MinDist = 0, MaxDist = 110, Power = 3.2, XMult = 1.1, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 0.3, Max = 0.9}, DerivationMult = 0.8, ZOffset = -5.0 },
        SmartCorner = { Enabled = true, MinDist = 0, MaxDist = 100, PowerMin = 2.8, XMult = 0.3, Spin = "None", HeightMult = 0.82, BaseHeightRange = {Min = 0.5, Max = 0.7}, DerivationMult = 0.3, ZOffset = 0.65 },
        SmartCandle = { Enabled = true, MinDist = 145, MaxDist = 180, Power = 3, XMult = 1.5, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 11, Max = 13}, DerivationMult = 2.8, ZOffset = -10 },
        SmartRicochet = { Enabled = true, MinDist = 80, MaxDist = 140, Power = 3.6, XMult = 0.9, Spin = true, HeightMult = 0.7, BaseHeightRange = {Min = 0.95, Max = 1.5}, DerivationMult = 1.6, ZOffset = 2 },
        SmartSpin = { Enabled = true, MinDist = 110, MaxDist = 155, PowerAdd = 0.6, XMult = 0.9, Spin = true, HeightMult = 0.75, BaseHeightRange = {Min = 0.7, Max = 1.5}, DerivationMult = 1.8, ZOffset = -5 },
        FarSmartCandle = { Enabled = true, MinDist = 200, MaxDist = 300, Power = 60, XMult = 0.7, Spin = true, HeightMult = 1.8, BaseHeightRange = {Min = 40.0, Max = 80.0}, DerivationMult = 4.5, ZOffset = -10 }
    }

    -- === GUI (Drawing) ===
    local Gui = {
        Status = Drawing.new("Text"),
        Dist = Drawing.new("Text"),
        Target = Drawing.new("Text"),
        Power = Drawing.new("Text"),
        Spin = Drawing.new("Text"),
        GK = Drawing.new("Text"),
        Mode = Drawing.new("Text")
    }

    local function SetupGUI()
        local s = Camera.ViewportSize
        local cx, y = s.X / 2, s.Y * 0.48
        local texts = {Gui.Status, Gui.Dist, Gui.Target, Gui.Power, Gui.Spin, Gui.GK, Gui.Mode}
        for i, v in ipairs(texts) do
            v.Size = 18
            v.Color = Color3.fromRGB(255, 255, 255)
            v.Outline = true
            v.Center = true
            v.Position = Vector2.new(cx, y + (i-1)*20)
            v.Visible = true
        end
        Gui.Status.Text = "AutoShoot: Ready"
        Gui.Mode.Text = "Mode: Manual (E)"
    end
    SetupGUI()

    -- === КЕЙБИНД (КРАСИВОЕ ИМЯ) ===
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

    local function UpdateModeText()
        if ManualShot then
            Gui.Mode.Text = string.format("Mode: Manual (%s)", GetKeyName(ShootKey))
        else
            Gui.Mode.Text = "Mode: Auto"
        end
    end

    -- === 3D КУБЫ ===
    local TargetCube, GoalCube, NoSpinCube = {}, {}, {}
    local function InitializeCubes()
        for i = 1, 12 do
            TargetCube[i] = Drawing.new("Line")
            GoalCube[i] = Drawing.new("Line")
            NoSpinCube[i] = Drawing.new("Line")
        end
        local function setup(cube, color, thickness)
            for _, line in ipairs(cube) do
                line.Color = color
                line.Thickness = thickness
                line.Transparency = 0.7
                line.ZIndex = 1000
                line.Visible = false
            end
        end
        setup(TargetCube, Color3.fromRGB(0, 255, 0), 6)
        setup(GoalCube, Color3.fromRGB(255, 0, 0), 4)
        setup(NoSpinCube, Color3.fromRGB(0, 255, 255), 5)
    end
    InitializeCubes()

    local function DrawOrientedCube(cube, cframe, size)
        if not cframe or not size then
            for _, line in ipairs(cube) do line.Visible = false end
            return
        end
        local half = size / 2
        local corners = {
            cframe * Vector3.new(-half.X, -half.Y, -half.Z), cframe * Vector3.new(half.X, -half.Y, -half.Z),
            cframe * Vector3.new(half.X, half.Y, -half.Z), cframe * Vector3.new(-half.X, half.Y, -half.Z),
            cframe * Vector3.new(-half.X, -half.Y, half.Z), cframe * Vector3.new(half.X, -half.Y, half.Z),
            cframe * Vector3.new(half.X, half.Y, half.Z), cframe * Vector3.new(-half.X, half.Y, half.Z)
        }
        local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
        for i, edge in ipairs(edges) do
            local a, b = corners[edge[1]], corners[edge[2]]
            local aScreen, aVis = Camera:WorldToViewportPoint(a)
            local bScreen, bVis = Camera:WorldToViewportPoint(b)
            local line = cube[i]
            if aVis and bVis and aScreen.Z > 0 and bScreen.Z > 0 then
                line.From = Vector2.new(aScreen.X, aScreen.Y)
                line.To = Vector2.new(bScreen.X, bScreen.Y)
                line.Visible = true
            else
                line.Visible = false
            end
        end
    end

    -- === ГОЛ ===
    local GoalCFrame, GoalWidth, GoalHeight
    local function UpdateGoal()
        local stats = Workspace:FindFirstChild("PlayerStats")
        if not stats then return end
        local myTeam = (stats:FindFirstChild("Away") and stats.Away:FindFirstChild(LocalPlayer.Name)) and "Away" or
                       (stats:FindFirstChild("Home") and stats.Home:FindFirstChild(LocalPlayer.Name)) and "Home"
        if not myTeam then return end
        local enemyGoalName = myTeam == "Away" and "HomeGoal" or "AwayGoal"
        local goalFolder = Workspace:FindFirstChild(enemyGoalName)
        if not goalFolder then return end
        local frame = goalFolder:FindFirstChild("Frame")
        if not frame then return end
        local left = frame:FindFirstChild("LeftPost")
        local right = frame:FindFirstChild("RightPost")
        local crossbar = frame:FindFirstChild("Crossbar")
        if not (left and right and crossbar) then return end
        local center = (left.Position + right.Position) / 2
        local forward = (center - crossbar.Position).Unit
        local up = crossbar.Position.Y > left.Position.Y and Vector3.yAxis or -Vector3.yAxis
        local rightDir = (right.Position - left.Position).Unit
        GoalCFrame = CFrame.fromMatrix(center, rightDir, up, -forward)
        GoalWidth = (left.Position - right.Position).Magnitude
        GoalHeight = math.abs(crossbar.Position.Y - left.Position.Y)
        return GoalWidth, GoalHeight
    end

    -- === ВРАТАРЬ ===
    local function GetEnemyGoalie()
        local myTeam = UpdateGoal() and ((Workspace.PlayerStats.Away:FindFirstChild(LocalPlayer.Name) and "Away") or "Home")
        if not myTeam then return nil, 0, 0, "None", false end
        local width = UpdateGoal()
        if not width then return nil, 0, 0, "None", false end
        local halfWidth = width / 2
        local goalies = {}
        for _, player in Players:GetPlayers() do
            if player ~= LocalPlayer and player.Team and player.Team.Name ~= myTeam then
                local char = player.Character
                if char and char:FindFirstChild("Humanoid") and char.Humanoid.HipHeight >= 4 then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp and GoalCFrame then
                        local distGoal = (hrp.Position - GoalCFrame.Position).Magnitude
                        local localX = GoalCFrame:PointToObjectSpace(hrp.Position).X
                        local localY = GoalCFrame:PointToObjectSpace(hrp.Position).Y
                        local isInGoal = distGoal < 18 and math.abs(localX) < halfWidth + 2
                        table.insert(goalies, { hrp = hrp, localX = localX, localY = localY, distGoal = distGoal, name = player.Name, isInGoal = isInGoal })
                    end
                end
            end
        end
        local goalieNPC = Workspace:FindFirstChild(myTeam == "Away" and "HomeGoalie" or "Goalie")
        if goalieNPC and goalieNPC:FindFirstChild("HumanoidRootPart") then
            local hrp = goalieNPC.HumanoidRootPart
            local distGoal = (hrp.Position - GoalCFrame.Position).Magnitude
            local localX = GoalCFrame:PointToObjectSpace(hrp.Position).X
            local localY = GoalCFrame:PointToObjectSpace(hrp.Position).Y
            local isInGoal = distGoal < 18 and math.abs(localX) < halfWidth + 2
            table.insert(goalies, { hrp = hrp, localX = localX, localY = localY, distGoal = distGoal, name = "NPC", isInGoal = isInGoal })
        end
        if #goalies == 0 then
            Gui.GK.Text = "GK: None"
            Gui.GK.Color = Color3.fromRGB(150,150,150)
            return nil, 0, 0, "None", false
        end
        table.sort(goalies, function(a,b)
            if a.isInGoal ~= b.isInGoal then return a.isInGoal end
            return a.distGoal < b.distGoal
        end)
        local best = goalies[1]
        Gui.GK.Text = string.format("GK: %s %s | X=%.1f", best.name, best.isInGoal and "(In)" or "(Aggro)", best.localX)
        Gui.GK.Color = Color3.fromRGB(255, 200, 0)
        return best.hrp, best.localX, best.localY, best.name, not best.isInGoal
    end

    -- === ТРАЕКТОРИЯ ВЫСОТЫ ===
    local function CalculateTrajectoryHeight(dist, power, attackName, isLowShot)
        local cfg = Attacks[attackName] or {}
        local baseHeightRange = cfg.BaseHeightRange or {Min = 0.15, Max = 0.45}
        local heightMult = cfg.HeightMult or 1.0
        local baseHeight = isLowShot and 0.5 or math.clamp(baseHeightRange.Min + (dist / 400), baseHeightRange.Min, baseHeightRange.Max)
        local timeToTarget = dist / 200
        local gravityFall = (attackName == "FarSmartCandle" and 10) or (0.5 * Gravity * timeToTarget^2)
        local height = math.clamp(baseHeight + gravityFall, isLowShot and 0.5 or 2.0, MaxHeight)
        height = math.clamp(height * heightMult, isLowShot and 0.5 or 2.0, MaxHeight)
        return height
    end

    -- === ЦЕЛЬ ===
    local TargetPoint, ShootDir, ShootVel, CurrentSpin, CurrentPower, CurrentType, NoSpinPoint
    local function CalculateTarget()
        local width = UpdateGoal()
        if not GoalCFrame or not width then
            TargetPoint = nil
            NoSpinPoint = nil
            return
        end
        local dist = (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude
        Gui.Dist.Text = string.format("Dist: %.1f", dist)
        if dist > MaxDistance then
            TargetPoint = nil
            NoSpinPoint = nil
            return
        end

        local startPos = HumanoidRootPart.Position
        local halfWidth = (GoalWidth / 2) - Inset
        local goalieHrp, goalieX, _ = GetEnemyGoalie()
        local targetSide = goalieX > 0 and -1 or 1
        local candidates = {}

        for name, cfg in pairs(Attacks) do
            if not cfg.Enabled or dist < cfg.MinDist or dist > math.min(cfg.MaxDist, MaxDistance) then continue end
            local spin = cfg.Spin and (dist >= 110 or name == "CloseSpin") and (targetSide > 0 and "Right" or "Left") or "None"
            local power = cfg.Power or math.clamp(MinPower + dist * PowerPerStud, cfg.PowerMin or MinPower, MaxPower)
            power = power + (cfg.PowerAdd or 0)
            local height = CalculateTrajectoryHeight(dist, power, name, false)
            local worldPos = GoalCFrame * Vector3.new(targetSide * halfWidth * (cfg.XMult or 1), height, cfg.ZOffset or 0)
            local noSpinPos = GoalCFrame * Vector3.new(targetSide * halfWidth * (cfg.XMult or 1), height, 0)
            table.insert(candidates, {
                pos = worldPos,
                noSpinPos = noSpinPos,
                spin = spin,
                power = power,
                name = name
            })
        end

        if #candidates == 0 then return end
        local selected = candidates[1]  -- Лучшая атака
        TargetPoint = selected.pos
        NoSpinPoint = selected.noSpinPos
        CurrentSpin = selected.spin
        CurrentType = selected.name
        CurrentPower = selected.power
        ShootDir = (TargetPoint - startPos).Unit
        ShootVel = ShootDir * (power * 1400)

        Gui.Target.Text = "Target: " .. selected.name
        Gui.Power.Text = "Power: " .. string.format("%.2f", power)
        Gui.Spin.Text = "Spin: " .. selected.spin
    end

    -- === СТРЕЛЬБА ===
    local CanShoot = true
    local LastShoot = 0
    local function TryShoot()
        if not Enabled or not TargetPoint then return end
        local ball = Workspace:FindFirstChild("ball")
        if not ball or not ball:FindFirstChild("playerWeld") or ball.creator.Value ~= LocalPlayer then return end

        if Legit and not IsAnimating then
            IsAnimating = true
            RShootAnim:Play()
            task.delay(AnimationHoldTime, function() IsAnimating = false end)
        end

        local success = pcall(function()
            Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
        end)
        if success then
            Gui.Status.Text = ManualShot and "MANUAL SHOT!" or "AUTO SHOT!"
            Gui.Status.Color = Color3.fromRGB(0,255,0)
            LastShoot = tick()
        end
    end

    -- === РУЧНАЯ СТРЕЛЬБА ===
    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp or not Enabled or not ManualShot then return end
        if inp.KeyCode == ShootKey and CanShoot then
            CalculateTarget()
            if TargetPoint then
                TryShoot()
                CanShoot = false
                task.delay(0.3, function() CanShoot = true end)
            end
        end
    end)

    -- === АВТО СТРЕЛЬБА ===
    local function AutoShoot()
        if ManualShot or not Enabled or tick() - LastShoot < 0.3 then return end
        CalculateTarget()
        if TargetPoint then TryShoot() end
    end

    -- === АВТОПИКАП ===
    RunService.Heartbeat:Connect(function()
        if not AutoPickup then return end
        local ball = Workspace:FindFirstChild("ball")
        if ball and not ball:FindFirstChild("playerWeld") and (HumanoidRootPart.Position - ball.Position).Magnitude <= PickupDist then
            if PickupRemote then
                pcall(function()
                    PickupRemote:FireServer(SpoofValue)
                end)
            end
        end
    end)

    -- === РЕНДЕР ===
    RunService.RenderStepped:Connect(function()
        local width = UpdateGoal()
        if GoalCFrame and width then
            DrawOrientedCube(GoalCube, GoalCFrame, Vector3.new(width, GoalHeight, 2))
        end
        if TargetPoint then
            DrawOrientedCube(TargetCube, CFrame.new(TargetPoint), Vector3.new(4,4,4))
        end
        if NoSpinPoint then
            DrawOrientedCube(NoSpinCube, CFrame.new(NoSpinPoint), Vector3.new(3,3,3))
        end
        AutoShoot()
    end)

    -- === ПЕРСОНАЖ ===
    LocalPlayer.CharacterAdded:Connect(function(c)
        Character = c
        Humanoid = c:WaitForChild("Humanoid")
        HumanoidRootPart = c:WaitForChild("HumanoidRootPart")
        BallAttachment = c:WaitForChild("ball")
        RShootAnim = Humanoid:LoadAnimation(Animations:WaitForChild("RShoot"))
        RShootAnim.Priority = Enum.AnimationPriority.Action4
        GoalCFrame = nil
        TargetPoint = nil
        NoSpinPoint = nil
        IsAnimating = false
        CanShoot = true
        InitializeCubes()
        UpdateModeText()
    end)

    -- === UI (ЧИТАЕМО, БЕЗ СЖАТИЯ) ===
    local section = UI.Tabs.Main:Section({ Name = 'Auto Shoot', Side = 'Left' })

    section:Header({ Name = "Auto Shoot" })
    section:SubLabel({ Text = "Smart aimbot with legit animation & ESP" })

    section:Toggle({
        Name = "Enabled",
        Default = true,
        Callback = function(v)
            Enabled = v
            Gui.Status.Text = v and "AutoShoot: Ready" or "AutoShoot: Disabled"
            notify("AutoShoot", v and "Enabled" or "Disabled", true)
        end
    })

    section:Toggle({
        Name = "Manual Mode",
        Default = true,
        Callback = function(v)
            ManualShot = v
            UpdateModeText()
            notify("AutoShoot", v and "Manual (Key)" or "Auto", true)
        end
    })

    section:Keybind({
        Name = "Shoot Key",
        Default = Enum.KeyCode.E,
        Callback = function(key)
            ShootKey = key
            UpdateModeText()
            notify("AutoShoot", "Key: " .. GetKeyName(key), false)
        end
    })

    section:Toggle({
        Name = "Legit Animation",
        Default = true,
        Callback = function(v)
            Legit = v
            notify("AutoShoot", "Legit: " .. (v and "On" or "Off"), false)
        end
    })

    section:Slider({
        Name = "Anim Hold (s)",
        Minimum = 0.1,
        Maximum = 2.0,
        Default = 0.6,
        Precision = 2,
        Callback = function(v)
            AnimationHoldTime = v
        end
    })

    section:Divider()
    section:SubLabel({ Text = "Pickup & Distance" })

    section:Toggle({
        Name = "Auto Pickup",
        Default = true,
        Callback = function(v)
            AutoPickup = v
        end
    })

    section:Slider({
        Name = "Pickup Dist",
        Minimum = 50,
        Maximum = 300,
        Default = 180,
        Callback = function(v)
            PickupDist = v
        end
    })

    section:Slider({
        Name = "Max Shoot Dist",
        Minimum = 100,
        Maximum = 300,
        Default = 160,
        Callback = function(v)
            MaxDistance = v
        end
    })

    section:Divider()
    section:SubLabel({ Text = "Power Settings" })

    section:Slider({
        Name = "Min Power",
        Minimum = 1,
        Maximum = 10,
        Default = 4.0,
        Callback = function(v)
            MinPower = v
        end
    })

    section:Slider({
        Name = "Max Power",
        Minimum = 1,
        Maximum = 10,
        Default = 7.0,
        Callback = function(v)
            MaxPower = v
        end
    })

    section:Slider({
        Name = "Power/Stud",
        Minimum = 0.01,
        Maximum = 0.1,
        Default = 0.025,
        Precision = 3,
        Callback = function(v)
            PowerPerStud = v
        end
    })

    -- === УНИЧТОЖЕНИЕ ===
    function AutoShoot:Destroy()
        for _, cube in ipairs({TargetCube, GoalCube, NoSpinCube}) do
            for _, line in ipairs(cube) do
                if line then line:Remove() end
            end
        end
        for _, v in pairs(Gui) do
            if v then v:Remove() end
        end
    end

    return AutoShoot
end

return AutoShoot
