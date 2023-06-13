
local math = require 'math'

local P = {}

function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function P:getIntersection(ray, segment, observer)
	local r_px = ray.s.x
	local r_py = ray.s.y

	local r_dx = ray.e.x - ray.s.x
	local r_dy = ray.e.y - ray.s.y

	local s_px = segment.s.x
	local s_py = segment.s.y
	local s_dx = segment.e.x - segment.s.x
	local s_dy = segment.e.y - segment.s.y

	local r_mag = math.sqrt(r_dx * r_dx + r_dy * r_dy)
	local s_mag = math.sqrt(s_dx * s_dx + s_dy * s_dy)
	if (r_dx / r_mag == s_dx / s_mag and r_dy / r_mag == s_dy / s_mag) then
		return nil
	end

	local T2 = (r_dx * (s_py - r_py) + r_dy * (r_px - s_px)) / (s_dx * r_dy - s_dy * r_dx)
	local T1 = (s_px + s_dx * T2 - r_px) / r_dx

	if(T1<0) then 
        return nil;
    end
	if(T2<0 or T2>1) then
        return nil;
    end

	local intersection = {
		x = round(r_px + r_dx * T1, 1),
		y = round(r_py + r_dy * T1, 1),
		param = round(T1)
	}
	
	return intersection
end

function P:getIntersectionOld(ray,segment)

	-- RAY in parametric: Point + Delta*T1
	local r_px = ray.s.x;
	local r_py = ray.s.y;
	local r_dx = ray.e.x-ray.s.x;
	local r_dy = ray.e.y-ray.s.y;

	-- SEGMENT in parametric: Point + Delta*T2
	local s_px = segment.s.x;
	local s_py = segment.s.y;
	local s_dx = segment.e.x-segment.s.x;
	local s_dy = segment.e.y-segment.s.y;

	-- Are they parallel? If so, no intersect
	local r_mag = math.sqrt(r_dx*r_dx+r_dy*r_dy);
	local s_mag = math.sqrt(s_dx*s_dx+s_dy*s_dy);
	if (r_dx/r_mag==s_dx/s_mag and r_dy/r_mag==s_dy/s_mag) then
		-- Unit vectors are the same.
		return nil;
    end

	-- SOLVE FOR T1 & T2
	-- r_px+r_dx*T1 = s_px+s_dx*T2 && r_py+r_dy*T1 = s_py+s_dy*T2
	-- ==> T1 = (s_px+s_dx*T2-r_px)/r_dx = (s_py+s_dy*T2-r_py)/r_dy
	-- ==> s_px*r_dy + s_dx*T2*r_dy - r_px*r_dy = s_py*r_dx + s_dy*T2*r_dx - r_py*r_dx
	-- ==> T2 = (r_dx*(s_py-r_py) + r_dy*(r_px-s_px))/(s_dx*r_dy - s_dy*r_dx)
	local T2 = (r_dx*(s_py-r_py) + r_dy*(r_px-s_px))/(s_dx*r_dy - s_dy*r_dx);
	local T1 = (s_px+s_dx*T2-r_px)/r_dx;

	-- Must be within parametic whatevers for RAY/SEGMENT
	if(T1<0) then 
        return nil;
    end
	if(T2<0 or T2>1) then
        return nil;
    end

	local intersection = {
		x=round(r_px+r_dx*T1,1),
		y=round(r_py+r_dy*T1,1),
		param=round(T1,1)
	};

	-- print ("Intersection")
	-- print (intersection.x)
	-- print (intersection.y) 
	-- print (intersection.param) 
	-- Return the POINT OF INTERSECTION
	return intersection;
end

function P:renderObscurers(display, group, objectData, onTouch)
    -- Loop through table and create objects
	for i = 1,#objectData do

		-- Create object
		local obj = display.newPolygon( group, objectData[i].x, objectData[i].y, objectData[i].vertices)
		obj:setFillColor( objectData[i].r, objectData[i].g, objectData[i].b )

        obj.label = display.newText( mainGroup, obj.id .. " - " .. string.format("%0.0f",obj.x)..", "..string.format("%0.0f",obj.y), obj.x, objectData[i].y-(obj.height/2)-14, appFont, 12 )
		obj.label:setFillColor( 0.8 )
	end
