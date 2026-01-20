// =============================================================================
// MEMORY MANAGEMENT: Zig vs C vs Rust
// =============================================================================
//
// MENTAL MODEL:
// - C: Manual malloc/free. Programmer 100% responsible. Easy to leak/double-free.
// - Rust: Ownership system. Compiler tracks lifetime. Borrow checker enforces rules.
// - Zig: Manual tapi EXPLICIT. Allocator harus di-pass sebagai parameter.
//        Tidak ada hidden allocation. Kamu selalu tau kapan memory dialokasi.
//
// PHILOSOPHY ZIG:
// "No hidden control flow, no hidden memory allocations"
// Berbeda dengan Rust yang "zero-cost abstractions", Zig lebih ke
// "what you see is what you get" - tidak ada magic di balik layar.
//
// UPDATE ZIG 0.15:
// - ArrayList sekarang "unmanaged" by default (tidak simpan allocator)
// - BoundedArray DIHAPUS - gunakan ArrayList dengan stack buffer
// - Lebih banyak kontrol, tapi juga lebih banyak tanggung jawab
// =============================================================================

const std = @import("std");

// =============================================================================
// ALLOCATOR PATTERN
// =============================================================================
// Di Zig, allocator SELALU di-pass explicitly. Ini berbeda dengan:
// - C: malloc() adalah global function
// - Rust: Default allocator tersembunyi di Vec, Box, dll
//
// Kenapa Zig begini?
// 1. Testability - bisa inject test allocator yang detect memory leak
// 2. Flexibility - bisa pakai different allocator untuk different use case
// 3. Transparency - selalu jelas kapan allocation terjadi
// =============================================================================

pub fn demonstrateAllocators() !void {
    // ----- ALLOCATOR TYPES -----

    // 1. Page Allocator - langsung minta ke OS
    // Cocok untuk: large allocations, long-lived data
    // Mirip dengan: mmap() di C
    const page_alloc = std.heap.page_allocator;

    // 2. General Purpose Allocator (GPA) - debug-friendly allocator
    // Cocok untuk: development, detecting memory bugs
    // Fitur: detect leaks, double-free, use-after-free
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        // defer = jalankan di akhir scope (mirip Rust's Drop, tapi explicit)
        const check = gpa.deinit();
        if (check == .leak) {
            std.debug.print("Memory leak detected!\n", .{});
        }
    }
    const gpa_alloc = gpa.allocator();

    // 3. Arena Allocator - bulk allocate, bulk free
    // Cocok untuk: request handling, parsing, temporary work
    // Mental model: "Semua allocation dalam satu batch, free sekaligus"
    var arena = std.heap.ArenaAllocator.init(page_alloc);
    defer arena.deinit(); // Free SEMUA allocation sekaligus
    const arena_alloc = arena.allocator();

    // ----- USING ALLOCATORS -----

    // Allocate single item
    const ptr = try gpa_alloc.create(i32);
    defer gpa_alloc.destroy(ptr); // WAJIB free! Zig tidak auto-free
    ptr.* = 42;

    // Allocate array/slice
    const slice = try gpa_alloc.alloc(u8, 100);
    defer gpa_alloc.free(slice);

    // Dengan arena - tidak perlu individual free
    const temp1 = try arena_alloc.alloc(u8, 50);
    const temp2 = try arena_alloc.alloc(u8, 50);
    // temp1 dan temp2 akan di-free bersamaan saat arena.deinit()
    _ = temp1;
    _ = temp2;
    _ = page_alloc;
}

