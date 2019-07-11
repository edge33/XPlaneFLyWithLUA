-- FSE_HUD
-- TOGFox
-- Thanks to Teddii on the FSEconomy forums for the inspiration to write this HUD
-- For support: post on x-plane.org

-- v0.01
-- v0.02
-- v0.03
--		Corrected 'end flight' bug
-- v0.04
--		Auto-end flight works better
-- v0.05
--		Added a hot-spot marker to guide the mouse.
-- v0.06
--		Redesigned the GUI
-- v0.07
--		Re-introduced flight time and fuel used
--v0.08
--		Added some automation - fixed the time/fuel used

-- Requires tf_common_functions v0.02 or later

local bolShowHotSpot = 1	--Change this to zero if you don't like the marker
local intHudXStart = 15		--This can be changed
local intHudYStart = 575	--This can be changed
-- ---------------------------------------------------------------------

local intButtonHeight = 30			--the clickable 'panels' are called buttons
local intButtonWidth = 140			--the clickable 'panels' are called buttons
local intHeadingHeight = 20
local intFrameBorderSize = 5
local fltTransparency = 0.10		--alpha value for the boxes

--These help draw the status panel
local fltFlightStartTimeSeconds = os.clock() --tracks time at start of flight
local fltFuelStartWeightKGs = 0		--tracks fuel weight at start of flight
local fltFlightTimeSeconds = 0		--what gets displayed on screen
local fltFuelUsedOnFlightKGs = 0	--what gets displayed on screen

local bolCancelArmed = 0			--0 = cancel button is not armed. 1 = cancel button is armed
local bolDeparted = 0				--0 = not yet departed from originating airport. Used for automation

require "graphics"
require "tf_common_functions"

local ACTION_NONE = 0			--no action
local ACTION_VOICEONLY = 1		--voice alert
local ACTION_TEXTANDVOICE = 2	--text and voice
local ACTION_AUTORESOLVE = 3	--auto-resolve
local ACTION_TEXTONLY = 4		--text alert

local intActionTypeConnect = ACTION_AUTORESOLVE
local intActionTypeRegisterFlight = ACTION_AUTORESOLVE
local intActionTypeEndflight = ACTION_AUTORESOLVE

local bolLoginAlertRaised = 0	--to ensure alerts aren't raised more than once
local bolFlightRegisteredAlertRaised = 0
local bolFlightNotEndedAlertRaised = 0

local fltTimerForEndFlight = 10	--wait this many seconds before auto-ending a flight
local fltBeginLandedTimer = 0	--the time at landing

dataref("fltCurrentFuelWeightKGs" ,"sim/flightmodel/weight/m_fuel_total")
dataref("fse_connected", "fse/status/connected")
dataref("fse_flying", "fse/status/flying")
dataref("bolOnTheGround", "sim/flightmodel/failures/onground_any")
dataref("datGSpd", "sim/flightmodel/position/groundspeed")

function tfFSE_DrawOutsidePanel()
	--Draws the overall box
	local x1 = intHudXStart
	local y1 = intHudYStart
	local x2 = x1 + intFrameBorderSize + intButtonWidth + intButtonWidth + intFrameBorderSize
	local y2 = y1 + intFrameBorderSize + intButtonHeight + intButtonHeight + intHeadingHeight + intFrameBorderSize
	
	graphics.set_color(1, 1, 1, fltTransparency) --white
	graphics.draw_rectangle(x1,y1,x2,y2)
end

function tfFSE_DrawInsidePanel()
	--Draws the inside panel
	local x1 = intHudXStart + intFrameBorderSize
	local y1 = intHudYStart + intFrameBorderSize
	local x2 = x1 + intButtonWidth + intButtonWidth
	local y2 = y1 + intButtonHeight + intButtonHeight + intHeadingHeight

	graphics.set_color(1, 1, 1, fltTransparency) --white
	graphics.draw_rectangle(x1,y1,x2,y2)
end

