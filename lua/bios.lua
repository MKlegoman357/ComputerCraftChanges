
-- Install fix for luaj's broken string.sub/string.find
local nativestringfind = string.find
local nativestringsub = string.sub
local nativepcall = pcall
function string.sub( ... )
    local ok, r = nativepcall( nativestringsub, ... )
    if ok then
        if r then
            return r .. ""
        end
        return nil
    else
        error( r, 2 )
    end
end
function string.find( s, ... )
    return nativestringfind( s .. "", ... );
end

-- Install lua parts of the os api
function os.version()
    return "CraftOS 1.7"
end

function os.pullEventRaw( sFilter )
    return coroutine.yield( sFilter )
end

function os.pullEvent( sFilter )
    local eventData = { os.pullEventRaw( sFilter ) }
    if eventData[1] == "terminate" then
        error( "Terminated", 0 )
    end
    return unpack( eventData )
end

-- Install globals
function sleep( nTime )
    local timer = os.startTimer( nTime or 0 )
    repeat
        local sEvent, param = os.pullEvent( "timer" )
    until param == timer
end

function write( sText )
    local w,h = term.getSize()        
    local x,y = term.getCursorPos()
    
    local nLinesPrinted = 0
    local function newLine()
        if y + 1 <= h then
            term.setCursorPos(1, y + 1)
        else
            term.setCursorPos(1, h)
            term.scroll(1)
        end
        x, y = term.getCursorPos()
        nLinesPrinted = nLinesPrinted + 1
    end
    
    -- Print the line with proper word wrapping
    while string.len(sText) > 0 do
        local whitespace = string.match( sText, "^[ \t]+" )
        if whitespace then
            -- Print whitespace
            term.write( whitespace )
            x,y = term.getCursorPos()
            sText = string.sub( sText, string.len(whitespace) + 1 )
        end
        
        local newline = string.match( sText, "^\n" )
        if newline then
            -- Print newlines
            newLine()
            sText = string.sub( sText, 2 )
        end
        
        local text = string.match( sText, "^[^ \t\n]+" )
        if text then
            sText = string.sub( sText, string.len(text) + 1 )
            if string.len(text) > w then
                -- Print a multiline word                
                while string.len( text ) > 0 do
                    if x > w then
                        newLine()
                    end
                    term.write( text )
                    text = string.sub( text, (w-x) + 2 )
                    x,y = term.getCursorPos()
                end
            else
                -- Print a word normally
                if x + string.len(text) - 1 > w then
                    newLine()
                end
                term.write( text )
                x,y = term.getCursorPos()
            end
        end
    end
    
    return nLinesPrinted
end

function print( ... )
    local nLinesPrinted = 0
    for n,v in ipairs( { ... } ) do
        nLinesPrinted = nLinesPrinted + write( tostring( v ) )
    end
    nLinesPrinted = nLinesPrinted + write( "\n" )
    return nLinesPrinted
end

function printError( ... )
    if term.isColour() then
        term.setTextColour( colours.red )
    end
    local x,y = term.getCursorPos()
    print( ... )
    term.setTextColour( colours.white )
end

