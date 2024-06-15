package element


ID :: struct {
    name: string,
    backingType: BaseType,
    entries: []Entry
}

Entry :: struct {
    name: string,
    value: int,
    fields: []Field
}

Field :: struct {
    name: string,
    type: Type,
    size: Value,
    length: Value,
    dependsOn: string,
}

Fields :: []Field

Marker :: struct {
    type: Type,
    size: int,
    length: int,
    value: []byte,
}

Type :: union {
    ID,
    Fields,
    BaseType
}


BaseType :: struct {
    name: string,
    size: int,
    type: typeid
}

Value :: union {
    string,
    int
}

Endianness :: enum {
    LITTLE,
    BIG,
}
