
------------------------------------------------------------------------------
include "MapEnums"
include "MapUtilities"

print ("loading modded AssignStartingPlots")
local YnAMP_Version = GameInfo.GlobalParameters["YNAMP_VERSION"].Value -- can't use GlobalParameters.YNAMP_VERSION because Value is Text ?
print ("Yet (not) Another Maps Pack version " .. tostring(YnAMP_Version) .." (2016) by Gedemon")

------------------------------------------------------------------------------
-- **************************** YnAMP globals ******************************
------------------------------------------------------------------------------

print ("Setting YnAMP globals ...")

local mapName = MapConfiguration.GetValue("MapName")
print ("Map Name = " .. tostring(mapName))
local tableName = nil
if mapName then	tableName = mapName.."_StartPosition" end
local getTSL = {}
local bCulturallyLinked = MapConfiguration.GetValue("CulturallyLinkedStart") == "PLACEMENT_ETHNIC";
local bTSL = MapConfiguration.GetValue("CivilizationPlacement") == "PLACEMENT_TSL";

if bTSL then
	print ("Building TSL list for "..tostring(mapName).."...")
	for row in GameInfo[tableName]() do
		for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
			local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
			if row.Civilization == CivilizationTypeName then
				if row.Leader then
					local LeaderTypeName = PlayerConfigurations[iPlayer]:GetLeaderTypeName()
					if row.Leader == LeaderTypeName then
						print ("- "..tostring(CivilizationTypeName).."( leader = "..tostring(LeaderTypeName)..") at "..tostring(row.X)..","..tostring(row.Y))
						getTSL[iPlayer] = {X = row.X, Y = row.Y}
					end
				else
					print ("- "..tostring(CivilizationTypeName).." at "..tostring(row.X)..","..tostring(row.Y))
					getTSL[iPlayer] = {X = row.X, Y = row.Y}
				end
			end
		end	
	end
	
	-- List Civs without TSL
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		if not getTSL[iPlayer] then
			local player = Players[iPlayer]
			local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
			print ("WARNING : no starting position found for :" .. tostring(CivilizationTypeName) )
		end
	end
end
------------------------------------------------------------------------------
-- YnAMP >>>>>
------------------------------------------------------------------------------

------------------------------------------------------------------------------
AssignStartingPlots = {};
------------------------------------------------------------------------------
function AssignStartingPlots.Create(args)
	local instance  = {

		-- Core Process member methods
		__InitStartingData					= AssignStartingPlots.__InitStartingData,
		__SetStartMajor						= AssignStartingPlots.__SetStartMajor,
		__SetStartMinor						= AssignStartingPlots.__SetStartMinor,
		__GetWaterCheck						= AssignStartingPlots.__GetWaterCheck,
		__GetValidAdjacent					= AssignStartingPlots.__GetValidAdjacent,
		__NaturalWonderBuffer				= AssignStartingPlots.__NaturalWonderBuffer,
		__BonusResource						= AssignStartingPlots.__BonusResource,
		__TryToRemoveBonusResource			= AssignStartingPlots.__TryToRemoveBonusResource,
		__LuxuryBuffer						= AssignStartingPlots.__LuxuryBuffer,
		__StrategicBuffer					= AssignStartingPlots.__StrategicBuffer,
		__CivilizationBuffer				= AssignStartingPlots.__CivilizationBuffer,
		__MajorCivBuffer					= AssignStartingPlots.__MajorCivBuffer,
		__MinorCivBuffer					= AssignStartingPlots.__MinorCivBuffer,
		__WeightedFertility					= AssignStartingPlots.__WeightedFertility,
		__AddBonusFoodProduction			= AssignStartingPlots.__AddBonusFoodProduction,
		__AddFood							= AssignStartingPlots.__AddFood,
		__AddProduction						= AssignStartingPlots.__AddProduction,
		__InitStartBias						= AssignStartingPlots.__InitStartBias,
		__StartBiasResources				= AssignStartingPlots.__StartBiasResources,
		__StartBiasFeatures					= AssignStartingPlots.__StartBiasFeatures,
		__StartBiasTerrains					= AssignStartingPlots.__StartBiasTerrains,
		__StartBiasRivers					= AssignStartingPlots.__StartBiasRivers,
		__StartBiasPlotRemoval				= AssignStartingPlots.__StartBiasPlotRemoval,
		__SortByArray						= AssignStartingPlots.__SortByArray,
		__ArraySize							= AssignStartingPlots.__ArraySize,				
		__PreFertilitySort					= AssignStartingPlots.__PreFertilitySort,			
		__SortByFertilityArray				= AssignStartingPlots.__SortByFertilityArray,	
		__AddResourcesBalanced				= AssignStartingPlots.__AddResourcesBalanced,
		__AddResourcesLegendary				= AssignStartingPlots.__AddResourcesLegendary,
		__BalancedStrategic					= AssignStartingPlots.__BalancedStrategic,
		__FindSpecificStrategic				= AssignStartingPlots.__FindSpecificStrategic,
		__AddStrategic						= AssignStartingPlots.__AddStrategic,
		__AddLuxury							= AssignStartingPlots.__AddLuxury,
		__AddBonus							= AssignStartingPlots.__AddBonus,
		__IsContinentalDivide				= AssignStartingPlots.__IsContinentalDivide,

		iNumMajorCivs = 0,					
		iNumMinorCivs = 0,			
		iNumRegions		= 0,
		iDefaultNumberMajor = 0,
		iDefaultNumberMinor = 0,
		iFirstFertility = 0,
		uiMinMajorCivFertility = args.MIN_MAJOR_CIV_FERTILITY or 0,
		uiMinMinorCivFertility = args.MIN_MINOR_CIV_FERTILITY or 0,
		uiMinBarbarianFertility = args.MIN_BARBARIAN_FERTILITY or 0,
		uiStartMinY = args.START_MIN_Y or 0,
		uiStartMaxY = args.START_MAX_Y or 0,
		uiStartConfig = args.START_CONFIG or 2,
		waterMap  = args.WATER or false,
		landMap  = args.LAND or false,
		majorStartPlots = {},
		majorCopy = {},
		minorStartPlots = {},	
		minorCopy = {},
		majorList		= {},
		minorList		= {},
		player_ID_list	= {},
		playerstarts = {},
		sortedArray = {},
		sortedFertilityArray = {},

		-- Team info variables (not used in the core process, but necessary to many Multiplayer map scripts)
		
	}

	instance:__InitStartingData()
	


	return instance
end
------------------------------------------------------------------------------
function AssignStartingPlots:__InitStartingData()
	if(self.uiMinMajorCivFertility <= 0) then
		self.uiMinMajorCivFertility = 5;
	end

	if(self.uiMinMinorCivFertility <= 0) then
		self.uiMinMinorCivFertility = 5;
	end

	if(self.uiMinBarbarianFertility<= 0) then
		self.uiMinBarbarianFertility = 1;
	end
	
	self.iNumMajorCivs = PlayerManager.GetAliveMajorsCount();
	self.iNumMinorCivs = PlayerManager.GetAliveMinorsCount();
	self.iNumRegions = self.iNumMajorCivs + self.iNumMinorCivs;
	local iMinNumBarbarians = self.iNumMajorCivs / 2;

	local iBonusMajor = math.floor(self.iNumMajorCivs / 2);
	local iBonusMinor = math.floor(self.iNumMinorCivs / 2);

	if(iBonusMajor < 1) then
		iBonusMajor = 1;
	end

	if(iBonusMinor < 2) then
		iBonusMinor = 2;
	end

	StartPositioner.DivideMapIntoMajorRegions(self.iNumMajorCivs + iBonusMajor, self.iNumMinorCivs + iBonusMinor, iMinNumBarbarians, self.uiMinMajorCivFertility, self.uiMinMinorCivFertility, self.uiMinBarbarianFertility);
	
	local iMajorCivStartLocs = StartPositioner.GetNumMajorCivStarts();

	--Find Default Number
	MapSizeTypes = {};
	for row in GameInfo.Maps() do
		MapSizeTypes[row.RowId] = row.DefaultPlayers;
	end
	local sizekey = Map.GetMapSize() + 1;
	local iDefaultNumberPlayers = MapSizeTypes[sizekey] or 8;
	self.iDefaultNumberMajor = iDefaultNumberPlayers ;
	self.iDefaultNumberMinor = math.floor(iDefaultNumberPlayers * 1.5);

	self.iIndex = 0;
	self.player_ID_list = {};
	for i = 0, (self.iNumRegions) - 1 do
		table.insert(self.player_ID_list, i);
	end

	self.majorList = {};
	self.minorList = {};

	self.majorList = PlayerManager.GetAliveMajorIDs();
	self.minorList = PlayerManager.GetAliveMinorIDs();

	-- Place the major civ start plots in an array
	self.majorStartPlots = {};
	local failed = 0;
	for i = self.iNumMajorCivs - 1, 0, - 1 do
		plots = StartPositioner.GetMajorCivStartPlots(i);
		local startPlot = self:__SetStartMajor(plots);
		if(startPlot ~= nil) then
			StartPositioner.MarkMajorRegionUsed(i);
			table.insert(self.majorStartPlots, startPlot);
			info = StartPositioner.GetMajorCivStartInfo(i);
			--print ("ContinentType: " .. tostring(info.ContinentType));
			--print ("LandmassID: " .. tostring(info.LandmassID));
			--print ("Fertility: " .. tostring(info.Fertility));
			--print ("TotalPlots: " .. tostring(info.TotalPlots));
			--print ("WestEdge: " .. tostring(info.WestEdge));
			--print ("EastEdge: " .. tostring(info.EastEdge));
			--print ("NorthEdge: " .. tostring(info.NorthEdge));
			--print ("SouthEdge: " .. tostring(info.SouthEdge));
		else
			failed = failed + 1;
			info = StartPositioner.GetMajorCivStartInfo(i);
			--print ("XContinentType: " .. tostring(info.ContinentType));
			--print ("XLandmassID: " .. tostring(info.LandmassID));
			--print ("XFertility: " .. tostring(info.Fertility));
			--print ("XTotalPlots: " .. tostring(info.TotalPlots));
			--print ("XWestEdge: " .. tostring(info.WestEdge));
			--print ("XEastEdge: " .. tostring(info.EastEdge));
			--print ("XNorthEdge: " .. tostring(info.NorthEdge));
			--print ("XSouthEdge: " .. tostring(info.SouthEdge));
			--print("FAilED Major");
		end
	end


	local count = self.iNumMajorCivs;
	while failed > 0 and iMajorCivStartLocs > count do
		plots = StartPositioner.GetMajorCivStartPlots(count);
		local startPlot = self:__SetStartMajor(plots);
		if(startPlot ~= nil) then
			StartPositioner.MarkMajorRegionUsed(count);
			table.insert(self.majorStartPlots, startPlot);
			info = StartPositioner.GetMajorCivStartInfo(count);
			--print ("ContinentType2: " .. tostring(info.ContinentType));
			--print ("LandmassID2: " .. tostring(info.LandmassID));
			--print ("Fertility2: " .. tostring(info.Fertility));
			--print ("TotalPlots2: " .. tostring(info.TotalPlots));
			--print ("WestEdge2: " .. tostring(info.WestEdge));
			--print ("EastEdge2: " .. tostring(info.EastEdge));
			--print ("NorthEdge2: " .. tostring(info.NorthEdge));
			--print ("SouthEdge2: " .. tostring(info.SouthEdge));
			failed = failed - 1;
		else
			info = StartPositioner.GetMajorCivStartInfo(count);
			--print ("X2ContinentType: " .. tostring(info.ContinentType));
			--print ("X2LandmassID: " .. tostring(info.LandmassID));
			--print ("X2Fertility: " .. tostring(info.Fertility));
			--print ("X2TotalPlots: " .. tostring(info.TotalPlots));
			--print ("X2WestEdge: " .. tostring(info.WestEdge));
			--print ("X2EastEdge: " .. tostring(info.EastEdge));
			--print ("X2NorthEdge: " .. tostring(info.NorthEdge));
			--print ("X2SouthEdge: " .. tostring(info.SouthEdge));
			--print("faILed MAJOR MINOR");
		end
		count = count + 1;
	end

	for k, plot in ipairs(self.majorStartPlots) do
		table.insert(self.majorCopy, plot);
	end

	--Begin Start Bias for major
	self:__InitStartBias(false);

	if(self.uiStartConfig == 1 ) then
		self:__AddResourcesBalanced();
	elseif(self.uiStartConfig == 3 ) then
		self:__AddResourcesLegendary();
	end

	for i = 1, self.iNumMajorCivs do
		local player = Players[self.majorList[i]]
		
		if(player == nil) then
			--print("THIS PLAYER FAILED");
		else
			local hasPlot = false;
			for k, v in pairs(self.playerStarts[i]) do
				if(v~= nil and hasPlot == false) then
					hasPlot = true;
					--player:SetStartingPlot(v);
					-- YnAMP <<<<<
					if not bTSL or getTSL[self.majorList[i]] then
						player:SetStartingPlot(v);					
					end
					-- YnAMP >>>>>
					--print("Major Start X: ", v:GetX(), "Major Start Y: ", v:GetY());
				end
			end
		end
	end

	--Place the minor start plots in an array
	self.minorStartPlots = {};
	StartPositioner.DivideUnusedRegions();
	local iMinorCivStartLocs = StartPositioner.GetNumMinorCivStarts();
	local iBarbarianStartLocs = StartPositioner.GetNumBarbarianStarts();
	local i = 0;
	local valid = 0;
	while i <= iMinorCivStartLocs - 1 and valid < self.iNumMinorCivs do
		plots = StartPositioner.GetMinorCivStartPlots(i);
		local startPlot = self:__SetStartMinor(plots);
		info = StartPositioner.GetMinorCivStartInfo(i);
		if(startPlot ~= nil) then
			table.insert(self.minorStartPlots, startPlot);
			--print ("Minor ContinentType: " .. tostring(info.ContinentType));
			--print ("Minor LandmassID: " .. tostring(info.LandmassID));
			--print ("Minor Fertility: " .. tostring(info.Fertility));
			--print ("Minor TotalPlots: " .. tostring(info.TotalPlots));
			--print ("Minor WestEdge: " .. tostring(info.WestEdge));
			--print ("Minor EastEdge: " .. tostring(info.EastEdge));
			--print ("Minor NorthEdge: " .. tostring(info.NorthEdge));
			--print ("Minor SouthEdge: " .. tostring(info.SouthEdge));
			--print("Minor Tried to Start X: ", plot:GetX(), "Minor Tried to Start Y: ", plot:GetY());
			valid = valid + 1;
		else
			--print ("BAAAD Minor ContinentType: " .. tostring(info.ContinentType));
			--print ("BAAAD Minor LandmassID: " .. tostring(info.LandmassID));
			--print ("BAAAD Minor Fertility: " .. tostring(info.Fertility));
			--print ("BAAAD Minor TotalPlots: " .. tostring(info.TotalPlots));
			--print ("BAAAD Minor WestEdge: " .. tostring(info.WestEdge));
			--print ("BAAAD Minor EastEdge: " .. tostring(info.EastEdge));
			--print ("BAAAD Minor NorthEdge: " .. tostring(info.NorthEdge));
			--print ("BAAAD Minor SouthEdge: " .. tostring(info.SouthEdge));
			--print("faILed MINOR");
		end
		
		i = i + 1;
	end

	for k, plot in ipairs(self.minorStartPlots) do
		table.insert(self.minorCopy, plot);
	end

	--Begin Start Bias for minor
	self:__InitStartBias(true);

	for i = 1, self.iNumMinorCivs do
		local player = Players[self.minorList[i]]
		
		if(player == nil) then
			--print("THIS PLAYER FAILED");
		else
			local hasPlot = false;
			for k, v in pairs(self.playerStarts[i + self.iNumMajorCivs]) do
				if(v~= nil and hasPlot == false) then
					hasPlot = true;
					--player:SetStartingPlot(v);
					-- YnAMP <<<<<
					if not bTSL or getTSL[self.minorList[i]] then
						player:SetStartingPlot(v);					
					end
					-- YnAMP >>>>>
					--print("Minor Start X: ", v:GetX(), "Minor Start Y: ", v:GetY());
				end
			end
		end
	end

	-- YnAMP
	YnAMP_StartPositions()
	-- / YnAMP
