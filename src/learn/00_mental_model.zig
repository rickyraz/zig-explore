// =============================================================================
//                    ZIG MENTAL MODEL SUMMARY
//             Perbandingan dengan C dan Rust
//                   Updated for Zig 0.15
// =============================================================================
//
// ┌─────────────────┬────────────────────┬────────────────────┬────────────────────┐
// │    CONCEPT      │         C          │        RUST        │        ZIG         │
// ├─────────────────┼────────────────────┼────────────────────┼────────────────────┤
// │ Philosophy      │ Trust programmer   │ Safety first       │ Simple & explicit  │
// │                 │ Low-level access   │ Zero-cost abstract │ No hidden behavior │
// ├─────────────────┼────────────────────┼────────────────────┼────────────────────┤
// │ Memory          │ malloc/free        │ Ownership/Borrow   │ Explicit allocator │
// │                 │ Manual, error-prone│ Automatic, strict  │ Manual, transparent│
// ├─────────────────┼────────────────────┼────────────────────┼────────────────────┤
// │ Null Safety     │ NULL pointer       │ Option<T>          │ ?T (optional)      │
// │                 │ No enforcement     │ Must handle        │ Must handle        │
// ├─────────────────┼────────────────────┼────────────────────┼────────────────────┤
// │ Error Handling  │ Return codes       │ Result<T,E>        │ !T (error union)   │
// │                 │ Easy to ignore     │ Must handle        │ Must handle        │
// ├─────────────────┼────────────────────┼────────────────────┼────────────────────┤
// │ Generics        │ Macros/void*       │ Generics + Traits  │ comptime T: type   │
// │                 │ No type safety     │ Type safe, complex │ Type safe, simple  │
// ├─────────────────┼────────────────────┼────────────────────┼────────────────────┤
// │ Metaprogramming │ Preprocessor       │ Macros (proc/decl) │ comptime           │
// │                 │ Text substitution  │ Separate syntax    │ Same language      │
// ├─────────────────┼────────────────────┼────────────────────┼────────────────────┤
// │ Modules         │ #include (textual) │ mod + use          │ @import (returns   │
// │                 │ Header files       │ Module tree        │ struct)            │
// ├─────────────────┼────────────────────┼────────────────────┼────────────────────┤
// │ Async           │ Callbacks/threads  │ async/await        │ Colorless I/O (WIP)│
// │                 │ Manual management  │ Colored functions  │ Io interface       │
// └─────────────────┴────────────────────┴────────────────────┴────────────────────┘
//
// =============================================================================
// ZIG 0.15 MAJOR CHANGES
// =============================================================================
//
// 1. COMPILER
//    - LLVM-free self-hosted x86 backend = ~5x faster debug builds!
//    - Threaded codegen = ~50% more speedup
//    - `zig init --minimal` for minimal template
//    - `zig build --webui` for web interface
//
// 2. LANGUAGE
//    - async/await REMOVED (colorless I/O planned instead)
//    - usingnamespace REMOVED (use explicit re-export)
//    - switch on non-exhaustive enums now allowed
//    - @ptrCast can now cast *T to []u8
//    - Lossy int-to-float casts are now compile errors
//
// 3. STANDARD LIBRARY (WRITERGATE!)
//    - Reader/Writer interfaces reworked (non-generic, vtable-based)
//    - ArrayList unmanaged by default (doesn't store allocator)
//    - BoundedArray REMOVED (use ArrayList with stack buffer)
//    - Linked lists de-generified (embed Node in your struct)
//    - Many ring buffer implementations removed
//    - Formatting changes: {f} for format method, {t} for tags
//
// =============================================================================
// ZIG'S CORE PRINCIPLES
// =============================================================================
//
// 1. NO HIDDEN BEHAVIOR
//    - Tidak ada hidden memory allocation
//    - Tidak ada hidden control flow (no exceptions)
//    - Tidak ada hidden function calls (no operator overloading)
//    - Method call a.foo() = Type.foo(&a) - no magic
//
// 2. SIMPLICITY OVER FEATURES
//    - Satu cara untuk melakukan sesuatu
//    - Tidak ada macros (pakai comptime)
//    - Tidak ada inheritance (pakai composition)
//    - Tidak ada function overloading
//
// 3. EXPLICIT IS BETTER THAN IMPLICIT
//    - Allocator di-pass explicitly
//    - Error harus di-handle explicitly
//    - Type conversions harus explicit (@intCast, @floatFromInt)
//    - Buffer harus di-allocate explicitly (Writergate!)
//
// 4. COMPILE-TIME > RUNTIME
//    - Sebanyak mungkin dikerjakan saat compile
//    - comptime evaluation pakai bahasa yang sama
//    - Generics resolved at compile time
//
// =============================================================================
// SYNTAX CHEAT SHEET
// =============================================================================
//
// VARIABLES:
//   const x: i32 = 10;        // Immutable
//   var y: i32 = 10;          // Mutable
//   var z: i32 = undefined;   // Uninitialized (be careful!)
//
// FUNCTIONS:
//   fn add(a: i32, b: i32) i32 { return a + b; }
//   pub fn public_fn() void {}
//   fn generic(comptime T: type, x: T) T { return x; }
//
// TYPES:
//   i8, i16, i32, i64, i128   // Signed integers
//   u8, u16, u32, u64, u128   // Unsigned integers
//   f32, f64                   // Floats
//   bool                       // Boolean
//   []u8                       // Slice
//   [10]u8                     // Array (fixed size)
//   *u8                        // Pointer
//   ?u8                        // Optional
//   !u8                        // Error union (inferred error)
//   error{A,B}!u8              // Error union (explicit)
//
// CONTROL FLOW:
//   if (cond) { } else { }
//   while (cond) { }
//   for (items) |item| { }     // For each
//   for (0..10) |i| { }        // Range
//   switch (x) { ... }
//
// ERROR HANDLING:
//   try expr           // Propagate error
//   expr catch default // Handle with default
//   expr catch |e| {}  // Handle with block
//   if (expr) |val| {} else |err| {}
//
// OPTIONALS:
//   x orelse default   // Unwrap with default
//   x.?                // Force unwrap (panic if null)
//   if (x) |val| {}    // Safe unwrap
//
// POINTERS:
//   &x                 // Address of
//   ptr.*              // Dereference
//   ptr[0]             // Index (for slices/arrays)
//
// =============================================================================
// COMMON PATTERNS (Updated for 0.15)
// =============================================================================
//
// DEFER (cleanup):
//   const file = try openFile();
//   defer file.close();
//   // ... use file, close() called at end of scope
//
// ERRDEFER (cleanup on error):
//   const resource = try allocate();
//   errdefer deallocate(resource);
//   try mightFail();  // If fails, deallocate runs
//   return resource;  // If success, errdefer doesn't run
//
// ARENA ALLOCATOR (bulk alloc/free):
//   var arena = std.heap.ArenaAllocator.init(allocator);
//   defer arena.deinit();  // Free everything at once
//   // ... allocate many things, one free at end
//
// ARRAYLIST (0.15 - unmanaged):
//   var list: std.ArrayList(i32) = .empty;
//   defer list.deinit(allocator);      // Pass allocator!
//   try list.append(allocator, 42);    // Pass allocator!
//
// WRITER (0.15 - Writergate):
//   var buffer: [1024]u8 = undefined;   // YOU allocate buffer
//   var writer: Io.File.Writer = .init(.stdout(), io, &buffer);
//   try writer.interface.print("Hello\n", .{});
//   try writer.interface.flush();       // DON'T FORGET!
//
// CONDITIONAL COMPILATION (0.15 - no usingnamespace):
//   pub const feature = if (builtin.os.tag == .windows)
//       struct { pub fn doThing() void {} }
//   else
//       struct { pub fn doThing() void { @compileError("Windows only"); } };
//
// MIXIN (0.15 - composition):
//   const MyStruct = struct {
//       mixin: MyMixin,  // Store as field
//       pub fn mixinMethod(self: *Self) void {
//           self.mixin.method();  // Call via field
//       }
//   };
//
// =============================================================================
// FORMAT SPECIFIERS (Updated for 0.15)
// =============================================================================
//
//   {d}     - decimal integer
//   {x}     - hex lowercase
//   {X}     - hex uppercase
//   {b}     - binary
//   {s}     - string
//   {c}     - character
//   {f}     - custom format method (NEW! Required for custom formatting)
//   {t}     - enum tag / error variant (NEW!)
//   {b64}   - base64 encoding (NEW!)
//   {any}   - any type (debug format)
//   {?}     - optional value
//   {*}     - pointer address
//   {}      - default (ERROR if has custom format method!)
//
// =============================================================================
// REMOVED FEATURES IN 0.15
// =============================================================================
//
// - async/await keywords (planned: colorless I/O with Io interface)
// - usingnamespace (use explicit re-export or composition)
// - BoundedArray (use ArrayList with FixedBufferAllocator)
// - Many ring buffer implementations
// - std.fs.File reader/writer (use Io interface)
// - Old generic Writer/Reader interfaces
//
// =============================================================================

const std = @import("std");

pub fn main() void {
    std.debug.print("Read the source code for the mental model!\n", .{});
    std.debug.print("Files to study (Updated for Zig 0.15):\n", .{});
    std.debug.print("  01_memory.zig   - Memory management (ArrayList unmanaged!)\n", .{});
    std.debug.print("  02_errors.zig   - Error handling\n", .{});
    std.debug.print("  03_comptime.zig - Compile-time features\n", .{});
    std.debug.print("  04_optionals.zig- Null safety\n", .{});
    std.debug.print("  05_structs.zig  - Structs & methods\n", .{});
    std.debug.print("  06_imports.zig  - Module system (no usingnamespace!)\n", .{});
    std.debug.print("  07_io.zig       - I/O & Writergate (NEW!)\n", .{});
    std.debug.print("  08_type_coercion.zig - Type conversion & casting\n", .{});
    std.debug.print("  09_comptime_vs_runtime.zig - Comptime vs Runtime + diagrams\n", .{});
}
