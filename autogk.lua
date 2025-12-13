-- GK Helper v46 — Advanced Defense Module
-- Модульный скрипт для лоадера

local player = game.Players.LocalPlayer
local ws = workspace
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- V46 ADVANCED DEFENSE - НАСТРОЙКИ КОНФИГУРАЦИИ
local CONFIG = {
    -- === ДВИЖЕНИЕ ===
    SPEED = 34,                     -- Базовая скорость перемещения
    STAND_DIST = 2.6,               -- Стандартное расстояние от ворот при защите
    MIN_DIST = 1.3,                 -- Минимальное расстояние для начала движения
    MAX_CHASE_DIST = 40,            -- Максимальная дистанция преследования врага

    -- === ПРЕДСКАЗАНИЕ ТРАЕКТОРИИ ===
    PRED_STEPS = 120,               -- Количество шагов предсказания траектории мяча
    CURVE_MULT = 38,                -- Множитель кривого удара
    DT = 1/60,                      -- Дельта времени для расчета физики
    GRAVITY = 110,                  -- Сила гравитации для предсказания
    DRAG = 0.982,                   -- Сопротивление воздуха
    BOUNCE_XZ = 0.72,               -- Отскок мяча по горизонтали
    BOUNCE_Y = 0.68,                -- Отскок мяча по вертикали

    -- === ДИСТАНЦИИ ===
    AGGRO_THRES = 45,               -- Дистанция до врага для агрессивного режима
    DIVE_DIST = 14,                 -- Максимальная дистанция для дайва
    ENDPOINT_DIVE = 4,              -- Дистанция до endpoint для дайва
    TOUCH_RANGE = 8.5,              -- Дистанция касания мяча руками
    NEAR_BALL_DIST = 7,             -- Дистанция "близко к мячу" для автоматического отбития

    -- === ЗОНА ЗАЩИТЫ ===
    ZONE_DIST = 56,                 -- Глубина защитной зоны (зеленый куб)
    ZONE_WIDTH = 2.5,               -- Ширина защитной зоны относительно ширины ворот

    -- === ПОРОГИ СРАБАТЫВАНИЯ ===
    DIVE_VEL_THRES = 18,            -- Минимальная скорость мяча для дайва
    JUMP_VEL_THRES = 31,            -- Минимальная скорость мяча для прыжка
    HIGH_BALL_THRES = 6.8,          -- Высота мяча для прыжка
    CLOSE_THREAT_DIST = 4.0,        -- Дистанция для угрозы вблизи
    JUMP_THRES = 5.0,               -- Порог высоты для определения прыжка
    GATE_COVERAGE = 0.99,           -- Покрытие ворот (1.0 = полное покрытие)
    CENTER_BIAS_DIST = 21,          -- Дистанция смещения к центру
    LATERAL_MAX_MULT = 0.45,        -- Максимальное боковое смещение относительно ширины ворот

    -- === КУЛДАУНЫ ===
    DIVE_COOLDOWN = 1.3,            -- КД между дайвами
    JUMP_COOLDOWN = 0.95,           -- КД между прыжками
    ATTACK_COOLDOWN = 1.5,          -- КД между сменой целей атаки

    -- === СКОРОСТЬ ДАЙВА ===
    DIVE_SPEED = 40,                -- Скорость дайва

    -- === ВИЗУАЛЬНЫЕ НАСТРОЙКИ ===
    SHOW_TRAJECTORY = true,         -- Показывать траекторию мяча
    SHOW_ENDPOINT = true,           -- Показывать конечную точку мяча
    SHOW_GOAL_CUBE = true,          -- Показывать красный куб ворот
    SHOW_ZONE = true,               -- Показывать зеленый куб защитной зоны
    SHOW_BALL_BOX = true,           -- Показывать куб вокруг мяча

    -- === РОТАЦИЯ ===
    ROT_SMOOTH = 0.79,              -- Плавность поворота (0-1, больше = плавнее)
    
    -- === УЛУЧШЕННАЯ ЗАЩИТА ===
    BALL_INTERCEPT_RANGE = 4.5,     -- Дистанция для перехвата мяча
    MIN_INTERCEPT_TIME = 0.1,       -- Минимальное время для перехвата
    ADVANCE_DISTANCE = 3.8,         -- Дистанция выхода вперед
    DIVE_LOOK_AHEAD = 0.25,         -- Упреждение взгляда при дайве
    
    -- === НАСТРОЙКИ АТАКИ ===
    PRIORITY = "attack",           -- Приоритет: "defense" - защита, "attack" - атака
    AUTO_ATTACK_IN_ZONE = true,     -- Автоматически атаковать врагов в защитной зоне
    ATTACK_DISTANCE = 34,          -- Дистанция для приближения к врагу
    BLOCK_ANGLE_MULT = 0.85,        -- Множитель блокировки угла обзора врага (0-1)
    AGGRESSIVE_MODE = false,        -- Агрессивный режим (постоянно преследовать врага)
    ATTACK_WHEN_CLOSE_TO_BALL = true -- Атаковать врага с мячом
}

-- Состояния модуля
local moduleState = {
    enabled = false,
    lastDiveTime = 0,
    lastJumpTime = 0,
    lastAttackTime = 0,
    isDiving = false,
    endpointRadius = 4.0,
    currentTargetType = nil,
    frameCounter = 0,
    cachedPoints = nil,
    lastBallVelMag = 0,
    isGoalkeeper = false,
    lastGoalkeeperCheck = 0,
    currentBV = nil,
    currentGyro = nil,
    smoothCFrame = nil,
    visualObjects = {}
}

-- Глобальные переменные
local GoalCFrame, GoalForward, GoalWidth = nil, nil, 0
local maxDistFromGoal = 50

