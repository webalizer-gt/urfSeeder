--
-- urfSeeder 4
-- Class for (moreRealistic) sowing machines with under-root fertilization
-- supports halfside shutoff and separate use of ridge markers
--
-- @author  Stefan Geiger
-- @date  25/02/08
--
-- @author  webalizer
-- @date  v 2.0 11/08/13
-- @date  v 3.0 19/12/13
-- @date  v 4.0.01 13/08/14 support SoilMod
--
-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.

source("dataS/scripts/vehicles/specializations/SprayerAreaEvent.lua");
source("dataS/scripts/vehicles/specializations/SprayerSetIsFillingEvent.lua");

UrfSeeder = {};
UrfSeeder.DIR =  g_currentModDirectory;


function UrfSeeder.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(SowingMachine, specializations);
end;

function UrfSeeder:load(xmlFile)
	self.setIsFertilizing = SpecializationUtil.callSpecializationsFunction("setIsFertilizing");
	self.setShutoff = SpecializationUtil.callSpecializationsFunction("setShutoff");
	self.addSprayerFillTrigger = SpecializationUtil.callSpecializationsFunction("addSprayerFillTrigger");
	self.removeSprayerFillTrigger = SpecializationUtil.callSpecializationsFunction("removeSprayerFillTrigger");
	self.drawFillLevels = SpecializationUtil.callSpecializationsFunction("drawFillLevels");
	self.wwMinMaxAreas = SpecializationUtil.callSpecializationsFunction("self.wwMinMaxAreas");
	self.wwMinMaxAI = SpecializationUtil.callSpecializationsFunction("self.wwMinMaxAI");
	self.setCurrentSprayFillType = SpecializationUtil.callSpecializationsFunction("self.setCurrentSprayFillType");

	self.setSprayFillLevel = UrfSeeder.setSprayFillLevel;
  assert(self.setIsSprayerFilling == nil, "UrfSeeder needs to be the first specialization which implements setIsSprayerFilling");
  self.setIsSprayerFilling = UrfSeeder.setIsSprayerFilling;
  self.addSprayerFillTrigger = UrfSeeder.addSprayerFillTrigger;
  self.removeSprayerFillTrigger = UrfSeeder.removeSprayerFillTrigger;
	self.fillUpSprayer = UrfSeeder.fillUpSprayer;
	self.wwMinMaxAreas = UrfSeeder.wwMinMaxAreas;
	self.wwMinMaxAI = UrfSeeder.wwMinMaxAI;
	self.setCurrentSprayFillType = UrfSeeder.setCurrentSprayFillType;
	self.setShutoff = UrfSeeder.setShutoff;

	self.isUrfSeeder = Utils.getNoNil(getXMLBool(xmlFile, "vehicle.isUrfSeeder#value"), false);

	self.realSprayingReferenceSpeed = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.realSprayingReferenceSpeed"), 0)/3.6; -- km/h to m/s
	self.sprayFillLitersPerSecond = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.sprayFillLitersPerSecond"), 50);
	self.sprayCapacity = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.sprayCapacity"), 0.0);
	self.sprayLitersPerSecond = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.sprayLitersPerSecond"), 7.2);

  -- Get allowed types of fertilizer for SoilMod
  self.mySprays = {};
  self.mySprayOverlays = {};
  local sprayTypes = getXMLString(xmlFile, "vehicle.sprayFillTypes#fillTypes");
  if sprayTypes ~= nil then
      local types = Utils.splitString(" ", sprayTypes);
      for k,v in pairs(types) do
        local sprayType = Fillable.fillTypeNameToInt[v];
        if sprayType ~= nil then
          self.mySprays[k] = sprayType;
        else
          print("Warning: '"..self.configFileName.. "' has invalid sprayType '"..v.."'.");
        end;
      end;
  end;

	self.wwMin = 0;
	self.wwMax = 0;
	self.markerZPos = 0;

	self.wwMin,self.wwMax,y,z = self:wwMinMaxAI();
	self.wwMin,self.wwMax,y,z = self:wwMinMaxAreas(self.cuttingAreas);

	self.wwY = y;
	self.wwZ = z;

	local workWidth = math.abs(self.wwMax-self.wwMin);
	if workWidth > .1 then
		self.workWidth = math.floor(workWidth + 0.5);
		self.wwCenter = (self.wwMin+self.wwMax)/2;
		if math.abs(self.wwCenter) < 0.1 then
			self.wwCenter = 0;
		end
	end

	-- Check if present and set workwith of drivingLine
	if self.smWorkwith ~= nil then
		self.smWorkwith = self.workWidth;
	end;

	if self.isUrfSeeder then
		self.sprayFillType = "fertilizer";
		self.currentSprayFillType = Fillable.fillTypeNameToInt[self.sprayFillType]
		self.sprayFillLevel = 0;
		self.isSprayerFilling = false;
		self.isFertilizing = true;

		self.sprayerFillTriggers = {};
		self.sprayerFillActivatable = SprayerFillActivatable:new(self);

		self.xPos = Utils.getNoNil(getXMLFloat(xmlFile,  "vehicle.hudPos#posX"), 0.853);
		self.yPos = Utils.getNoNil(getXMLFloat(xmlFile,  "vehicle.hudPos#posY"), 0.245);
		self.hudBarWidth = 0.104;

		self.hudHalfOverlay = Overlay:new("hudHalfOverlay", Utils.getFilename("textures/half_fertilizer_hud.dds", UrfSeeder.DIR), self.xPos, self.yPos, 0.235, 0.039525);
		self.hudNoneOverlay = Overlay:new("hudNoneOverlay", Utils.getFilename("textures/none_fertilizer_hud.dds", UrfSeeder.DIR), self.xPos, self.yPos, 0.235, 0.039525);
		self.hudBgOverlay = Overlay:new("hudBgOverlay", Utils.getFilename("textures/fertilizer_bg.dds", UrfSeeder.DIR), self.xPos, self.yPos, 0.235, 0.039525);
    self.hudBarLimeOverlay = Overlay:new("hudBarLimeOverlay", Utils.getFilename("textures/lime_fertilizer_bar.dds", UrfSeeder.DIR), self.xPos + 0.028, self.yPos + 0.01, 0.21, 0.02190);

		self.hudBarRedOverlay = Overlay:new("hudBarRedOverlay", Utils.getFilename("textures/red_fertilizer_bar.dds", UrfSeeder.DIR), self.xPos + 0.028, self.yPos + 0.01, 0.21, 0.02190);
	end;
	self.textOn = string.format(g_i18n:getText("URF_ON"), self.typeDesc);
	self.textOff = string.format(g_i18n:getText("URF_OFF"), self.typeDesc);
	self.textFertilization = string.format(g_i18n:getText("URF_FERTILIZATION"), self.typeDesc);
  self.textFtype = string.format(g_i18n:getText("URF_FTYPE"), self.typeDesc);

	--Halfside shutoff
	self.textToggleshutoff = string.format(g_i18n:getText("URF_TOGGLESHUTOFF"), self.typeDesc);
	self.textLeft = string.format(g_i18n:getText("URF_LEFT"), self.typeDesc);
	self.textRight = string.format(g_i18n:getText("URF_RIGHT"), self.typeDesc);

	self.origCuttingAreas = table.copy(self.cuttingAreas);
	self.rightCuttingAreas = table.copy(self.cuttingAreas);
	self.leftCuttingAreas = table.copy(self.cuttingAreas);

	local numCuttingAreas = Utils.getNoNil(getXMLInt(xmlFile, "vehicle.cuttingAreas#count"), 0);
  for i=1, numCuttingAreas do
    local areanamei = string.format("vehicle.cuttingAreas.cuttingArea%d", i);
    local areaside = Utils.getNoNil(getXMLString(xmlFile, areanamei.."#side"));
		if areaside == "right" then
			self.leftCuttingAreas[i] = nil;
		elseif areaside == "left" then
			self.rightCuttingAreas[i] = nil;
		end;
  end;
	self.shutoff = 0;