end

------------------------------------------------------------------------------
function AssignStartingPlots:__SetStartMajor(plots)
	-- Sort by fertility of all the plots
	-- eliminate them if they do not meet the following:
	-- distance to another civilization
	-- distance to a natural wonder
	-- minimum production
	-- minimum food
	-- minimum luxuries
	-- minimum strategic

	sortedPlots ={};

	local iSize = #plots;
	local iContinentIndex = 1;

	for i, plot in ipairs(plots) do
		row = {};
		row.Plot = plot;
		row.Fertility = self:__WeightedFertility(plot);
		table.insert (sortedPlots, row);
	end

	if(self.uiStartConfig > 1 ) then
		table.sort (sortedPlots, function(a, b) return a.Fertility > b.Fertility; end);
	else
		self.sortedFertilityArray = {};
		sortedPlotsFertility = {};
		sortedPlotsFertility = self:__PreFertilitySort(sortedPlots);
		self:__SortByFertilityArray(sortedPlots, sortedPlotsFertility);
		for k, v in pairs(sortedPlots) do
			sortedPlots[k] = nil;
		end
		for i, newPlot in ipairs(self.sortedFertilityArray) do
			row = {};
			row.Plot = newPlot.Plot;
			row.Fertility = newPlot.Fertility;
			table.insert (sortedPlots, row);
		end
	end

	local bValid = false;
	while bValid == false and iSize >= iContinentIndex do
		bValid = true;
		local NWMajor = 0;
		pTempPlot = Map.GetPlotByIndex(sortedPlots[iContinentIndex].Plot);
		iContinentIndex = iContinentIndex + 1;
		--print("Fertility: ", sortedPlots[iContinentIndex].Fertility)

		-- Checks to see if the plot is impassable
		if(pTempPlot:IsImpassable() == true) then
			bValid = false;
		end

		-- Checks to see if the plot is water
		if(pTempPlot:IsWater() == true) then
			bValid = false;
		end

		-- Checks to see if there are resources
		if(pTempPlot:GetResourceCount() > 0) then
		   local bValidResource = self:__BonusResource(pTempPlot);
		    if(bValidResource == false) then
		       bValid = false;
		    end
		end

		-- Checks to see if there are luxuries
		if (math.ceil(self.iDefaultNumberMajor * 1.25) + self.iDefaultNumberMinor > self.iNumMinorCivs + self.iNumMajorCivs) then
			local bLuxuryCheck = self:__LuxuryBuffer(pTempPlot); 
			if(bLuxuryCheck  == false) then
				bValid = false;
			end
		end
		

		--Checks to see if there are strategics
		-- local bStrategicCheck = self:__StrategicBuffer(pTempPlot); 
		-- if(bStrategicCheck  == false) then
		-- 	bValid = false;
		-- end

		-- Checks to see if there is fresh water or coast
		local bWaterCheck = self:__GetWaterCheck(pTempPlot); 
		if(bWaterCheck == false) then
			bValid = false;
		end

		local bValidAdjacentCheck = self:__GetValidAdjacent(pTempPlot, 0); 
		if(bValidAdjacentCheck == false) then
			bValid = false;
		end

		-- Checks to see if there are natural wonders in the given distance
		local bNaturalWonderCheck = self:__NaturalWonderBuffer(pTempPlot, false); 
		if(bNaturalWonderCheck == false) then
			bValid = false;
		end

		-- Checks to see if there are any major civs in the given distance
		local bMajorCivCheck = self:__MajorCivBuffer(pTempPlot); 
		if(bMajorCivCheck == false) then
			bValid = false;
		end

		-- Checks to see if there is an Oasis
		local featureType = pTempPlot:GetFeatureType();
		if(featureType == g_FEATURE_OASIS) then
			bValid = false;
		end

		-- If the plots passes all the checks then the plot equals the temp plot
		if(bValid == true) then
			self:__TryToRemoveBonusResource(pTempPlot);
			self:__AddBonusFoodProduction(pTempPlot);
			return pTempPlot;
		end
	end
 
	return nil;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__SetStartMinor(plots)
	-- Sort by fertility of all the plots
	-- eliminate them if they do not meet the following:
	-- distance to another civilization
	-- distance to a natural wonder
	-- minimum production
	-- minimum food

	sortedPlots ={};

	local iSize = #plots;
	local iContinentIndex = 1;

	for i, plot in ipairs(plots) do
		row = {};
		row.Plot = plot;
		row.Fertility = self:__WeightedFertility(plot);
		table.insert (sortedPlots, row);
	end

	table.sort (sortedPlots, function(a, b) return a.Fertility > b.Fertility; end);

	local bValid = false;
	while bValid == false and iSize >= iContinentIndex do
		bValid = true;
		local NWMinor = 2;
		pTempPlot = Map.GetPlotByIndex(sortedPlots[iContinentIndex].Plot);
		iContinentIndex = iContinentIndex + 1;
		--print("Fertility: ", sortedPlots[iContinentIndex].Fertility)

		-- Checks to see if the plot is impassable
		if(pTempPlot:IsImpassable() == true) then
			bValid = false;
		end

		-- Checks to see if the plot is water
		if(pTempPlot:IsWater() == true) then
			bValid = false;
		end

		-- Checks to see if there are resources
		if(pTempPlot:GetResourceCount() > 0) then
			local bValidResource = self:__BonusResource(pTempPlot);
			if(bValidResource == false) then
				bValid = false;
			end
		end

		local bValidAdjacentCheck = self:__GetValidAdjacent(pTempPlot, 2); 
		if(bValidAdjacentCheck == false) then
			bValid = false;
		end

		-- Checks to see if there are natural wonders in the given distance
		local bNaturalWonderCheck = self:__NaturalWonderBuffer(pTempPlot, true); 
		if(bNaturalWonderCheck == false) then
			bValid = false;
		end

		-- Checks to see if there are any minor civs in the given distance
		local bMinorCivCheck = self:__MinorCivBuffer(pTempPlot, 1); 
		if(bMinorCivCheck == false) then
			bValid = false;
		end

		-- Checks to see if there is an Oasis
		local featureType = pTempPlot:GetFeatureType();
		if(featureType == g_FEATURE_OASIS) then
			bValid = false;
		end

		-- If the plots passes all the checks then the plot equals the temp plot
		if(bValid == true) then
			self:__TryToRemoveBonusResource(pTempPlot);
			return pTempPlot;
		end
	end
 
	return nil;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__GetWaterCheck(plot)

	--Checks to see if there is water: rivers, it is a coastal hex, or adjacent fresh water
	local gridWidth, gridHeight = Map.GetGridSize();

	if(plot:IsFreshWater() == true) then
		return true;
	elseif( plot:IsCoastalLand() == true) then
		return true;
	end

	return false;
end
------------------------------------------------------------------------------
function AssignStartingPlots:__GetValidAdjacent(plot, minor)
	
	local impassable = 0;
	local food = 0;
	local production = 0;
	local water = 0;
	local desert = 0;
	local snow = 0;
	local gridWidth, gridHeight = Map.GetGridSize();
	local terrainType = plot:GetTerrainType();

	-- Add to the Snow Desert counter if snow shows up
	if(terrainType == g_TERRAIN_TYPE_SNOW or terrainType == g_TERRAIN_TYPE_SNOW_HILLS) then
		snow = snow + 1;
	end
	
	-- Add to the Snow Desert counter if desert shows up
	if(terrainType == g_TERRAIN_TYPE_DESERT or terrainType == g_TERRAIN_TYPE_DESERT_HILLS) then
		desert = desert + 1;
	end

	local max = 0;
	local min = 0; 
	if(minor == 0) then
		max = math.ceil(gridHeight * self.uiStartMaxY / 100);
		min = math.ceil(gridHeight * self.uiStartMinY / 100);
	end

	if(plot:GetY() <= min or plot:GetY() > gridHeight - max) then
		return false;
	end

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
		if (adjacentPlot ~= nil) then
			terrainType = adjacentPlot:GetTerrainType();
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				-- Checks to see if the plot is impassable
				if(adjacentPlot:IsImpassable() == true) then
					impassable = impassable + 1;
				end

				-- Checks to see if the plot is water
				if(adjacentPlot:IsWater() == true) then
					water = water + 1;
				end

				-- Add to the Snow Desert counter if snow shows up
				if(terrainType == g_TERRAIN_TYPE_SNOW or terrainType == g_TERRAIN_TYPE_SNOW_HILLS) then
					snow = snow + 1;
				end
			
				-- Add to the Snow Desert counter if desert shows up
				if(terrainType == g_TERRAIN_TYPE_DESERT or terrainType == g_TERRAIN_TYPE_DESERT_HILLS) then
					desert = desert + 1;
				end

				food = food + adjacentPlot:GetYield(g_YIELD_FOOD);
				production = production + adjacentPlot:GetYield(g_YIELD_PRODUCTION);
			else
				impassable = impassable + 1;
			end
		end
	end 

	--if(minor == 0) then
	--	print("X: ", plot:GetX(), " Y: ", plot:GetY(), " Food ", food, "Production: ", production);
	--end

	local balancedStart = 0;
	if(self.uiStartConfig == 1 and  minor == 0) then
		balancedStart = 1;
	end

	if(impassable >= 2 + minor - balancedStart or (self.LandMap == true and impassable >= 2 + minor)) then
		return false;
	elseif(water + impassable  >= 4 + minor - balancedStart and self.waterMap == false) then
		return false;
	elseif(water >= 3 + minor - balancedStart) then
		return false;
	elseif(water >= 4 + minor and self.waterMap == true) then
		return false;
	elseif(minor == 0 and desert > 2 - balancedStart) then
		return false;
	elseif(minor == 0 and snow > 1 - balancedStart) then
		return false;
	elseif(minor > 0 and snow > 2) then
		return false;
	else
		return true;
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__WeightedFertility(plot)
	-- Calculate the fertility of the starting plot
	local iRange = 3;
	local pPlot = Map.GetPlotByIndex(plot);
	local plotX = pPlot:GetX();
	local plotY = pPlot:GetY();

	local gridWidth, gridHeight = Map.GetGridSize();
	local gridHeightMinus1 = gridHeight - 1;

	--Rivers are awesome to start next to
	local iFertility = 0;
	local terrainType = pPlot:GetTerrainType();
	if(pPlot:IsRiver() == true and terrainType ~= g_TERRAIN_TYPE_SNOW and terrainType ~= g_TERRAIN_TYPE_SNOW_HILLS and pPlot:IsImpassable() ~= true) then
		iFertility = iFertility + 100;
	end
	
	for dx = -iRange, iRange do
		for dy = -iRange,iRange do
			local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, iRange);

			-- Valid plot?  Also, skip plots along the top and bottom edge
			if(otherPlot) then
				local otherPlotY = otherPlot:GetY();
				if(otherPlotY > 0 and otherPlotY < gridHeightMinus1) then

					terrainType = otherPlot:GetTerrainType();
					featureType = otherPlot:GetFeatureType();

					-- Subtract one if there is snow and no resource. Do not count water plots unless there is a resource
					if((terrainType == g_TERRAIN_TYPE_SNOW or terrainType == g_TERRAIN_TYPE_SNOW_HILLS or terrainType == g_TERRAIN_TYPE_SNOW_MOUNTAIN) and otherPlot:GetResourceCount() == 0) then
						iFertility = iFertility - 10;
					elseif(featureType == g_FEATURE_ICE) then
						iFertility = iFertility - 20;
					elseif((otherPlot:IsWater() == false and self.waterMap == false) or otherPlot:GetResourceCount() > 0) then
						iFertility = iFertility + StartPositioner.GetPlotFertility(otherPlot:GetIndex());
					end
				
					-- Lower the Fertility if the plot is impassable
					if(iFertility > 5 and otherPlot:IsImpassable() == true) then
						iFertility = iFertility - 5;
					end

					if(featureType ~= g_FEATURE_NONE) then
						iFertility = iFertility - 3;
					end	
				else
					iFertility = iFertility - 20;
				end
			else
				iFertility = iFertility - 20;
			end
		end
	end 

	return iFertility;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__NaturalWonderBuffer(plot, minor)
	-- Returns false if the player can start because there is a natural wonder too close.

	-- If Start position config equals legendary you can start near Natural wonders
	if(self.uiStartConfig == 3) then
		return true;
	end

	local iMaxNW = 4;
	
	
	if(minor == true) then
		iMaxNW = GlobalParameters.START_DISTANCE_MINOR_NATURAL_WONDER or 3;
	else
		iMaxNW = GlobalParameters.START_DISTANCE_MAJOR_NATURAL_WONDER or 4;
	end


	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -iMaxNW, iMaxNW do
		for dy = -iMaxNW,iMaxNW do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, iMaxNW);
			if(otherPlot and otherPlot:IsNaturalWonder()) then
				return false;
			end
		end
	end 

	return true;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__BonusResource(plot)
	--Finds bonus resources

	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	--Find bonus resource
	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			if(eResourceType[row] == plot:GetResourceType()) then
				return true;
			end
		end		
	end 

	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__TryToRemoveBonusResource(plot)
	--Removes Bonus Resources underneath starting players

	--Remove bonus resource
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			if(eResourceType[row] == plot:GetResourceType()) then
				ResourceBuilder.SetResourceType(plot, -1);
			end
		end		
	end 
