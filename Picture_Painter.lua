PAINTER = {
    ClassName = "PAINTER",
    Debug = false,
    verbose = 0,
    Coalition = coalition.side.Blue,
    Defaults = {
        Coalition = nil,
        GroupSeparation = {min = 10, max = 40},
        ProbAggressive = .5,
        ROE = 6 -- Random
    },
    DefendedZones = nil,
    Index = 0,
    Menu = nil,
    Name = nil,
    Pictures = {},
    TemplatePrefixes = {
        ALL = {},
        ATK = {},
        COMM = {},
        BMBR = {},
        FTR = {},
        HVA = {},
        LIFT = {}
    },
    ThreatOrigin = {
        Altitude = {min = 5000, max = 35000},
        Vector = {
            Bearing = 0,
            Swath = 360,
            Range = {min = 80, max = 120}
        },
        Zones = nil
    }

    
}

--- PAINTER script version.
-- @field #string version
PAINTER.version = "0.1.0"

PAINTER.PictureType = {
    AZIMUTH = "Azimuth",
    BOX = "Box",
    CHAMPAGNE = "Champagne",
    ECHELON = "Echelon",
    LADDER = "Ladder",
    RANGE = "Range",
    STACK = "Stack",
    STINGER = "Champagne",
    VIC = "Vic",
    WALL = "Wall"
}
--- PAINTER contructor. Creates a new PAINTER object.
-- @param #PAINTER self
-- @param #string PainterName Name of the Painter. Has to be unique. Will we used to create F10 menu items etc.
-- @return #PAINTER PAINTER object.
function PAINTER:New(PainterName, Coalition)
  
    -- Inherit BASE and FSM.
    local self = BASE:Inherit( self, FSM:New() )

    self.Coalition = Coalition
    -- Set Name
    self.Name = PainterName or "Picture Painter"
    -- Set Default Picture Coalition
    if self.Coalition == coalition.side.Blue then 
        self.Defaults.Coalition = coalition.side.Red
    elseif self.Coalition == coalition.side.Red then
        self.Defaults.Coalition = coalition.side.Blue
    else
        self:E("ERROR: PAINTER must be set to a Blue or Red Coalition")
    end

    -- Create F10 Menu
    --self:AddMainMenu()

    -- Subscribe to Mark Deletions
    self:HandleEvent(EVENTS.MarkRemoved)

    return self
end
function PAINTER:AddDefendedAsset(asset_name, radius)
    if self.DefendedZones == nil then
        self.DefendedZones = SET_ZONE:New()
    end

    local zone = nil
    local asset = GROUP:FindByName( asset_name )
    if asset ~= nil then
        zone = ZONE_GROUP:New("PP_DA_ZONE_" .. asset:GetName(), asset, radius)
        self.DefendedZones:AddZone(zone)
    end
    if asset == nil then
        asset = UNIT:FindByName( asset_name )
        if asset ~= nil then
            zone = ZONE_UNIT:New("PP_DA_ZONE_" .. asset:GetName(), asset, radius)
            self.DefendedZones:AddZone(zone)
        end
    end
    if asset == nil then
        asset = AIRBASE:FindByName( asset_name )
        if asset ~= nil then
            zone = ZONE_AIRBASE:New(asset.AirbaseName, radius)
            self.DefendedZones:AddZone(zone)
        end
    end
    if asset == nil then
        asset = STATIC:FindByName( asset_name )
        if asset ~= nil then
            zone = ZONE_RADIUS:New("PP_DA_ZONE_" .. asset:GetName(), asset:GetVec2(), radius)
            self.DefendedZones:AddZone(zone)
        end
    end
    if asset == nil then
        -- error
    end
    self.DefendedZones:AddZone(zone)
    return self
end
function PAINTER:AddDefendedZone(zone)
    if self.DefendedZones == nil then
        self.DefendedZones = SET_ZONE:New()
    end
    self.DefendedZones:AddZone(zone)
    return self
end
function PAINTER:AddDefendedZoneByName(zone_name)
    if self.DefendedZones == nil then
        self.DefendedZones = SET_ZONE:New()
    end
    self.DefendedZones:AddZonesByName(zone_name)
    return self