end

function P:renderSegments(display, group, objectData)
	for i = 1,#objectData do
		display.newLine( group, 
			objectData[i].s.x,
			objectData[i].s.y,
			objectData[i].e.x,
			objectData[i].e.y
		)
	end
end

function P:getUniquePoints(segments)
    local points = {}
    for key, seg in ipairs(segments) do
        table.insert(points, {x = seg.s.x, y = seg.s.y})
		table.insert(points, {x = seg.e.x, y = seg.e.y})
    end
    
    local uniquePoints = {}
    local set = {}

    for key, point in ipairs(points) do
        local key = point.x .. "," .. point.y
        if not set[key] then
			point.angle=0
            table.insert(uniquePoints, point)
            set[key] = true
        end
    end
    return uniquePoints
end

function P:getUniqueAngles(uniquePoints, observer)
	local uniqueAngles = {}
	local set = {}

	for _, uniquePoint in ipairs(uniquePoints) do
		local angle = math.atan2(
			uniquePoint.y-observer.y,
			uniquePoint.x-observer.x
		)
		uniquePoint.angle = angle
		if not set[angle] then
			table.insert(uniqueAngles, angle-0.00001)
			table.insert(uniqueAngles, angle)
			table.insert(uniqueAngles, angle+0.00001)
            set[angle] = true
        end
	end
	return uniqueAngles
end

function P:getVisiblePolygonPoints(segments, uniqueAngles, observer)
	local intersects = {}
	local set = {}

	local count = 0

	for _, angle in ipairs(uniqueAngles) do
		--if count <=0 then
			-- Calculate dx & dy from angle
			local dx = math.cos(angle);
			local dy = math.sin(angle);

			local ray = {
				s={ x=observer.x, y=observer.y },
				e={ x=observer.x+dx, y=observer.y+dy }
			}

			local closestIntersect = nil;
			for _, s in ipairs(segments) do
				local intersect = P:getIntersection(ray, s)
				if intersect then 
					if not closestIntersect then 
						closestIntersect = intersect;
					end
					if intersect.param < closestIntersect.param then 
						closestIntersect = intersect;
					end
				end
				if closestIntersect then
					print("Intersect");
					print (closestIntersect.param)
					local key = closestIntersect.x .. "," .. closestIntersect.y
					if not set[key] then
						table.insert(intersects, closestIntersect)
						set[key] = true
					end
				end
 
		end
	end
	return intersects
end

function P:renderVisibilityPolygon(display, group, observer, visibleAreaPolyData, redraw)

	-- print(table.getn(viewAreaToDraw))
	-- if redraw == true then
		for i = 1, table.getn(visibleAreaPolyData) do
			if group[i] then
				group:remove(i) 
			end
		end
		viewAreaToDraw = {}
	-- end

	-- print("START visibleAreaPolyData");
	-- for _, p in ipairs(visibleAreaPolyData) do
	-- 	print(p.x, p.y)
	-- end
	-- print("END visibleAreaPolyData");

	local pointId = 0
	local previous = {}

	for _, p in ipairs(visibleAreaPolyData) do
		-- if pointId <=3 then
		    -- group:remove(i)
			viewAreaToDraw[pointId] = display.newLine(
				group,
				observer.x, 
				observer.y, 
				p.x, 
				p.y
			)
		-- end
		pointId = pointId + 1
	-- obj:setFillColor( 0.8, 0.8, 0.8 )
	end
end

function P:renderObserverViewArea(display, group, observer, segments, redraw)
	local uniquePoints = P:getUniquePoints(segments)
	local angles = P:getUniqueAngles(uniquePoints, observer)
	local viewTriangles = P:getVisiblePolygonPoints(segments, angles, observer)
	P:renderVisibilityPolygon(display, group, observer, viewTriangles, redraw)
end

function P:renderTriangles(display, group, segments, observers)
	local points = {}
    -- Get all unique points

	for _, o in ipairs(observers) do
		if o.requireObserverRedraw then
	        P:renderObserverViewArea(display, group, o, segments, false)
		end
		
    end

end

return P