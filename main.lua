
local inspect = require 'inspect'
local iolib = require 'iolib'
local math = require 'math'

local debug = 0

display.setStatusBar( display.HiddenStatusBar )

-- Render the sample UI
local sampleUI = require( "sampleUI.sampleUI" )
sampleUI:newUI( { theme="darkgrey", title="Drag Me", showBuildNum=false } )

local pathtrace = require( "pathtrace.pathtrace" )

-- Configure Stage by adding groups
display.getCurrentStage():insert( sampleUI.backGroup )
display.getCurrentStage():insert( sampleUI.frontGroup )
local mainGroup = display.newGroup()
local obscurerGroup = display.newGroup()
local observerGroup = display.newGroup()
rayGroup = display.newGroup()
viewGroup = display.newGroup()
viewAreaToDraw = {}
local currentRays = {}
local activeObserver = 1

local isMultitouchEnabled = false

-- Require libraries/plugins
local widget = require( "widget" )
widget.setTheme( "widget_theme_ios7" )
local appFont = sampleUI.appFont

local function loadMap(name)
	segments = iolib.read(name, system.DocumentsDirectory)
	print('Segment Data:')
	inspect.inspect(segments)
end

-- Function to toggle multitouch
local function onSwitchPress( event )

	if ( event.target.isOn ) then
		-- Activate multitouch
		system.activate( "multitouch" )
		isMultitouchEnabled = true
	else
		-- Loop through touch-sensitive objects and force-release touch
		for i = 1,mainGroup.numChildren do
			if ( mainGroup[i].isDragObject == true ) then
				mainGroup[i]:dispatchEvent( { name="touch", phase="ended", target=mainGroup[i] } )
			end
		end
		-- Deactivate multitouch
		system.deactivate( "multitouch" )
		isMultitouchEnabled = false
	end
end

-- Detect if multitouch is supported
if not system.hasEventSource( "multitouch" ) then

	-- Inform that multitouch is not supported
	local shade = display.newRect( mainGroup, display.contentCenterX, display.contentHeight-display.screenOriginY-18, display.actualContentWidth, 36 )
	shade:setFillColor( 0, 0, 0, 0.7 )
	local msg = display.newText( mainGroup, "Multitouch events not supported on this platform", display.contentCenterX, shade.y, appFont, 13 )
	msg:setFillColor( 1, 0, 0.2 )
else
	-- Create switch/label to enable/disable multitouch
	local enableMultitouchCheckbox = widget.newSwitch(
	{
		x = display.contentCenterX - 68,
		y = display.contentHeight-display.screenOriginY-40,
		style = "checkbox",
		initialSwitchState = true,
		onPress = onSwitchPress
	})
	mainGroup:insert( enableMultitouchCheckbox )
	local checkboxLabel = display.newText( mainGroup, "Enable Multitouch", display.contentCenterX+18, enableMultitouchCheckbox.y, appFont, 16 )

	-- Activate multitouch
	system.activate( "multitouch" )
	isMultitouchEnabled = true
end

local function setObserverLabel(obj)
	obj.label.text = obj.id .. " - " .. string.format("%0.0f",obj.x)..", "..string.format("%0.0f",obj.y)
	obj.label.x = obj.x
	obj.label.y = obj.y-(obj.height/2)-14
end

