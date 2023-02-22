local Connection = {}
Connection.__index = Connection

local Database = require(workspace.DatabaseHandler);
local Opcodes = require(workspace.Opcodes)

--[[
	Here lies the ConnectionHandler
	When a player joins the game, 
	this object is created to represent 
	the connection between the client and 
	the server. 
	
]]

function Connection.new(player)
	local new_connection = {}
	setmetatable(new_connection, Connection)
	
	new_connection.player = player
	new_connection.characterList = {}
	
	return new_connection
end

function Connection:BuildCharacter()
	
end

function Connection:DisplayCharacters()
	-- Get character list
	self:GetCharacters();
	
	-- Send opcode
	local data, packet = {},Opcodes.FindClientPacket("SMSG_CHAR_LIST");
	data.List = self.characterList;
	packet:FireClient(self.player, data);
end

function Connection:GetCharacters()
	local chars = {}
	local folder = Database.Access("characters", "character", nil);
	for _,v in next,folder:GetChildren() do
		if v.Name == self.player.Name then
			for _,v in next, v:GetChildren() do
				table.insert(chars, v);
			end
		end
	end
	print(#chars)
	self.characterList = chars
	return chars;
end

return Connection
