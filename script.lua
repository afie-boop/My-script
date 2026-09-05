-- ============================================
-- RAYFIELD SIRIUS: CONSOLE.LOG + AUTO PARRY
-- Remote asli: ReplicatedStorage.Remotes.ParryButtonPress
-- ============================================

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ========== 1. CONSOLE.LOG MODULE (Sirius-style) ==========
local Logs = {}
local MAX_LOGS = 200
local ConsoleParagraph = nil
local updating = false

local function RefreshConsole()
    if not ConsoleParagraph then return end
    pcall(function()
        ConsoleParagraph:Set({
            Title = "Live Console",
            Content = #Logs > 0
                and table.concat(Logs, "\n")
                or "Console kosong."
        })
    end)
end

function ConsoleLog(message)
    if updating then return end
    updating = true

    local text = string.format(
        "[%s] %s",
        os.date("%H:%M:%S"),
        tostring(message)
    )

    table.insert(Logs, text)

    if #Logs > MAX_LOGS then
        table.remove(Logs, 1)
    end

    RefreshConsole()
    updating = false
    print(message) -- backup output
end

local function ClearConsole()
    table.clear(Logs)
    RefreshConsole()
    ConsoleLog("[SYSTEM] Console cleared")
end

local function CopyConsole()
    local text = table.concat(Logs, "\n")
    if setclipboard then
        setclipboard(text)
        ConsoleLog("[SYSTEM] Log berjaya disalin.")
    else
        ConsoleLog("[ERROR] Clipboard tidak tersedia.")
    end
end

-- ========== 2. ERROR LOGGER (Sirius-style) ==========
pcall(function()
    game:GetService("ScriptContext").Error:Connect(function(message, trace)
        ConsoleLog("[ERROR] " .. tostring(message))
        if trace and trace ~= "" then
            ConsoleLog("[TRACE] " .. tostring(trace))
        end
    end)
end)

pcall(function()
    game:GetService("LogService").MessageOut:Connect(function(message, messageType)
        if messageType == Enum.MessageType.MessageError then
            ConsoleLog("[ERROR] " .. tostring(message))
        elseif messageType == Enum.MessageType.MessageWarning then
            ConsoleLog("[WARN] " .. tostring(message))
        end
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

    if not parryRemote then
        parryRemote = getParryRemote()
    end

    if not parryRemote then
        ConsoleLog("[ERROR] Remote asli tidak ditemukan, auto parry gagal.")
        autoParryActive = false
        return
    end

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

-- ========== 4. RAYFIELD SIRIUS UI ==========
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Nexa Console + Auto Parry",
    LoadingTitle = "Nexa Console",
    LoadingSubtitle = "Blade Ball",
    ConfigurationSaving = {
        Enabled = false
    }
})

-- ========== CONSOLE TAB ==========
local ConsoleTab = Window:CreateTab("Console")

ConsoleParagraph = ConsoleTab:CreateParagraph({
    Title = "Live Console",
    Content = "Console sedang dimulakan..."
})

ConsoleTab:CreateButton({
    Name = "📋 Copy Logs",
    Callback = function()
        CopyConsole()
    end
})

ConsoleTab:CreateButton({
    Name = "🗑️ Clear Logs",
    Callback = function()
        ClearConsole()
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

-- ========== DEBUG TAB ==========
local DebugTab = Window:CreateTab("Debug")

DebugTab:CreateButton({
    Name = "Test Remote",
    Callback = function()
        local remote = getParryRemote()
        if remote then
            local success = pcall(function()
                remote:FireServer()
            end)
            ConsoleLog(success and "[DEBUG] Remote BERFUNGSI" or "[DEBUG] Remote GAGAL")
        end
    end
})

DebugTab:CreateButton({
    Name = "Scan Ball",
    Callback = function()
        findBall()
    end
})

-- ========== 5. EKSEKUSI AWAL ==========
ConsoleLog("[SYSTEM] =============================")
ConsoleLog("[SYSTEM] Rayfield Sirius + Auto Parry aktif")
ConsoleLog("[SYSTEM] Remote: ReplicatedStorage.Remotes.ParryButtonPress")
ConsoleLog("[SYSTEM] =============================")
