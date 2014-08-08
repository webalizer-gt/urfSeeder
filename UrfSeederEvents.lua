--MP-Events for specialization urfSeeder 3.0

-- Fertilizer fill level
UrfSeederFillLevelEvent = {};
UrfSeederFillLevelEvent_mt = Class(UrfSeederFillLevelEvent, Event);

InitEventClass(UrfSeederFillLevelEvent, "UrfSeederFillLevelEvent");

function UrfSeederFillLevelEvent:emptyNew()
    local self = Event:new(UrfSeederFillLevelEvent_mt);
    self.className="UrfSeederFillLevelEvent";
    return self;
end;

function UrfSeederFillLevelEvent:new(vehicle, sprayFillLevel)
    local self = UrfSeederFillLevelEvent:emptyNew()
    self.vehicle = vehicle;
	self.vehicle.sprayFillLevel = sprayFillLevel;
    return self;
end;

function UrfSeederFillLevelEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
    self.vehicle = networkGetObject(id);
	self.vehicle.sprayFillLevel = streamReadInt32(streamId);
    
	if not connection:getIsServer() then
        g_server:broadcastEvent(UrfSeederFillLevelEvent:new(self.vehicle, self.vehicle.sprayFillLevel), nil, connection, self.vehicle);
    end;
end;

function UrfSeederFillLevelEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
	streamWriteInt32(streamId, self.vehicle.sprayFillLevel);
end;

function UrfSeederFillLevelEvent.sendEvent(vehicle, fillLevel, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UrfSeederFillLevelEvent:new(vehicle, fillLevel), nil, nil, vehicle);
		else
			g_client:getServerConnection():sendEvent(UrfSeederFillLevelEvent:new(vehicle, fillLevel));
		end;
	end;
end;

-- Fertilizer state
UrfSeederStateEvent = {};
UrfSeederStateEvent_mt = Class(UrfSeederStateEvent, Event);

InitEventClass(UrfSeederStateEvent, "UrfSeederStateEvent");

function UrfSeederStateEvent:emptyNew()
    local self = Event:new(UrfSeederStateEvent_mt);
    self.className="UrfSeederStateEvent";
    return self;
end;

function UrfSeederStateEvent:new(vehicle, state)
    local self = UrfSeederStateEvent:emptyNew()
    self.vehicle = vehicle;
	self.isFertilizing = state;
    return self;
end;

function UrfSeederStateEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
	self.isFertilizing = streamReadBool(streamId);
    self.vehicle = networkGetObject(id);
    self:run(connection);
end;

function UrfSeederStateEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
	streamWriteBool(streamId, self.isFertilizing);
end;

function UrfSeederStateEvent:run(connection)
	self.vehicle:setIsFertilizing(self.isFertilizing, true);
    if not connection:getIsServer() then
        g_server:broadcastEvent(UrfSeederStateEvent:new(self.vehicle, self.isFertilizing), nil, connection, self.object);
    end;
end;

function UrfSeederStateEvent.sendEvent(vehicle, shutoff, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UrfSeederStateEvent:new(vehicle, shutoff), nil, nil, vehicle);
		else
			g_client:getServerConnection():sendEvent(UrfSeederStateEvent:new(vehicle, shutoff));
		end;
	end;
end;

-- shutoff state
UrfSeederShutoffEvent = {};
UrfSeederShutoffEvent_mt = Class(UrfSeederShutoffEvent, Event);

InitEventClass(UrfSeederShutoffEvent, "UrfSeederShutoffEvent");

function UrfSeederShutoffEvent:emptyNew()
    local self = Event:new(UrfSeederShutoffEvent_mt);
    self.className="UrfSeederShutoffEvent";
    return self;
end;

function UrfSeederShutoffEvent:new(vehicle, shutoff)
    local self = UrfSeederShutoffEvent:emptyNew()
    self.vehicle = vehicle;
	self.shutoff = shutoff;
    return self;
end;

function UrfSeederShutoffEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
	self.shutoff = streamReadInt8(streamId);
    self.vehicle = networkGetObject(id);
    self:run(connection);
end;

function UrfSeederShutoffEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
	streamWriteInt8(streamId, self.shutoff);
end;

function UrfSeederShutoffEvent:run(connection)
	self.vehicle:setShutoff(self.shutoff, true);
    if not connection:getIsServer() then
        g_server:broadcastEvent(UrfSeederShutoffEvent:new(self.vehicle, self.shutoff), nil, connection, self.object);
    end;
end;

function UrfSeederShutoffEvent.sendEvent(vehicle, shutoff, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UrfSeederShutoffEvent:new(vehicle, shutoff), nil, nil, vehicle);
		else
			g_client:getServerConnection():sendEvent(UrfSeederShutoffEvent:new(vehicle, shutoff));
		end;
	end;
end;