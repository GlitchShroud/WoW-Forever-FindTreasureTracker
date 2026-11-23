local ADDON_NAME = "FindTreasureTracker"
local FIND_TREASURE_ID = 2481
local BUY_ME_A_COFFEE_URL = "https://buymeacoffee.com/pbg88"
local SOUND_BASE_PATH = "Interface\\AddOns\\FindTreasureTracker\\Sounds\\"
local LEGENDARY_PRIMARY_SOUND = SOUND_BASE_PATH .. "Legendary.ogg"
local LEGENDARY_SECONDARY_SOUND = SOUND_BASE_PATH .. "Feature.mp3"
local UNCOMMON_SOUND_CANDIDATES = {
    SOUND_BASE_PATH .. "Uncommon.ogg",
    SOUND_BASE_PATH .. "Uncommon.mp3",
}
local HELP_SOUND_CANDIDATES = {
    SOUND_BASE_PATH .. "Help.ogg",
    SOUND_BASE_PATH .. "Help.mp3",
}
local TRACKER_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Map_01"
local COIN_TEXTURE_PATH = "Interface\\Icons\\INV_Misc_Coin_02"
local TOP_AH_LIMIT = 5
local f = CreateFrame("Frame")

local openingChest = false
local chestName = "Chest"
local lastChestName = "Chest"
local countedThisChest = false
local alertedThisChest = false
local remindedInactiveThisChest = false
local SettingsCategoryID = nil

local NORMAL_MAX_SLOTS = {
    ["Battered Chest"] = 4,
    ["Worn Wooden Chest"] = 4,
    ["Solid Chest"] = 5,
    ["Reinforced Chest"] = 5,
}

local function IsTrackedChestName(name, fromOpeningCast)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local lower = name:lower()

    if lower:find("vein", 1, true)
        or lower:find("deposit", 1, true)
        or lower:find("seam", 1, true)
        or lower:find("node", 1, true)
        or lower:find("corpse", 1, true)
    then
        return false
    end

    if NORMAL_MAX_SLOTS[name] ~= nil then
        return true
    end

    if lower:find("chest", 1, true)
        or lower:find("strongbox", 1, true)
        or lower:find("lockbox", 1, true)
        or lower:find("coffer", 1, true)
    then
        return true
    end

    if fromOpeningCast and lower == "chest" then
        return true
    end

    return false
end

local TIER_STYLES = {
    legendary = {
        label = "Legendary",
        color = "|cffff8000",
        chestColor = "|cffFFD700",
        goldPlated = true,
        r = 1.0, g = 0.50, b = 0.0,
        soundFallback = 12891,
    },
    epic = {
        label = "Epic",
        color = "|cffa335ee",
        chestColor = "|cffE5B80B",
        goldPlated = true,
        r = 0.64, g = 0.21, b = 0.93,
        soundFile = SOUND_BASE_PATH .. "Epic.ogg",
        soundFallback = 888,
    },
    rare = {
        label = "Rare",
        color = "|cff0070dd",
        chestColor = "|cffffffff",
        goldPlated = false,
        r = 0.0, g = 0.44, b = 0.87,
        soundFile = SOUND_BASE_PATH .. "Rare.ogg",
        soundFallback = 888,
    },
    uncommon = {
        label = "Uncommon",
        color = "|cff1eff00",
        chestColor = "|cffffffff",
        goldPlated = false,
        r = 0.12, g = 1.0, b = 0.0,
        soundCandidates = UNCOMMON_SOUND_CANDIDATES,
        soundFallback = 120,
    },
    common = {
        label = "Common",
        color = "|cffffffff",
        chestColor = "|cffffffff",
        goldPlated = false,
        r = 1.0, g = 1.0, b = 1.0,
        soundFallback = nil,
    },
}

local mainFrame = CreateFrame("Frame", "FindTreasureMainFrame")
mainFrame:SetSize(560, 625)

local function OpenAddonSettings()
    if Settings and Settings.OpenToCategory and SettingsCategoryID then
        Settings.OpenToCategory(SettingsCategoryID)
    elseif InterfaceOptionsFrame_OpenToCategory and mainFrame then
        InterfaceOptionsFrame_OpenToCategory(mainFrame)
        InterfaceOptionsFrame_OpenToCategory(mainFrame)
    end
end

local function GetFindTreasureRacialIcon()
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(FIND_TREASURE_ID)
        if tex then return tex end
    end
    if GetSpellTexture then
        local tex = GetSpellTexture(FIND_TREASURE_ID)
        if tex then return tex end
    end
    return COIN_TEXTURE_PATH
end

local function ApplyCoinTexture(tex, parentFrame, textureOverride, cropMin, cropMax)
    if not tex then return end
    tex:SetTexture(textureOverride or COIN_TEXTURE_PATH)
    if tex.SetTexCoord then
        local c0 = cropMin or 0.18
        local c1 = cropMax or 0.82
        tex:SetTexCoord(c0, c1, c0, c1)
    end
    if parentFrame and parentFrame.CreateMaskTexture and tex.AddMaskTexture and not tex.ftMaskAdded then
        local mask = parentFrame:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(tex)
        tex:AddMaskTexture(mask)
        tex.ftMaskAdded = true
    end
end

--------------------------------------------------------------------------------
-- Bottom-Screen Gold Coin Fountain + Top-Banner Glow & Sparkles (Legendary)
--------------------------------------------------------------------------------
local coinStage = CreateFrame("Frame", "FindTreasureCoinStage", UIParent)
coinStage:SetAllPoints(UIParent)
coinStage:SetFrameStrata("FULLSCREEN_DIALOG")
coinStage:SetFrameLevel(50)
coinStage:Hide()

local edgeGlowFrame = CreateFrame("Frame", "FindTreasureEdgeGlow", coinStage)
edgeGlowFrame:SetAllPoints(coinStage)
edgeGlowFrame:SetFrameLevel(48)

local topGlow = edgeGlowFrame:CreateTexture(nil, "BACKGROUND")
topGlow:SetPoint("TOPLEFT", edgeGlowFrame, "TOPLEFT", 0, 0)
topGlow:SetPoint("TOPRIGHT", edgeGlowFrame, "TOPRIGHT", 0, 0)
topGlow:SetHeight(108)
topGlow:SetTexture("Interface\\Cooldown\\starburst")
topGlow:SetBlendMode("ADD")
topGlow:SetVertexColor(1.0, 0.84, 0.22, 0.55)

local SPARKLE_POOL_SIZE = 42
local sparklePool = {}
local activeSparkles = {}

for i = 1, SPARKLE_POOL_SIZE do
    local s = edgeGlowFrame:CreateTexture(nil, "OVERLAY")
    s:SetSize(20, 20)
    s:SetTexture("Interface\\Cooldown\\star4")
    s:SetBlendMode("ADD")
    s:SetVertexColor(1.0, 0.92, 0.45, 0.98)
    s:Hide()
    sparklePool[i] = s
end

local function AcquireSparkleTexture()
    for _, s in ipairs(sparklePool) do
        if not s.inUse then
            return s
        end
    end
    return nil
end

local edgeGlowDuration = 0
local edgeGlowElapsed = 0

local function SpawnTopBannerSparkles(screenW, screenH, duration)
    local halfW = math.floor(screenW * 0.49)
    local halfH = math.floor(screenH * 0.50)

    for i = 1, SPARKLE_POOL_SIZE do
        local sp = AcquireSparkleTexture()
        if not sp then break end

        local sx = math.random(-halfW, halfW)
        local sy = halfH - math.random(4, 42)

        sp.inUse = true
        sp.x = sx
        sp.y = sy
        sp.delay = math.random() * 1.4
        sp.life = 0.85 + math.random() * 0.65
        sp.age = 0
        sp.baseSize = 15 + math.random() * 11
        sp.phase = math.random() * 6.28

        sp:SetSize(sp.baseSize, sp.baseSize)
        sp:ClearAllPoints()
        sp:SetPoint("CENTER", edgeGlowFrame, "CENTER", sp.x, sp.y)
        sp:SetAlpha(0)
        sp:Hide()

        table.insert(activeSparkles, sp)
    end

    edgeGlowElapsed = 0
    edgeGlowDuration = duration or 3.65
