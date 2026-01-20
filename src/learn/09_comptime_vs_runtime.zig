// =============================================================================
//                    COMPTIME vs RUNTIME
//              Execution Timeline & Hardware Diagram
// =============================================================================
//
// MENTAL MODEL:
// - COMPTIME = Kode dijalankan SAAT KOMPILASI (di mesin developer)
// - RUNTIME = Kode dijalankan SAAT PROGRAM BERJALAN (di mesin user)
//
// Zig unik karena comptime dan runtime pakai BAHASA YANG SAMA.
// Tidak ada macro language terpisah seperti C atau Rust.
//
// =============================================================================

const std = @import("std");

// =============================================================================
//                         EXECUTION TIMELINE
// =============================================================================
//
//  SOURCE CODE                    COMPILATION                      EXECUTION
//  (foo.zig)                     (zig build)                    (./program)
//      │                             │                               │
//      ▼                             ▼                               ▼
// ┌─────────┐    ┌─────────────────────────────────┐    ┌─────────────────────┐
// │         │    │         COMPILE TIME            │    │     RUN TIME        │
// │  .zig   │───▶│  ┌─────────────────────────┐   │───▶│                     │
// │  files  │    │  │ 1. Parse & Tokenize     │   │    │  Program runs on    │
// │         │    │  │ 2. Semantic Analysis    │   │    │  USER'S machine     │
// └─────────┘    │  │ 3. COMPTIME Evaluation  │◀──┼──┐ │                     │
//                │  │ 4. Code Generation      │   │  │ │  Uses runtime       │
//                │  │ 5. Optimization         │   │  │ │  values from:       │
//                │  │ 6. Linking              │   │  │ │  - User input       │
//                │  └─────────────────────────┘   │  │ │  - Files            │
//                │              │                  │  │ │  - Network          │
//                │              ▼                  │  │ │  - Sensors          │
//                │     ┌───────────────┐          │  │ │                     │
//                │     │  Executable   │          │  │ └─────────────────────┘
//                │     │  (binary)     │──────────┼──┘
//                │     └───────────────┘          │
//                └────────────────────────────────┘
//
//        DEVELOPER'S MACHINE                           USER'S MACHINE
//        (atau CI server)                              (bisa berbeda OS/arch)
//
// =============================================================================