end;

function table.copy(t)
  local t2 = {};
  for k,v in pairs(t) do
    if type(v) == "table" then
        t2[k] = table.copy(v);
    else
        t2[k] = v;
    end
  end
  return t2;
end

function UrfSeeder:delete()
	if self.isUrfSeeder then
		if self.hudBarLimeOverlay then
			self.hudBarLimeOverlay:delete();
		end;
		if self.hudBarRedOverlay then
			self.hudBarRedOverlay:delete();
		end;
		if self.hudBgOverlay then
			self.hudBgOverlay:delete();
		end;
		if self.hudHalfOverlay then
			self.hudHalfOverlay:delete();
		end;
		if self.hudNoneOverlay then
			self.hudNoneOverlay:delete();
		end;
		g_currentMission:removeActivatableObject(self.sprayerFillActivatable);
	end;
end;

function UrfSeeder:readStream(streamId, connection)
  local shutoff = streamReadInt8(streamId);
	if self.isUrfSeeder then
		local isSprayerFilling = streamReadBool(streamId);
		local isFertilizing = streamReadBool(streamId);
		local sprayFillLevel = streamReadInt32(streamId);
    local currentSprayFillType = streamReadInt8(streamId);
		self:setIsSprayerFilling(isSprayerFilling, true);
		self:setIsFertilizing(isFertilizing, true);
		self:setSprayFillLevel(sprayFillLevel, true);
    self:setCurrentSprayFillType(currentSprayFillType, true);
	end;
	self:setShutoff(shutoff, true);
