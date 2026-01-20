// =============================================================================
// STRUCTS & METHODS: Zig vs C vs Rust
// =============================================================================
//
// MENTAL MODEL:
// - C: struct hanya data. Functions terpisah, pass struct sebagai argument.
// - Rust: struct + impl block. Methods dengan self. Traits untuk behavior.
// - Zig: struct bisa punya functions di dalamnya, tapi TIDAK ada hidden "self".
//        Method adalah function yang kebetulan parameter pertamanya struct.
//
// KEY INSIGHT:
// Di Zig, tidak ada magic "self" atau "this".
// Method call `obj.method(arg)` adalah syntax sugar untuk `Type.method(&obj, arg)`
// WYSIWYG - What You See Is What You Get
// =============================================================================

const std = @import("std");

// =============================================================================
// BASIC STRUCT
// =============================================================================

const Point = struct {
    x: i32,
    y: i32,

    // "Method" - sebenarnya cuma function dengan self parameter
    // self: Point = by value (copy)
    pub fn distanceFromOrigin(self: Point) f64 {
        const x_f: f64 = @floatFromInt(self.x);
        const y_f: f64 = @floatFromInt(self.y);
        return @sqrt(x_f * x_f + y_f * y_f);
    }

    // self: *Point = by pointer (can mutate)
    pub fn translate(self: *Point, dx: i32, dy: i32) void {
        self.x += dx;
        self.y += dy;
    }

    // self: *const Point = by const pointer (read-only reference)
    pub fn print(self: *const Point) void {
        std.debug.print("Point({d}, {d})\n", .{ self.x, self.y });
    }

    // "Static" method - tidak ada self parameter
    pub fn origin() Point {
        return .{ .x = 0, .y = 0 };
    }

    // Constructor pattern
    pub fn init(x: i32, y: i32) Point {
        return .{ .x = x, .y = y };
    }
};

pub fn structBasicsDemo() void {
    // Create struct
    var p = Point.init(3, 4);

    // Method call - these two are EQUIVALENT:
    p.print(); // Syntax sugar
    Point.print(&p); // Actual function call

    // Distance
    const dist = p.distanceFromOrigin();
    std.debug.print("Distance: {d}\n", .{dist});

    // Mutate
    p.translate(2, 2);
    p.print();

    // Static method
    const origin = Point.origin();
    origin.print();
}

// =============================================================================
// COMPARISON: Method Definition
// =============================================================================
//
// C - Functions separate from struct:
//   struct Point { int x; int y; };
//   float point_distance(struct Point* p) { ... }
//   // Call: point_distance(&p);
//
// Rust - Methods in impl block:
//   struct Point { x: i32, y: i32 }
//   impl Point {
//       fn distance(&self) -> f64 { ... }
//   }
//   // Call: p.distance(); // &self is implicit
//
// Zig - Functions inside struct, explicit self:
//   const Point = struct {
//       fn distance(self: Point) f64 { ... }
//   };
//   // Call: p.distance(); atau Point.distance(p);
// =============================================================================

// =============================================================================
// DEFAULT VALUES
// =============================================================================

const Config = struct {
    port: u16 = 8080, // Default value
    host: []const u8 = "localhost", // Default value
    max_connections: u32 = 100,
    debug: bool = false,
};

pub fn defaultValuesDemo() void {
    // Partial initialization with defaults
    const config1 = Config{}; // All defaults
    const config2 = Config{ .port = 3000 }; // Override port only
    const config3 = Config{ .port = 443, .debug = true };

    std.debug.print("Config1 port: {d}\n", .{config1.port});
    std.debug.print("Config2 port: {d}\n", .{config2.port});
    std.debug.print("Config3 port: {d}, debug: {}\n", .{ config3.port, config3.debug });
}

// =============================================================================
// ANONYMOUS STRUCT & TUPLES
// =============================================================================