end

local function TriggerTopBannerGlow()
    local screenW = (UIParent and UIParent:GetWidth()) or 1280
    local screenH = (UIParent and UIParent:GetHeight()) or 720
    SpawnTopBannerSparkles(screenW, screenH, 3.65)
    coinStage:Show()
end

local COIN_POOL_SIZE = 45
local coinPool = {}
local activeCoins = {}

for i = 1, COIN_POOL_SIZE do
    local c = coinStage:CreateTexture(nil, "OVERLAY")
    c:SetSize(28, 28)
    ApplyCoinTexture(c, coinStage, GetFindTreasureRacialIcon(), 0.18, 0.82)
    c:Hide()
    coinPool[i] = c
end

local function AcquireCoinTexture()
    for _, c in ipairs(coinPool) do
        if not c.inUse then
            return c
        end
    end
    return nil
end

local function SpawnLegendaryCoinFountain()
    local screenW = (UIParent and UIParent:GetWidth()) or 1280
    local screenH = (UIParent and UIParent:GetHeight()) or 720
    local startY = -screenH * 0.48
    local gravity = 1250
    local count = 42
    local racialIcon = GetFindTreasureRacialIcon()

    for i = 1, count do
        local tex = AcquireCoinTexture()
        if not tex then break end

        ApplyCoinTexture(tex, coinStage, racialIcon, 0.18, 0.82)

        local startX = math.random(-math.floor(screenW * 0.16), math.floor(screenW * 0.16))
        local vx = (math.random() * 2 - 1) * 410
        local vy = 980 + math.random() * 340
        local delay = (i - 1) * 0.022
        local life = 3.25 + math.random() * 0.45

        tex.inUse = true
        tex.x = startX
        tex.y = startY
        tex.vx = vx
        tex.vy = vy
        tex.gravity = gravity
        tex.delay = delay
        tex.age = 0
        tex.life = life
        tex.baseSize = 28
        tex.spinSpeed = 9 + math.random() * 7
        tex.spinPhase = math.random() * 6.28

        tex:SetSize(tex.baseSize, tex.baseSize)
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", coinStage, "CENTER", tex.x, tex.y)
        tex:SetAlpha(0)
        tex:Hide()

        table.insert(activeCoins, tex)
    end

    TriggerTopBannerGlow()
end

coinStage:SetScript("OnUpdate", function(self, elapsed)
    local dt = elapsed or 0
    if #activeCoins == 0 and #activeSparkles == 0 and edgeGlowElapsed >= edgeGlowDuration then
        self:Hide()
        return
    end

    if edgeGlowElapsed < edgeGlowDuration then
        edgeGlowElapsed = edgeGlowElapsed + dt
        local progress = math.min(1, edgeGlowElapsed / edgeGlowDuration)
        local pulse = 0.70 + 0.30 * math.sin(edgeGlowElapsed * 5.5)
        local envelope = (progress > 0.72) and math.max(0, 1 - ((progress - 0.72) / 0.28)) or 1
        topGlow:SetAlpha(0.54 * pulse * envelope)
    else
        topGlow:SetAlpha(0)
    end

    for i = #activeSparkles, 1, -1 do
        local sp = activeSparkles[i]
        sp.age = sp.age + dt
        if sp.age >= sp.delay then
            local st = sp.age - sp.delay
            if st >= sp.life then
                sp:Hide()
                sp:SetAlpha(1)
                sp.inUse = false
                table.remove(activeSparkles, i)
            else
                sp:Show()
                local twinkle = 0.5 + 0.5 * math.sin(sp.phase + st * 12)
                local lifeFade = (st > sp.life * 0.65) and math.max(0, 1 - ((st - sp.life * 0.65) / (sp.life * 0.35))) or 1
                local sz = sp.baseSize * (0.75 + 0.35 * twinkle)
                sp:SetSize(sz, sz)
                sp:SetAlpha(twinkle * lifeFade * 0.96)
            end
        end
    end

    for i = #activeCoins, 1, -1 do
        local c = activeCoins[i]
        c.age = c.age + dt

        if c.age >= c.delay then
            local t = c.age - c.delay
            if t >= c.life then
                c:Hide()
                c:SetAlpha(1)
                c.inUse = false
                table.remove(activeCoins, i)
            else
                c:Show()
                local px = c.x + (c.vx * t)
                local py = c.y + (c.vy * t) - (0.5 * c.gravity * t * t)

                local flipCos = math.cos(c.spinPhase + (t * c.spinSpeed))
                local widthScale = math.max(0.18, math.abs(flipCos))
                local heightScale = 0.96 + 0.04 * math.sin(c.spinPhase + (t * c.spinSpeed))

                c:ClearAllPoints()
                c:SetPoint("CENTER", coinStage, "CENTER", px, py)
                c:SetSize(c.baseSize * widthScale, c.baseSize * heightScale)

                local fadeStart = c.life * 0.78
                if t > fadeStart then
                    c:SetAlpha(math.max(0, 1 - ((t - fadeStart) / (c.life - fadeStart))))
                else
                    c:SetAlpha(1)
                end
            end
        end
    end

    if #activeCoins == 0 and #activeSparkles == 0 and edgeGlowElapsed >= edgeGlowDuration then
        self:Hide()
    end
end)

--------------------------------------------------------------------------------
-- Database & Helper Functions
--------------------------------------------------------------------------------
local function CreateEmptyBucket()
    return {
        chests = 0,
        totalCopperValue = 0,
        totalAHCopperValue = 0,
        maxSlotsSeen = 0,
        maxSlotsChest = "",
        mostValuableDropLink = "",
        mostValuableDropValue = 0,
        mostValuableDropSource = "",
        topAHItems = {},
        legendaryChests = 0,
        epicChests = 0,
        rareChests = 0,
        uncommonChests = 0,
        commonChests = 0,
        procs = 0,
        byChest = {},
    }
end

local function InitDB()
    if type(FindTreasureDB) ~= "table" then
        FindTreasureDB = {}
    end
    for _, key in ipairs({ "dwarfActive", "humanOrOther" }) do
        if type(FindTreasureDB[key]) ~= "table" then
            FindTreasureDB[key] = CreateEmptyBucket()
        else
            local defaults = CreateEmptyBucket()
            for k, v in pairs(defaults) do
                if FindTreasureDB[key][k] == nil then
                    FindTreasureDB[key][k] = v
                end
            end
            if type(FindTreasureDB[key].totalCopperValue) ~= "number" then
                FindTreasureDB[key].totalCopperValue = FindTreasureDB[key].totalCopper or 0
            end
            if type(FindTreasureDB[key].totalAHCopperValue) ~= "number" then
                FindTreasureDB[key].totalAHCopperValue = 0
            end
            if type(FindTreasureDB[key].topAHItems) ~= "table" then
                FindTreasureDB[key].topAHItems = {}
            end
            if (FindTreasureDB[key].mostValuableDropValue or 0) <= 0 and type(FindTreasureDB[key].biggestItemValue) == "number" then
                FindTreasureDB[key].mostValuableDropValue = FindTreasureDB[key].biggestItemValue
                FindTreasureDB[key].mostValuableDropLink = FindTreasureDB[key].biggestItemLink or ""
                FindTreasureDB[key].mostValuableDropSource = FindTreasureDB[key].biggestItemSource or ""
            end
            if type(FindTreasureDB[key].mostValuableDropValue) ~= "number" then
                FindTreasureDB[key].mostValuableDropValue = 0
            end
            if type(FindTreasureDB[key].mostValuableDropLink) ~= "string" then
                FindTreasureDB[key].mostValuableDropLink = ""
            end
            if type(FindTreasureDB[key].mostValuableDropSource) ~= "string" then
                FindTreasureDB[key].mostValuableDropSource = ""
            end
            if type(FindTreasureDB[key].byChest) == "table" then
                for cName in pairs(FindTreasureDB[key].byChest) do
                    if not IsTrackedChestName(cName, false) then
                        FindTreasureDB[key].byChest[cName] = nil
                    end
                end
            end
        end
    end
    if type(FindTreasureDB.minimapAngle) ~= "number" then
        FindTreasureDB.minimapAngle = 220
    end
    if type(FindTreasureDB.enableLegendaryFeature) ~= "boolean" then
        FindTreasureDB.enableLegendaryFeature = true
    end
    if type(FindTreasureDB.allowInactiveAuraProcs) ~= "boolean" then
        FindTreasureDB.allowInactiveAuraProcs = false
    end