// =============================================================================
// ARRAYLIST - Zig 0.15 Changes (UNMANAGED BY DEFAULT)
// =============================================================================
//
// SEBELUMNYA (Zig < 0.15):
//   var list = std.ArrayList(i32).init(allocator);
//   // ArrayList SIMPAN allocator di dalam struct
//   try list.append(1);  // Pakai internal allocator
//   list.deinit();       // Pakai internal allocator
//
// SEKARANG (Zig 0.15+):
//   ArrayList TIDAK simpan allocator (unmanaged)!
//   Kamu harus pass allocator di SETIAP operasi yang butuh allocation.
//   Ini lebih flexible tapi juga lebih verbose.
//
// Kenapa perubahan ini?
// 1. Flexibility - bisa pakai buffer dari mana saja (stack, heap, arena)
// 2. Performance - tidak perlu store pointer di struct
// 3. Clarity - jelas kapan allocation terjadi
// =============================================================================

pub fn demonstrateArrayListNew() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // ----- UNMANAGED ARRAYLIST (Default di 0.15) -----
    // Tidak simpan allocator, harus pass di setiap operasi

    var list: std.ArrayList(i32) = .empty; // Inisialisasi kosong
    defer list.deinit(allocator); // Pass allocator saat deinit!

    // Setiap append/operasi yang bisa reallocate butuh allocator
    try list.append(allocator, 1);
    try list.append(allocator, 2);
    try list.append(allocator, 3);

    // Iterate (tidak perlu allocator untuk read-only)
    for (list.items) |item| {
        std.debug.print("{d} ", .{item});
    }
    std.debug.print("\n", .{});
}

// =============================================================================
// STACK-BASED ARRAYLIST (Pengganti BoundedArray)
// =============================================================================
//
// BoundedArray DIHAPUS di Zig 0.15!
//
// SEBELUMNYA:
//   var arr = std.BoundedArray(i32, 100){};
//   try arr.append(42);
//
// SEKARANG: Pakai ArrayList dengan stack buffer
//   var buffer: [100]i32 = undefined;
//   var list = std.ArrayList(i32).initBuffer(&buffer);
//
// Keuntungan pattern baru:
// 1. Satu API untuk semua kasus (heap dan stack)
// 2. Lebih flexible - bisa mix stack buffer dengan heap fallback
// 3. Explicit tentang dari mana memory berasal
// =============================================================================

pub fn demonstrateStackArrayList() !void {
    // Stack-allocated buffer (fixed size, no heap allocation!)
    var buffer: [100]i32 = undefined;

    // ArrayList yang pakai stack buffer
    var list: std.ArrayListUnmanaged(i32) = .initBuffer(&buffer);
    // CATATAN: initBuffer tidak tersedia di semua versi
    // Alternative: manual management

    // Untuk contoh yang lebih portable:
    var list2: std.ArrayList(i32) = .empty;

    // Dengan FixedBufferAllocator untuk guarantee no heap
    var stack_buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&stack_buffer);
    const stack_allocator = fba.allocator();

    try list2.append(stack_allocator, 42);
    try list2.append(stack_allocator, 99);

    std.debug.print("Stack-based list: ", .{});
    for (list2.items) |item| {
        std.debug.print("{d} ", .{item});
    }
    std.debug.print("\n", .{});

    _ = list;
}

// =============================================================================
// COMPARISON: Dynamic Array Evolution
// =============================================================================
//
// C:
//   int* arr = malloc(10 * sizeof(int));
//   // ... gampang lupa free, atau double free
//   free(arr);
//
// Rust:
//   let arr = Vec::new(); // Allocator tersembunyi
//   // Auto-drop saat keluar scope
//
// Zig < 0.15 (Managed):
//   var arr = std.ArrayList(i32).init(allocator);
//   try arr.append(1);  // Implicit pakai stored allocator
//   defer arr.deinit(); // Implicit pakai stored allocator
//
// Zig 0.15+ (Unmanaged):
//   var arr: std.ArrayList(i32) = .empty;
//   try arr.append(allocator, 1);  // Explicit pass allocator
//   defer arr.deinit(allocator);   // Explicit pass allocator
// =============================================================================

// =============================================================================
// STACK vs HEAP
// =============================================================================
// Zig sangat jelas membedakan stack dan heap allocation:
// - Variabel biasa = stack (automatic, fast)
// - Pakai allocator = heap (manual, flexible)
//
// Di Rust, ini kadang tersembunyi (Box, Vec auto heap)
// Di C, ini juga jelas tapi gampang salah
// =============================================================================

