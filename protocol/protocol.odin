package protocol

import "core:fmt"
import "core:encoding/xml"
import "core:strconv"
import "core:io"
import "core:strings"
import "core:mem"
import "core:slice"

import "../builtin_types"
import "../element"

UNKNOWN_NAME :: "??????"


Protocol :: struct {
    name: string,
    endianness: element.Endianness,
    custom_types: map[string]element.Type,
    ids: map[string]element.ID,
    marker: element.Marker,
    header: element.Fields,
    body: element.Fields
}


parse :: proc(path: string) -> (p: Protocol, ok: bool) 
{
    d, err := xml.load_from_file(path)
    if err != .None { 
        fmt.printfln("Error loading file %v: %v", path, err)
        return {}, false
    }
    defer xml.destroy(d)

    buf := strings.Builder{}
    defer strings.builder_destroy(&buf)
    w := strings.to_writer(&buf)

    return parse_protocol(d)
}

@(private)
parse_protocol :: proc(doc: ^xml.Document) -> (p: Protocol, ok: bool) 
{
    if doc.elements[0].ident != "protocol" {
        fmt.println("Protocol not found in document")
        return {}, false 
    }

    prot_name, prot_name_ok := xml.find_attribute_val_by_key(doc, 0, "name")
    prot_endi, prot_endi_ok := xml.find_attribute_val_by_key(doc, 0, "endianness")

    p.name = prot_name_ok ? prot_name : UNKNOWN_NAME
    p.endianness = prot_endi_ok ? to_endian(prot_endi) : .LITTLE
    parse_custom_types(&p, doc, 0)
    p.ids = parse_ids(&p, doc, 0)

    packet, packet_ok := xml.find_child_by_ident(doc, 0, "packet")
    p.marker = parse_marker(&p, doc, packet)
    p.header = parse_header(&p, doc, packet)
    p.body = parse_body(&p, doc, packet)

    return p, true
}

@(private)
parse_ids :: proc(p: ^Protocol, doc: ^xml.Document, p_id: u32) -> map[string]element.ID
{
    ids := map[string]element.ID{}

    for i in 0 ..< max(int) {
        id_num, found := xml.find_child_by_ident(doc, p_id, "id", i)
        
        if !found { break }
        
        entries := parse_entries(p, doc, id_num)
        name, name_found := xml.find_attribute_val_by_key(doc, id_num, "name")
        backingType, backingType_found := xml.find_attribute_val_by_key(doc, id_num, "type")
        if !backingType_found {
            fmt.printfln("ID `%v` missing backing type", name)
            continue
        }

        type, type_ok := builtin_types.get(backingType, p.endianness)
        if !type_ok {
            fmt.printfln("Backing type `%v` is invalid. Base type expected", type)
            continue
        }

        id := element.ID {
            name = name_found ? name : UNKNOWN_NAME,
            backingType = type,
            entries = entries,
        }

        ids[name] = id
    } 

    return ids
}

@(private)
parse_custom_types :: proc(p: ^Protocol, doc: ^xml.Document, p_id: u32)
{
    for i in 0 ..< max(int) {
        ctype_id, ctype_id_ok := xml.find_child_by_ident(doc, p_id, "type", i)
        ctype_name, ctype_name_ok := xml.find_attribute_val_by_key(doc, ctype_id, "name")

        if !ctype_id_ok { break }

        if !ctype_name_ok {
            fmt.printfln("No name found for custom type")
            break
        }

        if fields := parse_fields(p, doc, ctype_id); len(fields) > 0 {
            // fields alias
            // prepend name of custom type to all fields
            p.custom_types[ctype_name] = fields
        }
        else {
            // type alias
            ctype, ctype_ok := xml.find_attribute_val_by_key(doc, ctype_id, "type")
            if type, type_name_ok := get_type(p, ctype); type_name_ok {
                p.custom_types[ctype_name] = type
            }
        }
    }
}

@(private)
parse_header :: proc(p: ^Protocol, doc: ^xml.Document, p_id: u32) -> []element.Field
{
    header_id, header_id_ok := xml.find_child_by_ident(doc, p_id, "header")

    if header_id_ok {
        fields := [dynamic]element.Field{}
        
        f := parse_fields(p, doc, header_id)
        append(&fields, ..f)

        return fields[:]
    }
    else {
        return {}
    }
}

@(private)
parse_body :: proc(p: ^Protocol, doc: ^xml.Document, p_id: u32) -> []element.Field
{
    body_id, body_id_ok := xml.find_child_by_ident(doc, p_id, "body")

    if body_id_ok {
        return parse_fields(p, doc, body_id)
    }
    else {
        return {}
    }
}


