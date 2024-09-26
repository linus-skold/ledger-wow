local test, addon = ...

local playerName = UnitName("player")
local playerRealm = GetRealmName()
local characterTransactions = {}
local inventoryBefore = {}
local tempInventory = {}
local tempCopperAmount = 0

local columnWidth = 100
local rowHeight = 20

local mainFrame = CreateFrame("Frame", "Ledger", UIParent, "DefaultPanelTemplate")
mainFrame.CloseButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButtonDefaultAnchors")

mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("PLAYER_LOGOUT")

mainFrame:SetSize(300, 300)
mainFrame:SetPoint("CENTER", 0, 0)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)

mainFrame.TitleText = mainFrame.TitleContainer.TitleText
mainFrame.TitleText:SetText("Ledger")

mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetClampedToScreen(true)

mainFrame.ContentFrame = CreateFrame("ScrollFrame", "LedgerContentFrame", mainFrame, "UIPanelScrollFrameTemplate")
mainFrame.ContentFrame:SetSize(274, 300 - (mainFrame.TitleContainer:GetHeight() / 2) - 60)
mainFrame.ContentFrame:SetPoint("TOPLEFT", 0, -(mainFrame.TitleContainer:GetHeight()) - 7)

local scrollChild = CreateFrame("Frame", nil, mainFrame.ContentFrame)
scrollChild:SetSize(mainFrame.ContentFrame:GetWidth(), 20 * 20)
mainFrame.ContentFrame:SetScrollChild(scrollChild)

local scrollbar = _G[mainFrame.ContentFrame:GetName() .. "ScrollBar"]
scrollbar:SetScript(
    "OnValueChanged",
    function(self, value)
        if value ~= nil then
            mainFrame.ContentFrame:SetVerticalScroll(value)
        end
    end
)

function createColumn(text, index)
    local column = CreateFrame("Button", nil, scrollChild)
    row:SetSize(columnWidth, rowHeight)
end

local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"

function moneyString(gold, silver, copper)
    return gold .. goldIcon .. " " .. silver .. silverIcon .. " " .. copper .. copperIcon
end

function createRow(text, index)
    local row = CreateFrame("Button", nil, scrollChild)
    row:SetSize(mainFrame.ContentFrame:GetWidth() - 10, 20)
    row:SetFrameLevel(mainFrame:GetFrameLevel() + 1)
    row:SetPoint("TOPLEFT", 7, -20 * (index - 1))
    row:SetNormalTexture("Interface\\Buttons\\UI-Listbox-Highlight")
    row:GetNormalTexture():SetVertexColor(0, 0, 0, 0)
    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight")
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.5)

    local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rowText:SetPoint("LEFT", row, "LEFT", 5, 0)
    rowText:SetText(text)
end

--  Set the scrollbar for the scroll frame

function createFrames(scrollHeight)
    mainFrame.ContentFrame =
        CreateFrame("ScrollFrame", "MacroMasterContentFrame", mainFrame, "UIPanelScrollFrameTemplate")
    mainFrame.ContentFrame:SetSize(300, 300 - (mainFrame.TitleContainer:GetHeight() / 2))
    mainFrame.ContentFrame:SetPoint("TOPLEFT", 0, -(mainFrame.TitleContainer:GetHeight() / 2))

    local scrollChild = CreateFrame("Frame", nil, mainFrame.ContentFrame)
    scrollChild:SetSize(mainFrame.ContentFrame:GetWidth(), scrollHeight)
    mainFrame.ContentFrame:SetScrollChild(scrollChild)

    local scrollbar = _G[mainFrame.ContentFrame:GetName() .. "ScrollBar"]
    scrollbar:SetScript(
        "OnValueChanged",
        function(self, value)
            if value ~= nil then
                mainFrame.ContentFrame:SetVerticalScroll(value)
            end
        end
    )
end

function help()
    print("Ledger Help")
    print("/ledger show - shows the ledger")
    print("/ledger toggle - toggles the ledger")
end

SLASH_LEDGER1 = "/ledger"
SlashCmdList["LEDGER"] = function(args)
    local command, profile, realmName = strsplit(" ", args)
    if command == "show" or command == nil then
        mainFrame:Show()
    elseif command == "help" then
        help()
    end
end

-- list all the profiles saved in the saved variables file as different rows in the frame
mainFrame:SetScript(
    "OnEvent",
    function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Ledger" then
            AccountLedgerDB = AccountLedgerDB or {}
            characterTransactions = AccountLedgerDB[playerName] or {}
        elseif event == "PLAYER_ENTERING_WORLD" then
            tempCopperAmount = GetMoney()
            tempInventory = GetCharacterInventory()
            inventoryBefore = tempInventory

            mainFrame:RegisterEvent("MERCHANT_UPDATE") -- Fired when the player buys or sells something from a vendor
            mainFrame:RegisterEvent("MERCHANT_SHOW") -- Fired when the player buys or sells something from a vendor
            mainFrame:RegisterEvent("MERCHANT_CLOSED") -- Fired when the player buys or sells something from a vendor
            mainFrame:RegisterEvent("UNIT_INVENTORY_CHANGED") -- Fired when the player buys or sells something from a vendor
            mainFrame:RegisterEvent("BAG_UPDATE") -- Fired when the player buys or sells something from a vendor
        elseif event == "MERCHANT_UPDATE" then
            return
        elseif event == "UNIT_INVENTORY_CHANGED" then
            return
        elseif event == "BAG_UPDATE" then
            PrintGoldChange()
            OnBagUpdate()

            tempInventory = GetCharacterInventory()
            tempCopperAmount = GetMoney()
        elseif event == "MERCHANT_SHOW" then
            tempInventory = GetCharacterInventory()
            tempCopperAmount = GetMoney()
        elseif event == "MERCHANT_CLOSED" then
            return
        end
    end
)

