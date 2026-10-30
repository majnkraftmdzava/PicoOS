-- PicoOS Windows-Style Desktop Environment with Advanced Shell & System Control v3.2.0
local PicoOS = {}
PicoOS.version = "3.2.0"

-- Theme Configuration
PicoOS.theme = {
    desktopBg = colors.blue,
    taskbarBg = colors.gray,
    taskbarText = colors.white,
    startBtnBg = colors.lightGray,
    startBtnText = colors.black,
    accent = colors.cyan,
    windowBg = colors.black,
    windowHeader = colors.blue,
    windowHeaderInactive = colors.gray,
    windowText = colors.lightGray,
}

local activeWindow = nil
local draggingWindow = nil
local resizingWindow = nil
local dragOffsetX = 0
local dragOffsetY = 0
local startMenuOpen = false
local windows = {}
local icons = {}

-- ==========================================
-- BOOT SCREEN (Logo & Progress Bar)
-- ==========================================
function PicoOS.bootScreen()
    local w, h = term.getSize()
    term.setBackgroundColor(PicoOS.theme.desktopBg)
    term.clear()
    
    local logo = {
        "  ____  _           ___  ____  ",
        " |  _ \\(_) ___ ___ / _ \\/ ___| ",
        " | |_) | |/ __/ _ \\ | | \\___ \\ ",
        " |  __/| | (_| (_) | |_| |___) |",
        " |_|   |_|\\___\\___/ \\___/|____/ "
    }
    
    local logoY = math.floor(h / 2) - 4
    local logoX = math.floor((w - string.len(logo[1])) / 2)
    
    for i, line in ipairs(logo) do
        term.setCursorPos(logoX, logoY + i)
        term.setTextColor(colors.white)
        term.write(line)
    end
    
    local statusY = logoY + #logo + 2
    term.setCursorPos(math.floor(w / 2) - 10, statusY)
    term.setTextColor(colors.yellow)
    term.write("Starting PicoOS...")
    
    local barW = 26
    local barX = math.floor((w - barW) / 2)
    local barY = statusY + 2
    
    term.setCursorPos(barX, barY)
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", barW))
    
    local steps = {
        {1, "Loading kernel..."},
        {8, "Initializing drivers..."},
        {15, "Starting window manager..."},
        {22, "Connecting to network..."},
        {26, "Welcome to PicoOS!"}
    }
    
    local currentStep = 1
    for i = 1, barW do
        term.setCursorPos(barX, barY)
        term.setBackgroundColor(colors.cyan)
        term.write(string.rep(" ", i))
        
        if currentStep <= #steps and i >= steps[currentStep][1] then
            term.setCursorPos(math.floor(w / 2) - math.floor(string.len(steps[currentStep][2]) / 2), statusY)
            term.setBackgroundColor(PicoOS.theme.desktopBg)
            term.setTextColor(colors.yellow)
            term.write(string.rep(" ", 24))
            term.setCursorPos(math.floor(w / 2) - math.floor(string.len(steps[currentStep][2]) / 2), statusY)
            term.write(steps[currentStep][2])
            currentStep = currentStep + 1
        end
        
        os.sleep(0.04)
    end
    
    os.sleep(0.3)
end

-- Utility: Clear screen with desktop background
function PicoOS.drawDesktop()
    term.setBackgroundColor(PicoOS.theme.desktopBg)
    term.clear()
end

-- Draw Windows-style Bottom Taskbar
function PicoOS.drawTaskbar()
    local w, h = term.getSize()
    
    term.setCursorPos(1, h)
    term.setBackgroundColor(PicoOS.theme.taskbarBg)
    term.setTextColor(PicoOS.theme.taskbarText)
    term.clearLine()
    
    -- Start Button
    term.setBackgroundColor(PicoOS.theme.startBtnBg)
    term.setTextColor(PicoOS.theme.startBtnText)
    term.write(" Start ")
    
    -- Running windows in taskbar
    local x = 9
    for _, win in ipairs(windows) do
        term.setCursorPos(x, h)
        if win == activeWindow then
            term.setBackgroundColor(PicoOS.theme.accent)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.lightGray)
            term.setTextColor(colors.black)
        end
        term.write(" " .. win.title .. " ")
        x = x + string.len(win.title) + 3
    end
    
    -- Clock on the bottom right
    local timeStr = textutils.formatTime(os.time(), true)
    term.setCursorPos(w - string.len(timeStr) - 1, h)
    term.setBackgroundColor(PicoOS.theme.taskbarBg)
    term.setTextColor(PicoOS.theme.taskbarText)
    term.write(timeStr)
