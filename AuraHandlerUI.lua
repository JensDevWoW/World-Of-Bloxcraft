local AuraHandler = {}
AuraHandler.__index = AuraHandler

local Database = require(workspace.DatabaseHandler)

function AuraHandler.new(UI, info, key, spot)
	local new_aura = {}
	setmetatable(new_aura, AuraHandler)
	
	new_aura.info = info
	new_aura.m_duration = info.AuraDuration.Value
	new_aura.key = key;
	new_aura.spotNum = key;
	new_aura.UI = UI;
	new_aura.spot = spot;
	new_aura.targetDebuffFolder = script.Parent.Frame.Target.Debuffs.DebuffFolder;
	
	if spot == "target" then
		new_aura.link = script.Parent.Frame.Target.Debuffs.DebuffName:Clone();
		new_aura.link.Parent = script.Parent.Frame.Target.Debuffs.DebuffFolder;
	elseif spot == "player" then
		if info.Parent.PositiveNegative == true then
			new_aura.link = script.Parent.Frame.BuffList.BuffName:Clone()
			new_aura.link.Parent = script.Parent.Frame.BuffList.BuffFolder;
		else
			new_aura.link = script.Parent.Frame.DebuffList.DebuffName:Clone()
			new_aura.link.Parent = script.Parent.Frame.DebuffList.DebuffFolder;
		end
	end
	new_aura.durationLink = new_aura.link.TimeLeft
	
	local tac1,tac2 = Database.Access("world", "spell_script_decals", info.Parent.Name);
	new_aura.link.Name = info.AuraName.Value;
	new_aura.link.Aura.Image = tac1.Value;
	new_aura.link.Visible = true
	new_aura.link.Parent.Parent.Visible = true;
	new_aura.m_active = true;
	
	return new_aura;
end

function AuraHandler:UpdateInfo(new_info)
	self.info = new_info;
	self.m_duration = new_info.AuraDuration.Value;
end

function AuraHandler:Update(m_time)
	if self.m_active == true then
		if self.m_duration > 0 then
			self.m_duration = self.m_duration - m_time;
			self.durationLink.Text = math.ceil(self.m_duration)
		else
			self.m_duration = 0;
		end
	end
end

return AuraHandler