@(private)
parse_entries :: proc(p: ^Protocol, doc: ^xml.Document, id_num: u32) -> []element.Entry 
{
    entries := [dynamic]element.Entry{}
    
    for i in 0 ..< max(int) {
        entry_id, entry_found := xml.find_child_by_ident(doc, id_num, "entry", i)
        if !entry_found { break }

        ename, ename_found := xml.find_attribute_val_by_key(doc, entry_id, "name")
        eval, eval_found := xml.find_attribute_val_by_key(doc, entry_id, "value")
        eval_int, eval_int_ok := strconv.parse_int(eval)
        if !eval_found || !eval_int_ok {
            fmt.println("value not found for entry or value not valid")
            continue
        }


        e := element.Entry {
            name = ename_found ? ename : UNKNOWN_NAME,
            value = eval_int,
            fields = parse_fields(p, doc, entry_id),
        }

        append(&entries, e)
    }

    return entries[:]
}

@(private)
parse_fields :: proc(p: ^Protocol, doc: ^xml.Document, p_id: u32) -> []element.Field
{
    fields := [dynamic]element.Field{}

    for i in 0 ..< max(int) {
        field_id, field_found := xml.find_child_by_ident(doc, p_id, "field", i)
        if !field_found { break }

        field, f_ok := parse_field(p, doc, field_id, fields[:])
        if !f_ok {
            continue
        }

        append(&fields, field)
    }

    return fields[:]
}

@(private)
parse_marker :: proc(p: ^Protocol, doc: ^xml.Document, p_id: u32) -> element.Marker
{
    m, m_ok := xml.find_child_by_ident(doc, p_id, "marker")
    if !m_ok {
        fmt.println("No marker specified for protocol")
        return {}
    }

    mtype, mtype_ok := xml.find_attribute_val_by_key(doc, m, "type")
    msize, msize_ok := xml.find_attribute_val_by_key(doc, m, "size")
    mlen, mlen_ok   := xml.find_attribute_val_by_key(doc, m, "length")
    
    switch v in doc.elements[m].value[0] {
    case string:
        t, t_ok := get_type(p, mtype)
        if !t_ok {
            fmt.printfln("Invalid type specified for marker: %v", mtype)
            return {}
        }
        size, size_ok := parse_size(p, &t, msize, msize_ok)
        if !size_ok {
            fmt.printfln("Invalid size specified for marker: %v", msize)
            return {}
        }
        size_int, size_int_ok := size.(int)
        if !size_int_ok {
            fmt.printfln("Cannot use reference as size for marker")
            return {}
        }
        len := 1
        len_ok := true 
        if mlen_ok {
            len, len_ok = strconv.parse_int(mlen)
        }

        d, d_ok := parse_data(v, len, &t)
        if !d_ok {
            fmt.printfln("Unable to parse data: %v", t)
            return {}
        }
        m := element.Marker {
            type = t,
            size = size_int,
            length = len,
            value = d,
        }

        return m
    case u32:
    }

    return {}
}

@(private)
parse_field :: proc(p: ^Protocol, doc: ^xml.Document, field_id: u32, fields: []element.Field) -> (f: element.Field, ok: bool)
{
    fname, fname_found := xml.find_attribute_val_by_key(doc, field_id, "name")
    ftype, ftype_found := xml.find_attribute_val_by_key(doc, field_id, "type")
    fsize, fsize_found := xml.find_attribute_val_by_key(doc, field_id, "size")
    fdepends, fdepends_found := xml.find_attribute_val_by_key(doc, field_id, "dependsOn")
    flen, flen_ok   := xml.find_attribute_val_by_key(doc, field_id, "length")

    if !ftype_found && !fdepends_found{
        fmt.printfln("%v: type not found", fname)
        return {}, false
    }

    type := element.Type{}
    t_ok := false
    size := element.Value{}
    size_ok := false

    if ftype_found {

        type, t_ok = get_type(p, ftype)
        if !t_ok {
            fmt.printfln("%v: type not recognized `%v`", fname, ftype)
            return {}, false
        }

        size, size_ok = parse_size(p, &type, fsize, fsize_found, fields)
        if !size_ok {
            fmt.printfln("%v: invalid size specified `%v`", fname, fsize)
            return {}, false
        }

        if fields, is_fields := type.(element.Fields); is_fields {
            fields := slice.clone(fields)
            for &field in fields {
                full_name := [?]string{
                    fname,
                    field.name,
                }
                field.name = strings.join(full_name[:], "_")
                if len, len_is_ref := field.length.(string); len_is_ref {
                    full_name := [?]string{
                        fname,
                        len,
                    }
                    field.length = strings.join(full_name[:], "_")
                }
            }

            type = fields
        }
    }
    else if fdepends_found {
        if id, id_ok := p.ids[fdepends]; !id_ok {
            fmt.printfln("%v: unknown depencency `%v`", fname, fdepends)
            return {}, false
        }
    }
    else {
        fmt.printfln("%v: Missing either type or type dependency", fname)
        return {}, false
    }

    len := element.Value(1)
    len_ok := true 
    if flen_ok {
        len, len_ok = parse_size(p, &type, flen, flen_ok, fields)

        if !len_ok {
            fmt.printfln("%v: invalid length specified `%v`", fname, flen)
            return {}, false
        }
    }

    return element.Field {
        name = fname,
        type = type,
        size = size,
        length = len,
        dependsOn = fdepends_found ? fdepends : "",
    }, true
}