-- Функция для создания визуалов
local function createVisuals()
    -- Очищаем старые визуалы если есть
    for _, objList in pairs(moduleState.visualObjects) do
        if type(objList) == "table" then
            for _, drawing in pairs(objList) do
                if drawing and drawing.Remove then
                    pcall(function() drawing:Remove() end)
                end
            end
        end
    end
    moduleState.visualObjects = {}
    
    if CONFIG.SHOW_GOAL_CUBE then
        moduleState.visualObjects.GoalCube = {}
        for i = 1, 12 do 
            local line = Drawing.new("Line")
            line.Thickness = 4 
            line.Transparency = 0.5
            line.Visible = false
            moduleState.visualObjects.GoalCube[i] = line
        end
    end
    
    if CONFIG.SHOW_ZONE then
        moduleState.visualObjects.LimitCube = {}
        for i = 1, 12 do 
            local line = Drawing.new("Line")
            line.Thickness = 4 
            line.Transparency = 0.5
            line.Visible = false
            moduleState.visualObjects.LimitCube[i] = line
        end
    end
    
    if CONFIG.SHOW_BALL_BOX then
        moduleState.visualObjects.BallBox = {}
        for i = 1, 12 do 
            local line = Drawing.new("Line")
            line.Thickness = 4 
            line.Transparency = 0.5
            line.Visible = false
            moduleState.visualObjects.BallBox[i] = line
        end
    end
    
    if CONFIG.SHOW_TRAJECTORY then
        moduleState.visualObjects.trajLines = {}
        for i = 1, CONFIG.PRED_STEPS do
            local line = Drawing.new("Line")
            line.Thickness = 2.5 
            line.Color = Color3.fromHSV(i / CONFIG.PRED_STEPS, 1, 1) 
            line.Transparency = 0.45
            line.Visible = false
            moduleState.visualObjects.trajLines[i] = line
        end
    end
    
    if CONFIG.SHOW_ENDPOINT then
        moduleState.visualObjects.endpointLines = {}
        for i = 1, 24 do
            local line = Drawing.new("Line")
            line.Thickness = 3 
            line.Color = Color3.new(1,1,0) 
            line.Transparency = 0.5
            line.Visible = false
            moduleState.visualObjects.endpointLines[i] = line
        end
    end
end

local function clearAllVisuals()
    for _, objList in pairs(moduleState.visualObjects) do
        if type(objList) == "table" then
            for _, drawing in pairs(objList) do
                if drawing then
                    pcall(function()
                        drawing.Visible = false
                        drawing:Remove()
                    end)
                end
            end
        end
    end
    moduleState.visualObjects = {}
end

local function hideAllVisuals()
    for _, objList in pairs(moduleState.visualObjects) do
        if type(objList) == "table" then
            for _, drawing in pairs(objList) do
                if drawing then
                    drawing.Visible = false
                end
            end
        end
    end
end

-- Функция проверки вратаря
local function checkIfGoalkeeper()
    if tick() - moduleState.lastGoalkeeperCheck < 1 then return moduleState.isGoalkeeper end
    
    moduleState.lastGoalkeeperCheck = tick()
    local isHPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("HPG") and ws.Bools.HPG.Value == player
    local isAPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("APG") and ws.Bools.APG.Value == player
    
    local wasGoalkeeper = moduleState.isGoalkeeper
    moduleState.isGoalkeeper = isHPG or isAPG
    
    -- Если перестали быть вратарем - очищаем визуалы
    if wasGoalkeeper and not moduleState.isGoalkeeper then
        hideAllVisuals()
        if moduleState.currentBV then pcall(function() moduleState.currentBV:Destroy() end) moduleState.currentBV = nil end
        if moduleState.currentGyro then pcall(function() moduleState.currentGyro:Destroy() end) moduleState.currentGyro = nil end
    end
    
    -- Если стали вратарем - создаем визуалы
    if moduleState.isGoalkeeper and not wasGoalkeeper and moduleState.enabled then
        createVisuals()
    end
    
    return moduleState.isGoalkeeper
end

local function updateGoals()
    if not checkIfGoalkeeper() then return false end
    
    local isHPG = ws.Bools.HPG.Value == player
    local isAPG = ws.Bools.APG.Value == player
    
    local posModelName = isHPG and "HomePosition" or "AwayPosition"
    local posModel = ws:FindFirstChild(posModelName)
    if not posModel then return false end
    
    local parts = {}
    for _, obj in posModel:GetDescendants() do 
        if obj:IsA("BasePart") then table.insert(parts, obj) end 
    end
    if #parts == 0 then return false end
    
    local center = Vector3.new()
    for _, part in parts do center = center + part.Position end 
    center = center / #parts
    
    local goalName = isHPG and "HomeGoal" or "AwayGoal"
    local goal = ws:FindFirstChild(goalName)
    
    if goal and goal:FindFirstChild("Frame") then
        local frame = goal.Frame
        local left = frame:FindFirstChild("LeftPost")
        local right = frame:FindFirstChild("RightPost")
        
        if left and right then
            local gcenter = (left.Position + right.Position) / 2
            local rightDir = (right.Position - left.Position).Unit
            local fieldDir = center - gcenter
            fieldDir = fieldDir - fieldDir:Dot(rightDir) * rightDir  
            fieldDir = Vector3.new(fieldDir.X, 0, fieldDir.Z)
            
            local fwdMag = fieldDir.Magnitude
            if fwdMag > 0.1 then
                GoalForward = fieldDir.Unit
            else
                GoalForward = rightDir:Cross(Vector3.new(0,1,0)).Unit
            end
            
            local minDist, maxDist = math.huge, -math.huge
            for _, part in parts do
                local rel = part.Position - gcenter  
                local dist = rel:Dot(GoalForward)
                minDist = math.min(minDist, dist)
                maxDist = math.max(maxDist, dist)
            end
            
            if maxDist - minDist < 10 or maxDist < 10 then
                GoalForward = -GoalForward
                minDist, maxDist = math.huge, -math.huge
                for _, part in parts do
                    local rel = part.Position - gcenter
                    dist = rel:Dot(GoalForward)
                    minDist = math.min(minDist, dist)
                    maxDist = math.max(maxDist, dist)
                end
            end
            
            GoalCFrame = CFrame.fromMatrix(gcenter, rightDir, Vector3.new(0,1,0), -GoalForward)
            GoalWidth = (right.Position - left.Position).Magnitude
            maxDistFromGoal = math.max(34, maxDist - minDist + 15)
            return true
        end
    end
    return false