function tfFSE_DrawHeadingPanel()
	--Draws the heading panel and text at the top of the inside panel
	local x1 = intHudXStart + intFrameBorderSize
	local y1 = intHudYStart + intFrameBorderSize + intButtonHeight + intButtonHeight
	local x2 = x1 + intButtonWidth + intButtonWidth
	local y2 = y1 + intHeadingHeight
	
	graphics.draw_string((x1 + (intButtonWidth * 0.85)),(y1 + (intButtonHeight * 0.25)), "FSE HUD", "white")
	
	graphics.set_color(1, 1, 1, fltTransparency) --white
	graphics.draw_rectangle(x1,y1,x2,y2)	
end

function tfFSE_DrawStatusPanel()
	--Draw the status panel that displays flight time and fuel used
	--Note to me: this method doesn't work when ground acel is used. Suggest finding a dataref that displays flight time.
	local x1 = intHudXStart + intFrameBorderSize
	local y1 = intHudYStart + intFrameBorderSize
	local x2 = x1 + intButtonWidth + intButtonWidth
	local y2 = y1 + intButtonHeight
	local strTemp
	
	--print(fltFuelUsedOnFlightKGs .. ";" .. fltFuelStartWeightKGs ..";" ..fltCurrentFuelWeightKGs)
	--Work out what the panel values are
	if fse_flying == 1 then
		fltFlightTimeSeconds = os.clock() - fltFlightStartTimeSeconds
		
		--This bit is a hack. The fuel is suppose to sync when you start flight but there is a timing problem so we do it here as well
		if fltFlightTimeSeconds > 0 and fltFlightTimeSeconds < 5 then
			fltFuelStartWeightKGs = fltCurrentFuelWeightKGs
		end
		
		fltFuelUsedOnFlightKGs = tf_common_functions.round((fltFuelStartWeightKGs - fltCurrentFuelWeightKGs), 1)
		if fltFuelUsedOnFlightKGs < 0 then 
			fltFuelUsedOnFlightKGs = 0 
		end
	end
	
	strTemp = "Flight time: " ..  tf_common_functions.tf_SecondsToClockFormat(fltFlightTimeSeconds)
	graphics.draw_string(x1 + (intButtonWidth * 0.05),y1 + (intButtonHeight * 0.6),strTemp,"white")
	
	local fltFuelUsedOnFlightGALs = tf_common_functions.round((fltFuelUsedOnFlightKGs * 0.2642),1)
	strTemp = "Fuel used: " .. fltFuelUsedOnFlightKGs .. " KGs / " .. fltFuelUsedOnFlightGALs .. " gals"
	graphics.draw_string(x1 + (intButtonWidth * 0.05), y1 + (intButtonHeight * 0.2), strTemp, "white")	
	
	graphics.set_color(1, 1, 1, fltTransparency) --white
	graphics.draw_rectangle(x1,y1,x2,y2)
	
	--print(fltFlightStartTimeSeconds .. ";" .. fse_flighttime)
	
end

function tfFSE_DrawCorner()
	--Draw one corner of the HUD so people know where to put the mouse_over
	graphics.set_color(0,0,0,0.75)	--black
	
	--draw the vertical line
	local x1 = intHudXStart
	local y1 = intHudYStart + intFrameBorderSize + intButtonHeight + intButtonHeight
	local x2 = x1
	local y2 = y1 + intHeadingHeight + intFrameBorderSize
	graphics.draw_line(x1,y1,x2,y2)
	
	--draw the horizontal line
	--x1 = x1		--no change
	y1 = y2
	x2 = x1 + intButtonWidth * 0.25
	y2 = y1
	graphics.draw_line(x1,y1,x2,y2)
end

function tfFSE_DrawAlphaState()
	--Alpha state = not connected to FSE
	local x1 = intHudXStart + intFrameBorderSize
	local y1 = intHudYStart + intFrameBorderSize + intButtonHeight
	local x2 = x1 + intButtonWidth + intButtonWidth
	local y2 = y1 + intButtonHeight
	
	graphics.draw_string(x1 + (intButtonWidth * 0.15), y1 + (intButtonHeight * 0.4), "Click to connect", "white")
	
	graphics.set_color( 0, 1, 0, fltTransparency) --green
	graphics.draw_rectangle(x1,y1,x2,y2)
	
	--draw button outline
	graphics.set_color(0,0,0,0.5)	--black
	graphics.draw_line(x1,y1,x2,y1)
	graphics.draw_line(x2,y1,x2,y2)
	graphics.draw_line(x2,y2,x1,y2)
	graphics.draw_line(x1,y2,x1,y1)