end

local function IsLegendaryFeatureEnabled()
    InitDB()
    return FindTreasureDB.enableLegendaryFeature ~= false
end

local function IsInactiveAuraProcsEnabled()
    InitDB()
    return FindTreasureDB.allowInactiveAuraProcs == true
end

local function PlaySoundFileCandidates(candidates)
    if not PlaySoundFile or type(candidates) ~= "table" then return false end
    for _, path in ipairs(candidates) do
        if type(path) == "string" and path ~= "" then
            if PlaySoundFile(path, "Master") then
                return true
            end
        end
    end
    return false
end

local function PlayLegendaryJackpotAudio(style, includeFeatureSound)
    local anyPlayed = false
    if PlaySoundFile then
        if LEGENDARY_PRIMARY_SOUND and LEGENDARY_PRIMARY_SOUND ~= "" then
            if PlaySoundFile(LEGENDARY_PRIMARY_SOUND, "Master") then
                anyPlayed = true
            end
        end
        if includeFeatureSound and LEGENDARY_SECONDARY_SOUND and LEGENDARY_SECONDARY_SOUND ~= "" then
            if PlaySoundFile(LEGENDARY_SECONDARY_SOUND, "Master") then
                anyPlayed = true
            end
        end
    end
    if not anyPlayed and PlaySound and style and style.soundFallback then
        PlaySound(style.soundFallback, "Master")
    end
end

local function PlayTierFeedback(tierKey)
    local style = TIER_STYLES[tierKey] or TIER_STYLES.uncommon
    if tierKey == "legendary" then
        local featureEnabled = IsLegendaryFeatureEnabled()
        if featureEnabled then
            SpawnLegendaryCoinFountain()
        else
            TriggerTopBannerGlow()
        end
        PlayLegendaryJackpotAudio(style, featureEnabled)
    else
        local playedFile = false
        if style.soundCandidates then
            playedFile = PlaySoundFileCandidates(style.soundCandidates)
        elseif PlaySoundFile and style.soundFile and style.soundFile ~= "" then
            playedFile = PlaySoundFile(style.soundFile, "Master") and true or false
        end
        if not playedFile and PlaySound and style.soundFallback then
            PlaySound(style.soundFallback, "Master")
        end
    end
end

local function HasFindTreasureActive()
    if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
        for i = 1, (C_Minimap.GetNumTrackingTypes() or 0) do
            local info = C_Minimap.GetTrackingInfo(i)
            if type(info) == "table" then
                if info.spellID == FIND_TREASURE_ID and info.active then
                    return true
                end
            else
                local _, _, active, _, _, spellID = C_Minimap.GetTrackingInfo(i)
                if spellID == FIND_TREASURE_ID and active then
                    return true
                end
            end
        end
    end
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(FIND_TREASURE_ID) ~= nil
    end
    return false
end

local function IsPlayerDwarf()
    if not UnitRace then
        return true
    end
    local race = UnitRace("player")
    return race == "Dwarf"
end

local function GetSpellNameSafe(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    elseif C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end
    return nil
end

local function ParseCoinToCopper(text)
    if type(text) ~= "string" then return 0 end
    local gold = tonumber(text:match("(%d+)%s*Gold")) or 0
    local silver = tonumber(text:match("(%d+)%s*Silver")) or 0
    local copper = tonumber(text:match("(%d+)%s*Copper")) or 0
    return (gold * 10000) + (silver * 100) + copper
end

local function GetItemVendorSellCopper(link, quantity)
    local qty = (type(quantity) == "number" and quantity > 0) and quantity or 1
    if type(link) ~= "string" or link == "" then
        return 0
    end
    local sellPrice = 0
    if C_Item and C_Item.GetItemInfo then
        local info = { C_Item.GetItemInfo(link) }
        sellPrice = tonumber(info[11]) or 0
    elseif GetItemInfo then
        local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
        sellPrice = tonumber(vendorPrice) or 0
    end
    if sellPrice <= 0 and C_Item and C_Item.RequestLoadItemDataByID and C_Item.GetItemInfoInstant then
        local itemID = C_Item.GetItemInfoInstant(link)
        if itemID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
    return math.max(0, sellPrice) * qty
end

local function GetItemAHUnitCopper(link)
    if type(link) ~= "string" or link == "" then
        return 0
    end
    local itemID = nil
    if C_Item and C_Item.GetItemInfoInstant then
        itemID = C_Item.GetItemInfoInstant(link)
    elseif GetItemInfoInstant then
        itemID = GetItemInfoInstant(link)
    end

    if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemLink then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemLink, ADDON_NAME, link)
        if ok and type(price) == "number" and price > 0 then
            return math.floor(price)
        end
    end
    if Auctionator and Auctionator.API and Auctionator.API.v1 and itemID and Auctionator.API.v1.GetAuctionPriceByItemID then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON_NAME, itemID)
        if ok and type(price) == "number" and price > 0 then
            return math.floor(price)
        end
    end
    if TSM_API and TSM_API.GetCustomPriceValue and TSM_API.ToItemString then
        local okTSMString, itemString = pcall(TSM_API.ToItemString, link)
        if okTSMString and itemString then
            local okPrice, price = pcall(TSM_API.GetCustomPriceValue, "DBMinBuyout", itemString)
            if okPrice and type(price) == "number" and price > 0 then
                return math.floor(price)
            end
        end
    end
    if type(GetAuctionBuyout) == "function" then
        local ok, price = pcall(GetAuctionBuyout, link)
        if ok and type(price) == "number" and price > 0 then
            return math.floor(price)
        end
    end
    return 0
end

local function GetItemAHSellCopper(link, quantity)
    local qty = (type(quantity) == "number" and quantity > 0) and quantity or 1
    local unitAH = GetItemAHUnitCopper(link)
    return math.max(0, unitAH) * qty
end

local function FormatCopper(copper)
    copper = math.floor((tonumber(copper) or 0) + 0.5)
    if copper <= 0 then return "0c" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, g .. "g") end
    if s > 0 then table.insert(parts, s .. "s") end
    if c > 0 or #parts == 0 then table.insert(parts, c .. "c") end
    return table.concat(parts, " ")
end

local function RecordMostValuableDrop(bucket, link, quantity, vendorCopper, ahCopper)
    if type(link) ~= "string" or link == "" then return end
    local qty = (type(quantity) == "number" and quantity > 1) and quantity or 1
    local bestVal = math.max(vendorCopper or 0, ahCopper or 0)
    if bestVal <= 0 then return end

    if bestVal > (bucket.mostValuableDropValue or 0) then
        local sourceLabel = ((ahCopper or 0) >= (vendorCopper or 0) and (ahCopper or 0) > 0) and "AH" or "Vendor"
        bucket.mostValuableDropValue = bestVal
        bucket.mostValuableDropLink = (qty > 1) and (link .. "x" .. qty) or link
        bucket.mostValuableDropSource = sourceLabel
    end
end

