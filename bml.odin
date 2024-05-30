package bml

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import "protocol"
import "parser"

CommandCode :: enum u16 {
    FOO_1 = 1,
    FOO_2 = 2
}

FooData :: struct #raw_union {
    foo1: struct #packed {
            length: u32,
            name: [20]u8
        },
    foo2: struct #packed {}
}

Foo :: struct #packed {
    marker: [4]u8,

    // header
    size: u32,
    commandcode: CommandCode,
    messageId: u32,

    // body
    data: FooData
}



main :: proc() 
{
    arena := virtual.Arena{}
    arena_alloc := virtual.arena_allocator(&arena)
    context.allocator = arena_alloc
    bml, ok := protocol.parse("tests/foo.xml")

    if ok {
        fmt.println("Protocol: ", bml)
        msg := "Hello there!"

        foo := Foo {
            marker = [?]u8{0xA, 0xB, 0xC, 0xD},
            size = size_of(Foo),
            commandcode = .FOO_1,
            messageId = 0xAA,
            data = FooData {
                foo1 = {
                    length = u32(len(msg)),
                    name = {},
                },
            },
        }

        mem.copy(raw_data(foo.data.foo1.name[:]), raw_data(msg), len(msg))

        c, c_ok := parser.parse(&bml, mem.ptr_to_bytes(&foo))

        if c_ok {
            for d in c {
                switch t in d.value {
                case [^]u8:
                    fmt.printfln("%v => %v", d.name, strings.string_from_ptr(t, len(msg)))
                case:
                    fmt.printfln("%v => %v", d.name, d.value)
                }
            }
        }
        else {
            fmt.println("Error parsing content")
        }
    }
    else {
        fmt.println("Error parsing protocol")
    }

    virtual.arena_destroy(&arena)
}