end

local function drawCube(cube, cf, size, color)
    if not cube or not cf or not cf.Position then 
        if cube then
            for _, l in cube do 
                if l then l.Visible = false end 
            end 
        end
        return 
    end
    
    local cam = ws.CurrentCamera
    if not cam then return end
    
    local h = size / 2
    local corners = {
        cf * Vector3.new(-h.X, -h.Y, -h.Z), cf * Vector3.new( h.X, -h.Y, -h.Z), 
        cf * Vector3.new( h.X,  h.Y, -h.Z), cf * Vector3.new(-h.X,  h.Y, -h.Z),
        cf * Vector3.new(-h.X, -h.Y,  h.Z), cf * Vector3.new( h.X, -h.Y,  h.Z), 
        cf * Vector3.new( h.X,  h.Y,  h.Z), cf * Vector3.new(-h.X,  h.Y,  h.Z)
    }
    
    local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
    
    for i, e in ipairs(edges) do
        local a, b = corners[e[1]], corners[e[2]]
        local sa, sb = cam:WorldToViewportPoint(a), cam:WorldToViewportPoint(b)
        local l = cube[i]
        
        if l then
            l.From = Vector2.new(sa.X, sa.Y) 
            l.To = Vector2.new(sb.X, sb.Y) 
            l.Color = color or Color3.new(1,1,1)
            l.Visible = sa.Z > 0 and sb.Z > 0
        end
    end
end

local function drawFlatZone()
    if not (GoalCFrame and GoalForward and GoalWidth) or not moduleState.visualObjects.LimitCube then 
        if moduleState.visualObjects.LimitCube then
            for _, l in moduleState.visualObjects.LimitCube do 
                if l then l.Visible = false end 
            end 
        end
        return 
    end
    
    local center = GoalCFrame.Position + GoalForward * (CONFIG.ZONE_DIST / 2)
    local flatCF = CFrame.new(center.X, 0, center.Z) * GoalCFrame.Rotation
    drawCube(moduleState.visualObjects.LimitCube, flatCF, Vector3.new(GoalWidth * CONFIG.ZONE_WIDTH, 0.2, CONFIG.ZONE_DIST), Color3.fromRGB(0, 255, 0))
end

local function drawEndpoint(pos)
    if not pos or not moduleState.visualObjects.endpointLines then 
        if moduleState.visualObjects.endpointLines then
            for _, l in moduleState.visualObjects.endpointLines do 
                if l then l.Visible = false end 
            end 
        end
        return 
    end
    
    local cam = ws.CurrentCamera 
    if not cam then return end
    
    local step = math.pi * 2 / 24
    for i = 1, 24 do
        local a1, a2 = (i-1)*step, i*step
        local p1 = pos + Vector3.new(math.cos(a1)*moduleState.endpointRadius, 0, math.sin(a1)*moduleState.endpointRadius)
        local p2 = pos + Vector3.new(math.cos(a2)*moduleState.endpointRadius, 0, math.sin(a2)*moduleState.endpointRadius)
        local s1, s2 = cam:WorldToViewportPoint(p1), cam:WorldToViewportPoint(p2)
        local l = moduleState.visualObjects.endpointLines[i]
        
        if l then
            l.From = Vector2.new(s1.X, s1.Y) 
            l.To = Vector2.new(s2.X, s2.Y) 
            l.Visible = s1.Z > 0 and s2.Z > 0
        end
    end
end

local function predictTrajectory(ball)
    local points = {ball.Position}
    local pos, vel = ball.Position, ball.Velocity
    local dt = CONFIG.DT
    local gravity = CONFIG.GRAVITY
    local drag = CONFIG.DRAG
    local steps = CONFIG.PRED_STEPS
    local spinCurve = Vector3.new(0,0,0)
    
    pcall(function()
        if ws.Bools.Curve and ws.Bools.Curve.Value then 
            spinCurve = ball.CFrame.RightVector * CONFIG.CURVE_MULT * 0.035
        end
        if ws.Bools.Header and ws.Bools.Header.Value then 
            spinCurve = spinCurve + Vector3.new(0, 28, 0) 
        end
    end)
    
    for i = 1, steps do
        local curveFade = 1 - (i/steps) * 0.5
        vel = vel * drag + spinCurve * dt * curveFade
        vel = vel - Vector3.new(0, gravity * dt * 1.02, 0)
        pos = pos + vel * dt
        
        if pos.Y < 0.5 then
            pos = Vector3.new(pos.X, 0.5, pos.Z)
            vel = Vector3.new(vel.X * CONFIG.BOUNCE_XZ, math.abs(vel.Y) * CONFIG.BOUNCE_Y, vel.Z * CONFIG.BOUNCE_XZ)
        end
        table.insert(points, pos)
    end
    return points
end