end

-- Desktop Icons Management
function PicoOS.registerIcon(id, label, x, y, onClick)
    table.insert(icons, {id = id, label = label, x = x, y = y, onClick = onClick})
end

function PicoOS.drawIcons()
    for _, icon in ipairs(icons) do
        term.setCursorPos(icon.x, icon.y)
        term.setBackgroundColor(PicoOS.theme.desktopBg)
        term.setTextColor(colors.yellow)
        term.write("[ ]")
        term.setCursorPos(icon.x, icon.y + 1)
        term.setTextColor(colors.white)
        term.write(icon.label)
    end
end

-- Windows Start Menu
function PicoOS.drawStartMenu()
    if not startMenuOpen then return end
    local w, h = term.getSize()
    local menuH = 8
    local menuY = h - menuH
    
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    
    for y = menuY, h - 1 do
        term.setCursorPos(1, y)
        term.write("                ")
    end
    
    term.setCursorPos(2, menuY)   term.write("=== PicoOS ===")
    term.setCursorPos(2, menuY+2) term.write("> Terminal")
    term.setCursorPos(2, menuY+3) term.write("> Notepad")
    term.setCursorPos(2, menuY+4) term.write("> Network Config")
    term.setCursorPos(2, menuY+5) term.write("> Messenger")
    term.setCursorPos(2, menuY+6) term.write("> Shutdown")
end

-- Window Construction Helper
local function createWindow(title, x, y, width, height, initFunc, renderFunc, eventFunc)
    local win = {
        title = title,
        x = x,
        y = y,
        w = width,
        h = height,
        render = renderFunc,
        handleEvent = eventFunc,
        data = {}
    }
    if initFunc then initFunc(win) end
    table.insert(windows, win)
    activeWindow = win
    return win
end

-- Render all open windows
function PicoOS.drawWindows()
    for _, win in ipairs(windows) do
        -- Window body background
        for row = 0, win.h - 1 do
            term.setCursorPos(win.x, win.y + row)
            term.setBackgroundColor(PicoOS.theme.windowBg)
            term.setTextColor(PicoOS.theme.windowText)
            term.write(string.rep(" ", win.w))
        end
        
        -- Window title bar
        term.setCursorPos(win.x, win.y)
        if win == activeWindow then
            term.setBackgroundColor(PicoOS.theme.windowHeader)
        else
            term.setBackgroundColor(colors.gray)
        end
        term.setTextColor(colors.white)
        
        local titleText = " " .. win.title
        local padding = win.w - string.len(titleText) - 3
        if padding < 0 then padding = 0 end
        term.write(titleText .. string.rep(" ", padding) .. "[X]")
        
        -- Resize handle in the bottom-right corner
        term.setCursorPos(win.x + win.w - 1, win.y + win.h - 1)
        term.setBackgroundColor(PicoOS.theme.windowBg)
        term.setTextColor(colors.yellow)
        term.write("\\")
        
        -- Render window contents
        if win.render then
            win.render(win)
        end
    end
end

