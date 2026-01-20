// =============================================================================
// TYPE COERCION & CONVERSION: Zig vs C vs Rust
// =============================================================================
//
// MENTAL MODEL:
// - C: Banyak implicit conversion, bahkan yang berbahaya. Silent overflow.
// - Rust: Explicit dengan `as` keyword. Safe tapi verbose.
// - Zig: Implicit hanya untuk SAFE cases. Explicit pakai builtins.
//
// PHILOSOPHY ZIG:
// "Explicit is better than implicit"
// Zig tidak akan diam-diam kehilangan data atau mengubah representasi.
// Kalau ada potensi data loss, kamu HARUS explicit.
//
// UPDATE ZIG 0.15:
// - Lossy int-to-float conversions sekarang compile-time error!
// =============================================================================

const std = @import("std");

// =============================================================================
// IMPLICIT COERCION (Safe - Diizinkan Otomatis)
// =============================================================================
// Zig mengizinkan implicit coercion HANYA jika:
// 1. Tidak ada kemungkinan data loss
// 2. Representasi semantik sama
// 3. Aman secara type safety
// =============================================================================

pub fn implicitCoercionDemo() void {
    // ----- 1. SMALLER → LARGER INTEGER -----
    // u8 pasti muat di u16, jadi aman
    const small: u8 = 200;
    const bigger: u16 = small; // ✓ Implicit OK
    const even_bigger: u32 = small; // ✓ Implicit OK
    std.debug.print("u8 → u16: {d} → {d}\n", .{ small, bigger });
    _ = even_bigger;

    // ----- 2. SIGNED → LARGER SIGNED -----
    const signed_small: i8 = -50;
    const signed_big: i16 = signed_small; // ✓ OK, sign preserved
    std.debug.print("i8 → i16: {d} → {d}\n", .{ signed_small, signed_big });

    // ----- 3. ARRAY → SLICE -----
    var array: [5]i32 = .{ 1, 2, 3, 4, 5 };
    const slice: []i32 = &array; // ✓ Array coerces to slice
    std.debug.print("Array as slice, len: {d}\n", .{slice.len});

    // ----- 4. POINTER → OPTIONAL POINTER -----
    var value: i32 = 42;
    const ptr: *i32 = &value;
    const opt_ptr: ?*i32 = ptr; // ✓ *T → ?*T
    std.debug.print("Optional ptr: {?}\n", .{opt_ptr});

    // ----- 5. MUTABLE → CONST -----
    var mutable_data: [3]u8 = .{ 'a', 'b', 'c' };
    const const_slice: []const u8 = &mutable_data; // ✓ []T → []const T
    std.debug.print("Const slice: {s}\n", .{const_slice});

    // ----- 6. COMPTIME INT → RUNTIME INT -----
    // comptime_int bisa jadi type apapun yang muat
    const from_comptime: u8 = 100; // ✓ comptime_int → u8
    const from_comptime2: i64 = 100; // ✓ comptime_int → i64
    std.debug.print("From comptime: {d}, {d}\n", .{ from_comptime, from_comptime2 });

    // ----- 7. VALUE → ERROR UNION -----
    const result: anyerror!i32 = 42; // ✓ i32 → anyerror!i32
    std.debug.print("Error union: {!}\n", .{result});

    // ----- 8. SINGLE-ITEM POINTER → MANY-ITEM POINTER -----
    var single: i32 = 10;
    const single_ptr: *i32 = &single;
    const many_ptr: [*]i32 = single_ptr; // ✓ *T → [*]T
    std.debug.print("Many ptr first: {d}\n", .{many_ptr[0]});
}

// =============================================================================
// EXPLICIT CONVERSION (Wajib Pakai Builtins)
// =============================================================================
// Untuk conversion yang MUNGKIN kehilangan data atau berubah representasi,
// Zig WAJIBKAN pakai builtin functions.
//
// List of conversion builtins:
// - @intCast      : Convert between integer types (checked)
// - @truncate     : Discard upper bits (intentional)
// - @floatCast    : Convert between float types
// - @floatFromInt : Integer → Float
// - @intFromFloat : Float → Integer
// - @intFromBool  : Bool → Integer (0 or 1)
// - @intFromEnum  : Enum → Integer
// - @intFromPtr   : Pointer → Integer
// - @ptrFromInt   : Integer → Pointer
// - @ptrCast      : Convert pointer types
// - @bitCast      : Reinterpret bits (same size types)
// - @enumFromInt  : Integer → Enum
// =============================================================================

