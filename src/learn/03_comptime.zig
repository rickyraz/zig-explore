// =============================================================================
// COMPTIME: Zig's Superpower
// =============================================================================
//
// MENTAL MODEL:
// - C: Preprocessor macros (#define). Text substitution. No type safety.
// - Rust: Generics + const fn + macros. Multiple systems untuk different needs.
// - Zig: SATU sistem "comptime" untuk semuanya. Same language, compile vs runtime.
//
// KEY INSIGHT:
// Di Zig, "compile-time" dan "runtime" menggunakan BAHASA YANG SAMA.
// Tidak ada macro language terpisah.
// Tidak ada template syntax berbeda.
// Just Zig code yang dijalankan saat compile.
//
// Ini seperti punya REPL yang jalan saat compile.
// =============================================================================

const std = @import("std");

// =============================================================================
// COMPTIME PARAMETERS
// =============================================================================
// Parameter dengan keyword "comptime" HARUS diketahui saat compile time
// Ini yang enable generics di Zig
// =============================================================================

// Generic function - T harus diketahui saat compile
pub fn max(comptime T: type, a: T, b: T) T {
    // Karena T comptime, compiler generate specific code untuk tiap type
    // max(i32, 1, 2) -> generate versi i32
    // max(f64, 1.0, 2.0) -> generate versi f64
    return if (a > b) a else b;
}

// Kenapa "comptime T: type"?
// - comptime = nilai harus known at compile time
// - T = nama parameter
// - type = tipe dari parameter (yes, type adalah first-class value di Zig!)

pub fn swap(comptime T: type, a: *T, b: *T) void {
    const temp = a.*;
    a.* = b.*;
    b.* = temp;
}

// =============================================================================
// TYPE AS FIRST-CLASS VALUE
// =============================================================================
// Di Zig, type adalah VALUE yang bisa di:
// - Pass sebagai argument
// - Return dari function
// - Store di variable
//
// Ini TIDAK bisa di C atau Rust (tanpa macro)
// =============================================================================

fn ReturnType(comptime a: bool) type {
    // Function yang RETURN sebuah TYPE!
    if (a) {
        return i32;
    } else {
        return f64;
    }
}

pub fn typeDemo() void {
    // Type variable!
    const MyType = ReturnType(true); // MyType adalah i32
    const value: MyType = 42;
    std.debug.print("Value: {d}\n", .{value});

    const OtherType = ReturnType(false); // OtherType adalah f64
    const other: OtherType = 3.14;
    std.debug.print("Other: {d}\n", .{other});
}

// =============================================================================
// COMPTIME BLOCKS
// =============================================================================
// comptime {} block = kode yang WAJIB jalan saat compile
// Berguna untuk:
// - Compile-time assertions
// - Generate lookup tables
// - Compute constants
// =============================================================================

// Compile-time computed constant
const precomputed_squares = blk: {
    var result: [10]i32 = undefined;
    for (0..10) |i| {
        result[i] = @intCast(i * i);
    }
    break :blk result;
};
// precomputed_squares sudah dihitung SAAT COMPILE
// Runtime tidak perlu compute lagi

pub fn comptimeBlockDemo() void {
    // Compile-time assertion
    comptime {
        const x = 1 + 1;
        if (x != 2) {
            @compileError("Math is broken!");
        }
    }

    // Use precomputed values
    std.debug.print("5 squared = {d}\n", .{precomputed_squares[5]});
}

// =============================================================================
// INLINE FOR/WHILE
// =============================================================================
// inline for = loop yang di-unroll saat compile time
// Berguna untuk iterate over type info, generate code
// =============================================================================

fn sumFields(comptime T: type, value: T) i32 {
    var sum: i32 = 0;
    const fields = @typeInfo(T).@"struct".fields;

    // inline for - unrolled at compile time
    inline for (fields) |field| {
        if (field.type == i32) {
            sum += @field(value, field.name);
        }
    }
    return sum;
}

const Point = struct {
    x: i32,
    y: i32,
    name: []const u8, // This field will be skipped (not i32)
};

pub fn inlineForDemo() void {
    const p = Point{ .x = 10, .y = 20, .name = "origin" };
    const sum = sumFields(Point, p);
    std.debug.print("Sum of i32 fields: {d}\n", .{sum}); // 30
}

// =============================================================================
// COMPARISON: Generic Data Structure
// =============================================================================
//
// C - Pakai void* atau macro, tidak type safe:
//   struct Node {
//       void* data;
//       struct Node* next;
//   };
//
// Rust - Pakai generics dengan trait bounds:
//   struct Node<T> {
//       data: T,
//       next: Option<Box<Node<T>>>,
//   }
//
// Zig - Pakai comptime type parameter:
// =============================================================================

pub fn LinkedList(comptime T: type) type {
    // Function yang RETURN sebuah TYPE (struct)
    return struct {
        const Self = @This();

        pub const Node = struct {
            data: T,
            next: ?*Node = null,
        };

        head: ?*Node = null,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn prepend(self: *Self, data: T) !void {
            const new_node = try self.allocator.create(Node);
            new_node.* = .{
                .data = data,
                .next = self.head,
            };
            self.head = new_node;
        }

        pub fn deinit(self: *Self) void {
            var current = self.head;
            while (current) |node| {
                const next = node.next;
                self.allocator.destroy(node);
                current = next;
            }
        }
    };
}

pub fn linkedListDemo(allocator: std.mem.Allocator) !void {
    // Create LinkedList of i32
    var list = LinkedList(i32).init(allocator);
    defer list.deinit();

    try list.prepend(3);
    try list.prepend(2);
    try list.prepend(1);

    // Traverse
    var current = list.head;
    while (current) |node| {
        std.debug.print("{d} -> ", .{node.data});
        current = node.next;
    }
    std.debug.print("null\n", .{});
}

// =============================================================================
// @typeInfo - Runtime Type Introspection
// =============================================================================
// Zig bisa inspect type information at compile time
// Ini yang enable serialization, ORM, dll tanpa macro
// =============================================================================

pub fn printTypeInfo(comptime T: type) void {
    const info = @typeInfo(T);

    switch (info) {
        .int => |int_info| {
            std.debug.print("Integer: {d} bits, signed={}\n", .{ int_info.bits, int_info.signedness == .signed });
        },
        .@"struct" => |struct_info| {
            std.debug.print("Struct with {d} fields:\n", .{struct_info.fields.len});
            inline for (struct_info.fields) |field| {
                std.debug.print("  - {s}: {}\n", .{ field.name, field.type });
            }
        },
        else => {
            std.debug.print("Other type: {}\n", .{info});
        },
    }
}

test "comptime basics" {
    // Test generic max
    try std.testing.expectEqual(@as(i32, 5), max(i32, 3, 5));
    try std.testing.expectEqual(@as(f64, 3.14), max(f64, 2.71, 3.14));

    // Test precomputed values
    try std.testing.expectEqual(@as(i32, 25), precomputed_squares[5]);
}