-- Touch handling function
local function onTouch( event )

	local obj = event.target

	local phase = event.phase

	if ( "began" == phase ) then
		
		-- Make target and its label the top-most objects
		obj:toFront()
		obj.label:toFront()

		-- Set focus on the object based on the unique touch ID, and if multitouch is enabled
		if ( isMultitouchEnabled == true ) then
			display.currentStage:setFocus( obj, event.id )
		else
			display.currentStage:setFocus( obj )
		end
		-- Spurious events can be sent to the target, for example the user presses
		-- elsewhere on the screen and then moves the finger over the target;
		-- to prevent this, we add this flag and only move the target when it's true
		obj.isFocus = true

		-- Store initial position
		obj.x0 = event.x - obj.x
		obj.y0 = event.y - obj.y

	elseif obj.isFocus then

		if ( "moved" == phase ) then

			-- Make object move; we subtract "obj.x0" and "obj.y0" so that moves are relative
			-- to the initial touch point rather than the object snapping to that point
			obj.x = event.x - obj.x0
			obj.y = event.y - obj.y0
			obj.range = event.target.range

			-- Save x & y back into the observer data
			event.target.x = event.x
			event.target.y = event.y

			-- obj.currentRays = event.target.currentRays

			-- pathtrace:renderObserverViewArea(display, viewGroup, event.target, segments, true)

			display.remove(rayGroup)
			rayGroup = display.newGroup()
			
			drawObserverRays(display, rayGroup, obj, segmentVertices)
			-- Update/move object label
			setObserverLabel(obj)

			-- Gradually show the shape's stroke depending on how much pressure is applied
			if ( event.pressure ) then
				obj:setStrokeColor( 1, 1, 1, event.pressure )
			end

		elseif ( "ended" == phase or "cancelled" == phase ) then

			-- Release focus on the object
			if ( isMultitouchEnabled == true ) then
				display.currentStage:setFocus( obj, nil )
			else
				display.currentStage:setFocus( nil )
			end
			obj.isFocus = false

			obj:setStrokeColor( 1, 1, 1, 0 )
		end
	end
	return true
end

-- Data table for position, radius, and color of objects
local observers =
{
	[1] = { id=1,
	  label = 'A',
	  r=1, g=0, b=0.1,  
	  x=25, y=75, 
	  radius=5,
	  range=70,
	  requireObserverRedraw = true,
	},
	[2] = { id=2,
	 label = 'B',
	 r=0.1, g=0, b=1, 
	  x=150, y=75,
	   radius=5,
    range=40,
	requireObserverRedraw = true,
},

	-- { id=2, label = '', x=65, y=175, radius=32, r=0.95, g=0.1, b=0.3, requireObserverRedraw = true },
	-- { id=3, label = '', x=200, y=225, radius=48, r=0.9, g=0.2, b=0.5, requireObserverRedraw = false },
	-- { id=4, label = '', x=100, y=350, radius=18, r=0.9, g=0.9, b=0.1, requireObserverRedraw = false },

}

segments = {

	-- line #0
	-- {s={x=100,y=150}, e={x=120,y=50}, r=0.9, g=0.9, b=0.1},

	-- line #0
	-- {s={x=100,y=150}, e={x=120,y=50}, r=0.9, g=0.9, b=0.1},

	-- test poly
	{s={x=50,y=50}, e={x=50,y=100}},
	{s={x=50,y=100}, e={x=100,y=100}},
	{s={x=100,y=100}, e={x=100,y=50}},
	{s={x=100,y=50}, e={x=50,y=50}},

	-- test poly
	{s={x=100,y=100}, e={x=120,y=100}},
	{s={x=120,y=100}, e={x=120,y=120}},
	{s={x=120,y=120}, e={x=100,y=120}},
	{s={x=100,y=120}, e={x=100,y=100}},


		-- Border
		{s={x=40,y=40}, e={x=300,y=40}, r=0.9, g=0.9, b=0.1},
		{s={x=300,y=40}, e={x=300,y=300}, r=0.9, g=0.9, b=0.1},
		{s={x=300,y=300}, e={x=40,y=300}, r=0.9, g=0.9, b=0.1},
		{s={x=40,y=300}, e={x=40,y=40}, r=0.9, g=0.9, b=0.1},
	
	-- -- poly 0
	-- {s={x=100,y=150}, e={x=120,y=50}},
	-- {s={x=120,y=50}, e={x=200,y=80}},
	-- {s={x=200,y=80}, e={x=140,y=210}},
	-- {s={x=140,y=210}, e={x=100,y=150}},

	-- -- poly 0
	-- {s={x=100,y=150}, e={x=120,y=50}},
	-- {s={x=120,y=50}, e={x=200,y=80}},
	-- {s={x=200,y=80}, e={x=140,y=210}},
	-- {s={x=140,y=210}, e={x=100,y=150}},

	-- --repeat poly 0
	-- {s={x=100,y=150}, e={x=120,y=50}},
	-- {s={x=120,y=50}, e={x=200,y=80}},
	-- {s={x=200,y=80}, e={x=140,y=210}},
	-- {s={x=140,y=210}, e={x=100,y=150}},

	--poly 1
	{s={x=90,y=250}, e={x=190,y=280}},
	{s={x=190,y=280}, e={x=130,y=310}},
	{s={x=130,y=310}, e={x=90,y=250}},

	--poly 2
	{s={x=10,y=300}, e={x=70,y=270}},
	{s={x=70,y=270}, e={x=80,y=330}},
	{s={x=80,y=330}, e={x=10,y=300}},
}

