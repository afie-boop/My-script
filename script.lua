-- ============================================
-- RAYFIELD: CONSOLE.LOG + AUTO PARRY
-- Remote asli: ReplicatedStorage.Remotes.ParryButtonPress
-- ============================================

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ========== 1. CONSOLE.LOG MODULE ==========
local ConsoleLogs = {}
local MAX_LOGS = 100
local ConsoleParagraph = nil

local function RefreshConsole()
    if not ConsoleParagraph then return end
    pcall(function()
        ConsoleParagraph:Set({
            Title = "Live Console",
            Content = #ConsoleLogs > 0
                and table.concat(ConsoleLogs, "\n")
                or "Console kosong."
        })
    end)
end

function ConsoleLog(message)
    message = tostring(message)
    table.insert(ConsoleLogs, message)
    if #ConsoleLogs > MAX_LOGS then
        table.remove(ConsoleLogs, 1)
    end
    RefreshConsole()
    print(message)
end

local function ClearConsole()
    table.clear(ConsoleLogs)
    RefreshConsole()
    ConsoleLog("[SYSTEM] Console cleared")
end

local function CopyConsole()
    local text = table.concat(ConsoleLogs, "\n")
    if setclipboard then
        setclipboard(text)
        ConsoleLog("[SYSTEM] Log berjaya disalin.")
    else
        ConsoleLog("[ERROR] Clipboard tidak tersedia.")
    end
end

-- ========== 2. ERROR LOGGER ==========
pcall(function()
    game:GetService("ScriptContext").Error:Connect(function(message)
        ConsoleLog("[ERROR] " .. tostring(message))
    end)
end)

-- ========== 3. AUTO PARRY SYSTEM (REMOTE ASLI) ==========
local autoParryActive = false
local parryRemote = nil
local ball = nil
local heartbeatConnection = nil
local lastParryTime = 0
local PARRY_COOLDOWN = 0.2

local function getParryRemote()
    -- REMOTE ASLI BLADE BALL
    local success, remote = pcall(function()
        return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ParryButtonPress")
    end)
    
    if success and remote then
        ConsoleLog("[INFO] Remote asli ditemui: " .. remote:GetFullName())
        return remote
    else
        ConsoleLog("[ERROR] Remote asli TIADA di ReplicatedStorage.Remotes.ParryButtonPress")
        return nil
    end
end

local function findBall()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (
            obj.Name:find("Ball") or 
            obj.Name:find("ball") or 
            obj.Name:find("Sphere") or
            obj.Name:find("Projectile")
        ) then
            ConsoleLog("[INFO] Bola ditemui: " .. obj:GetFullName())
            return obj
        end
    end
    ConsoleLog("[WARN] Tiada bola ditemui di workspace")
    return nil
end

local function getBallSpeed(ballObj)
    local speed = 0
    pcall(function()
        if ballObj.AssemblyLinearVelocity then
            speed = ballObj.AssemblyLinearVelocity.Magnitude
        end
    end)
    if speed == 0 then
        pcall(function()
            if ballObj.Velocity then
                speed = ballObj.Velocity.Magnitude
            end
        end)
    end
    return speed
end

local function startAutoParry()
    if autoParryActive then
        ConsoleLog("[AUTO PARRY] Sudah aktif, tuan.")
        return
    end
    autoParryActive = true

    -- Cari remote asli
    if not parryRemote then
        parryRemote = getParryRemote()
    end

    if not parryRemote then
        ConsoleLog("[ERROR] Remote asli tidak ditemukan, auto parry gagal.")
        autoParryActive = false
        return
    end

    -- Cari bola
    if not ball or not ball.Parent then
        ball = findBall()
    end

    heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not autoParryActive then return end

        if not ball or not ball.Parent then
            ball = findBall()
            if not ball then return end
        end

        if not humanoidRootPart or not humanoidRootPart.Parent then
            character = player.Character or player.CharacterAdded:Wait()
            humanoidRootPart = character:WaitForChild("HumanoidRootPart")
            return
        end

        local dist = (ball.Position - humanoidRootPart.Position).Magnitude
        local speed = getBallSpeed(ball)

        if tick() % 2 < 0.1 then
            ConsoleLog("[DEBUG] Jarak: " .. string.format("%.2f", dist) .. " | Speed: " .. string.format("%.2f", speed))
        end

        if dist < 30 and speed > 15 and (tick() - lastParryTime) >= PARRY_COOLDOWN then
            lastParryTime = tick()
            
            -- GUNA REMOTE ASLI
            local success = pcall(function()
                parryRemote:FireServer()
            end)
            
            if success then
                ConsoleLog("[AUTO PARRY] Parry dikirim via remote asli!")
            else
                ConsoleLog("[ERROR] Gagal kirim parry.")
            end
        end
    end)

    ConsoleLog("[AUTO PARRY] DIAKTIFKAN dengan remote asli, tuan.")
end

local function stopAutoParry()
    if not autoParryActive then
        ConsoleLog("[AUTO PARRY] Sudah nonaktif, tuan.")
        return
    end
    autoParryActive = false

    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    ConsoleLog("[AUTO PARRY] DINONAKTIFKAN, tuan.")
end

-- ========== 4. RAYFIELD UI ==========
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/jensonhirst/Rayfield/main/source"
))()

local Window = Rayfield:CreateWindow({
    Name = "Console.log",
    LoadingTitle = "Console.log",
    LoadingSubtitle = "Blade Ball",
    ConfigurationSaving = {
        Enabled = false
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

-- ========== CONSOLE TAB ==========
local ConsoleTab = Window:CreateTab("Console")

ConsoleParagraph = ConsoleTab:CreateParagraph({
    Title = "Live Console",
    Content = "Console initialized..."
})

ConsoleTab:CreateButton({
    Name = "Clear",
    Callback = function()
        ClearConsole()
    end
})

ConsoleTab:CreateButton({
    Name = "Copy",
    Callback = function()
        CopyConsole()
    end
})

-- ========== AUTO PARRY TAB ==========
local MainTab = Window:CreateTab("Auto Parry")

MainTab:CreateToggle({
    Name = "Auto Parry",
    CurrentValue = false,
    Flag = "AutoParry",
    Callback = function(Value)
        if Value then
            ConsoleLog("[AUTO PARRY] Toggle: ON")
            startAutoParry()
        else
            ConsoleLog("[AUTO PARRY] Toggle: OFF")
            stopAutoParry()
        end
    end
})

-- ========== 5. DEBUG TAB ==========
local DebugTab = Window:CreateTab("Debug")

DebugTab:CreateButton({
    Name = "Test Remote Asli",
    Callback = function()
        local remote = getParryRemote()
        if remote then
            local success = pcall(function()
                remote:FireServer()
            end)
            ConsoleLog(success and "[DEBUG] Remote asli BERFUNGSI" or "[DEBUG] Remote asli GAGAL")
        end
    end
})

-- ========== 6. EKSEKUSI AWAL ==========
ConsoleLog("[SYSTEM] =============================")
ConsoleLog("[SYSTEM] Console.log UI aktif")
ConsoleLog("[SYSTEM] Auto Parry UI aktif")
ConsoleLog("[SYSTEM] Remote ASLI: ReplicatedStorage.Remotes.ParryButtonPress")
ConsoleLog("[SYSTEM] =============================")