end

------------------------------------------------------------------------------
function AssignStartingPlots:__LuxuryBuffer(plot)
	-- Checks to see if there are luxuries in the given distance

	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -2, 2 do
		for dy = -2,2 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
			if(otherPlot) then
				if(otherPlot:GetResourceCount() > 0) then
					for row = 0, iResourcesInDB do
						if (eResourceClassType[row]== "RESOURCECLASS_LUXURY") then
							if(eResourceType[row] == otherPlot:GetResourceType()) then
								return true;
							end
						end
					end
				end
			end
		end
	end 

	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StrategicBuffer(plot)
	-- Checks to see if there are strategics in the given distance

	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -2, 2 do
		for dy = -2,2 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
			if(otherPlot) then
				if(otherPlot:GetResourceCount() > 0) then
					for row = 0, iResourcesInDB do
						if (eResourceClassType[row]== "RESOURCECLASS_STRATEGIC") then
							if(eResourceType[row] == otherPlot:GetResourceType()) then
								return true;
							end
						end
					end
				end
			end
		end
	end 

	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__MajorCivBuffer(plot)
	-- Checks to see if there are major civs in the given distance for this major civ

	local iMaxStart = GlobalParameters.START_DISTANCE_MAJOR_CIVILIZATION or 9;

	if(self.waterMap == true) then
		iMaxStart = iMaxStart - 2;
	else
		if(self.iDefaultNumberMajor > 4 and self.iNumMajorCivs <= self.iDefaultNumberMajor) then
			iMaxStart = iMaxStart + 1;
		end
	end

	local iSourceIndex = plot:GetIndex();
	for i, majorPlot in ipairs(self.majorStartPlots) do
		if(Map.GetPlotDistance(iSourceIndex, majorPlot:GetIndex()) <= iMaxStart) then
			return false;
		end
	end 

	return true;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__MinorCivBuffer(plot, minorAdjustment)
	-- Checks to see if there are civs in the given distance for this minor civ

	local iMaxStart = GlobalParameters.START_DISTANCE_MINOR_CIVILIZATION or 5;

	local iSourceIndex = plot:GetIndex();

	if(self.waterMap == true) then
		if(minorAdjustment > 0) then
			iMaxStart = iMaxStart - 1;
		end
	else
		if(self.iDefaultNumberMajor > 4 and self.iNumMajorCivs <= self.iDefaultNumberMajor and self.iNumMinorCivs <= self.iDefaultNumberMinor) then
			iMaxStart = iMaxStart + 2;
		end
	end

	for i, majorPlot in ipairs(self.majorCopy) do
		if(Map.GetPlotDistance(iSourceIndex, majorPlot:GetIndex()) <= iMaxStart) then
			return false;
		end
	end 

	--Check if there there is a minor civ too close to a minor
	iMaxStart = iMaxStart - minorAdjustment;
	for i, minorPlot in ipairs(self.minorStartPlots) do
		if(Map.GetPlotDistance(iSourceIndex, minorPlot:GetIndex()) <= iMaxStart) then
			return false;
		end
	end 

	return true;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddBonusFoodProduction(plot)
	local food = 0;
	local production = 0;
	local maxFood = 0;
	local maxProduction = 0;
	local gridWidth, gridHeight = Map.GetGridSize();
	local terrainType = plot:GetTerrainType();

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
		if (adjacentPlot ~= nil) then
			terrainType = adjacentPlot:GetTerrainType();
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				-- Gets the food and productions
				food = food + adjacentPlot:GetYield(g_YIELD_FOOD);
				production = production + adjacentPlot:GetYield(g_YIELD_PRODUCTION);

				--Checks the maxFood
				if(maxFood <=  adjacentPlot:GetYield(g_YIELD_FOOD)) then
					maxFood = adjacentPlot:GetYield(g_YIELD_FOOD);
				end

				--Checks the maxProduction
				if(maxProduction <=  adjacentPlot:GetYield(g_YIELD_PRODUCTION)) then
					maxProduction = adjacentPlot:GetYield(g_YIELD_PRODUCTION);
				end
			end
		end
	end 

	if(food < 7 or maxFood < 3) then
		--print("X: ", plot:GetX(), " Y: ", plot:GetY(), " Food Time");
		self:__AddFood(plot); 
	end

	if(production < 5 or maxProduction < 2) then
		--print("X: ", plot:GetX(), " Y: ", plot:GetY(), " Production Time");
		self:__AddProduction(plot); 
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddFood(plot)
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			for row2 in GameInfo.TypeTags() do
				if(GameInfo.Resources[row2.Type] ~= nil) then
					if(GameInfo.Resources[row2.Type].Index== eResourceType[row] and row2.Tag=="CLASS_FOOD") then
						table.insert(aBonus, eResourceType[row]);
					end
				end
			end
		end
	end

	local dir = TerrainBuilder.GetRandomNumber(DirectionTypes.NUM_DIRECTION_TYPES, "Random Direction");
	for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), dir);
		if (adjacentPlot ~= nil) then
			aShuffledBonus =  GetShuffledCopyOfTable(aBonus);
			for i, bonus in ipairs(aShuffledBonus) do
				if(ResourceBuilder.CanHaveResource(adjacentPlot, bonus)) then
					--print("X: ", adjacentPlot:GetX(), " Y: ", adjacentPlot:GetY(), " Resource #: ", bonus);
					ResourceBuilder.SetResourceType(adjacentPlot, bonus, 1);
					return;
				end
			end
		end


		if(dir == DirectionTypes.NUM_DIRECTION_TYPES - 1) then
			dir = 0;
		else
			dir = dir + 1;
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddProduction(plot)
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			for row2 in GameInfo.TypeTags() do
				if(GameInfo.Resources[row2.Type] ~= nil) then
					if(GameInfo.Resources[row2.Type].Index== eResourceType[row] and row2.Tag=="CLASS_PRODUCTION") then
						table.insert(aBonus, eResourceType[row]);
					end
				end
			end
		end
	end

	local dir = TerrainBuilder.GetRandomNumber(DirectionTypes.NUM_DIRECTION_TYPES, "Random Direction");
	for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), dir);
		if (adjacentPlot ~= nil) then
			aShuffledBonus =  GetShuffledCopyOfTable(aBonus);
			for i, bonus in ipairs(aShuffledBonus) do
				if(ResourceBuilder.CanHaveResource(adjacentPlot, bonus)) then
					--print("X: ", adjacentPlot:GetX(), " Y: ", adjacentPlot:GetY(), " Resource #: ", bonus);
					ResourceBuilder.SetResourceType(adjacentPlot, bonus, 1);
					return;
				end
			end
		end


		if(dir == DirectionTypes.NUM_DIRECTION_TYPES - 1) then
			dir = 0;
		else
			dir = dir + 1;
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__InitStartBias(minor)
	--Create an array of each starting plot for each civ
	self.playerStarts = {};
	if (minor == true) then
		for i = 1, self.iNumMinorCivs do
			local playerStart = {}
			for j, plot in ipairs(self.minorStartPlots) do
				playerStart[j] = plot;
			end
			self.playerStarts[self.iNumMajorCivs + i] = playerStart
		end
	else
		for i = 1, self.iNumMajorCivs do
			local playerStart = {}
			for j, plot in ipairs(self.majorStartPlots) do
				playerStart[j] = plot;
			end
			self.playerStarts[i] = playerStart;
		end
	end

	--Find the Max tier
	local max = 0; 
	for row in GameInfo.StartBiasResources() do
		if( row.Tier > max) then
			max = row.Tier;
		end
	end
	for row in GameInfo.StartBiasFeatures() do
		if( row.Tier > max) then
			max = row.Tier;
		end
	end
	for row in GameInfo.StartBiasTerrains() do
		if( row.Tier > max) then
			max = row.Tier;
		end
	end
	for row in GameInfo.StartBiasRivers() do
		if(row.Tier > max) then
			max = row.Tier;
		end
	end

	
	for i = 1, max do
		players = {};
		
		--Add all the civs that are in this tier to a table
		if(minor == true) then
			for j = 1, self.iNumMinorCivs do
				local playerIndex = self.iNumMajorCivs + j;
				local civilizationType = PlayerConfigurations[self.minorList[j]]:GetCivilizationTypeName();

				for row in GameInfo.StartBiasResources() do
					if(row.CivilizationType == civilizationType) then
						if( row.Tier == i) then
							table.insert(players, playerIndex);
						end
					end
				end

				for row in GameInfo.StartBiasFeatures() do
					if(row.CivilizationType == civilizationType) then
						if( row.Tier == i) then
							table.insert(players, playerIndex);
						end
					end
				end

				for row in GameInfo.StartBiasTerrains() do
					if(row.CivilizationType == civilizationType) then
						if( row.Tier == i) then
							table.insert(players, playerIndex);
						end
					end
				end

				for row in GameInfo.StartBiasRivers() do
					if(row.CivilizationType == civilizationType) then
						if( row.Tier == i) then
							table.insert(players, playerIndex);
						end
					end
				end
			end
		else
			for j = 1, self.iNumMajorCivs do
				local playerIndex = j;
				local civilizationType = PlayerConfigurations[self.majorList[j]]:GetCivilizationTypeName();
				for row in GameInfo.StartBiasResources() do
					if(row.CivilizationType == civilizationType) then
						if( row.Tier == i) then
							table.insert(players, playerIndex);
						end
					end
				end

				for row in GameInfo.StartBiasFeatures() do
					if(row.CivilizationType == civilizationType) then
						if( row.Tier == i) then
							table.insert(players, playerIndex);
						end
					end
				end

				for row in GameInfo.StartBiasTerrains() do
					if(row.CivilizationType == civilizationType) then
						if( row.Tier == i) then
							table.insert(players, playerIndex);
						end
					end
				end

				for row in GameInfo.StartBiasRivers() do
					if(row.CivilizationType == civilizationType) then
						if( row.Tier == i) then
							table.insert(players, playerIndex);
						end
					end
				end
			end
		end


		players =  GetShuffledCopyOfTable(players); -- Shuffle the table
		-- Go through all the players in this tier
		for j, playerIndex in ipairs(players) do
			local playerId = (playerIndex > self.iNumMajorCivs) and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
			local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
			
			--Check if this player has a resource bias then it calls that method
			local resource = false;
			for row in GameInfo.StartBiasResources() do
				if(row.CivilizationType == civilizationType) then
					if( row.Tier == i) then
						resource = true;
					end
				end
			end
			if(resource == true) then
				self:__StartBiasResources(playerIndex, i, minor);
			end

			--Check if this player has a feature bias then it calls that method
			local feature = false;
			for row in GameInfo.StartBiasFeatures() do
				if(row.CivilizationType == civilizationType) then
					if( row.Tier == i) then
						feature = true;
					end
				end
			end
			if(feature == true) then
				self:__StartBiasFeatures(playerIndex, i, minor);
			end

			--Check if this player has a terrain bias then it calls that method
			local terrain = false;
			for row in GameInfo.StartBiasTerrains() do
				if(row.CivilizationType == civilizationType) then
					if( row.Tier == i) then
						terrain = true;
					end
				end
			end
			if(terrain == true) then
				self:__StartBiasTerrains(playerIndex, i, minor);
			end

			--Check if this player has a river bias then it calls that method
			local river = false;
			for row in GameInfo.StartBiasRivers() do
				if(row.CivilizationType == civilizationType) then
					if( row.Tier == i) then
						river = true;
					end
				end
			end
			if(river == true) then
				self:__StartBiasRivers(playerIndex, i, minor);
			end
		end

		local minorModifier = 0;
		if(minor == true) then
			minorModifier = self.iNumMajorCivs;
		end

		if(i == max) then
			local loop = self.iNumMajorCivs;

			if(minor == true) then
				loop = self.iNumMinorCivs;
			end

			for j = 1, loop do
				if(self:__ArraySize(self.playerStarts, j + minorModifier) > 1) then
					for k, v in pairs(self.playerStarts[j + minorModifier]) do
						if(v~= nil) then
							--Call Removal
							self:__StartBiasPlotRemoval(v, minor, j + minorModifier);
						end
					end
				end
			end
		else
			for j, playerIndex in ipairs(players) do
				local hasPlot = false;

				if(self:__ArraySize(self.playerStarts, playerIndex) > 1) then
					for k, v in pairs(self.playerStarts[playerIndex]) do
						if(v~= nil and hasPlot == false) then
							hasPlot = true;
							--Call Removal
							self:__StartBiasPlotRemoval(v, minor, playerIndex);
						end
					end
				end
			end
		end
	end
	

	-- Safety net for starting plots
	playerRestarts = {};
	local loop = 0;
	if (minor == true) then
		loop = self.iNumMinorCivs;
		
		for k, plot in ipairs(self.minorCopy) do
			table.insert(playerRestarts, plot);
		end

		for i = 1, self.iNumMinorCivs do
			local removed = false;
			for j, plot in pairs(self.playerStarts[i + self.iNumMajorCivs]) do
				for k, rePlot in ipairs(playerRestarts) do
					if(plot:GetIndex() == rePlot:GetIndex() and removed == false) then
						table.remove(playerRestarts, k);
						removed = true;
					end
				end
			end
		end
	else
		loop = self.iNumMajorCivs;
		
		for k, plot in ipairs(self.majorCopy) do
			table.insert(playerRestarts, plot);
		end

		for i = 1, self.iNumMajorCivs do
			local removed = false;
			for j, plot in pairs(self.playerStarts[i]) do
				for k, rePlot in ipairs(playerRestarts) do
					if(plot:GetIndex() == rePlot:GetIndex() and removed == false) then
						table.remove(playerRestarts, k);
						removed = true;
					end
				end
			end
		end
	end

	
	for i = 1, loop do
		local bHasStart = false;

		local offset = minor and self.iNumMajorCivs or 0;

		for j, plot in pairs(self.playerStarts[i + offset]) do
			if(plot ~= nil) then
				bHasStart = true;
			end
		end

		if(bHasStart == false) then
			local bNeedPlot = true;
			local index = -1;
			for j, plot in ipairs(playerRestarts) do
				if (plot ~= nil and bNeedPlot == true) then
					bNeedPlot = false;
					index = j;
				end
			end
			if(bNeedPlot == true) then
				--print("Start Bias Error");
			else
				table.insert(self.playerStarts[i + offset], playerRestarts[index]);
				table.remove(playerRestarts, index);
			end
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasResources(playerIndex, tier, minor)
	local numResource = 0;
	resources = {}

	local playerId = minor and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
	local playerStart = self.playerStarts[playerIndex];

	-- Find the resouces in this tier
	for row in GameInfo.StartBiasResources() do
		if(row.CivilizationType == civilizationType) then
			if( row.Tier == tier) then
				table.insert(resources,  row.ResourceType);
			end
		end
	end

	--Change the range if it is a minor civ
	local range = 2;
	if(minor == true) then
		range = 1;
	end

	resourcePlots = {};

	Resources = {};

	for row in GameInfo.Resources() do
		table.insert(Resources, row.ResourceType);
	end

	--Loop through all the starting plots
	for k, v in pairs(playerStart) do
		--Count the starting plots with the given resource(s) in this tier and add them to an array
		if(v ~= nil) then
			local plotX = v:GetX();
			local plotY = v:GetY();

			local hasResource = false;

			for dx = -range, range, 1 do
				for dy = -range,range, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(otherPlot:GetResourceCount() > 0) then
							for j, resource in ipairs(resources) do
								if(Resources[otherPlot:GetResourceType()+1] == resource) then
									hasResource = true;
								end
							end
						end
					end
				end
			end

			if (hasResource == true) then
				numResource = numResource + 1;
				table.insert(resourcePlots, v);
			end
		end
	end 

	--If more than 1 has this resource(s) within 3
	if(numResource  > 1) then
		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			playerStart[k] = nil;
		end
		for i, resourcePlot in ipairs(resourcePlots) do
			table.insert(playerStart, resourcePlot);
		end
	elseif (numResource  == 1) then
		local startPlot = resourcePlots[1];
		
		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			if(startPlot:GetIndex() == v:GetIndex()) then
					playerStart[k] = startPlot;
			else
					playerStart[k] = nil;
			end
		end

		-- Remove this starting plot from all other civ's list
		-- Check to to see if they have one starting spot left if so remove it from all other players
		self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);

	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasFeatures(playerIndex, tier, minor)
	local numFeature = 0;
	features = {}

	local playerId = minor and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
	local playerStart = self.playerStarts[playerIndex];

	-- Find the features in this tier
	for row in GameInfo.StartBiasFeatures() do
		if(row.CivilizationType == civilizationType) then
			if( row.Tier == tier) then
				table.insert(features,  row.FeatureType);
			end
		end
	end

	--Change the range if it is a minor civ
	local range = 3;
	if(minor == true) then
		range = 2;
	end

	featurePlots = {};

	Features = {};

	for row in GameInfo.Features() do
		table.insert(Features, row.FeatureType);
	end

	--Loop through all the starting plots
	for k, v in pairs(playerStart) do
		--Count the starting plots with the given feature(s) in this tier and add them to an array
		if(v ~= nil) then
			local plotX = v:GetX();
			local plotY = v:GetY();

			local hasFeature = false;

			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(otherPlot:GetFeatureType() ~= g_FEATURE_NONE) then
							for j, feature in ipairs(features) do
								if(Features[otherPlot:GetFeatureType()+1] == feature) then
									hasFeature = true;
								end
							end
						end
					end
				end
			end

			if (hasFeature == true) then
				numFeature = numFeature + 1;
				table.insert(featurePlots, v);
			end
		end
	end 

	--If more than 1 has this feature(s) within 3
	if(numFeature  > 1) then
		-- Remove all other starting plots from this civ�s list.
		local featureValue = table.fill(0, #featurePlots);

		for i, featurePlot in ipairs(featurePlots) do
			local plotX = featurePlot:GetX();
			local plotY = featurePlot:GetY();


			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(featurePlot:GetIndex() ~= otherPlot:GetIndex()) then
							if(otherPlot:GetFeatureType() ~= g_FEATURE_NONE) then
								for j, feature in ipairs(features) do
									if(Features[otherPlot:GetFeatureType()+1] == feature) then
										featureValue[i] = featureValue[i] + 1;
									end
								end
							end
						end
					end
				end
			end
		end

		self.sortedArray = {};
		self:__SortByArray(featurePlots, featureValue);

		for k, v in pairs(playerStart) do
			playerStart[k] = nil;
		end
		for i, featurePlot in ipairs(self.sortedArray) do
			table.insert(playerStart, featurePlot);
		end
	elseif (numFeature  == 1) then
		local startPlot = featurePlots[1];

		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			if(startPlot:GetIndex() == v:GetIndex()) then
					playerStart[k] = startPlot;
			else
					playerStart[k] = nil;
			end
		end

		-- Remove this starting plot from all other civ's list
		-- Check to to see if they have one starting spot left if so remove it from all other players
		self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);

	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasTerrains(playerIndex, tier, minor)
	local numTerrain = 0;
	terrains = {}

	local playerId = minor and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
	local playerStart = self.playerStarts[playerIndex];

	-- Find the terrains in this tier
	for row in GameInfo.StartBiasTerrains() do
		if(row.CivilizationType == civilizationType) then
			if( row.Tier == tier) then
				table.insert(terrains,  row.TerrainType);
			end
		end
	end

	--Change the range if it is a minor civ
	local range = 3;
	if(minor == true) then
		range = 2;
	end

	terrainPlots = {};

	Terrains = {};

	for row in GameInfo.Terrains() do
		table.insert(Terrains, row.TerrainType);
	end

	--Loop through all the starting plots
	for k, v in pairs(playerStart) do
		--Count the starting plots with the given terrain(s) in this tier and add them to an array
		if(v ~= nil) then
			local plotX = v:GetX();
			local plotY = v:GetY();

			local hasTerrain = false;

			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(v:GetIndex() ~= otherPlot:GetIndex()) then
							if(otherPlot:GetTerrainType() ~= g_TERRAIN_NONE) then
								for j, terrain in ipairs(terrains) do
									if(Terrains[otherPlot:GetTerrainType()+1] == terrain) then
										hasTerrain = true;
									end
								end
							end
						end
					end
				end
			end

			if (hasTerrain == true) then
				numTerrain = numTerrain + 1;
				table.insert(terrainPlots, v);
			end
		end
	end 

	--If more than 1 has this terrain(s) within 3
	if(numTerrain  > 1) then
		-- Remove all other starting plots from this civ�s list.
		local terrainValue = table.fill(0, #terrainPlots);

		for i, terrainPlot in ipairs(terrainPlots) do
			local plotX = terrainPlot:GetX();
			local plotY = terrainPlot:GetY();


			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(otherPlot:GetTerrainType() ~= g_TERRAIN_NONE) then
							for j, terrain in ipairs(terrains) do
								if(Terrains[otherPlot:GetTerrainType()+1] == terrain) then
									terrainValue[i] = terrainValue[i] + 1;
								end
							end
						end
					end
				end
			end
		end

		self.sortedArray = {};
		self:__SortByArray(terrainPlots, terrainValue);

		for k, v in pairs(playerStart) do
			playerStart[k] = nil;
		end
		for i, terrainPlot in ipairs(self.sortedArray) do
			table.insert(playerStart, terrainPlot);
		end
	elseif (numTerrain  == 1) then
		local startPlot = terrainPlots[1];

		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			if(startPlot:GetIndex() == v:GetIndex()) then
				playerStart[k] = startPlot;
			else
				playerStart[k] = nil;
			end
		end

		-- Remove this starting plot from all other civ's list
		-- Check to to see if they have one starting spot left if so remove it from all other players
		self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);

	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasRivers(playerIndex, tier, minor)
	local numRiver = 0;

	--The range is 1 in the beginning
	local range = 1;

	riverPlots = {};

	local playerId = minor and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
	local playerStart = self.playerStarts[playerIndex];

	--Loop through all the starting plots
	for k, v in pairs(playerStart) do
		--Count the starting plots with the given river(s) in this tier and add them to an array
		if(v ~= nil) then
			local plotX = v:GetX();
			local plotY = v:GetY();

			local hasRiver = false;

			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(otherPlot:IsRiver()) then
							hasRiver = true;
						end
					end
				end
			end

			if (hasRiver == true) then
				numRiver = numRiver + 1;
				table.insert(riverPlots, v);
			end
		end
	end 

	--If more than 1 has this river(s) within 3
	if(numRiver  > 1) then
		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			playerStart[k] = nil;
		end
		for i, riverPlot in ipairs(riverPlots) do
			table.insert(playerStart, riverPlot);
		end
	elseif (numRiver  == 1) then
		local startPlot = riverPlots[1];
		
		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			if(startPlot:GetIndex() == v:GetIndex()) then
				playerStart[k] = startPlot;
			else
				playerStart[k] = nil;
			end
		end

		-- Remove this starting plot from all other civ's list
		-- Check to to see if they have one starting spot left if so remove it from all other players
		self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);

	elseif(minor == false) then
		--Change the range if no rivers within 3 and major
		local numRiver = 0;
		local range = 3;

		riverPlots = {};

		--Loop through all the starting plots
		for k, v in pairs(playerStart) do
			--Count the starting plots with the given river(s) in this tier and add them to an array
			if(v ~= nil) then
				local plotX = v:GetX();
				local plotY = v:GetY();

				local hasRiver = false;

				for dx = -range, range - 1, 1 do
					for dy = -range,range -1, 1 do
						local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
						if(otherPlot) then
							if(otherPlot:IsRiver()) then
								hasRiver = true;
							end
						end
					end
				end

				if (hasRiver == true) then
					numRiver = numRiver + 1;
					table.insert(riverPlots, v);
				end
			end
		end 

		if(numRiver  > 1) then
			-- Remove all other starting plots from this civ�s list.
			for k, v in pairs(playerStart) do
				playerStart[k] = nil;
			end
			for i, riverPlot in ipairs(riverPlots) do
				table.insert(playerStart, riverPlot);
			end
		elseif (numRiver  == 1) then
			local startPlot = riverPlots[1];
		
			-- Remove all other starting plots from this civ�s list.
			for k, v in pairs(playerStart) do
				if(startPlot:GetIndex() == v:GetIndex()) then
					playerStart[k] = startPlot;
				else
					playerStart[k] = nil;
				end
			end

			-- Remove this starting plot from all other civ's list
			-- Check to to see if they have one starting spot left if so remove it from all other players
			self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasPlotRemoval(startPlot, minor, playerIndex)
	
	if(startPlot == nil) then
		print("Nil1 Starting Plot");
	end
 
	local start = 1;
	local finish = self.iNumMajorCivs; 

	if (minor == true) then
		start = self.iNumMajorCivs + 1;
		finish = self.iNumMajorCivs + self.iNumMinorCivs;
	end

	for i = start, finish do
		if(i ~= playerIndex) then
			local plotID  = -1;

			for k, v in pairs(self.playerStarts[i]) do
				if(v~= nil and v:GetIndex() == startPlot:GetIndex()) then
					plotID = k;
				end
			end

			--If only one left remove it. And remove it from others...
			if(plotID > -1) then
				if(self:__ArraySize(self.playerStarts, i) == 1) then
					--print("Deleting the last entry will have bad results. Minor is ", minor);
				end

				self.playerStarts[i][plotID] = nil;

				if(self:__ArraySize(self.playerStarts, i) == 1) then
					local hasPlot = false;
					for k, v in pairs(self.playerStarts[i]) do
						if(v~= nil and hasPlot == false) then
							hasPlot = true;
							--Call Removal
							self:__StartBiasPlotRemoval(v, minor, i)
						end
					end
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:__SortByArray(sorted, keyArray)
	local greatestValue = -1;
	local index  = -1;

	for k, key in ipairs(keyArray) do
		if(key ~= nil and key > greatestValue) then
			index = k;
			greatestValue = key;
		end
	end

	if(index > 0 and sorted[index] ~= nil) then
		table.insert(self.sortedArray,sorted[index]);
		table.remove(sorted,index);
		table.remove(keyArray,index);
	else
		print("Nil");
	end 

	if(#keyArray > 0) then
		self:__SortByArray(sorted, keyArray);
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:__ArraySize(array, index)
	local count = 0;
	
	if( array ~= nil) then
		for v in pairs(array[index]) do 
			if(v~=nil) then
				count = count + 1;
			end
		end
	end

 	return count;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__PreFertilitySort(sortedPlots)
	--Only used for balanced start
	if(#self.majorStartPlots == 1) then
		self.iFirstFertility = self:__WeightedFertility(self.majorStartPlots[1]:GetIndex())
	end

	local score = {};

	for i, plot in ipairs(sortedPlots) do
		local value = plot.Fertility;
		if(#self.majorStartPlots > 1) then
			if(self.iFirstFertility - plot.Fertility < 0) then
				value = self.iFirstFertility - plot.Fertility;
			end
		end

		table.insert(score, value);
	end

	return score;
end
------------------------------------------------------------------------------
function AssignStartingPlots:__SortByFertilityArray(sorted, keyArray)
	--Only used for balanced start
	local greatestValue = math.huge * -1;
	local index  = -1;

	for k, key in ipairs(keyArray) do
		if(key ~= nil and key > greatestValue) then
			index = k;
			greatestValue = key;
		end
	end

	if(index > 0 and sorted[index] ~= nil) then
		row = {};
		row.Plot = sorted[index].Plot;
		row.Fertility = sorted[index].Fertility;
		table.insert(self.sortedFertilityArray,row);
		table.remove(sorted,index);
		table.remove(keyArray,index);
	else
		--print("Nil");
	end 

	if(#keyArray > 0) then
		self:__SortByFertilityArray(sorted, keyArray);
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddResourcesBalanced()
	local iStartEra = GameInfo.Eras[ GameConfiguration.GetStartEra() ];
	local iStartIndex = 1;
	if iStartEra ~= nil then
		iStartIndex = iStartEra.ChronologyIndex;
	end

	local iHighestFertility = 0;
	for i, plot in ipairs(self.majorStartPlots) do
		self:__BalancedStrategic(plot, iStartIndex);
		self:__BalancedStrategic(plot, iStartIndex + 1);
		
		if(self:__WeightedFertility(plot:GetIndex()) > iHighestFertility) then
			iHighestFertility = self:__WeightedFertility(plot:GetIndex());
		end
	end

	for i, plot in ipairs(self.majorStartPlots) do
		local iFertilityLeft = self:__WeightedFertility(plot:GetIndex());

		if(iFertilityLeft > 0) then
			if(self:__IsContinentalDivide(plot) == true) then
				local iContinentalWeight = GlobalParameters.START_FERTILITY_WEIGHT_CONTINENTAL_DIVIDE or 250;
				iFertilityLeft = iFertilityLeft - iContinentalWeight
			else
				local bAddLuxury = true;
				local iLuxWeight = GlobalParameters.START_FERTILITY_WEIGHT_LUXURY or 250;
				while iFertilityLeft >= iLuxWeight and bAddLuxury == true do 
					bAddLuxury = self:__AddLuxury(plot);
					if(bAddLuxury == true) then
						iFertilityLeft = iFertilityLeft - iLuxWeight;
					end
				end
			end
			local bAddBonus = true;
			local iBonusWeight = GlobalParameters.START_FERTILITY_WEIGHT_BONUS or 75;
			while iFertilityLeft >= iBonusWeight and bAddBonus == true do 
				bAddBonus = self:__AddBonus(plot);
				if(bAddBonus == true) then
					iFertilityLeft = iFertilityLeft - iBonusWeight;
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:__AddResourcesLegendary()
	local iStartEra = GameInfo.Eras[ GameConfiguration.GetStartEra() ];
	local iStartIndex = 1;
	if iStartEra ~= nil then
		iStartIndex = iStartEra.ChronologyIndex;
	end

	local iLegendaryBonusResources = GlobalParameters.START_LEGENDARY_BONUS_QUANTITY or 2;
	local iLegendaryLuxuryResources = GlobalParameters.START_LEGENDARY_LUXURY_QUANTITY or 1;
	for i, plot in ipairs(self.majorStartPlots) do
		self:__BalancedStrategic(plot, iStartIndex);
		self:__BalancedStrategic(plot, iStartIndex + 1);

		if(self:__IsContinentalDivide(plot) == true) then
			iLegendaryLuxuryResources = iLegendaryLuxuryResources - 1;
		else	
			local bAddLuxury = true;
			while iLegendaryLuxuryResources > 0 and bAddLuxury == true do 
				bAddLuxury = self:__AddLuxury(plot);
				if(bAddLuxury == true) then
						iLegendaryLuxuryResources = iLegendaryLuxuryResources - 1;
				end
			end
		end

		local bAddBonus = true;
		iLegendaryBonusResources = iLegendaryBonusResources + 2 * iLegendaryLuxuryResources;
		while iLegendaryBonusResources > 0 and bAddBonus == true do 
			bAddBonus = self:__AddBonus(plot);
			if(bAddBonus == true) then
					iLegendaryBonusResources = iLegendaryBonusResources - 1;
			end
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__BalancedStrategic(plot, iStartIndex)
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};	
	eRevealedEra = {};	

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
		eRevealedEra[iResourcesInDB] = row.RevealedEra;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row]== "RESOURCECLASS_STRATEGIC") then
			if(eRevealedEra[row] == iStartIndex) then
				local bHasResource = false;
				bHasResource = self:__FindSpecificStrategic(eResourceType[row], plot);	
				if(bHasResource == false) then
					self:__AddStrategic(eResourceType[row], plot)
					--print("Placed!");
				end
			end
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__FindSpecificStrategic(eResourceType, plot)
	-- Checks to see if there is a specific strategic in a given distance

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -3, 3 do
		for dy = -3,3 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 3);
			if(otherPlot) then
				if(otherPlot:GetResourceCount() > 0) then
					if(eResourceType == otherPlot:GetResourceType() ) then
						return true;
					end
				end
			end
		end
	end 

	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddStrategic(eResourceType, plot)
	-- Checks to see if it can place a specific strategic

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -3, 3 do
		for dy = -3,3 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 3);
			if(otherPlot) then
				if(ResourceBuilder.CanHaveResource(otherPlot, eResourceType) and otherPlot:GetIndex() ~= plot:GetIndex()) then
					ResourceBuilder.SetResourceType(otherPlot, eResourceType, 1);
					return;
				end
			end
		end
	end 

	--print("Failed");
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddLuxury(plot)
	-- Checks to see if it can place a nearby luxury

	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType	= {};
	eAddLux	= {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
		iResourcesInDB = iResourcesInDB + 1;
	end

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -4, 4 do
		for dy = -4, 4 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 4);
			if(otherPlot) then
				if(otherPlot:GetResourceCount() > 0) then
					for row = 0, iResourcesInDB do
						if (eResourceClassType[row]== "RESOURCECLASS_LUXURY") then
							if(otherPlot:GetResourceType() == eResourceType[row]) then
								table.insert(eAddLux, eResourceType[row]);
							end
						end
					end
				end
			end
		end
	end 

	for dx = -2, 2 do
		for dy = -2, 2 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
			if(otherPlot) then
				eAddLux =  GetShuffledCopyOfTable(eAddLux);
				for i, resource in ipairs(eAddLux) do
					if(ResourceBuilder.CanHaveResource(otherPlot, resource) and otherPlot:GetIndex() ~= plot:GetIndex()) then
						ResourceBuilder.SetResourceType(otherPlot, resource, 1);
						--print("Yeah Lux");
						return true;
					end
				end
			end
		end
	end 

	--print("Failed Lux");
	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddBonus(plot)
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			for row2 in GameInfo.TypeTags() do
				if(GameInfo.Resources[row2.Type] ~= nil) then
					table.insert(aBonus, eResourceType[row]);
				end
			end
		end
	end

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	aBonus =  GetShuffledCopyOfTable(aBonus);
	for i, resource in ipairs(aBonus) do
		for dx = -2, 2 do
			for dy = -2, 2 do
				local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
				if(otherPlot) then
					if(ResourceBuilder.CanHaveResource(otherPlot, resource) and otherPlot:GetIndex() ~= plot:GetIndex()) then
						ResourceBuilder.SetResourceType(otherPlot, resource, 1);
						--print("Yeah Bonus");
						return true;
					end
				end
			end
		end
	end 

	--print("Failed Bonus");
	return false