// =============================================================================
//                      HARDWARE DURING COMPILATION
// =============================================================================
//
//    DEVELOPER'S MACHINE (compile time)
//    ══════════════════════════════════
//
//    ┌─────────────────────────────────────────────────────────────────────┐
//    │                              CPU                                     │
//    │  ┌──────────────────────────────────────────────────────────────┐  │
//    │  │                    Zig Compiler                               │  │
//    │  │  ┌────────────┐  ┌────────────┐  ┌────────────────────────┐  │  │
//    │  │  │   Parser   │─▶│  Sema +    │─▶│   Code Gen (LLVM or   │  │  │
//    │  │  │            │  │  COMPTIME  │  │   self-hosted x86)    │  │  │
//    │  │  └────────────┘  └────────────┘  └────────────────────────┘  │  │
//    │  │        ▲              │ ▲                    │               │  │
//    │  └────────┼──────────────┼─┼────────────────────┼───────────────┘  │
//    │           │              │ │                    │                   │
//    └───────────┼──────────────┼─┼────────────────────┼───────────────────┘
//                │              │ │                    │
//    ┌───────────┼──────────────┼─┼────────────────────┼───────────────────┐
//    │           │              ▼ │                    ▼            RAM    │
//    │   ┌───────┴────┐   ┌──────┴─────┐      ┌──────────────┐            │
//    │   │ Source     │   │ Comptime   │      │  Generated   │            │
//    │   │ .zig files │   │ Results    │      │  Machine     │            │
//    │   │            │   │ (computed  │      │  Code        │            │
//    │   │            │   │  values)   │      │              │            │
//    │   └────────────┘   └────────────┘      └──────────────┘            │
//    └────────────────────────────────────────────────────────────────────┘
//                │                                     │
//                │              DISK                   │
//    ┌───────────┼─────────────────────────────────────┼───────────────────┐
//    │           ▼                                     ▼                   │
//    │   ┌──────────────┐                     ┌──────────────┐             │
//    │   │  foo.zig     │                     │  executable  │             │
//    │   │  bar.zig     │                     │  (binary)    │             │
//    │   │  build.zig   │                     │              │             │
//    │   └──────────────┘                     └──────────────┘             │
//    └────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                      HARDWARE DURING RUNTIME
// =============================================================================
//
//    USER'S MACHINE (run time)
//    ═════════════════════════
//
//    ┌─────────────────────────────────────────────────────────────────────┐
//    │                              CPU                                     │
//    │  ┌──────────────────────────────────────────────────────────────┐  │
//    │  │                    Your Program                               │  │
//    │  │                                                               │  │
//    │  │   Comptime values are now CONSTANTS embedded in binary       │  │
//    │  │   Runtime code executes with actual user data                │  │
//    │  │                                                               │  │
//    │  └──────────────────────────────────────────────────────────────┘  │
//    │           │                    │                    │               │
//    └───────────┼────────────────────┼────────────────────┼───────────────┘
//                │                    │                    │
//    ┌───────────┼────────────────────┼────────────────────┼───────────────┐
//    │           ▼                    ▼                    ▼        RAM    │
//    │   ┌────────────┐      ┌────────────┐      ┌────────────────┐        │
//    │   │   Stack    │      │    Heap    │      │  Static Data   │        │
//    │   │            │      │            │      │  (includes     │        │
//    │   │  Local     │      │  Dynamic   │      │   comptime     │        │
//    │   │  variables │      │  allocs    │      │   results)     │        │
//    │   └────────────┘      └────────────┘      └────────────────┘        │
//    └────────────────────────────────────────────────────────────────────┘
//                │                    │                    │
//    ┌───────────┼────────────────────┼────────────────────┼───────────────┐
//    │           ▼                    ▼                    ▼        I/O    │
//    │   ┌────────────┐      ┌────────────┐      ┌────────────────┐        │
//    │   │  Keyboard  │      │  Network   │      │     Files      │        │
//    │   │  Mouse     │      │  Socket    │      │     Disk       │        │
//    │   └────────────┘      └────────────┘      └────────────────┘        │
//    └────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    COMPARISON: C vs RUST vs ZIG
// =============================================================================
//
//                    COMPILE TIME FEATURES
//    ┌────────────────┬────────────────┬────────────────┬────────────────┐
//    │    Feature     │       C        │      Rust      │      Zig       │
//    ├────────────────┼────────────────┼────────────────┼────────────────┤
//    │ Preprocessing  │ #define, #if   │ cfg!, macros   │ comptime if    │
//    │                │ TEXT-BASED     │ AST-BASED      │ SEMANTIC       │
//    ├────────────────┼────────────────┼────────────────┼────────────────┤
//    │ Const eval     │ constexpr(C++) │ const fn       │ comptime       │
//    │                │ Limited        │ Limited        │ FULL LANGUAGE  │
//    ├────────────────┼────────────────┼────────────────┼────────────────┤
//    │ Generics       │ Macros/void*   │ <T> + Traits   │ comptime T     │
//    │                │ NO TYPE SAFETY │ Complex syntax │ Same syntax    │
//    ├────────────────┼────────────────┼────────────────┼────────────────┤
//    │ Code gen       │ X-macros       │ proc_macro     │ inline for     │
//    │                │ Ugly hacks     │ Separate crate │ Same language  │
//    ├────────────────┼────────────────┼────────────────┼────────────────┤
//    │ Type introspct │ sizeof only    │ std::any       │ @typeInfo      │
//    │                │ Very limited   │ Limited        │ Full access    │
//    └────────────────┴────────────────┴────────────────┴────────────────┘
//
// =============================================================================