-- ==========================================
-- 1. ADVANCED TERMINAL APPLICATION (Pro Shell)
-- ==========================================
local function createTerminalWindow()
    createWindow("Terminal", 4, 3, 44, 16, 
        function(win)
            win.data.history = {
                "PicoOS Pro Shell v3.2",
                "Type 'help' for advanced commands."
            }
            win.data.inputStr = ""
        end,
        function(win)
            local contentX = win.x + 1
            local contentY = win.y + 1
            local contentW = win.w - 2
            local contentH = win.h - 3
            
            local linesToShow = contentH - 1
            local startIdx = math.max(1, #win.data.history - linesToShow + 1)
            local currentY = contentY
            
            for i = startIdx, #win.data.history do
                term.setCursorPos(contentX, currentY)
                term.setTextColor(colors.lightGray)
                term.write(string.sub(win.data.history[i], 1, contentW))
                currentY = currentY + 1
            end
            
            term.setCursorPos(contentX, win.y + win.h - 2)
            term.setTextColor(colors.green)
            term.write("> " .. win.data.inputStr .. "_")
        end,
        function(win, event, param)
            local colorMap = {
                black = colors.black, blue = colors.blue, green = colors.green,
                cyan = colors.cyan, red = colors.red, purple = colors.purple,
                yellow = colors.yellow, gray = colors.gray, lightGray = colors.lightGray
            }

            if event == "char" then
                win.data.inputStr = win.data.inputStr .. param
            elseif event == "key" then
                if param == keys.backspace and string.len(win.data.inputStr) > 0 then
                    win.data.inputStr = string.sub(win.data.inputStr, 1, -2)
                elseif param == keys.enter then
                    local fullCmd = win.data.inputStr
                    table.insert(win.data.history, "> " .. fullCmd)
                    win.data.inputStr = ""
                    
                    local args = {}
                    for word in string.gmatch(fullCmd, "%S+") do
                        table.insert(args, word)
                    end
                    local cmd = args[1] and string.lower(args[1]) or ""
                    
                    if cmd == "clear" then
                        win.data.history = {}
                    elseif cmd == "help" then
                        table.insert(win.data.history, "--- PicoOS Pro Commands ---")
                        table.insert(win.data.history, " ls - List files/folders")
                        table.insert(win.data.history, " cat <file> - Read file")
                        table.insert(win.data.history, " mkdir <dir> - Create folder")
                        table.insert(win.data.history, " rm <path> - Delete file/dir")
                        table.insert(win.data.history, " theme <bg> <hdr> - Change colors")
                        table.insert(win.data.history, " ping <id> - Test network ID")
                        table.insert(win.data.history, " killall - Close all windows")
                        table.insert(win.data.history, " 67 - Big numbers art")
                        table.insert(win.data.history, " reboot / exit - Control")
                    elseif cmd == "ls" then
                        local files = fs.list("")
                        table.insert(win.data.history, "Directory content:")
                        for _, f in ipairs(files) do
                            local prefix = fs.isDir(f) and "[DIR] " or "      "
                            table.insert(win.data.history, prefix .. f)
                        end
                    elseif cmd == "cat" then
                        if args[2] then
                            if fs.exists(args[2]) and not fs.isDir(args[2]) then
                                local f = fs.open(args[2], "r")
                                table.insert(win.data.history, "--- " .. args[2] .. " ---")
                                while true do
                                    local line = f.readLine()
                                    if not line then break end
                                    table.insert(win.data.history, line)
                                end
                                f.close()
                            else
                                table.insert(win.data.history, "File not found: " .. args[2])
                            end
                        else
                            table.insert(win.data.history, "Usage: cat <filename>")
                        end
                    elseif cmd == "mkdir" then
                        if args[2] then
                            fs.makeDir(args[2])
                            table.insert(win.data.history, "Created directory: " .. args[2])
                        else
                            table.insert(win.data.history, "Usage: mkdir <dirname>")
                        end
                    elseif cmd == "rm" then
                        if args[2] then
                            if fs.exists(args[2]) then
                                fs.delete(args[2])
                                table.insert(win.data.history, "Deleted: " .. args[2])
                            else
                                table.insert(win.data.history, "Path not found: " .. args[2])
                            end
                        else
                            table.insert(win.data.history, "Usage: rm <path>")
                        end
                    elseif cmd == "theme" then
                        if args[2] and colorMap[args[2]] then
                            PicoOS.theme.desktopBg = colorMap[args[2]]
                            table.insert(win.data.history, "Desktop theme updated!")
                        end
                        if args[3] and colorMap[args[3]] then
                            PicoOS.theme.windowHeader = colorMap[args[3]]
                            table.insert(win.data.history, "Window header theme updated!")
                        end
                        if not args[2] then
                            table.insert(win.data.history, "Colors: black, blue, green, cyan, red, purple, yellow, gray")
                        end
                    elseif cmd == "ping" then
                        local targetId = tonumber(args[2])
                        if targetId then
                            local modem = peripheral.find("modem")
                            if modem then
                                modem.transmit(targetId, os.getComputerID(), {action = "PING", senderID = os.getComputerID()})
                                table.insert(win.data.history, "Ping sent to #" .. targetId)
                            else
                                table.insert(win.data.history, "Error: No modem found!")
                            end
                        else
                            table.insert(win.data.history, "Usage: ping <computer_id>")
                        end
                    elseif cmd == "killall" then
                        windows = {}
                        activeWindow = nil
                        table.insert(win.data.history, "All windows closed!")
                    elseif cmd == "id" then
                        table.insert(win.data.history, "Computer ID: #" .. tostring(os.getComputerID()))
                    elseif cmd == "time" or cmd == "date" then
                        table.insert(win.data.history, "Time: " .. textutils.formatTime(os.time(), true))
                    elseif cmd == "ver" then
                        table.insert(win.data.history, "PicoOS Version " .. PicoOS.version)
                    elseif cmd == "67" then
                        table.insert(win.data.history, "  ██████╗  ███████╗")
                        table.insert(win.data.history, " ██╔════╝  ██╔════╝")
                        table.insert(win.data.history, " ██║       ███████╗")
                        table.insert(win.data.history, " ██║       ██╔══██╗")
                        table.insert(win.data.history, " ╚██████╗  ███████╗")
                        table.insert(win.data.history, "  ╚═════╝  ╚══════╝")
                    elseif cmd == "echo" then
                        table.insert(win.data.history, table.concat(args, " ", 2))
                    elseif cmd == "reboot" then
                        table.insert(win.data.history, "Rebooting PicoOS...")
                        os.sleep(0.4)
                        PicoOS.bootScreen()
                        win.data.history = {"PicoOS Pro Shell v3.2 (Rebooted)", "Type 'help' for commands."}
                    elseif cmd == "exit" then
                        for i, w in ipairs(windows) do
                            if w == win then table.remove(windows, i) break end
                        end
                    elseif cmd ~= "" then
                        table.insert(win.data.history, "Unknown command: " .. cmd)
                    end
                end
            end
        end
    )
end

-- ==========================================
-- 2. NOTEPAD APPLICATION
-- ==========================================
local function createNotepadWindow()
    createWindow("Notepad", 15, 5, 30, 10,
        function(win)
            win.data.text = "Hello from Notepad!"
        end,
        function(win)
            term.setCursorPos(win.x + 2, win.y + 2)
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.white)
            term.write(win.data.text)
        end,
        function(win, event, param)
            if event == "char" then
                win.data.text = win.data.text .. param
            elseif event == "key" and param == keys.backspace then
                win.data.text = string.sub(win.data.text, 1, -2)
            end
        end
    )
