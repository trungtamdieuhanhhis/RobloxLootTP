-- loot.lua
-- Single-file loader: UI (A3) + TP flow (speed 32, height +30)
local modules = {}

----------------------------------------------------------------
-- MODULE UI (CoreGui / gethui safe)
----------------------------------------------------------------
modules["ui"] = function()
    local parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    if not parent then return end

    local old = parent:FindFirstChild("LootTP_UI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LootTP_UI"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = parent

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 320, 0, 120)
    frame.Position = UDim2.new(0, 120, 0, 120)
    frame.BackgroundColor3 = Color3.fromRGB(18,18,18)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -20, 0, 26)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🛰️  Loot Teleport (A3)"
    title.TextColor3 = Color3.fromRGB(240,240,240)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left

    local info = Instance.new("TextLabel", frame)
    info.Size = UDim2.new(1, -20, 0, 36)
    info.Position = UDim2.new(0, 10, 0, 36)
    info.BackgroundTransparency = 1
    info.Text = "TP mượt → tới item gần nhất → nhấn E → về chỗ cũ"
    info.TextColor3 = Color3.fromRGB(200,200,200)
    info.Font = Enum.Font.SourceSans
    info.TextSize = 14
    info.TextXAlignment = Enum.TextXAlignment.Left

    local startBtn = Instance.new("TextButton", frame)
    startBtn.Size = UDim2.new(0, 120, 0, 34)
    startBtn.Position = UDim2.new(0, 16, 1, -46)
    startBtn.BackgroundColor3 = Color3.fromRGB(45,135,255)
    startBtn.Text = "Start"
    startBtn.TextColor3 = Color3.fromRGB(255,255,255)
    startBtn.Font = Enum.Font.SourceSansSemibold
    startBtn.TextSize = 16
    Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0,8)

    -- trạng thái chung
    _G.LOOTTP_RUNNING = false
    _G.LOOTTP_SPEED = 32 -- cố định theo yêu cầu
    _G.LOOTTP_HEIGHT = 30 -- +30 theo yêu cầu

    -- khi bấm start: bật trạng thái; core module sẽ theo dõi _G.LOOTTP_RUNNING
    startBtn.MouseButton1Click:Connect(function()
        -- khởi chạy 1 lần nếu chưa đang chạy
        if _G.LOOTTP_RUNNING then
            -- nếu đang chạy, tắt để cancel
            _G.LOOTTP_RUNNING = false
            startBtn.Text = "Start"
        else
            _G.LOOTTP_RUNNING = true
            startBtn.Text = "Stop"
        end
    end)

    -- expose gui refs nếu cần
    return {
        gui = gui,
        frame = frame,
        start = startBtn,
        info = info
    }
end