local function RecordTopAHItem(bucket, link, quantity, ahCopper, sourceChest)
    if type(link) ~= "string" or link == "" then return end
    local val = math.floor(tonumber(ahCopper) or 0)
    if val <= 0 then return end

    bucket.topAHItems = bucket.topAHItems or {}
    local qty = (type(quantity) == "number" and quantity > 1) and quantity or 1
    local displayLabel = (qty > 1) and (link .. "x" .. qty) or link
    local chestLabel = (type(sourceChest) == "string" and sourceChest ~= "") and sourceChest or "Chest"

    local replaced = false
    for _, entry in ipairs(bucket.topAHItems) do
        if entry.link == link then
            if val > (entry.ahValue or 0) then
                entry.label = displayLabel
                entry.ahValue = val
                entry.chest = chestLabel
            end
            replaced = true
            break
        end
    end

    if not replaced then
        table.insert(bucket.topAHItems, {
            link = link,
            label = displayLabel,
            ahValue = val,
            chest = chestLabel,
        })
    end

    table.sort(bucket.topAHItems, function(a, b)
        return (a.ahValue or 0) > (b.ahValue or 0)
    end)

    while #bucket.topAHItems > TOP_AH_LIMIT do
        table.remove(bucket.topAHItems)
    end
end

local function FormatMostValuableDropText(b)
    local val = b.mostValuableDropValue or 0
    local link = b.mostValuableDropLink or ""
    if val <= 0 or link == "" then
        return "|cffB0B0B0None|r"
    end
    local src = (type(b.mostValuableDropSource) == "string" and b.mostValuableDropSource ~= "") and (" " .. b.mostValuableDropSource) or ""
    return string.format("|cffFFD700%s|r |cffFFFFFF(%s%s)|r", link, FormatCopper(val), src)
end

local function ClassifyChestBySlots(numSlots, maxExpected)
    local bonus = numSlots - (maxExpected or 4)
    if bonus >= 4 then
        return "legendary", true
    elseif bonus == 3 then
        return "epic", true
    elseif bonus == 2 then
        return "rare", true
    elseif bonus == 1 then
        return "uncommon", true
    else
        return "common", false
    end
end

local function FormatTierCountPct(colorHex, count, pct)
    return string.format("%s%d (%.0f%%)|r", colorHex, count or 0, pct or 0)
end

local function FormatMaxSlotsText(b)
    local maxS = b.maxSlotsSeen or 0
    if maxS <= 0 then
        return "|cffB0B0B00|r"
    end
    local cLabel = (type(b.maxSlotsChest) == "string" and b.maxSlotsChest ~= "") and string.format(" (%s)", b.maxSlotsChest) or ""
    return string.format("|cffB0B0B0%d%s|r", maxS, cLabel)
end

--------------------------------------------------------------------------------
-- Chat Output, Safe Debug Sniffer & Slash Commands
--------------------------------------------------------------------------------
local function SayMessageSafe(msg)
    if type(msg) ~= "string" or msg == "" then return end
    if SendChatMessage then
        SendChatMessage(msg, "SAY")
    else
        print(msg)
    end
end

local function ShareActiveStatsToSay()
    InitDB()
    local b = FindTreasureDB.dwarfActive
    local c = b.chests or 0
    local procs = b.procs or 0
    local procRate = c > 0 and ((procs / c) * 100) or 0
    local pctLeg = c > 0 and (((b.legendaryChests or 0) / c) * 100) or 0
    local pctEpic = c > 0 and (((b.epicChests or 0) / c) * 100) or 0
    local pctRare = c > 0 and (((b.rareChests or 0) / c) * 100) or 0
    local pctUncommon = c > 0 and (((b.uncommonChests or 0) / c) * 100) or 0
    local pctCommon = c > 0 and (((b.commonChests or 0) / c) * 100) or 0
    local maxS = b.maxSlotsSeen or 0
    local maxLabel = (maxS > 0 and type(b.maxSlotsChest) == "string" and b.maxSlotsChest ~= "")
        and string.format("%d (%s)", maxS, b.maxSlotsChest)
        or tostring(maxS)
    local topDropLabel = ((b.mostValuableDropValue or 0) > 0 and (b.mostValuableDropLink or "") ~= "")
        and string.format("%s (%s %s)", b.mostValuableDropLink, FormatCopper(b.mostValuableDropValue), b.mostValuableDropSource or "")
        or "None"

    SayMessageSafe("=== Find Treasure Tracker ===")
    SayMessageSafe(string.format("Find Treasure Active · %d Chests", c))
    SayMessageSafe(string.format("Proc Count: %d", procs))
    SayMessageSafe(string.format("Proc Rate: %.0f%%", procRate))
    SayMessageSafe(string.format("Legendary: %d (%.0f%%)", b.legendaryChests or 0, pctLeg))
    SayMessageSafe(string.format("Epic: %d (%.0f%%)", b.epicChests or 0, pctEpic))
    SayMessageSafe(string.format("Rare: %d (%.0f%%)", b.rareChests or 0, pctRare))
    SayMessageSafe(string.format("Uncommon: %d (%.0f%%)", b.uncommonChests or 0, pctUncommon))
    SayMessageSafe(string.format("Common: %d (%.0f%%)", b.commonChests or 0, pctCommon))
    SayMessageSafe(string.format("Max Slots Seen: %s", maxLabel))
    SayMessageSafe(string.format("Most Valuable Drop: %s", topDropLabel))
    SayMessageSafe(string.format("Vendor Value: %s", FormatCopper(b.totalCopperValue or 0)))
    SayMessageSafe(string.format("AH Value: %s", FormatCopper(b.totalAHCopperValue or 0)))
end