end;

function UrfSeeder:writeStream(streamId, connection)
  streamWriteInt8(streamId, self.shutoff);
	if self.isUrfSeeder then
		streamWriteBool(streamId, self.isSprayerFilling);
		streamWriteBool(streamId, self.isFertilizing);
		streamWriteInt32(streamId, self.sprayFillLevel);
    streamWriteInt8(streamId, self.currentSprayFillType);
	end;
end;

function UrfSeeder:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	if self.isUrfSeeder then
		local fertilizationStatus = getXMLBool(xmlFile, key.."#fertilizationStatus");
		if fertilizationStatus ~= nil then
			self.isFertilizing = fertilizationStatus;
		end;
		local sprayFillLevel = getXMLInt(xmlFile, key.."#sprayFillLevel");
		if sprayFillLevel ~= nil then
			self.sprayFillLevel = sprayFillLevel;
		end;
    local currentSprayFillType = Utils.getNoNil(getXMLString(xmlFile, key.."#sprayFillType", "fertilizer"));
    if currentSprayFillType ~= nil then
      self.currentSprayFillType = Fillable.fillTypeNameToInt[currentSprayFillType];
    end;
		return BaseMission.VEHICLE_LOAD_OK;
	end;
end;

function UrfSeeder:getSaveAttributesAndNodes(nodeIdent)
	if self.isUrfSeeder then
		local fertilizationStatus = self.isFertilizing;
		local sprayFillLevel = self.sprayFillLevel;
    local currentSprayFillType = self.currentSprayFillType;
		local attributes = 'fertilizationStatus="'..tostring(fertilizationStatus)..'" sprayFillLevel="'..sprayFillLevel..'" sprayFillType="'..tostring(Fillable.fillTypeIntToName[currentSprayFillType])..'"';
		return attributes, nil;
	end;
end;

function UrfSeeder:keyEvent(unicode, sym, modifier, isDown)
end;

function UrfSeeder:mouseEvent(posX, posY, isDown, isUp, button)
end;

function UrfSeeder:update(dt)
  if self:getIsActive() then
    if self:getIsActiveForInput() then
			if self.isUrfSeeder then
				if InputBinding.hasEvent(InputBinding.URF_FERTILIZATION) then
					local newState = not self.isFertilizing;
					self:setIsFertilizing(newState);
				end;
        if InputBinding.hasEvent(InputBinding.URF_FTYPE) then
          local currentSprayFillType = self.currentSprayFillType;
          self:setCurrentSprayFillType(currentSprayFillType);
        end;
			end;
			if self.ridgeMarkerState ~= nil then
				if InputBinding.hasEvent(InputBinding.URF_RMleft) then
					local rmState = self.ridgeMarkerState;
					if rmState == 0 then
						rmState = 1;
					else
						rmState = 0;
					end;
					self:setRidgeMarkerState(rmState);
				end;
				if InputBinding.hasEvent(InputBinding.URF_RMright) then
					local rmState = self.ridgeMarkerState;
					if rmState == 0 then
						rmState = 2;
					else
						rmState = 0;
					end;
					self:setRidgeMarkerState(rmState);
				end;
			end;
			if InputBinding.hasEvent(InputBinding.URF_TOGGLESHUTOFF) then
        local shutoff = self.shutoff + 1;
        if shutoff > 2 then
          shutoff = 0;
        end;
			  self:setShutoff(shutoff);
			end;
    end;
	end;
