// =============================================================================
//                    PRIMITIVE TYPES & VALUES
//               TypeScript vs C vs Rust vs Zig
// =============================================================================
//
// Comparison of basic data types across languages.
// Useful for developers coming from web (TS/JS) or systems (C/Rust) background.
//
// =============================================================================

const std = @import("std");

// =============================================================================
//                         TYPE SYSTEM OVERVIEW
// =============================================================================
//
//    ┌─────────────────────────────────────────────────────────────────────────┐
//    │                        TYPE SYSTEM SPECTRUM                             │
//    │                                                                         │
//    │   DYNAMIC                                            STATIC             │
//    │   (runtime type check)                        (compile-time check)      │
//    │                                                                         │
//    │   JavaScript ──────── TypeScript ──────── C ──────── Rust ──────── Zig  │
//    │        │                   │               │           │            │   │
//    │        │                   │               │           │            │   │
//    │   No compile-time     Types optional    Weak types  Strong types  Strong│
//    │   type checking       but helpful       some UB     safe          + comptime
//    │                                                                         │
//    └─────────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    1. UNDEFINED / UNINITIALIZED
// =============================================================================
//
// TypeScript: `undefined` - unintentionally missing value
//             let x: number;  // x is undefined
//             console.log(x); // undefined (runtime value)
//
// C:          Uninitialized variables have GARBAGE values!
//             int x;          // Contains random memory garbage
//             printf("%d", x); // Undefined Behavior!
//
// Rust:       Must initialize before use (compiler enforced)
//             let x: i32;     // OK to declare
//             println!("{}", x); // COMPILE ERROR: use of uninitialized
//
// Zig:        `undefined` - explicitly marks uninitialized
//             Compiler TRACKS usage, warns if read before write
// =============================================================================

pub fn undefinedDemo() void {
    // Zig: `undefined` adalah explicit marker untuk "belum diisi"
    var x: i32 = undefined;

    // BAHAYA! Membaca undefined adalah Undefined Behavior
    // std.debug.print("{d}\n", .{x}); // UB! Jangan lakukan ini!

    // Harus assign dulu sebelum dibaca
    x = 42;
    std.debug.print("After assignment: {d}\n", .{x});

    // Untuk array - bisa partial initialize
    var buffer: [10]u8 = undefined;
    buffer[0] = 'H';
    buffer[1] = 'i';
    // Sisanya masih undefined - hati-hati!
}

// =============================================================================
//                    UNDEFINED COMPARISON TABLE
// =============================================================================
//
//    ┌─────────────┬────────────────────────────────────────────────────────┐
//    │  Language   │  Uninitialized Variable Behavior                       │
//    ├─────────────┼────────────────────────────────────────────────────────┤
//    │ TypeScript  │  `undefined` - valid runtime value, can be used       │
//    │             │  let x: number | undefined;                            │
//    ├─────────────┼────────────────────────────────────────────────────────┤
//    │ C           │  GARBAGE value! Reading = Undefined Behavior          │
//    │             │  int x; printf("%d", x); // UB, bisa crash            │
//    ├─────────────┼────────────────────────────────────────────────────────┤
//    │ Rust        │  COMPILE ERROR if read before initialized             │
//    │             │  let x: i32; println!("{}", x); // Error!             │
//    ├─────────────┼────────────────────────────────────────────────────────┤
//    │ Zig         │  `undefined` keyword, reading = UB but TRACKED        │
//    │             │  var x: i32 = undefined; // Explicit intent           │
//    │             │  Debug mode: may detect reads of undefined            │
//    └─────────────┴────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    2. NULL / OPTIONAL VALUES
// =============================================================================
//
// TypeScript: `null` - intentionally missing value
//             let x: number | null = null;
//
// C:          NULL pointer (0), no null for primitives
//             int* ptr = NULL;  // Only for pointers
//             int x = ???;      // No "null" for int
//
// Rust:       Option<T> - Some(value) or None
//             let x: Option<i32> = None;
//             let y: Option<i32> = Some(42);
//
// Zig:        ?T (optional type) - value or null
//             Compiler FORCES you to handle null case!
// =============================================================================