local function PrintChestLog(filterName)
    InitDB()
    local query = (type(filterName) == "string" and filterName ~= "") and filterName:lower() or nil
    print("|cffFFD100=== Logged Chest Contents ===|r")

    for _, group in ipairs({
        { key = "dwarfActive", label = "|cff00FF00[Find Treasure Active]|r" },
        { key = "humanOrOther", label = "|cffffffff[Find Treasure Inactive]|r" },
    }) do
        local bucket = FindTreasureDB[group.key]
        local anyForGroup = false
        for cName, entry in pairs(bucket.byChest or {}) do
            if IsTrackedChestName(cName, false) and (not query or cName:lower():find(query, 1, true)) then
                if not anyForGroup then
                    anyForGroup = true
                    print(string.format("%s Most Valuable Drop: %s", group.label, FormatMostValuableDropText(bucket)))
                end
                local runs = entry.runs or {}
                local cCount = entry.chests or 0
                local expSlots = NORMAL_MAX_SLOTS[cName] or 4
                local cMax = entry.maxSlotsSeen or 0
                print(string.format("%s %s (exp %d, max %d): %d opened", group.label, cName, expSlots, cMax, cCount))
                local startIdx = math.max(1, #runs - 4)
                for idx = startIdx, #runs do
                    local r = runs[idx]
                    local formattedItems = {}
                    for _, itemLabel in ipairs(r.items or {}) do
                        if bucket.mostValuableDropLink ~= "" and itemLabel == bucket.mostValuableDropLink then
                            table.insert(formattedItems, "|cffFFD700[TOP VALUE]|r " .. itemLabel)
                        else
                            table.insert(formattedItems, itemLabel)
                        end
                    end
                    local itemsText = (#formattedItems > 0) and table.concat(formattedItems, ", ") or "Empty"
                    print(string.format("   #%d (%d slots): %s", idx, r.slots or 0, itemsText))
                end
            end
        end
    end
end

local function PrintChestComparison()
    InitDB()
    local onBucket = FindTreasureDB.dwarfActive
    local offBucket = FindTreasureDB.humanOrOther

    local onChests = onBucket.chests or 0
    local offChests = offBucket.chests or 0

    print("|cffFFD100=== Find Treasure On vs. Off Comparison ===|r")

    if onChests == 0 or offChests == 0 then
        print(string.format("Need data for both states to compare average value (FT On: %d chests | FT Off: %d chests).", onChests, offChests))
        return
    end

    local onAHAvg = (onBucket.totalAHCopperValue or 0) / onChests
    local offAHAvg = (offBucket.totalAHCopperValue or 0) / offChests

    local useAH = (onAHAvg > 0 and offAHAvg > 0)
    local metricLabel = useAH and "AH" or "Vendor"
    local onAvg = useAH and onAHAvg or ((onBucket.totalCopperValue or 0) / onChests)
    local offAvg = useAH and offAHAvg or ((offBucket.totalCopperValue or 0) / offChests)

    if offAvg <= 0 then
        print(string.format("FT On avg (%s): %s (%d chests) | FT Off avg (%s): %s (%d chests) — cannot calculate %% difference from 0.",
            metricLabel, FormatCopper(onAvg), onChests, metricLabel, FormatCopper(offAvg), offChests))
        return
    end

    local pctDiff = ((onAvg - offAvg) / offAvg) * 100
    local direction = pctDiff >= 0 and "|cff00FF00better|r" or "|cffFF5555worse|r"

    print(string.format("Loot using Find Treasure has been |cffFFD100%.1f%%|r %s on average than FT inactive (%s avg: %s vs %s across %d vs %d chests).",
        math.abs(pctDiff), direction, metricLabel, FormatCopper(onAvg), FormatCopper(offAvg), onChests, offChests))
end

local SyncSettingsControls
local function ResetStatsKeepAngle()
    InitDB()
    local savedAngle = FindTreasureDB.minimapAngle
    local savedFeature = IsLegendaryFeatureEnabled()
    local savedInactiveProcs = IsInactiveAuraProcsEnabled()
    FindTreasureDB = nil
    InitDB()
    FindTreasureDB.minimapAngle = savedAngle
    FindTreasureDB.enableLegendaryFeature = savedFeature
    FindTreasureDB.allowInactiveAuraProcs = savedInactiveProcs
    if SyncSettingsControls then
        SyncSettingsControls()
    end
    print("|cffFFD100[Find Treasure]|r Stats and chest logs reset.")
end

StaticPopupDialogs["FTT_CONFIRM_RESET_STATS"] = {
    text = "Are you sure you want to reset all Find Treasure Tracker stats and chest logs?\n\nYour minimap position and settings toggles will be kept.",
    button1 = "Reset Stats",
    button2 = CANCEL,
    OnAccept = function()
        ResetStatsKeepAngle()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function PromptResetStatsConfirmation()
    if StaticPopup_Show then
        StaticPopup_Show("FTT_CONFIRM_RESET_STATS")
    else
        ResetStatsKeepAngle()
    end
end

local function FormatAlertMessage(style, targetChest, isNewRecord)
    local chestColor = style.goldPlated and (style.chestColor or "|cffFFD700") or (style.chestColor or "|cffffffff")
    local recordTag = isNewRecord and " |cffFFD100(New Record!)|r" or ""
    return string.format("%s%s Find|r %s- %s|r%s",
        style.color, style.label, chestColor, targetChest, recordTag)
end

local function PreviewTierProc(tierArg)
    local key = (type(tierArg) == "string" and tierArg ~= "") and tierArg:lower() or "legendary"
    if not TIER_STYLES[key] or key == "common" then
        key = "legendary"
    end
    local style = TIER_STYLES[key]
    local msg = FormatAlertMessage(style, "Battered Chest", false)

    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    end
    print("|cffFFD100[Find Treasure]|r " .. msg)
    PlayTierFeedback(key)
end

local debugEvents = false
local debugFrame = CreateFrame("Frame")
debugFrame:SetScript("OnEvent", function(_, event, ...)
    if not debugEvents then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            local name = GetSpellNameSafe(spellID) or "Unknown"
            print(string.format("|cff00FFFF[FT Debug]|r Cast Succeeded: %s (ID: %s)", tostring(name), tostring(spellID)))
        end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            print("|cff00FFFF[FT Debug]|r Player UNIT_AURA updated")
        end
    else
        print("|cff00FFFF[FT Debug]|r " .. event, ...)
    end
end)

local function ToggleEventDebug()
    debugEvents = not debugEvents
    if debugEvents then
        debugFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        debugFrame:RegisterUnitEvent("UNIT_AURA", "player")
        debugFrame:RegisterEvent("CHAT_MSG_SYSTEM")
        debugFrame:RegisterEvent("LOOT_READY")
        debugFrame:RegisterEvent("LOOT_OPENED")
        print("|cffFFD100[Find Treasure]|r Safe event debug |cff00FF00ENABLED|r (or use Blizzard's /etrace).")
    else
        debugFrame:UnregisterAllEvents()
        print("|cffFFD100[Find Treasure]|r Safe event debug |cffFF5555DISABLED|r.")
    end
    if SyncSettingsControls then
        SyncSettingsControls()
    end
end

--------------------------------------------------------------------------------
-- Clean Radial Minimap Button & Clean Tooltip
--------------------------------------------------------------------------------
local minimapBtn = CreateFrame("Button", "FindTreasureMinimapButton", Minimap or UIParent)
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(20)
minimapBtn:SetClampedToScreen(true)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = minimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)
ApplyCoinTexture(icon, minimapBtn, TRACKER_ICON_TEXTURE, 0.08, 0.92)

local function UpdateTrackerIconState()
    if not icon then return end
    if HasFindTreasureActive() or not IsPlayerDwarf() then
        icon:SetVertexColor(1.0, 1.0, 1.0)
    else
        icon:SetVertexColor(1.0, 0.32, 0.32)
    end
end

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetSize(52, 52)
border:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 0, 0)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdateMinimapButtonPosition()
    local angle = math.rad((FindTreasureDB and FindTreasureDB.minimapAngle) or 220)
    local radius = ((Minimap and Minimap:GetWidth()) or 140) / 2 + 6
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapBtn:ClearAllPoints()
    if Minimap and Minimap:GetWidth() and Minimap:GetWidth() > 0 then
        minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    else
        minimapBtn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -180, -180)
    end
    minimapBtn:Show()
end