function GetCharacterInventory()
    local items = {}
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemLink(bag, slot)
            if item ~= nil then
                local itemID = tonumber(string.match(item, "item:(%d+):"))
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                items[itemID] = itemInfo.stackCount
            end
        end
    end
    return items
end

function ConvertToGoldSilverCopper(totalCopper)
    -- Convert copper to gold, silver, and copper
    local gold = math.floor(totalCopper / 10000) -- 1 gold = 10,000 copper
    local silver = math.floor((totalCopper % 10000) / 100) -- 1 silver = 100 copper
    local copper = totalCopper % 100 -- Remaining copper

    return gold, silver, copper
end

function PrintGoldChange()
    local copper = GetMoney()
    local diff = copper - tempCopperAmount
    local gold, silver, copper = ConvertToGoldSilverCopper(abs(diff))
    if diff < 0 then
        print("|cFFFF0000-" .. moneyString(gold, silver, copper) .. "|r")
    elseif diff > 0 then
        print("|cFF00FF00" .. moneyString(gold, silver, copper) .. "|r")
    end
end

function PrintGold(amt)
    local gold, silver, copper = ConvertToGoldSilverCopper(amt)
    return moneyString(gold, silver, copper)
end

function tableDifferenceDict(t1, t2)
    local result = {}

    -- Find keys in t1 that are not in t2
    for key, value in pairs(t1) do
        if t2[key] == nil then
            result[key] = value
        end
    end

    return result
end

function tableSymmetricDifferenceArray(t1, t2)
    local result = {}
    local t1Set, t2Set = {}, {}

    -- Create sets for both tables
    for _, value in ipairs(t1) do
        t1Set[value] = true
    end
    for _, value in ipairs(t2) do
        t2Set[value] = true
    end

    -- Find elements in t1 that are not in t2
    for value in pairs(t1Set) do
        if not t2Set[value] then
            table.insert(result, value)
        end
    end

    -- Find elements in t2 that are not in t1
    for value in pairs(t2Set) do
        if not t1Set[value] then
            table.insert(result, value)
        end
    end

    return result
end

function OnBagUpdate()
    local copper = GetMoney()
    local diff = copper - tempCopperAmount

    if diff > 0 then
        local currentInventory = GetCharacterInventory()
        for itemID, prevCount in pairs(tempInventory) do
            local currentCount = currentInventory[itemID] or 0
            if (prevCount > currentCount) then
                local soldCount = prevCount - currentCount
                local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemID)
                local totalSellPrice = soldCount * itemSellPrice
                print(totalSellPrice)
                print("Sold: " .. soldCount .. "x " .. GetItemInfo(itemID) .. " for " .. PrintGold(totalSellPrice))

                RecordTransaction("sell", itemID, soldCount, totalSellPrice)
            end
        end
    elseif diff < 0 then
        local currentInventory = GetCharacterInventory()
        for itemID, currentCount in pairs(currentInventory) do
            local prevCount = tempInventory[itemID] or 0
            if (prevCount < currentCount) then
                local buyCount = currentCount - prevCount
                local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemID)
                local totalBuyPrice = buyCount * itemSellPrice
                print(totalBuyPrice)
                print("Bought: " .. buyCount .. "x " .. GetItemInfo(itemID) .. " for " .. PrintGold(totalBuyPrice))
                RecordTransaction("buy", itemID, buyCount, totalBuyPrice)
            end
        end
    end

    DrawTransactions()
    tempInventory = GetCharacterInventory()
end

function GetMoneyChange()
    local copper = GetMoney()
    return copper - tempCopperAmount
end

-- On bag update check if the item is in the inventory before, if not then it is a new item

function RecordTransaction(transactionType, item, itemCount, amount)
    -- record the transaction in the database
    characterTransactions.transactions = characterTransactions.transactions or {}
    local transaction = {
        transactionType = transactionType,
        item = item,
        itemCount = itemCount,
        amount = amount,
        timestamp = time()
    }

    print("Recorded transaction: " .. item .. " " .. itemCount .. " " .. amount)
    table.insert(characterTransactions.transactions, transaction)
end

function DrawTransactions()
    local transactions = characterTransactions.transactions
    for i, transaction in ipairs(transactions) do
        local gold, silver, copper = ConvertToGoldSilverCopper(abs(transaction.amount))

        local itemName, itemLink = GetItemInfo(transaction.item)

        if transaction.transactionType == "sell" then
            createRow(
                itemLink .. "x" .. transaction.itemCount .. " | |cFF00FF00" .. moneyString(gold, silver, copper) .. "|r",
                i
            )
        elseif transaction.transactionType == "buy" then
            createRow(
                itemLink ..
                    "x" .. transaction.itemCount .. " | |cFFFF0000-" .. moneyString(gold, silver, copper) .. "|r",
                i
            )
        end
    end
end

function RemoveAllRows(container)
    -- Iterate through all child frames of the container
    for i = container:GetNumChildren(), 1, -1 do
        local child = select(i, container:GetChildren())
        if child then
            child:Hide() -- Hide the child (optional)
            child:SetParent(nil) -- Remove the child from its parent
            child:ClearAllPoints() -- Clear any positional points
        end
    end
end
