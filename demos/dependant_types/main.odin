package bml

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import "../../protocol"
import "../../parser"
import "../../emitter"

CommandCode :: enum u16 {
    FOO_1 = 1,
    FOO_2 = 2
}

FooData :: struct #raw_union {
    foo1: struct #packed {
            length: u32,
            name: [5]u8,
            value: f32,
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
    data: FooData,

    checksum: u32,
}


main :: proc() 
{
    arena := virtual.Arena{}
    arena_alloc := virtual.arena_allocator(&arena)
    context.allocator = arena_alloc
    defer virtual.arena_destroy(&arena)
    bml, ok := protocol.parse("dependant_types.xml")

    if ok {
        fmt.println("C header: ", emitter.emit_c(&bml))
        msg := "Hello"

        foo := Foo {
            marker = [?]u8{0xA, 0xB, 0xC, 0xD},
            size = size_of(Foo),
            commandcode = .FOO_1,
            messageId = 0xAA,
            data = FooData {
                foo1 = {
                    length = u32(len(msg)),
                    name = {},
                    value = 1.2345,
                },
            },
            checksum = 4321,
        }

        bytes := make([]u8, 300)
        mem.copy(raw_data(&foo.data.foo1.name), raw_data(msg), len(msg))
        mem.copy(raw_data(bytes[100:]), raw_data(mem.ptr_to_bytes(&foo)), size_of(Foo))

        packet, c_ok := parser.parse(&bml, bytes)

        if c_ok {
            fmt.printfln("Marker found at %v, size %v", packet.offset, packet.size)
            for d in packet.data {
                switch t in d.value {
                case parser.Array:
                    memory := make([dynamic]u8, t.len)
                    mem.copy(raw_data(memory), t.ptr, t.element_size * t.len)
                    fmt.printfln("%v => %v[%v] @ %v = %v", d.name, t.type, t.len, t.ptr, memory[:])
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

}