end;

function UrfSeeder:updateTick(dt)
	if self.isUrfSeeder then
		if self:getIsActive() then
			self.lastSprayingArea = 0;
			local doGroundManipulation = (self.movingDirection > 0 and self.sowingMachineHasGroundContact and (not self.needsActivation or self.isTurnedOn));

			if doGroundManipulation then
				if self.isServer then
					if self.isFertilizing then
					--#### DECKER_MMIV ############################################################
          -- Use 'fillType' in sprayer area event
            local fillType = self.currentSprayFillType;
            if fillType == Fillable.FILLTYPE_UNKNOWN then
              fillType = self:getFirstEnabledFillType();
            end;
            -- URF-seeder has it´s own litersPerSecond!
            --local litersPerSecond = self.sprayLitersPerSecond[self.currentFillType];
            --local litersPerSecond = self.sprayLitersPerSecond[fillType];
            --#############################################################################
						local litersPerSecond = self.sprayLitersPerSecond;

						local usage = litersPerSecond * dt*0.001;
						if self.isRealistic then
							usage = usage * RealisticGlobalListener.realDifficultyFX8; -- hard / normal / easy = 1 / 1 / 0.5
							if self.realSprayingReferenceSpeed>0 then
								usage = usage * math.max(0.5, self.realGroundSpeed)/self.realSprayingReferenceSpeed;
								--print(self.time .. " SprayingReferenceSpeed / usage = " .. tostring(self.realSprayingReferenceSpeed) .. " / " .. usage);
							end;
						end;
						local hasSpray = false;

						if self:getIsHired() and g_currentMission.missionStats.difficulty==1 then
							hasSpray = true;
							local sprayFillType = self.currentSprayFillType;
							local sprayFillTypeDesc = Fillable.fillTypeIndexToDesc[sprayFillType];
							if sprayFillTypeDesc ~= nil then
								local delta = usage*sprayFillTypeDesc.pricePerLiter;
								g_currentMission.missionStats.expensesTotal = g_currentMission.missionStats.expensesTotal + delta;
								g_currentMission.missionStats.expensesSession = g_currentMission.missionStats.expensesSession + delta;

								g_currentMission:addSharedMoney(-delta, "other");

							end;
						else
							if self.sprayFillLevel > 0 and self.fillLevel > 0 then
								hasSpray = true;
								self:setSprayFillLevel(self.sprayFillLevel - usage);
							end;
						end;

						if hasSpray then
							if self.shutoff == 0 then
								self.sprayAmount = self.cuttingAreas;
							elseif self.shutoff == 1 then
								self.sprayAmount = self.rightCuttingAreas;
							elseif self.shutoff == 2 then
								self.sprayAmount = self.leftCuttingAreas;
							end;

							local sprayingAreasSend = {};
							for _,sprayingArea in pairs(self.sprayAmount) do
								if self:getIsAreaActive(sprayingArea) then
									local sx,s_,sz = getWorldTranslation(sprayingArea.start);
									local sx1,s_1,sz1 = getWorldTranslation(sprayingArea.width);
									local sx2,s_2,sz2 = getWorldTranslation(sprayingArea.height);
									local sqm = math.abs((sz1-sz)*(sx2-sx) - (sx1-sx)*(sz2-sz)); -- this is the cross product with y=0
									--Utils.updateSprayArea(x, z, x1, z1, x2, z2);
									self.lastSprayingArea = self.lastSprayingArea + sqm;
									table.insert(sprayingAreasSend, {sx,sz,sx1,sz1,sx2,sz2});
								end;
							end;
							if (table.getn(sprayingAreasSend) > 0) then
                --#### DECKER_MMIV ############################################################
                -- Add 'fillType' to sprayer area event
                -- SprayerAreaEvent.runLocally(sprayingAreasSend);
                -- g_server:broadcastEvent(SprayerAreaEvent:new(sprayingAreasSend));
								SprayerAreaEvent.runLocally(sprayingAreasSend, filltype + 128); -- +128 for use with growth state 0!
								g_server:broadcastEvent(SprayerAreaEvent:new(sprayingAreasSend, filltype + 128));
                --#############################################################################
							end;
						end;
					end;
				end;
			end
		end;

		if self.isServer and self.isSprayerFilling then
			local delta = 0;
			if self.sprayerFillTrigger ~= nil then
				delta = self.sprayFillLitersPerSecond*dt*0.001;
				delta = self:fillUpSprayer(delta);
			end;
			if delta <= 0 then
				self:setIsSprayerFilling(false);
			end;
		end;
	end;