local obscurers = {
	{ id=1,
	  x=100, y=50, 
	  vertices = { 10, 10, 40, 10, 40, 20, 10, 20},
	  r=0.8, g=0.2, b=0.1,
	},
	{ 
	  id=2,	
	  x=75, y=275,
	  vertices = { 20, 20, 20, 40, 40, 40, 40, 20},
	  r=0.9, g=0.9, b=0.1,
	}
}
local function renderObservers(display, group, objectData)
	for i = 1,#objectData do
		local obj = display.newCircle( group, objectData[i].x, objectData[i].y, objectData[i].radius )
		obj:setFillColor( objectData[i].r, objectData[i].g, objectData[i].b )

		obj.isDragObject = true
		obj.id = objectData[i].id
		-- Create label to show x/y of object
		-- setObserverLabel(obj)
		obj.label = display.newText( mainGroup, string.format("%0.0f",obj.x)..", "..string.format("%0.0f",obj.y), obj.x, objectData[i].y-(obj.height/2)-14, appFont, 12 )
		obj.label:setFillColor( 0.8 )

		-- Add touch sensitivity to object
		obj:addEventListener( "touch", onTouch )
	end
end

local function init(observerData, segmentData)
    renderObservers(display, mainGroup, observerData, onTouch)
    for i = 1, #segmentData do
        local segment = segmentData[i]
        display.newLine(mainGroup, segment.s.x, segment.s.y, segment.e.x, segment.e.y)
    end
end

function getClosestIntersection(observer, vertexX, vertexY)
    local closestIntersection = nil
    local closestDistance = 2000

    for i = 1, #segments do
        local intersection = pathtrace:getIntersection(
            {s = {x = observer.x, y = observer.y}, e = {x = vertexX, y = vertexY}},
            segments[i],
			observer
        )
        
        if intersection then
            local distance = math.sqrt(
                (observer.x - intersection.x) ^ 2 + (observer.y - intersection.y) ^ 2
            )
            if distance < closestDistance then
                closestIntersection = intersection
                closestDistance = distance
            end
        end
    end

    return closestIntersection
end

local function drawRay(display, group, observer, vertex)
    local closestIntersection = getClosestIntersection(observer, vertex.x, vertex.y)
    local endpoint
	local maxRange = 50
	
	local dx = vertex.x - observer.x
	local dy = vertex.y - observer.y
	local freeDistance = math.sqrt(dx * dx + dy * dy)

	if freeDistance > maxRange then
	    return
	end

	local idx = closestIntersection.x - observer.x
	local idy = closestIntersection.y - observer.y
	local blockDistance = math.sqrt(idx * idx + idy * idy)

	if blockDistance < maxRange and blockDistance < freeDistance then
		endpoint = {x = closestIntersection.x, y = closestIntersection.y}
	else 
		-- into open space, and more than range
		if freeDistance > maxRange then
			local scaleFactor = maxRange / freeDistance
			endpoint = {
				x = observer.x + dx * scaleFactor,
				y = observer.y + dy * scaleFactor
			}
		else
			endpoint = vertex
		end
	end

	display.newLine(group, observer.x, observer.y, endpoint.x, endpoint.y)    
end


function drawObserverRays(display, group, observer, segmentVertices)
	for i = 1, #segmentVertices do
		drawRay(display, group, observer, segmentVertices[i])
	end
end

function getSegmentVertices(segmentData)
	local segmentVertices = {}
	for _, segment in ipairs(segments) do
		table.insert(segmentVertices, {x = segment.s.x, y = segment.s.y})
		table.insert(segmentVertices, {x = segment.e.x, y = segment.e.y})
	end
	return segmentVertices
end

init(observers, segments)

segmentVertices = getSegmentVertices(segments)

drawObserverRays(display, rayGroup, observers[1], segmentVertices)
