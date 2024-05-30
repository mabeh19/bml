package builtin_types

import "../element"

BUILTIN_TYPES := map[string]element.BaseType {
    "u8" = {"u8", 1,    typeid_of(u8)},
    "i8" = {"i8", 1,    typeid_of(i8)}, 
    "u16" = {"u16", 2,  typeid_of(u16)},
    "i16" = {"i16", 2,  typeid_of(i16)},
    "u32" = {"u32", 4,  typeid_of(u32)},
    "i32" = {"i32", 4,  typeid_of(i32)},
    "u64" = {"u64", 8,  typeid_of(u64)},
    "i64" = {"i64", 8,  typeid_of(i64)},
}


get :: proc(key: string) -> (t: element.BaseType, ok: bool)
{
    return BUILTIN_TYPES[key]
}