end;

function UrfSeeder:drawFillLevels()
	if self.isUrfSeeder then
		local percent = 0;
		local level = self.sprayFillLevel;
		local capacity = self.sprayCapacity;
		percent = level / capacity * 100;

		-- render the hud overlays
		self.hudBgOverlay:render();

		if percent > 10 then
			self.hudBarOverlay = self.hudBarLimeOverlay;
		else
			self.hudBarOverlay = self.hudBarRedOverlay;
		end;

		self.hudBarOverlay.width = self.hudBarWidth * (self.sprayFillLevel / self.sprayCapacity);
		setOverlayUVs(self.hudBarOverlay.overlayId, 0, 0.05, 0, 1, self.sprayFillLevel / self.sprayCapacity, 0.05, self.sprayFillLevel / self.sprayCapacity, 1);
		self.hudBarOverlay:render();

		if self.isFertilizing then
			self.hudOverlay = self.hudHalfOverlay;
		else
			self.hudOverlay = self.hudNoneOverlay;
		end;
		self.hudOverlay:render();

		-- write fertilizer level
		setTextBold(true);
		setTextAlignment(RenderText.ALIGN_CENTER);

		setTextColor(0, 0, 0, 1);
		renderText(self.xPos + 0.075, self.yPos + 0.011, 0.017, string.format("%d (%d%%)", level, percent));
		if percent > 10 then
			setTextColor(1, 1, 1, 1);
		else
			setTextColor(1, 0, 0, 1);
		end;
		renderText(self.xPos + 0.075, self.yPos + 0.013, 0.017, string.format("%d (%d%%)", level, percent));

		setTextColor(1, 1, 1, 1);
		setTextAlignment(RenderText.ALIGN_LEFT);
		setTextBold(false);
	end;
end;

function UrfSeeder:draw()
    if self.isClient then
        if self:getIsActiveForInput(true) then
			if self.isUrfSeeder then
        g_currentMission:addHelpButtonText(self.textFtype, InputBinding.URF_FTYPE);
				if self.isFertilizing then
					g_currentMission:addHelpButtonText(self.textFertilization .. " " .. self.textOff, InputBinding.URF_FERTILIZATION);
				else
					g_currentMission:addHelpButtonText(self.textFertilization .. " " .. self.textOn, InputBinding.URF_FERTILIZATION);
				end;
			end;
			if self.shutoff == 0 then
                g_currentMission:addHelpButtonText(self.textToggleshutoff .. " " .. self.textOff, InputBinding.URF_TOGGLESHUTOFF);
			elseif self.shutoff == 1 then
                g_currentMission:addHelpButtonText(self.textToggleshutoff .. " " .. self.textLeft, InputBinding.URF_TOGGLESHUTOFF);
			elseif self.shutoff == 2 then
                g_currentMission:addHelpButtonText(self.textToggleshutoff .. " " .. self.textRight, InputBinding.URF_TOGGLESHUTOFF);
			end;
			if self.ridgeMarkerState ~= nil then
				g_currentMission:addExtraPrintText(g_i18n:getText("URF_RMleft")..": "..InputBinding.getKeyNamesOfDigitalAction(InputBinding.URF_RMleft).." / "..g_i18n:getText("URF_RIGHT")..": "..InputBinding.getKeyNamesOfDigitalAction(InputBinding.URF_RMright));
			end;
        end;
		if self.isUrfSeeder then
			self:drawFillLevels();

      self.hudSprayOverlay = Overlay:new("hudSprayOverlay", g_currentMission.fillTypeOverlays[self.currentSprayFillType].filename, g_currentMission.fillTypeOverlays[self.currentSprayFillType].x - 0.075, g_currentMission.fillTypeOverlays[self.currentSprayFillType].y, g_currentMission.fillTypeOverlays[self.currentSprayFillType].width, g_currentMission.fillTypeOverlays[self.currentSprayFillType].height);
      self.hudSprayOverlay:render();
    end;
  end;