pub fn nullDemo() void {
    // Zig: ?T = "T atau null"
    var maybe_number: ?i32 = null; // Intentionally no value
    std.debug.print("maybe_number is null: {}\n", .{maybe_number == null});

    maybe_number = 42;
    std.debug.print("maybe_number has value: {?}\n", .{maybe_number});

    // HARUS handle null case sebelum pakai!
    if (maybe_number) |value| {
        std.debug.print("Unwrapped value: {d}\n", .{value});
    } else {
        std.debug.print("Value is null\n", .{});
    }

    // Optional pointer - very common pattern
    var data: i32 = 100;
    var maybe_ptr: ?*i32 = &data;
    maybe_ptr = null; // Now it's null

    // orelse - provide default
    const with_default = maybe_number orelse 0;
    std.debug.print("With default: {d}\n", .{with_default});
}

// =============================================================================
//                    NULL COMPARISON TABLE
// =============================================================================
//
//    ┌─────────────┬─────────────────┬──────────────────────────────────────┐
//    │  Language   │  Syntax         │  Notes                               │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ TypeScript  │  null           │  Explicit null, distinct from        │
//    │             │  T | null       │  undefined. Nullable types.          │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ C           │  NULL (0)       │  Only for pointers!                  │
//    │             │  int* p = NULL; │  No null for value types.            │
//    │             │                 │  Easy to forget null check → crash   │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Rust        │  Option<T>      │  None or Some(value)                 │
//    │             │  None           │  Must pattern match to extract       │
//    │             │  Some(42)       │  Compiler enforces handling          │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Zig         │  ?T             │  null or value                       │
//    │             │  null           │  Must unwrap before use              │
//    │             │  orelse         │  Provide default if null             │
//    │             │  .?             │  Force unwrap (panic if null)        │
//    └─────────────┴─────────────────┴──────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    3. BOOLEANS
// =============================================================================
//
// TypeScript: boolean - true or false
//             Truthy/falsy: 0, "", null, undefined are falsy
//
// C:          _Bool or int (0 = false, non-zero = true)
//             No real boolean until C99 <stdbool.h>
//
// Rust:       bool - true or false (strict, no implicit conversion)
//
// Zig:        bool - true or false (strict, 1 bit conceptually)
// =============================================================================

pub fn booleanDemo() void {
    const is_active: bool = true;
    const is_disabled: bool = false;

    std.debug.print("is_active: {}\n", .{is_active});
    std.debug.print("is_disabled: {}\n", .{is_disabled});

    // Logical operations
    const and_result = is_active and is_disabled; // false
    const or_result = is_active or is_disabled; // true
    const not_result = !is_active; // false

    std.debug.print("AND: {}, OR: {}, NOT: {}\n", .{ and_result, or_result, not_result });

    // NO implicit conversion from int to bool!
    // const bad: bool = 1;  // ERROR in Zig!
    // const bad: bool = 0;  // ERROR in Zig!

    // Must be explicit
    const from_int: bool = (42 != 0); // true
    std.debug.print("from_int: {}\n", .{from_int});

    // Boolean as integer (when needed)
    const bool_as_int: u8 = @intFromBool(is_active); // 1
    std.debug.print("bool_as_int: {d}\n", .{bool_as_int});
}

// =============================================================================
//                    BOOLEAN COMPARISON TABLE
// =============================================================================
//
//    ┌─────────────┬─────────────────┬──────────────────────────────────────┐
//    │  Language   │  Type           │  Truthy/Falsy                        │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ TypeScript  │  boolean        │  YES! 0, "", null, undefined = false │
//    │             │                 │  if (0) = false, if ("hi") = true    │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ C           │  _Bool / int    │  0 = false, non-zero = true          │
//    │             │                 │  if (ptr) checks if not NULL         │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Rust        │  bool           │  NO implicit conversion              │
//    │             │                 │  if 0 {} // ERROR                    │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Zig         │  bool           │  NO implicit conversion              │
//    │             │                 │  if (0) {} // ERROR                  │
//    │             │                 │  Must use: if (x != 0) {}            │
//    └─────────────┴─────────────────┴──────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    4. NUMBERS
// =============================================================================
//
// TypeScript: number (64-bit float for everything!)
//             const x = 42;     // Actually 64-bit float
//             const y = 3.14;   // Also 64-bit float
//             Integer precision only up to 2^53
//
// C:          Multiple types with platform-dependent sizes!
//             int, long, short, char, float, double
//             sizeof(int) varies by platform!
//
// Rust:       Fixed-size types
//             i8, i16, i32, i64, i128 (signed)
//             u8, u16, u32, u64, u128 (unsigned)
//             f32, f64 (floats)
//
// Zig:        Same as Rust, plus arbitrary bit-width!
//             i8, i16, i32, i64 (signed)
//             u8, u16, u32, u64 (unsigned)
//             u7, i3, u53 - any bit width!
// =============================================================================