end
function PAINTER:AddThreatOriginZoneByName(zone_name)
    if self.ThreatOrigin.Zones == nil then
        self.ThreatOrigin.Zones = SET_ZONE:New()
    end
    self.ThreatOrigin.Zones:AddZonesByName(zone_name)
    return self
end
function PAINTER:AddMenu()
    self.Menu = MENU_MISSION:New(self.Name)
    MENU_MISSION_COMMAND:New("Clear All Pictures", self.Menu, self.KnockItOff, self)

    -- Add Sub-Menu to control Default ROE
    subMenu_PP_ROE = MENU_MISSION:New("Set Default ROE", self.Menu)
    MENU_MISSION_COMMAND:New("HOLD", subMenu_PP_ROE, self.SetDefaultROE, ENUMS.ROE.WeaponHold)
    MENU_MISSION_COMMAND:New("RETURN FIRE", subMenu_PP_ROE, self.SetDefaultROE, ENUMS.ROE.ReturnFire)
    MENU_MISSION_COMMAND:New("WPNS FREE", subMenu_PP_ROE, self.SetDefaultROE, ENUMS.ROE.WeaponFree)
    MENU_MISSION_COMMAND:New("Random", subMenu_PP_ROE, self.SetDefaultROE, 6)

    -- New Picture Sub-Menu
    menu_PP_SNGL_GRP = MENU_MISSION:New("Single Group", self.Menu)
    MENU_MISSION_COMMAND:New("FTR_AGGRO", menu_PP_SNGL_GRP, self.PaintPicture, self, nil, nil, nil, 1,  "TEMPLATE_ACFT_FTR")
    MENU_MISSION_COMMAND:New("FTR_DEFENSIVE", menu_PP_SNGL_GRP, self.PaintPicture, self, nil, nil, nil, 0, "TEMPLATE_ACFT_FTR")
    MENU_MISSION_COMMAND:New("FTR_HOLD", menu_PP_SNGL_GRP, self.PaintPicture, self, nil, nil, nil, -1, "TEMPLATE_ACFT_FTR")
    MENU_MISSION_COMMAND:New("BMBR", menu_PP_SNGL_GRP, self.PaintPicture, self, nil, nil, nil, nil, "TEMPLATE_ACFT_BMBR")
    MENU_MISSION_COMMAND:New("LIFT", menu_PP_SNGL_GRP, self.PaintPicture, self, nil, nil, nil, -1, "TEMPLATE_ACFT_LIFT")
    MENU_MISSION_COMMAND:New("COMM", menu_PP_SNGL_GRP, self.PaintPicture, self, nil, nil, coalition.side.NEUTRAL, -1, "TEMPLATE_ACFT_COMM")

    menu_PP_TWO_GRP = MENU_MISSION:New("Two Group", self.Menu)
    MENU_MISSION_COMMAND:New("AZIMUTH_FTR", menu_PP_TWO_GRP, self.PaintPicture, self, "Azimuth", nil, nil, nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR")
    MENU_MISSION_COMMAND:New("ECHELON_FTR", menu_PP_TWO_GRP, self.PaintPicture, self, "Echelon", nil, nil, nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR")
    MENU_MISSION_COMMAND:New("RANGE_FTR", menu_PP_TWO_GRP, self.PaintPicture, self, "Range", nil, nil, nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR")
    MENU_MISSION_COMMAND:New("RANGE_FTR_BMBR", menu_PP_TWO_GRP, self.PaintPicture, self, "Range", nil, nil, nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_BMBR")
    --MENU_MISSION_COMMAND:New("STACK_FTR", menu_PP_TWO_GRP, self.PaintPicture, self, "Stack", nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR")

    menu_PP_THREE_GRP = MENU_MISSION:New("Three Group", self.Menu)
    MENU_MISSION_COMMAND:New("CHAMPAGNE", menu_PP_THREE_GRP, self.PaintPicture, self, "Champagne", nil, nil, nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR")
    MENU_MISSION_COMMAND:New("LADDER", menu_PP_THREE_GRP, self.PaintPicture, self, "Ladder", nil, nil, nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR")
    MENU_MISSION_COMMAND:New("VIC", menu_PP_THREE_GRP, self.PaintPicture, self, "Vic", nil, nil, nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR")
    MENU_MISSION_COMMAND:New("WALL", menu_PP_THREE_GRP, self.PaintPicture, self, "Wall", nil, nil, nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR")


    menu_PP_FOUR_GRP = MENU_MISSION:New("Four Group", self.Menu)
    MENU_MISSION_COMMAND:New("BOX_FTR", menu_PP_FOUR_GRP, self.PaintPicture, self, "Box", nil, nil, nil, "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR", "TEMPLATE_ACFT_FTR")

    menu_EDIT_PIC = MENU_MISSION:New("Pictures", self.Menu)
    return self
end
function PAINTER:SetTemplatePrefixes(prefixes)
    if type(prefixes) ~= "table" then
        prefixes = {prefixes}
    end
    local grps = SET_GROUP:New():FilterCategories("plane"):FilterPrefixes(prefixes):FilterOnce()
    grps:ForEachGroup(
        function(group)
            table.insert(self.TemplatePrefixes.ALL, group:GetName())
            if group:HasAttribute( "Transports" ) or group:HasAttribute( "AWACS" ) or group:HasAttribute( "Tankers" ) then
                table.insert(self.TemplatePrefixes.HVA, group:GetName())
            elseif group:HasAttribute( "Fighters" ) or group:HasAttribute( "Interceptors" ) or group:HasAttribute( "Multirole fighters" ) or (group:HasAttribute( "Bombers" ) and not group:HasAttribute( "Strategic bombers" )) then
                table.insert(self.TemplatePrefixes.FTR, group:GetName())
            elseif group:HasAttribute( "Strategic bombers" ) then
                table.insert(self.TemplatePrefixes.BMBR, group:GetName())
            end
        end
    )
end

function PAINTER:KnockItOff()
    for i,v in pairs(self.Pictures) do
        self:_RemovePicture(i)
    end
end
--- Initializes number of targets and location of the range. Starts the event handlers.
-- @param #RANGE self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function PAINTER:OnEventMarkRemoved(EventData)
    if (string.find(EventData.MarkText, "^PP")) ~= nil then
        -- Debug info.
        local text = string.format( "Captured event MarkRemoved for myself:\n" )
        text = text .. string.format( "Marker ID  = %s\n", tostring( EventData.MarkID ) )
        text = text .. string.format( "Coalition  = %s\n", tostring( EventData.MarkCoalition ) )
        text = text .. string.format( "Group  ID  = %s\n", tostring( EventData.MarkGroupID ) )
        text = text .. string.format( "Initiator  = %s\n", EventData.IniUnit and EventData.IniUnit:GetName() or "Nobody" )
        text = text .. string.format( "Coordinate = %s\n", EventData.MarkCoordinate and EventData.MarkCoordinate:ToStringLLDMS() or "Nowhere" )
        text = text .. string.format( "Text:          \n%s", tostring( EventData.MarkText ) )
        BASE:E( text )
        ---local UNIT_requester = UNIT:FindByName(EventData.IniUnit:GetName())
        local GROUP_requester = GROUP:FindByName(EventData.MarkGroupID)
        local mrkr_msg = {}
        for line in EventData.MarkText:gmatch("([^\n]+)") do
            --_, _, acft, num, side = string.find(w, "%s*(%S+)[%s+|$](%d+)[%s+|$](%a+)")
            --_, _, acft, num, side = string.find(w, "%s*(%S+)[%s+|$](%d?)[%s+|$](%a?)"
            --_, _, acft, num, side = string.find(w, "%s*(%S+)[%s+|$](%d?)[%s+|$](%a?)"
            --print(acft, num, side)
            BASE:E(line)
            table.insert(mrkr_msg, line) 
        end
        local _, _, shape = string.find(mrkr_msg[1], "PP%s+(%a+)")
        local _, _, alt = string.find(mrkr_msg[1], "%s-a%s+(%d+)")
        local _, _, side = string.find(mrkr_msg[1], "%s-s%s+(%a)")

        BASE:E(shape)
        BASE:E(alt)
        BASE:E(tonumber(alt))
        BASE:E(side)

        BASE:E(mrkr_msg)
        BASE:E(mrkr_msg[2])
        local prefixes = UTILS.DeepCopy(mrkr_msg)
        table.remove(prefixes, 1)

        --for prefix in string.gmatch(mrkr_msg[2], "(%S+)") do
        --    BASE:E(prefix)
        --    table.insert(prefixes, prefix)
        --end
        local mrkr_coord = EventData.MarkCoordinate
        if alt ~= nil then 
            mrkr_coord = mrkr_coord:SetAltitude(UTILS.FeetToMeters(tonumber(alt)))
        end
        BASE:E(prefixes)
        self:PaintPicture(shape, mrkr_coord, side, nil, prefixes)

    end
end
function PAINTER:PaintPicture(pic_shape, pic_anchor, pic_coalition, prob_agg, ...)
    BASE:E(arg)
    local grp_data = UTILS.DeepCopy(arg)
    if type(grp_data[1]) == "table" then
        grp_data = unpack(grp_data)
    end
    BASE:E(grp_data)

    self.Index = self.Index + 1
    pic_coalition = pic_coalition or self.Defaults.Coalition
    local pic_size = #grp_data
    local pic_prefix = nil
    local pic_coords = nil
    local pic_tgt_ZONE = self.DefendedZones:GetRandomZone()
    local pic_tgt_COORD = COORDINATE:NewFromVec2(pic_tgt_ZONE:GetVec2())
    if (pic_anchor == nil) then
        pic_anchor = self:_PictureAnchor(pic_tgt_ZONE)
        pic_anchor.anchor.y = nil
    else
        local init_heading = pic_anchor:GetAngleDegrees(pic_anchor:GetDirectionVec3(pic_tgt_COORD))
        pic_anchor = {anchor = pic_anchor, heading = init_heading}
        pic_alt = pic_anchor.anchor.y
    end
    if (pic_anchor.anchor.y == nil) then
     pic_anchor.anchor.y = UTILS.FeetToMeters(
        (math.random(5000,35000) + math.random(5000,35000) + math.random(5000,35000) + 
        math.random(5000,35000) + math.random(5000,35000))/5)
    end
    local pic_alt = pic_anchor.anchor.y

    BASE:E(pic_alt)
    pic_tgt_COORD = pic_tgt_COORD:SetAltitude(pic_alt)
    BASE:E(pic_tgt_COORD.y)
    local separation = UTILS.NMToMeters(math.random(
                                            self.Defaults.GroupSeparation.min, 
                                            self.Defaults.GroupSeparation.max))

    -- Determine Picture's ROE
    local pic_roe = self.Defaults.ROE 

    if prob_agg ~= nil then
        if prob_agg < 0 then
            pic_roe = ENUMS.ROE.WeaponHold
        else 
            pic_roe = 6 -- random, use roll against prob_agg
        end
    else
        prob_agg = self.Defaults.ProbAggressive
    end

    if (pic_roe > 5) then -- Random
        local rndm_num = math.random() -- uniform 0 to 1
        if (rndm_num <= prob_agg) then
            pic_roe = ENUMS.ROE.WeaponFree
        else
            pic_roe = ENUMS.ROE.ReturnFire
        end
    end

    -- Creat SET_GROUP for this Picture
    local setGroup_picture = SET_GROUP:New()

    -- Set Spawn Coords for the Picture
    if pic_shape == PAINTER.PictureType.AZIMUTH then
        pic_size = 2
        pic_prefix = "Two"
        pic_coords = self:_PictureAzimuth(pic_anchor.anchor, pic_anchor.heading, separation)
    elseif  pic_shape == PAINTER.PictureType.BOX then
        pic_size = 4
        pic_prefix = "Four"
        pic_coords = self:_PictureBox(pic_anchor.anchor, pic_anchor.heading, separation)
    elseif  pic_shape == PAINTER.PictureType.CHAMPAGNE then
        pic_size = 3
        pic_prefix = "Three"
        pic_coords = self:_PictureChampagne(pic_anchor.anchor, pic_anchor.heading, separation)
    elseif  pic_shape == PAINTER.PictureType.ECHELON then
        pic_size = 2
        pic_prefix = "Two"
        pic_coords = self:_PictureEchelon(pic_anchor.anchor, pic_anchor.heading, separation)
    elseif  pic_shape == PAINTER.PictureType.LADDER then
        pic_size = pic_size or 3
        if pic_size == 4 then pic_prefix = "Four" else  pic_prefix = "Three" end
        pic_coords = self:_PictureLadder(pic_anchor.anchor, pic_anchor.heading, separation)
    elseif  pic_shape == PAINTER.PictureType.RANGE then
        pic_size = 2
        pic_prefix = "Two"
        pic_coords = self:_PictureRange(pic_anchor.anchor, pic_anchor.heading, separation)
    elseif  pic_shape == PAINTER.PictureType.STACK then
        pic_size = 2
        pic_prefix = "Two"
        pic_coords = self:_PictureStack(pic_anchor.anchor, pic_anchor.heading, separation)
    elseif  pic_shape == PAINTER.PictureType.VIC then
        pic_size = 3
        pic_prefix = "Three"
        pic_coords = self:_PictureVic(pic_anchor.anchor, pic_anchor.heading, separation)
    elseif  pic_shape == PAINTER.PictureType.WALL then
        pic_size = pic_size or 3
        if pic_size == 4 then pic_prefix = "Four" else  pic_prefix = "Three" end
        pic_coords = self:_PictureWall(pic_anchor.anchor, pic_anchor.heading, separation)
    else
        pic_size = 1
        pic_coords = {pic_anchor.anchor}
        pic_prefix = "Single"
        pic_shape = ""
    end

    -- Set the Picture Name
    local pic_type =  pic_prefix .. " Group " .. pic_shape
    local pic_name = "Picture_" .. self.Index .. "_" .. string.gsub(pic_type, " ", "_")
    
    -- Spawn the Picture 
    local SPAWN_Group = SPAWN:NewWithAlias("TEMPLATE_ACFT_FTR_MiG-21_WVR_1SHIP", pic_name)

    for i=1,pic_size do

        BASE:E("Prefix: ")
        BASE:E(grp_data[i])
        local grp_prefix = nil
        local grp_size = nil
        local grp_coal = nil
        local grp_country = nil
        if grp_data[i] ~= nil then
            grp_prefix = string.match(grp_data[i], "^%s*(%S+)")
            BASE:E(grp_prefix)
            grp_size = string.match(grp_data[i], "-n%s*(%d)")
            BASE:E(grp_size)
            grp_coal = string.match(grp_data[i], "-s%s*(%a)")
            BASE:E(grp_coal)
        end

        if grp_prefix == nil then
            grp_prefix = self.TemplatePrefixes.ALL
        end

        if grp_coal == nil then
            grp_coal = pic_coalition
        else
            if string.find(grp_coal, "[b|B|2]") ~= nil then
                grp_coal = coalition.side.BLUE
            elseif string.find(grp_coal, "[n|N|0]") ~= nil then
                grp_coal = coalition.side.NEUTRAL
            elseif string.find(grp_coal, "[r|R|1]") ~= nil then
                grp_coal = coalition.side.RED
            else
                grp_coal = pic_coalition
            end
        end
        if grp_coal == coalition.side.RED then
            grp_country = country.id.CJTF_RED -- CJTF_RED
        elseif grp_coal == coalition.side.BLUE then
            grp_country = country.id.CJTF_BLUE -- CJTF_BLUE
        elseif grp_coal == coalition.side.NEUTRAL then
            grp_country = country.id.UN_PEACEKEEPERS -- UN_PEACEKEEPERS
        end

        if (grp_size == nil) then 
            local rndm_num = math.random()
            if rndm_num > .2 then grp_size = 2
            elseif rndm_num > .7 then grp_size = 3
            elseif rndm_num > .9 then grp_size = 4
            else grp_size = 1
            end
        else 
            grp_size = tonumber(grp_size)
        end

        -- Spawn Group
        for _i,_v in ipairs(self.TemplatePrefixes.COMM) do
            if string.find(grp_prefix, _v) ~= nil then
                grp_coal = coalition.side.NEUTRAL
                grp_size = 1
                break
            end
        end
        BASE:E(grp_coal)
        BASE:E(grp_country)

        SPAWN_Group:InitRandomizeTemplatePrefixes(grp_prefix)
            :InitSkill("Random")
            :InitCountry(grp_country)
            :InitCoalition(grp_coal)
            :InitHeading(pic_anchor.heading)
            :InitGrouping(grp_size)
            :OnSpawnGroup(
                function( SpawnGroup )
                    setGroup_picture:AddGroup(SpawnGroup)
                    local mission = AUFTRAG:NewCAP(pic_tgt_ZONE, UTILS.MetersToFeet(pic_alt))
                    local fltGrp = FLIGHTGROUP:New(SpawnGroup)
                    fltGrp:AddMission(mission)
                    --fltGrp:AddWaypoint(pic_tgt_COORD, nil, nil, pic_alt)
                    fltGrp:SetDetection(true)
                    fltGrp:SetDefaultROE(pic_roe)

                    --function fltGrp:onafterPassingFinalWaypoint(From, Event, To)
                    --    self:_RemovePicture(pic_name)
                    --  end
                end
            )
        SPAWN_Group:SpawnFromCoordinate(pic_coords[i]:SetAltitude(pic_alt))

    end

    -- Creat SET_GROUP for this Picture
    local setGroup_picture = SET_GROUP:New():FilterPrefixes(pic_name):FilterOnce()
    -- Add this picture to the list of pictures
    self.Pictures[pic_name] = setGroup_picture

    -- If an F10 Menu was added for the Picture Painter, add this picture to Picture sub-menu
    local PictureMenu = MENU_MISSION:New(pic_name, self.Menu.Menus["Pictures"])
    MENU_MISSION_COMMAND:New("Remove", PictureMenu, self._RemovePicture, self, pic_name)
    local PictureMenu_EMCON = MENU_MISSION:New("Set EMCON Status", PictureMenu)
    MENU_MISSION_COMMAND:New("Disable Emissions", PictureMenu_EMCON, self._SetPictureEMCON, self, pic_name, true)
    MENU_MISSION_COMMAND:New("Enable Emissions", PictureMenu_EMCON, self._SetPictureEMCON, self, pic_name, false)
 
    local PictureMenu_ROE = MENU_MISSION:New("Set ROE", PictureMenu)
    MENU_MISSION_COMMAND:New("HOLD", PictureMenu_ROE, self._SetPictureROE, self, pic_name, ENUMS.ROE.WeaponHold)
    MENU_MISSION_COMMAND:New("RETURN FIRE", PictureMenu_ROE, self._SetPictureROE, self, pic_name, ENUMS.ROE.ReturnFire)
    MENU_MISSION_COMMAND:New("WPNS FREE", PictureMenu_ROE, self._SetPictureROE, self, pic_name, ENUMS.ROE.WeaponFree)
 
    local PictureMenu_Speed = MENU_MISSION:New("Set Speed", PictureMenu)
    MENU_MISSION_COMMAND:New("Slow", PictureMenu_Speed,  self._SetPictureSpeed, self, pic_name, .65)
    MENU_MISSION_COMMAND:New("Cruise", PictureMenu_Speed, self._SetPictureSpeed, self, pic_name, .8)
    MENU_MISSION_COMMAND:New("Fast", PictureMenu_Speed, self._SetPictureSpeed, self, pic_name, 1.1)
    MENU_MISSION_COMMAND:New("Very Fast", PictureMenu_Speed, self._SetPictureSpeed, self, pic_name, 1.5)
    MENU_MISSION_COMMAND:New("Max", PictureMenu_Speed, self._SetPictureSpeed, self, pic_name, 99)

    -- Despawn upon reaching target
    setGroup_picture:ScheduleRepeat(0, 60, 0, nil, 
        function()

            --local arrived_at_tgt = 0
            --setGroup_picture:ForEachGroupCompletelyInZone(pic_tgt_ZONE,
            --    function()
            --        arrived_at_tgt = arrived_at_tgt + 1
            --    end
           -- )
            --if (arrived_at_tgt > 0 ) then self:_RemovePicture(pic_name) end

            if setGroup_picture:AllCompletelyInZone(pic_tgt_ZONE) then 
                self:_RemovePicture(pic_name) 
            end
        end
    )

end
function PAINTER:SetDefaultROE(roe)
    self.Defaults.ROE = roe or self.Defaults.ROE
    return self
end
function PAINTER:SetProbAggressive(prob)
    self.Defaults.ProbAggressive = prob or self.ProbAggressive
    return self
end
function PAINTER:SetThreatAxis(bearing, swath)
    self.ThreatOrigin.Vector.Bearing = bearing or self.ThreatOrigin.Vector.Bearing
    self.ThreatOrigin.Vector.Swath = swath or self.ThreatOrigin.Vector.Swath
    return self
end
function PAINTER:SetThreatRange(min, max)
    self.ThreatOrigin.Vector.Range.min = min or self.ThreatOrigin.Vector.Range.min
    self.ThreatOrigin.Vector.Range.max = max or self.ThreatOrigin.Vector.Range.max
    return self
end

function PAINTER:_GetPictureSpeedCruise(pic_name)
    local max_speed = self:_GetPictureSpeedMax(pic_name) 
    local max_80_pcnt = max_speed * .8
    local kts_400 = UTILS.KnotsToMps(400)
    local cruise_speed = math.min(max_80_pcnt, kts_400)
    return cruise_speed
end
function PAINTER:_GetPictureSpeedMax(pic_name)
    local setGroup_picture = self.Pictures[pic_name]
    local min_max_speed = 999
    setGroup_picture:ForEachGroup( 
        -- @param Wrapper.Group#GROUP MooseGroup
        function( MooseGroup )
            --if (min_max_speed == nil) then min_max_speed = MooseGroup:GetSpeedMax()
            --else 
                min_max_speed = math.min(min_max_speed, MooseGroup:GetSpeedMax())
            --end
        end 
      )
    return min_max_speed
end
function PAINTER:_PictureAnchor(target_zone)
    local COORD_target = target_zone:GetCoordinate()
    local anchor = nil
    if self.ThreatOrigin.Zones == nil then
        local radial = math.random( self.ThreatOrigin.Vector.Bearing - self.ThreatOrigin.Vector.Swath/2, 
                                self.ThreatOrigin.Vector.Bearing + self.ThreatOrigin.Vector.Swath/2)
        local dist = math.random(self.ThreatOrigin.Vector.Range.min,self.ThreatOrigin.Vector.Range.max)
        anchor = COORD_target:Translate(UTILS.NMToMeters(dist), radial)
    else 
        anchor = COORDINATE:NewFromVec2(self.ThreatOrigin.Zones:GetRandomZone():GetRandomVec2())
    end
    local init_heading = anchor:GetAngleDegrees(anchor:GetDirectionVec3(COORD_target))
    return { anchor = anchor, heading = init_heading }
end
function PAINTER:_PictureAzimuth(anchor, heading, separation)
    local picture_coords = {anchor}
    picture_coords[2] = anchor:Translate(separation, heading + 90 )
    return picture_coords
end
function PAINTER:_PictureBox(anchor, heading, separation)
    local picture_coords = {anchor}
    picture_coords[2] = anchor:Translate(separation, heading + 90 )
    picture_coords[3] = anchor:Translate(separation, heading - 180 )
    picture_coords[4] = picture_coords[3]:Translate(separation, heading + 90 )
    return picture_coords
end
function PAINTER:_PictureChampagne(anchor, heading, separation)
    local picture_coords = {anchor}
    picture_coords[2] = anchor:Translate(separation, heading + 45 )
    picture_coords[3] = anchor:Translate(separation, heading - 45 )
    return picture_coords
end
function PAINTER:_PictureEchelon(anchor, heading, separation)
    local picture_coords = {anchor}
    picture_coords[2] = anchor:Translate(separation, heading + 135 )
    picture_coords[3] = anchor:Translate(separation, heading - 45 )
    return picture_coords
end
function PAINTER:_PictureLadder(anchor, heading, separation)
    local picture_coords = {anchor}
    picture_coords[2] = anchor:Translate(separation, heading + 180 )
    picture_coords[3] = anchor:Translate(separation * 2, heading - 180 )
    picture_coords[4] = anchor:Translate(separation * 3, heading - 180 )
    return picture_coords
end
function PAINTER:_PictureRange(anchor, heading, separation)
    local picture_coords = {anchor}
    picture_coords[2] = anchor:Translate(separation, heading + 180 )
    return picture_coords
end
function PAINTER:_PictureStinger(anchor, heading, separation)
    local picture_coords = self:__PictureChampagne(anchor, heading, separation)
    return picture_coords
end
function PAINTER:_PictureVic(anchor, heading, separation)
    local picture_coords = {anchor}
    picture_coords[2] = anchor:Translate(separation, heading + 135 )
    picture_coords[3] = anchor:Translate(separation, heading - 135 )
    return picture_coords
end
function PAINTER:_PictureWall(anchor, heading, separation)
    local picture_coords = {anchor}
    picture_coords[2] = anchor:Translate(separation, heading + 90 )
    picture_coords[3] = anchor:Translate(separation, heading - 90 )
    picture_coords[4] = anchor:Translate(separation *2, heading - 90 )
    return picture_coords
end
function PAINTER:_RemovePicture(pic_name)
    local picture_set_group = self.Pictures[pic_name]
    picture_set_group:ForEachGroup(
        function(MooseGroup) 
            if(MooseGroup:IsAlive()) then MooseGroup:Destroy() end
        end
    )
    self.Pictures[pic_name] = nil
    self.Menu:GetMenu("Pictures"):GetMenu(pic_name):Remove()

end
function PAINTER:_SetPictureEMCON(pic_name, emcon)
    local setGroup_picture = self.Pictures[pic_name]
    emcon = emcon or true
    setGroup_picture:ForEachGroup( 
        -- @param Wrapper.Group#GROUP MooseGroup
        function( MooseGroup ) 
            MooseGroup:EnableEmission(emcon)
        end
    )
end
function PAINTER:_SetPictureROE(pic_name, roe_enum)
    local setGroup_picture = self.Pictures[pic_name]
    setGroup_picture:ForEachGroup( 
        -- @param Wrapper.Group#GROUP MooseGroup
        function( MooseGroup ) 
            MooseGroup:OptionROE(roe_enum)
        end
    )
end
function PAINTER:_SetPictureSpeed(pic_name, mach)
    local setGroup_picture = self.Pictures[pic_name]
    local mach1 = 309.6
    local mach_table = {  
        -- alt in m,  mach 1 in m/s    
        { alt = 10668, mach = 295 },
        { alt = 9144, mach = 303 },
        { alt = 7620, mach = 309 },
        { alt = 6096, mach = 316 },
        { alt = 4572, mach = 322 },
        { alt = 3048, mach = 328 },
        { alt = 1524, mach = 334 }
    }
    local new_speed = self:_GetPictureSpeedCruise(pic_name)
    setGroup_picture:ForEachGroup( 
        -- @param Wrapper.Group#GROUP MooseGroup
        function( MooseGroup ) 
            if (string.find("Cruise", mach) == nil) then 
                local alt = MooseGroup:GetAltitude(false) -- get alt MSL
                for index, value in ipairs(mach_table) do
                    if (value.alt < alt) then mach1 = value.mach break end
                end
                new_speed = math.min(self:_GetPictureSpeedMax(pic_name), mach1 * mach)
            end
            MooseGroup:SetSpeed(new_speed, true)
        end 
    )
end

test_painter = PAINTER:New("Picture Painter 2", coalition.side.Blue)
test_painter.Debug = true
test_painter:AddDefendedAsset("McCarran International", UTILS.NMToMeters(10))
--test_painter:AddDefendedAsset("Lincoln County", UTILS.NMToMeters(10))

test_painter:AddMenu()
test_painter:SetThreatAxis(330, 120)
test_painter:SetTemplatePrefixes({"FTR", "ATK", "BMBR", "AWACS", "COMM"})
test_painter:AddThreatOriginZoneByName("71N")