end;

function UrfSeeder:setSprayFillLevel(sprayFillLevel, noEventSend)
  self.sprayFillLevel = sprayFillLevel;
  if self.sprayFillLevel > self.sprayCapacity then
    self.sprayFillLevel = self.sprayCapacity;
  end;
  if self.sprayFillLevel <= 0 then
    self.sprayFillLevel = 0;
  end;
  -- TODO: take mass of fertilizer into account

	--synchronize fill level in mp
	UrfSeederFillLevelEvent.sendEvent(self, self.sprayFillLevel, noEventSend);
end;

function UrfSeeder:setIsFertilizing(urfState, noEventSend)
	--synchronize fertilization state in mp
	UrfSeederStateEvent.sendEvent(self, urfState, noEventSend);
	self.isFertilizing = urfState;
end;

function UrfSeeder:setCurrentSprayFillType(currentSprayFillType, noEventSend)
  local action = -1;
  for i,sprayType in ipairs(self.mySprays) do
    if sprayType ~= nil and sprayType == currentSprayFillType then
      for k=0,table.getn(self.mySprays) do
        i = (i % table.getn(self.mySprays))+1
        if self.mySprays[i] then
          action = self.mySprays[i];
          break;
        end;
      end;
      break;
    end;
  end;
  if action >= 0 then
    self.currentSprayFillType = action;
  end;
  --synchronize spray type in mp
  UrfSeederSprayTypeEvent.sendEvent(self, self.currentSprayFillType, noEventSend);
end;

function UrfSeeder:setShutoff(shutoff, noEventSend)
	--synchronize shutoff state in mp
	UrfSeederShutoffEvent.sendEvent(self, shutoff, noEventSend);
	self.shutoff = shutoff;
	if self.shutoff == 1 then
		self.cuttingAreas = self.rightCuttingAreas;
	elseif self.shutoff == 2 then
		self.cuttingAreas = self.leftCuttingAreas;
	elseif self.shutoff == 0 then
		self.cuttingAreas = self.origCuttingAreas;
	end;
end;

function UrfSeeder:setIsSprayerFilling(isFilling, noEventSend)
  SprayerSetIsFillingEvent.sendEvent(self, isFilling, noEventSend)
  if self.isSprayerFilling ~= isFilling then
    self.isSprayerFilling = isFilling;
      if isFilling then
        -- find the first trigger which is activable
        self.sprayerFillTrigger = nil;
          for i=1, table.getn(self.sprayerFillTriggers) do
            local trigger = self.sprayerFillTriggers[i];
            if (self.currentSprayFillType == trigger.fillType) or (trigger.isSiloTrigger and g_currentMission:getSiloAmount(trigger.fillType) > 0) then
              self.sprayerFillTrigger = trigger;
              break;
            end;
          end;
      end:
  end;
end;

function UrfSeeder:addSprayerFillTrigger(trigger)
	if self.isUrfSeeder then
		if table.getn(self.sprayerFillTriggers) == 0 then
			g_currentMission:addActivatableObject(self.sprayerFillActivatable);
		end;
		table.insert(self.sprayerFillTriggers, trigger);
	end;
end;

function UrfSeeder:removeSprayerFillTrigger(trigger)
	if self.isUrfSeeder then
		for i=1, table.getn(self.sprayerFillTriggers) do
			if self.sprayerFillTriggers[i] == trigger then
				table.remove(self.sprayerFillTriggers, i);
				break;
			end;
		end;
		if table.getn(self.sprayerFillTriggers) == 0 or trigger == self.sprayerFillTrigger then
			if self.isServer then
				self:setIsSprayerFilling(false);
			end;
			if table.getn(self.sprayerFillTriggers) == 0 then
				g_currentMission:removeActivatableObject(self.sprayerFillActivatable);
			end
		end;
	end;
end;

