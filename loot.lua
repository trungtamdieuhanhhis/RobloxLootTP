local parent = (gethui and gethui()) or game:GetService("CoreGui")

local old = parent:FindFirstChild("TP_TEST_UI")
if old then old:Destroy() end

local g = Instance.new("ScreenGui")
g.Name = "TP_TEST_UI"
g.IgnoreGuiInset = true
g.ResetOnSpawn = false
g.Parent = parent

local f = Instance.new("Frame", g)
f.Size = UDim2.new(0, 220, 0, 90)
f.Position = UDim2.new(0, 120, 0, 120)
f.BackgroundColor3 = Color3.fromRGB(35,35,35)
Instance.new("UICorner", f).CornerRadius = UDim.new(0,12)

local t = Instance.new("TextLabel", f)
t.BackgroundTransparency = 1
t.Size = UDim2.new(1,0,1,0)
t.Text = "LOADER OK"
t.Font = Enum.Font.SourceSansBold
t.TextSize = 22
t.TextColor3 = Color3.new(1,1,1)