minimapBtn:RegisterForDrag("RightButton")
minimapBtn:SetScript("OnDragStart", function(self)
    if not Minimap then return end
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        if not mx or not my then return end
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale() or 1
        cx, cy = cx / scale, cy / scale
        FindTreasureDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
        UpdateMinimapButtonPosition()
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

local function AddBucketTooltipLines(title, r, g, bColor, b, showProcStats)
    local c = b.chests or 0
    local pctLeg = c > 0 and (((b.legendaryChests or 0) / c) * 100) or 0
    local pctEpic = c > 0 and (((b.epicChests or 0) / c) * 100) or 0
    local pctRare = c > 0 and (((b.rareChests or 0) / c) * 100) or 0
    local pctUncommon = c > 0 and (((b.uncommonChests or 0) / c) * 100) or 0
    local pctCommon = c > 0 and (((b.commonChests or 0) / c) * 100) or 0

    GameTooltip:AddLine(string.format("%s · %d Chests", title, c), r, g, bColor)
    if showProcStats then
        local procs = b.procs or 0
        local procRate = c > 0 and ((procs / c) * 100) or 0
        GameTooltip:AddDoubleLine("Proc Count:", string.format("|cffFFD100%d|r", procs), 0.69, 0.69, 0.69, 1.0, 0.82, 0.0)
        GameTooltip:AddDoubleLine("Proc Rate:", string.format("|cffFFD100%.0f%%|r", procRate), 0.69, 0.69, 0.69, 1.0, 0.82, 0.0)
    end
    GameTooltip:AddDoubleLine("Legendary:", FormatTierCountPct("|cffff8000", b.legendaryChests or 0, pctLeg), 0.69, 0.69, 0.69, 1.0, 0.50, 0.0)
    GameTooltip:AddDoubleLine("Epic:", FormatTierCountPct("|cffa335ee", b.epicChests or 0, pctEpic), 0.69, 0.69, 0.69, 0.64, 0.21, 0.93)
    GameTooltip:AddDoubleLine("Rare:", FormatTierCountPct("|cff0070dd", b.rareChests or 0, pctRare), 0.69, 0.69, 0.69, 0.0, 0.44, 0.87)
    GameTooltip:AddDoubleLine("Uncommon:", FormatTierCountPct("|cff1eff00", b.uncommonChests or 0, pctUncommon), 0.69, 0.69, 0.69, 0.12, 1.0, 0.0)
    GameTooltip:AddDoubleLine("Common:", FormatTierCountPct("|cffB0B0B0", b.commonChests or 0, pctCommon), 0.69, 0.69, 0.69, 0.69, 0.69, 0.69)
    GameTooltip:AddDoubleLine("Max Slots Seen:", FormatMaxSlotsText(b), 0.69, 0.69, 0.69, 0.69, 0.69, 0.69)
    GameTooltip:AddDoubleLine("Most Valuable Drop:", FormatMostValuableDropText(b), 1.0, 0.84, 0.2, 1.0, 0.84, 0.2)
    GameTooltip:AddDoubleLine("Vendor Value:", string.format("|cffFFD100%s|r", FormatCopper(b.totalCopperValue or 0)), 0.69, 0.69, 0.69, 1.0, 0.82, 0.0)
    GameTooltip:AddDoubleLine("AH Value:", string.format("|cffFFD100%s|r", FormatCopper(b.totalAHCopperValue or 0)), 0.69, 0.69, 0.69, 1.0, 0.82, 0.0)
end

minimapBtn:SetScript("OnEnter", function(self)
    InitDB()
    UpdateTrackerIconState()
    local d = FindTreasureDB.dwarfActive
    local h = FindTreasureDB.humanOrOther
    local isTracking = HasFindTreasureActive()

    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Find Treasure Tracker", 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Find Treasure:", isTracking and "|cff00FF00Active|r" or "|cffB0B0B0Inactive|r", 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine(" ")

    AddBucketTooltipLines("Find Treasure Active", 0.2, 1.0, 0.2, d, true)
    GameTooltip:AddLine(" ")
    AddBucketTooltipLines("Find Treasure Inactive", 1.0, 1.0, 1.0, h, false)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-Click: Open settings", 1, 1, 1)
    GameTooltip:AddLine("Right-Click Drag: Move button around minimap", 1, 1, 1)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

minimapBtn:RegisterForClicks("LeftButtonUp")
minimapBtn:SetScript("OnClick", function()
    UpdateTrackerIconState()
    OpenAddonSettings()
end)

--------------------------------------------------------------------------------
-- Main Options > AddOns Page
--------------------------------------------------------------------------------
local titleText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
titleText:SetPoint("TOPLEFT", 16, -16)
titleText:SetText("Find Treasure Tracker")

local subheadingText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
subheadingText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -14)
subheadingText:SetText("How It Works")

local howItWorksText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
howItWorksText:SetPoint("TOPLEFT", subheadingText, "BOTTOMLEFT", 0, -10)
howItWorksText:SetWidth(520)
howItWorksText:SetJustifyH("LEFT")
howItWorksText:SetSpacing(6)
howItWorksText:SetText(
    "• Chest Rarity Tiers: Opened chests are grouped by bonus loot slots above expected into |cff1eff00Uncommon|r (+1 slot), |cff0070ddRare|r (+2 slots), |cffa335eeEpic|r (+3 slots), and |cffff8000Legendary|r (+4 or more slots).\n\n" ..
    "• Find Treasure Aura Check: When you attempt to open a chest without Find Treasure active, the minimap icon tints red and a Raid Warning + Help sound reminds you to enable it.\n\n" ..
    "• Value & Proc Tracking: Keeps separate records for Active vs. Inactive runs, tracking most valuable drop (AH or Vendor), coin and item vendor value, auction house value (when supported by a price addon), highest slot count seen, and proc rate."
)

local featureCheckBtn = CreateFrame("CheckButton", "FindTreasureFeatureToggle", mainFrame, "UICheckButtonTemplate")
featureCheckBtn:SetPoint("TOPLEFT", howItWorksText, "BOTTOMLEFT", -2, -16)
featureCheckBtn:SetSize(26, 26)

local featureCheckLabel = featureCheckBtn.text or _G[featureCheckBtn:GetName() .. "Text"]
if featureCheckLabel then
    featureCheckLabel:SetText("Enable Legendary Feature (Coin Fountain & Feature Sound)")
    featureCheckLabel:SetFontObject("GameFontHighlight")
end

featureCheckBtn:SetScript("OnClick", function(self)
    InitDB()
    FindTreasureDB.enableLegendaryFeature = self:GetChecked() and true or false
end)

featureCheckBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Legendary Feature", 1, 0.82, 0)
    GameTooltip:AddLine("Uncheck to disable the Feature sound and coin fountain on Legendary finds while keeping the top screen glow.", 1, 1, 1, true)
    GameTooltip:Show()
end)

featureCheckBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local inactiveProcCheckBtn = CreateFrame("CheckButton", "FindTreasureInactiveProcToggle", mainFrame, "UICheckButtonTemplate")
inactiveProcCheckBtn:SetPoint("TOPLEFT", featureCheckBtn, "BOTTOMLEFT", 0, -4)
inactiveProcCheckBtn:SetSize(26, 26)

local inactiveProcCheckLabel = inactiveProcCheckBtn.text or _G[inactiveProcCheckBtn:GetName() .. "Text"]
if inactiveProcCheckLabel then
    inactiveProcCheckLabel:SetText("Allow Procs When Find Treasure Is Inactive")
    inactiveProcCheckLabel:SetFontObject("GameFontHighlight")
end

inactiveProcCheckBtn:SetScript("OnClick", function(self)
    InitDB()
    FindTreasureDB.allowInactiveAuraProcs = self:GetChecked() and true or false
end)

inactiveProcCheckBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Inactive Aura Procs", 1, 0.82, 0)
    GameTooltip:AddLine("Trigger bonus-slot proc alerts and effects even when Find Treasure is not active.", 1, 1, 1, true)
    GameTooltip:Show()
end)

inactiveProcCheckBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local shareBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
shareBtn:SetSize(140, 24)
shareBtn:SetPoint("TOPLEFT", inactiveProcCheckBtn, "BOTTOMLEFT", 2, -16)
shareBtn:SetText("Share Stats")
shareBtn:SetScript("OnClick", function()
    ShareActiveStatsToSay()
end)

local resetBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
resetBtn:SetSize(140, 24)
resetBtn:SetPoint("LEFT", shareBtn, "RIGHT", 10, 0)
resetBtn:SetText("Reset Stats")
resetBtn:SetScript("OnClick", function()
    PromptResetStatsConfirmation()
end)

local debugBtn = CreateFrame("Button", "FindTreasureDebugButton", mainFrame, "UIPanelButtonTemplate")
debugBtn:SetSize(110, 24)
debugBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
debugBtn:SetScript("OnClick", function()
    ToggleEventDebug()
end)
debugBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Event Debug", 1, 0.82, 0)
    GameTooltip:AddLine("Toggle safe player spell/aura/loot event logging in chat.", 1, 1, 1, true)
    GameTooltip:Show()
end)
debugBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

--------------------------------------------------------------------------------
-- Top 5 Highest Value Items by AH Price Table
--------------------------------------------------------------------------------
local topAHHeader = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
topAHHeader:SetPoint("TOPLEFT", shareBtn, "BOTTOMLEFT", 0, -18)
topAHHeader:SetText("Top 5 of the Prospector's AH Haul:")