local function moveToTarget(root, targetPos)
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    local dirVec = (targetPos - root.Position) * Vector3.new(1,0,1)
    if dirVec.Magnitude < CONFIG.MIN_DIST then return end
    
    moduleState.currentBV = Instance.new("BodyVelocity", root)
    moduleState.currentBV.MaxForce = Vector3.new(4e5, 0, 4e5)
    moduleState.currentBV.Velocity = dirVec.Unit * CONFIG.SPEED
    game.Debris:AddItem(moduleState.currentBV, 1.4)
    
    if ts then
        ts:Create(moduleState.currentBV, tweenInfo, {Velocity = Vector3.new()}):Play()
    end
end

local function rotateSmooth(root, targetPos, isOwner, isDivingNow, ballVel)
    if isOwner then 
        if moduleState.currentGyro then 
            pcall(function() moduleState.currentGyro:Destroy() end) 
            moduleState.currentGyro = nil
        end
        moduleState.currentTargetType = "owner"
        return 
    end
    
    if not moduleState.smoothCFrame then moduleState.smoothCFrame = root.CFrame end
    
    local finalLookPos
    
    if isDivingNow and ballVel then
        -- При дайве смотрим туда, куда летит мяч (с небольшим упреждением)
        finalLookPos = targetPos + ballVel.Unit * CONFIG.DIVE_LOOK_AHEAD
        moduleState.currentTargetType = "dive"
    else
        -- В остальное время смотрим на мяч
        finalLookPos = targetPos
        moduleState.currentTargetType = "ball"
    end
    
    local targetLook = CFrame.lookAt(root.Position, finalLookPos)
    moduleState.smoothCFrame = moduleState.smoothCFrame:Lerp(targetLook, CONFIG.ROT_SMOOTH)
    
    if moduleState.currentGyro then 
        pcall(function() moduleState.currentGyro:Destroy() end) 
        moduleState.currentGyro = nil
    end
    
    moduleState.currentGyro = Instance.new("BodyGyro", root)
    moduleState.currentGyro.Name = "GKRoto"
    moduleState.currentGyro.P = 2500000
    moduleState.currentGyro.MaxTorque = Vector3.new(0, 4e6, 0)
    moduleState.currentGyro.CFrame = moduleState.smoothCFrame
    game.Debris:AddItem(moduleState.currentGyro, 0.22)
end

local function playJumpAnimation(hum)
    pcall(function()
        local anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK.Jump)
        anim.Priority = Enum.AnimationPriority.Action4
        anim:Play()
    end)
end

local function forceJump(hum)
    local oldPower = hum.JumpPower
    hum.JumpPower = 72
    hum.Jump = true
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    playJumpAnimation(hum)
    task.wait(0.04)
    hum.JumpPower = oldPower
end

local function getSmartPosition(defenseBase, rightVec, lateral, goalWidth, threatLateral, enemyLateral, isAggro)
    local maxLateral = goalWidth * CONFIG.LATERAL_MAX_MULT
    local baseLateral = math.clamp(lateral, -maxLateral, maxLateral)
    
    if threatLateral ~= 0 then 
        baseLateral = threatLateral * 0.97 
    end
    
    if enemyLateral ~= 0 and isAggro then 
        baseLateral = enemyLateral * 0.92 
    end
    
    local finalLateral = math.clamp(baseLateral, -maxLateral * CONFIG.GATE_COVERAGE, maxLateral * CONFIG.GATE_COVERAGE)
    return Vector3.new(defenseBase.X + rightVec.X * finalLateral, defenseBase.Y, defenseBase.Z + rightVec.Z * finalLateral)
end

local function clearTrajAndEndpoint()
    if moduleState.visualObjects.trajLines then
        for _, l in moduleState.visualObjects.trajLines do 
            if l then l.Visible = false end 
        end
    end
    
    if moduleState.visualObjects.endpointLines then
        for _, l in moduleState.visualObjects.endpointLines do 
            if l then l.Visible = false end 
        end
    end
end

-- Функция: Поиск точки для перехвата
local function findBestInterceptPoint(rootPos, ballPos, ballVel, points)
    if not points or #points < 2 then return nil end
    
    local bestPoint = nil
    local bestScore = math.huge
    
    for i = 2, #points do
        local point = points[i]
        local distToPoint = (rootPos - point).Magnitude
        local ballTravelDist = 0
        
        -- Вычисляем расстояние, которое пролетит мяч до этой точки
        for j = 1, i-1 do
            ballTravelDist = ballTravelDist + (points[j+1] - points[j]).Magnitude
        end
        
        local timeToPoint = ballTravelDist / math.max(1, ballVel.Magnitude)
        local timeToReach = distToPoint / CONFIG.SPEED
        
        -- Если можем добраться до точки раньше мяча
        if timeToReach < timeToPoint - CONFIG.MIN_INTERCEPT_TIME then
            local score = distToPoint + (point - GoalCFrame.Position):Dot(GoalForward) * 0.5
            if score < bestScore then
                bestScore = score
                bestPoint = point
            end
        end
    end
    
    return bestPoint
end

-- Функция: Проверка находится ли игрок в защитной зоне
local function isInDefenseZone(position)
    if not (GoalCFrame and GoalForward) then return false end
    
    local relPos = position - GoalCFrame.Position
    local distForward = relPos:Dot(GoalForward)
    local distLateral = math.abs(relPos:Dot(GoalCFrame.RightVector))
    
    return distForward > 0 and distForward < CONFIG.ZONE_DIST and 
           distLateral < (GoalWidth * CONFIG.ZONE_WIDTH) / 2
end

