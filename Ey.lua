-- =============================================================================
-- SYSTEM: BERSERKER PRE-EMPTIVE SHADOW (BOX DETECTION HYBRID)
-- OBJECTIVE: EARLY EVASION, AUTOMATIC FLANKING, ALWAYS BEHIND
-- =============================================================================

local CONFIG = {
    -- POSITIONING & LOCOMOTION
    MAX_TARGET_DIST = 1500,
    IDEAL_COMBO_DIST = 4.3,
    DASH_COOLDOWN = 0.15,
    ORBIT_STRENGTH = 10.5,     -- Mas mabilis na pag-orbit
    SNAP_TO_BACK_SPEED = 14,   -- Mas mabilis na hatak sa likod
    BACK_DOT_THRESHOLD = -0.75, 
    LERP_SMOOTHNESS = 0.4,     -- Smoother turning

    -- TURBO SAITAMA DATA
    M1_SPEED = 0.001,
    SHOVE_DELAY = 0.015,
    UPPERCUT_DELAY = 0.32,
    CONSECUTIVE_WINDOW = 0.18,
    CAMERA_OFFSET_Y = 1.3,
}

-- ================= GUI ADJUSTER =================
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 180, 0, 70)
MainFrame.Position = UDim2.new(0.02, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 2
MainFrame.Active = true
MainFrame.Draggable = true

local Title = Instance.new("TextLabel", MainFrame)
Title.Text = "EVASION RANGE (1-15)"
Title.Size = UDim2.new(1, 0, 0, 25)
Title.TextColor3 = Color3.new(1, 1, 1)
Title.BackgroundTransparency = 1

local Slider = Instance.new("TextBox", MainFrame)
Slider.Size = UDim2.new(0.8, 0, 0, 25)
Slider.Position = UDim2.new(0.1, 0, 0.5, 0)
Slider.Text = "7" -- Default size (Adjustable)
Slider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Slider.TextColor3 = Color3.new(0, 0.7, 1)

-- ================= SERVICES =================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInput = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

-- ================= STATE =================
local state = {
    isComboing = false,
    lastDash = 0,
    lastCombo = 0,
    visualBoxes = {},
    currentKeys = {W = false, A = false, D = false}
}

-- ================= UTILS =================
local function getHRP(obj) return obj and obj:FindFirstChild("HumanoidRootPart") end
local function alive(model) return model and model:FindFirstChild("Humanoid") and model.Humanoid.Health > 0 end

local function setKeyState(key, down)
    if state.currentKeys[key] ~= down then
        VirtualInput:SendKeyEvent(down, key, false, game)
        state.currentKeys[key] = down
    end
end

local function tapKey(key)
    VirtualInput:SendKeyEvent(true, key, false, game)
    task.wait(0.005)
    VirtualInput:SendKeyEvent(false, key, false, game)
end

local function mouseM1()
    VirtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VirtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- ================= BOX LOGIC =================
local function updateEvasionBox(enemy)
    local head = enemy:FindFirstChild("Head")
    if not head then return end
    
    local box = state.visualBoxes[enemy]
    if not box then
        box = Instance.new("Part")
        box.Color = Color3.fromRGB(0, 150, 255)
        box.Transparency = 0.75
        box.CanCollide = false
        box.Anchored = true
        box.Material = Enum.Material.ForceField
        box.Parent = workspace
        state.visualBoxes[enemy] = box
    end
    
    local size = tonumber(Slider.Text) or 7
    box.Size = Vector3.new(size, size, size)
    box.CFrame = head.CFrame * CFrame.new(0, 0, -(size/2))
    return box
end

-- ================= ADVANCED FLANKING MOVEMENT =================
local function handleMovement(enemy, dist)
    local eHRP = getHRP(enemy)
    local box = updateEvasionBox(enemy)
    if not eHRP or not box then return end

    -- FACE LOCK (Aggressive)
    local lookPos = Vector3.new(eHRP.Position.X, hrp.Position.Y, eHRP.Position.Z)
    hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(hrp.Position, lookPos), CONFIG.LERP_SMOOTHNESS)

    -- ZONE DETECTION
    local relToBox = box.CFrame:PointToObjectSpace(hrp.Position)
    local boxSize = box.Size
    
    -- Detection Zone (Pre-emptive) - mararamdaman na nya yung lapit ng box
    local isThreatZone = math.abs(relToBox.X) < (boxSize.X * 1.2) and math.abs(relToBox.Z) < (boxSize.Z * 1.2)
    local isInside = math.abs(relToBox.X) < (boxSize.X/2) and math.abs(relToBox.Z) < (boxSize.Z/2)

    local moveVec;

    if isThreatZone then
        -- Kusa syang umiikot para makapunta sa gilid/likod
        local sideKey = relToBox.X > 0 and Enum.KeyCode.D or Enum.KeyCode.A
        setKeyState(Enum.KeyCode.W, true)
        setKeyState(sideKey, true)
        
        -- Kung pumasok sa "Critical" zone (gitna ng box), Dash agad pabalik sa likod
        if isInside and (tick() - state.lastDash > CONFIG.DASH_COOLDOWN) then
            state.lastDash = tick()
            tapKey(Enum.KeyCode.Q)
        end
        
        -- Vector calculation para sa mabilis na flanking
        local sideMult = relToBox.X > 0 and 1 or -1
        moveVec = Vector3.new(CONFIG.ORBIT_STRENGTH * sideMult, 0, -5)
        
        -- Release opposite keys
        local otherKey = sideKey == Enum.KeyCode.D and Enum.KeyCode.A or Enum.KeyCode.D
        setKeyState(otherKey, false)
    else
        -- SHADOW MODE: Kapag wala sa harap, pilit na dumidikit sa likod
        setKeyState(Enum.KeyCode.A, false)
        setKeyState(Enum.KeyCode.D, false)
        setKeyState(Enum.KeyCode.W, true)

        local enemyLook = eHRP.CFrame.LookVector
        local dot = enemyLook:Dot((hrp.Position - eHRP.Position).Unit)
        
        if dot > CONFIG.BACK_DOT_THRESHOLD then
            -- Wala pa sa likod, kailangan pang lumiko
            local rel = eHRP.CFrame:PointToObjectSpace(hrp.Position)
            moveVec = Vector3.new(rel.X > 0 and CONFIG.ORBIT_STRENGTH or -CONFIG.ORBIT_STRENGTH, 0, -CONFIG.SNAP_TO_BACK_SPEED)
        else
            -- NASA LIKOD NA: Direct pressure
            moveVec = Vector3.new(0, 0, -15)
        end
    end

    hum:Move(moveVec, true)