pub fn numberDemo() void {
    // ----- SIGNED INTEGERS -----
    const i8_val: i8 = -128; // -128 to 127
    const i16_val: i16 = -32768; // -32768 to 32767
    const i32_val: i32 = -2147483648; // ~-2 billion to ~2 billion
    const i64_val: i64 = -9223372036854775808; // Very large range

    std.debug.print("i8: {d}, i16: {d}\n", .{ i8_val, i16_val });
    std.debug.print("i32: {d}, i64: {d}\n", .{ i32_val, i64_val });

    // ----- UNSIGNED INTEGERS -----
    const u8_val: u8 = 255; // 0 to 255
    const u16_val: u16 = 65535; // 0 to 65535
    const u32_val: u32 = 4294967295; // 0 to ~4 billion
    const u64_val: u64 = 18446744073709551615; // Very large

    std.debug.print("u8: {d}, u16: {d}\n", .{ u8_val, u16_val });
    std.debug.print("u32: {d}, u64: {d}\n", .{ u32_val, u64_val });

    // ----- ARBITRARY BIT-WIDTH (Zig special!) -----
    const u3_val: u3 = 7; // 0 to 7 (3 bits)
    const u7_val: u7 = 127; // 0 to 127 (7 bits)
    const i5_val: i5 = -16; // -16 to 15 (5 bits signed)

    std.debug.print("u3: {d}, u7: {d}, i5: {d}\n", .{ u3_val, u7_val, i5_val });

    // ----- FLOATING POINT -----
    const f32_val: f32 = 3.14159; // 32-bit float
    const f64_val: f64 = 3.141592653589793; // 64-bit float (double)

    std.debug.print("f32: {d}, f64: {d}\n", .{ f32_val, f64_val });

    // ----- COMPTIME INT (unbounded!) -----
    const big_comptime = 123456789012345678901234567890; // No overflow at comptime!
    const as_u128: u128 = big_comptime; // Fits in u128
    std.debug.print("u128: {d}\n", .{as_u128});
}

// =============================================================================
//                    NUMBER COMPARISON TABLE
// =============================================================================
//
//    ┌─────────────┬────────────────────┬────────────────────────────────────┐
//    │  Language   │  Integer Types     │  Float Types                       │
//    ├─────────────┼────────────────────┼────────────────────────────────────┤
//    │ TypeScript  │  number (f64)      │  number (f64)                      │
//    │             │  bigint            │  Same type for all!                │
//    │             │  53-bit int prec   │  No separate float type            │
//    ├─────────────┼────────────────────┼────────────────────────────────────┤
//    │ C           │  char, short, int  │  float (32-bit)                    │
//    │             │  long, long long   │  double (64-bit)                   │
//    │             │  SIZE VARIES!      │  long double (80+ bit)             │
//    ├─────────────┼────────────────────┼────────────────────────────────────┤
//    │ Rust        │  i8, i16, i32, i64 │  f32 (32-bit)                      │
//    │             │  u8, u16, u32, u64 │  f64 (64-bit)                      │
//    │             │  i128, u128        │                                    │
//    │             │  isize, usize      │                                    │
//    ├─────────────┼────────────────────┼────────────────────────────────────┤
//    │ Zig         │  i8, i16, i32...   │  f16, f32, f64, f80, f128          │
//    │             │  u8, u16, u32...   │                                    │
//    │             │  ANY bit width!    │                                    │
//    │             │  u3, i7, u53...    │                                    │
//    │             │  comptime_int      │  comptime_float                    │
//    └─────────────┴────────────────────┴────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    5. BIGINT / LARGE NUMBERS
// =============================================================================
//
// TypeScript: bigint - arbitrary precision integer (ES2020)
//             const big = 9007199254740993n; // Note the 'n' suffix
//
// C:          No native support, need library (GMP)
//
// Rust:       No native bigint, need crate (num-bigint)
//
// Zig:        comptime_int - unbounded at compile time
//             u128, i128 - largest fixed runtime integers
//             No runtime bigint (need library)
// =============================================================================

