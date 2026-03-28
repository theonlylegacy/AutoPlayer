local Reader = { };

function Reader.new(Content)
    local ReaderObject = { };
    
    local Buffer = buffer.fromstring(Content);
    local Cursor = 0;
    local Length = buffer.len(Buffer);

    function ReaderObject:ReadByte()
        local Value = buffer.readu8(Buffer, Cursor);

        Cursor += 1;

        return Value;
    end;

    function ReaderObject:ReadInt32()
        local Value = buffer.readu32be(Buffer, Cursor);
        
        Cursor += 4;

        return Value;
    end;

    function ReaderObject:ReadInt16()
        local Value = buffer.readu16be(Buffer, Cursor);
        
        Cursor += 2;

        return Value;
    end;

    function ReaderObject:ReadVLQ()
        local Value = 0;

        while true do
            Value = bit32.lshift(Value, 7) + bit32.band(Value, 0x7F);

            if bit32.band(ReaderObject:ReadByte(), 0x80) == 0 then
                break;
            end;
        end;

        return Value;
    end;

    function ReaderObject:Skip(Amount)
        Cursor += Amount;
    end;

    function ReaderObject:IsEOF()
        return Cursor >= Length;
    end;

    return ReaderObject;
end;

return Reader;