end

-- ================= COMBO & ATTACK ENGINE =================
local function executeSaitamaCombo(enemy)
    if state.isComboing or not alive(enemy) then return end
    state.isComboing = true
    
    -- Machine Gun M1
    for i = 1, 3 do mouseM1() task.wait(CONFIG.M1_SPEED) end
    
    tapKey(Enum.KeyCode.Three) -- Guard Break Shove
    task.wait(CONFIG.SHOVE_DELAY)
    
    tapKey(Enum.KeyCode.Q) -- Dash Cancel for Frame Advantage
    task.wait(0.01)
    
    tapKey(Enum.KeyCode.One) -- Consecutive Punches
    task.wait(CONFIG.CONSECUTIVE_WINDOW)
    
    tapKey(Enum.KeyCode.Space)
    task.wait(0.01)
    tapKey(Enum.KeyCode.Four) -- Uppercut Launcher
    
    task.wait(0.4)
    tapKey(Enum.KeyCode.Two) -- Finisher
    
    state.isComboing = false
    state.lastCombo = tick()
end

-- ================= MAIN SYSTEM LOOP =================
RunService.RenderStepped:Connect(function()
    if not alive(char) then
        char = lp.Character or lp.CharacterAdded:Wait()
        hum = char:WaitForChild("Humanoid")
        hrp = char:WaitForChild("HumanoidRootPart")
        return
    end

    -- Ragdoll Recovery
    if hum:GetState() == Enum.HumanoidStateType.Ragdoll then tapKey(Enum.KeyCode.Space) end

    -- Scan for Targets
    local target, dist = nil, CONFIG.MAX_TARGET_DIST
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character and alive(p.Character) then
            local d = (getHRP(p.Character).Position - hrp.Position).Magnitude
            if d < dist then dist = d target = p.Character end
        end
    end

    -- Box Visual Manager
    for enemy, box in pairs(state.visualBoxes) do
        if enemy ~= target or not alive(enemy) then
            box:Destroy()
            state.visualBoxes[enemy] = nil
        end
    end

    if target then
        handleMovement(target, dist)
        
        -- Auto Counter
        local tHRP = getHRP(target)
        if dist < 8 and tHRP.AssemblyLinearVelocity.Magnitude > 12 then tapKey(Enum.KeyCode.F) end

        -- Execution
        if dist <= CONFIG.IDEAL_COMBO_DIST and not state.isComboing and (tick() - state.lastCombo) > 0.1 then
            task.spawn(function() executeSaitamaCombo(target) end)
        end
        
        if dist < 5 then mouseM1() end
    else
        -- Idle State
        setKeyState(Enum.KeyCode.W, false)
        setKeyState(Enum.KeyCode.A, false)
        setKeyState(Enum.KeyCode.D, false)
        hum:Move(Vector3.new(0,0,0))
    end
end)

print("SYSTEM: PRE-EMPTIVE SHADOW BERSERKER ACTIVE")