function UrfSeeder:wwMinMaxAI()

	local x1,y1,z1,x2,y2,z2 = 0;
	if self.aiLeftMarker ~= nil and self.aiRightMarker ~= nil then
		x1,y1,z1 = getTranslation(self.aiLeftMarker)
		x2,y2,z2 = getTranslation(self.aiRightMarker)
		self.markerZPos = z1;

		if x1 < self.wwMin then
			self.wwMin = x1;
		end
		if x1 > self.wwMax then
			self.wwMax = x1;
		end
		if x2 < self.wwMin then
			self.wwMin = x2;
		end
		if x2 > self.wwMax then
			self.wwMax = x2;
		end
	end

	return self.wwMin, self.wwMax, y1, z1;
end;

function UrfSeeder:wwMinMaxAreas(areas)
	local x1,y1,z1,x2,y2,z2,x3,y3,z3 = 0;
	if areas ~= nil then
		for _,cuttingArea in pairs(areas) do
				x1,y1,z1 = getTranslation(cuttingArea.start);
				x2,y2,z2 = getTranslation(cuttingArea.width);
				x3,y3,z3 = getTranslation(cuttingArea.height);

				if x1 < self.wwMin then
					self.wwMin = x1;
				end;
				if x1 > self.wwMax then
					self.wwMax = x1;
				end;
				if x2 < self.wwMin then
					self.wwMin = x2;
				end;
				if x2 > self.wwMax then
					self.wwMax = x2;
				end;
				if x3 < self.wwMin then
					self.wwMin = x3;
				end;
				if x3 > self.wwMax then
					self.wwMax = x3;
				end;
		end;
	end;
	return self.wwMin, self.wwMax, y1, z1;
end

SprayerFillActivatable = {}
local SprayerFillActivatable_mt = Class(SprayerFillActivatable);

function SprayerFillActivatable:new(sprayer)
  local self = {};
  setmetatable(self, SprayerFillActivatable_mt);

  self.sprayer = sprayer;
  self.activateText = "unknown";

  return self;
end;

function SprayerFillActivatable:getIsActivatable()
  if self.sprayer:getIsActiveForInput() and self.sprayer.sprayFillLevel < self.sprayer.sprayCapacity then
    -- find the first trigger which is activable
    for i=1, table.getn(self.sprayer.sprayerFillTriggers) do
      local trigger = self.sprayer.sprayerFillTriggers[i];
      if (self.sprayer.currentSprayFillType == trigger.fillType) or (trigger.isSiloTrigger and g_currentMission:getSiloAmount(trigger.fillType) > 0) then
        self:updateActivateText();
        return true;
      end;
    end;
  end;
  return false;
end;

function SprayerFillActivatable:onActivateObject()
  self.sprayer:setIsSprayerFilling(not self.sprayer.isSprayerFilling);
  self:updateActivateText();
  g_currentMission:addActivatableObject(self);
end;

function SprayerFillActivatable:drawActivate()
  -- TODO draw icon
end;

function SprayerFillActivatable:updateActivateText()
  if self.sprayer.isSprayerFilling then
    self.activateText = string.format(g_i18n:getText("URF_STOP_REFILL"), self.sprayer.typeDesc);
  else
    self.activateText = string.format(g_i18n:getText("URF_REFILL"), self.sprayer.typeDesc);
  end;
end;

function UrfSeeder:fillUpSprayer(deltax)

	local oldFillLevel = self.sprayFillLevel;
	if self.sprayerFillTrigger.isSiloTrigger then
		local silo = g_currentMission:getSiloAmount(self.sprayerFillTrigger.fillType);
		deltax = math.min(deltax, silo);
		if deltax > 0 then
			self:setSprayFillLevel(oldFillLevel + deltax);
			deltax = self.sprayFillLevel - oldFillLevel;
			g_currentMission:setSiloAmount(self.sprayerFillTrigger.fillType, silo - deltax);
		end;
	else
		self:setSprayFillLevel(oldFillLevel + deltax);
		deltax = self.sprayFillLevel - oldFillLevel;

		local fillTypeDesc = Fillable.fillTypeIndexToDesc[self.sprayerFillTrigger.fillType];

		if fillTypeDesc ~= nil then
			local price = deltax*fillTypeDesc.pricePerLiter;
			g_currentMission.missionStats.expensesTotal = g_currentMission.missionStats.expensesTotal + price;
			g_currentMission.missionStats.expensesSession = g_currentMission.missionStats.expensesSession + price;
			g_currentMission:addSharedMoney(-price, "other");
		end;
	end;
	return deltax;
end;
