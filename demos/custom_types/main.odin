package bml

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import "../../protocol"
import "../../parser"
import "../../emitter"


CustomTypeDemo :: struct #packed {
    marker: [4]u8,

    // header (EMPTY)

    // body
    firstNameLen: u32,
    firstName: [7]u8,

    middleNameLen: u32,
    middleName: [8]u8,

    lastNameLen: u32,
    lastName: [9]u8,
}


main :: proc() 
{
    arena := virtual.Arena{}
    arena_alloc := virtual.arena_allocator(&arena)
    context.allocator = arena_alloc
    defer virtual.arena_destroy(&arena)
    bml, ok := protocol.parse("custom_types.xml")

    if ok {
        fmt.println("C header: ", emitter.emit_c(&bml))

        customTypes := CustomTypeDemo {
            marker = [?]u8{0x1, 0x2, 0x3, 0x4},
            firstNameLen = 7,
            firstName = [?]u8{'M', 'a', 't', 'h', 'i', 'a', 's'},
            middleNameLen = 8,
            middleName = [?]u8{'I', 'n', 'g', 'e', 'm', 'a', 'n', 'n'},
            lastNameLen = 9,
            lastName = [?]u8{'B', 'e', 'h', 'r', 'e', 'n', 's', 's', 's'},
        }

        bytes := make([]u8, 300)
        mem.copy(raw_data(bytes[100:]), raw_data(mem.ptr_to_bytes(&customTypes)), size_of(CustomTypeDemo))

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