end


------------------------------------------------------------------------------
function AssignStartingPlots:__IsContinentalDivide(plot)
	local plotX = plot:GetX();
	local plotY = plot:GetY();

	eContinents	= {};

	for dx = -4, 4 do
		for dy = -4, 4 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 4);
			if(otherPlot) then
				if(otherPlot:GetContinentType() ~= nil) then
					if(#eContinents == 0) then
						table.insert(eContinents, otherPlot:GetContinentType());
					else
						if(eContinents[1] ~= otherPlot:GetContinentType()) then
							return true;
						end
					end
				end
			end
		end
	end 
	
	return false;
end


------------------------------------------------------------------------------
-- **************************** YnAMP functions ******************************
------------------------------------------------------------------------------

print ("Loading YnAMP functions ...")

------------------------------------------------------------------------------
-- Imported Maps Creation
------------------------------------------------------------------------------

function GenerateImportedMap(MapToConvert, Civ6DataToConvert, NaturalWonders, g_iW, g_iH)

	--local pPlot
	--g_iFlags = TerrainBuilder.GetFractalFlags();
	
	print("Importing Map Data...")	
	
	-- We'll do Rivers after NW placement, as they can create incompatibilities and Resources come after Rivers (in case Rivers are generated instead of imported)
	local bDoTerrains, bDoRivers, bDoFeatures, bDoResources, bDoCliffs = true, false, true, false, true
	ImportMap(MapToConvert, Civ6DataToConvert, g_iW, g_iH, bDoTerrains, bDoRivers, bDoFeatures, bDoResources, bDoCliffs)

	-- Temp
	AreaBuilder.Recalculate();
	local biggest_area = Areas.FindBiggestArea(false);
	print("After Adding Hills: ", biggest_area:GetPlotCount());
	
	-- River generation is affected by plot types, originating from highlands and preferring to traverse lowlands.
	--AddRivers();
	
	--AddFeatures();	

	local args = {
		numberToPlace = GameInfo.Maps[Map.GetMapSize()].NumNaturalWonders,
	};
	--local nwGen = NaturalWonderGenerator.Create(args);
	PlaceRealNaturalWonders(NaturalWonders)
	
	-- now we import rivers and resources
	local resourcePlacement = MapConfiguration.GetValue("ResourcesPlacement")
	print("Resource placement = "..tostring(resourcePlacement))
	bDoResources = resourcePlacement == "PLACEMENT_IMPORT"
	bDoTerrains, bDoRivers, bDoFeatures, bDoCliffs = false, true, false, false
	ImportMap(MapToConvert, Civ6DataToConvert, g_iW, g_iH, bDoTerrains, bDoRivers, bDoFeatures, bDoResources, bDoCliffs)

	AreaBuilder.Recalculate();
	TerrainBuilder.AnalyzeChokepoints();
	TerrainBuilder.StampContinents();
	

	if not bDoResources then
		resourcesConfig = MapConfiguration.GetValue("resources");
		local args = {
			resources = resourcesConfig,
		};
		ResourceGenerator.Create(args);
	else
		--local resourceType = GameInfo.Resources["RESOURCE_NITER"].Index
		--print(" Adding Civ6 resource : Niter (TypeID = " .. tostring(resourceType)..")")
		--PlaceStrategicResources(resourceType)
	end
	
	print("Creating start plot database.");
	local startConfig = MapConfiguration.GetValue("start");-- Get the start config
	-- START_MIN_Y and START_MAX_Y is the percent of the map ignored for major civs' starting positions.
	local args = {
		MIN_MAJOR_CIV_FERTILITY = 150,
		MIN_MINOR_CIV_FERTILITY = 50, 
		MIN_BARBARIAN_FERTILITY = 1,
		START_MIN_Y = 15,
		START_MAX_Y = 15,
		START_CONFIG = startConfig,
	};
	local start_plot_database = AssignStartingPlots.Create(args)

	local GoodyGen = AddGoodies(g_iW, g_iH);
end

function PlaceRealNaturalWonders(NaturalWonders)
	print("YnAMP Natural Wonders placement")
	for eFeatureType, position in pairs(NaturalWonders) do
		local featureTypeName = GameInfo.Features[eFeatureType].FeatureType
		local x, y = position.X, position.Y
		print ("- Trying to place " .. tostring(featureTypeName) .. " at (" .. tostring(x) .. ", " .. tostring(y) .. ")");		
		local pPlot = Map.GetPlot(x, y);
		local plotsIndex = {}
		local plotsList = {}
		
		-- Preparing placement
		if featureTypeName == "FEATURE_DEAD_SEA" then
			print(" - Preparing position...")
			-- 2 plots, flat desert surrounded by desert, 1st plot is SOUTHWEST 
			-- preparing the 2 plot
			local terrainType = g_TERRAIN_TYPE_DESERT
			table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHEAST), Terrain = terrainType })
		end		
		
		if featureTypeName == "FEATURE_PIOPIOTAHI" then
			print(" - Preparing position...")
			-- 3 plots, flat grass near coast, 1st plot is WEST
			-- preparing the 3 plots
			local terrainType = g_TERRAIN_TYPE_GRASS
			table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHEAST), Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
		end
		
		if featureTypeName == "FEATURE_EVEREST" then
			print(" - Preparing position...")
			-- 3 plots, mountains, 1st plot is WEST
			-- preparing the 3 plots
			local terrainType = g_TERRAIN_TYPE_TUNDRA_MOUNTAIN
			table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_SOUTHEAST), Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
		end
		
		if featureTypeName == "FEATURE_PANTANAL" then
			print(" - Preparing position...")
			-- 4 plots, flat grass/plains without features, 1st plot is SOUTH-WEST
			-- preparing the 4 plots
			local terrainType = g_TERRAIN_TYPE_PLAINS
			local pPlot2 = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHEAST) -- we need plot2 to get plot4
			table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
			table.insert(plotsList, { Plot = pPlot2, Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(pPlot2:GetX(), pPlot2:GetY(), DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
		end

		if featureTypeName == "FEATURE_CLIFFS_DOVER" then
			print(" - Preparing position...")
			-- 2 plots, hills on coast, 1st plot is WEST 
			-- preparing the 2 plots
			local terrainType = g_TERRAIN_TYPE_GRASS_HILLS
			table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
		end
		
		if featureTypeName == "FEATURE_YOSEMITE" then
			print(" - Preparing position...")
			-- 2 plots EAST-WEST, flat tundra/plains without features, 1st plot is WEST
			-- preparing the 2 plots
			local terrainType = g_TERRAIN_TYPE_PLAINS
			table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
		end
		
		if featureTypeName == "FEATURE_TORRES_DEL_PAINE" then
			print(" - Preparing position...")
			-- 2 plots EAST-WEST without features, 1st plot is WEST
			-- preparing the 2 plots
			local terrainType = g_TERRAIN_TYPE_PLAINS
			table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
		end		

		if featureTypeName == "FEATURE_BARRIER_REEF" then
			print(" - Preparing position...")
			-- 2 plots, coast, 1st plot is SOUTHEAST 
			-- preparing the 2 plots
			local terrainType = g_TERRAIN_TYPE_COAST
			table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHWEST), Terrain = terrainType })
		end

		if featureTypeName == "FEATURE_GALAPAGOS" then
			print(" - Preparing position...")
			-- 2 plots, coast, surrounded by coast, 1st plot is SOUTHWEST 
			-- preparing the area
			local terrainType = g_TERRAIN_TYPE_COAST			
			table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
			table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHEAST), Terrain = terrainType })
		end
		
		for k, data in ipairs(plotsList) do 
			TerrainBuilder.SetTerrainType(data.Plot, data.Terrain)
			TerrainBuilder.SetFeatureType(data.Plot, -1)
			ResourceBuilder.SetResourceType(data.Plot, -1)
			table.insert(plotsIndex, data.Plot:GetIndex())
		end		
		
		if not(TerrainBuilder.CanHaveFeature(pPlot, eFeatureType)) then			
			print("  - WARNING : TerrainBuilder.CanHaveFeature says that we can't place that feature here...")
		end		
		
		print("  - Trying Direct Placement...")
		TerrainBuilder.SetFeatureType(pPlot, eFeatureType);
		local bPlaced = pPlot:IsNaturalWonder()
			
		if (not bPlaced) and (#plotsIndex > 0) then
			print("  - Direct Placement has failed, using plot list for placement")
			TerrainBuilder.SetMultiPlotFeatureType(plotsIndex, eFeatureType)
			bPlaced = pPlot:IsNaturalWonder()
		end
		
		if bPlaced then
			ResetTerrain(pPlot:GetIndex())
			ResourceBuilder.SetResourceType(pPlot, -1)

			local plotX = pPlot:GetX()
			local plotY = pPlot:GetY()

			for dx = -2, 2 do
				for dy = -2,2 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2)
					if(otherPlot) then
						if(otherPlot:IsNaturalWonder() == true) then
							ResetTerrain(otherPlot:GetIndex())
							ResourceBuilder.SetResourceType(otherPlot, -1)
						end
					end
				end
			end
			print ("  - Success : plot is now a natural wonder !")
		else
			print ("  - Failed to place natural wonder here...")		
		end
	end
