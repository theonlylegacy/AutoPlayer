local Reader = loadstring(game:HttpGet("https://raw.githubusercontent.com/theonlylegacy/AutoPlayer/refs/heads/main/Reader.lua"))();
local Menu = loadstring(game:HttpGet("https://raw.githubusercontent.com/theonlylegacy/AutoPlayer/refs/heads/main/Menu.lua"))();

local VirtualInputManager = game:GetService("VirtualInputManager");
local FileInput = nil;
local PlaybackInput = nil;

local ForcePause = false;
local ForceStop = false;


local Keys = { };
local Notes = {
    [36] = "1",
    [37] = "!",
    [38] = "2",
    [39] = "@",
    [40] = "3",
    [41] = "4",
    [42] = "$",
    [43] = "5",
    [44] = "%",
    [45] = "6",
    [46] = "^",
    [47] = "7",
    [48] = "8",
    [49] = "*",
    [50] = "9",
    [51] = "(",
    [52] = "0",
    [53] = "q",
    [54] = "Q",
    [55] = "w",
    [56] = "W",
    [57] = "e",
    [58] = "E",
    [59] = "r",
    [60] = "t",
    [61] = "T",
    [62] = "y",
    [63] = "Y",
    [64] = "u",
    [65] = "i",
    [66] = "I",
    [67] = "o",
    [68] = "O",
    [69] = "p",
    [70] = "P",
    [71] = "a",
    [72] = "s",
    [73] = "S",
    [74] = "d",
    [75] = "D",
    [76] = "f",
    [77] = "g",
    [78] = "G",
    [79] = "h",
    [80] = "H",
    [81] = "j",
    [82] = "J",
    [83] = "k",
    [84] = "l",
    [85] = "L",
    [86] = "z",
    [87] = "Z",
    [88] = "x",
    [89] = "c",
    [90] = "C",
    [91] = "v",
    [92] = "V",
    [93] = "b",
    [94] = "B",
    [95] = "n",
    [96] = "m",
    [97] = "M"
};

local Symbols = {
    ["!"] = "One",
    ["@"] = "Two",
    ["#"] = "Three",
    ["$"] = "Four",
    ["%"] = "Five",
    ["^"] = "Six",
    ["&"] = "Seven",
    ["*"] = "Eight",
    ["("] = "Nine",
    [")"] = "Zero",
    ["_"] = "Minus",
    ["+"] = "Equals",
    ["{"] = "LeftBracket",
    ["}"] = "RightBracket",
    [":"] = "Semicolon",
    ["\""] = "Quoted",
    ["<"] = "Comma",
    [">"] = "Period",
    ["?"] = "Slash",
    [","] = "Comma",
    ["."] = "Period",
    ["/"] = "Slash",
    [";"] = "Semicolon",
    ["'"] = "Quote",
};

for NoteNumber, Character in Notes do
    local EnumName = Symbols[Character] or Character:upper();
    
    local Success, KeyCode = pcall(function() 
        return Enum.KeyCode[EnumName];
    end);

    if Success then
        Keys[NoteNumber] = { KeyCode = KeyCode, RequiresShift = Character:match("[%u!@#%$%%^&*%(%)_%+{}<>%?]") ~= nil };  
    end;
end;

local function PlayNote(Character)
    local Data = Keys[Character];
    
    if not Data then 
        return;
    end;

    local KeyCode = Data.KeyCode;
    local RequiresShift = Data.RequiresShift;

    if RequiresShift then 
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game) 
    end
    
    VirtualInputManager:SendKeyEvent(true, KeyCode, false, game);
    task.wait(0.01);
    VirtualInputManager:SendKeyEvent(false, KeyCode, false, game);
    
    if RequiresShift then 
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game);
    end;
end;

local PlayMIDI = function()
    local Url = FileInput:GetValue();
    local Response = http.request({ Url = Url, Method = "GET" });

    if not Response.Success then
        return;
    end;

    if ForcePause or ForceStop then
        ForcePause = false;
        ForceStop = false;

        return;
    end;

    local Stream = Reader.new(Response.Body);

    Stream:Skip(4);
    Stream:ReadInt32();

    local _Format = Stream:ReadInt16();
    local Tracks = Stream:ReadInt16();
    local Division = Stream:ReadInt16();

    local Transpose = 0;
    local Tempo = 500000;
    local Events = { };

    for Track = 1, Tracks do
        Stream:Skip(4);

        local TrackLength = Stream:ReadInt32()
        local TrackEnd = Stream:GetPosition() + TrackLength;
        local Time = 0;
        local PreviousStatus = nil;

        while Stream:GetPosition() < TrackEnd do
            local Delta = Stream:ReadVLQ();
            
            Time += Delta;

            local Status = Stream:ReadByte();

            if Status < 0x80 then
                Stream:Rewind(1);
                Status = PreviousStatus;
            else
                PreviousStatus = Status;
            end;

            if Status == 0xFF then
                local MetaType = Stream:ReadByte();
                local Length = Stream:ReadVLQ();

                if MetaType == 0x51 then
                    local Bit1 = Stream:ReadByte();
                    local Bit2 = Stream:ReadByte();
                    local Bit3 = Stream:ReadByte();

                    Tempo = bit32.lshift(Bit1, 16) + bit32.lshift(Bit2, 8) + Bit3;
                else
                    Stream:Skip(Length);
                end
            else
                local EventType = bit32.band(Status, 0xF0);

                if EventType == 0x90 then
                    local Note = Stream:ReadByte();
                    local Velocity = Stream:ReadByte();

                    if Velocity > 0 then
                        Events[#Events + 1] = { Time = Time, Note = Note };
                    end;
                elseif EventType == 0x80 then
                    Stream:Skip(2)
                elseif EventType == 0xC0 or EventType == 0xD0 then
                    Stream:Skip(1);
                else
                    Stream:Skip(2);
                end;
            end;
        end;
    end;

    table.sort(Events, function(A, B)
        return A.Time < B.Time;
    end);

    task.spawn(function()
        local LastTime = 0;

        for Index = 1, #Events do
            local Event = Events[Index];
            local Delta = Event.Time - LastTime;
            local Delay = (Delta * Tempo) / (Division * 10 ^ 6);

            LastTime = Event.Time;

            -- // Lazy switches
            if ForceStop then
                ForceStop = false;
                
                break;
            end;

            if ForcePause then
                repeat task.wait() until not ForcePause;
            end;
            -- // Lazy switches

            task.wait(Delay / PlaybackInput:GetValue());
            PlayNote(Event.Note + Transpose);
        end;
    end);
end

local PauseMIDI = function()
    ForcePause = true;
end;

local StopMIDI = function()
    ForceStop = true;
end;

local Window = Menu:CreateWindow({ Title = "MIDI Player | Window", Size = UDim2.fromOffset(350, 370), Position = UDim2.new(0.75, 0, 0, 70) });
local Tab = Window:CreateTab({ Name = "Player" });

FileInput = Tab:InputText({ Label = "MIDI File", PlaceHolder = "https://mymidilink", Value = "https://bitmidi.com/uploads/85263.mid" });
PlaybackInput = Tab:ProgressSlider({ Label = "Playback", Format = "%.2f/%s", Value = 1, MinValue = 0.1, MaxValue = 5 });

local Actions = Tab:Row() do
    Actions:Button({ Text = "Play", Callback = PlayMIDI });
    Actions:Button({ Text = "Pause", Callback = PauseMIDI });
    Actions:Button({ Text = "Stop", Callback = StopMIDI });
end;

Window:ShowTab(Tab);