pub fn bigintDemo() void {
    // Zig's largest built-in integers
    const max_u128: u128 = 340282366920938463463374607431768211455;
    const max_i128: i128 = 170141183460469231731687303715884105727;

    std.debug.print("max u128: {d}\n", .{max_u128});
    std.debug.print("max i128: {d}\n", .{max_i128});

    // At comptime, integers are unbounded!
    const huge_comptime = comptime blk: {
        var x: comptime_int = 1;
        for (0..200) |_| {
            x *= 2;
        }
        break :blk x; // 2^200, way bigger than u128!
    };
    _ = huge_comptime; // Can't print - too big for runtime!

    // For runtime bigint, you'd need a library
    std.debug.print("(For runtime bigint, use std.math.big or external library)\n", .{});
}

// =============================================================================
//                    6. STRINGS
// =============================================================================
//
// TypeScript: string - UTF-16 encoded, immutable
//             const s = "hello";
//             s.length;  // Character count (sort of)
//             s[0];      // "h"
//
// C:          char* or char[] - null-terminated byte array
//             No built-in string type, just conventions
//             char* s = "hello";  // Pointer to static string
//
// Rust:       String (owned, heap) and &str (slice, borrowed)
//             let s: String = String::from("hello");
//             let s: &str = "hello";
//
// Zig:        []const u8 - slice of bytes (UTF-8)
//             No special string type, just byte slices!
// =============================================================================

pub fn stringDemo() void {
    // String literal = pointer to static null-terminated bytes
    const literal: *const [5:0]u8 = "hello"; // Compile-time constant
    std.debug.print("literal: {s}\n", .{literal});

    // Slice (most common for strings)
    const slice: []const u8 = "hello world";
    std.debug.print("slice: {s}, len: {d}\n", .{ slice, slice.len });

    // Indexing (byte access, not character!)
    std.debug.print("First byte: {c}\n", .{slice[0]}); // 'h'

    // Multi-line string
    const multiline =
        \\Line 1
        \\Line 2
        \\Line 3
    ;
    std.debug.print("multiline:\n{s}\n", .{multiline});

    // String concatenation (comptime only!)
    const hello = "Hello, ";
    const world = "World!";
    const greeting = hello ++ world; // Comptime concatenation
    std.debug.print("greeting: {s}\n", .{greeting});

    // Runtime string operations need allocator
    // See std.ArrayList(u8) for dynamic strings
}

// =============================================================================
//                    STRING COMPARISON TABLE
// =============================================================================
//
//    ┌─────────────┬─────────────────┬──────────────────────────────────────┐
//    │  Language   │  Type           │  Notes                               │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ TypeScript  │  string         │  UTF-16, immutable                   │
//    │             │                 │  "hello".length = 5                  │
//    │             │                 │  Easy concatenation with +           │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ C           │  char*          │  Null-terminated bytes               │
//    │             │  char[]         │  No length tracking!                 │
//    │             │                 │  Manual memory management            │
//    │             │                 │  Buffer overflow danger              │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Rust        │  String         │  Owned, heap-allocated, UTF-8        │
//    │             │  &str           │  Borrowed slice, UTF-8               │
//    │             │                 │  .len() returns bytes, not chars     │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Zig         │  []const u8     │  Byte slice, usually UTF-8           │
//    │             │  [:0]const u8   │  Null-terminated (for C interop)     │
//    │             │                 │  .len is byte count                  │
//    │             │                 │  No special string operations        │
//    └─────────────┴─────────────────┴──────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    7. SYMBOLS (TypeScript specific)
// =============================================================================
//
// TypeScript: Symbol - unique identifier
//             const sym = Symbol("description");
//             obj[sym] = value;  // Hidden property
//
// C:          No equivalent (use enum or #define)
//
// Rust:       No equivalent (use enum variants)
//
// Zig:        No equivalent (use enum or comptime strings)
// =============================================================================