end

-- Add a strategic resource
function PlaceStrategicResources(resourceType)

	local continentsInUse = Map.GetContinentsInUse();	
	ResourceGenerator.iNumContinents = #continentsInUse;
	ResourceGenerator.aStrategicType = {};

	-- Find the Strategic Resource
	table.insert(ResourceGenerator.aStrategicType, resourceType);

	aWeight = {};
	for row in GameInfo.Resource_Distribution() do
		if (row.Continents == ResourceGenerator.iNumContinents) then
			for iI = 1, row.Scarce do
				table.insert(aWeight, 1 - row.PercentAdjusted / 100);
			end

			for iI = 1, row.Average do
				table.insert(aWeight, 1);
			end

			for iI = 1, row.Plentiful do
				table.insert(aWeight, 1 + row.PercentAdjusted / 100);
			end
		end
	end

	aWeight	= GetShuffledCopyOfTable(aWeight);

	ResourceGenerator.iFrequencyStrategicTotal = 0;
    for i, row in ipairs(ResourceGenerator.aStrategicType) do
		ResourceGenerator.iFrequencyStrategicTotal = ResourceGenerator.iFrequencyStrategicTotal + GameInfo.Resources["RESOURCE_NITER"].Frequency;
	end

	for index, eContinent in ipairs(continentsInUse) do 
		-- Shuffle the table
		ResourceGenerator.aStrategicType = GetShuffledCopyOfTable(ResourceGenerator.aStrategicType);
		--print ("Retrieved plots for continent: " .. tostring(eContinent));

		ResourceGenerator:__ValidStrategicPlots(aWeight[index], eContinent);

		-- next find the valid plots for each of the strategics
		ResourceGenerator:__PlaceStrategicResources(eContinent);
	end