// =============================================================================
//                     C COMPILATION PIPELINE
// =============================================================================
//
//    ┌─────────┐     ┌─────────────┐     ┌──────────┐     ┌─────────┐
//    │ .c/.h   │────▶│ Preprocessor│────▶│ Compiler │────▶│ Linker  │
//    │ files   │     │ (cpp)       │     │ (cc1)    │     │ (ld)    │
//    └─────────┘     └─────────────┘     └──────────┘     └─────────┘
//         │               │                   │                │
//         │               ▼                   ▼                ▼
//         │         ┌───────────┐       ┌──────────┐    ┌──────────┐
//         │         │ .i file   │       │ .o file  │    │ a.out    │
//         │         │ (expanded │       │ (object) │    │ (binary) │
//         │         │  macros)  │       │          │    │          │
//         │         └───────────┘       └──────────┘    └──────────┘
//         │
//         │   PREPROCESSOR PHASE (Text substitution!)
//         │   ════════════════════════════════════════
//         │   - #include → copy-paste file contents
//         │   - #define FOO 42 → text replace "FOO" with "42"
//         │   - #ifdef → conditional text inclusion
//         │
//         │   PROBLEMS:
//         │   - No type safety in macros
//         │   - Hard to debug (line numbers messed up)
//         │   - Namespace pollution
//         │   - Macro hygiene issues
//         ▼
//
//    // C Example: Macro "generics"
//    #define MAX(a, b) ((a) > (b) ? (a) : (b))
//
//    int x = MAX(1, 2);      // OK
//    int y = MAX(i++, j++);  // BUG! Double evaluation!
//
// =============================================================================

// =============================================================================
//                    RUST COMPILATION PIPELINE
// =============================================================================
//
//    ┌─────────┐     ┌─────────────┐     ┌──────────┐     ┌─────────┐
//    │ .rs     │────▶│ rustc       │────▶│ LLVM     │────▶│ Linker  │
//    │ files   │     │ frontend    │     │ backend  │     │         │
//    └─────────┘     └─────────────┘     └──────────┘     └─────────┘
//         │               │                   │                │
//         │               ▼                   ▼                ▼
//         │         ┌───────────┐       ┌──────────┐    ┌──────────┐
//         │         │ HIR/MIR   │       │ .o file  │    │ binary   │
//         │         │ (typed)   │       │          │    │          │
//         │         └───────────┘       └──────────┘    └──────────┘
//         │
//         │   COMPILE TIME FEATURES
//         │   ══════════════════════
//         │
//         │   1. const fn (limited evaluation)
//         │      const fn factorial(n: u64) -> u64 { ... }
//         │      const FACT_10: u64 = factorial(10);
//         │
//         │   2. Declarative macros (macro_rules!)
//         │      macro_rules! vec { ... }  // Pattern matching
//         │
//         │   3. Procedural macros (separate crate!)
//         │      #[derive(Debug)]  // Requires proc-macro crate
//         │      struct Foo { ... }
//         │
//         │   LIMITATIONS:
//         │   - const fn sangat terbatas (no loops until recently)
//         │   - proc_macro butuh crate terpisah
//         │   - Macro syntax berbeda dari Rust biasa
//         ▼
//
// =============================================================================

// =============================================================================
//                     ZIG COMPILATION PIPELINE
// =============================================================================
//
//    ┌─────────┐     ┌────────────────────────────────────┐     ┌─────────┐
//    │ .zig    │────▶│           Zig Compiler             │────▶│ binary  │
//    │ files   │     │  ┌─────┐  ┌─────┐  ┌───────────┐  │     │         │
//    └─────────┘     │  │Parse│─▶│Sema │─▶│  CodeGen  │  │     └─────────┘
//                    │  └─────┘  └──┬──┘  └───────────┘  │
//                    │              │                     │
//                    │              ▼                     │
//                    │     ┌───────────────┐             │
//                    │     │   COMPTIME    │             │
//                    │     │   Evaluator   │             │
//                    │     │               │             │
//                    │     │ Same language!│             │
//                    │     │ Full features!│             │
//                    │     └───────────────┘             │
//                    └────────────────────────────────────┘
//
//    COMPTIME FEATURES (Full Zig language!)
//    ═══════════════════════════════════════
//    - Variables, loops, functions
//    - Type manipulation
//    - Allocators (comptime allocator)
//    - String operations
//    - @import at comptime
//    - @embedFile
//    - Full type introspection
//
// =============================================================================