pub fn stackVsHeap(allocator: std.mem.Allocator) !void {
    // STACK - automatic lifetime, sangat cepat
    var stack_array: [100]i32 = undefined;
    stack_array[0] = 42;
    // Otomatis "freed" saat function return

    // HEAP - manual lifetime, lebih flexible
    const heap_array = try allocator.alloc(i32, 100);
    defer allocator.free(heap_array); // WAJIB free
    heap_array[0] = 42;

    // Kapan pakai heap?
    // 1. Size tidak diketahui saat compile time
    // 2. Data perlu outlive function scope
    // 3. Data terlalu besar untuk stack
}

// =============================================================================
// SLICES - Zig's Safe Pointer
// =============================================================================
// Slice = pointer + length
// Ini cara Zig avoid buffer overflow yang sering terjadi di C
//
// C:  int* ptr; // Tidak tau panjangnya!
// Zig: []i32   // Pointer + length, bounds checked
// =============================================================================

pub fn demonstrateSlices() void {
    var array = [_]i32{ 1, 2, 3, 4, 5 };

    // Slice dari array
    const slice: []i32 = array[1..4]; // [2, 3, 4]

    // Bounds checking! Ini akan panic kalau out of bounds
    // slice[10] = 5; // Runtime error: index out of bounds

    // Const slice = immutable view
    const const_slice: []const i32 = &array;
    _ = const_slice;

    for (slice) |*item| {
        item.* *= 2; // Modify through pointer
    }
}

// =============================================================================
// LINKED LIST CHANGES (Zig 0.15)
// =============================================================================
// SinglyLinkedList dan DoublyLinkedList juga berubah!
// Sekarang Node tidak mengandung data langsung.
// Kamu harus embed Node di dalam struct data kamu.
//
// SEBELUMNYA:
//   var list = std.SinglyLinkedList(i32){};
//   var node = try allocator.create(std.SinglyLinkedList(i32).Node);
//   node.data = 42;
//
// SEKARANG:
//   const MyNode = struct {
//       value: i32,
//       node: std.SinglyLinkedList.Node = .{},  // Embed node
//   };
//   var list = std.SinglyLinkedList{};
// =============================================================================

pub const MyListNode = struct {
    value: i32,
    node: std.SinglyLinkedList.Node = .{},

    pub fn fromNode(node: *std.SinglyLinkedList.Node) *MyListNode {
        return @fieldParentPtr("node", node);
    }
};

pub fn demonstrateNewLinkedList(allocator: std.mem.Allocator) !void {
    var list: std.SinglyLinkedList = .{};

    // Create and add nodes
    const node1 = try allocator.create(MyListNode);
    node1.* = .{ .value = 10 };
    list.prepend(&node1.node);

    const node2 = try allocator.create(MyListNode);
    node2.* = .{ .value = 20 };
    list.prepend(&node2.node);

    // Iterate
    var it = list.first;
    while (it) |node| {
        const my_node = MyListNode.fromNode(node);
        std.debug.print("Value: {d}\n", .{my_node.value});
        it = node.next;
    }

    // Cleanup
    while (list.popFirst()) |node| {
        const my_node = MyListNode.fromNode(node);
        allocator.destroy(my_node);
    }
}

test "memory basics" {
    // Test allocator - special allocator yang detect memory leaks
    const allocator = std.testing.allocator;

    const ptr = try allocator.create(i32);
    defer allocator.destroy(ptr);
    ptr.* = 42;

    try std.testing.expectEqual(@as(i32, 42), ptr.*);
}

test "unmanaged arraylist" {
    const allocator = std.testing.allocator;

    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(allocator);

    try list.append(allocator, 1);
    try list.append(allocator, 2);

    try std.testing.expectEqual(@as(usize, 2), list.items.len);
}