// Zig alternative to symbols: enums or comptime strings
const PropertyKey = enum {
    name,
    age,
    secret_value, // "hidden" by convention
};

pub fn symbolAlternativeDemo() void {
    // Use enum as "symbol-like" keys
    var properties: [3]i32 = undefined;
    properties[@intFromEnum(PropertyKey.name)] = 1;
    properties[@intFromEnum(PropertyKey.age)] = 25;
    properties[@intFromEnum(PropertyKey.secret_value)] = 42;

    std.debug.print("age property: {d}\n", .{properties[@intFromEnum(PropertyKey.age)]});
}

// =============================================================================
//                    8. OBJECTS / STRUCTS
// =============================================================================
//
// TypeScript: object - dynamic key-value pairs
//             const obj = { name: "Alice", age: 30 };
//             obj.name; obj["name"]; // Both work
//
// C:          struct - fixed layout, named fields
//             struct Person { char* name; int age; };
//
// Rust:       struct - fixed layout, named fields
//             struct Person { name: String, age: i32 }
//
// Zig:        struct - fixed layout, named fields
//             Very similar to C/Rust
// =============================================================================

const Person = struct {
    name: []const u8,
    age: u32,
    email: ?[]const u8 = null, // Optional with default

    // Methods
    pub fn greet(self: Person) void {
        std.debug.print("Hello, I'm {s}!\n", .{self.name});
    }

    pub fn isAdult(self: Person) bool {
        return self.age >= 18;
    }
};

pub fn objectDemo() void {
    // Struct literal
    const alice = Person{
        .name = "Alice",
        .age = 30,
        .email = "alice@example.com",
    };

    // Anonymous struct (like TS object literal)
    const point = .{
        .x = 10,
        .y = 20,
    };

    std.debug.print("alice.name: {s}\n", .{alice.name});
    std.debug.print("point: ({d}, {d})\n", .{ point.x, point.y });

    alice.greet();
    std.debug.print("alice is adult: {}\n", .{alice.isAdult()});

    // Tuple (anonymous struct with indices)
    const tuple = .{ "hello", 42, true };
    std.debug.print("tuple: {s}, {d}, {}\n", .{ tuple[0], tuple[1], tuple[2] });
}

// =============================================================================
//                    OBJECT COMPARISON TABLE
// =============================================================================
//
//    ┌─────────────┬─────────────────┬──────────────────────────────────────┐
//    │  Language   │  Type           │  Notes                               │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ TypeScript  │  object         │  Dynamic keys, any values            │
//    │             │  interface      │  Type declaration                    │
//    │             │  class          │  OOP with inheritance                │
//    │             │                 │  obj.prop or obj["prop"]             │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ C           │  struct         │  Fixed fields, no methods            │
//    │             │                 │  No inheritance (fake with embed)    │
//    │             │                 │  obj.field or ptr->field             │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Rust        │  struct         │  Fixed fields, impl for methods      │
//    │             │  trait          │  Interface-like behavior             │
//    │             │                 │  No inheritance, use composition     │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Zig         │  struct         │  Fixed fields, methods inside        │
//    │             │  .{ }           │  Anonymous struct literals           │
//    │             │                 │  No inheritance, no OOP              │
//    │             │                 │  Composition only                    │
//    └─────────────┴─────────────────┴──────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    9. ARRAYS / COLLECTIONS
// =============================================================================
//
// TypeScript: Array<T> or T[] - dynamic, resizable
//             const arr = [1, 2, 3];
//             arr.push(4); arr.pop();
//
// C:          Fixed arrays, or pointer + malloc
//             int arr[10];  // Fixed size
//             int* dynamic = malloc(10 * sizeof(int));
//
// Rust:       [T; N] fixed, Vec<T> dynamic
//             let arr: [i32; 3] = [1, 2, 3];
//             let vec: Vec<i32> = vec![1, 2, 3];
//
// Zig:        [N]T fixed, ArrayList(T) dynamic
// =============================================================================