end

function AddFeatures()
	print("Adding Features");

	-- Get Rainfall setting input by user.
	local rainfall = MapConfiguration.GetValue("rainfall");
	if rainfall == 4 then
		rainfall = 1 + TerrainBuilder.GetRandomNumber(3, "Random Rainfall - Lua");
	end
	
	local args = {rainfall = rainfall}
	local featuregen = FeatureGenerator.Create(args);

	featuregen:AddFeatures();
end

-----------------
-- ENUM 
-----------------

-- ResourceType Civ5
--[[
	[0]	 = RESOURCE_IRON
	[1]	 = RESOURCE_HORSE
	[2]	 = RESOURCE_COAL
	[3]	 = RESOURCE_OIL
	[4]	 = RESOURCE_ALUMINUM
	[5]	 = RESOURCE_URANIUM
	[6]	 = RESOURCE_WHEAT
	[7]	 = RESOURCE_COW
	[8]	 = RESOURCE_SHEEP
	[9]	 = RESOURCE_DEER
	[10] = RESOURCE_BANANA
	[11] = RESOURCE_FISH
	[12] = RESOURCE_STONE
	[13] = RESOURCE_WHALE
	[14] = RESOURCE_PEARLS
	[15] = RESOURCE_GOLD
	[16] = RESOURCE_SILVER
	[17] = RESOURCE_GEMS
	[18] = RESOURCE_MARBLE
	[19] = RESOURCE_IVORY
	[20] = RESOURCE_FUR
	[21] = RESOURCE_DYE
	[22] = RESOURCE_SPICES
	[23] = RESOURCE_SILK
	[24] = RESOURCE_SUGAR
	[25] = RESOURCE_COTTON
	[26] = RESOURCE_WINE
	[27] = RESOURCE_INCENSE
	[28] = RESOURCE_JEWELRY
	[29] = RESOURCE_PORCELAIN
	[30] = RESOURCE_COPPER
	[31] = RESOURCE_SALT
	[32] = RESOURCE_CRAB
	[33] = RESOURCE_TRUFFLES
	[34] = RESOURCE_CITRUS
	[40] = RESOURCE_BISON
	[41] = RESOURCE_COCOA
--]]
-- ResourceType Civ6
--[[
	[0]	 = RESOURCE_BANANAS
	[1]	 = RESOURCE_CATTLE
	[2]	 = RESOURCE_COPPER
	[3]	 = RESOURCE_CRABS
	[4]	 = RESOURCE_DEER
	[5]	 = RESOURCE_FISH
	[6]	 = RESOURCE_RICE
	[7]	 = RESOURCE_SHEEP
	[8]	 = RESOURCE_STONE
	[9]	 = RESOURCE_WHEAT
	[10] = RESOURCE_CITRUS
	[11] = RESOURCE_COCOA
	[12] = RESOURCE_COFFEE
	[13] = RESOURCE_COTTON
	[14] = RESOURCE_DIAMONDS
	[15] = RESOURCE_DYES
	[16] = RESOURCE_FURS
	[17] = RESOURCE_GYPSUM
	[18] = RESOURCE_INCENSE
	[19] = RESOURCE_IVORY
	[20] = RESOURCE_JADE
	[21] = RESOURCE_MARBLE
	[22] = RESOURCE_MERCURY
	[23] = RESOURCE_PEARLS
	[24] = RESOURCE_SALT
	[25] = RESOURCE_SILK
	[26] = RESOURCE_SILVER
	[27] = RESOURCE_SPICES
	[28] = RESOURCE_SUGAR
	[29] = RESOURCE_TEA
	[30] = RESOURCE_TOBACCO
	[31] = RESOURCE_TRUFFLES
	[32] = RESOURCE_WHALES
	[33] = RESOURCE_WINE
	[40] = RESOURCE_ALUMINUM
	[41] = RESOURCE_COAL
	[42] = RESOURCE_HORSES
	[43] = RESOURCE_IRON
	[44] = RESOURCE_NITER
	[45] = RESOURCE_OIL
	[46] = RESOURCE_URANIUM
--]]
-- FeaturesType Civ5
--[[
	[0]  = FEATURE_ICE			----> 1
	[1]  = FEATURE_JUNGLE		----> 2
	[2]  = FEATURE_MARSH		----> 5
	[3]  = FEATURE_OASIS		----> 4
	[4]  = FEATURE_FLOOD_PLAINS	----> 0
	[5]  = FEATURE_FOREST		----> 3
	[6]  = FEATURE_FALLOUT
	[7]  = FEATURE_CRATER
	[8]  = FEATURE_FUJI
	[9]  = FEATURE_MESA
	[10] = FEATURE_REEF			----> 6
	[11] = FEATURE_VOLCANO
	[12] = FEATURE_GIBRALTAR
	[13] = FEATURE_GEYSER
	[14] = FEATURE_FOUNTAIN_YOUTH
	[15] = FEATURE_POTOSI
	[16] = FEATURE_EL_DORADO
	[17] = FEATURE_ATOLL
	[18] = FEATURE_SRI_PADA
	[19] = FEATURE_MT_SINAI
	[20] = FEATURE_MT_KAILASH
	[21] = FEATURE_ULURU
	[22] = FEATURE_LAKE_VICTORIA
	[23] = FEATURE_KILIMANJARO	----> 12
	[24] = FEATURE_SOLOMONS_MINES	
--]]
-- FeaturesType Civ6
--[[
[0]  = FEATURE_FLOODPLAINS
[1]  = FEATURE_ICE
[2]  = FEATURE_JUNGLE
[3]  = FEATURE_FOREST
[4]  = FEATURE_OASIS
[5]  = FEATURE_MARSH
[6]  = FEATURE_BARRIER_REEF
[7]  = FEATURE_CLIFFS_DOVER
[8]  = FEATURE_CRATER_LAKE
[9]  = FEATURE_DEAD_SEA
[10] = FEATURE_EVEREST
[11] = FEATURE_GALAPAGOS
[12] = FEATURE_KILIMANJARO
[13] = FEATURE_PANTANAL
[14] = FEATURE_PIOPIOTAHI
[15] = FEATURE_TORRES_DEL_PAINE
[16] = FEATURE_TSINGY
[17] = FEATURE_YOSEMITE
--]]
-- PlotType Civ5
--[[
	[0] =	PLOT_MOUNTAIN		
	[1] =	PLOT_HILLS		
	[2] =	PLOT_LAND		
	[3] =	PLOT_OCEAN
--]]	
-- TerrainTypes Civ5
--[[
	[0] = TERRAIN_GRASS, 
	[1] = TERRAIN_PLAINS,
	[2] = TERRAIN_DESERT,
	[3] = TERRAIN_TUNDRA,
	[4] = TERRAIN_SNOW,
	[5] = TERRAIN_COAST,
	[6] = TERRAIN_OCEAN,
--]]
-- Continental Art Set Civ5
--[[
	[0] = Ocean
	[1] = America
	[2] = Asia
	[3] = Africa
	[4] = Europe
--]]
-- Rivers (same for civ6)
--[[	
	
	[0] = FLOWDIRECTION_NORTH
	[1] = FLOWDIRECTION_NORTHEAST
	[2] = FLOWDIRECTION_SOUTHEAST
	[3] = FLOWDIRECTION_SOUTH
	[4] = FLOWDIRECTION_SOUTHWEST
	[5] = FLOWDIRECTION_NORTHWEST
	
	Directions (same for civ6)
	[0] = DIRECTION_NORTHEAST	
	[1] = DIRECTION_EAST
	[2] = DIRECTION_SOUTHEAST
	[3] = DIRECTION_SOUTHWEST
	[4] = DIRECTION_WEST		
	[5] = DIRECTION_NORTHWEST
--]]	
-- Code to export a civ5 map
--[[
	for iPlotLoop = 0, Map.GetNumPlots()-1, 1 do
		local plot = Map.GetPlotByIndex(iPlotLoop)
		local NEOfRiver = 0
		local WOfRiver = 0
		local NWOfRiver = 0
		if plot:IsNEOfRiver() then NEOfRiver = 1 end -- GetRiverSWFlowDirection()
		if plot:IsWOfRiver() then WOfRiver = 1 end -- GetRiverEFlowDirection()
		if plot:IsNWOfRiver() then NWOfRiver = 1 end -- GetRiverSEFlowDirection()
		print("MapToConvert["..plot:GetX().."]["..plot:GetY().."]={"..plot:GetTerrainType()..","..plot:GetPlotType()..","..plot:GetFeatureType()..","..plot:GetContinentArtType()..",{{"..NEOfRiver..","..plot:GetRiverSWFlowDirection().. "},{"..WOfRiver..","..plot:GetRiverEFlowDirection().."},{"..NWOfRiver..","..plot:GetRiverSEFlowDirection().."}},{"..plot:GetResourceType(-1)..","..plot:GetNumResource().."}}")
	end
--]]
-- Code to export a civ6 cliffs map
--[[
	local iPlotCount = Map.GetPlotCount();
	for iPlotLoop = 0, iPlotCount-1, 1 do
		local bData = false
		local plot = Map.GetPlotByIndex(iPlotLoop)
		local NEOfCliff = 0
		local WOfCliff = 0
		local NWOfCliff = 0
		if plot:IsNEOfCliff() then NEOfCliff = 1 end 
		if plot:IsWOfCliff() then WOfCliff = 1 end 
		if plot:IsNWOfCliff() then NWOfCliff = 1 end 
		
		bData = NEOfCliff + WOfCliff + NWOfCliff > 0
		if bData then
			print("Civ6DataToConvert["..plot:GetX().."]["..plot:GetY().."]={{"..NEOfCliff..","..WOfCliff..","..NWOfCliff.."},}")
		end
	end
--]]

