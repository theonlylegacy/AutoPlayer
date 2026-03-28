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

    function ReaderObject:ReadInt32() --// Shift: [b1][b2][b3][b4]
        local Byte1 = self:ReadByte();
        local Byte2 = self:ReadByte();
        local Byte3 = self:ReadByte();
        local Byte4 = self:ReadByte();

        return bit32.lshift(Byte1, 24) + bit32.lshift(Byte2, 16) + bit32.lshift(Byte3, 8) + Byte4;
    end;

    function ReaderObject:ReadInt16() --// Shift: [b1][b2]
        local Byte1 = self:ReadByte();
        local Byte2 = self:ReadByte();

        return bit32.lshift(Byte1, 8) + Byte2;
    end;

    function ReaderObject:ReadVLQ()
        local Value = 0;

        while true do
            local Byte = self:ReadByte();

            Value = bit32.lshift(Value, 7) + bit32.band(Byte, 0x7F);

            if bit32.band(Byte, 0x80) == 0 then
                break;
            end;
        end;

        return Value;
    end;

    function ReaderObject:GetPosition()
        return Cursor;
    end;

    function ReaderObject:Skip(Amount)
        Cursor += Amount;
    end;

    function ReaderObject:Rewind(Amount)
        Cursor -= Amount;
    end;

    function ReaderObject:IsEOF()
        return Cursor >= Length;
    end;

    return ReaderObject;
end;

return Reader;