-- Функция: Поиск цели для атаки (уменьшение угла обзора врага)
local function findAttackTarget(rootPos, ball)
    local bestTarget = nil
    local bestScore = -math.huge
    
    for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local targetRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = otherPlayer.Character:FindFirstChild("Humanoid")
            
            if targetRoot and targetHum and targetHum.Health > 0 then
                -- Проверяем команду (враг ли)
                local isEnemy = true
                pcall(function()
                    if ws.Bools.HPG.Value == otherPlayer or ws.Bools.APG.Value == otherPlayer then
                        isEnemy = false
                    end
                end)
                
                if isEnemy then
                    local distToTarget = (rootPos - targetRoot.Position).Magnitude
                    local inZone = isInDefenseZone(targetRoot.Position)
                    
                    -- Вычисляем оценку цели
                    local score = 0
                    
                    -- Приоритет целям в защитной зоне
                    if inZone then
                        score = score + 50
                    end
                    
                    -- Приоритет целям с мячом
                    local hasBall = false
                    pcall(function()
                        if ball:FindFirstChild("creator") and ball.creator.Value == otherPlayer then
                            hasBall = true
                            score = score + 100
                        end
                    end)
                    
                    -- Приоритет ближайшим целям
                    score = score + (100 - math.min(distToTarget, 100))
                    
                    -- Приоритет целям, которые смотрят на ворота
                    local targetLook = targetRoot.CFrame.LookVector
                    local toGoalDir = (GoalCFrame.Position - targetRoot.Position).Unit
                    local angleToGoal = math.deg(math.acos(math.clamp(targetLook:Dot(toGoalDir), -1, 1)))
                    
                    if angleToGoal < 45 then -- Если враг смотрит на ворота
                        score = score + 30
                    end
                    
                    -- Учитываем настройку приоритета
                    if CONFIG.PRIORITY == "attack" then
                        score = score * 1.5
                    end
                    
                    if score > bestScore then
                        bestScore = score
                        bestTarget = otherPlayer
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- Функция: Блокировка угла обзора врага (уменьшение FOV)
local function blockEnemyView(root, targetPlayer, ball)
    if tick() - moduleState.lastAttackTime < CONFIG.ATTACK_COOLDOWN then
        return false
    end
    
    if not targetPlayer or not targetPlayer.Character then
        return false
    end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end
    
    local distToTarget = (root.Position - targetRoot.Position).Magnitude
    
    -- Вычисляем позицию для блокировки угла обзора
    -- Становимся между врагом и центром ворот, но чуть ближе к врагу
    local goalCenter = GoalCFrame.Position
    local toGoalDir = (goalCenter - targetRoot.Position).Unit
    
    -- Вычисляем оптимальную позицию для блокировки
    local blockDistance = CONFIG.ATTACK_DISTANCE
    local blockPos = targetRoot.Position + toGoalDir * blockDistance
    
    -- Корректируем высоту
    blockPos = Vector3.new(blockPos.X, root.Position.Y, blockPos.Z)
    
    -- Двигаемся к позиции блокировки
    moveToTarget(root, blockPos)
    
    -- Поворачиваемся лицом к врагу
    rotateSmooth(root, targetRoot.Position, false, false, Vector3.new())
    
    -- Если враг с мячом и мы достаточно близко, можем блокировать удар
    local hasBall = false
    pcall(function()
        if ball:FindFirstChild("creator") and ball.creator.Value == targetPlayer then
            hasBall = true
        end
    end)
    
    if hasBall and distToTarget < CONFIG.ATTACK_DISTANCE * 1.5 then
        -- Смотрим прямо на врага, чтобы блокировать удар
        rotateSmooth(root, targetRoot.Position, false, false, Vector3.new())
        moduleState.lastAttackTime = tick()
        return true
    end
    
    return false
end

-- Функция очистки всех ресурсов
local function cleanup()
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    if moduleState.currentGyro then 
        pcall(function() moduleState.currentGyro:Destroy() end) 
        moduleState.currentGyro = nil 
    end
    
    clearAllVisuals()
    moduleState.isDiving = false
    moduleState.cachedPoints = nil
    moduleState.smoothCFrame = nil
end

