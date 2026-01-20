// =============================================================================
// IMPORTS & MODULES: Zig vs C vs Rust
// =============================================================================
//
// MENTAL MODEL:
// - C: #include = text copy-paste. Header files. Linker resolves symbols.
// - Rust: mod + use. Module tree. pub controls visibility. Crate = package.
// - Zig: @import returns struct. File = implicit struct. No header files.
//
// KEY INSIGHT:
// Di Zig, setiap file adalah implicitly sebuah struct.
// @import("foo.zig") returns that file AS A STRUCT VALUE.
// Sangat elegant - import system = struct system.
//
// UPDATE ZIG 0.15:
// - `usingnamespace` keyword telah DIHAPUS!
// - Ada pattern baru untuk conditional compilation dan mixins
// =============================================================================

const std = @import("std");
const builtin = @import("builtin");

// =============================================================================
// FILE AS STRUCT
// =============================================================================
// Setiap file .zig adalah implicit struct.
// Top-level declarations jadi fields/methods dari struct tersebut.
//
// Contoh: jika foo.zig berisi:
//   pub const VALUE = 42;
//   pub fn hello() void { ... }
//   const private = 1; // Not pub, internal only
//
// Maka @import("foo.zig") returns struct:
//   struct {
//       pub const VALUE = 42;
//       pub fn hello() void { ... }
//   }
// =============================================================================

// Import standard library (package import by name)
// std adalah struct besar dengan banyak nested namespaces

// Import local file (path-based import)
// const my_module = @import("my_module.zig");

// Import from package defined in build.zig
// const my_package = @import("my_package");

// =============================================================================
// VISIBILITY: pub vs private
// =============================================================================
// - pub = visible to importers
// - no pub = private to this file only
//
// Mirip Rust: pub vs private (default)
// Beda dengan C: everything visible unless static
// =============================================================================

pub const PUBLIC_CONSTANT = 42; // Visible to importers
const PRIVATE_CONSTANT = 99; // Only visible in this file

pub fn publicFunction() void {
    // Can be called from other files
    privateHelper();
}

fn privateHelper() void {
    // Only callable from this file
    _ = PRIVATE_CONSTANT;
}

// =============================================================================
// NAMESPACE PATTERN
// =============================================================================
// Karena struct bisa punya nested types, bisa bikin namespace-like organization
// =============================================================================

pub const Math = struct {
    pub const PI = 3.14159;
    pub const E = 2.71828;

    pub fn square(x: i32) i32 {
        return x * x;
    }

    pub fn cube(x: i32) i32 {
        return x * x * x;
    }

    // Nested namespace
    pub const Trig = struct {
        pub fn sinApprox(x: f64) f64 {
            // Simple Taylor series approximation
            return x - (x * x * x) / 6.0;
        }
    };
};

pub fn namespaceDemo() void {
    // Access nested values
    std.debug.print("PI = {d}\n", .{Math.PI});
    std.debug.print("5² = {d}\n", .{Math.square(5)});
    std.debug.print("sin(0.1) ≈ {d}\n", .{Math.Trig.sinApprox(0.1)});
}

// =============================================================================
// COMPARISON: Import Syntax
// =============================================================================
//
// C:
//   #include "local.h"       // Textual inclusion
//   #include <system.h>      // System header
//   // Everything becomes global symbols
//
// Rust:
//   mod my_module;           // Declare module (looks for my_module.rs)
//   use my_module::Thing;    // Bring into scope
//   use crate::other;        // Relative to crate root
//   use std::collections::HashMap;
//
// Zig:
//   const local = @import("local.zig");   // Import file as struct
//   const thing = local.Thing;            // Access member
//   const std = @import("std");           // Standard library
//   const pkg = @import("package_name");  // External package
// =============================================================================

// =============================================================================
// @embedFile - Compile-Time File Embedding
// =============================================================================
// Embed file contents as compile-time constant
// Perfect for: templates, static assets, embedded resources
// =============================================================================

// const embedded_data = @embedFile("data.txt");
// embedded_data is now []const u8 with file contents

// =============================================================================
// CONDITIONAL COMPILATION (Zig 0.15+ Pattern)
// =============================================================================
// SEBELUMNYA (Zig < 0.15) pakai usingnamespace:
//
//   pub usingnamespace if (builtin.os.tag == .windows)
//       @import("windows_impl.zig")
//   else
//       @import("posix_impl.zig");
//
// SEKARANG (Zig 0.15+): Define variable always, guard with @compileError
// Zig tidak compute nilai constants sampai di-reference!
// =============================================================================

// Pattern 1: Always define, lazy evaluation
// Zig tidak evaluate sampai dipakai, jadi ini AMAN
pub const platform_specific_value = if (builtin.os.tag == .windows)
    @as(i32, 1) // Windows value
else if (builtin.os.tag == .linux)
    @as(i32, 2) // Linux value
else
    @as(i32, 0); // Default

// Pattern 2: Guard with @compileError for unavailable features
pub const windows_only_feature = if (builtin.os.tag == .windows)
    struct {
        pub fn doWindowsThing() void {
            // Windows-specific implementation
        }
    }
else
    struct {
        pub fn doWindowsThing() void {
            @compileError("doWindowsThing() is only available on Windows");
        }
    };

// Pattern 3: Conditional imports with re-export
const platform_impl = if (builtin.os.tag == .windows)
    struct {
        pub const SPECIAL_VALUE: i32 = 100;
        pub fn platformInit() void {}
    }