function read( _sReplaceChar, _tHistory, _fnComplete )
    term.setCursorBlink( true )

    local sLine = ""
    local nHistoryPos
    local nPos = 0
    if _sReplaceChar then
        _sReplaceChar = string.sub( _sReplaceChar, 1, 1 )
    end

    local tCompletions
    local nCompletion
    local function recomplete()
        if _fnComplete and nPos == string.len(sLine) then
            tCompletions = _fnComplete( sLine )
            if tCompletions and #tCompletions > 0 then
                nCompletion = 1
            else
                nCompletion = nil
            end
        else
            tCompletions = nil
            nCompletion = nil
        end
    end

    local w = term.getSize()
    local sx = term.getCursorPos()

    local function redraw( _bClear )
        local nScroll = 0
        if sx + nPos >= w then
            nScroll = (sx + nPos) - w
        end

        local cx,cy = term.getCursorPos()
        term.setCursorPos( sx, cy )
        local sReplace = (_bClear and " ") or _sReplaceChar
        if sReplace then
            term.write( string.rep( sReplace, math.max( string.len(sLine) - nScroll, 0 ) ) )
        else
            term.write( string.sub( sLine, nScroll + 1 ) )
        end

        if nCompletion then
            local sCompletion = tCompletions[ nCompletion ]
            local oldText, oldBg
            if not _bClear then
                oldText = term.getTextColor()
                oldBg = term.getBackgroundColor()
                term.setTextColor( colours.white )
                term.setBackgroundColor( colours.grey )
            end
            if sReplace then
                term.write( string.rep( sReplace, string.len( sCompletion ) ) )
            else
                term.write( sCompletion )
            end
            if not _bClear then
                term.setTextColor( oldText )
                term.setBackgroundColor( oldBg )
            end
        end

        term.setCursorPos( sx + nPos - nScroll, cy )
    end
    
    local function clear()
        redraw( true )
    end

    recomplete()
    redraw()

    local function acceptCompletion()
        if nCompletion then
            -- Clear
            clear()

            -- Find the common prefix of all the other suggestions which start with the same letter as the current one
            local sCompletion = tCompletions[ nCompletion ]
            local sFirstLetter = string.sub( sCompletion, 1, 1 )
            local sCommonPrefix = sCompletion
            for n=1,#tCompletions do
                local sResult = tCompletions[n]
                if n ~= nCompletion and string.find( sResult, sFirstLetter, 1, true ) == 1 then
                    while #sCommonPrefix > 1 do
                        if string.find( sResult, sCommonPrefix, 1, true ) == 1 then
                            break
                        else
                            sCommonPrefix = string.sub( sCommonPrefix, 1, #sCommonPrefix - 1 )
                        end
                    end
                end
            end

            -- Append this string
            sLine = sLine .. sCommonPrefix
            nPos = string.len( sLine )
            recomplete()
            redraw()
        end
    end
    while true do
        local sEvent, param = os.pullEvent()
        if sEvent == "char" then
            -- Typed key
            clear()
            sLine = string.sub( sLine, 1, nPos ) .. param .. string.sub( sLine, nPos + 1 )
            nPos = nPos + 1
            recomplete()
            redraw()

        elseif sEvent == "paste" then
            -- Pasted text
            clear()
            sLine = string.sub( sLine, 1, nPos ) .. param .. string.sub( sLine, nPos + 1 )
            nPos = nPos + string.len( param )
            recomplete()
            redraw()

        elseif sEvent == "key" then
            if param == keys.enter then
                -- Enter
                if nCompletion then
                    clear()
                    tCompletions = nil
                    nCompletion = nil
                    redraw()
                end
                break
                
            elseif param == keys.left then
                -- Left
                if nPos > 0 then
                    clear()
                    nPos = nPos - 1
                    recomplete()
                    redraw()
                end
                
            elseif param == keys.right then
                -- Right                
                if nPos < string.len(sLine) then
                    -- Move right
                    clear()
                    nPos = nPos + 1
                    recomplete()
                    redraw()
                else
                    -- Accept autocomplete
                    acceptCompletion()
                end

            elseif param == keys.up or param == keys.down then
                -- Up or down
                if nCompletion then
                    -- Cycle completions
                    clear()
                    if param == keys.up then
                        nCompletion = nCompletion - 1
                        if nCompletion < 1 then
                            nCompletion = #tCompletions
                        end
                    elseif param == keys.down then
                        nCompletion = nCompletion + 1
                        if nCompletion > #tCompletions then
                            nCompletion = 1
                        end
                    end
                    redraw()

                elseif _tHistory then
                    -- Cycle history
                    clear()
                    if param == keys.up then
                        -- Up
                        if nHistoryPos == nil then
                            if #_tHistory > 0 then
                                nHistoryPos = #_tHistory
                            end
                        elseif nHistoryPos > 1 then
                            nHistoryPos = nHistoryPos - 1
                        end
                    else
                        -- Down
                        if nHistoryPos == #_tHistory then
                            nHistoryPos = nil
                        elseif nHistoryPos ~= nil then
                            nHistoryPos = nHistoryPos + 1
                        end                        
                    end
                    if nHistoryPos then
                        sLine = _tHistory[nHistoryPos]
                        nPos = string.len( sLine ) 
                    else
                        sLine = ""
                        nPos = 0
                    end
                    recomplete()
                    redraw()

                end

            elseif param == keys.backspace then
                -- Backspace
                if nPos > 0 then
                    clear()
                    sLine = string.sub( sLine, 1, nPos - 1 ) .. string.sub( sLine, nPos + 1 )
                    nPos = nPos - 1
                    recomplete()
                    redraw()
                end

            elseif param == keys.home then
                -- Home
                if nPos > 0 then
                    clear()
                    nPos = 0
                    recomplete()
                    redraw()
                end

            elseif param == keys.delete then
                -- Delete
                if nPos < string.len(sLine) then
                    clear()
                    sLine = string.sub( sLine, 1, nPos ) .. string.sub( sLine, nPos + 2 )                
                    recomplete()
                    redraw()
                end

            elseif param == keys["end"] then
                -- End
                if nPos < string.len(sLine ) then
                    clear()
                    nPos = string.len(sLine)
                    recomplete()
                    redraw()
                end

            elseif param == keys.tab then
                -- Tab (accept autocomplete)
                acceptCompletion()

            end

        elseif sEvent == "term_resize" then
            -- Terminal resized
            w = term.getSize()
            redraw()

        end
    end

    local cx, cy = term.getCursorPos()
    term.setCursorBlink( false )
    term.setCursorPos( w + 1, cy )
    print()
    
    return sLine
end

loadfile = function( _sFile )
    local file = fs.open( _sFile, "r" )
    if file then
        local func, err = loadstring( file.readAll(), fs.getName( _sFile ) )
        file.close()
        return func, err
    end
    return nil, "File not found"
end

dofile = function( _sFile )
    local fnFile, e = loadfile( _sFile )
    if fnFile then
        setfenv( fnFile, getfenv(2) )
        return fnFile()
    else
        error( e, 2 )
    end
end

-- Install the rest of the OS api
function os.run( _tEnv, _sPath, ... )
    local tArgs = { ... }
    local fnFile, err = loadfile( _sPath )
    if fnFile then
        local tEnv = _tEnv
        setmetatable( tEnv, { __index = _G } )
        setfenv( fnFile, tEnv )
        local ok, err = pcall( function()
            fnFile( unpack( tArgs ) )
        end )
        if not ok then
            if err and err ~= "" then
                printError( err )
            end
            return false
        end
        return true
    end
    if err and err ~= "" then
        printError( err )
    end
    return false
end

-- Prevent access to metatables or environments of strings, as these are global between all computers
do
    local nativegetfenv = getfenv
    local nativegetmetatable = getmetatable
    local nativeerror = error
    local nativetype = type
    local string_metatable = nativegetmetatable("")
    local string_env = nativegetfenv(("").gsub)
    function getmetatable( t )
        local mt = nativegetmetatable( t )
        if mt == string_metatable or mt == string_env then
            nativeerror( "Attempt to access string metatable", 2 )
        else
            return mt
        end
    end
    function getfenv( env )
        if env == nil then
            env = 2
        elseif nativetype( env ) == "number" and env > 0 then
            env = env + 1
        end
        local fenv = nativegetfenv(env)
        if fenv == string_metatable or fenv == string_env then
            --nativeerror( "Attempt to access string metatable", 2 )
            return nativegetfenv( 0 )
        else
            return fenv
        end
    end
end

local tAPIsLoading = {}
function os.loadAPI( _sPath )
    local sName = fs.getName( _sPath )
    if tAPIsLoading[sName] == true then
        printError( "API "..sName.." is already being loaded" )
        return false
    end
    tAPIsLoading[sName] = true
        
    local tEnv = {}
    setmetatable( tEnv, { __index = _G } )
    local fnAPI, err = loadfile( _sPath )
    if fnAPI then
        setfenv( fnAPI, tEnv )
        local ok, err = pcall( fnAPI )
        if not ok then
            printError( err )
            tAPIsLoading[sName] = nil
            return false
        end
    else
        printError( err )
        tAPIsLoading[sName] = nil
        return false
    end
    
    local tAPI = {}
    for k,v in pairs( tEnv ) do
        tAPI[k] =  v
    end
    
    _G[sName] = tAPI    
    tAPIsLoading[sName] = nil
    return true
end

function os.unloadAPI( _sName )
    if _sName ~= "_G" and type(_G[_sName]) == "table" then
        _G[_sName] = nil
    end
end

function os.sleep( nTime )
    sleep( nTime )
end

local nativeShutdown = os.shutdown
function os.shutdown()
    nativeShutdown()
    while true do
        coroutine.yield()
    end
end

local nativeReboot = os.reboot
function os.reboot()
    nativeReboot()
    while true do
        coroutine.yield()
    end
end

-- Install the lua part of the HTTP api (if enabled)
if http then
    local nativeHTTPRequest = http.request

    local function wrapRequest( _url, _post, _headers )
        local ok, err = nativeHTTPRequest( _url, _post, _headers )
        if ok then
            while true do
                local event, param1, param2 = os.pullEvent()
                if event == "http_success" and param1 == _url then
                    return param2
                elseif event == "http_failure" and param1 == _url then
                    return nil, param2
                end
            end
        end
        return nil, err
    end
    
    http.get = function( _url, _headers )
        return wrapRequest( _url, nil, _headers )
    end

    http.post = function( _url, _post, _headers )
        return wrapRequest( _url, _post or "", _headers )
    end

    http.request = function( _url, _post, _headers )
        local ok, err = nativeHTTPRequest( _url, _post, _headers )
        if not ok then
            os.queueEvent( "http_failure", _url, err )
        end
        return ok, err
    end
end

-- Install the lua part of the FS api
local tEmpty = {}
function fs.complete( sPath, sLocation, bIncludeFiles, bIncludeDirs )
    bIncludeFiles = (bIncludeFiles ~= false)
    bIncludeDirs = (bIncludeDirs ~= false)
    local sDir = sLocation
    local nStart = 1
    local nSlash = string.find( sPath, "[/\\]", nStart )
    if nSlash == 1 then
        sDir = ""
        nStart = 2
    end
    local sName
    while not sName do
        local nSlash = string.find( sPath, "[/\\]", nStart )
        if nSlash then
            local sPart = string.sub( sPath, nStart, nSlash - 1 )
            sDir = fs.combine( sDir, sPart )
            nStart = nSlash + 1
        else
            sName = string.sub( sPath, nStart )
        end
    end

    if fs.isDir( sDir ) then
        local tResults = {}
        if bIncludeDirs and sPath == "" then
            table.insert( tResults, "." )
        end
        if sDir ~= "" then
            if sPath == "" then
                table.insert( tResults, (bIncludeDirs and "..") or "../" )
            elseif sPath == "." then
                table.insert( tResults, (bIncludeDirs and ".") or "./" )
            end
        end
        local tFiles = fs.list( sDir )
        for n=1,#tFiles do
            local sFile = tFiles[n]
            if #sFile >= #sName and string.sub( sFile, 1, #sName ) == sName then
                local bIsDir = fs.isDir( fs.combine( sDir, sFile ) )
                local sResult = string.sub( sFile, #sName + 1 )
                if bIsDir then
                    table.insert( tResults, sResult .. "/" )
                    if bIncludeDirs and #sResult > 0 then
                        table.insert( tResults, sResult )
                    end
                else
                    if bIncludeFiles and #sResult > 0 then
                        table.insert( tResults, sResult )
                    end
                end
            end
        end
        return tResults
    end
    return tEmpty
end


-- Load APIs
local bAPIError = false
local tApis = fs.list( "rom/apis" )
for n,sFile in ipairs( tApis ) do
    if string.sub( sFile, 1, 1 ) ~= "." then
        local sPath = fs.combine( "rom/apis", sFile )
        if not fs.isDir( sPath ) then
            if not os.loadAPI( sPath ) then
                bAPIError = true
            end
        end
    end
end

if turtle then
    -- Load turtle APIs
    local tApis = fs.list( "rom/apis/turtle" )
    for n,sFile in ipairs( tApis ) do
        if string.sub( sFile, 1, 1 ) ~= "." then
            local sPath = fs.combine( "rom/apis/turtle", sFile )
            if not fs.isDir( sPath ) then
                if not os.loadAPI( sPath ) then
                    bAPIError = true
                end
            end
        end
    end
end

if pocket and fs.isDir( "rom/apis/pocket" ) then
    -- Load pocket APIs
    local tApis = fs.list( "rom/apis/pocket" )
    for n,sFile in ipairs( tApis ) do
        if string.sub( sFile, 1, 1 ) ~= "." then
            local sPath = fs.combine( "rom/apis/pocket", sFile )
            if not fs.isDir( sPath ) then
                if not os.loadAPI( sPath ) then
                    bAPIError = true
                end
            end
        end
    end
end

if commands and fs.isDir( "rom/apis/command" ) then
    -- Load command APIs
    if os.loadAPI( "rom/apis/command/commands" ) then
        -- Add a special case-insensitive metatable to the commands api
        local tCaseInsensitiveMetatable = {
            __index = function( table, key )
                local value = rawget( table, key )
                if value ~= nil then
                    return value
                end
                if type(key) == "string" then
                    local value = rawget( table, string.lower(key) )
                    if value ~= nil then
                        return value
                    end
                end
                return nil
            end
        }
        setmetatable( commands, tCaseInsensitiveMetatable )
        setmetatable( commands.async, tCaseInsensitiveMetatable )

        -- Add global "exec" function
        exec = commands.exec
    else
        bAPIError = true
    end
end

if bAPIError then
    print( "Press any key to continue" )
    os.pullEvent( "key" )
    term.clear()
    term.setCursorPos( 1,1 )
end

-- Run the shell
local ok, err = pcall( function()
    parallel.waitForAny( 
        function()
            if term.isColour() then
                os.run( {}, "rom/programs/advanced/multishell" )
            else
                os.run( {}, "rom/programs/shell" )
            end
            os.run( {}, "rom/programs/shutdown" )
        end,
        function()
            rednet.run()
        end )
end )

-- If the shell errored, let the user read it.
term.redirect( term.native() )
if not ok then
    printError( err )
    pcall( function()
        term.setCursorBlink( false )
        print( "Press any key to continue" )
        os.pullEvent( "key" )
    end )
end

-- End
os.shutdown()