// =============================================================================
//              WHEN IS `comptime` KEYWORD NEEDED?
// =============================================================================
//
//    ┌─────────────────────────────────────────────────────────────────────┐
//    │                     TOP LEVEL (Module Scope)                        │
//    │                                                                     │
//    │   const x = 42;              // ✓ Otomatis comptime                 │
//    │   const y = someFunc();      // ✓ Otomatis comptime                 │
//    │   const z = comptime blk:{}; // ✗ REDUNDANT! Hapus `comptime`       │
//    │                                                                     │
//    │   Semua top-level const SUDAH comptime by default!                  │
//    └─────────────────────────────────────────────────────────────────────┘
//
//    ┌─────────────────────────────────────────────────────────────────────┐
//    │                      INSIDE FUNCTION                                │
//    │                                                                     │
//    │   pub fn foo() void {                                               │
//    │       const a = 42;                    // ✓ Comptime (literal)      │
//    │       const b = someFunc();            // ✗ RUNTIME!                │
//    │       const c = comptime someFunc();   // ✓ Comptime (forced)       │
//    │                                                                     │
//    │       comptime {                       // ✓ Comptime block          │
//    │           // Everything here is comptime                            │
//    │       }                                                             │
//    │   }                                                                 │
//    │                                                                     │
//    │   Di dalam function, `comptime` DIPERLUKAN untuk force evaluation!  │
//    └─────────────────────────────────────────────────────────────────────┘
//
//    ┌─────────────────────────────────────────────────────────────────────┐
//    │                    FUNCTION PARAMETERS                              │
//    │                                                                     │
//    │   fn generic(comptime T: type, value: T) T { ... }                  │
//    │              ^^^^^^^^                                               │
//    │              Parameter HARUS comptime-known saat dipanggil          │
//    │                                                                     │
//    │   generic(i32, 42);  // ✓ T = i32 (known at comptime)               │
//    │   generic(x, 42);    // ✗ ERROR jika x bukan comptime               │
//    └─────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                         COMPTIME EXAMPLES
// =============================================================================

// ----- 1. COMPTIME COMPUTED CONSTANT -----
// Dihitung SAAT KOMPILASI, hasil di-embed ke binary
//
// PENTING: Top-level `const` SUDAH OTOMATIS comptime!
// Tidak perlu tambah keyword `comptime` - itu REDUNDANT!
const factorial_10 = blk: {
    var result: u64 = 1;
    for (1..11) |i| {
        result *= i;
    }
    break :blk result;
};
// factorial_10 = 3628800, sudah dihitung saat compile!

// ----- 2. COMPTIME FUNCTION -----
fn comptimeFactorial(n: u64) u64 {
    var result: u64 = 1;
    for (1..n + 1) |i| {
        result *= i;
    }
    return result;
}

// Top-level const → otomatis comptime, tidak perlu keyword!
const fact_5 = comptimeFactorial(5); // 120 (computed at compile time)

// ----- 3. TYPE AS COMPTIME VALUE -----
fn GenericMax(comptime T: type) type {
    return struct {
        pub fn max(a: T, b: T) T {
            return if (a > b) a else b;
        }
    };
}

const IntMax = GenericMax(i32); // Type dibuat saat comptime!

// ----- 4. COMPTIME STRING PROCESSING -----
fn comptimeRepeat(comptime s: []const u8, comptime n: usize) *const [s.len * n]u8 {
    comptime {
        var result: [s.len * n]u8 = undefined;
        for (0..n) |i| {
            @memcpy(result[i * s.len ..][0..s.len], s);
        }
        return &result;
    }
}

const repeated = comptimeRepeat("ab", 3); // "ababab" - computed at compile time!

// ----- 5. COMPTIME TYPE INTROSPECTION -----
fn printFieldNames(comptime T: type) void {
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields) |field| {
        std.debug.print("Field: {s}\n", .{field.name});
    }
}

const Point = struct {
    x: i32,
    y: i32,
    z: i32,
};

// ----- 6. COMPTIME INSIDE FUNCTION (when keyword IS needed) -----
pub fn functionWithComptime() void {
    // Di dalam function, tanpa `comptime` = bisa jadi runtime
    // const runtime_fact = comptimeFactorial(5);  // Mungkin runtime!

    // Dengan `comptime` = PAKSA compile-time evaluation
    const forced_comptime = comptime comptimeFactorial(5); // Pasti comptime!
    std.debug.print("Forced comptime: {d}\n", .{forced_comptime});

    // Comptime block di dalam function
    comptime {
        const x = 1 + 2 + 3;
        if (x != 6) {
            @compileError("Math is broken!");
        }
    }
}

// ----- 7. COMPTIME LOOKUP TABLE -----
// Top-level const = otomatis comptime, tidak perlu keyword
const sin_table = blk: {
    var table: [360]f32 = undefined;
    for (0..360) |deg| {
        const rad = @as(f32, @floatFromInt(deg)) * std.math.pi / 180.0;
        table[deg] = @sin(rad);
    }
    break :blk table;
};
// 360 sin values computed at compile time!

