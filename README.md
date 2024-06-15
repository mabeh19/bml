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