pub fn anonymousStructDemo() void {
    // Anonymous struct literal
    const point = .{
        .x = 10,
        .y = 20,
    };
    std.debug.print("Anonymous point: ({d}, {d})\n", .{ point.x, point.y });

    // Tuple (anonymous struct with numbered fields)
    const tuple = .{ "hello", 42, true };
    std.debug.print("Tuple: {s}, {d}, {}\n", .{ tuple[0], tuple[1], tuple[2] });

    // Function returning multiple values via anonymous struct
    const result = divmod(17, 5);
    std.debug.print("17 / 5 = {d} remainder {d}\n", .{ result.quotient, result.remainder });
}

fn divmod(a: i32, b: i32) struct { quotient: i32, remainder: i32 } {
    return .{
        .quotient = @divTrunc(a, b),
        .remainder = @rem(a, b),
    };
}

// =============================================================================
// PACKED STRUCT
// =============================================================================
// packed struct = no padding, exact memory layout
// Useful for: binary protocols, hardware registers, memory-mapped I/O
// =============================================================================

const Flags = packed struct {
    enabled: bool, // 1 bit
    mode: u2, // 2 bits
    priority: u3, // 3 bits
    _reserved: u2 = 0, // 2 bits padding to make 1 byte
};

pub fn packedStructDemo() void {
    var flags = Flags{
        .enabled = true,
        .mode = 2,
        .priority = 5,
    };

    std.debug.print("Flags size: {d} bytes\n", .{@sizeOf(Flags)});

    // Can cast to integer
    const as_byte: u8 = @bitCast(flags);
    std.debug.print("As byte: 0x{X}\n", .{as_byte});

    // Modify
    flags.priority = 7;
    std.debug.print("New priority: {d}\n", .{flags.priority});
}

// =============================================================================
// EXTERN STRUCT
// =============================================================================
// extern struct = C ABI compatible layout
// Useful for: FFI with C code
// =============================================================================

const CCompatibleStruct = extern struct {
    a: i32,
    b: i64,
    c: i32,
};

// =============================================================================
// NESTED STRUCT
// =============================================================================

const Rectangle = struct {
    top_left: Point,
    bottom_right: Point,

    pub fn width(self: Rectangle) i32 {
        return self.bottom_right.x - self.top_left.x;
    }

    pub fn height(self: Rectangle) i32 {
        return self.bottom_right.y - self.top_left.y;
    }

    pub fn area(self: Rectangle) i32 {
        return self.width() * self.height();
    }
};

pub fn nestedStructDemo() void {
    const rect = Rectangle{
        .top_left = .{ .x = 0, .y = 0 },
        .bottom_right = .{ .x = 10, .y = 5 },
    };

    std.debug.print("Rectangle: {d}x{d}, area={d}\n", .{
        rect.width(),
        rect.height(),
        rect.area(),
    });
}

// =============================================================================
// @This() - Self Reference
// =============================================================================

const Counter = struct {
    const Self = @This(); // Get type of enclosing struct

    count: i32 = 0,

    pub fn increment(self: *Self) void {
        self.count += 1;
    }

    pub fn reset(self: *Self) void {
        self.count = 0;
    }

    pub fn clone(self: Self) Self {
        return self;
    }
};

// =============================================================================
// COMPARISON: Object Creation
// =============================================================================
//
// C:
//   struct Point p = { .x = 10, .y = 20 };
//   // or
//   struct Point p;
//   p.x = 10; p.y = 20;
//
// Rust:
//   let p = Point { x: 10, y: 20 };
//
// Zig:
//   const p = Point{ .x = 10, .y = 20 };
//   // or with init function
//   const p = Point.init(10, 20);
// =============================================================================

test "struct basics" {
    var p = Point.init(3, 4);
    try std.testing.expectEqual(@as(f64, 5.0), p.distanceFromOrigin());

    p.translate(1, 1);
    try std.testing.expectEqual(@as(i32, 4), p.x);
    try std.testing.expectEqual(@as(i32, 5), p.y);
}