// =============================================================================
//                    COMPTIME vs RUNTIME DECISION
// =============================================================================
//
//    ┌─────────────────────────────────────────────────────────────────────┐
//    │                    IS VALUE KNOWN AT COMPILE TIME?                  │
//    │                                                                     │
//    │                              │                                      │
//    │               ┌──────────────┴──────────────┐                       │
//    │               ▼                              ▼                      │
//    │         ┌─────────┐                    ┌──────────┐                 │
//    │         │   YES   │                    │    NO    │                 │
//    │         └────┬────┘                    └────┬─────┘                 │
//    │              │                              │                       │
//    │              ▼                              ▼                       │
//    │    ┌─────────────────┐            ┌─────────────────┐              │
//    │    │    COMPTIME     │            │     RUNTIME     │              │
//    │    │                 │            │                 │              │
//    │    │ • Literals      │            │ • User input    │              │
//    │    │ • const values  │            │ • File contents │              │
//    │    │ • Type params   │            │ • Network data  │              │
//    │    │ • @embedFile    │            │ • Random numbers│              │
//    │    │ • comptime vars │            │ • Time/Date     │              │
//    │    │                 │            │ • var variables │              │
//    │    └────────┬────────┘            └────────┬────────┘              │
//    │             │                              │                       │
//    │             ▼                              ▼                       │
//    │    ┌─────────────────┐            ┌─────────────────┐              │
//    │    │ Computed during │            │ Computed during │              │
//    │    │ compilation     │            │ program exec    │              │
//    │    │                 │            │                 │              │
//    │    │ Result embedded │            │ Uses CPU at     │              │
//    │    │ in binary       │            │ runtime         │              │
//    │    └─────────────────┘            └─────────────────┘              │
//    └─────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                     COMPTIME BENEFITS
// =============================================================================
//
//    1. ZERO RUNTIME COST
//       ┌────────────────────────────────────────────────────────┐
//       │  const table = comptime generateLookupTable();        │
//       │                                                        │
//       │  At runtime: table is just static data in binary      │
//       │  No computation, no allocation, instant access        │
//       └────────────────────────────────────────────────────────┘
//
//    2. CATCH ERRORS EARLY
//       ┌────────────────────────────────────────────────────────┐
//       │  const x: u8 = comptime blk: {                        │
//       │      break :blk 256;  // COMPILE ERROR! > 255         │
//       │  };                                                    │
//       │                                                        │
//       │  Error caught at compile time, not runtime crash      │
//       └────────────────────────────────────────────────────────┘
//
//    3. GENERICS WITHOUT RUNTIME OVERHEAD
//       ┌────────────────────────────────────────────────────────┐
//       │  fn sort(comptime T: type, items: []T) void { ... }   │
//       │                                                        │
//       │  Compiler generates specialized code for each T       │
//       │  No vtable, no type erasure, full optimization        │
//       └────────────────────────────────────────────────────────┘
//
//    4. CONDITIONAL COMPILATION
//       ┌────────────────────────────────────────────────────────┐
//       │  const impl = if (builtin.os.tag == .windows)         │
//       │      @import("windows.zig")                           │
//       │  else                                                  │
//       │      @import("posix.zig");                            │
//       │                                                        │
//       │  Only relevant code compiled into binary              │
//       └────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    MEMORY LAYOUT: COMPTIME vs RUNTIME
// =============================================================================
//
//    BINARY FILE (after compilation)
//    ═══════════════════════════════
//
//    ┌────────────────────────────────────────────────────────────┐
//    │                        ELF HEADER                          │
//    ├────────────────────────────────────────────────────────────┤
//    │                                                            │
//    │   .text (code)                                             │
//    │   ┌────────────────────────────────────────────────────┐  │
//    │   │  Machine instructions                              │  │
//    │   │  (generated from Zig code)                         │  │
//    │   └────────────────────────────────────────────────────┘  │
//    │                                                            │
//    │   .rodata (read-only data)                                 │
//    │   ┌────────────────────────────────────────────────────┐  │
//    │   │  COMPTIME RESULTS HERE!                            │  │
//    │   │  ─────────────────────                             │  │
//    │   │  • factorial_10 = 3628800                          │  │
//    │   │  • sin_table[360] = {...}                          │  │
//    │   │  • repeated = "ababab"                             │  │
//    │   │  • String literals                                 │  │
//    │   └────────────────────────────────────────────────────┘  │
//    │                                                            │
//    │   .data (initialized data)                                 │
//    │   ┌────────────────────────────────────────────────────┐  │
//    │   │  Global variables with initial values              │  │
//    │   └────────────────────────────────────────────────────┘  │
//    │                                                            │
//    │   .bss (uninitialized data)                                │
//    │   ┌────────────────────────────────────────────────────┐  │
//    │   │  Global variables, zero-initialized                │  │
//    │   └────────────────────────────────────────────────────┘  │
//    │                                                            │
//    └────────────────────────────────────────────────────────────┘
//
//    AT RUNTIME (in RAM)
//    ════════════════════
//
//    ┌────────────────────────────────────────────────────────────┐
//    │  HIGH ADDRESS                                              │
//    │  ┌────────────────────────────────────────────────────┐   │
//    │  │                      STACK                         │   │
//    │  │  • Local variables                                 │   │
//    │  │  • Function call frames                            │   │
//    │  │  • Return addresses                                │   │
//    │  │                   ▼ grows down                     │   │
//    │  └────────────────────────────────────────────────────┘   │
//    │                        ...                                 │
//    │  ┌────────────────────────────────────────────────────┐   │
//    │  │                      HEAP                          │   │
//    │  │                   ▲ grows up                       │   │
//    │  │  • Dynamic allocations (allocator.alloc)          │   │
//    │  │  • ArrayList buffers                               │   │
//    │  └────────────────────────────────────────────────────┘   │
//    │                        ...                                 │
//    │  ┌────────────────────────────────────────────────────┐   │
//    │  │              STATIC DATA (from binary)             │   │
//    │  │  • .rodata (comptime results, string literals)    │   │
//    │  │  • .data (initialized globals)                     │   │
//    │  │  • .bss (zero-initialized globals)                 │   │
//    │  └────────────────────────────────────────────────────┘   │
//    │  ┌────────────────────────────────────────────────────┐   │
//    │  │                 CODE (.text)                       │   │
//    │  │  • Machine instructions                            │   │
//    │  └────────────────────────────────────────────────────┘   │
//    │  LOW ADDRESS                                               │
//    └────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                        DEMO FUNCTIONS
// =============================================================================

