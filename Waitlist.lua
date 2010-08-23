local verbose = true
local squelch = true
local altPrefix = ""
local altSuffix = ""

if not WaitlistDB then WaitlistDB = {} end
local L = {}
local locale = _G.GetLocale()
if locale == "enUS" then
	L["print_prefix"] = "|cffffff7fWaitlist:|r"

	L["usage_slash"] = "Usage: /wl add | remove | who | announce | reset"
	L["usage_help"] = "Whisper me 'wl add' to get on the waitlist, or 'wl help' for more commands"
	L["usage_whisper"] = "Valid commands: 'wl who', 'wl add', 'wl main', 'wl remove'"

	L["prefix_command"] = "wl"
	L["prefix_response"] = "<Waitlist>"

	L["command_slash"] = "/wl"
	L["command_add"] = "add"
	L["command_main"] = "main"
	L["command_remove"] = "remove"
	L["command_who"] = "who"
	L["command_announce"] = "announce"
	L["command_reset"] = "reset"
	L["command_help"] = "help"

	L["response_inraid"] = "%s is already in the raid."
	L["response_added"] = "%s has been added to the waitlist."
	L["response_alreadylisted"] = "%s is already on the waitlist."
	L["response_removed"] = "%s has been removed from the waitlist."
	L["response_empty"] = "The waitlist is currently empty."
	L["response_current"] = "Current Waitlist: "
	L["response_nomain"] = "Unable to find main's name on the guild roster."
	L["response_reset"] = "The waitlist has been reset."

	L["report_guild"] = "guild"
	L["report_officer"] = "officer"
	L["report_raid"] = "raid"
	L["report_party"] = "party"
	L["report_say"] = "say"
end

local raidunit = "raid%s"
local caret = "^%s"
local spam = "%s %s"
local namelist = "%s %s, "

local _G = getfenv(0)
local strsplit = _G.strsplit
local strlower = _G.string.lower
local strupper = _G.string.upper
local tinsert = _G.table.insert
local tremove = _G.table.remove
local ipairs = _G.ipairs
local print = _G.print
local type = _G.type
local GetGuildRosterInfo = _G.GetGuildRosterInfo
local GetNumGuildMembers = _G.GetNumGuildMembers
local GetNumPartyMembers = _G.GetNumPartyMembers
local GetNumRaidMembers = _G.GetNumRaidMembers
local SendChatMessage = _G.SendChatMessage
local UnitInRaid = _G.UnitInRaid
local UnitName = _G.UnitName

local function fixcase(msg)
	if type(msg) == "string" then
		return (strlower(msg)):gsub("%a", strupper, 1)
	end
end

local function getmain(alt)
	local note
	local total = GetNumGuildMembers(true)
	for i=1,total do 
		local name = GetGuildRosterInfo(i)
		if name == alt then
			local _,_,_,_,_,_, x = GetGuildRosterInfo(i)
			note = x
		end
	end
	for i=1,total do
		local name = strlower(GetGuildRosterInfo(i))
		if note:find(name) then
			return name
		end
	end
	return nil
end

local function addname(msg)
	local name = fixcase(msg)
	if UnitInRaid(name) then
		return L["response_inraid"]:format(name)
	else
		for k,v in ipairs(WaitlistDB) do
			if v == name then
					return L["response_alreadylisted"]:format(name)
			end
		end
	end
	tinsert(WaitlistDB, name)
	return L["response_added"]:format(name)
end

local function delname(msg)
	local name = fixcase(msg)
	for k,v in ipairs(WaitlistDB) do
		if v == name then
			tremove(WaitlistDB, k)
			return L["response_removed"]:format(name)
		end
	end
	return nil
end

local function listnames()
	if #WaitlistDB == 0 then
		return L["response_empty"]
	else
		local message = L["response_current"]
		for index,name in ipairs(WaitlistDB) do
			message = namelist:format(message, name)
		end
		message = message:sub(1, -3)
		return message
	end
	return nil
end
	
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", function(_,_,msg) if squelch and msg and msg:find(caret:format(L["prefix_response"])) then return true end end)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER",  function(_,_,msg) if squelch and msg and msg:find(caret:format(L["prefix_command"])) then return true end end)

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, ...)
	self[event](self,...)
end)

frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_WHISPER")

function frame:RAID_ROSTER_UPDATE()
	for i=1, GetNumRaidMembers() do
		delname(UnitName(raidunit:format(i)))
	end
end

function frame:CHAT_MSG_WHISPER(msg, player)
	local prefix, command = strsplit(" ", strlower(msg), 2)
	if prefix == L["prefix_command"] then 
		local response = L["usage_help"]
		if command == L["command_help"] then
			response = L["usage_whisper"]
		elseif command == L["command_add"] then
			response = addname(player)
			if verbose then print(L["print_prefix"],response) end
		elseif command == L["command_main"] then
			local main = getmain(player)
			response = main and addname(main) or L["response_nomain"]
		elseif command == L["command_remove"] then
			response = delname(player)
		elseif command == L["command_who"] then
			response = listnames()
		end
		SendChatMessage(spam:format(L["prefix_response"],response), "WHISPER", nil, player)
		return squelch
	end
end

SLASH_WAITLIST1 = L["command_slash"];
SlashCmdList["WAITLIST"] = function(msg)
	local input = strlower(msg)
	local command, arg = strsplit(" ", strlower(msg), 2)
	local output, chatmsg, channel
	if command == L["command_announce"] then
		chatmsg = listnames()	
		channel = "GUILD"
		SendChatMessage(spam:format(L["prefix_response"],L["usage_help"]), channel)
	elseif command == L["command_who"] then
		chatmsg = listnames()
		if arg == L["report_officer"] and GetNumGuildMembers() ~= 0 then
			channel = "OFFICER"
		elseif arg == L["report_guild"] and GetNumGuildMembers() ~= 0 then
			channel = "GUILD"
		elseif arg == L["report_raid"] and GetNumRaidMembers() ~= 0 then
			channel = "RAID"
		elseif arg == L["report_party"] and GetNumPartyMembers() ~= 0 then
			channel = "PARTY"
		elseif arg == L["report_say"] then
			channel = "SAY"
		else
			print(chatmsg)
		end
	elseif command == L["command_add"] then
		output = addname(arg)
	elseif command == L["command_remove"] then
		output = delname(arg)
	elseif command == L["command_reset"] then
		WaitlistDB = {}
		output = L["response_reset"]
	else
		output = L["usage_slash"]
	end
	if output then print(L["print_prefix"],output) end
	if chatmsg and channel then
		SendChatMessage(spam:format(L["prefix_response"],chatmsg), channel)
	end
end