@(private)
get_type :: proc(p: ^Protocol, type: string) -> (t: element.Type, ok: bool)
{
    ctype, ctype_ok := p.custom_types[type]
    if ctype_ok { return ctype, true }

    id_type, id_type_ok := p.ids[type]
    if id_type_ok { return id_type, true }

    return builtin_types.get(type, p.endianness)
}

@(private)
type_size :: proc(p: ^Protocol, type: ^element.Type) -> int 
{
    switch t in type {
    case element.ID:
        return t.backingType.size
    case element.BaseType:
        return t.size
    case element.Fields:
        total_size := 0
        for &f in t {
            total_size += type_size(p, &f.type)
        }
        return total_size
    }

    return 0
}

@(private)
parse_size :: proc(p: ^Protocol, type: ^element.Type, fsize: string, fsize_found: bool, fields: []element.Field = {}) -> (size: element.Value, size_ok: bool)
{
    known_field :: proc(fields: []element.Field, field: string) -> bool 
    {
        for f in fields {
            if f.name == field {
                return true
            }
        }

        return false
    }

    if fsize_found {
        size, size_ok = strconv.parse_int(fsize)

        if !size_ok {
            // size not numeric, check if dependant on other field
            size_ok = known_field(fields[:], fsize)
            size = fsize
        }
    }
    else {
        size = type_size(p, type)
        size_ok = true
    }

    return size, size_ok
}

@(private)
parse_data :: proc(s: string, length: int, type: ^element.Type) -> (d: []byte, ok: bool)
{
    switch t in type {
    case element.BaseType:
        eles := strings.split(s, ",")
        defer delete(eles)
        if len(eles) > length {
            eles = eles[:length]
        }
        dat := make([dynamic]byte)
        for e in eles {
            v := parse_type(t.type, e) or_return
            append(&dat, ..v)
        }

        return dat[:], true
    case element.Fields, element.ID:
        return {}, false
    }

    return {}, false
}

@(private)
parse_type :: proc(type: typeid, s: string) -> ([]byte, bool)
{
    s := strings.trim(s, " \n\t")
    switch type {
    case u8:
        return uint_to_bits(u8, s)
    case i8:
        return int_to_bits(i8, s)
    case u16le:
        return uint_to_bits(u16le, s)
    case i16le:
        return int_to_bits(i16le, s)
    case u32le:
        return uint_to_bits(u32le, s)
    case i32le:
        return int_to_bits(i32le, s)
    case u64le:
        return uint_to_bits(u64le, s)
    case i64le:
        return int_to_bits(i64le, s)
    case u16be:
        return uint_to_bits(u16be, s)
    case i16be:
        return int_to_bits(i16be, s)
    case u32be:
        return uint_to_bits(u32be, s)
    case i32be:
        return int_to_bits(i32be, s)
    case u64be:
        return uint_to_bits(u64be, s)
    case i64be:
        return int_to_bits(i64be, s)
    case:
        return {}, false
    }

    return {}, false
}

@(private)
int_to_bits :: proc($T: typeid, s: string) -> (dat: []byte, ok: bool)
{
    i := new_clone(cast(T)strconv.parse_int(s) or_return)
    return mem.ptr_to_bytes(i), true
}

@(private)
uint_to_bits :: proc($T: typeid, s: string) -> (dat: []byte, ok: bool)
{
    i := new_clone(cast(T)strconv.parse_uint(s) or_return)
    return mem.ptr_to_bytes(i), true
}

@(private)
to_endian :: proc(s: string) -> element.Endianness
{
    switch strings.to_lower(s) {
    case "little":
        return .LITTLE
    case "big":
        return .BIG
    case:
        return .LITTLE
    }
}
