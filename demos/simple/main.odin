package bml

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import "../../protocol"
import "../../parser"
import "../../emitter"

Simple :: struct #packed {
    // Marker
    marker: u32be,

    // Header
    size: u32be,
    code: u16be,

    // Body
    data: u64be
}

main :: proc() 
{
    arena := virtual.Arena{}
    arena_alloc := virtual.arena_allocator(&arena)
    context.allocator = arena_alloc
    defer virtual.arena_destroy(&arena)
    bml, ok := protocol.parse("simple.xml")

    if ok {
        fmt.println(bml)
        fmt.println("C header: ", emitter.emit_c(&bml))

        simple := Simple {
            marker = 0x12345678,

            size = 33,
            code = 0xBEEF,

            data = 0x1233456787654321,
        }

        bytes := make([]u8, 300)

        // insert at some spot inside the memory buffer
        mem.copy(raw_data(bytes[20:]), raw_data(mem.ptr_to_bytes(&simple)), size_of(Simple))

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
                    fmt.printfln("%v => %x", d.name, d.value)
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


