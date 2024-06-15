package parser

import proto "../protocol"
import ele "../element"

import "core:fmt"
import "core:os"
import "core:mem"
import "core:slice"


Packet :: struct {
    data:   Content,
    buffer: rawptr,
    offset: int,
    size:   int,
}


Data :: struct {
    name: string,
    value: any,
}

Array :: struct {
    ptr: rawptr,
    len: int,
    element_size: int,
    type: typeid,
}

Content :: []Data

parse :: proc { parse_from_file, parse_from_protocol, parse_data }

parse_from_protocol :: proc(p: ^proto.Protocol, file: string) -> (packet: Packet, ok: bool)
{
    data := os.read_entire_file_from_filename(file) or_return

    return parse(p, data)
}

parse_from_file :: proc(proto_path: string, file: string) -> (packet: Packet, ok: bool)
{
    p, p_ok := proto.parse(proto_path)
    if !p_ok {
        fmt.printfln("Failed to parse protocol %v", proto_path)
        return {}, false
    }
    
    data, data_ok := os.read_entire_file_from_filename(file)
    if !data_ok {
        fmt.printfln("Failed to read contents of file %v", file)
        return {}, false
    }

    return parse(&p, data)
}

parse_data :: proc(p: ^proto.Protocol, data: []byte) -> (packet: Packet, ok: bool)
{
    cont := [dynamic]Data{}
    idx := 0

    // move forward in data until marker is reached
    marker_tot_len := p.marker.size * p.marker.length
    for mem.compare_ptrs(raw_data(p.marker.value), raw_data(data[idx:]), marker_tot_len) != 0 {
        idx += 1;

        if idx >= len(data) {
            fmt.println("No marker found")
            return {}, false
        }
    }

    packet.offset = idx
    idx += marker_tot_len

    header := [dynamic]ele.BaseType{}
    for &f in p.header {
        if idx >= len(data) {
            break
        }

        ok := add_field(p, &cont, &f, data, &idx)
    }

    for &f in p.body {
        if idx >= len(data) {
            break
        }

        ok := add_field(p, &cont, &f, data, &idx)
    }

    packet.data = cont[:]
    packet.size = idx - packet.offset
    packet.buffer = raw_data(data)

    return packet, true
}

print :: proc(c: Content)
{
    for d in c {
        fmt.printfln("%v => %v", d.name, d.value)
    }
}


@(private)
add_field :: proc(p: ^proto.Protocol, c: ^[dynamic]Data, f: ^ele.Field, data: []byte, offset: ^int) -> bool
{
    ok := true
    d := Data{}
    switch t in f.type {
    case ele.Fields:
        for &field in t {
            add_field(p, c, &field, data, offset)
        }
    case ele.ID: 
        if f.dependsOn != "" {
            // Is dependant on other field look it up and parse the approtriate entry
            if dep_val, found := lookup_val(c[:], f.dependsOn); found {
                for e in f.type.(ele.ID).entries {
                    if dep_val == e.value {
                        for &field in e.fields {
                            add_field(p, c, &field, data, offset)
                        }
                    }
                }
            }
            else {
                fmt.printfln("Value lookup failed for %v while parsing field %v", f.dependsOn, f.name)
                ok = false
            }

            return ok
        }
        else {
            // Is the deciding field
            v := mem.make_any(raw_data(data[offset^:]), t.backingType.type)

            d = Data {
                name = f.name,
                value = v,
            }

            offset^ += t.backingType.size
        }

    case ele.BaseType:
        if f.length != 1 {
            // is array
            len := 1
            switch t in f.length {
            case int:
                len = t
            case string:
                if l, ok := lookup_val(c[:], t); ok {
                    len = l
                }
                else {
                    return false
                }
            }

            arr := new_clone(Array {
                ptr             = raw_data(data[offset^:]),
                len             = len,
                element_size    = t.size,
                type            = t.type,
            })

            d = Data {
                name = f.name,
                value = mem.make_any(arr, Array),
            }

            offset^ += len * t.size
        }
        else {
            // is single element
            v := mem.make_any(raw_data(data[offset^:]), t.type)

            d = Data {
                name = f.name,
                value = v,
            }

            offset^ += f.size.(int)
        }

    case:
        ok = false
    }

    if ok && d.value != nil {
        append(c, d)
    }

    return ok
}

@(private)
lookup_val :: proc(c: []Data, s: string) -> (int, bool)
{
    for d in c {
        if d.name == s { 
            return any_to_int(d.value)
        }
    }

    return {}, false
}

@(private)
any_to_int :: proc(v: any) -> (int, bool)
{
    switch t in v { 
    case u8:
        return int(t), true
    case i8:
        return int(t), true
    case u16:
        return int(t), true
    case u16le:
        return int(t), true
    case u16be:
        return int(t), true
    case i16:
        return int(t), true
    case i16le:
        return int(t), true
    case i16be:
        return int(t), true
    case u32:
        return int(t), true
    case u32le:
        return int(t), true
    case u32be:
        return int(t), true
    case i32:
        return int(t), true
    case i32le:
        return int(t), true
    case i32be:
        return int(t), true
    case u64:
        return int(t), true
    case u64le:
        return int(t), true
    case u64be:
        return int(t), true
    case i64:
        return int(t), true
    case i64le:
        return int(t), true
    case i64be:
        return int(t), true
    case:
        return {}, false
    }

    return {}, false
}