-- Основной heartbeat цикл
local heartbeatConnection
local function startHeartbeat()
    heartbeatConnection = rs.Heartbeat:Connect(function()
        if not moduleState.enabled then 
            hideAllVisuals()
            return 
        end
        
        moduleState.frameCounter = moduleState.frameCounter + 1
        
        -- Проверяем остались ли мы вратарем
        if not checkIfGoalkeeper() then
            hideAllVisuals()
            if moduleState.currentBV then pcall(function() moduleState.currentBV:Destroy() end) moduleState.currentBV = nil end
            if moduleState.currentGyro then pcall(function() moduleState.currentGyro:Destroy() end) moduleState.currentGyro = nil end
            return
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then 
            hideAllVisuals()
            return 
        end
        
        local root = char.HumanoidRootPart
        local hum = char.Humanoid
        local ball = ws:FindFirstChild("ball")
        
        if not ball then 
            clearTrajAndEndpoint()
            if GoalCFrame then 
                moveToTarget(root, GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST) 
            end
            moduleState.isDiving = false
            moduleState.currentTargetType = nil
            moduleState.cachedPoints = nil
            return 
        end
        
        if not updateGoals() then 
            clearTrajAndEndpoint()
            return 
        end

        -- Отрисовка визуалов
        if CONFIG.SHOW_GOAL_CUBE and moduleState.visualObjects.GoalCube then
            drawCube(moduleState.visualObjects.GoalCube, GoalCFrame, Vector3.new(GoalWidth, 8, 2), Color3.fromRGB(255, 0, 0))
        end
        
        if CONFIG.SHOW_ZONE then 
            drawFlatZone() 
        end

        local hasWeld = ball:FindFirstChild("playerWeld")
        local owner = ball:FindFirstChild("creator") and ball.creator.Value
        local isMyBall = owner == player
        local oRoot = nil
        local enemyDistFromLine = math.huge
        local enemyLateral = 0
        local distToEnemy = math.huge
        local isAggro = false
        local blockEnemyViewActive = false
        local attackTargetPlayer = nil

        -- Поиск цели для атаки (блокировки угла обзора)
        if CONFIG.PRIORITY == "attack" or CONFIG.AUTO_ATTACK_IN_ZONE then
            attackTargetPlayer = findAttackTarget(root.Position, ball)
            
            -- Если найден враг в защитной зоне и включена автоатака
            if attackTargetPlayer and CONFIG.AUTO_ATTACK_IN_ZONE then
                local targetRoot = attackTargetPlayer.Character and attackTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot and isInDefenseZone(targetRoot.Position) then
                    -- Блокируем угол обзора врага
                    blockEnemyViewActive = blockEnemyView(root, attackTargetPlayer, ball)
                end
            end
        end

        if owner and owner ~= player and owner.Character then
            oRoot = owner.Character:FindFirstChild("HumanoidRootPart")
            if oRoot then
                local rel = oRoot.Position - GoalCFrame.Position
                enemyDistFromLine = rel:Dot(GoalForward)
                enemyLateral = rel:Dot(GoalCFrame.RightVector)
                distToEnemy = (root.Position - oRoot.Position).Magnitude
                isAggro = enemyDistFromLine < CONFIG.AGGRO_THRES and distToEnemy < CONFIG.MAX_CHASE_DIST and hasWeld
                
                -- Блокировка врага с мячом (старая логика)
                if isAggro and not blockEnemyViewActive then
                    blockEnemyViewActive = true
                    local viewBlockPos = (oRoot.Position + GoalCFrame.Position) / 2 + GoalForward * 1.2
                    viewBlockPos = Vector3.new(viewBlockPos.X, root.Position.Y, viewBlockPos.Z)
                    moveToTarget(root, viewBlockPos)
                end
            end
        end

        -- Если включен агрессивный режим и есть враг с мячом, преследуем его
        if CONFIG.AGGRESSIVE_MODE and owner and owner ~= player and oRoot and not blockEnemyViewActive then
            local targetPos = oRoot.Position + GoalForward * CONFIG.ATTACK_DISTANCE
            moveToTarget(root, targetPos)
            blockEnemyViewActive = true
        end

        local points, endpoint = nil, nil
        local threatLateral = 0
        local isShot = not hasWeld and owner ~= player
        local distEnd = math.huge
        local velMag = ball.Velocity.Magnitude
        local distBall = (root.Position - ball.Position).Magnitude
        local isThreat = false
        local timeToEndpoint = 999

        -- Обновление предикта при новом ударе
        local freshShot = false
        if velMag > 18 and moduleState.lastBallVelMag <= 18 then
            freshShot = true
            moduleState.cachedPoints = nil
            clearTrajAndEndpoint()
        end
        moduleState.lastBallVelMag = velMag

        if isShot and (moduleState.frameCounter % 2 == 0 or freshShot or not moduleState.cachedPoints) then
            moduleState.cachedPoints = predictTrajectory(ball)
        end
        points = moduleState.cachedPoints
        
        if points then
            endpoint = points[#points]
            distEnd = (root.Position - endpoint).Magnitude
            threatLateral = (endpoint - GoalCFrame.Position):Dot(GoalCFrame.RightVector)
            isThreat = (endpoint - GoalCFrame.Position):Dot(GoalForward) < 2.6 and math.abs(threatLateral) < GoalWidth / 2.0
            local distBallEnd = (ball.Position - endpoint).Magnitude
            timeToEndpoint = distBallEnd / math.max(1, velMag)
        else
            clearTrajAndEndpoint()
        end

        -- Отрисовка траектории
        if CONFIG.SHOW_TRAJECTORY and points and moduleState.visualObjects.trajLines then
            local cam = ws.CurrentCamera
            for i = 1, math.min(CONFIG.PRED_STEPS, #points - 1) do
                local p1 = cam:WorldToViewportPoint(points[i])
                local p2 = cam:WorldToViewportPoint(points[i + 1])
                local l = moduleState.visualObjects.trajLines[i]
                if l then
                    l.From = Vector2.new(p1.X, p1.Y)
                    l.To = Vector2.new(p2.X, p2.Y)
                    l.Visible = p1.Z > 0 and p2.Z > 0 and (points[i + 1] - root.Position).Magnitude < 70
                end
            end
            if CONFIG.SHOW_ENDPOINT and endpoint then
                drawEndpoint(endpoint)
            end
        else 
            clearTrajAndEndpoint() 
        end

        if CONFIG.SHOW_BALL_BOX and distBall < 70 and moduleState.visualObjects.BallBox then 
            local col = endpoint and (isThreat and Color3.fromRGB(255,0,0) or (endpoint.Y > CONFIG.JUMP_THRES and Color3.fromRGB(255,255,0)) or Color3.fromRGB(0,200,255)) or Color3.fromRGB(0,255,0)
            drawCube(moduleState.visualObjects.BallBox, CFrame.new(ball.Position), Vector3.new(3.5, 3.5, 3.5), col)
        elseif moduleState.visualObjects.BallBox then 
            drawCube(moduleState.visualObjects.BallBox, nil) 
        end

        local rightVec = GoalCFrame.RightVector
        local defenseBase = GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST
        local lateral = 0

        -- Только если не блокируем врага
        if not blockEnemyViewActive then
            if isMyBall then
                lateral = 0
            elseif oRoot and isAggro then
                local targetDist = math.max(2.0, enemyDistFromLine - 1.5)
                defenseBase = GoalCFrame.Position + GoalForward * targetDist
                lateral = enemyLateral * 1.02
            elseif not hasWeld then
                lateral = threatLateral * 0.82
                defenseBase = GoalCFrame.Position + GoalForward * math.min(6.0, distBall * 0.085)
            else
                local targetDist = math.max(CONFIG.STAND_DIST, math.min(8.0, enemyDistFromLine * 0.50))
                defenseBase = GoalCFrame.Position + GoalForward * targetDist
                local centerBias = math.max(0, 1 - (enemyDistFromLine / CONFIG.CENTER_BIAS_DIST))
                lateral = enemyLateral * centerBias
            end

            local threatWeight = isThreat and 0.99 or (distEnd < CONFIG.CLOSE_THREAT_DIST and 0.96 or 0.45)
            lateral = threatLateral * threatWeight + lateral * (1 - threatWeight)

            local bestPos = getSmartPosition(defenseBase, rightVec, lateral, GoalWidth, threatLateral, enemyLateral, isAggro)
            
            -- Улучшенная логика: Пытаемся перехватить мяч, а не бежать к endpoint
            if isShot and points and isThreat then
                local interceptPoint = findBestInterceptPoint(root.Position, ball.Position, ball.Velocity, points)
                if interceptPoint then
                    -- Если можем перехватить - идем к точке перехвата
                    local adjustedPos = interceptPoint + GoalForward * CONFIG.ADVANCE_DISTANCE
                    adjustedPos = Vector3.new(adjustedPos.X, root.Position.Y, adjustedPos.Z)
                    bestPos = adjustedPos
                elseif distEnd > 8 and timeToEndpoint > 1.0 then
                    -- Если мяч летит долго - выходим немного вперед
                    local advancePos = defenseBase + GoalForward * CONFIG.ADVANCE_DISTANCE * 2
                    bestPos = Vector3.new(advancePos.X, root.Position.Y, advancePos.Z)
                end
            end
            
            moveToTarget(root, bestPos)
        end

        -- Улучшенная ротация (смотрим на мяч, кроме случаев блокировки врага)
        if blockEnemyViewActive and attackTargetPlayer then
            local targetRoot = attackTargetPlayer.Character and attackTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                rotateSmooth(root, targetRoot.Position, isMyBall, moduleState.isDiving, ball.Velocity)
            else
                rotateSmooth(root, ball.Position, isMyBall, moduleState.isDiving, ball.Velocity)
            end
        else
            rotateSmooth(root, ball.Position, isMyBall, moduleState.isDiving, ball.Velocity)
        end

        -- ACTIONS
        if not isMyBall and not moduleState.isDiving then
            -- Перехват мяча вблизи
            if distBall < CONFIG.BALL_INTERCEPT_RANGE and velMag < CONFIG.DIVE_VEL_THRES * 0.82 then
                for _, hand in {char:FindFirstChild("RightHand"), char:FindFirstChild("LeftHand")} do
                    if hand and (hand.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
                        firetouchinterest(hand, ball, 0)
                        task.wait(0.025)
                        firetouchinterest(hand, ball, 1)
                    end
                end
            end

            -- Прыжок для высоких мячей
            local highThreat = isThreat and endpoint and endpoint.Y > CONFIG.HIGH_BALL_THRES and distEnd < 10.0 and velMag > CONFIG.JUMP_VEL_THRES
            if highThreat and tick() - moduleState.lastJumpTime > CONFIG.JUMP_COOLDOWN then
                forceJump(hum)
                moduleState.lastJumpTime = tick()
            end

            -- Дайв
            local emergency = false
            if isThreat then
                if distEnd < CONFIG.ENDPOINT_DIVE then
                    emergency = true
                elseif timeToEndpoint < 0.40 then
                    emergency = true
                elseif distBall < CONFIG.DIVE_DIST and velMag > CONFIG.DIVE_VEL_THRES then
                    emergency = true
                end
            end
            
            -- ИСПРАВЛЕННЫЙ ДАЙВ
            if emergency and tick() - moduleState.lastDiveTime > CONFIG.DIVE_COOLDOWN then
                moduleState.isDiving = true
                moduleState.lastDiveTime = tick()
                local diveTarget = endpoint or ball.Position
                
                -- Определяем направление дайва относительно ворот
                local relToGoal = diveTarget - GoalCFrame.Position
                local lateralDist = relToGoal:Dot(GoalCFrame.RightVector)
                local dir = lateralDist > 0 and "Right" or "Left"

                pcall(function()
                    ReplicatedStorage.Remotes.Action:FireServer(dir.."Dive", root.CFrame)
                end)

                -- ИСПРАВЛЕНИЕ: Направляем дайв по горизонтали к мячу, не учитывая высоту
                local diveDir = (diveTarget - root.Position)
                diveDir = Vector3.new(diveDir.X, 0, diveDir.Z) -- Игнорируем вертикальную составляющую
                if diveDir.Magnitude > 0 then
                    diveDir = diveDir.Unit
                else
                    diveDir = root.CFrame.LookVector -- Направление по умолчанию
                end
                
                local diveBV = Instance.new("BodyVelocity", root)
                diveBV.MaxForce = Vector3.new(5e6, 0, 5e6)
                diveBV.Velocity = diveDir * CONFIG.DIVE_SPEED
                game.Debris:AddItem(diveBV, 1.0)
                
                if ts then
                    ts:Create(diveBV, TweenInfo.new(0.5), {Velocity = diveBV.Velocity * 0.015}):Play()
                end

                local diveGyro = Instance.new("BodyGyro", root)
                diveGyro.P = 2200000
                diveGyro.MaxTorque = Vector3.new(0, 4.5e5, 0)
                diveGyro.CFrame = CFrame.lookAt(root.Position, diveTarget)
                game.Debris:AddItem(diveGyro, 1.0)

                local lowDive = (diveTarget.Y <= 3.8)
                pcall(function()
                    local animName = dir .. (lowDive and "LowDive" or "Dive")
                    local anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK[animName])
                    anim.Priority = Enum.AnimationPriority.Action4
                    anim:Play()
                end)

                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                task.delay(0.95, function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                    moduleState.isDiving = false
                end)
            end
        else
            if isMyBall then 
                moduleState.isDiving = false 
            end
        end

        if not isShot or not points then
            clearTrajAndEndpoint()
        end
    end)
end

-- Модуль GK Helper
local GKHelperModule = {}

function GKHelperModule.Init(UI, coreParam, notifyFunc)
    local core = coreParam
    local notify = notifyFunc
    
    -- Создаем секцию в UI
    if UI.Sections.AutoGoalKeeper then
        UI.Sections.AutoGoalKeeper:Header({ Name = "Auto GoalKeeper v46" })
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Включение/выключение
        UI.Sections.AutoGoalKeeper:Toggle({ 
            Name = "Enabled", 
            Default = false, 
            Callback = function(v) 
                moduleState.enabled = v
                if v then
                    createVisuals()
                    startHeartbeat()
                    notify("GK Helper", "Включен", true)
                else
                    if heartbeatConnection then
                        heartbeatConnection:Disconnect()
                        heartbeatConnection = nil
                    end
                    cleanup()
                    notify("GK Helper", "Выключен", true)
                end
            end
        })
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки движения
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Speed",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.SPEED = v end
        })
        
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Stand Distance",
            Minimum = 1.0,
            Maximum = 5.0,
            Default = CONFIG.STAND_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.STAND_DIST = v end
        })
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки дайва
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Distance",
            Minimum = 5,
            Maximum = 20,
            Default = CONFIG.DIVE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_DIST = v end
        })
        
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Speed",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.DIVE_SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_SPEED = v end
        })
        
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Velocity Threshold",
            Minimum = 10,
            Maximum = 40,
            Default = CONFIG.DIVE_VEL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_VEL_THRES = v end
        })
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки зоны
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Distance",
            Minimum = 30,
            Maximum = 100,
            Default = CONFIG.ZONE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_DIST = v end
        })
        
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Width Multiplier",
            Minimum = 1.0,
            Maximum = 3.0,
            Default = CONFIG.ZONE_WIDTH,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_WIDTH = v end
        })
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки приоритета
        UI.Sections.AutoGoalKeeper:Dropdown({
            Name = "Priority",
            Default = CONFIG.PRIORITY,
            Options = {"defense", "attack"},
            Callback = function(v) CONFIG.PRIORITY = v end
        })
        
        UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Auto Attack in Zone",
            Default = CONFIG.AUTO_ATTACK_IN_ZONE,
            Callback = function(v) CONFIG.AUTO_ATTACK_IN_ZONE = v end
        })
        
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Distance",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.ATTACK_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ATTACK_DISTANCE = v end
        })
        
        UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Aggressive Mode",
            Default = CONFIG.AGGRESSIVE_MODE,
            Callback = function(v) CONFIG.AGGRESSIVE_MODE = v end
        })
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Визуальные настройки
        UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Trajectory",
            Default = CONFIG.SHOW_TRAJECTORY,
            Callback = function(v) 
                CONFIG.SHOW_TRAJECTORY = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        })
        
        UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Endpoint",
            Default = CONFIG.SHOW_ENDPOINT,
            Callback = function(v) 
                CONFIG.SHOW_ENDPOINT = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        })
        
        UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Goal Cube",
            Default = CONFIG.SHOW_GOAL_CUBE,
            Callback = function(v) 
                CONFIG.SHOW_GOAL_CUBE = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        })
        
        UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Zone",
            Default = CONFIG.SHOW_ZONE,
            Callback = function(v) 
                CONFIG.SHOW_ZONE = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        })
        
        UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Ball Box",
            Default = CONFIG.SHOW_BALL_BOX,
            Callback = function(v) 
                CONFIG.SHOW_BALL_BOX = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        })
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Расширенные настройки
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Ball Intercept Range",
            Minimum = 2.0,
            Maximum = 8.0,
            Default = CONFIG.BALL_INTERCEPT_RANGE,
            Precision = 1,
            Callback = function(v) CONFIG.BALL_INTERCEPT_RANGE = v end
        })
        
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Advance Distance",
            Minimum = 1.0,
            Maximum = 6.0,
            Default = CONFIG.ADVANCE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ADVANCE_DISTANCE = v end
        })
        
        UI.Sections.AutoGoalKeeper:Slider({
            Name = "Rotation Smoothness",
            Minimum = 0.5,
            Maximum = 0.95,
            Default = CONFIG.ROT_SMOOTH,
            Precision = 2,
            Callback = function(v) CONFIG.ROT_SMOOTH = v end
        })
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Информация
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "Информация",
            Body = "GK Helper v46 Advanced Defense\n• Приоритет: defense - защита ворот, attack - атака врагов\n• Auto Attack in Zone: атаковать врагов в защитной зоне\n• Aggressive Mode: постоянно преследовать врага с мячом\n• Исправлен баг с дайвом (не отправляет в космос)\n• Правильная очистка визуалов при смене роли"
        })
    end
    
    notify("GK Helper", "Модуль загружен (версия v46)", true)
end

function GKHelperModule:Destroy()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    cleanup()
    moduleState.enabled = false
end

return GKHelperModule