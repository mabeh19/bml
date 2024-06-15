# Binary Markup Language
Binary Markup Language (BML) is a XML scheme for describing structured binary data. The library contains a protocol parser, a binary data parser, as well as a c header emitter.

# Usage
In its current iteration, BML is simply an Odin package. It does not currently support an FFI friendly interface.

## Parsing a BML Scheme
```
import "bml/protocol"

...

foo :: proc() 
{
    prot, prot_ok := protocol.parse("foo.xml")
}
```

## Parsing a Binary File
```
import "bml/protocol"
import "bml/parser"

...

foo :: proc()
{
    // Either of these three are possible

    // 1. parse from protocol and file path
    prot, prot_ok := protocol.parse("foo.xml")
    content, content_ok := parser.parse_from_protocol(&prot, "foo.bin")

    // 2. parse from scheme and file path
    content, content_ok := parser.parse_from_file("foo.xml", "foo.bin")

    // 3. parse from protocol and binary data
    prot, prot_ok := protocol.parse("foo.xml")
    data := os.read_entire_file_from_filename("foo.bin")
    content, content_ok := parser.parse_data(&prot, data)
}
```

## Emitting C header
```
import "bml/protocol"
import "bml/emitter"

...

foo :: proc()
{
    prot, prot_ok := protocol.parse("foo.xml")
    c_header := emitter.emit_c(&prot)
}
```

# BML Grammar
The overall structure of a BML protocol consists of a series of custom types, a series of IDs and a packet definition. The packet definition describes the actual payload.

## Packet Definition
The packet definition consists of a marker, a header as well as a body.

### Marker
#### Name
marker
#### Attributes
- [required] type: BaseType
- [optional] length: int
- [optional] size: int
#### Value
Comma-separated list of values. May be provided in different bases using the following prefixes:
- Hexadecimal: 0x
- Binary: 0b
- Octal: 0o

### Header
#### Name
header
#### Attributes
None
#### Value
List of fields in header

### Body
#### Name
body
#### Attributes
None
#### Value
List of fields in body


## Base types
| Type  | Size  |
|  ---  |  ---  |
| u8    | 1     |
| i8    | 1     |
| u16   | 2     |
| i16   | 2     |
| u32   | 4     |
| i32   | 4     |
| u64   | 8     |
| i64   | 8     |
| f16   | 2     |
| f32   | 4     |
| f64   | 8     |


## ID
IDs correlate an integer value to set of fields. A field can be dependant on another field, the type of which should be an ID.
### Name
id
### Attributes
- [required] name: string
- [required] type: BaseType
### Value
List of entries

## Custom Type
Custom Types come in two flavors: type aliases and field lists.
### Name
type
### Attributes
- [required] name: string
- [optional] type: BaseType
### Value
List of fields

## Entry
### Name
entry
### Attributes
- [required] name: string
- [required] value: int

## Field