end

function tfFSE_DrawBetaState()
	--Beta state = connected but not enroute
	local x1 = intHudXStart + intFrameBorderSize
	local y1 = intHudYStart + intFrameBorderSize + intButtonHeight
	local x2 = x1 + intButtonWidth + intButtonWidth
	local y2 = y1 + intButtonHeight
	
	graphics.draw_string(x1 + (intButtonWidth * 0.15), y1 + (intButtonHeight * 0.4), "Click to register flight", "white")
	
	graphics.set_color( 0, 1, 0, fltTransparency) --green
	graphics.draw_rectangle(x1,y1,x2,y2)
	
	--draw button outline
	graphics.set_color(0,0,0,0.5)	--black
	graphics.draw_line(x1,y1,x2,y1)
	graphics.draw_line(x2,y1,x2,y2)
	graphics.draw_line(x2,y2,x1,y2)
	graphics.draw_line(x1,y2,x1,y1)
end

function tfFSE_DrawCharlieState()
	--Charlie state = flight in progress (cancel not armed)
	
	--There are two buttons side by side in this state
	local x1 = intHudXStart + intFrameBorderSize
	local y1 = intHudYStart + intFrameBorderSize + intButtonHeight
	local x2 = x1 + intButtonWidth
	local y2 = y1 + intButtonHeight
	
	graphics.draw_string(x1 + (intButtonWidth * 0.15), y1 + (intButtonHeight * 0.4), "Flight in progress", "white")
	
	graphics.set_color(1, 1, 1, fltTransparency) --white
	graphics.draw_rectangle(x1,y1,x2,y2)	
	
	--draw button outline
	graphics.set_color(0,0,0,0.5)	--black
	graphics.draw_line(x1,y1,x2,y1)
	graphics.draw_line(x2,y1,x2,y2)
	graphics.draw_line(x2,y2,x1,y2)
	graphics.draw_line(x1,y2,x1,y1)
	
	--Draw the second button
	x1 = x2
	--y1 = y1		--y1 doesn't change value
	x2 = x1 + intButtonWidth
	y2 = y1 + intButtonHeight	
	
	graphics.draw_string(x1 + (intButtonWidth * 0.1), y1 + (intButtonHeight * 0.4), "Click to cancel flight", "white")
	
	graphics.set_color( 0, 1, 0, fltTransparency) --green
	graphics.draw_rectangle(x1,y1,x2,y2)

	--draw button outline
	graphics.set_color(0,0,0,0.5)	--black
	graphics.draw_line(x1,y1,x2,y1)
	graphics.draw_line(x2,y1,x2,y2)
	graphics.draw_line(x2,y2,x1,y2)
	graphics.draw_line(x1,y2,x1,y1)	

	
end

function tfFSE_DrawDeltaState()
	--Delta state = flight in progress (cancel is armed)

	--There are two buttons side by side in this state
	local x1 = intHudXStart + intFrameBorderSize
	local y1 = intHudYStart + intFrameBorderSize + intButtonHeight
	local x2 = x1 + intButtonWidth
	local y2 = y1 + intButtonHeight
	
	graphics.draw_string(x1 + (intButtonWidth * 0.15), y1 + (intButtonHeight * 0.4), "Really cancel?", "white")
	
	graphics.set_color(1, 1, 0, fltTransparency) --yellow
	graphics.draw_rectangle(x1,y1,x2,y2)

	--draw button outline
	graphics.set_color(0,0,0,0.5)	--black
	graphics.draw_line(x1,y1,x2,y1)
	graphics.draw_line(x2,y1,x2,y2)
	graphics.draw_line(x2,y2,x1,y2)
	graphics.draw_line(x1,y2,x1,y1)	
	
	--Draw the second button
	x1 = x2
	--y1 = y1		--y1 doesn't change value
	x2 = x1 + intButtonWidth
	y2 = y1 + intButtonHeight	
	
	graphics.draw_string(x1 + (intButtonWidth * 0.15), y1 + (intButtonHeight * 0.4), "Click to un-cancel", "white")
	
	graphics.set_color( 0, 1, 0, fltTransparency) --green
	graphics.draw_rectangle(x1,y1,x2,y2)	

	--draw button outline
	graphics.set_color(0,0,0,0.5)	--black
	graphics.draw_line(x1,y1,x2,y1)
	graphics.draw_line(x2,y1,x2,y2)
	graphics.draw_line(x2,y2,x1,y2)
	graphics.draw_line(x1,y2,x1,y1)	