pub fn comptimeDemo() void {
    std.debug.print("\n=== COMPTIME DEMO ===\n\n", .{});

    // Comptime constant - already computed!
    std.debug.print("factorial(10) = {d} (computed at compile time)\n", .{factorial_10});
    std.debug.print("factorial(5) = {d} (computed at compile time)\n", .{fact_5});

    // Comptime generic
    const result = IntMax.max(10, 20);
    std.debug.print("IntMax.max(10, 20) = {d}\n", .{result});

    // Comptime string
    std.debug.print("repeated string: {s}\n", .{repeated});

    // Comptime lookup table
    std.debug.print("sin(90°) = {d} (from precomputed table)\n", .{sin_table[90]});
    std.debug.print("sin(45°) = {d}\n", .{sin_table[45]});

    // Type introspection
    std.debug.print("\nPoint struct fields:\n", .{});
    printFieldNames(Point);
}

pub fn runtimeDemo() void {
    std.debug.print("\n=== RUNTIME DEMO ===\n\n", .{});

    // Runtime value - not known at compile time
    var runtime_val: i32 = undefined;
    runtime_val = 42; // Could come from user input, file, etc.

    // Runtime computation
    var sum: i32 = 0;
    for (0..@as(usize, @intCast(runtime_val))) |i| {
        sum += @intCast(i);
    }
    std.debug.print("Runtime sum(0..{d}) = {d}\n", .{ runtime_val, sum });

    // This CANNOT be comptime because value is runtime
    // const comptime_from_runtime = comptime runtime_val; // ERROR!
}

pub fn main() void {
    comptimeDemo();
    runtimeDemo();
}

test "comptime values" {
    try std.testing.expectEqual(@as(u64, 3628800), factorial_10);
    try std.testing.expectEqual(@as(u64, 120), fact_5);
    try std.testing.expectEqualStrings("ababab", repeated);
}