function ImportMap(MapToConvert, Civ6DataToConvert, g_iW, g_iH, bDoTerrains, bDoRivers, bDoFeatures, bDoResources, bDoCliffs)
	print("Importing Map ( Terrain = "..tostring(bDoTerrains)..", Rivers = "..tostring(bDoRivers)..", Features = "..tostring(bDoFeatures)..", Resources = "..tostring(bDoResources)..", Cliffs = "..tostring(bDoCliffs).." )")
	local count = 0
	
	-- Civ5 ENUM
	PLOT_MOUNTAIN = 0
	PLOT_HILLS = 1
	
	-- Civ5 to Civ6 
	local FeaturesCiv5toCiv6 = {}
	for i = 0, 24 do FeaturesCiv5toCiv6[i] = g_FEATURE_NONE end
	FeaturesCiv5toCiv6[0]  = g_FEATURE_ICE
	FeaturesCiv5toCiv6[1]  = g_FEATURE_JUNGLE
	FeaturesCiv5toCiv6[2]  = g_FEATURE_MARSH
	FeaturesCiv5toCiv6[3]  = g_FEATURE_OASIS
	FeaturesCiv5toCiv6[4]  = g_FEATURE_FLOODPLAINS
	FeaturesCiv5toCiv6[5]  = g_FEATURE_FOREST
	-- Natural wonders may require a special coding
	--FeaturesCiv5toCiv6[10] = g_FEATURE_BARRIER_REEF
	--FeaturesCiv5toCiv6[23] = g_FEATURE_KILIMANJARO
	
	local ResourceCiv5toCiv6 = {}
	for i = 0, 41 do ResourceCiv5toCiv6[i] = -1 end
	ResourceCiv5toCiv6[4]= 40 -- ALUMINUM
	ResourceCiv5toCiv6[10]= 0 -- BANANAS
	ResourceCiv5toCiv6[40]= 16 -- BISON to FURS
	ResourceCiv5toCiv6[7]= 1 -- CATTLE
	ResourceCiv5toCiv6[34]= 10 -- CITRUS
	ResourceCiv5toCiv6[2]= 41 -- COAL
	ResourceCiv5toCiv6[41]= 11 -- COCOA
	ResourceCiv5toCiv6[30]= 2 -- COPPER
	ResourceCiv5toCiv6[25]= 13 -- COTTON
	ResourceCiv5toCiv6[32]= 3 -- CRABS
	ResourceCiv5toCiv6[9]= 4 -- DEER
	ResourceCiv5toCiv6[17]= 14 -- DIAMONDS
	ResourceCiv5toCiv6[21]= 15 -- DYES
	ResourceCiv5toCiv6[11]= 5 -- FISH
	ResourceCiv5toCiv6[20]= 16 -- FURS
	ResourceCiv5toCiv6[15]= 44 -- GOLD to NITER
	ResourceCiv5toCiv6[1]= 42 -- HORSES
	ResourceCiv5toCiv6[27]= 18 -- INCENSE
	ResourceCiv5toCiv6[0]= 43 -- IRON
	ResourceCiv5toCiv6[19]= 19 -- IVORY
	ResourceCiv5toCiv6[28]= 20 -- JADE
	ResourceCiv5toCiv6[18]= 21 -- MARBLE
	ResourceCiv5toCiv6[3]= 45 -- OIL
	ResourceCiv5toCiv6[14]= 23 -- PEARLS
	ResourceCiv5toCiv6[31]= 24 -- SALT
	ResourceCiv5toCiv6[8]= 7 -- SHEEP
	ResourceCiv5toCiv6[23]= 25 -- SILK
	ResourceCiv5toCiv6[16]= 26 -- SILVER
	ResourceCiv5toCiv6[22]= 27 -- SPICES
	ResourceCiv5toCiv6[12]= 8 -- STONE
	ResourceCiv5toCiv6[24]= 28 -- SUGAR
	ResourceCiv5toCiv6[33]= 31 -- TRUFFLES
	ResourceCiv5toCiv6[5]= 46 -- URANIUM
	ResourceCiv5toCiv6[13]= 32 -- WHALES
	ResourceCiv5toCiv6[6]= 9 -- WHEAT
	ResourceCiv5toCiv6[26]= 33 -- WINE
	
	bOutput = false
	for i = 0, (g_iW * g_iH) - 1, 1 do
		plot = Map.GetPlotByIndex(i)
		if bOutput then
			print("----------")
			print("Convert plot at "..plot:GetX()..","..plot:GetY())
		end
		-- Map Data
		-- MapToConvert[x][y] = {civ5TerrainType, civ5PlotTypes, civ5FeatureTypes, civ5ContinentType, {{IsNEOfRiver, flow}, {IsWOfRiver, flow}, {IsNWOfRiver, flow}}, {Civ5ResourceType, num} }
		local civ5TerrainType = MapToConvert[plot:GetX()][plot:GetY()][1]
		local civ5PlotTypes = MapToConvert[plot:GetX()][plot:GetY()][2]
		local civ5FeatureTypes = MapToConvert[plot:GetX()][plot:GetY()][3]
		local civ5ContinentType = MapToConvert[plot:GetX()][plot:GetY()][4]
		local Rivers = MapToConvert[plot:GetX()][plot:GetY()][5] -- = {{IsNEOfRiver, flow}, {IsWOfRiver, flow}, {IsNWOfRiver, flow}}
		local resource = MapToConvert[plot:GetX()][plot:GetY()][6] -- = {Civ5ResourceType, num}
		
		-- Get Civ6 map data exported form the internal WB
		local Cliffs
		if Civ6DataToConvert[plot:GetX()][plot:GetY()] then
			Cliffs =  Civ6DataToConvert[plot:GetX()][plot:GetY()][1] -- {IsNEOfCliff,IsWOfCliff,IsNWOfCliff}
		end
		
		-- Set terrain type
		if bDoTerrains then
			local civ6TerrainType = g_TERRAIN_TYPE_OCEAN		
			if civ5TerrainType == 5 then civ6TerrainType = g_TERRAIN_TYPE_COAST
			elseif civ5TerrainType ~= 6 then
				-- the code below won't work if the order is changed in the terrains table
				-- entrie for civ5 are: 0 = GRASS, 1= PLAINS, ...
				-- entries for civ6 are: 0 = GRASS, 1= GRASS_HILL, 2 = GRASS_MOUNTAIN, 3= PLAINS, 4 = PLAINS_HILL, ...
				civ6TerrainType = civ5TerrainType * 3 -- civ5TerrainType * 3  0-0 1-3 2-6 3-9 4-12
				if civ5PlotTypes == PLOT_HILLS then 
					civ6TerrainType = civ6TerrainType + g_TERRAIN_BASE_TO_HILLS_DELTA
				elseif civ5PlotTypes == PLOT_MOUNTAIN then
					civ6TerrainType = civ6TerrainType + g_TERRAIN_BASE_TO_MOUNTAIN_DELTA
				end
			end
			if bOutput then print(" - Set Terrain Type = "..tostring(GameInfo.Terrains[civ6TerrainType].TerrainType)) end
			count = count + 1
			TerrainBuilder.SetTerrainType(plot, civ6TerrainType)
		end
		
		-- Set Rivers
		if bDoRivers then
			if Rivers[1][1] == 1 then -- IsNEOfRiver
				TerrainBuilder.SetNEOfRiver(plot, true, Rivers[1][2])
				if bOutput then print(" - Set is NE of River, flow = "..tostring(Rivers[1][2])) end
			end
			if Rivers[2][1] == 1 then -- IsWOfRiver
				TerrainBuilder.SetWOfRiver(plot, true, Rivers[2][2])
				if bOutput then print(" - Set is W of River, flow = "..tostring(Rivers[2][2])) end
			end
			if Rivers[3][1] == 1 then -- IsNWOfRiver
				TerrainBuilder.SetNWOfRiver(plot, true, Rivers[3][2])
				if bOutput then print(" - Set is NW of River, flow = "..tostring(Rivers[3][2])) end
			end
		end
		
		-- Set Features
		if bDoFeatures then
			if civ5FeatureTypes ~= -1 and FeaturesCiv5toCiv6[civ5FeatureTypes] ~= g_FEATURE_NONE then		
				if bOutput then print(" - Set Feature Type = "..tostring(GameInfo.Features[FeaturesCiv5toCiv6[civ5FeatureTypes]].FeatureType)) end
				TerrainBuilder.SetFeatureType(plot, FeaturesCiv5toCiv6[civ5FeatureTypes])
			end
		end
		
		-- Set Resources
		if bDoResources and not plot:IsNaturalWonder() then
			if resource[1] ~= -1 and ResourceCiv5toCiv6[resource[1]] ~= -1 then		
				if bOutput then print(" - Set Resource Type = "..tostring(GameInfo.Resources[ResourceCiv5toCiv6[resource[1]]].ResourceType)) end
				--ResourceBuilder.SetResourceType(plot, ResourceCiv5toCiv6[resource[1]], resource[2]) -- maybe an option to import number of resources on one plot even if civ6 use 1 ?
				ResourceBuilder.SetResourceType(plot, ResourceCiv5toCiv6[resource[1]], 1)
			end
		end
		
		-- Set Cliffs
		if bDoCliffs and Cliffs then
			if Cliffs[1] == 1 then -- IsNEOfCliff
				TerrainBuilder.SetNEOfCliff(plot, true)
				if bOutput then print(" - Set is NE of Cliff") end
			end
			if Cliffs[2] == 1 then -- IsWOfCliff
				TerrainBuilder.SetWOfCliff(plot, true)
				if bOutput then print(" - Set is W of Cliff") end
			end
			if Cliffs[3] == 1 then -- IsNWOfCliff
				TerrainBuilder.SetNWOfCliff(plot, true)
				if bOutput then print(" - Set is NW of Cliff") end
			end	
		end
		
	end	
	
	print("Placed terrain on "..tostring(count) .. " tiles")
end

------------------------------------------------------------------------------
-- True Starting Locations
------------------------------------------------------------------------------

function SetTrueStartingLocations()
	print ("-------------------------------------------------------")
	print ("Beginning True Starting Location placement for "..tostring(mapName))
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
		local position = getTSL[iPlayer]
		if position then 
			print ("- "..tostring(CivilizationTypeName).." at "..tostring(position.X)..","..tostring(position.Y))
			local plot = Map.GetPlot(position.X, position.Y)
			if plot:IsStartingPlot() then
				print ("WARNING ! Plot is already a Starting Position")
			end
			player:SetStartingPlot(plot)
		end
	end	
end

function YnAMP_StartPositions()

	if bTSL then
		SetTrueStartingLocations()	
	end
	
	if bCulturallyLinked then
		CulturallyLinkedCivilizations(true)	
		CulturallyLinkedCityStates(true)
	end
end

------------------------------------------------------------------------------
-- Culturally Linked Start Locations
------------------------------------------------------------------------------
function Round(num)
    under = math.floor(num)
    upper = math.floor(num) + 1
    underV = -(under - num)
    upperV = upper - num
    if (upperV > underV) then
        return under
    else
        return upper
    end
end

BRUTE_FORCE_TRIES = 3 -- raise this number for better placement but longer initialization. From tests, 3 passes should be more than enough.
OVERSEA_PENALTY = 50 -- distance penalty for starting plot separated by sea
SAME_GROUP_WEIGHT = 2 -- factor to use for distance in same cultural group