end

function tfFSE_DrawEchoState()
	--Echo state = flight in progress but stopped on the ground (ready to end flight)
	
	--There are two buttons side by side in this state
	local x1 = intHudXStart + intFrameBorderSize
	local y1 = intHudYStart + intFrameBorderSize + intButtonHeight
	local x2 = x1 + intButtonWidth
	local y2 = y1 + intButtonHeight
	
	graphics.draw_string(x1 + (intButtonWidth * 0.05), y1 + (intButtonHeight * 0.4), "Click to end flight", "white")
	
	graphics.set_color( 0, 1, 0, fltTransparency) --green
	graphics.draw_rectangle(x1,y1,x2,y2)	
	
	--draw button outline
	graphics.set_color(0,0,0,0.5)	--black
	graphics.draw_line(x1,y1,x2,y1)
	graphics.draw_line(x2,y1,x2,y2)
	graphics.draw_line(x2,y2,x1,y2)
	graphics.draw_line(x1,y2,x1,y1)
	
	--Draw the second button
	x1 = x2
	--y1 = y1		--y1 doesn't change value
	x2 = x1 + intButtonWidth
	y2 = y1 + intButtonHeight	
	
	graphics.draw_string(x1 + (intButtonWidth * 0.05), y1 + (intButtonHeight * 0.4), "Click to cancel flight", "white")
	
	graphics.set_color( 0, 1, 0, fltTransparency) --green
	graphics.draw_rectangle(x1,y1,x2,y2)

	--draw button outline
	graphics.set_color(0,0,0,0.5)	--black
	graphics.draw_line(x1,y1,x2,y1)
	graphics.draw_line(x2,y1,x2,y2)
	graphics.draw_line(x2,y2,x1,y2)
	graphics.draw_line(x1,y2,x1,y1)	
end

function tfFSE_DrawButtons()
	--Examines FSE and flight state to draw the correct buttons in the correct place.
	--There is a finite number of button states so are just hardcoded here
	
	if fse_connected == 0 then
		--fse_connected == 0
		tfFSE_DrawAlphaState()
	else
		if fse_flying == 0 then
			--fse_connected == 1
			--fse_flying == 0
			tfFSE_DrawBetaState()
		else
			if bolCancelArmed == 0 then
				if bolOnTheGround == 1 and datGSpd <= 5 and os.clock() >= fltBeginLandedTimer + 4 then
					--fse_connected == 1
					--fse_flying == 1
					--bolCancelArmed == 0
					--bolOnTheGround == 1
					--datGSpd <= 5
					--been stopped for at least 4 seconds
					tfFSE_DrawEchoState()
				else
					--fse_connected == 1
					--fse_flying == 1
					--bolCancelArmed == 0
					--bolOnTheGround == ?
					--datGSpd == ?
					tfFSE_DrawCharlieState()
				end
			else
				--fse_connected == 1
				--fse_flying == 1
				--bolCancelArmed == 1
				tfFSE_DrawDeltaState()
			end
		end
	end	
end
	
function tfFSE_DrawThings()

	XPLMSetGraphicsState(0,0,0,1,1,0,0)
	
	if bolShowHotSpot == 1 then
		tfFSE_DrawCorner()
	end
	
	--check for mouse over before drawing
	local x1 = intHudXStart
	local y1 = intHudYStart
	local x2 = x1 + intFrameBorderSize + intButtonWidth + intButtonWidth + intFrameBorderSize
	local y2 = y1 + intFrameBorderSize + intButtonHeight + intButtonHeight + intHeadingHeight + intFrameBorderSize	
	if MOUSE_X < x1 or MOUSE_X > x2 or MOUSE_Y < y1 or MOUSE_Y > y2 then
		--don't draw
	else
		tfFSE_DrawOutsidePanel()
		tfFSE_DrawInsidePanel()
		tfFSE_DrawHeadingPanel()
		tfFSE_DrawStatusPanel()
		tfFSE_DrawButtons()
	end
