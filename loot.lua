-- UI Test (Ironbrew-like safe loader)

local function d(s)  -- decode helper
    return string.char(unpack(s))
end

-- obfuscated class names:
local cls_SG = d({83,99,114,101,101,110,71,117,105})      -- "ScreenGui"
local cls_FR = d({70,114,97,109,101})                    -- "Frame"
local cls_TL = d({84,101,120,116,76,97,98,101,108})      -- "TextLabel"

local parent
pcall(function()
    parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not parent then
    parent = game:GetService("CoreGui")
end

local gui = Instance.new(cls_SG)
gui.Name = "TEST_IRONBREW_UI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = parent

local frame = Instance.new(cls_FR, gui)
frame.Size = UDim2.new(0, 240, 0, 90)
frame.Position = UDim2.new(0.5, -120, 0.5, -45)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local label = Instance.new(cls_TL, frame)
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "HAIDANG"
label.TextColor3 = Color3.new(1,1,1)
label.Font = Enum.Font.SourceSansBold
label.TextSize = 22