else
    struct {
        pub const SPECIAL_VALUE: i32 = 200;
        pub fn platformInit() void {}
    };

// Re-export secara explicit
pub const SPECIAL_VALUE = platform_impl.SPECIAL_VALUE;
pub const platformInit = platform_impl.platformInit;

// =============================================================================
// MIXIN PATTERN (Zig 0.15+ - tanpa usingnamespace)
// =============================================================================
// SEBELUMNYA pakai usingnamespace untuk "embed" functionality:
//
//   const MyStruct = struct {
//       value: i32,
//       pub usingnamespace ObservableMixin(@This());
//   };
//
// SEKARANG: Gunakan COMPOSITION atau explicit re-export
// =============================================================================

// ----- COMPOSITION APPROACH (Recommended) -----
// Simpan mixin sebagai field, akses via field tersebut

pub fn ObservableMixin(comptime T: type) type {
    return struct {
        callbacks: std.ArrayList(*const fn (T) void),

        const Self = @This();

        pub fn initObservable(allocator: std.mem.Allocator) Self {
            return .{
                .callbacks = std.ArrayList(*const fn (T) void).init(allocator),
            };
        }

        pub fn deinitObservable(self: *Self) void {
            self.callbacks.deinit();
        }

        pub fn subscribe(self: *Self, callback: *const fn (T) void) !void {
            try self.callbacks.append(callback);
        }

        pub fn notify(self: *Self, value: T) void {
            for (self.callbacks.items) |callback| {
                callback(value);
            }
        }
    };
}

// Penggunaan dengan composition
pub const TemperatureSensor = struct {
    temperature: f32,
    // Composition: simpan mixin sebagai field
    observable: ObservableMixin(f32),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .temperature = 0.0,
            .observable = ObservableMixin(f32).initObservable(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.observable.deinitObservable();
    }

    pub fn setTemperature(self: *Self, temp: f32) void {
        self.temperature = temp;
        // Notify observers via composition
        self.observable.notify(temp);
    }

    // Optional: convenience wrapper
    pub fn subscribe(self: *Self, callback: *const fn (f32) void) !void {
        try self.observable.subscribe(callback);
    }
};

// ----- EXPLICIT RE-EXPORT APPROACH -----
// Jika ingin methods di top-level struct

const HelperMixin = struct {
    pub fn helperMethod1() i32 {
        return 42;
    }
    pub fn helperMethod2() i32 {
        return 99;
    }
};

pub const MyStructWithHelpers = struct {
    value: i32,

    // Explicit re-export setiap method yang diinginkan
    pub const helperMethod1 = HelperMixin.helperMethod1;
    pub const helperMethod2 = HelperMixin.helperMethod2;
};

pub fn mixinDemo() void {
    // Composition usage
    // sensor.observable.subscribe(callback);
    // sensor.setTemperature(25.0);

    // Re-export usage
    const result = MyStructWithHelpers.helperMethod1();
    std.debug.print("Helper result: {d}\n", .{result});
}

// =============================================================================
// WHY USINGNAMESPACE WAS REMOVED
// =============================================================================
// 1. Name collisions - susah track dari mana symbol berasal
// 2. Tooling - IDE/LSP kesulitan provide autocomplete
// 3. Readability - kode jadi implicit, tidak jelas apa yang available
// 4. Zig philosophy - "explicit is better than implicit"
//
// Dengan pattern baru:
// - Jelas dari mana setiap symbol berasal
// - IDE bisa provide autocomplete dengan benar
// - Kode lebih readable dan maintainable
// =============================================================================

// =============================================================================
// BUILD.ZIG - Package Definition
// =============================================================================
// build.zig adalah entry point untuk Zig build system.
// Di sini kamu define:
// - Executables dan libraries
// - Dependencies
// - Module mapping (nama package -> file)
//
// Contoh module mapping di build.zig:
//
//   exe.root_module.addImport("zig_explore", b.createModule(.{
//       .root_source_file = "src/root.zig",
//   }));
//
// Setelah itu, di code bisa:
//   const zig_explore = @import("zig_explore");
// =============================================================================

// =============================================================================
// RE-EXPORTING
// =============================================================================
// Untuk expose symbols dari file lain melalui current file
// Pattern yang sering dipakai di root.zig
// =============================================================================

// Di root.zig:
// const internal = @import("internal.zig");
// pub const PublicType = internal.SomeType;  // Re-export specific
// pub const utils = @import("utils.zig");     // Re-export whole module

// =============================================================================
// CIRCULAR IMPORTS
// =============================================================================
// Zig ALLOWS circular imports!
// Karena import adalah compile-time evaluation, Zig bisa handle ini.
//
// file_a.zig:
//   const file_b = @import("file_b.zig");
//
// file_b.zig:
//   const file_a = @import("file_a.zig");
//
// Ini OK di Zig, tapi error di Rust (tanpa workaround).
// Tapi tetap hindari jika possible - makes code harder to understand.
// =============================================================================

test "namespace access" {
    try std.testing.expectEqual(@as(i32, 25), Math.square(5));
    try std.testing.expectEqual(@as(i32, 125), Math.cube(5));
}

test "explicit re-export" {
    try std.testing.expectEqual(@as(i32, 42), MyStructWithHelpers.helperMethod1());
}
