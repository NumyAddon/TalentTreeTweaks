local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;

local Module = Main:NewModule('LinkSpells');

function Module:OnEnable()
    EventRegistry:RegisterCallback('TalentButton.OnClick', self.OnButtonClick, self);
end

function Module:OnDisable()
    EventRegistry:UnregisterCallback('TalentButton.OnClick', self);
end

function Module:GetDescription()
    return 'Shift-clicking a spell in the talent tree will link it to chat or the macro frame.'
end

function Module:GetName()
    return 'Link Spells'
end

function Module:GetOptions(defaultOptionsTable, db)
    return defaultOptionsTable;
end

function Module:OnButtonClick(buttonFrame, mouseButton)
    if mouseButton ~= 'LeftButton' or not IsModifiedClick('CHATLINK') then
        return;
    end
    local spellId = buttonFrame:GetSpellID();
    if not spellId then
        return;
    end
    local spellName = GetSpellInfo(spellId);
    if not spellName then
        return;
    end
    local link = GetSpellLink(spellId);
    if (MacroFrameText and MacroFrameText:HasFocus()) then
        if (spellName and not IsPassiveSpell(spellName)) then
            local subSpellName = GetSpellSubtext(spellName)
            if (subSpellName) then
                if (subSpellName ~= '') then
                    ChatEdit_InsertLink(spellName .. '(' .. subSpellName .. ')')
                else
                    ChatEdit_InsertLink(spellName)
                end
            else
                ChatEdit_InsertLink(spellName)
            end
        end
    elseif (link) then
        ChatEdit_InsertLink(link)
    end
end