----------------------------------------------------------------
-- MODULE CORE (TP logic)
----------------------------------------------------------------
modules["core"] = function()
    local Players = game:GetService("Players")
    local p = Players.LocalPlayer
    local c = p.Character or p.CharacterAdded:Wait()
    local hum = c:WaitForChild("Humanoid")
    local hrp = c:WaitForChild("HumanoidRootPart")
    local RunService = game:GetService("RunService")

    -- safety helpers
    local function FixFreeze()
        task.wait(0.05)
        pcall(function()
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
            if hum then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end

    -- di chuyển mượt bằng velocity hướng tới targetPos, giữ y cố định
    local function MoveSmooth(targetPos, speed, keepY)
        speed = speed or _G.LOOTTP_SPEED or 32
        local reached = false
        local dt = RunService.Heartbeat:Wait()
        -- lặp cho đến khi gần mục tiêu
        while true do
            if not hrp or not targetPos then break end
            local cur = hrp.Position
            local desired = Vector3.new(targetPos.X, (keepY and cur.Y) or targetPos.Y, targetPos.Z)
            local dir = (desired - cur)
            local dist = dir.Magnitude
            if dist <= 2 then
                break
            end
            local velDir = dir.Unit
            -- set velocity
            pcall(function()
                hrp.AssemblyLinearVelocity = velDir * speed
            end)
            task.wait(1/60)
        end
        -- stop
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
        FixFreeze()
    end

    -- tìm loot gần nhất (tìm basepart thuộc object Name == "Loot")
    local function findNearestLoot()
        local best, bd = nil, 1e9
        for _, obj in ipairs(game:GetDescendants()) do
            if obj.Name == "Loot" then
                local part = obj:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bd then
                        bd = d
                        best = part
                    end
                end
            end
        end
        return best
    end

    -- find proximity prompt inside/near loot part
    local function findPrompt(root)
        if not root then return nil end
        -- search descendants for ProximityPrompt
        for _, v in ipairs(root:GetDescendants()) do
            if v:IsA("ProximityPrompt") then return v end
        end
        -- search nearby parts (same position) within small radius
        local nearby = workspace:FindPartsInRegion3WithWhiteList(Region3.new(root.Position - Vector3.new(2,2,2), root.Position + Vector3.new(2,2,2)), {workspace}, 10)
        for _, part in ipairs(nearby) do
            for _, d in ipairs(part:GetDescendants()) do
                if d:IsA("ProximityPrompt") then return d end
            end
        end
        return nil
    end

    -- try fire prompt using available methods
    local function firePrompt(pr)
        if not pr then return false end
        local ok = false
        -- try exploit helper
        pcall(function()
            if type(fireproximityprompt) == "function" then
                fireproximityprompt(pr)
                ok = true
            end
        end)
        if ok then return true end
        -- try :InputHoldBegin / :InputHoldEnd (some games)
        pcall(function()
            if pr and pr.Parent then
                pr:InputHoldBegin()
                task.wait(0.1)
                pr:InputHoldEnd()
                ok = true
            end
        end)
        if ok then return true end
        -- try :Triggered event
        pcall(function()
            pr:Trigger()
            ok = true
        end)
        return ok
    end

    -- main routine to perform one TP cycle
    _G.LOOTTP_GO = function()
        -- ensure character and parts valid
        if not hrp or not hum then
            local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
            hum = char:WaitForChild("Humanoid")
            hrp = char:WaitForChild("HumanoidRootPart")
        end

        local lootPart = findNearestLoot()
        if not lootPart then
            warn("Không tìm thấy loot gần đó.")
            return
        end

        local origin = hrp.CFrame

        -- 1) TP mượt lên cao (giữ xz)
        local upPos = hrp.Position + Vector3.new(0, _G.LOOTTP_HEIGHT or 30, 0)
        MoveSmooth(Vector3.new(hrp.Position.X, upPos.Y, hrp.Position.Z), _G.LOOTTP_SPEED, true)

        -- 2) TP mượt ngang tới ngang trên loot (giữ Y)
        local aboveLoot = Vector3.new(lootPart.Position.X, upPos.Y, lootPart.Position.Z)
        MoveSmooth(aboveLoot, _G.LOOTTP_SPEED, true)

        -- 3) TP nhanh xuống vị trí item (nhanh xuống)
        local downPos = Vector3.new(lootPart.Position.X, lootPart.Position.Y + 2, lootPart.Position.Z)
        pcall(function() hrp.CFrame = CFrame.new(downPos) end)
        FixFreeze()
        task.wait(0.15)

        -- 4) Nhấn E nhặt (fire proximity prompt)
        local pr = findPrompt(lootPart)
        if pr then
            local fired = firePrompt(pr)
            if not fired then
                -- fallback: try to simulate keypress (some exploit libs)
                pcall(function()
                    if type(game.GetService) == "function" then
                        -- best-effort no-op
                    end
                end)
            end
        end

        task.wait(0.4)

        -- 5) TP nhanh lên cao
        pcall(function() hrp.CFrame = CFrame.new(aboveLoot) end)
        FixFreeze()
        task.wait(0.12)

        -- 6) TP mượt về vị trí ban đầu (giữ y bằng current-> smooth down)
        local dest = origin.Position
        MoveSmooth(dest, _G.LOOTTP_SPEED, false)
        pcall(function() hrp.CFrame = origin end)
        FixFreeze()
    end

    -- runner: monitor _G.LOOTTP_RUNNING and execute one cycle per start
    task.spawn(function()
        while true do
            if _G.LOOTTP_RUNNING then
                -- run one cycle
                pcall(function() _G.LOOTTP_GO() end)
                -- disable after one run (per yêu cầu)
                _G.LOOTTP_RUNNING = false
                -- reset Start button text if possible (via CoreGui)
                pcall(function()
                    local parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
                    local gui = parent:FindFirstChild("LootTP_UI")
                    if gui then
                        local btn = gui:FindFirstChildWhichIsA("TextButton", true)
                        if btn then btn.Text = "Start" end
                    end
                end)
            end
            task.wait(0.2)
        end
    end)
end

----------------------------------------------------------------
-- RUN LOADER
----------------------------------------------------------------
return function()
    for name, fn in pairs(modules) do
        local ok, err = pcall(fn)
        if not ok then warn("Module error:", name, err) end
    end
end