pub fn explicitConversionDemo() void {
    // ----- @intCast: INTEGER RESIZE (CHECKED) -----
    // Akan PANIC jika nilai tidak muat!
    const big: u32 = 200;
    const small: u8 = @intCast(big); // ✓ OK, 200 muat di u8
    std.debug.print("@intCast u32→u8: {d} → {d}\n", .{ big, small });

    // const too_big: u32 = 300;
    // const will_panic: u8 = @intCast(too_big); // PANIC! 300 > 255

    // Signed ↔ Unsigned (jika range cocok)
    const positive: i32 = 100;
    const as_unsigned: u32 = @intCast(positive); // ✓ OK
    std.debug.print("i32→u32: {d} → {d}\n", .{ positive, as_unsigned });

    // const negative: i32 = -1;
    // const bad: u32 = @intCast(negative); // PANIC! Negative → unsigned

    // ----- @truncate: INTENTIONALLY DISCARD BITS -----
    // Tidak panic, sengaja buang bits atas
    const full: u32 = 0xABCD_1234;
    const low_16: u16 = @truncate(full); // Ambil 16-bit bawah
    const low_8: u8 = @truncate(full); // Ambil 8-bit bawah
    std.debug.print("@truncate: 0x{X} → 0x{X} → 0x{X}\n", .{ full, low_16, low_8 });

    // ----- @floatFromInt: INT → FLOAT -----
    const int_val: i32 = 42;
    const as_float: f64 = @floatFromInt(int_val);
    std.debug.print("@floatFromInt: {d} → {d}\n", .{ int_val, as_float });

    // ----- @intFromFloat: FLOAT → INT -----
    // Truncates decimal part (towards zero)
    const float_val: f64 = 3.99;
    const as_int: i32 = @intFromFloat(float_val); // 3, bukan 4!
    std.debug.print("@intFromFloat: {d} → {d}\n", .{ float_val, as_int });

    const negative_float: f64 = -2.7;
    const neg_int: i32 = @intFromFloat(negative_float); // -2
    std.debug.print("@intFromFloat negative: {d} → {d}\n", .{ negative_float, neg_int });

    // ----- @floatCast: FLOAT RESIZE -----
    const f64_val: f64 = 3.14159265358979;
    const f32_val: f32 = @floatCast(f64_val); // Loss of precision!
    std.debug.print("@floatCast: {d} → {d}\n", .{ f64_val, f32_val });

    // ----- @bitCast: REINTERPRET BITS -----
    // Size harus sama! Tidak ada conversion, cuma reinterpret.
    const signed: i8 = -1; // bits: 11111111
    const unsigned: u8 = @bitCast(signed); // bits: 11111111 = 255
    std.debug.print("@bitCast i8→u8: {d} → {d}\n", .{ signed, unsigned });

    const float_bits: f32 = 1.0;
    const as_u32: u32 = @bitCast(float_bits); // IEEE 754 representation
    std.debug.print("@bitCast f32→u32: {d} → 0x{X}\n", .{ float_bits, as_u32 });

    // ----- @intFromBool: BOOL → INT -----
    const is_true: bool = true;
    const is_false: bool = false;
    const true_int: u8 = @intFromBool(is_true); // 1
    const false_int: u8 = @intFromBool(is_false); // 0
    std.debug.print("@intFromBool: true={d}, false={d}\n", .{ true_int, false_int });
}

// =============================================================================
// POINTER CONVERSIONS
// =============================================================================

