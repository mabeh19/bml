package builtin_types

import "../element"

BUILTIN_TYPES_LE := map[string]element.BaseType {
    "u8" = {"u8", 1,    typeid_of(u8)},
    "i8" = {"i8", 1,    typeid_of(i8)}, 
    "u16" = {"u16", 2,  typeid_of(u16le)},
    "i16" = {"i16", 2,  typeid_of(i16le)},
    "u32" = {"u32", 4,  typeid_of(u32le)},
    "i32" = {"i32", 4,  typeid_of(i32le)},
    "u64" = {"u64", 8,  typeid_of(u64le)},
    "i64" = {"i64", 8,  typeid_of(i64le)},

    "f16" = {"f16", 2,  typeid_of(f16le)},
    "f32" = {"f32", 4,  typeid_of(f32le)},
    "f64" = {"f64", 8,  typeid_of(f64le)},
}

BUILTIN_TYPES_BE := map[string]element.BaseType {
    "u8" = {"u8", 1,    typeid_of(u8)},
    "i8" = {"i8", 1,    typeid_of(i8)}, 
    "u16" = {"u16", 2,  typeid_of(u16be)},
    "i16" = {"i16", 2,  typeid_of(i16be)},
    "u32" = {"u32", 4,  typeid_of(u32be)},
    "i32" = {"i32", 4,  typeid_of(i32be)},
    "u64" = {"u64", 8,  typeid_of(u64be)},
    "i64" = {"i64", 8,  typeid_of(i64be)},

    "f16" = {"f16", 2,  typeid_of(f16be)},
    "f32" = {"f32", 4,  typeid_of(f32be)},
    "f64" = {"f64", 8,  typeid_of(f64be)},
}


get :: proc(key: string, endianness: element.Endianness) -> (t: element.BaseType, ok: bool)
{
    switch endianness {
    case .LITTLE:
        return BUILTIN_TYPES_LE[key]
    case .BIG:
        return BUILTIN_TYPES_BE[key]
    }

    return {}, false
}
