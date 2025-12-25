-- ================= CONFIGURATION =================
local MAX_TARGET_DIST = 300
local DASH_COOLDOWN = 0.18 -- Optimized from script 2
local ENEMY_ATTACK_THRESHOLD = 5
local CAMERA_OFFSET_Y = 1.0
local COMBO_TRIGGER_DIST = 4.5 -- Balanced trigger distance
local DASH_TRIGGER_DIST = 7.5 

-- ================= SERVICES =================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInput = game:GetService("VirtualInputManager")

-- ================= PLAYER DATA =================
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

-- ================= STATE =================
local lastCombo = 0
local lastDash = 0
local isGhostFlicking = false
local currentKeys = {W = false, A = false, D = false}

-- ================= UTILS =================
local function getHRP(obj) return obj:FindFirstChild("HumanoidRootPart") end
local function alive(model) return model and model:FindFirstChild("Humanoid") and model.Humanoid.Health > 0 end

local function tapKey(key)
    task.spawn(function()
        VirtualInput:SendKeyEvent(true, key, false, game)
        task.wait(0.01)
        VirtualInput:SendKeyEvent(false, key, false, game)
    end)
end

local function clickM1(times)
    for i = 1, times do
        VirtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        VirtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        task.wait(0.05) -- Fast M1 speed
    end
end

local function pressMoveKey(keyName, state)
    if currentKeys[keyName] ~= state then
        VirtualInput:SendKeyEvent(state, Enum.KeyCode[keyName], false, game)
        currentKeys[keyName] = state
    end
end

local function releaseAllKeys()
    for key, pressed in pairs(currentKeys) do
        if pressed then
            VirtualInput:SendKeyEvent(false, Enum.KeyCode[key], false, game)
            currentKeys[key] = false
        end
    end
    hum:Move(Vector3.new(0,0,0))
end

-- ================= CAMERA LOCK (PREDICTIVE) =================

local function updateCameraLock(enemy)
    local eHRP = getHRP(enemy)
    if not eHRP then return end
    
    local predictedPos = eHRP.Position + (eHRP.AssemblyLinearVelocity * 0.12)
    local targetPos = predictedPos + Vector3.new(0, CAMERA_OFFSET_Y, 0)
    cam.CFrame = CFrame.new(cam.CFrame.Position, targetPos)
end

-- ================= INTEGRATED SAITAMA COMBO =================

local function runSaitamaAntiHeroCombo(enemy)
    if isGhostFlicking or not alive(enemy) then return end
    isGhostFlicking = true
    
    -- [STEP 1] Initial Pressure
    clickM1(3) 
    
    -- [STEP 2] Ultra Fast Shove
    tapKey(Enum.KeyCode.Three) 
    task.wait(0.08) 
    
    -- [STEP 3] Gap Close Dash
    tapKey(Enum.KeyCode.Q) 
    task.wait(0.02)
    
    -- [STEP 4] Secondary Pressure
    clickM1(3) 
    
    -- [STEP 5] Consecutive Punches
    tapKey(Enum.KeyCode.One) 
    task.wait(0.40) 
    
    -- [STEP 6] Aerial Catch
    tapKey(Enum.KeyCode.Space)
    task.wait(0.01)
    tapKey(Enum.KeyCode.Four) 
    
    -- [STEP 7] Finisher
    task.wait(0.52) 
    tapKey(Enum.KeyCode.Two) 
    
    isGhostFlicking = false
end

-- ================= HYBRID MOVEMENT (BACKSIDE SNAP + W-HOLD) =================

local function handleMovement(enemy, dist)
    local eHRP = getHRP(enemy)
    if not eHRP then return end

    -- FACE ENEMY
    local lookPos = Vector3.new(eHRP.Position.X, hrp.Position.Y, eHRP.Position.Z)
    hrp.CFrame = CFrame.new(hrp.Position, lookPos)

    -- BACKSIDE SNAPPING LOGIC
    local relPos = eHRP.CFrame:PointToObjectSpace(hrp.Position)
    local enemyLook = eHRP.CFrame.LookVector
    local toMe = (hrp.Position - eHRP.Position).Unit
    local dotProduct = enemyLook:Dot(toMe)
    local isBehind = dotProduct > 0.2

    local moveDirection = Vector3.new(0, 0, -1.5) 

    if not isBehind and dist < 15 then
        -- Orbit movement to get behind target
        if relPos.X > 0 then
            moveDirection = Vector3.new(2.5, 0, -1.5) 
            pressMoveKey("D", true); pressMoveKey("A", false)
        else
            moveDirection = Vector3.new(-2.5, 0, -1.5) 
            pressMoveKey("A", true); pressMoveKey("D", false)
        end
    else
        -- Pin target from behind
        pressMoveKey("A", false); pressMoveKey("D", false)
        moveDirection = Vector3.new(0, 0, -2.0) 
    end

    -- APPLY AGGRESSIVE MOVEMENT
    hum:Move(moveDirection, true)
    pressMoveKey("W", true)

    -- SMART MOMENTUM DASH (Script 2 Logic)
    if dist > DASH_TRIGGER_DIST or (dist > 5 and eHRP.AssemblyLinearVelocity.Magnitude > 20) then
        if tick() - lastDash > DASH_COOLDOWN then
            lastDash = tick()
            tapKey(Enum.KeyCode.Q)
        end
    end
end

-- ================= MAIN SYSTEM LOOP =================

RunService.RenderStepped:Connect(function()
    if not alive(char) then
        char = lp.Character or lp.CharacterAdded:Wait()
        hum = char:WaitForChild("Humanoid")
        hrp = char:WaitForChild("HumanoidRootPart")
        return
    end

    -- Fast Recovery (Space Spam)
    if hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum.PlatformStand then
        tapKey(Enum.KeyCode.Space)
    end

    -- Target Acquisition
    local enemy, dist = nil, MAX_TARGET_DIST
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character and alive(p.Character) then
            local d = (getHRP(p.Character).Position - hrp.Position).Magnitude
            if d < dist then dist = d enemy = p.Character end
        end
    end

    if enemy then
        updateCameraLock(enemy)
        handleMovement(enemy, dist)
        
        -- Auto Block/Counter
        local eHRP = getHRP(enemy)
        if dist < 8 and eHRP.AssemblyLinearVelocity.Magnitude > ENEMY_ATTACK_THRESHOLD then
            tapKey(Enum.KeyCode.F)
        end
        
        -- Execute Combo
        if dist <= COMBO_TRIGGER_DIST and (tick() - lastCombo) > 0.15 then
            lastCombo = tick()
            task.spawn(function() runSaitamaAntiHeroCombo(enemy) end)
        end
    else
        releaseAllKeys()
    end
end)