local topAHTableFrame = CreateFrame("Frame", "FindTreasureTopAHTable", mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
topAHTableFrame:SetPoint("TOPLEFT", topAHHeader, "BOTTOMLEFT", 0, -8)
topAHTableFrame:SetSize(524, 152)
if topAHTableFrame.SetBackdrop then
    topAHTableFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    topAHTableFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
    topAHTableFrame:SetBackdropBorderColor(0.55, 0.45, 0.15, 0.90)
end

local headerBg = topAHTableFrame:CreateTexture(nil, "ARTWORK")
headerBg:SetPoint("TOPLEFT", topAHTableFrame, "TOPLEFT", 5, -5)
headerBg:SetPoint("TOPRIGHT", topAHTableFrame, "TOPRIGHT", -5, -5)
headerBg:SetHeight(20)
headerBg:SetColorTexture(0.22, 0.17, 0.05, 0.85)

local colRankTitle = topAHTableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colRankTitle:SetPoint("LEFT", headerBg, "LEFT", 8, 0)
colRankTitle:SetWidth(26)
colRankTitle:SetJustifyH("LEFT")
colRankTitle:SetText("#")

local colItemTitle = topAHTableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colItemTitle:SetPoint("LEFT", colRankTitle, "RIGHT", 4, 0)
colItemTitle:SetWidth(215)
colItemTitle:SetJustifyH("LEFT")
colItemTitle:SetText("Item")

local colChestTitle = topAHTableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colChestTitle:SetPoint("LEFT", colItemTitle, "RIGHT", 8, 0)
colChestTitle:SetWidth(150)
colChestTitle:SetJustifyH("LEFT")
colChestTitle:SetText("Chest")

local colPriceTitle = topAHTableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colPriceTitle:SetPoint("RIGHT", headerBg, "RIGHT", -8, 0)
colPriceTitle:SetWidth(100)
colPriceTitle:SetJustifyH("RIGHT")
colPriceTitle:SetText("AH Value")

local topAHRows = {}
local topAHEmptyText = topAHTableFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
topAHEmptyText:SetPoint("CENTER", topAHTableFrame, "CENTER", 0, -8)
topAHEmptyText:SetText("No AH-priced chest items recorded yet.")
topAHEmptyText:Hide()

for idx = 1, TOP_AH_LIMIT do
    local row = CreateFrame("Frame", nil, topAHTableFrame)
    row:SetPoint("TOPLEFT", headerBg, "BOTTOMLEFT", 0, -((idx - 1) * 23) - 2)
    row:SetPoint("TOPRIGHT", headerBg, "BOTTOMRIGHT", 0, -((idx - 1) * 23) - 2)
    row:SetHeight(21)

    if idx % 2 == 0 then
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints(row)
        stripe:SetColorTexture(1, 1, 1, 0.03)
    end

    local rankFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rankFS:SetPoint("LEFT", row, "LEFT", 8, 0)
    rankFS:SetWidth(26)
    rankFS:SetJustifyH("LEFT")
    rankFS:SetText(idx .. ".")

    local itemBtn = CreateFrame("Button", nil, row)
    itemBtn:SetPoint("LEFT", rankFS, "RIGHT", 4, 0)
    itemBtn:SetSize(215, 20)

    local itemFS = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemFS:SetAllPoints(itemBtn)
    itemFS:SetJustifyH("LEFT")
    itemFS:SetWordWrap(false)

    itemBtn:SetScript("OnEnter", function(self)
        if self.itemLink and self.itemLink ~= "" and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    itemBtn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    local chestFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chestFS:SetPoint("LEFT", itemBtn, "RIGHT", 8, 0)
    chestFS:SetWidth(150)
    chestFS:SetJustifyH("LEFT")
    chestFS:SetWordWrap(false)

    local priceFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceFS:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    priceFS:SetWidth(100)
    priceFS:SetJustifyH("RIGHT")

    topAHRows[idx] = {
        frame = row,
        rankFS = rankFS,
        itemBtn = itemBtn,
        itemFS = itemFS,
        chestFS = chestFS,
        priceFS = priceFS,
    }
end

--------------------------------------------------------------------------------
-- Dwarven Support Fund Footer (Copyable EditBox)
--------------------------------------------------------------------------------
local tipHeaderText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
tipHeaderText:SetPoint("TOPLEFT", topAHTableFrame, "BOTTOMLEFT", 0, -14)
tipHeaderText:SetText("Dwarven Support Fund:")

local tipPromptText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
tipPromptText:SetPoint("TOPLEFT", tipHeaderText, "BOTTOMLEFT", 0, -4)
tipPromptText:SetText("Pour a brew in this ol' prospector's mug")

local tipLinkBox = CreateFrame("EditBox", "FindTreasureTipLinkBox", mainFrame, "InputBoxTemplate")
tipLinkBox:SetPoint("TOPLEFT", tipPromptText, "BOTTOMLEFT", 4, -6)
tipLinkBox:SetSize(225, 20)
tipLinkBox:SetAutoFocus(false)
tipLinkBox:SetText(BUY_ME_A_COFFEE_URL)
tipLinkBox:SetCursorPosition(0)
tipLinkBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)
tipLinkBox:SetScript("OnEditFocusLost", function(self)
    self:HighlightText(0, 0)
end)
tipLinkBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
tipLinkBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
        self:SetText(BUY_ME_A_COFFEE_URL)
        self:HighlightText()
    end
end)

local function RefreshTopAHTable()
    InitDB()
    local items = (FindTreasureDB.dwarfActive and FindTreasureDB.dwarfActive.topAHItems) or {}
    local hasAny = false

    for idx = 1, TOP_AH_LIMIT do
        local rowUI = topAHRows[idx]
        local entry = items[idx]
        if entry and (entry.ahValue or 0) > 0 then
            hasAny = true
            rowUI.frame:Show()
            rowUI.rankFS:SetText(string.format("|cffFFD100%d.|r", idx))
            rowUI.itemBtn.itemLink = entry.link
            rowUI.itemFS:SetText(entry.label or entry.link or "Item")
            rowUI.chestFS:SetText(string.format("|cffCCCCCC%s|r", entry.chest or "Chest"))
            rowUI.priceFS:SetText(string.format("|cffFFD700%s|r", FormatCopper(entry.ahValue)))
        else
            rowUI.frame:Hide()
            rowUI.itemBtn.itemLink = nil
        end
    end

    topAHEmptyText:SetShown(not hasAny)
end

SyncSettingsControls = function()
    InitDB()
    featureCheckBtn:SetChecked(IsLegendaryFeatureEnabled())
    if inactiveProcCheckBtn then
        inactiveProcCheckBtn:SetChecked(IsInactiveAuraProcsEnabled())
    end
    if debugBtn then
        debugBtn:SetText(debugEvents and "Debug: ON" or "Debug")
    end
    if tipLinkBox then
        tipLinkBox:SetText(BUY_ME_A_COFFEE_URL)
        tipLinkBox:SetCursorPosition(0)
    end
    RefreshTopAHTable()
end

mainFrame:SetScript("OnShow", function()
    SyncSettingsControls()
end)

local function RegisterSettingsCategory()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(mainFrame, "Find Treasure Tracker")
        Settings.RegisterAddOnCategory(category)
        SettingsCategoryID = category:GetID()
    elseif Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterVerticalLayoutCategory("Find Treasure Tracker")
        Settings.RegisterAddOnCategory(category)
        SettingsCategoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        mainFrame.name = "Find Treasure Tracker"
        InterfaceOptions_AddCategory(mainFrame)
    end
end

--------------------------------------------------------------------------------
-- Chest Loot Tracking & Slot-Count Proc Alert Logic
--------------------------------------------------------------------------------
local function WarnIfFindTreasureInactive(targetLabel)
    if remindedInactiveThisChest then return end
    if not IsPlayerDwarf() then return end
    UpdateTrackerIconState()
    if not HasFindTreasureActive() then
        remindedInactiveThisChest = true
        local chestLabel = (type(targetLabel) == "string" and targetLabel ~= "") and targetLabel or "Chest"
        local rwMsg = string.format("|cffFF5555Enable Find Treasure!|r |cffB0B0B0- %s|r", chestLabel)
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, rwMsg, ChatTypeInfo["RAID_WARNING"])
        end
        print(string.format("|cffFF5555[Find Treasure]|r Find Treasure is NOT enabled on |cffffffff%s|r — enable Find Treasure before looting!", chestLabel))
        PlaySoundFileCandidates(HELP_SOUND_CANDIDATES)
    end