g_CultureRelativeDistance = {
	["ETHNICITY_EURO"] = 0, -- center of the world (yes, that's a clich�)
	["ETHNICITY_MEDIT"] = 1,
	["ETHNICITY_SOUTHAM"] = 20,
	["ETHNICITY_ASIAN"] = 10,
	["ETHNICITY_AFRICAN"] = 5,
}

function CalculateDistanceScore(cultureList, bOutput)
	if bOutput then print ("------------------------------------------------------- ") end
	if bOutput then  print ("Calculating distance score...") end
	local globalDistanceScore = 0
	local cultureDistanceScore = {}
	for civCulture, playerList in pairs(cultureList) do
		if bOutput then  print (" - culture = " .. tostring(civCulture)) end
		local distanceScore = 0
		for i, playerID in pairs(playerList) do
			local player = Players[playerID]
			local playerConfig = PlayerConfigurations[playerID]
			if bOutput then  print ("    - player = " .. tostring(playerConfig:GetPlayerName())) end
			for _, player_ID2 in ipairs(PlayerManager.GetAliveMajorIDs()) do
				local player2 = Players[player_ID2]
				local playerConfig2 = PlayerConfigurations[player_ID2]
				local civCulture2 = GameInfo.Civilizations[playerConfig2:GetCivilizationTypeID()].Ethnicity
				if  civCulture2 == civCulture then
					local startPlot1 = player:GetStartingPlot()
					if not startPlot1 then print("WARNING no starting plot for : " .. tostring(playerConfig:GetPlayerName())) end
					local startPlot2 = player2:GetStartingPlot()
					if not startPlot2 then print("WARNING no starting plot for : " .. tostring(playerConfig2:GetPlayerName())) end
					local distance = Map.GetPlotDistance(startPlot1:GetX(), startPlot1:GetY(), startPlot2:GetX(), startPlot2:GetY())
					if startPlot1:GetArea() ~= startPlot2:GetArea() then
						distance = distance + OVERSEA_PENALTY
					end
					distanceScore = distanceScore + Round(distance*SAME_GROUP_WEIGHT)
					if bOutput then print ("      - Distance to same culture (" .. tostring(playerConfig2:GetPlayerName()) .. ") = " .. tostring(distance) .. " (x".. tostring(SAME_GROUP_WEIGHT) .."), total distance score = " .. tostring(distanceScore) ) end
				else
					local interGroupMinimizer = 1
					if g_CultureRelativeDistance[civCulture] and g_CultureRelativeDistance[civCulture2] then
						interGroupMinimizer = math.abs(g_CultureRelativeDistance[civCulture] - g_CultureRelativeDistance[civCulture2])
					else
						interGroupMinimizer = 8 -- unknown culture group (new DLC ?), average distance
					end
					local startPlot1 = player:GetStartingPlot()
					local startPlot2 = player2:GetStartingPlot()
					local distance = Map.GetPlotDistance(startPlot1:GetX(), startPlot1:GetY(), startPlot2:GetX(), startPlot2:GetY())
					distanceScore = distanceScore + Round(distance/interGroupMinimizer)
					if bOutput then print ("      - Distance to different culture (" .. tostring(playerConfig2:GetPlayerName()) .. ") = " .. tostring(distance) .. " (/".. tostring(interGroupMinimizer) .." from intergroup relative distance), total distance score = " .. tostring(distanceScore) ) end
				end
			end
		end
		cultureDistanceScore[civCulture] = distanceScore
		globalDistanceScore = globalDistanceScore + distanceScore
	end		
	if bOutput then print ("Global distance score = " .. tostring(globalDistanceScore)) end
	if bOutput then print ("------------------------------------------------------- ") end
	return globalDistanceScore
end

function CulturallyLinkedCivilizations()

	local playerList = {}

	local cultureList = {}
	local cultureCount = {}


	local bestList = {}
	local bestDistanceScore = 99999
	
	print ("------------------------------------------------------- ")
	print ("Creating Civilization list for Culturally linked startingposition... ")
	for _, player_ID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do

		-- creating player lists
		local player = Players[player_ID]
		local playerConfig = PlayerConfigurations[player_ID]
		local civCulture = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Ethnicity
		if not civCulture then
			print("WARNING : no Ethnicity defined for " .. playerConfig:GetPlayerName() ..", using EURO")
			civCulture = "ETHNICITY_EURO"
		end
		print (" - Adding player " .. tostring(playerConfig:GetPlayerName()) .. " to culture " .. tostring(civCulture))
		table.insert(playerList, player_ID)
		if cultureList[civCulture] then
			table.insert(cultureList[civCulture], player_ID)
			cultureCount[civCulture] = cultureCount[civCulture] + 1
		else
			cultureList[civCulture] = {}
			table.insert(cultureList[civCulture], player_ID)
			cultureCount[civCulture] = 1
		end

	end
	print ("------------------------------------------------------- ")

	-- Sort culture table by number of civs...
	local cultureTable = {}
	for civCulture, num in pairs(cultureCount) do	
		table.insert(cultureTable, {Culture = civCulture, Num = num})
	end
	table.sort(cultureTable, function(a,b) return a.Num > b.Num end)
	for i, data in ipairs(cultureTable) do	
		print ("Culture " .. tostring(data.Culture) .. " represented by " .. tostring(data.Num) .. " civs")
	end
	print ("------------------------------------------------------- ")

	
	local initialDistanceScore = CalculateDistanceScore(cultureList, true)
	if  initialDistanceScore < bestDistanceScore then
		bestDistanceScore = initialDistanceScore
	end

	-- todo : do and lock initial placement of the biggest cultural group in game
	-- on the area with most starting plots, then use brute force for the remaining civs

	-- todo : add cultural relative distance (ie Mediterannean should be closer from European than American or Asian culture)

	-- very brute force
	for try = 1, BRUTE_FORCE_TRIES do 
		print ("------------------------------------------------------- ")
		print ("Brute Force Pass num = " .. tostring(try) )
		for _, player_ID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
			local player = Players[player_ID]
			local playerConfig = PlayerConfigurations[player_ID]
			--print ("------------------------------------------------------- ")
			--print ("Testing " .. tostring(playerConfig:GetPlayerName()) )
			local culture = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Ethnicity
			for _, player_ID2 in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do	
				--print ("in loop 2")
				if player_ID ~= player_ID2 then
					local player2 = Players[player_ID2]
					local playerConfig2 = PlayerConfigurations[player_ID2]
					local culture2 = GameInfo.Civilizations[playerConfig2:GetCivilizationTypeID()].Ethnicity
					if culture ~= culture2 then -- don't try to swith civs from same culture style, we can gain better score from different culture only...
						--print ("culture ~= culture2")
						local startPlot1 = player:GetStartingPlot()
						local startPlot2 = player2:GetStartingPlot()
						--print ("------------------------------------------------------- ")
						--print ("trying to switch " .. tostring(playerConfig:GetPlayerName()) .. " with " .. tostring(playerConfig2:GetPlayerName()) )
						player:SetStartingPlot(startPlot2)
						player2:SetStartingPlot(startPlot1)
						local actualdistanceScore = CalculateDistanceScore(cultureList)
						if  actualdistanceScore < bestDistanceScore then
							bestDistanceScore = actualdistanceScore
							--print ("------------------------------------------------------- ")
							--print ("Better score, confirming switching position of " .. tostring(playerConfig:GetPlayerName()) .. " with " .. tostring(playerConfig2:GetPlayerName()) )
						else
							--print ("------------------------------------------------------- ")
							--print ("No gain, restoring position of " .. tostring(playerConfig:GetPlayerName()) .. " and " .. tostring(playerConfig2:GetPlayerName()) )								
							player:SetStartingPlot(startPlot1)
							player2:SetStartingPlot(startPlot2)
						end
					end
				end
			end
		end

		--print ("------------------------------------------------------- ")
		--print ("Brute Force Pass num " .. tostring(try) )
		print ("New global distance = " .. tostring(CalculateDistanceScore(cultureList)))
	end
	CalculateDistanceScore(cultureList, true)
	print ("------------------------------------------------------- ")
	print ("INITIAL DISTANCE SCORE = " .. tostring(initialDistanceScore))
	print ("------------------------------------------------------- ")
	print ("FINAL DISTANCE SCORE: " .. tostring(CalculateDistanceScore(cultureList)) )
	print ("------------------------------------------------------- ")
end

function CalculateDistanceScoreCityStates(bOutput)
	if bOutput then print ("------------------------------------------------------- ") end
	if bOutput then  print ("Calculating distance score for City States...") end
	local globalDistanceScore = 0
	
	for _, player_ID in ipairs(PlayerManager.GetAliveMinorIDs()) do
		local player = Players[player_ID]
		local playerConfig = PlayerConfigurations[player_ID]
		local distanceScore = 0
		local startPlot1 = player:GetStartingPlot()
		local civCulture = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Ethnicity		
		if not civCulture then
			print("WARNING : no Ethnicity defined for " .. playerConfig:GetPlayerName() ..", using EURO")
			civCulture = "ETHNICITY_EURO"
		end
		if startPlot1 ~= nil then

			if bOutput then  print ("    - player = " .. tostring(playerConfig:GetPlayerName())) end

			for _, player_ID2 in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
				local player2 = Players[player_ID2]
				local playerConfig2 = PlayerConfigurations[player_ID2]
				local civCulture2 = GameInfo.Civilizations[playerConfig2:GetCivilizationTypeID()].Ethnicity
				if  civCulture2 == civCulture then
					local startPlot2 = player2:GetStartingPlot()
					local distance = Map.GetPlotDistance(startPlot1:GetX(), startPlot1:GetY(), startPlot2:GetX(), startPlot2:GetY())
					if startPlot1:GetArea() ~= startPlot2:GetArea() then
						distance = distance + OVERSEA_PENALTY
					end
					distanceScore = distanceScore + Round(distance*SAME_GROUP_WEIGHT)
					if bOutput then print ("      - Distance to same culture (" .. tostring(playerConfig2:GetPlayerName()) .. ") = " .. tostring(distance) .. " (x".. tostring(SAME_GROUP_WEIGHT) .."), total distance score = " .. tostring(distanceScore) ) end
				else
					local interGroupMinimizer = 1
					if g_CultureRelativeDistance[civCulture] and g_CultureRelativeDistance[civCulture2] then
						interGroupMinimizer = math.abs(g_CultureRelativeDistance[civCulture] - g_CultureRelativeDistance[civCulture2])
					else
						interGroupMinimizer = 8 -- unknown culture group, average distance
					end
					local startPlot2 = player2:GetStartingPlot()
					local distance = Map.GetPlotDistance(startPlot1:GetX(), startPlot1:GetY(), startPlot2:GetX(), startPlot2:GetY())
					distanceScore = distanceScore + Round(distance/interGroupMinimizer)
					if bOutput then print ("      - Distance to different culture (" .. tostring(playerConfig2:GetPlayerName()) .. ") = " .. tostring(distance) .. " (/".. tostring(interGroupMinimizer) .." from intergroup relative distance), total distance score = " .. tostring(distanceScore) ) end
				end
			end
		end
		globalDistanceScore = globalDistanceScore + distanceScore
	end		
	if bOutput then print ("Global distance score = " .. tostring(globalDistanceScore)) end
	if bOutput then print ("------------------------------------------------------- ") end
	return globalDistanceScore
end

-- try to place city states closes to corresponding culture civs
function CulturallyLinkedCityStates()

	local bestDistanceScore = 99999
	
	print ("------------------------------------------------------- ")
	print ("Set Culturally linked starting positions for City States... ")

	local initialDistanceScore = CalculateDistanceScoreCityStates()
	if  initialDistanceScore < bestDistanceScore then
		bestDistanceScore = initialDistanceScore
	end

	-- very brute force again
	for try = 1, BRUTE_FORCE_TRIES do 
		print ("------------------------------------------------------- ")
		print ("Brute Force Pass num = " .. tostring(try) )
		for _, player_ID in ipairs(PlayerManager.GetAliveMinorIDs()) do
			local player = Players[player_ID]
			local playerConfig = PlayerConfigurations[player_ID]
			local culture = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Ethnicity

			for _, player_ID2 in ipairs(PlayerManager.GetAliveMinorIDs()) do
				local player2 = Players[player_ID2]
				if player_ID ~= player_ID2 then
					local playerConfig2 = PlayerConfigurations[player_ID2]
					local startPlot1 = player:GetStartingPlot()
					local startPlot2 = player2:GetStartingPlot()
					--print ("  - Player = " .. tostring(playerConfig:GetPlayerName()) .. ", Start Plot = " .. tostring(startPlot1) )
					--print ("  - Player = " .. tostring(playerConfig2:GetPlayerName()) .. ", Start Plot = " .. tostring(startPlot2) )
					local culture2 = GameInfo.Civilizations[playerConfig2:GetCivilizationTypeID()].Ethnicity
					if (startPlot1 ~= nil) and (startPlot2 ~= nil) then
						if culture ~= culture2 then -- don't try to swith civs from same culture style, we can gain better score from different culture only...
							--print ("culture ~= culture2")
							--print ("------------------------------------------------------- ")
							--print ("trying to switch " .. tostring(playerConfig:GetPlayerName()) .. " with " .. tostring(playerConfig2:GetPlayerName()) )
							player:SetStartingPlot(startPlot2)
							player2:SetStartingPlot(startPlot1)
							local actualdistanceScore = CalculateDistanceScoreCityStates()
							if  actualdistanceScore < bestDistanceScore then
								bestDistanceScore = actualdistanceScore
								--print ("------------------------------------------------------- ")
								--print ("Better score, conforming switching position of " .. tostring(playerConfig:GetPlayerName()) .. " with " .. tostring(playerConfig2:GetPlayerName()) )
							else
								--print ("------------------------------------------------------- ")
								--print ("No gain, restoring position of " .. tostring(playerConfig:GetPlayerName()) .. " and " .. tostring(playerConfig2:GetPlayerName()) )								
								player:SetStartingPlot(startPlot1)
								player2:SetStartingPlot(startPlot2)
							end
						end
					end						
				end
			end			

		end
		print ("New global distance = " .. tostring(CalculateDistanceScoreCityStates()))
	end
	print ("------------------------------------------------------- ")
	print ("CS INITIAL DISTANCE SCORE = " .. tostring(initialDistanceScore))
	print ("------------------------------------------------------- ")
	print ("CS FINAL DISTANCE SCORE = " .. tostring(CalculateDistanceScoreCityStates()))
	print ("------------------------------------------------------- ")
end

------------------------------------------------------------------------------
-- /end YnAMP
------------------------------------------------------------------------------