end	
	
function tfFSE_ConnectToServer()
	command_once("fse/server/connect")
	bolLoginAlertRaised = 0
end

function tfFSE_RegisterFlight()
	command_once("fse/flight/start")
	bolCancelArmed = 0
	fltFuelStartWeightKGs = fltCurrentFuelWeightKGs
	fltFlightStartTimeSeconds = os.clock()
	--print("reset")
end	
	
function tfFSE_CancelArm()
	--Arm the cancel
	command_once("fse/flight/cancelArm")
	bolCancelArmed = 1

end

function tfFSE_ReallyCancel()
	if bolCancelArmed == 1 then	--this is unnecessary but for safety
		command_once("fse/flight/cancelConfirm")
		bolCancelArmed = 0
	end
end
	
function tfFSE_EndFlight()
	command_once("fse/flight/finish")
	--print("Just called finish flight")
	
	if fse_flying == 0 then
		bolDeparted = 0
		bolCancelArmed = 0
		fltBeginLandedTimer = 0
	end
end	
	
function tfFSE_MouseClick()
	--process mouse click hot spots
	
	--check if button hot spot is clicked
	
	--alpha state
	local x1 = intHudXStart + intFrameBorderSize
	local y1 = intHudYStart + intFrameBorderSize + intButtonHeight
	local x2 = x1 + intButtonWidth + intButtonWidth
	local y2 = y1 + intButtonHeight
	
	--print (fse_flying .. ";" .. bolCancelArmed .. ";" .. bolOnTheGround .. ";" .. datGSpd)
	
	if MOUSE_X >= x1 and MOUSE_X <= x2 and MOUSE_Y >= y1 and MOUSE_Y < y2 then
		if fse_connected == 0 then
			--Alpha state
			--try to log in
			tfFSE_ConnectToServer()
			return
		end
		
		if fse_connected == 1 and fse_flying == 0 then
			--Beta state
			tfFSE_RegisterFlight()
			return
		end
		
		--The buttons get small for Charlie, Delta and Echo state - so need more granularity
		x1 = intHudXStart + intFrameBorderSize
		y1 = intHudYStart + intFrameBorderSize + intButtonHeight
		x2 = x1 + intButtonWidth
		y2 = y1 + intButtonHeight
		
		--print(x1 .. ";" .. y1 .. ";" .. x2 .. ";" .. y2)
		--print(MOUSE_X ..";" .. MOUSE_Y)

		--check if left button is clicked
		if MOUSE_X >= x1 and MOUSE_X <= x2 and MOUSE_Y >= y1 and MOUSE_Y < y2 then
		
				--print("alpha")
		
				--The left button has been clicked
				if (fse_flying == 1 and bolCancelArmed == 0) and (bolOnTheGround == 0 or datGSpd > 5) then
					--This button is disabled. Do nothing
					--print("beta")
					return
				end
				
				if fse_flying == 1 and bolCancelArmed == 1 then
					--Really Cancel has been clicked
					tfFSE_ReallyCancel()
					--print("Charle")
					return
				end
				
				if fse_flying == 1 and bolCancelArmed == 0 and bolOnTheGround == 1 and datGSpd <= 5 and os.clock() >= fltBeginLandedTimer + 4 then
					--End flight has been clicked
					--print("Trying to end flight")
					tfFSE_EndFlight()
					return
				end
		end
		
		--The bit above is the left button
		--This bit is the right button
		x1 = x2
		--y1 = y1		--y1 doesn't change value
		x2 = x1 + intButtonWidth
		y2 = y1 + intButtonHeight			
		if MOUSE_X >= x1 and MOUSE_X <= x2 and MOUSE_Y >= y1 and MOUSE_Y < y2 then
			if fse_flying == 1 and bolCancelArmed == 0 then
				--Charle state
				--Cancel is armed
				tfFSE_CancelArm()
				return
			end
			
			if fse_flying == 1 and bolCancelArmed == 1 then
				--Deta state
				--un-cancel flight
				bolCancelArmed = 0
				return
			end
		end
	end