pub fn pointerConversionDemo() void {
    // ----- @ptrCast: CONVERT POINTER TYPES -----
    var int_val: u32 = 0xAABBCCDD;
    const int_ptr: *u32 = &int_val;

    // View as array of bytes
    const byte_ptr: *[4]u8 = @ptrCast(int_ptr);
    std.debug.print("Bytes: ", .{});
    for (byte_ptr) |b| {
        std.debug.print("{X} ", .{b});
    }
    std.debug.print("\n", .{});

    // ----- @alignCast: CHANGE ALIGNMENT -----
    // Needed when casting to type with stricter alignment
    const unaligned: [*]u8 = @ptrCast(int_ptr);
    _ = unaligned;

    // ----- @intFromPtr / @ptrFromInt -----
    const addr: usize = @intFromPtr(int_ptr);
    std.debug.print("Address as int: 0x{X}\n", .{addr});

    // const back_to_ptr: *u32 = @ptrFromInt(addr);
    // Careful! Only do this if you know the address is valid

    // ----- POINTER TO OPTIONAL -----
    const opt_ptr: ?*u32 = int_ptr; // Implicit ✓
    if (opt_ptr) |p| {
        std.debug.print("Optional unwrapped: {d}\n", .{p.*});
    }
}

// =============================================================================
// ENUM CONVERSIONS
// =============================================================================

const Color = enum(u8) {
    red = 0,
    green = 1,
    blue = 2,
};

pub fn enumConversionDemo() void {
    // ----- @intFromEnum: ENUM → INT -----
    const color: Color = .green;
    const as_int: u8 = @intFromEnum(color);
    std.debug.print("@intFromEnum: green = {d}\n", .{as_int});

    // ----- @enumFromInt: INT → ENUM -----
    const from_int: Color = @enumFromInt(2);
    std.debug.print("@enumFromInt(2) = {}\n", .{from_int}); // blue
}

// =============================================================================
// ZIG 0.15: LOSSY INT-TO-FLOAT IS NOW ERROR
// =============================================================================
//
// Beberapa integer tidak bisa direpresentasikan EXACTLY dalam float.
// f32 hanya punya 24-bit mantissa, jadi integer > 16777216 bisa kehilangan precision.
//
// SEBELUMNYA (< 0.15):
//   const f: f32 = 16777217;  // ✓ Silent precision loss!
//
// SEKARANG (0.15+):
//   const f: f32 = 16777217;  // ✗ COMPILE ERROR!
//   const f: f32 = @floatFromInt(16777217);  // ✓ Explicit
//   const f: f32 = 16777217.0;  // ✓ Float literal (you know it's approximate)
// =============================================================================

pub fn lossyFloatDemo() void {
    // Safe: this integer can be exactly represented
    const exact: f32 = 16777216; // ✓ 2^24, exactly representable
    std.debug.print("Exact: {d}\n", .{exact});

    // Would be error in 0.15 if literal:
    // const lossy: f32 = 16777217;  // ✗ ERROR in 0.15!

    // Must be explicit:
    const int_val: i32 = 16777217;
    const explicit: f32 = @floatFromInt(int_val); // ✓ You acknowledge the loss
    std.debug.print("Explicit lossy: {d}\n", .{explicit});
}

// =============================================================================
// COMPARISON TABLE
// =============================================================================
//
// ┌─────────────────────┬─────────────┬──────────────┬─────────────────────┐
// │ Conversion          │ C           │ Rust         │ Zig                 │
// ├─────────────────────┼─────────────┼──────────────┼─────────────────────┤
// │ u8 → u16            │ Implicit    │ Implicit     │ Implicit ✓          │
// │ u16 → u8            │ Implicit!   │ `as u8`      │ @intCast (checked)  │
// │ i32 → u32           │ Implicit!   │ `as u32`     │ @intCast (checked)  │
// │ f64 → i32           │ Implicit!   │ `as i32`     │ @intFromFloat       │
// │ i32 → f64           │ Implicit    │ `as f64`     │ @floatFromInt       │
// │ f64 → f32           │ Implicit!   │ `as f32`     │ @floatCast          │
// │ *T → *U             │ Implicit!   │ Unsafe block │ @ptrCast            │
// │ bool → int          │ Implicit    │ `as usize`   │ @intFromBool        │
// │ enum → int          │ Implicit    │ `as usize`   │ @intFromEnum        │
// │ bits reinterpret    │ union/cast  │ transmute    │ @bitCast            │
// └─────────────────────┴─────────────┴──────────────┴─────────────────────┘
//
// Key differences:
// - C: Almost everything implicit, many are DANGEROUS
// - Rust: Uses `as` for most conversions, unsafe for pointers
// - Zig: Different builtin for each conversion type, most are CHECKED
// =============================================================================

