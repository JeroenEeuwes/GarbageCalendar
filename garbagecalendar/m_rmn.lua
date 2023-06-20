-----------------------------------------------------------------------------------------------------------------
-- garbagecalendar module script: m_rmn.lua
----------------------------------------------------------------------------------------------------------------
ver = '20230620-1400'
websitemodule = 'm_rmn'
-- Link to WebSite: "https://21burgerportaal.mendixcloud.com/p/rmn/landing/"
--

-- Start Functions =========================================================================
-------------------------------------------------------
-- Do the actual update retrieving data from the website and processing it
function Perform_Update()
	-- function to process ThisYear and Lastyear JSON data
	function processdata(ophaaldata)
		local i = 0
		local pickuptimes = {}
      Print_logfile("ophaaldata records:"..(#ophaaldata or "??"))
		--[[
				[
				{
				  "year": 2023,
				  "month": 12,
				  "day": 13,
				  "collectionDate": "2023-12-11T00:00:00.000Z",
				  "fraction": "GFT",
				  "placementPeriod": "",
				  "placementDescription": "",
				  "uuid": "XXXGFT"
				},
			]]
		for i = 1, #ophaaldata do
			record = ophaaldata[i]
			if type(record) == 'table' then
				wnameType = record['fraction']
				web_garbagetype = record['fraction']
				web_garbagedate = record['collectionDate']
				-- first match for each Type we save the date to capture the first next dates
				-- get the long description from the JSON data
				Print_logfile(i .. ' web_garbagetype:' .. tostring(web_garbagetype) .. '   web_garbagedate:' .. tostring(web_garbagedate))
				local dateformat = '????????'
				-- Get days diff
				dateformat, daysdiffdev = genfuncs.GetDateFromInput(web_garbagedate, '(%d+)[-%s]+(%d+)[-%s]+(%d+)', {'yyyy', 'mm', 'dd'})
				if daysdiffdev == nil then
					Print_logfile('Invalid date from web for : ' .. web_garbagetype .. '   date:' .. web_garbagedate)
				end
				if (daysdiffdev >= 0) then
					pickuptimes[#pickuptimes + 1] = {}
					pickuptimes[#pickuptimes].garbagetype = web_garbagetype
					pickuptimes[#pickuptimes].garbagedate = dateformat
               pickuptimes[#pickuptimes].diff = daysdiffdev
				-- field to be used when WebData contains a description
				-- pickuptimes[#pickuptimes].wdesc = ....
				end
			end
		end
		Print_logfile('- Sorting records.' .. #pickuptimes)
		local eventcnt = 0
		for x = 0, 60, 1 do
			for mom in pairs(pickuptimes) do
				if pickuptimes[mom].diff == x then
					garbagedata[#garbagedata + 1] = {}
					garbagedata[#garbagedata].garbagetype = pickuptimes[mom].garbagetype
					garbagedata[#garbagedata].garbagedate = pickuptimes[mom].garbagedate
					-- field to be used when Web_Data contains a description
					garbagedata[#garbagedata].wdesc = pickuptimes[mom].wdesc
				end
			end
		end
	end
	--

	Print_logfile('---- web update ----------------------------------------------------------------------------')
	local Web_Data
	local thnr = Housenr .. Housenrsuf
	local refreshToken = ''
	local idToken = ''

	-- read previous found refresh token
   local tokenfilename = datafilepath .. 'garbagecalendar_' .. websitemodule .. '_refresh_token.txt'
	local ifile, ierr = io.open(tokenfilename, 'rb')
	if ifile and not ierr then
		refreshToken = ifile:read('*all')
		ifile:close()
	end

	--[[
		===============================================================================================
		from: https://github.com/xirixiz/homeassistant-afvalwijzer/issues/232#issuecomment-1498616173
		===============================================================================================
	]]
	-- ======================================================================
	-- Check if we already have received an refreshToken ...else create one
	if refreshToken == '' or refreshToken:len() < 200 then
		--[[
		--Step 1a: We need to register the app/device
			curl -X POST "https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=AIzaSyA6NkRqJypTfP-cjWzrZNFJzPUbBaGjOdk"
			Which will return a IDtoken (valid for one hour), and refresh token.
			{
			  "kind": "identitytoolkit#SignupNewUserResponse",
			  "idToken": "_IDTOKEN_",
			  "refreshToken": "_REFRESH_TOKEN_",
			  "expiresIn": "3600",
			  "localId": "XXXXXX"
			}
		]]
		--
		Web_Data = genfuncs.perform_webquery(' -X POST -H "Content-Length:0" "https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=AIzaSyA6NkRqJypTfP-cjWzrZNFJzPUbBaGjOdk"')
		jdata = JSON:decode(Web_Data)
		-- get idToken
		if type(jdata) ~= 'table' or not jdata.idToken then
			Print_logfile('### Error: Token not received, stopping execution.')
			return
		end
		--
		idToken = jdata.idToken
		refreshToken = jdata.refreshToken
		-- save refreshToken to file
		local file, err = io.open(tokenfilename, 'w')
		if not err then
			file:write(refreshToken)
			file:close()
		end
	else
		-- ======================================================================
		-- use previously created refreshToken to get the IDTOKEN
		-- ======================================================================
		--[[
		Step 1b: We can refresh our idToken with the refresh token (which will not expire)
			curl -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data 'grant_type=refresh_token&refresh_token=_REFRESH_TOKEN_' "https://securetoken.googleapis.com/v1/token?key=AIzaSyA6NkRqJypTfP-cjWzrZNFJzPUbBaGjOdk"
			Which will return a new IDtoken (valid for one hour), and refresh token.
				{
				  "access_token": "_IDTOKEN_",
				  "expires_in": "3600",
				  "token_type": "Bearer",
				  "refresh_token": "_REFRESH_TOKEN_",
				  "id_token": "_ID_TOKEN_",
				  "user_id": "XXX",
				  "project_id": "XXX"
				}
		]]
		Web_Data = genfuncs.perform_webquery(' -X POST -H "Content-Type: application/x-www-form-urlencoded" --data "grant_type=refresh_token&refresh_token=' .. refreshToken .. '" "https://securetoken.googleapis.com/v1/token?key=AIzaSyA6NkRqJypTfP-cjWzrZNFJzPUbBaGjOdk"')
		jdata = JSON:decode(Web_Data)
		-- get idToken
		if type(jdata) ~= 'table' or not jdata.id_token then
			Print_logfile('### Error: Token not received, stopping execution.')
			return
		end
		--
		idToken = jdata.id_token
	end

	Print_logfile('idToken:' .. (idToken or 'nil'))

	--[[
		Step 2: We can use the IDToken to retrieve a address ID by using the postal code and housenumber
			curl -H "authorization: _IDTOKEN_" "https://europe-west3-burgerportaal-production.cloudfunctions.net/exposed/organisations/138204213564933597/address?zipcode=1234AB&housenumber=1"
			[{"addressId":"_ADDRESSID_","zipcode":"1234AB","street":"Xtraat","city":"XCity","housenumber":1,"municipalityId":"XXX","latitude":XXXX,"longitude":XXXX}]

	]]
	Web_Data = genfuncs.perform_webquery(' -X GET -H "Content-Length:0" -H "authorization:' .. idToken .. '" "https://europe-west3-burgerportaal-production.cloudfunctions.net/exposed/organisations/138204213564933597/address?zipcode=' .. Zipcode:upper() .. '&housenumber=' .. thnr .. '"')
	jdata = JSON:decode(Web_Data)[1]
	-- get idToken
	if type(jdata) ~= 'table' or not jdata.addressId then
		Print_logfile('### Error: addressId not received, stopping execution.')
		return
	end
	--
	local addressId = jdata.addressId
	Print_logfile('addressId:' .. (addressId or 'nil'))

	--[[
		Step 3: We can use the IDToken and ADDRESSID to retrieve the calendar
			curl -H "authorization: _IDTOKEN_" https://europe-west3-burgerportaal-production.cloudfunctions.net/exposed/organisations/138204213564933597/address/_ADDRESSID_/calendar
			[
			  {
				 "year": 2023,
				 "month": 12,
				 "day": 13,
				 "collectionDate": "2023-12-11T00:00:00.000Z",
				 "fraction": "GFT",
				 "placementPeriod": "",
				 "placementDescription": "",
				 "uuid": "XXXGFT"
			  },
			  {
				 "year": 2023,
				 "month": 12,
				 "day": 19,
				 "collectionDate": "2023-12-14T00:00:00.000Z",
				 "fraction": "REST",
				 "placementPeriod": "",
				 "placementDescription": "",
				 "uuid": "XXXREST"
			  },
			............
			]
	]]
	Web_Data = genfuncs.perform_webquery(' -H "authorization: ' .. idToken .. '" https://europe-west3-burgerportaal-production.cloudfunctions.net/exposed/organisations/138204213564933597/address/' .. addressId .. '/calendar')
	-- get calendar information
	jdata = JSON:decode(Web_Data)
	-- get the ophaaldagen tabel for the coming scheduled pickups
	if type(jdata) ~= 'table' then
		Print_logfile('### Error: Empty Kalender found stopping execution.')
		return
	end
	-- process the data
	processdata(jdata)
end
-- End Functions =========================================================================

-- Start of logic ========================================================================
-- ================================================================================================
-- These activated fields will be checked for being defined and the script will end when one isn't
-- ===========================================Print_logfile((Datafile=====================================================
local chkfields = {
	'Zipcode',
	'Housenr',
	--	"Housenrsuf",
	'Datafile'
	--	"Hostname",
	--	"Street",
	--	"Companycode"
}
local param_err = 0
-- Check whether the required parameters are specified.
for key, value in pairs(chkfields) do
	if (_G[value] or '') == '' then
		param_err = param_err + 1
		Print_logfile('!!! ' .. value .. ' not specified!', 1)
	end
end
-- Get the web info when all required parameters are defined
if param_err == 0 then
	Perform_Update()
	Print_logfile('=> Write data to ' .. Datafile)
	table.save(garbagedata, Datafile)
else
	Print_logfile('!!! Webupdate cancelled due to misseng parameters!', 1)
end