end

-- ==========================================
-- 3. NETWORK CONFIG APP
-- ==========================================
local function createNetworkConfigWindow()
    createWindow("Network Config", 10, 4, 32, 10,
        function(win)
            win.data.idInput = ""
            win.data.portInput = "65535"
            win.data.status = "Enter Server ID and Port"
            
            if fs.exists("server_config.txt") then
                local f = fs.open("server_config.txt", "r")
                if f then
                    win.data.idInput = f.readLine() or ""
                    win.data.portInput = f.readLine() or "65535"
                    f.close()
                end
            end
            win.data.focusField = 1
        end,
        function(win)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            
            term.setCursorPos(win.x + 2, win.y + 2)
            term.write("Server ID:")
            term.setCursorPos(win.x + 13, win.y + 2)
            term.setBackgroundColor(win.data.focusField == 1 and colors.gray or colors.black)
            term.write("[" .. win.data.idInput .. string.rep(" ", 8 - #win.data.idInput) .. "]")
            
            term.setBackgroundColor(colors.black)
            term.setCursorPos(win.x + 2, win.y + 4)
            term.write("Port:")
            term.setCursorPos(win.x + 13, win.y + 4)
            term.setBackgroundColor(win.data.focusField == 2 and colors.gray or colors.black)
            term.write("[" .. win.data.portInput .. string.rep(" ", 8 - #win.data.portInput) .. "]")
            
            term.setBackgroundColor(colors.blue)
            term.setCursorPos(win.x + 8, win.y + 7)
            term.write(" [ SAVE CONFIG ] ")
            
            term.setBackgroundColor(colors.black)
            term.setCursorPos(win.x + 2, win.y + 8)
            term.setTextColor(colors.yellow)
            term.write(string.sub(win.data.status, 1, win.w - 4))
        end,
        function(win, event, p1, p2, p3)
            if event == "mouse_click" then
                local btn, cx, cy = p1, p2, p3
                local lx, ly = cx - win.x + 1, cy - win.y + 1
                if ly == 3 then win.data.focusField = 1
                elseif ly == 5 then win.data.focusField = 2
                elseif ly == 8 and lx >= 8 and lx <= 23 then
                    local f = fs.open("server_config.txt", "w")
                    if f then
                        f.writeLine(win.data.idInput)
                        f.writeLine(win.data.portInput)
                        f.close()
                        win.data.status = "Saved successfully!"
                    else
                        win.data.status = "Save error!"
                    end
                end
            elseif event == "char" then
                if win.data.focusField == 1 and #win.data.idInput < 6 and p1:match("%d") then
                    win.data.idInput = win.data.idInput .. p1
                elseif win.data.focusField == 2 and #win.data.portInput < 6 and p1:match("%d") then
                    win.data.portInput = win.data.portInput .. p1
                end
            elseif event == "key" then
                if p1 == keys.backspace then
                    if win.data.focusField == 1 and #win.data.idInput > 0 then
                        win.data.idInput = string.sub(win.data.idInput, 1, #win.data.idInput - 1)
                    elseif win.data.focusField == 2 and #win.data.portInput > 0 then
                        win.data.portInput = string.sub(win.data.portInput, 1, #win.data.portInput - 1)
                    end
                elseif p1 == keys.tab then
                    win.data.focusField = win.data.focusField == 1 and 2 or 1
                end
            end
        end
    )
end

-- ==========================================
-- 4. NOVAMESSENGER APPLICATION
-- ==========================================
local function createNovaMessengerWindow()
    createWindow("Messenger", 6, 3, 42, 16,
        function(win)
            win.data.myID = os.getComputerID()
            win.data.modem = peripheral.find("modem")
            win.data.serverID = nil
            win.data.serverPort = 65535
            
            if fs.exists("server_config.txt") then
                local f = fs.open("server_config.txt", "r")
                if f then
                    win.data.serverID = tonumber(f.readLine())
                    win.data.serverPort = tonumber(f.readLine()) or 65535
                    f.close()
                end
            end
            
            if win.data.modem then
                if not win.data.modem.isOpen(win.data.serverPort) then win.data.modem.open(win.data.serverPort) end
                if not win.data.modem.isOpen(65535) then win.data.modem.open(65535) end
                if not win.data.modem.isOpen(win.data.myID) then win.data.modem.open(win.data.myID) end
            end
            
            win.data.chats = {}
            win.data.recentContacts = {}
            win.data.activeTargetID = win.data.serverID or nil
            win.data.inputBuffer = ""
            win.data.inputMode = "msg"
            
            if win.data.serverID and not win.data.chats[win.data.serverID] then
                win.data.chats[win.data.serverID] = {}
                table.insert(win.data.chats[win.data.serverID], {sender = "Sys", text = "Srv ID: " .. tostring(win.data.serverID) .. " Port: " .. tostring(win.data.serverPort)})
            end
            
            win.data.sendMessage = function()
                if #win.data.inputBuffer > 0 then
                    if not win.data.modem then
                        table.insert(win.data.chats[win.data.activeTargetID], {sender = "Sys", text = "Error: No modem!"})
                        return
                    end
                    if not win.data.serverID then
                        table.insert(win.data.chats[win.data.activeTargetID], {sender = "Sys", text = "Error: Set Server ID in NetConfig!"})
                        return
                    end
                    
                    local packet = {
                        action = (win.data.activeTargetID == win.data.serverID) and "NEW_MSG" or "RELAY_MSG",
                        senderID = win.data.myID,
                        recipientID = win.data.activeTargetID,
                        text = win.data.inputBuffer
                    }
                    
                    win.data.modem.transmit(win.data.serverID, win.data.myID, packet)
                    
                    if not win.data.chats[win.data.activeTargetID] then
                        win.data.chats[win.data.activeTargetID] = {}
                    end
                    table.insert(win.data.chats[win.data.activeTargetID], {sender = "Me", text = win.data.inputBuffer})
                    win.data.inputBuffer = ""
                end
            end
            
            win.data.addContact = function(id)
                if not id or id == win.data.myID or id == win.data.serverID then return end
                for _, c in ipairs(win.data.recentContacts) do
                    if c == id then return end
                end
                table.insert(win.data.recentContacts, 1, id)
                if not win.data.chats[id] then win.data.chats[id] = {} end
            end
            
            win.data.addMessage = function(targetID, sender, text)
                if not targetID then return end
                if targetID ~= win.data.serverID then win.data.addContact(targetID) end
                if not win.data.chats[targetID] then win.data.chats[targetID] = {} end
                table.insert(win.data.chats[targetID], {sender = sender, text = text})
                if #win.data.chats[targetID] > 20 then table.remove(win.data.chats[targetID], 1) end
            end
        end,
        function(win)
            local sidebarW = 12
            local chatX = win.x + sidebarW
            local chatW = win.w - sidebarW
            
            for r = 1, win.h - 2 do
                for c = 1, sidebarW - 1 do
                    term.setCursorPos(win.x + c - 1, win.y + r)
                    term.setBackgroundColor(colors.gray)
                    term.write(" ")
                end
            end
            
            term.setCursorPos(win.x, win.y + 1)
            term.setBackgroundColor(colors.lightGray)
            term.setTextColor(colors.black)
            term.write(" [+]PEERS")
            
            if win.data.serverID then
                term.setCursorPos(win.x, win.y + 2)
                if win.data.serverID == win.data.activeTargetID then
                    term.setBackgroundColor(colors.cyan)
                    term.setTextColor(colors.black)
                else
                    term.setBackgroundColor(colors.gray)
                    term.setTextColor(colors.yellow)
                end
                local srvLabel = " #Srv:" .. tostring(win.data.serverID)
                term.write(srvLabel .. string.rep(" ", sidebarW - #srvLabel))
            end
            
            for i, cId in ipairs(win.data.recentContacts) do
                if (i + 2) > (win.h - 3) then break end
                term.setCursorPos(win.x, win.y + 2 + i)
                if cId == win.data.activeTargetID then
                    term.setBackgroundColor(colors.cyan)
                    term.setTextColor(colors.black)
                else
                    term.setBackgroundColor(colors.gray)
                    term.setTextColor(colors.white)
                end
                local label = " #" .. tostring(cId)
                term.write(label .. string.rep(" ", sidebarW - #label))
            end
            
            term.setBackgroundColor(colors.black)
            for r = 1, win.h - 2 do
                term.setCursorPos(win.x + sidebarW - 1, win.y + r)
                term.setTextColor(colors.gray)
                term.write("|")
            end
            
            term.setCursorPos(chatX, win.y + 1)
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.yellow)
            term.write(string.rep(" ", chatW))
            term.setCursorPos(chatX + 1, win.y + 1)
            if win.data.activeTargetID then
                local targetName = (win.data.activeTargetID == win.data.serverID) and "Server" or ("#" .. tostring(win.data.activeTargetID))
                term.write("Chat: " .. targetName)
            else
                term.write("Select chat")
            end
            
            term.setBackgroundColor(colors.black)
            for r = 2, win.h - 3 do
                term.setCursorPos(chatX, win.y + r)
                term.write(string.rep(" ", chatW))
            end
            
            if win.data.activeTargetID and win.data.chats[win.data.activeTargetID] then
                local history = win.data.chats[win.data.activeTargetID]
                local maxLines = win.h - 4
                local startIdx = math.max(1, #history - maxLines + 1)
                local row = win.y + 2
                
                for i = startIdx, #history do
                    local msg = history[i]
                    if msg and row < win.y + win.h - 1 then
                        term.setCursorPos(chatX + 1, row)
                        if msg.sender == "Me" then
                            term.setTextColor(colors.cyan)
                            term.write("[Me]: ")
                            term.setTextColor(colors.white)
                            term.write(tostring(msg.text))
                        elseif msg.sender == "Sys" then
                            term.setTextColor(colors.yellow)
                            term.write(tostring(msg.text))
                        else
                            term.setTextColor(colors.lime)
                            term.write("[Peer]: ")
                            term.setTextColor(colors.white)
                            term.write(tostring(msg.text))
                        end
                        row = row + 1
                    end
                end
            end
            
            term.setCursorPos(win.x, win.y + win.h - 2)
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)
            term.write(string.rep(" ", win.w))
            
            term.setCursorPos(win.x + 1, win.y + win.h - 2)
            if win.data.inputMode == "add_id" then
                term.setTextColor(colors.yellow)
                term.write("ID: " .. tostring(win.data.inputBuffer) .. "_")
            else
                term.setTextColor(colors.white)
                local maxInputLen = win.w - sidebarW - 8
                local displayInput = string.sub(win.data.inputBuffer, -maxInputLen)
                term.write(">" .. displayInput .. "_")
                
                term.setCursorPos(win.x + win.w - 7, win.y + win.h - 2)
                term.setBackgroundColor(colors.blue)
                term.setTextColor(colors.white)
                term.write("[SEND]")
            end
        end,
        function(win, event, p1, p2, p3)
            if event == "mouse_click" then
                local btn, cx, cy = p1, p2, p3
                local localX = cx - win.x + 1
                local localY = cy - win.y + 1
                
                if localY == win.h - 1 and localX >= win.w - 7 and localX <= win.w then
                    win.data.sendMessage()
                elseif localX <= 8 and localY == 2 then
                    win.data.inputMode = "add_id"
                    win.data.inputBuffer = ""
                elseif localX <= 11 and localY == 3 and win.data.serverID then
                    win.data.activeTargetID = win.data.serverID
                elseif localX <= 11 and localY > 3 and localY < win.h - 1 then
                    local idx = localY - 3
                    if win.data.recentContacts[idx] then
                        win.data.activeTargetID = win.data.recentContacts[idx]
                    end
                end
            elseif event == "char" then
                if win.data.inputMode == "add_id" then
                    if p1 and p1:match("%d") and #win.data.inputBuffer < 6 then
                        win.data.inputBuffer = win.data.inputBuffer .. p1
                    end
                else
                    if p1 and #win.data.inputBuffer < 40 then
                        win.data.inputBuffer = win.data.inputBuffer .. p1
                    end
                end
            elseif event == "key" then
                if p1 == keys.backspace then
                    if #win.data.inputBuffer > 0 then
                        win.data.inputBuffer = string.sub(win.data.inputBuffer, 1, #win.data.inputBuffer - 1)
                    end
                elseif p1 == keys.enter then
                    if win.data.inputMode == "add_id" then
                        local newId = tonumber(win.data.inputBuffer)
                        if newId and newId ~= win.data.myID then
                            win.data.addContact(newId)
                            win.data.activeTargetID = newId
                        end
                        win.data.inputMode = "msg"
                        win.data.inputBuffer = ""
                    else
                        win.data.sendMessage()
                    end
                end
            elseif event == "rednet_message" or event == "modem_message" then
                local modemChannel, modemReply, msg = p1, p2, p3
                if event == "rednet_message" then msg = p2 end
                if type(msg) == "table" and msg.text then
                    local sender = msg.senderID or modemReply
                    win.data.addMessage(sender, "Peer", msg.text)
                end
            end
        end
    )
end

-- Register Desktop Icons
PicoOS.registerIcon("terminal", "Terminal", 3, 2, createTerminalWindow)
PicoOS.registerIcon("notepad", "Notepad", 3, 6, createNotepadWindow)
PicoOS.registerIcon("config", "NetConfig", 3, 10, createNetworkConfigWindow)
PicoOS.registerIcon("messenger", "Messenger", 3, 14, createNovaMessengerWindow)

-- Main System Loop
function PicoOS.run()
    PicoOS.bootScreen()
    
    while true do
        PicoOS.drawDesktop()
        PicoOS.drawIcons()
        PicoOS.drawWindows()
        PicoOS.drawTaskbar()
        PicoOS.drawStartMenu()
        
        local event, p1, p2, p3 = os.pullEvent()
        local w, h = term.getSize()
        
        if event == "mouse_click" then
            local button, x, y = p1, p2, p3
            
            if y == h and x >= 1 and x <= 7 then
                startMenuOpen = not startMenuOpen
                
            elseif startMenuOpen and x >= 1 and x <= 18 and y >= h - 7 and y <= h - 1 then
                if y == h - 6 then
                    createTerminalWindow()
                    startMenuOpen = false
                elseif y == h - 5 then
                    createNotepadWindow()
                    startMenuOpen = false
                elseif y == h - 4 then
                    createNetworkConfigWindow()
                    startMenuOpen = false
                elseif y == h - 3 then
                    createNovaMessengerWindow()
                    startMenuOpen = false
                elseif y == h - 2 then
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(colors.white)
                    term.clear()
                    term.setCursorPos(1, 1)
                    print("Shutting down PicoOS...")
                    break
                end
            else
                startMenuOpen = false
                
                local clickedIcon = false
                for _, icon in ipairs(icons) do
                    if x >= icon.x and x <= icon.x + 2 and (y == icon.y or y == icon.y + 1) then
                        icon.onClick()
                        clickedIcon = true
                        break
                    end
                end
                
                if not clickedIcon then
                    for i = #windows, 1, -1 do
                        local win = windows[i]
                        
                        if x == win.x + win.w - 1 and y == win.y + win.h - 1 then
                            activeWindow = win
                            resizingWindow = win
                            table.remove(windows, i)
                            table.insert(windows, win)
                            break
                        elseif y == win.y and x >= win.x + win.w - 3 and x <= win.x + win.w then
                            table.remove(windows, i)
                            if activeWindow == win then activeWindow = windows[#windows] end
                            break
                        elseif y == win.y and x >= win.x and x < win.x + win.w - 3 then
                            activeWindow = win
                            draggingWindow = win
                            dragOffsetX = x - win.x
                            dragOffsetY = y - win.y
                            table.remove(windows, i)
                            table.insert(windows, win)
                            break
                        elseif x >= win.x and x < win.x + win.w and y >= win.y and y < win.y + win.h then
                            activeWindow = win
                            table.remove(windows, i)
                            table.insert(windows, win)
                            
                            if win.handleEvent then
                                win.handleEvent(win, "mouse_click", button, x, y)
                            end
                            break
                        end
                    end
                end
            end
            
        elseif event == "mouse_drag" then
            local button, x, y = p1, p2, p3
            if draggingWindow then
                draggingWindow.x = x - dragOffsetX
                draggingWindow.y = y - dragOffsetY
            elseif resizingWindow then
                local newW = x - resizingWindow.x + 1
                local newH = y - resizingWindow.y + 1
                if newW >= 22 then resizingWindow.w = newW end
                if newH >= 8 then resizingWindow.h = newH end
            end
            
        elseif event == "mouse_up" then
            draggingWindow = nil
            resizingWindow = nil
            
        elseif event == "char" or event == "key" or event == "rednet_message" or event == "modem_message" then
            if activeWindow and activeWindow.handleEvent then
                activeWindow.handleEvent(activeWindow, event, p1, p2, p3)
            end
        end
    end
end

-- Boot System
PicoOS.run()