pub fn arrayDemo() void {
    // Fixed-size array (stack allocated)
    var fixed: [5]i32 = .{ 1, 2, 3, 4, 5 };
    fixed[0] = 10;
    std.debug.print("fixed[0]: {d}, len: {d}\n", .{ fixed[0], fixed.len });

    // Array with inferred size
    const inferred = [_]i32{ 1, 2, 3 }; // Compiler counts: [3]i32
    std.debug.print("inferred len: {d}\n", .{inferred.len});

    // Slice (view into array)
    const slice: []const i32 = &fixed;
    std.debug.print("slice[1]: {d}\n", .{slice[1]});

    // For dynamic arrays, use ArrayList (requires allocator)
    // var list = std.ArrayList(i32).init(allocator);
}

// =============================================================================
//                    10. FUNCTIONS
// =============================================================================
//
// TypeScript: function / arrow function / method
//             function add(a: number, b: number): number { return a + b; }
//             const add = (a: number, b: number): number => a + b;
//             First-class: can pass/return functions
//
// C:          Function definition, function pointers
//             int add(int a, int b) { return a + b; }
//             int (*fn_ptr)(int, int) = add;
//
// Rust:       fn keyword, closures with |args| { body }
//             fn add(a: i32, b: i32) -> i32 { a + b }
//             let closure = |a, b| a + b;
//
// Zig:        fn keyword, function pointers
//             No closures (by design - explicit is better)
// =============================================================================

fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn applyOperation(x: i32, y: i32, op: *const fn (i32, i32) i32) i32 {
    return op(x, y);
}

pub fn functionDemo() void {
    // Direct call
    const result = add(10, 20);
    std.debug.print("add(10, 20) = {d}\n", .{result});

    // Function pointer
    const fn_ptr: *const fn (i32, i32) i32 = add;
    const result2 = fn_ptr(5, 3);
    std.debug.print("fn_ptr(5, 3) = {d}\n", .{result2});

    // Higher-order function
    const result3 = applyOperation(10, 5, add);
    std.debug.print("applyOperation(10, 5, add) = {d}\n", .{result3});

    // No closures in Zig! This is intentional.
    // Closures hide allocations and captures.
    // Instead, pass context explicitly:
    const Context = struct {
        multiplier: i32,

        pub fn multiply(self: @This(), x: i32) i32 {
            return x * self.multiplier;
        }
    };

    const ctx = Context{ .multiplier = 3 };
    const multiplied = ctx.multiply(10);
    std.debug.print("ctx.multiply(10) = {d}\n", .{multiplied});
}