end

local function TriggerSlotProcAlert(bucket, tierKey, numSlots, maxExpected, isNewRecord)
    if alertedThisChest then return end
    alertedThisChest = true
    bucket.procs = (bucket.procs or 0) + 1

    local style = TIER_STYLES[tierKey] or TIER_STYLES.uncommon
    local msg = FormatAlertMessage(style, chestName, isNewRecord)

    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    end
    print("|cffFFD100[Find Treasure]|r " .. msg)

    PlayTierFeedback(tierKey)
end

local function EvaluateChestLoot()
    if countedThisChest then return end

    local numSlots = (GetNumLootItems and GetNumLootItems()) or 0
    if numSlots <= 0 then return end

    local fromOpeningCast = openingChest
    local candidateName = chestName
    if not fromOpeningCast then
        local tipText = (GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()) or ""
        candidateName = (type(tipText) == "string" and tipText ~= "") and tipText or ""
    end

    if not IsTrackedChestName(candidateName, fromOpeningCast) then
        return
    end

    chestName = candidateName
    openingChest = true
    lastChestName = chestName
    countedThisChest = true
    local hasAura = HasFindTreasureActive()
    UpdateTrackerIconState()
    local bucket = hasAura and FindTreasureDB.dwarfActive or FindTreasureDB.humanOrOther

    local maxExpected = NORMAL_MAX_SLOTS[chestName] or 4
    local chestCopperValue = 0
    local chestAHCopperValue = 0
    local loggedItems = {}

    for slot = 1, numSlots do
        local link = (GetLootSlotLink and GetLootSlotLink(slot)) or nil
        local _, rawName, rawQuantity = GetLootSlotInfo(slot)
        local name = (type(rawName) == "string") and rawName or ""

        if link then
            local parsedQty = tonumber(name:match("x(%d+)"))
            local quantity = (type(rawQuantity) == "number" and rawQuantity > 0) and rawQuantity or (parsedQty or 1)
            local vendorCopper = GetItemVendorSellCopper(link, quantity)
            local ahCopper = GetItemAHSellCopper(link, quantity)
            chestCopperValue = chestCopperValue + vendorCopper
            chestAHCopperValue = chestAHCopperValue + ahCopper
            RecordMostValuableDrop(bucket, link, quantity, vendorCopper, ahCopper)
            RecordTopAHItem(bucket, link, quantity, ahCopper, chestName)
            local entryLabel = (quantity > 1) and (link .. "x" .. quantity) or link
            table.insert(loggedItems, entryLabel)
        elseif name ~= "" then
            local coinCopper = ParseCoinToCopper(name)
            chestCopperValue = chestCopperValue + coinCopper
            chestAHCopperValue = chestAHCopperValue + coinCopper
            local cleanCoin = name:gsub("\n", " ")
            table.insert(loggedItems, cleanCoin)
        end
    end

    local tierKey, isProc = ClassifyChestBySlots(numSlots, maxExpected)
    local tierField = tierKey .. "Chests"
    local prevMax = bucket.maxSlotsSeen or 0
    local isNewRecord = numSlots > prevMax

    bucket.chests = (bucket.chests or 0) + 1
    bucket.totalCopperValue = (bucket.totalCopperValue or 0) + chestCopperValue
    bucket.totalAHCopperValue = (bucket.totalAHCopperValue or 0) + chestAHCopperValue
    bucket[tierField] = (bucket[tierField] or 0) + 1

    if numSlots > prevMax then
        bucket.maxSlotsSeen = numSlots
        bucket.maxSlotsChest = chestName
    end

    bucket.byChest[chestName] = bucket.byChest[chestName] or {
        chests = 0,
        maxSlotsSeen = 0,
        legendaryChests = 0,
        epicChests = 0,
        rareChests = 0,
        uncommonChests = 0,
        commonChests = 0,
        runs = {},
    }
    local cEntry = bucket.byChest[chestName]
    cEntry.runs = cEntry.runs or {}
    cEntry.chests = (cEntry.chests or 0) + 1
    cEntry[tierField] = (cEntry[tierField] or 0) + 1
    if numSlots > (cEntry.maxSlotsSeen or 0) then
        cEntry.maxSlotsSeen = numSlots
    end

    table.insert(cEntry.runs, {
        slots = numSlots,
        tier = (TIER_STYLES[tierKey] and TIER_STYLES[tierKey].label) or "Common",
        items = loggedItems,
    })

    if (hasAura or IsInactiveAuraProcsEnabled()) and isProc then
        TriggerSlotProcAlert(bucket, tierKey, numSlots, maxExpected, isNewRecord)
    end

    if mainFrame and mainFrame:IsShown() then
        RefreshTopAHTable()
    end
end

SLASH_FINDTREASURE1 = "/ftt"
SLASH_FINDTREASURE2 = "/fttstats"
SLASH_FINDTREASURE3 = "/ft"
SLASH_FINDTREASURE4 = "/ftstats"
SlashCmdList["FINDTREASURE"] = function(msg)
    InitDB()
    UpdateTrackerIconState()
    local raw = (msg or ""):match("^%s*(.-)%s*$")
    local lower = raw:lower()
    if lower == "" or lower == "options" or lower == "config" then
        OpenAddonSettings()
        return
    elseif lower == "stats" or lower == "print" or lower == "share" then
        ShareActiveStatsToSay()
        return
    elseif lower == "reset" then
        PromptResetStatsConfirmation()
        return
    elseif lower == "debug" then
        ToggleEventDebug()
        return
    elseif lower == "testcoin" or lower == "test" then
        PreviewTierProc("legendary")
        return
    elseif lower == "testsound" then
        PreviewTierProc("legendary")
        return
    elseif lower:sub(1, 10) == "testsound " then
        PreviewTierProc(raw:sub(11))
        return
    elseif lower == "log" then
        PrintChestLog(nil)
        return
    elseif lower:sub(1, 4) == "log " then
        PrintChestLog(raw:sub(5))
        return
    elseif lower == "compare" then
        PrintChestComparison()
        return
    end
    OpenAddonSettings()
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_SPELLCAST_SENT")
f:RegisterEvent("LOOT_READY")
f:RegisterEvent("LOOT_OPENED")
f:RegisterEvent("LOOT_CLOSED")
pcall(function() f:RegisterEvent("MINIMAP_UPDATE_TRACKING") end)

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            InitDB()
            RegisterSettingsCategory()
            SyncSettingsControls()
            UpdateMinimapButtonPosition()
            UpdateTrackerIconState()
        end
    elseif event == "PLAYER_LOGIN" or event == "MINIMAP_UPDATE_TRACKING" then
        InitDB()
        SyncSettingsControls()
        UpdateMinimapButtonPosition()
        UpdateTrackerIconState()
        if event == "PLAYER_LOGIN" then
            print("|cffFFD100[Find Treasure]|r Loaded. /ftt | /ftt share | /ftt log | /ftt compare | /ftt testsound | /ftt debug")
        end
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, target, _, spellID = ...
        local spellName = GetSpellNameSafe(spellID)
        if unit == "player" and (spellName == "Opening" or spellID == 3365 or spellID == 6247) then
            openingChest = true
            countedThisChest = false
            alertedThisChest = false
            remindedInactiveThisChest = false
            chestName = (type(target) == "string" and target ~= "") and target or "Chest"
            lastChestName = chestName
            WarnIfFindTreasureInactive(chestName)
        end
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        EvaluateChestLoot()
    elseif event == "LOOT_CLOSED" then
        openingChest = false
        countedThisChest = false
        alertedThisChest = false
        remindedInactiveThisChest = false
        chestName = "Chest"
    end
end)