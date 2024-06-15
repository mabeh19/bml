package emitter

import "core:strings"
import "core:fmt"
import proto "../protocol"
import ele "../element"


C_TYPES := map[typeid]string { 
    u8    = "uint8_t",
    i8    = "int8_t", 
    u16le = "uint16_t",
    i16le = "int16_t",
    u32le = "uint32_t",
    i32le = "int32_t",
    u64le = "uint64_t",
    i64le = "int64_t",
    f16le = "uint16_t", // no built-in support for float16 in C
    f32le = "float",
    f64le = "double",

    u16be =  "uint16_t",
    i16be =  "int16_t",
    u32be =  "uint32_t",
    i32be =  "int32_t",
    u64be =  "uint64_t",
    i64be =  "int64_t",
    f16be =  "uint16_t", // no built-in support for float16 in C
    f32be =  "float",
    f64be =  "double",
}

emit_c :: proc(p: ^proto.Protocol) -> string
{
    out := strings.Builder{}

    GUARD :: `

#ifndef %v_DEFINITIONS
#define %v_DEFINITIONS

`

    INCLUDES :: `

#include <stdint.h>

`

    fmt.sbprintf(&out, GUARD, p.name, p.name)
    strings.write_string(&out, INCLUDES)

    // Create typedefs and structs for custom types
    for name, id in p.custom_types {
        switch t in id {
        case ele.ID:
            fmt.sbprintf(&out, "typedef %v %v\n\n;", t.name, name)
        case ele.BaseType:
            fmt.sbprintf(&out, "typedef %v %v\n\n;", C_TYPES[t.type], name)
        case ele.Fields:
            fmt.sbprintf(&out, "struct %v {{\n", name)
            add_fields(p, &out, t)
            fmt.sbprintf(&out, "};\n\n")
        }
    }
   
    // Create enums for IDs
    for _, id  in p.ids {
        fmt.sbprintf(&out, "enum %v {{\n", id.name)
        for entry in id.entries {
            fmt.sbprintf(&out, "\t%v_%v = %v,\n", id.name, entry.name, entry.value)
        }
        strings.write_string(&out, "};\n\n")
    }

    // Create unions for Ids
    for _, id in p.ids {
        fmt.sbprintf(&out, "union %v {{\n", id.name)
        for entry in id.entries {
            fmt.sbprintf(&out, "\tstruct %v {{\n", entry.name)
            add_fields(p, &out, entry.fields, indent_level = 2)
            fmt.sbprintf(&out, "\t} %v;\n", entry.name)
        }
        fmt.sbprintf(&out, "};\n\n")
    }

    // Create Header
    fmt.sbprintf(&out, "struct %v_header {{\n", p.name)
    add_fields(p, &out, p.header)
    fmt.sbprintf(&out, "};\n\n")

    // Create body
    fmt.sbprintf(&out, "struct %v_body {{\n", p.name)
    add_fields(p, &out, p.body)
    fmt.sbprintf(&out, "};\n\n")


    // Create marker
    s := fmt.aprint(p.marker.value)
    s, _ = strings.replace(s, "[", "{", 1)
    s, _ = strings.replace(s, "]", "}", 1)
    fmt.sbprintf(&out, "static const unsigned char %v_MARKER[%v] = %v;\n\n", p.name, p.marker.size * p.marker.length, s)


    // end guard
    fmt.sbprintf(&out, "#endif /* %v_DEFINITIONS */\n", p.name)

    return strings.to_string(out)
}

@(private)
add_fields :: proc(p: ^proto.Protocol, out: ^strings.Builder, fields: []ele.Field, indent_level: int = 1)
{
    for f in fields {
        indent := strings.repeat("\t", indent_level)
        defer delete(indent)
        if f.dependsOn != "" {
            fmt.sbprintf(out, "%vconst union %v %v;\n", indent, f.dependsOn, f.name)
            continue
        }

        switch t in f.type {
        case ele.BaseType:
            l, l_ok := f.length.(int)
            if !l_ok {
                l = 0
            }
            fmt.sbprintf(out, "%vconst %v *%v;\n", indent, C_TYPES[t.type], f.name)
        case ele.ID:
            fmt.sbprintf(out, "%vconst %v *%v;\n", indent, t.backingType.name, f.name)
        case ele.Fields:
            add_fields(p, out, t, indent_level)
        }
    }
}
