local ChinaHat = {}

function ChinaHat.Init(UI, Core, notify)
    local Players = Core.Services.Players
    local RunService = Core.Services.RunService
    local Workspace = Core.Services.Workspace
    local UserInputService = Core.Services.UserInputService
    local camera = Workspace.CurrentCamera

    local LocalPlayer = Core.PlayerData.LocalPlayer
    local localCharacter = LocalPlayer.Character
    local localHumanoid = localCharacter and localCharacter:FindFirstChild("Humanoid")

    local State = {
        ChinaHat = {
            HatActive = { Value = false, Default = false },
            HatScale = { Value = 0.85, Default = 0.85 },
            HatParts = { Value = 50, Default = 50 },
            HatGradientSpeed = { Value = 4, Default = 4 },
            HatGradient = { Value = true, Default = true },
            HatColor = { Value = Color3.fromRGB(0, 0, 255), Default = Color3.fromRGB(0, 0, 255) },
            HatYOffset = { Value = 1.6, Default = 1.6 },
            OutlineCircle = { Value = false, Default = false },
            Filled = { Value = false, Default = false }, -- Новая опция для заполненного ChinaHat
            FillTransparency = { Value = 0.3, Default = 0.3 } -- Прозрачность заполнения
        },
        Circle = {
            CircleActive = { Value = false, Default = false },
            CircleRadius = { Value = 1.7, Default = 1.7 },
            CircleParts = { Value = 30, Default = 30 },
            CircleGradientSpeed = { Value = 4, Default = 4 },
            CircleGradient = { Value = true, Default = true },
            CircleColor = { Value = Color3.fromRGB(0, 0, 255), Default = Color3.fromRGB(0, 0, 255) },
            JumpAnimate = { Value = false, Default = false },
            CircleYOffset = { Value = -3, Default = -3 },
            StickToGround = { Value = true, Default = true } -- Автоматическое прилипание к земле
        },
        Nimb = {
            NimbActive = { Value = false, Default = false },
            NimbRadius = { Value = 1.7, Default = 1.7 },
            NimbParts = { Value = 30, Default = 30 },
            NimbGradientSpeed = { Value = 4, Default = 4 },
            NimbGradient = { Value = true, Default = true },
            NimbColor = { Value = Color3.fromRGB(0, 0, 255), Default = Color3.fromRGB(0, 0, 255) },
            NimbYOffset = { Value = 2.7, Default = 2.7 }
        }
    }

    local hatLines = {}
    local hatCircleQuads = {}
    local hatFilledTriangles = {} -- Треугольники для заполненного ChinaHat
    local circleQuads = {}
    local nimbQuads = {}
    local jumpAnimationActive = false
    local renderConnection
    local humanoidConnection
    local uiElements = {}
    
    -- Переменные для стабильного позиционирования
    local lastGroundHeight = 0
    local groundSmoothness = 0.9 -- Коэффициент сглаживания (0-1)
    local isShiftLockEnabled = false
    local shiftLockConnection

    local function destroyParts(parts)
        for _, part in ipairs(parts) do
            if part and part.Destroy then
                part:Destroy()
            end
        end
        table.clear(parts)
    end

    local function interpolateColor(color1, color2, factor)
        return Color3.new(
            color1.R + (color2.R - color1.R) * factor,
            color1.G + (color2.G - color1.G) * factor,
            color1.B + (color2.B - color1.B) * factor
        )
    end

    -- Улучшенная функция определения высоты земли со сглаживанием
    local function getSmoothedGroundHeight(rootPart)
        if not rootPart then return 0 end
        
        local rayOrigin = rootPart.Position
        local rayDirection = Vector3.new(0, -100, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {localCharacter}
        
        local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        
        local currentHeight = 0
        if raycastResult then
            currentHeight = raycastResult.Position.Y
        else
            -- Если луч не попал ни во что, используем текущую высоту персонажа - 3
            currentHeight = rootPart.Position.Y - 3
        end
        
        -- Сглаживание высоты для предотвращения рывков
        lastGroundHeight = lastGroundHeight * groundSmoothness + currentHeight * (1 - groundSmoothness)
        
        return lastGroundHeight
    end

    -- Функция для обновления состояния ShiftLock
    local function updateShiftLockState()
        if camera and localCharacter and localCharacter:FindFirstChild("HumanoidRootPart") then
            local characterPos = localCharacter.HumanoidRootPart.Position
            local cameraPos = camera.CFrame.Position
            
            -- Вычисляем расстояние между камерой и персонажем
            local distance = (cameraPos - characterPos).Magnitude
            
            -- Также проверяем угол камеры для более точного определения
            local cameraCFrame = camera.CFrame
            local cameraLookVector = cameraCFrame.LookVector
            local toCharacter = (characterPos - cameraPos).Unit
            
            -- Если камера смотрит на персонажа с расстояния > 8, считаем что включен ShiftLock
            local dotProduct = cameraLookVector:Dot(toCharacter)
            isShiftLockEnabled = distance > 8 and dotProduct > 0.5
        else
            isShiftLockEnabled = false
        end
    end

    local function createHat()
        if not localCharacter or not localCharacter:FindFirstChild("Head") then return end
        destroyParts(hatLines)
        destroyParts(hatCircleQuads)
        destroyParts(hatFilledTriangles)
        
        local head = localCharacter.Head
        
        -- Создаем линии для контура
        for i = 1, State.ChinaHat.HatParts.Value do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = 0.06
            line.Transparency = 0.5
            line.Color = State.ChinaHat.HatGradient.Value and
                interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / State.ChinaHat.HatParts.Value) or
                State.ChinaHat.HatColor.Value
            table.insert(hatLines, line)
        end
        
        -- Создаем треугольники для заполнения, если включена опция
        if State.ChinaHat.Filled.Value then
            for i = 1, State.ChinaHat.HatParts.Value do
                local triangle = Drawing.new("Triangle")
                triangle.Visible = false
                triangle.Transparency = State.ChinaHat.FillTransparency.Value
                triangle.Color = State.ChinaHat.HatGradient.Value and
                    interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / State.ChinaHat.HatParts.Value) or
                    State.ChinaHat.HatColor.Value
                table.insert(hatFilledTriangles, triangle)
            end
        end
        
        -- Создаем контур круга, если включена опция
        if State.ChinaHat.OutlineCircle.Value then
            for i = 1, State.ChinaHat.HatParts.Value do
                local quad = Drawing.new("Quad")
                quad.Visible = false
                quad.Thickness = 1
                quad.Filled = false
                quad.Color = State.ChinaHat.HatGradient.Value and
                    interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / State.ChinaHat.HatParts.Value) or
                    State.ChinaHat.HatColor.Value
                table.insert(hatCircleQuads, quad)
            end
        end
    end

    local function createCircle()
        if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then return end
        destroyParts(circleQuads)
        for i = 1, State.Circle.CircleParts.Value do
            local quad = Drawing.new("Quad")
            quad.Visible = false
            quad.Thickness = 1
            quad.Filled = false
            quad.Color = State.Circle.CircleGradient.Value and
                interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / State.Circle.CircleParts.Value) or
                State.Circle.CircleColor.Value
            table.insert(circleQuads, quad)
        end
    end

    local function createNimb()
        if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then return end
        destroyParts(nimbQuads)
        for i = 1, State.Nimb.NimbParts.Value do
            local quad = Drawing.new("Quad")
            quad.Visible = false
            quad.Thickness = 1
            quad.Filled = false
            quad.Color = State.Nimb.NimbGradient.Value and
                interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / State.Nimb.NimbParts.Value) or
                State.Nimb.NimbColor.Value
            table.insert(nimbQuads, quad)
        end
    end

    local function updateHat()
        if not State.ChinaHat.HatActive.Value or not localCharacter or not localCharacter:FindFirstChild("Head") then
            for _, line in ipairs(hatLines) do line.Visible = false end
            for _, quad in ipairs(hatCircleQuads) do quad.Visible = false end
            for _, tri in ipairs(hatFilledTriangles) do tri.Visible = false end
            return
        end
        
        local head = localCharacter.Head
        
        -- Обновляем состояние ShiftLock
        updateShiftLockState()
        
        -- Автоматическая корректировка высоты для ChinaHat
        local yOffset = State.ChinaHat.HatYOffset.Value
        if isShiftLockEnabled then
            -- При ShiftLock добавляем дополнительное смещение
            yOffset = yOffset + 0.3
        end
        
        local baseY = head.Position.Y + yOffset
        local t = tick()
        local hatHeight = 2.15 * State.ChinaHat.HatScale.Value
        local hatRadius = 1.95 * State.ChinaHat.HatScale.Value
        
        -- Получаем базовую позицию и позицию вершины
        local basePosition = Vector3.new(head.Position.X, baseY, head.Position.Z)
        local topCenter = Vector3.new(head.Position.X, baseY - hatHeight, head.Position.Z)
        
        local screenBase, onScreenBase = camera:WorldToViewportPoint(basePosition)
        local screenTop, onScreenTop = camera:WorldToViewportPoint(topCenter)
        
        if not (onScreenBase and onScreenTop and screenBase.Z > 0 and screenTop.Z > 0) then
            for _, line in ipairs(hatLines) do line.Visible = false end
            for _, quad in ipairs(hatCircleQuads) do quad.Visible = false end
            for _, tri in ipairs(hatFilledTriangles) do tri.Visible = false end
            return
        end

        -- Обновляем линии и/или треугольники
        for i = 1, State.ChinaHat.HatParts.Value do
            local angle = (i / State.ChinaHat.HatParts.Value) * 2 * math.pi
            local x = math.cos(angle) * hatRadius
            local z = math.sin(angle) * hatRadius
            
            local rimPoint = Vector3.new(head.Position.X + x, baseY, head.Position.Z + z)
            local screenRim, onScreenRim = camera:WorldToViewportPoint(rimPoint)
            
            if onScreenRim and screenRim.Z > 0 then
                local color
                if State.ChinaHat.HatGradient.Value then
                    local factor = (math.sin(t * State.ChinaHat.HatGradientSpeed.Value + (i / State.ChinaHat.HatParts.Value) * 2 * math.pi) + 1) / 2
                    color = interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, factor)
                else
                    color = State.ChinaHat.HatColor.Value
                end
                
                -- Обновляем линию
                if hatLines[i] then
                    hatLines[i].From = Vector2.new(screenBase.X, screenBase.Y)
                    hatLines[i].To = Vector2.new(screenRim.X, screenRim.Y)
                    hatLines[i].Color = color
                    hatLines[i].Visible = true
                end
                
                -- Обновляем треугольник для заполнения
                if State.ChinaHat.Filled.Value and hatFilledTriangles[i] then
                    local nextAngle = ((i % State.ChinaHat.HatParts.Value + 1) / State.ChinaHat.HatParts.Value) * 2 * math.pi
                    local nextX = math.cos(nextAngle) * hatRadius
                    local nextZ = math.sin(nextAngle) * hatRadius
                    
                    local nextRimPoint = Vector3.new(head.Position.X + nextX, baseY, head.Position.Z + nextZ)
                    local screenNextRim, onScreenNextRim = camera:WorldToViewportPoint(nextRimPoint)
                    
                    if onScreenNextRim and screenNextRim.Z > 0 then
                        hatFilledTriangles[i].PointA = Vector2.new(screenBase.X, screenBase.Y)
                        hatFilledTriangles[i].PointB = Vector2.new(screenRim.X, screenRim.Y)
                        hatFilledTriangles[i].PointC = Vector2.new(screenNextRim.X, screenNextRim.Y)
                        hatFilledTriangles[i].Color = color
                        hatFilledTriangles[i].Transparency = State.ChinaHat.FillTransparency.Value
                        hatFilledTriangles[i].Visible = true
                    else
                        hatFilledTriangles[i].Visible = false
                    end
                end
            else
                if hatLines[i] then hatLines[i].Visible = false end
                if hatFilledTriangles[i] then hatFilledTriangles[i].Visible = false end
            end
        end

        -- Обновляем контур круга, если включен
        if State.ChinaHat.OutlineCircle.Value and #hatCircleQuads > 0 then
            local rimCenter = Vector3.new(head.Position.X, baseY - hatHeight, head.Position.Z)
            local screenRimCenter, onScreenRimCenter = camera:WorldToViewportPoint(rimCenter)
            
            if onScreenRimCenter and screenRimCenter.Z > 0 then
                local circleRadius = 2.0 * State.ChinaHat.HatScale.Value
                for i, quad in ipairs(hatCircleQuads) do
                    local angle1 = ((i - 1) / #hatCircleQuads) * 2 * math.pi
                    local angle2 = (i / #hatCircleQuads) * 2 * math.pi
                    local point1 = rimCenter + Vector3.new(math.cos(angle1) * circleRadius, 0, math.sin(angle1) * circleRadius)
                    local point2 = rimCenter + Vector3.new(math.cos(angle2) * circleRadius, 0, math.sin(angle2) * circleRadius)
                    local screenPoint1, onScreen1 = camera:WorldToViewportPoint(point1)
                    local screenPoint2, onScreen2 = camera:WorldToViewportPoint(point2)

                    if onScreen1 and onScreen2 and screenPoint1.Z > 0 and screenPoint2.Z > 0 then
                        quad.PointA = Vector2.new(screenPoint1.X, screenPoint1.Y)
                        quad.PointB = Vector2.new(screenPoint2.X, screenPoint2.Y)
                        quad.PointC = Vector2.new(screenPoint2.X, screenPoint2.Y)
                        quad.PointD = Vector2.new(screenPoint1.X, screenPoint1.Y)
                        quad.Visible = true
                        if State.ChinaHat.HatGradient.Value then
                            local factor = (math.sin(t * State.ChinaHat.HatGradientSpeed.Value + (i / #hatCircleQuads) * 2 * math.pi) + 1) / 2
                            quad.Color = interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, factor)
                        else
                            quad.Color = State.ChinaHat.HatColor.Value
                        end
                    else
                        quad.Visible = false
                    end
                end
            else
                for _, quad in ipairs(hatCircleQuads) do
                    quad.Visible = false
                end
            end
        end
    end

    local function updateCircle()
        if not State.Circle.CircleActive.Value or not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then
            for _, quad in ipairs(circleQuads) do
                quad.Visible = false
            end
            return
        end
        
        local rootPart = localCharacter.HumanoidRootPart
        
        -- Обновляем состояние ShiftLock
        updateShiftLockState()
        
        -- Автоматическая корректировка высоты для Circle
        local yOffset
        
        if State.Circle.StickToGround.Value then
            -- Прилипаем к земле с использованием сглаженной высоты
            yOffset = getSmoothedGroundHeight(rootPart) + 0.05 -- Немного выше земли
        else
            -- Используем обычное смещение
            if isShiftLockEnabled then
                -- При ShiftLock используем позицию земли
                yOffset = getSmoothedGroundHeight(rootPart) + 0.05
            else
                -- В обычном режиме используем смещение относительно корневой части
                yOffset = rootPart.Position.Y + State.Circle.CircleYOffset.Value
            end
        end
        
        local t = tick()
        local center = Vector3.new(rootPart.Position.X, yOffset, rootPart.Position.Z)
        local screenCenter, onScreenCenter = camera:WorldToViewportPoint(center)
        
        if not (onScreenCenter and screenCenter.Z > 0) then
            for _, quad in ipairs(circleQuads) do
                quad.Visible = false
            end
            return
        end

        local circleRadius = State.Circle.CircleRadius.Value
        local partsCount = #circleQuads
        
        for i, quad in ipairs(circleQuads) do
            local angle1 = ((i - 1) / partsCount) * 2 * math.pi
            local angle2 = (i / partsCount) * 2 * math.pi
            local point1 = center + Vector3.new(math.cos(angle1) * circleRadius, 0, math.sin(angle1) * circleRadius)
            local point2 = center + Vector3.new(math.cos(angle2) * circleRadius, 0, math.sin(angle2) * circleRadius)
            local screenPoint1, onScreen1 = camera:WorldToViewportPoint(point1)
            local screenPoint2, onScreen2 = camera:WorldToViewportPoint(point2)

            if onScreen1 and onScreen2 and screenPoint1.Z > 0 and screenPoint2.Z > 0 then
                quad.PointA = Vector2.new(screenPoint1.X, screenPoint1.Y)
                quad.PointB = Vector2.new(screenPoint2.X, screenPoint2.Y)
                quad.PointC = Vector2.new(screenPoint2.X, screenPoint2.Y)
                quad.PointD = Vector2.new(screenPoint1.X, screenPoint1.Y)
                quad.Visible = true
                if State.Circle.CircleGradient.Value then
                    local factor = (math.sin(t * State.Circle.CircleGradientSpeed.Value + (i / partsCount) * 2 * math.pi) + 1) / 2
                    quad.Color = interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, factor)
                else
                    quad.Color = State.Circle.CircleColor.Value
                end
            else
                quad.Visible = false
            end
        end
    end

    local function updateNimb()
        if not State.Nimb.NimbActive.Value or not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then
            for _, quad in ipairs(nimbQuads) do
                quad.Visible = false
            end
            return
        end
        
        local rootPart = localCharacter.HumanoidRootPart
        
        -- Обновляем состояние ShiftLock
        updateShiftLockState()
        
        -- Автоматическая корректировка высоты для Nimb
        local yOffset
        
        if isShiftLockEnabled then
            -- При ShiftLock располагаем Nimb над головой
            if localCharacter:FindFirstChild("Head") then
                local head = localCharacter.Head
                yOffset = head.Position.Y + 0.5 -- Над головой
            else
                yOffset = rootPart.Position.Y + State.Nimb.NimbYOffset.Value + 2.0
            end
        else
            -- В обычном режиме используем смещение относительно корневой части
            yOffset = rootPart.Position.Y + State.Nimb.NimbYOffset.Value
        end
        
        local t = tick()
        local center = Vector3.new(rootPart.Position.X, yOffset, rootPart.Position.Z)
        local screenCenter, onScreenCenter = camera:WorldToViewportPoint(center)
        
        if not (onScreenCenter and screenCenter.Z > 0) then
            for _, quad in ipairs(nimbQuads) do
                quad.Visible = false
            end
            return
        end

        local nimbRadius = State.Nimb.NimbRadius.Value
        local partsCount = #nimbQuads
        
        for i, quad in ipairs(nimbQuads) do
            local angle1 = ((i - 1) / partsCount) * 2 * math.pi
            local angle2 = (i / partsCount) * 2 * math.pi
            local point1 = center + Vector3.new(math.cos(angle1) * nimbRadius, 0, math.sin(angle1) * nimbRadius)
            local point2 = center + Vector3.new(math.cos(angle2) * nimbRadius, 0, math.sin(angle2) * nimbRadius)
            local screenPoint1, onScreen1 = camera:WorldToViewportPoint(point1)
            local screenPoint2, onScreen2 = camera:WorldToViewportPoint(point2)

            if onScreen1 and onScreen2 and screenPoint1.Z > 0 and screenPoint2.Z > 0 then
                quad.PointA = Vector2.new(screenPoint1.X, screenPoint1.Y)
                quad.PointB = Vector2.new(screenPoint2.X, screenPoint2.Y)
                quad.PointC = Vector2.new(screenPoint2.X, screenPoint2.Y)
                quad.PointD = Vector2.new(screenPoint1.X, screenPoint1.Y)
                quad.Visible = true
                if State.Nimb.NimbGradient.Value then
                    local factor = (math.sin(t * State.Nimb.NimbGradientSpeed.Value + (i / partsCount) * 2 * math.pi) + 1) / 2
                    quad.Color = interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, factor)
                else
                    quad.Color = State.Nimb.NimbColor.Value
                end
            else
                quad.Visible = false
            end
        end
    end

    local function animateJump()
        if not State.Circle.JumpAnimate.Value or #circleQuads == 0 or jumpAnimationActive then return end
        jumpAnimationActive = true
        local t = 0
        local duration = 0.55
        local initialRadius = State.Circle.CircleRadius.Value
        local maxRadius = initialRadius * 1.6
        while t < duration do
            local dt = RunService.RenderStepped:Wait()
            t = t + dt
            local factor = t / duration
            State.Circle.CircleRadius.Value = initialRadius + (maxRadius - initialRadius) * math.sin(factor * math.pi)
            updateCircle()
        end
        State.Circle.CircleRadius.Value = initialRadius
        jumpAnimationActive = false
    end

    local function toggleHat(value)
        State.ChinaHat.HatActive.Value = value
        if value then
            createHat()
            notify("ChinaHat", "Hat Enabled", true)
        else
            destroyParts(hatLines)
            destroyParts(hatCircleQuads)
            destroyParts(hatFilledTriangles)
            notify("ChinaHat", "Hat Disabled", true)
        end
    end

    local function toggleCircle(value)
        State.Circle.CircleActive.Value = value
        if value then
            createCircle()
            notify("Circle", "Circle Enabled", true)
        else
            destroyParts(circleQuads)
            notify("Circle", "Circle Disabled", true)
        end
    end

    local function toggleNimb(value)
        State.Nimb.NimbActive.Value = value
        if value then
            createNimb()
            notify("Nimb", "Nimb Enabled", true)
        else
            destroyParts(nimbQuads)
            notify("Nimb", "Nimb Disabled", true)
        end
    end

    local function onStateChanged(oldState, newState)
        if State.Circle.JumpAnimate.Value and newState == Enum.HumanoidStateType.Jumping and not jumpAnimationActive then
            animateJump()
        end
    end

    local function connectHumanoid(character)
        if humanoidConnection then
            humanoidConnection:Disconnect()
        end
        localCharacter = character
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            localHumanoid = humanoid
            humanoidConnection = humanoid.StateChanged:Connect(onStateChanged)
        end
        -- Сбрасываем сглаженную высоту при смене персонажа
        lastGroundHeight = 0
        
        -- Воссоздаем элементы, если они активны
        if State.ChinaHat.HatActive.Value then
            createHat()
        end
        if State.Circle.CircleActive.Value then
            createCircle()
        end
        if State.Nimb.NimbActive.Value then
            createNimb()
        end
    end

    -- Функция для обработки изменения камеры
    local function onCameraChanged()
        updateShiftLockState()
    end

    renderConnection = RunService.RenderStepped:Connect(function()
        if localCharacter then
            updateHat()
            updateCircle()
            updateNimb()
        else
            for _, line in ipairs(hatLines) do
                line.Visible = false
            end
            for _, quad in ipairs(hatCircleQuads) do
                quad.Visible = false
            end
            for _, tri in ipairs(hatFilledTriangles) do
                tri.Visible = false
            end
            for _, quad in ipairs(circleQuads) do
                quad.Visible = false
            end
            for _, quad in ipairs(nimbQuads) do
                quad.Visible = false
            end
        end
    end)

    -- Подключаем отслеживание изменений камеры
    shiftLockConnection = camera:GetPropertyChangedSignal("CFrame"):Connect(onCameraChanged)

    LocalPlayer.CharacterAdded:Connect(connectHumanoid)
    if localCharacter then
        connectHumanoid(localCharacter)
    end

    if UI.Tabs and UI.Tabs.Visuals then
        local chinaHatSection = UI.Sections.ChinaHat or UI.Tabs.Visuals:Section({ Name = "ChinaHat", Side = "Left" })
        UI.Sections.ChinaHat = chinaHatSection
        chinaHatSection:Header({ Name = "China Hat" })
        chinaHatSection:SubLabel({ Text = "Displays a hat above the player head" })
        uiElements.HatEnabled = chinaHatSection:Toggle({
            Name = "Enabled",
            Default = State.ChinaHat.HatActive.Default,
            Callback = function(value)
                toggleHat(value)
            end,
        }, 'HatEnabled')
        chinaHatSection:Divider()
        uiElements.HatScale = chinaHatSection:Slider({
            Name = "Scale",
            Minimum = 0.5,
            Maximum = 2.0,
            Default = State.ChinaHat.HatScale.Default,
            Precision = 2,
            Callback = function(value)
                State.ChinaHat.HatScale.Value = value
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end
                notify("ChinaHat", "Hat Scale set to: " .. value, false)
            end,
        }, 'HatScale')
        uiElements.HatParts = chinaHatSection:Slider({
            Name = "Parts",
            Minimum = 20,
            Maximum = 150,
            Default = State.ChinaHat.HatParts.Value,
            Precision = 0,
            Callback = function(value)
                State.ChinaHat.HatParts.Value = value
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end
                notify("ChinaHat", "Hat Parts set to: " .. value, false)
            end,
        }, 'HatParts')
        chinaHatSection:Divider()
        uiElements.HatFilled = chinaHatSection:Toggle({
            Name = "Filled",
            Default = State.ChinaHat.Filled.Default,
            Callback = function(value)
                State.ChinaHat.Filled.Value = value
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end
                notify("ChinaHat", "Filled: " .. (value and "Enabled" or "Disabled"), true)
            end,
        }, 'HatFilled')
        uiElements.FillTransparency = chinaHatSection:Slider({
            Name = "Fill Transparency",
            Minimum = 0,
            Maximum = 1,
            Default = State.ChinaHat.FillTransparency.Default,
            Precision = 2,
            Callback = function(value)
                State.ChinaHat.FillTransparency.Value = value
                if State.ChinaHat.HatActive.Value and State.ChinaHat.Filled.Value then
                    createHat()
                end
                notify("ChinaHat", "Fill Transparency set to: " .. value, false)
            end,
        }, 'FillTransparency')
        chinaHatSection:Divider()
        uiElements.HatGradientSpeed = chinaHatSection:Slider({
            Name = "Gradient Speed",
            Minimum = 1,
            Maximum = 10,
            Default = State.ChinaHat.HatGradientSpeed.Default,
            Precision = 1,
            Callback = function(value)
                State.ChinaHat.HatGradientSpeed.Value = value
                notify("ChinaHat", "Hat Gradient Speed set to: " .. value, false)
            end,
        }, 'HatGradientSpeed')
        uiElements.HatGradient = chinaHatSection:Toggle({
            Name = "Gradient",
            Default = State.ChinaHat.HatGradient.Default,
            Callback = function(value)
                State.ChinaHat.HatGradient.Value = value
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end
                notify("ChinaHat", "Hat Gradient: " .. (value and "Enabled" or "Disabled"), true)
            end,
        }, 'HatGradient')
        uiElements.HatColor = chinaHatSection:Colorpicker({
            Name = "Color",
            Default = State.ChinaHat.HatColor.Default,
            Callback = function(value)
                State.ChinaHat.HatColor.Value = value
                if State.ChinaHat.HatActive.Value and not State.ChinaHat.HatGradient.Value then
                    createHat()
                end
                notify("ChinaHat", "Hat Color updated", false)
            end,
        }, 'HatColor')
        chinaHatSection:Divider()
        uiElements.HatYOffset = chinaHatSection:Slider({
            Name = "Y Offset",
            Minimum = -5,
            Maximum = 5,
            Default = State.ChinaHat.HatYOffset.Default,
            Precision = 2,
            Callback = function(value)
                State.ChinaHat.HatYOffset.Value = value
                notify("ChinaHat", "Hat Y Offset set to: " .. value, false)
            end,
        }, 'HatYOffset')
        uiElements.OutlineCircle = chinaHatSection:Toggle({
            Name = "Outline Circle",
            Default = State.ChinaHat.OutlineCircle.Default,
            Callback = function(value)
                State.ChinaHat.OutlineCircle.Value = value
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end
                notify("ChinaHat", "Outline Circle: " .. (value and "Enabled" or "Disabled"), true)
            end,
        }, 'OutlineCircle')

        local circleSection = UI.Sections.Circle or UI.Tabs.Visuals:Section({ Name = "Circle", Side = "Left" })
        UI.Sections.Circle = circleSection
        circleSection:Header({ Name = "Circle" })
        circleSection:SubLabel({ Text = "Displays a circle at the player feet (Auto-adjusts for ShiftLock)" })
        uiElements.CircleEnabled = circleSection:Toggle({
            Name = "Enabled",
            Default = State.Circle.CircleActive.Default,
            Callback = function(value)
                toggleCircle(value)
            end,
        }, 'CircleEnabled')
        circleSection:Divider()
        uiElements.StickToGround = circleSection:Toggle({
            Name = "Stick to Ground",
            Default = State.Circle.StickToGround.Default,
            Callback = function(value)
                State.Circle.StickToGround.Value = value
                notify("Circle", "Stick to Ground: " .. (value and "Enabled" or "Disabled"), true)
            end,
        }, 'StickToGround')
        uiElements.CircleRadius = circleSection:Slider({
            Name = "Radius",
            Minimum = 1.0,
            Maximum = 3.0,
            Default = State.Circle.CircleRadius.Default,
            Precision = 1,
            Callback = function(value)
                State.Circle.CircleRadius.Value = value
                if State.Circle.CircleActive.Value then
                    createCircle()
                end
                notify("Circle", "Circle Radius set to: " .. value, false)
            end,
        }, 'CircleRadius')
        uiElements.CircleParts = circleSection:Slider({
            Name = "Parts",
            Minimum = 20,
            Maximum = 100,
            Default = State.Circle.CircleParts.Default,
            Precision = 0,
            Callback = function(value)
                State.Circle.CircleParts.Value = value
                if State.Circle.CircleActive.Value then
                    createCircle()
                end
                notify("Circle", "Circle Parts set to: " .. value, false)
            end,
        }, 'CircleParts')
        circleSection:Divider()
        uiElements.CircleGradientSpeed = circleSection:Slider({
            Name = "Gradient Speed",
            Minimum = 1,
            Maximum = 10,
            Default = State.Circle.CircleGradientSpeed.Default,
            Precision = 1,
            Callback = function(value)
                State.Circle.CircleGradientSpeed.Value = value
                notify("Circle", "Circle Gradient Speed set to: " .. value, false)
            end,
        }, 'CircleGradientSpeed')
        uiElements.CircleGradient = circleSection:Toggle({
            Name = "Gradient",
            Default = State.Circle.CircleGradient.Default,
            Callback = function(value)
                State.Circle.CircleGradient.Value = value
                if State.Circle.CircleActive.Value then
                    createCircle()
                end
                notify("Circle", "Circle Gradient: " .. (value and "Enabled" or "Disabled"), true)
            end,
        }, 'CircleGradient')
        uiElements.CircleColor = circleSection:Colorpicker({
            Name = "Color",
            Default = State.Circle.CircleColor.Default,
            Callback = function(value)
                State.Circle.CircleColor.Value = value
                if State.Circle.CircleActive.Value and not State.Circle.CircleGradient.Value then
                    createCircle()
                end
                notify("Circle", "Circle Color updated", false)
            end,
        }, 'CircleColor')
        circleSection:Divider()
        uiElements.JumpAnimate = circleSection:Toggle({
            Name = "Jump Animate",
            Default = State.Circle.JumpAnimate.Default,
            Callback = function(value)
                State.Circle.JumpAnimate.Value = value
                notify("Circle", "Jump Animation: " .. (value and "Enabled" or "Disabled"), true)
            end,
        }, 'JumpAnimate')

        local nimbSection = UI.Sections.Nimb or UI.Tabs.Visuals:Section({ Name = "Nimb", Side = "Right" })
        UI.Sections.Nimb = nimbSection
        nimbSection:Header({ Name = "Nimb" })
        nimbSection:SubLabel({ Text = "Displays a circle above the player head (Auto-adjusts for ShiftLock)" })
        uiElements.NimbEnabled = nimbSection:Toggle({
            Name = "Nimb Enabled",
            Default = State.Nimb.NimbActive.Default,
            Callback = function(value)
                toggleNimb(value)
            end,
        }, 'NimbEnabled')
        nimbSection:Divider()
        uiElements.NimbRadius = nimbSection:Slider({
            Name = "Radius",
            Minimum = 1.0,
            Maximum = 3.0,
            Default = State.Nimb.NimbRadius.Default,
            Precision = 1,
            Callback = function(value)
                State.Nimb.NimbRadius.Value = value
                if State.Nimb.NimbActive.Value then
                    createNimb()
                end
                notify("Nimb", "Nimb Radius set to: " .. value, false)
            end,
        }, 'NimbRadius')
        uiElements.NimbParts = nimbSection:Slider({
            Name = "Parts",
            Minimum = 20,
            Maximum = 100,
            Default = State.Nimb.NimbParts.Default,
            Precision = 0,
            Callback = function(value)
                State.Nimb.NimbParts.Value = value
                if State.Nimb.NimbActive.Value then
                    createNimb()
                end
                notify("Nimb", "Nimb Parts set to: " .. value, false)
            end,
        }, 'NimbParts')
        nimbSection:Divider()
        uiElements.NimbGradientSpeed = nimbSection:Slider({
            Name = "Gradient Speed",
            Minimum = 1,
            Maximum = 10,
            Default = State.Nimb.NimbGradientSpeed.Default,
            Precision = 1,
            Callback = function(value)
                State.Nimb.NimbGradientSpeed.Value = value
                notify("Nimb", "Nimb Gradient Speed set to: " .. value, false)
            end,
        }, 'NimbGradientSpeed')
        uiElements.NimbGradient = nimbSection:Toggle({
            Name = "Gradient",
            Default = State.Nimb.NimbGradient.Default,
            Callback = function(value)
                State.Nimb.NimbGradient.Value = value
                if State.Nimb.NimbActive.Value then
                    createNimb()
                end
                notify("Nimb", "Nimb Gradient: " .. (value and "Enabled" or "Disabled"), true)
            end,
        }, 'NimbGradient')
        uiElements.NimbColor = nimbSection:Colorpicker({
            Name = "Color",
            Default = State.Nimb.NimbColor.Default,
            Callback = function(value)
                State.Nimb.NimbColor.Value = value
                if State.Nimb.NimbActive.Value and not State.Nimb.NimbGradient.Value then
                    createNimb()
                end
                notify("Nimb", "Nimb Color updated", false)
            end,
        }, 'NimbColor')
        nimbSection:Divider()
        uiElements.NimbYOffset = nimbSection:Slider({
            Name = "Y Offset",
            Minimum = 1,
            Maximum = 3,
            Default = State.Nimb.NimbYOffset.Default,
            Precision = 2,
            Callback = function(value)
                State.Nimb.NimbYOffset.Value = value
                notify("Nimb", "Nimb Y Offset set to: " .. value, false)
            end,
        }, 'NimbYOffset')

        local configSection = UI.Tabs.Config:Section({ Name = "Circle,ChinaHat,Nimb Sync", Side = "Right" })
        configSection:Header({ Name = "ChinaHat, Circle, Nimb Settings Sync" })
        configSection:Button({
            Name = "Sync Config",
            Callback = function()
                State.ChinaHat.HatScale.Value = uiElements.HatScale:GetValue()
                State.ChinaHat.HatParts.Value = uiElements.HatParts:GetValue()
                State.ChinaHat.HatGradientSpeed.Value = uiElements.HatGradientSpeed:GetValue()
                State.ChinaHat.HatYOffset.Value = uiElements.HatYOffset:GetValue()
                State.ChinaHat.Filled.Value = uiElements.HatFilled:GetValue()
                State.ChinaHat.FillTransparency.Value = uiElements.FillTransparency:GetValue()
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end

                State.Circle.CircleRadius.Value = uiElements.CircleRadius:GetValue()
                State.Circle.CircleParts.Value = uiElements.CircleParts:GetValue()
                State.Circle.CircleGradientSpeed.Value = uiElements.CircleGradientSpeed:GetValue()
                State.Circle.StickToGround.Value = uiElements.StickToGround:GetValue()
                if State.Circle.CircleActive.Value then
                    createCircle()
                end

                State.Nimb.NimbRadius.Value = uiElements.NimbRadius:GetValue()
                State.Nimb.NimbParts.Value = uiElements.NimbParts:GetValue()
                State.Nimb.NimbGradientSpeed.Value = uiElements.NimbGradientSpeed:GetValue()
                State.Nimb.NimbYOffset.Value = uiElements.NimbYOffset:GetValue()
                if State.Nimb.NimbActive.Value then
                    createNimb()
                end

                notify("ChinaHat", "Config synchronized!", true)
            end
        })
    end

    function ChinaHat:Destroy()
        destroyParts(hatLines)
        destroyParts(hatCircleQuads)
        destroyParts(hatFilledTriangles)
        destroyParts(circleQuads)
        destroyParts(nimbQuads)
        if renderConnection then
            renderConnection:Disconnect()
        end
        if humanoidConnection then
            humanoidConnection:Disconnect()
        end
        if shiftLockConnection then
            shiftLockConnection:Disconnect()
        end
    end

    return ChinaHat
end

return ChinaHat