// =============================================================================
// PEER TYPE RESOLUTION
// =============================================================================
// Saat Zig perlu menentukan common type (misal di if/else atau array),
// dia akan mencoba menemukan "peer type" yang bisa menampung semua values.
// =============================================================================

pub fn peerTypeDemo() void {
    const a: u8 = 10;
    const b: u16 = 1000;

    // Zig finds common type: u16 (can hold both)
    const result = if (true) a else b; // Type: u16
    std.debug.print("Peer type result: {d}, type: {s}\n", .{ result, @typeName(@TypeOf(result)) });

    // Array dengan mixed types
    const mixed = [_]i32{ 1, 2, 3 }; // comptime_int → i32
    std.debug.print("Mixed array type: {s}\n", .{@typeName(@TypeOf(mixed))});

    // Optional peer resolution
    var maybe: ?u32 = null;
    maybe = 42; // u32 coerces to ?u32
    std.debug.print("Optional: {?}\n", .{maybe});
}

// =============================================================================
// WHEN COERCION FAILS - COMMON ERRORS
// =============================================================================

pub fn commonErrorsDemo() void {
    // ERROR 1: Larger → Smaller without explicit cast
    // const big: u32 = 1000;
    // const small: u8 = big;  // ✗ ERROR: cannot coerce

    // FIX:
    const big: u32 = 100;
    const small: u8 = @intCast(big); // ✓
    _ = small;

    // ERROR 2: Signed → Unsigned (or vice versa) directly
    // const signed: i32 = -5;
    // const unsigned: u32 = signed;  // ✗ ERROR

    // FIX (if you know it's positive):
    const positive: i32 = 5;
    const as_unsigned: u32 = @intCast(positive); // ✓
    _ = as_unsigned;

    // ERROR 3: Float literal to int
    // const x: i32 = 3.14;  // ✗ ERROR

    // FIX:
    const x: i32 = @intFromFloat(3.14); // ✓ = 3
    _ = x;

    // ERROR 4: Incompatible pointer types
    // var a: u32 = 10;
    // const p: *u8 = &a;  // ✗ ERROR

    // FIX:
    var a: u32 = 10;
    const p: *u8 = @ptrCast(&a); // ✓ (first byte)
    _ = p;
}

// =============================================================================
// BEST PRACTICES
// =============================================================================
//
// 1. Prefer implicit coercion when possible (it's safe)
// 2. Use @intCast for integer conversions (it's checked at runtime)
// 3. Use @truncate ONLY when you intentionally want to discard bits
// 4. Use @bitCast for same-size reinterpretation (no conversion)
// 5. Be careful with @intFromFloat - it truncates towards zero
// 6. Consider using comptime to catch conversion errors early
// 7. When in doubt, be explicit - future readers will thank you
//
// =============================================================================

test "implicit coercion" {
    const a: u8 = 100;
    const b: u16 = a;
    try std.testing.expectEqual(@as(u16, 100), b);
}

test "explicit conversion" {
    const big: u32 = 200;
    const small: u8 = @intCast(big);
    try std.testing.expectEqual(@as(u8, 200), small);
}

test "bitcast" {
    const signed: i8 = -1;
    const unsigned: u8 = @bitCast(signed);
    try std.testing.expectEqual(@as(u8, 255), unsigned);
}

test "float conversion" {
    const f: f64 = 3.7;
    const i: i32 = @intFromFloat(f);
    try std.testing.expectEqual(@as(i32, 3), i); // Truncated, not rounded!
}