end	
	
function tfFSE_Automation()	
	--detect key events and react according to the action settings specified by the user
	
	--if taxiing and not logged in then check if there needs to be an action
	if datGSpd > 5 and fse_connected == 0 and bolLoginAlertRaised == 0 then
		if intActionTypeConnect == ACTION_NONE then
			--do nothing
		elseif intActionTypeLogin == ACTION_TEXTONLY then
			--display a text warning
		
			-- ## TODO: how to display a string outside a do_every_draw event?
			
		elseif intActionTypeConnect == ACTION_VOICEONLY then
			--audible only
			--speakNoText("Not logged into FSE") 
		elseif intActionTypeConnect == ACTION_TEXTANDVOICE then
			--text and audible
			XPLMSpeakString("Not logged into FSE")
		elseif intActionTypeConnect == ACTION_AUTORESOLVE then
			--auto-resolve
			tfFSE_ConnectToServer()
		end
		
		bolLoginAlertRaised = 1	--this prevents the alert being raised multiple times
			
	end
	
	--if taking off and not registered flight then check if there needs to be an action
	if bolOnTheGround == 0 and fse_flying == 0 and bolFlightRegisteredAlertRaised == 0 and fse_connected == 1 then
		if intActionTypeRegisterFlight == ACTION_NONE then
			--do nothing
		elseif intActionTypeRegisterFlight == ACTION_TEXTONLY then
			--display a text warning
		
			-- ## TODO: how to display a string outside a do_every_draw event?
			
		elseif intActionTypeRegisterFlight == ACTION_VOICEONLY then
			--audible only
			--speakNoText("Flight not registered with FSE") 
		elseif intActionTypeRegisterFlight == ACTION_TEXTANDVOICE then
			--text and audible
			XPLMSpeakString("Flight not registered with FSE")
		elseif intActionTypeRegisterFlight == ACTION_AUTORESOLVE then
			--auto-resolve
			tfFSE_RegisterFlight()
		end

		bolFlightRegisteredAlertRaised = 1  --this prevents the alert being raised multiple times
	end
	
	--if landed then check if there needs to be an action
	--print("end: " .. bolOnTheGround .. ";" .. datGSpd .. ";" .. fse_flying .. ";" .. bolDeparted .. ":" .. bolFlightNotEndedAlertRaised)
	if bolOnTheGround == 1 and datGSpd < 5 and fse_flying == 1 and bolDeparted == 1 and bolFlightNotEndedAlertRaised == 0 then
		if fltBeginLandedTimer == 0 then	--if timer is not started then start the timer.
			fltBeginLandedTimer = os.clock()
		end
		
		if os.clock() > fltBeginLandedTimer + fltTimerForEndFlight then
			--try to end flight

			--## Need to build in a 15 second timer to give the pilot to end flight manually
			if intActionTypeEndflight == ACTION_NONE then
				--do nothing
			elseif intActionTypeEndflight == ACTION_TEXTONLY then
				--display a text warning
			
				-- ## TODO: how to display a string outside a do_every_draw event?
				
			elseif intActionTypeEndflight == ACTION_VOICEONLY then
				--audible only
				--speakNoText("Flight not ended") 
			elseif intActionTypeEndflight == ACTION_TEXTANDVOICE then
				--text and audible
				XPLMSpeakString("Flight not ended")
			else
				--auto-resolve
				--print("trying to end flight")
				tfFSE_EndFlight()
			end
			bolFlightNotEndedAlertRaised = 1  --this prevents the alert being raised multiple times	
		end
		

	end	
	
	--capture if plane has taken off
	--print("bodeparted = " .. bolDeparted)
	if bolOnTheGround == 0 and bolDeparted == 0 then
		bolDeparted = 1
	end
	
end
	
do_every_draw("tfFSE_DrawThings()")
do_on_mouse_click("tfFSE_MouseClick()")
do_sometimes("tfFSE_Automation()")
	
	
	
	
	