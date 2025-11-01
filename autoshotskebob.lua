local AutoShoot = {}

function AutoShoot.Init(UI, Core, notify)
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
            PickupRemote = r; break
        end
    end

    -- === АНИМАЦИЯ RShoot (ДЛИТЕЛЬНАЯ) ===
    local Animations = ReplicatedStorage:WaitForChild("Animations")
    local RShootAnim = Humanoid:LoadAnimation(Animations:WaitForChild("RShoot"))
    RShootAnim.Priority = Enum.AnimationPriority.Action4
    local IsAnimating = false
    local AnimationHoldTime = 0.6

    -- === STATE (UI) ===
    local State = {
        AutoShoot = {
            Enabled = { Value = true, Default = true },
            Legit = { Value = true, Default = true },
            ManualShot = { Value = true, Default = true },
            ShootKey = { Value = Enum.KeyCode.E, Default = Enum.KeyCode.E },
            AutoPickup = { Value = true, Default = true },
            PickupDist = { Value = 180, Default = 180 },
            SpoofValue = { Value = 2.8, Default = 2.8 },
            MaxDistance = { Value = 160, Default = 160 },
            MinPower = { Value = 4.0, Default = 4.0 },
            MaxPower = { Value = 7.0, Default = 7.0 },
            PowerPerStud = { Value = 0.025, Default = 0.025 },
            Inset = { Value = 2, Default = 2 },
            Gravity = { Value = 110, Default = 110 },
            MaxHeight = { Value = 100.0, Default = 100.0 },

            -- АТАКИ
            Attacks = {
                SideRicochet = { Enabled = { Value = true, Default = true }, MinDist = 0, MaxDist = 60, Power = 3.5, XMult = 0.8, Spin = "None", HeightMult = 1.0, BaseHeightRange = {Min = 0.15, Max = 0.34}, DerivationMult = 0.0, ZOffset = 2.0 },
                CloseSpin = { Enabled = { Value = true, Default = true }, MinDist = 0, MaxDist = 110, Power = 3.2, XMult = 1.1, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 0.3, Max = 0.9}, DerivationMult = 0.8, ZOffset = -5.0 },
                SmartCorner = { Enabled = { Value = true, Default = true }, MinDist = 0, MaxDist = 100, PowerMin = 2.8, XMult = 0.3, Spin = "None", HeightMult = 0.82, BaseHeightRange = {Min = 0.5, Max = 0.7}, DerivationMult = 0.3, ZOffset = 0.65 },
                SmartCandle = { Enabled = { Value = true, Default = true }, MinDist = 145, MaxDist = 180, Power = 3, XMult = 1.5, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 11, Max = 13}, DerivationMult = 2.8, ZOffset = -10 },
                SmartRicochet = { Enabled = { Value = true, Default = true }, MinDist = 80, MaxDist = 140, Power = 3.6, XMult = 0.9, Spin = true, HeightMult = 0.7, BaseHeightRange = {Min = 0.95, Max = 1.5}, DerivationMult = 1.6, ZOffset = 2 },
                SmartSpin = { Enabled = { Value = true, Default = true }, MinDist = 110, MaxDist = 155, PowerAdd = 0.6, XMult = 0.9, Spin = true, HeightMult = 0.75, BaseHeightRange = {Min = 0.7, Max = 1.5}, DerivationMult = 1.8, ZOffset = -5 },
                SmartCandleMid = { Enabled = { Value = false, Default = false }, MinDist = 100, MaxDist = 165, PowerAdd = 0.4, XMult = 0.7, Spin = true, HeightMult = 0.9, BaseHeightRange = {Min = 0.15, Max = 0.55}, DerivationMult = 1.35, ZOffset = 0.0 },
                FarSmartCandle = { Enabled = { Value = true, Default = true }, MinDist = 200, MaxDist = 300, Power = 60, XMult = 0.7, Spin = true, HeightMult = 1.8, BaseHeightRange = {Min = 40.0, Max = 80.0}, DerivationMult = 4.5, ZOffset = -10 }
            }
        }
    }

    -- === GUI (Drawing) ===
    local Gui = {
        Status = Drawing.new("Text"), Dist = Drawing.new("Text"), Target = Drawing.new("Text"),
        Power = Drawing.new("Text"), Spin = Drawing.new("Text"), GK = Drawing.new("Text"),
        Debug = Drawing.new("Text"), Mode = Drawing.new("Text")
    }
    local function SetupGUI()
        local s = Camera.ViewportSize
        local cx, y = s.X / 2, s.Y * 0.48
        for i, v in ipairs({Gui.Status, Gui.Dist, Gui.Target, Gui.Power, Gui.Spin, Gui.GK, Gui.Debug, Gui.Mode}) do
            v.Size = 18; v.Color = Color3.fromRGB(255, 255, 255); v.Outline = true; v.Center = true
            v.Position = Vector2.new(cx, y + (i-1)*20); v.Visible = true
        end
        Gui.Status.Text = "AutoShoot: Ready"
        UpdateModeText()
    end
    SetupGUI()

    -- === КЕЙБИНД ===
    local function GetKeyName(key)
        if key == Enum.KeyCode.Unknown then return "None" end
        local name = tostring(key):match("KeyCode%.(.+)") or tostring(key)
        local pretty = { LeftMouse = "LMB", RightMouse = "RMB", MiddleMouse = "MMB", Space = "Space", LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt", RightAlt = "RAlt" }
        return pretty[name] or name
    end
    local function UpdateModeText()
        if State.AutoShoot.ManualShot.Value then
            Gui.Mode.Text = string.format("Mode: Manual (%s)", GetKeyName(State.AutoShoot.ShootKey.Value))
        else
            Gui.Mode.Text = "Mode: Auto"
        end
    end

    -- === 3D CUBES ===
    local TargetCube, GoalCube, NoSpinCube = {}, {}, {}
    local function SetupCube(cube, color, thickness)
        for _, line in ipairs(cube) do
            if line then line.Color = color; line.Thickness = thickness or 2; line.Transparency = 0.7; line.ZIndex = 1000; line.Visible = false end
        end
    end
    local function InitializeCubes()
        for i = 1, 12 do
            if TargetCube[i] then TargetCube[i]:Remove() end
            if GoalCube[i] then GoalCube[i]:Remove() end
            if NoSpinCube[i] then NoSpinCube[i]:Remove() end
            TargetCube[i] = Drawing.new("Line")
            GoalCube[i] = Drawing.new("Line")
            NoSpinCube[i] = Drawing.new("Line")
        end
        SetupCube(TargetCube, Color3.fromRGB(0, 255, 0), 6)
        SetupCube(GoalCube, Color3.fromRGB(255, 0, 0), 4)
        SetupCube(NoSpinCube, Color3.fromRGB(0, 255, 255), 5)
    end
    InitializeCubes()

    local function DrawOrientedCube(cube, cframe, size)
        if not cframe or not size then for _, line in ipairs(cube) do if line then line.Visible = false end end; return end
        local success = pcall(function()
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
                if line and aVis and bVis and aScreen.Z > 0 and bScreen.Z > 0 then
                    line.From = Vector2.new(aScreen.X, aScreen.Y)
                    line.To = Vector2.new(bScreen.X, bScreen.Y)
                    line.Visible = true
                else if line then line.Visible = false end end
            end
        end)
        if not success then for _, line in ipairs(cube) do if line then line.Visible = false end end end
    end

    -- === GOAL & GOALIE ===
    local GoalCFrame, GoalWidth, GoalHeight
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

    local function GetEnemyGoalie()
        local myTeam = GetMyTeam()
        if not myTeam then Gui.GK.Text = "GK: None"; Gui.GK.Color = Color3.fromRGB(150,150,150); return nil, 0, 0, "None", false end
        local width = UpdateGoal()
        if not width then Gui.GK.Text = "GK: None"; Gui.GK.Color = Color3.fromRGB(150,150,150); return nil, 0, 0, "None", false end
        local halfWidth = width / 2
        local goalies = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Team and player.Team.Name ~= myTeam then
                local char = player.Character
                if char and char:FindFirstChild("Humanoid") and char.Humanoid.HipHeight >= 4 then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp and GoalCFrame then
                        local distGoal = (hrp.Position - GoalCFrame.Position).Magnitude
                        local localX = GoalCFrame:PointToObjectSpace(hrp.Position).X
                        local localY = GoalCFrame:PointToObjectSpace(hrp.Position).Y
                        local isInGoal = distGoal < 18 and math.abs(localX) < halfWidth + 2
                        table.insert(goalies, { hrp=hrp, localX=localX, localY=localY, distGoal=distGoal, distPlayer=(hrp.Position - HumanoidRootPart.Position).Magnitude, name=player.Name, isInGoal=isInGoal })
                    end
                end
            end
        end
        local goalieModelName = myTeam == "Away" and "HomeGoalie" or "Goalie"
        local goalieNPC = Workspace:FindFirstChild(goalieModelName)
        if goalieNPC and goalieNPC:FindFirstChild("HumanoidRootPart") then
            local hrp = goalieNPC.HumanoidRootPart
            local distGoal = (hrp.Position - GoalCFrame.Position).Magnitude
            local localX = GoalCFrame:PointToObjectSpace(hrp.Position).X
            local localY = GoalCFrame:PointToObjectSpace(hrp.Position).Y
            local isInGoal = distGoal < 18 and math.abs(localX) < halfWidth + 2
            table.insert(goalies, { hrp=hrp, localX=localX, localY=localY, distGoal=distGoal, distPlayer=(hrp.Position - HumanoidRootPart.Position).Magnitude, name="NPC", isInGoal=isInGoal })
        end
        if #goalies == 0 then Gui.GK.Text = "GK: None"; Gui.GK.Color = Color3.fromRGB(150,150,150); return nil, 0, 0, "None", false end
        table.sort(goalies, function(a, b) if a.isInGoal ~= b.isInGoal then return a.isInGoal end; return a.distGoal < b.distGoal end)
        local best = goalies[1]
        local isAggressive = not best.isInGoal
        Gui.GK.Text = string.format("GK: %s %s | X=%.1f, Y=%.1f", best.name, best.isInGoal and "(In Goal)" or "(Aggressive)", best.localX, best.localY)
        Gui.GK.Color = Color3.fromRGB(255, 200, 0)
        return best.hrp, best.localX, best.localY, best.name, isAggressive
    end

    -- === TRAJECTORY & TARGET ===
    local function CalculateTrajectoryHeight(dist, power, attackName, isLowShot)
        local cfg = State.AutoShoot.Attacks[attackName] or {}
        local baseHeightRange = cfg.BaseHeightRange or {Min = 0.15, Max = 0.45}
        local heightMult = cfg.HeightMult or 1.0
        local baseHeight

        if isLowShot then baseHeight = 0.5
        elseif dist <= 80 then baseHeight = math.clamp(baseHeightRange.Min + (dist / 400), baseHeightRange.Min, baseHeightRange.Max)
        elseif dist <= 100 then baseHeight = math.clamp(baseHeightRange.Min + (dist / 200), baseHeightRange.Min, baseHeightRange.Max)
        elseif dist <= 140 then baseHeight = math.clamp(baseHeightRange.Min + (dist / 80), baseHeightRange.Min, baseHeightRange.Max)
        else
            if attackName == "SmartCandle" then baseHeight = math.clamp(8 + (dist / 25), baseHeightRange.Min, baseHeightRange.Max) * (dist >= 180 and 0.6 or 0.75)
            elseif attackName == "FarSmartCandle" then baseHeight = math.clamp(40 + (dist / 5), baseHeightRange.Min, baseHeightRange.Max) * (dist >= 250 and 2.2 or 2.0)
            else baseHeight = math.clamp(8 + (dist / 25), baseHeightRange.Min, baseHeightRange.Max) * 0.9 end
        end
        local timeToTarget = dist / 200
        local gravityFall = attackName == "FarSmartCandle" and 10 or 0.5 * State.AutoShoot.Gravity.Value * timeToTarget^2
        local height = math.clamp(baseHeight + gravityFall, isLowShot and 0.5 or 2.0, State.AutoShoot.MaxHeight.Value)
        if power < 1.5 and attackName ~= "FarSmartCandle" then height = math.clamp(height * (power / 1.5), isLowShot and 0.5 or 2.0, height) end
        height = math.clamp(height * heightMult, isLowShot and 0.5 or 2.0, State.AutoShoot.MaxHeight.Value)
        return height, timeToTarget, gravityFall, baseHeight
    end

    local NoSpinPoint
    local function GetTarget(dist, goalieX, goalieY, isAggressive, goaliePos, playerAngle)
        if not GoalCFrame or not GoalWidth then return nil, "None", "None", 0 end
        if dist > State.AutoShoot.MaxDistance.Value then return nil, "None", "None", 0 end

        local startPos = HumanoidRootPart.Position
        local halfWidth = (GoalWidth / 2) - State.AutoShoot.Inset.Value
        local halfHeight = (GoalHeight / 2) - State.AutoShoot.Inset.Value
        local targetSide = goalieX > 0 and -1 or 1
        local playerLocalX = GoalCFrame:PointToObjectSpace(startPos).X
        local isOffAngle = math.abs(playerAngle) > 30
        local isClose = dist < 30
        local isLowShot = (dist < 80 and math.random() < 0.3) or (isAggressive and goalieY > 3)

        local candidates = {}
        local ricochetPoints = {
            {x=halfWidth, y=halfHeight, normal=Vector3.new(-1, 0, 0), type="RightPost"},
            {x=-halfWidth, y=halfHeight, normal=Vector3.new(1, 0, 0), type="LeftPost"},
            {x=0, y=GoalHeight-0.5, normal=Vector3.new(0, -1, 0), type="Crossbar"},
            {x=halfWidth, y=0.5, normal=Vector3.new(-1, 0, 0), type="RightLower"},
            {x=-halfWidth, y=0.5, normal=Vector3.new(1, 0, 0), type="LeftLower"}
        }

        for name, cfg in pairs(State.AutoShoot.Attacks) do
            if not cfg.Enabled.Value or dist < cfg.MinDist or dist > math.min(cfg.MaxDist, State.AutoShoot.MaxDistance.Value) then continue end
            local spin = cfg.Spin and (dist >= 110 or name == "CloseSpin") and (targetSide > 0 and "Right" or "Left") or "None"
            if name == "CloseSpin" and isOffAngle then spin = (playerLocalX > 0 and "Left" or "Right") end
            local xMult = cfg.XMult or 1
            local zOffset = cfg.ZOffset or 0
            local heightAdjust = 0
            if name == "CloseSpin" and isOffAngle then zOffset = cfg.ZOffset; heightAdjust = GoalHeight - 0.5; xMult = 1.0 end
            if name == "CloseSpin" or name == "SmartCorner" then
                if (playerLocalX < 0 and targetSide < 0) or (playerLocalX > 0 and targetSide > 0) then xMult = math.clamp(xMult * 0.7, 0.5, 0.8) end
            end
            local targets = {{x=targetSide * halfWidth * xMult, y=0, type="Direct"}}
            if name == "CloseSpin" and isOffAngle then targets = {{x=(playerLocalX > 0 and -halfWidth or halfWidth) * 0.95, y=GoalHeight - 0.5, type="Corner"}}
            elseif name == "SmartCorner" then targets = ricochetPoints end
            for _, target in ipairs(targets) do
                local x = target.x; local y = target.y; local targetType = target.type; local ricochetNormal = target.normal
                local randX = (name == "SideRicochet" or name == "CloseSpin" or name == "SmartCorner") and math.random(-0.15, 0.15) * halfWidth or 0
                local randY = (name == "SideRicochet" or name == "CloseSpin" or name == "SmartCorner") and math.random(-0.15, 0.15) * halfHeight or 0
                local power = cfg.Power or math.clamp(State.AutoShoot.MinPower.Value + dist * State.AutoShoot.PowerPerStud.Value, cfg.PowerMin or State.AutoShoot.MinPower.Value, State.AutoShoot.MaxPower.Value)
                power += cfg.PowerAdd or 0
                local derivation = 0
                if cfg.Spin and (dist >= 110 or name == "CloseSpin") then
                    local derivationBase = (dist / 100)^1.5 * (cfg.DerivationMult or 1.3) * power
                    if name == "CloseSpin" and isOffAngle then derivationBase = derivationBase * (math.abs(playerAngle) / 45) end
                    derivation = (spin == "Left" and 1 or -1) * derivationBase
                    if dist < 80 then derivation = derivation * (dist / 80) end
                elseif name == "SideRicochet" or name == "SmartCorner" then
                    derivation = math.random(-0.5, 0.5)
                end
                local height, timeToTarget, gravityFall, baseHeight = CalculateTrajectoryHeight(dist, power, name, isLowShot)
                if heightAdjust > 0 then height = math.clamp(heightAdjust, 2.0, State.AutoShoot.MaxHeight.Value)
                elseif isLowShot then height = 0.5 end
                local noSpinPos = GoalCFrame * Vector3.new(math.clamp(x + randX, -halfWidth+0.5, halfWidth-0.5), height + randY, 0)
                local worldPos = GoalCFrame * Vector3.new(x + derivation + randX, height + randY, zOffset)
                local shootDir = (worldPos - startPos).Unit
                local goalNormal = GoalCFrame.LookVector
                local angleScore = math.abs(shootDir:Dot(goalNormal))
                local postPenalty = math.abs(playerLocalX - (x + derivation + randX)) < halfWidth * 0.5 and 5 or 0
                local goaliePenalty = math.abs(goalieX - (x + derivation + randX)) * 3
                local goalieYDist = math.abs(goalieY - (height + randY))
                local distToTarget = goaliePos and (worldPos - goaliePos).Magnitude or 999
                local goalieBlockPenalty = distToTarget < 5 and 10 or 0
                if goaliePos then
                    local goalieDir = (goaliePos - startPos).Unit
                    if shootDir:Dot(goalieDir) > 0.9 then goalieBlockPenalty = goalieBlockPenalty + 15 end
                end
                local ricochetScore = 0
                if name == "SmartCorner" and ricochetNormal then
                    local reflectDir = shootDir - 2 * shootDir:Dot(ricochetNormal) * ricochetNormal
                    local reflectAwayFromGoalie = goalieX > 0 and reflectDir.X < 0 or goalieX < 0 and reflectDir.X > 0
                    ricochetScore = reflectAwayFromGoalie and 5 or 0
                end
                local score = goaliePenalty - angleScore * 2 - goalieYDist * 0.5 + math.random() - postPenalty - goalieBlockPenalty + ricochetScore
                if name == "CloseSpin" and isOffAngle then score = score + 5 elseif isClose then score = score + 3 end
                table.insert(candidates, { pos=worldPos, noSpinPos=noSpinPos, spin=spin, power=power, name=name, score=score, angleScore=angleScore, derivation=derivation, baseHeight=baseHeight, timeToTarget=timeToTarget, gravityFall=gravityFall, targetType=targetType })
            end
        end

        if #candidates == 0 then
            local x = targetSide * halfWidth * 0.9
            local power = math.clamp(State.AutoShoot.MinPower.Value + dist * State.AutoShoot.PowerPerStud.Value, State.AutoShoot.MinPower.Value, State.AutoShoot.MaxPower.Value)
            local height, timeToTarget, gravityFall, baseHeight = CalculateTrajectoryHeight(dist, power, "FALLBACK", isLowShot)
            local spin = dist >= 110 and (targetSide > 0 and "Right" or "Left") or "None"
            local zOffset = playerLocalX < 0 and 2.0 or 0
            local derivation = 0
            if dist >= 110 then
                derivation = (spin == "Left" and 1 or -1) * (dist / 100)^1.5 * 1.3 * power
                if dist < 80 then derivation = derivation * (dist / 80) end
            elseif dist < 80 then
                derivation = math.random(-0.5, 0.5)
            end
            local targets = ricochetPoints
            for _, target in ipairs(targets) do
                local x = target.x; local y = target.y; local targetType = target.type; local ricochetNormal = target.normal
                local randX = math.random(-0.15, 0.15) * halfWidth
                local randY = math.random(-0.15, 0.15) * halfHeight
                local noSpinPos = GoalCFrame * Vector3.new(math.clamp(x + randX, -halfWidth+0.5, halfWidth-0.5), height + randY, 0)
                local worldPos = GoalCFrame * Vector3.new(x + derivation + randX, height + randY, zOffset)
                local shootDir = (worldPos - startPos).Unit
                local goalNormal = GoalCFrame.LookVector
                local angleScore = math.abs(shootDir:Dot(goalNormal))
                local postPenalty = math.abs(playerLocalX - (x + derivation + randX)) < halfWidth * 0.5 and 5 or 0
                local goaliePenalty = math.abs(goalieX - (x + derivation + randX)) * 3
                local goalieYDist = math.abs(goalieY - (height + randY))
                local distToTarget = goaliePos and (worldPos - goaliePos).Magnitude or 999
                local goalieBlockPenalty = distToTarget < 5 and 10 or 0
                if goaliePos then
                    local goalieDir = (goaliePos - startPos).Unit
                    if shootDir:Dot(goalieDir) > 0.9 then goalieBlockPenalty = goalieBlockPenalty + 15 end
                end
                local ricochetScore = 0
                if ricochetNormal then
                    local reflectDir = shootDir - 2 * shootDir:Dot(ricochetNormal) * ricochetNormal
                    local reflectAwayFromGoalie = goalieX > 0 and reflectDir.X < 0 or goalieX < 0 and reflectDir.X > 0
                    ricochetScore = reflectAwayFromGoalie and 5 or 0
                end
                local score = goaliePenalty - angleScore * 2 - goalieYDist * 0.5 + math.random() - postPenalty - goalieBlockPenalty + ricochetScore
                if isClose then score = score + 3 end
                table.insert(candidates, { pos=worldPos, noSpinPos=noSpinPos, spin=spin, power=power, name="FALLBACK", score=score, angleScore=angleScore, derivation=derivation, baseHeight=baseHeight, timeToTarget=timeToTarget, gravityFall=gravityFall, targetType=targetType })
            end
        end

        table.sort(candidates, function(a, b) return a.score > b.score end)
        local selected = candidates[1]
        return selected.pos, selected.spin, selected.name .. " (" .. selected.targetType .. ")", selected.power, selected.noSpinPos
    end

    local TargetPoint, ShootDir, ShootVel, CurrentSpin, CurrentPower, CurrentType, NoSpinPoint
    local function CalculateTarget()
        local width = UpdateGoal()
        if not GoalCFrame or not width then TargetPoint = nil; NoSpinPoint = nil; Gui.Target.Text = "Target: --"; Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --"; return end

        local dist = (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude
        Gui.Dist.Text = string.format("Dist: %.1f (Max: %.1f)", dist, State.AutoShoot.MaxDistance.Value)
        if dist > State.AutoShoot.MaxDistance.Value then TargetPoint = nil; NoSpinPoint = nil; Gui.Target.Text = "Target: --"; Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --"; return end

        local startPos = HumanoidRootPart.Position
        local goalDir = (GoalCFrame.Position - startPos).Unit
        local forwardDir = (HumanoidRootPart.CFrame.LookVector).Unit
        local playerAngle = math.deg(math.acos(goalDir:Dot(forwardDir)))
        local goalieHrp, goalieX, goalieY, _, isAggressive = GetEnemyGoalie()
        local goaliePos = goalieHrp and goalieHrp.Position or nil
        local worldTarget, spin, name, power, noSpinPos = GetTarget(dist, goalieX or 0, goalieY or 0, isAggressive or false, goaliePos, playerAngle)
        if not worldTarget then TargetPoint = nil; NoSpinPoint = nil; Gui.Target.Text = "Target: --"; Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --"; return end

        TargetPoint = worldTarget
        NoSpinPoint = noSpinPos
        CurrentSpin = spin
        CurrentType = name
        CurrentPower = power
        ShootDir = (worldTarget - startPos).Unit
        ShootVel = ShootDir * (power * 1400)

        Gui.Target.Text = string.format("Target: %s", name)
        Gui.Power.Text = string.format("Power: %.2f", power)
        Gui.Spin.Text = string.format("Spin: %s", spin)
    end

    -- === RENDER & HEARTBEAT ===
    RunService.RenderStepped:Connect(function()
        local width = UpdateGoal()
        if GoalCFrame and width then DrawOrientedCube(GoalCube, GoalCFrame, Vector3.new(width, GoalHeight, 2)) else for _, l in ipairs(GoalCube) do if l then l.Visible = false end end end

        if TargetPoint then
            local targetCFrame = CFrame.new(TargetPoint)
            local cubeSize = Vector3.new(4, 4, 4)
            local distToCamera = (Camera.CFrame.Position - TargetPoint).Magnitude
            if distToCamera < 500 then DrawOrientedCube(TargetCube, targetCFrame, cubeSize) else for _, l in ipairs(TargetCube) do if l then l.Visible = false end end end
        else
            for _, l in ipairs(TargetCube) do if l then l.Visible = false end end
        end

        if NoSpinPoint then
            local noSpinCFrame = CFrame.new(NoSpinPoint)
            local cubeSize = Vector3.new(3, 3, 3)
            local distToCamera = (Camera.CFrame.Position - NoSpinPoint).Magnitude
            if distToCamera < 500 then DrawOrientedCube(NoSpinCube, noSpinCFrame, cubeSize) else for _, l in ipairs(NoSpinCube) do if l then l.Visible = false end end end
        else
            for _, l in ipairs(NoSpinCube) do if l then l.Visible = false end end
        end
    end)

    local CanShoot = true
    local LastShoot = 0
    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp or not State.AutoShoot.Enabled.Value or not State.AutoShoot.ManualShot.Value then return end
        if inp.KeyCode == State.AutoShoot.ShootKey.Value and CanShoot then
            local ball = Workspace:FindFirstChild("ball")
            local hasBall = ball and ball:FindFirstChild("playerWeld") and ball.creator.Value == LocalPlayer
            if hasBall and TargetPoint then
                pcall(CalculateTarget)
                if ShootDir then
                    if State.AutoShoot.Legit.Value and not IsAnimating then
                        IsAnimating = true
                        RShootAnim:Play()
                        task.delay(AnimationHoldTime, function() IsAnimating = false end)
                    end

                    local success = pcall(function()
                        Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
                    end)
                    if success then
                        Gui.Status.Text = string.format("MANUAL SHOT! [%s]", CurrentType)
                        Gui.Status.Color = Color3.fromRGB(0,255,0)
                        LastShoot = tick()
                        CanShoot = false
                        task.delay(0.3, function() CanShoot = true end)
                    end
                end
            end
        end
    end)

    local function AutoShootFunc()
        if State.AutoShoot.ManualShot.Value or not State.AutoShoot.Enabled.Value then return end
        local ball = Workspace:FindFirstChild("ball")
        if not ball or not ball:FindFirstChild("playerWeld") or ball:FindFirstChild("playerWeld").Part0 ~= Character.PrimaryPart or
           not ball:FindFirstChild("creator") or ball.creator.Value ~= LocalPlayer or not ShootDir or tick() - LastShoot < 0.3 then return end
        local dist = (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude
        if dist > State.AutoShoot.MaxDistance.Value then return end

        if State.AutoShoot.Legit.Value and not IsAnimating then
            IsAnimating = true
            RShootAnim:Play()
            task.delay(AnimationHoldTime, function() IsAnimating = false end)
        end

        local success = pcall(function()
            Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
        end)
        if success then
            Gui.Status.Text = string.format("AUTO SHOT! [%s]", CurrentType)
            Gui.Status.Color = Color3.fromRGB(0,255,0)
            LastShoot = tick()
        end
    end

    RunService.Heartbeat:Connect(function()
        if not State.AutoShoot.Enabled.Value then return end
        pcall(CalculateTarget)

        local ball = Workspace:FindFirstChild("ball")
        local hasBall = ball and ball:FindFirstChild("playerWeld") and ball.creator.Value == LocalPlayer
        local dist = GoalCFrame and (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude or 999

        if hasBall and TargetPoint and dist <= State.AutoShoot.MaxDistance.Value then
            Gui.Status.Text = State.AutoShoot.ManualShot.Value and "Ready (Press " .. GetKeyName(State.AutoShoot.ShootKey.Value) .. ")" or "Aiming..."
            Gui.Status.Color = Color3.fromRGB(0,255,0)
        elseif hasBall then
            Gui.Status.Text = dist > State.AutoShoot.MaxDistance.Value and "Too Far" or "No Target"
            Gui.Status.Color = Color3.fromRGB(255,100,0)
        else
            Gui.Status.Text = "No Ball"
            Gui.Status.Color = Color3.fromRGB(255,165,0)
        end

        UpdateModeText()
        AutoShootFunc()
    end)

    RunService.Heartbeat:Connect(function()
        if not State.AutoShoot.AutoPickup.Value then return end
        local ball = Workspace:FindFirstChild("ball")
        if not ball or ball:FindFirstChild("playerWeld") or (HumanoidRootPart.Position - ball.Position).Magnitude > State.AutoShoot.PickupDist.Value then return end
        if PickupRemote then pcall(function() PickupRemote:FireServer(State.AutoShoot.SpoofValue.Value) end) end
    end)

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
        LastShoot = 0
        IsAnimating = false
        CanShoot = true
        InitializeCubes()
        UpdateModeText()
    end)

    -- === UI SECTION (уже существует) ===
    local uiElements = {}
    local section = UI.Tabs.Main:Section({Name = 'Auto Shoot', Side = 'Left'})

    section:Header({ Name = "Auto Shoot" })
    section:SubLabel({ Text = "goal aimbot with manual/auto modes" })

    uiElements.Enabled = section:Toggle({
        Name = "Enabled",
        Default = State.AutoShoot.Enabled.Default,
        Callback = function(v) State.AutoShoot.Enabled.Value = v; notify("AutoShoot", v and "Enabled" or "Disabled", v) end
    }, 'AutoShootEnabled')

    uiElements.Legit = section:Toggle({
        Name = "Legit Animation",
        Default = State.AutoShoot.Legit.Default,
        Callback = function(v) State.AutoShoot.Legit.Value = v end
    }, 'AutoShootLegit')

    uiElements.ManualShot = section:Toggle({
        Name = "Manual Shot",
        Default = State.AutoShoot.ManualShot.Default,
        Callback = function(v) State.AutoShoot.ManualShot.Value = v; UpdateModeText() end
    }, 'AutoShootManual')

    uiElements.ShootKey = section:Keybind({
        Name = "Shoot Key",
        Default = State.AutoShoot.ShootKey.Default,
        Callback = function(v) State.AutoShoot.ShootKey.Value = v; UpdateModeText() end
    }, 'AutoShootKey')

    section:Divider()

    uiElements.AutoPickup = section:Toggle({
        Name = "Auto Pickup",
        Default = State.AutoShoot.AutoPickup.Default,
        Callback = function(v) State.AutoShoot.AutoPickup.Value = v end
    }, 'AutoShootPickup')

    uiElements.PickupDist = section:Slider({
        Name = "Pickup Distance",
        Minimum = 50, Maximum = 300, Default = State.AutoShoot.PickupDist.Default,
        Callback = function(v) State.AutoShoot.PickupDist.Value = v end
    }, 'AutoShootPickupDist')

    uiElements.MaxDistance = section:Slider({
        Name = "Shoot Distance",
        Minimum = 100, Maximum = 300, Default = State.AutoShoot.MaxDistance.Default,
        Callback = function(v) State.AutoShoot.MaxDistance.Value = v end
    }, 'AutoShootMaxDist')

    -- === АТАКИ ===
    section:Divider()
    section:Header({ Name = "Attack Modes" })
    for name, cfg in pairs(State.AutoShoot.Attacks) do
        section:Toggle({
            Name = name,
            Default = cfg.Enabled.Default,
            Callback = function(v) cfg.Enabled.Value = v end
        }, 'AutoShoot_'..name)
    end

    function AutoShoot:Destroy()
        for _, v in pairs(Gui) do if v.Remove then v:Remove() end end
        for i = 1, 12 do
            if TargetCube[i] then TargetCube[i]:Remove() end
            if GoalCube[i] then GoalCube[i]:Remove() end
            if NoSpinCube[i] then NoSpinCube[i]:Remove() end
        end
    end

    return AutoShoot
end

return AutoShoot