// =============================================================================
//                    FUNCTION COMPARISON TABLE
// =============================================================================
//
//    ┌─────────────┬─────────────────┬──────────────────────────────────────┐
//    │  Language   │  Syntax         │  Notes                               │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ TypeScript  │  function       │  First-class functions               │
//    │             │  () => {}       │  Arrow functions / closures          │
//    │             │                 │  Captures variables automatically    │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ C           │  int fn() {}    │  No closures                         │
//    │             │  int (*ptr)()   │  Function pointers                   │
//    │             │                 │  Pass context via void*              │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Rust        │  fn name() {}   │  Functions and closures              │
//    │             │  |x| x + 1      │  Closures capture by ref/value       │
//    │             │  Fn/FnMut/FnOnce│  Trait-based closure types           │
//    ├─────────────┼─────────────────┼──────────────────────────────────────┤
//    │ Zig         │  fn name() {}   │  NO closures (by design)             │
//    │             │  *const fn      │  Function pointers                   │
//    │             │                 │  Pass context via struct             │
//    │             │                 │  Explicit > Implicit                 │
//    └─────────────┴─────────────────┴──────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    MEMORY MODEL COMPARISON
// =============================================================================
//
//    ┌──────────────────────────────────────────────────────────────────────┐
//    │                     WHERE DO VALUES LIVE?                            │
//    ├──────────────────────────────────────────────────────────────────────┤
//    │                                                                      │
//    │  TypeScript (JavaScript Engine)                                      │
//    │  ┌─────────────────────────────────────────────────────────────┐    │
//    │  │  Primitives: Stored by VALUE (stack or inline)              │    │
//    │  │  Objects:    Stored by REFERENCE (heap, garbage collected)  │    │
//    │  │                                                             │    │
//    │  │  const x = 42;        // Value on stack                     │    │
//    │  │  const obj = {a: 1};  // Reference to heap object           │    │
//    │  │                                                             │    │
//    │  │  Memory managed by GARBAGE COLLECTOR (automatic)            │    │
//    │  └─────────────────────────────────────────────────────────────┘    │
//    │                                                                      │
//    │  C                                                                   │
//    │  ┌─────────────────────────────────────────────────────────────┐    │
//    │  │  Stack:  Local variables (automatic lifetime)               │    │
//    │  │  Heap:   malloc/free (manual lifetime)                      │    │
//    │  │  Static: Global/static variables (program lifetime)         │    │
//    │  │                                                             │    │
//    │  │  int x = 42;           // Stack                             │    │
//    │  │  int* p = malloc(4);   // Heap (must free!)                 │    │
//    │  │  static int y = 10;    // Static/global                     │    │
//    │  │                                                             │    │
//    │  │  Memory managed MANUALLY (easy to leak or double-free)      │    │
//    │  └─────────────────────────────────────────────────────────────┘    │
//    │                                                                      │
//    │  Rust                                                                │
//    │  ┌─────────────────────────────────────────────────────────────┐    │
//    │  │  Stack:  Values without Box/Rc                              │    │
//    │  │  Heap:   Box<T>, Vec<T>, String, etc.                       │    │
//    │  │                                                             │    │
//    │  │  let x = 42;                // Stack                        │    │
//    │  │  let b = Box::new(42);      // Heap (auto-freed on drop)    │    │
//    │  │  let v = vec![1,2,3];       // Heap (auto-freed on drop)    │    │
//    │  │                                                             │    │
//    │  │  Memory managed by OWNERSHIP system (compile-time checks)   │    │
//    │  └─────────────────────────────────────────────────────────────┘    │
//    │                                                                      │
//    │  Zig                                                                 │
//    │  ┌─────────────────────────────────────────────────────────────┐    │
//    │  │  Stack:  Local variables (default)                          │    │
//    │  │  Heap:   allocator.alloc/free (explicit)                    │    │
//    │  │  Static: Comptime values, string literals                   │    │
//    │  │                                                             │    │
//    │  │  var x: i32 = 42;                    // Stack               │    │
//    │  │  const p = try alloc.create(i32);   // Heap (must free!)   │    │
//    │  │  defer alloc.destroy(p);            // Explicit cleanup    │    │
//    │  │  const s = "hello";                 // Static (in binary)  │    │
//    │  │                                                             │    │
//    │  │  Memory managed MANUALLY but with EXPLICIT allocator        │    │
//    │  │  No hidden allocations!                                     │    │
//    │  └─────────────────────────────────────────────────────────────┘    │
//    │                                                                      │
//    └──────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

pub fn main() void {
    std.debug.print("\n=== PRIMITIVE TYPES DEMO ===\n\n", .{});

    std.debug.print("--- Undefined ---\n", .{});
    undefinedDemo();

    std.debug.print("\n--- Null/Optional ---\n", .{});
    nullDemo();

    std.debug.print("\n--- Booleans ---\n", .{});
    booleanDemo();

    std.debug.print("\n--- Numbers ---\n", .{});
    numberDemo();

    std.debug.print("\n--- BigInt ---\n", .{});
    bigintDemo();

    std.debug.print("\n--- Strings ---\n", .{});
    stringDemo();

    std.debug.print("\n--- Objects/Structs ---\n", .{});
    objectDemo();

    std.debug.print("\n--- Arrays ---\n", .{});
    arrayDemo();

    std.debug.print("\n--- Functions ---\n", .{});
    functionDemo();
}

test "primitives" {
    // Boolean
    try std.testing.expect(true);
    try std.testing.expect(!false);

    // Optional
    const opt: ?i32 = 42;
    try std.testing.expectEqual(@as(i32, 42), opt.?);

    // Numbers
    try std.testing.expectEqual(@as(i32, 15), add(10, 5));
}
