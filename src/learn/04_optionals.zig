// =============================================================================
// OPTIONALS & NULL SAFETY: Zig vs C vs Rust
// =============================================================================
//
// MENTAL MODEL:
// - C: NULL pointer. No enforcement. Segfault waiting to happen.
// - Rust: Option<T>. Must unwrap. Very safe but verbose.
// - Zig: ?T (optional type). Must unwrap. Clean syntax.
//
// KEY INSIGHT:
// Zig tidak punya NULL pointer untuk regular pointers.
// Kalau mau express "mungkin tidak ada nilai", pakai optional: ?T
// Compiler PAKSA kamu handle case "tidak ada nilai"
// =============================================================================

const std = @import("std");

// =============================================================================
// OPTIONAL TYPE: ?T
// =============================================================================
// ?T = "T atau null"
// Harus di-unwrap sebelum dipakai
// =============================================================================

pub fn optionalBasics() void {
    // Optional integer
    var maybe_number: ?i32 = 42;
    std.debug.print("Has value: {?}\n", .{maybe_number});

    maybe_number = null;
    std.debug.print("Now null: {?}\n", .{maybe_number});

    // Optional pointer
    var data: i32 = 100;
    var maybe_ptr: ?*i32 = &data;
    std.debug.print("Pointer value: {?}\n", .{maybe_ptr});

    maybe_ptr = null;
    std.debug.print("Null pointer: {?}\n", .{maybe_ptr});
}

// =============================================================================
// UNWRAPPING OPTIONALS
// =============================================================================
// Beberapa cara untuk "unwrap" optional dan dapat nilai di dalamnya
// =============================================================================

pub fn unwrappingDemo() void {
    const maybe_value: ?i32 = 42;
    const no_value: ?i32 = null;

    // ----- IF UNWRAP -----
    // Paling safe dan idiomatic
    if (maybe_value) |value| {
        std.debug.print("Value is: {d}\n", .{value});
    } else {
        std.debug.print("No value\n", .{});
    }

    // ----- ORELSE -----
    // Provide default value (mirip Rust's unwrap_or)
    const with_default = no_value orelse 0;
    std.debug.print("With default: {d}\n", .{with_default});

    // Orelse dengan block
    const computed_default = no_value orelse blk: {
        std.debug.print("Computing default...\n", .{});
        break :blk 999;
    };
    std.debug.print("Computed: {d}\n", .{computed_default});

    // ----- .? (UNWRAP OPERATOR) -----
    // DANGER! Akan panic jika null
    // Hanya pakai kalau YAKIN tidak null
    const definitely_has_value: ?i32 = 42;
    const unwrapped = definitely_has_value.?; // Panic if null!
    std.debug.print("Unwrapped: {d}\n", .{unwrapped});

    // JANGAN LAKUKAN INI:
    // const bad = no_value.?; // PANIC!
}

// =============================================================================
// OPTIONAL POINTERS vs NULLABLE POINTERS
// =============================================================================
// Di Zig:
// - *T = pointer yang PASTI valid (tidak bisa null)
// - ?*T = pointer yang MUNGKIN null
//
// Di C:
// - T* = bisa null atau valid, compiler tidak peduli
//
// Di Rust:
// - &T = reference, pasti valid
// - Option<&T> = mungkin null
// =============================================================================

fn findValue(haystack: []const i32, needle: i32) ?*const i32 {
    for (haystack) |*item| {
        if (item.* == needle) {
            return item; // Return pointer to found item
        }
    }
    return null; // Not found
}

pub fn optionalPointerDemo() void {
    const array = [_]i32{ 1, 2, 3, 4, 5 };

    // Found case
    if (findValue(&array, 3)) |ptr| {
        std.debug.print("Found at address: {*}, value: {d}\n", .{ ptr, ptr.* });
    }

    // Not found case
    if (findValue(&array, 99)) |ptr| {
        std.debug.print("Found: {d}\n", .{ptr.*});
    } else {
        std.debug.print("Value 99 not found\n", .{});
    }
}

// =============================================================================
// COMPARISON: Null Handling
// =============================================================================
//
// C - Null checks easily forgotten:
//   int* ptr = find_value(arr, 5);
//   // Easy to forget this check!
//   if (ptr != NULL) {
//       printf("%d\n", *ptr);
//   }
//   // Or worse: printf("%d\n", *ptr); // SEGFAULT if NULL
//
// Rust - Safe but verbose:
//   let result: Option<&i32> = find_value(&arr, 5);
//   match result {
//       Some(val) => println!("{}", val),
//       None => println!("not found"),
//   }
//   // Or: result.unwrap_or(&0)
//
// Zig - Safe and concise:
//   const result = findValue(&arr, 5);
//   if (result) |val| {
//       print("{d}\n", .{val.*});
//   }
//   // Or: const val = result orelse &default;
// =============================================================================

// =============================================================================
// OPTIONAL IN STRUCTS
// =============================================================================

const Person = struct {
    name: []const u8,
    age: u32,
    // Optional field - might not have middle name
    middle_name: ?[]const u8 = null,
    // Optional pointer - might not have spouse
    spouse: ?*const Person = null,
};

pub fn optionalFieldsDemo() void {
    const john = Person{
        .name = "John",
        .age = 30,
        .middle_name = "William",
    };

    const jane = Person{
        .name = "Jane",
        .age = 28,
        // middle_name defaults to null
    };

    // Access optional fields safely
    if (john.middle_name) |middle| {
        std.debug.print("{s}'s middle name: {s}\n", .{ john.name, middle });
    }

    if (jane.middle_name) |middle| {
        std.debug.print("{s}'s middle name: {s}\n", .{ jane.name, middle });
    } else {
        std.debug.print("{s} has no middle name\n", .{jane.name});
    }
}

// =============================================================================
// SENTINEL-TERMINATED TYPES
// =============================================================================
// Zig has special types for null-terminated strings/arrays
// This bridges the gap with C while maintaining safety
// =============================================================================

pub fn sentinelDemo() void {
    // Regular slice - no null terminator
    const slice: []const u8 = "hello";

    // Sentinel-terminated - has null terminator at end
    const c_string: [:0]const u8 = "hello"; // Guaranteed null-terminated

    // Can pass to C functions safely
    _ = slice;
    std.debug.print("C string: {s}, length: {d}\n", .{ c_string, c_string.len });

    // Convert between them
    const converted: []const u8 = c_string; // OK: sentinel -> slice
    _ = converted;
    // const bad: [:0]const u8 = slice; // ERROR: slice might not have sentinel
}

// =============================================================================
// OPTIONAL CHAINING (sort of)
// =============================================================================
// Zig tidak punya ?. operator seperti TypeScript/Kotlin
// Tapi bisa achieve similar result dengan if dan orelse
// =============================================================================

const Node = struct {
    value: i32,
    next: ?*Node = null,
};

fn getSecondValue(head: ?*Node) ?i32 {
    // Manual "optional chaining"
    if (head) |h| {
        if (h.next) |next| {
            return next.value;
        }
    }
    return null;

    // In languages with ?. operator:
    // return head?.next?.value;
}

test "optional basics" {
    const some: ?i32 = 42;
    const none: ?i32 = null;

    try std.testing.expect(some != null);
    try std.testing.expect(none == null);
    try std.testing.expectEqual(@as(i32, 42), some.?);
    try std.testing.expectEqual(@as(i32, 0), none orelse 0);
}
