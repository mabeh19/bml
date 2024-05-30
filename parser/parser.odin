package parser

import proto "../protocol"
import ele "../element"

import "core:fmt"
import "core:os"
import "core:mem"
import "core:slice"

Data :: struct {
    name: string,
    value: any
}

Content :: []Data

parse :: proc { parse_from_file, parse_from_protocol, parse_data }

parse_from_protocol :: proc(p: ^proto.Protocol, file: string) -> Content
{
    c := Content{}

    return c
}

parse_from_file :: proc(proto_path: string, file: string) -> (c: Content, ok: bool)
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

parse_data :: proc(p: ^proto.Protocol, data: []byte) -> (c: Content, ok: bool)
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

    return cont[:], true
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
    case ele.ID: 
        v := mem.make_any(raw_data(data[offset^:]), t.backingType.type)

        d = Data {
            name = f.name,
            value = v,
        }

        offset^ += t.backingType.size

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
            arr_size := len * f.size.(int)
            v := slice.clone(data[offset^:][:arr_size])

            d = Data {
                name = f.name,
                value = v,
            }

            offset^ += arr_size
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
        // type unspecified, must depend on other
        if dep_type, ok := p.ids[f.dependsOn]; ok {
            if dep_val, found := lookup_val(c[:], f.dependsOn); found {
                for e in dep_type.entries {
                    if dep_val == e.value {
                        for &field in e.fields {
                            add_field(p, c, &field, data, offset)
                        }
                    }
                }
            }
            else {
                fmt.printfln("Value lookup failed for %v", f.dependsOn)
            }

            return ok
        }
        else {
            ok = false
        }
    }

    if ok {
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
    case i16:
        return int(t), true
    case u32:
        return int(t), true
    case i32:
        return int(t), true
    case u64:
        return int(t), true
    case i64:
        return int(t), true
    case:
        return {}, false
    }

    return {}, false
}
