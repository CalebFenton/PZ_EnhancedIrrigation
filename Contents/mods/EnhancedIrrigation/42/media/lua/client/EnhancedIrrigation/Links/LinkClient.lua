-- This client's copy of the tank links (shared/EnhancedIrrigation/Links/Links.lua), which the menu
-- lists: the system of the same name as the authority's (server/EnhancedIrrigation/Links/
-- LinkSystem.lua) gets the list with its initial state and again with each "links" command. Also
-- in single player, where the server's commands loop back.

require "Map/CGlobalObjectSystem"
require "EnhancedIrrigation/Links/Links"

EnhancedIrrigation = EnhancedIrrigation or {}
local LinkClient = CGlobalObjectSystem:derive("EnhancedIrrigation_ClientLinkSystem")
EnhancedIrrigation.LinkClient = LinkClient

local Links = EnhancedIrrigation.Links

function LinkClient:new()
    return CGlobalObjectSystem.new(self, Links.SYSTEM_NAME)
end

-- The initial state's `links` and `version` are already in the system's table
-- (CGlobalObjects.registerSystem): a client that connects takes the server's list as it stands.
function LinkClient:initSystem()
    Links.clientSystem = self
    self.links = self.links or {}
    self.version = self.version or 0
end

function LinkClient:isValidIsoObject(isoObject)
    return false
end

-- A list older than the one shown came the long way round: the newer one already holds its change.
function LinkClient:OnServerCommand(command, args)
    if command == "links" and args.version >= self.version then
        self.links = args.links or {}
        self.version = args.version
    end
end

CGlobalObjectSystem.RegisterSystemClass(LinkClient)

return LinkClient
