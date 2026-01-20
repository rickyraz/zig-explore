// =============================================================================
//            TCP/IP ILLUSTRATED VOL 2: THE IMPLEMENTATION
//                Data Structures & Algorithms dari BSD
// =============================================================================
//
// Buku: "TCP/IP Illustrated, Volume 2: The Implementation"
//       - Gary R. Wright, W. Richard Stevens
//
// Volume 2 fokus pada ACTUAL CODE dari 4.4BSD-Lite.
// Ini blueprint untuk implementasi kamu.
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;

// =============================================================================
//                    MBUF - MEMORY BUFFER (Chapter 2)
// =============================================================================
//
// BSD menggunakan "mbuf" sebagai fundamental data structure untuk packets.
// Ini SANGAT PENTING - hampir semua network code pakai mbuf.
//
// =============================================================================

//    ┌───────────────────────────────────────────────────────────────────────┐
//    │                         MBUF STRUCTURE                                │
//    │                                                                       │
//    │   Small packet (< 208 bytes) - data in mbuf itself:                   │
//    │   ┌─────────────────────────────────────────────────────────────┐    │
//    │   │  m_next     │ → next mbuf in chain                         │    │
//    │   │  m_nextpkt  │ → next packet in queue                       │    │
//    │   │  m_data     │ → pointer to data                            │    │
//    │   │  m_len      │   length of data                             │    │
//    │   │  m_type     │   type (data, header, etc)                   │    │
//    │   │  m_flags    │   flags                                      │    │
//    │   ├─────────────────────────────────────────────────────────────┤    │
//    │   │             │                                              │    │
//    │   │   PKTHDR    │   (if M_PKTHDR flag set)                     │    │
//    │   │   - len     │   total packet length                        │    │
//    │   │   - rcvif   │   received interface                         │    │
//    │   │             │                                              │    │
//    │   ├─────────────────────────────────────────────────────────────┤    │
//    │   │             │                                              │    │
//    │   │   DATA      │   ← m_data points here                       │    │
//    │   │  (up to     │                                              │    │
//    │   │   208 B)    │                                              │    │
//    │   │             │                                              │    │
//    │   └─────────────────────────────────────────────────────────────┘    │
//    │                                                                       │
//    │   Large packet - data in separate cluster:                            │
//    │   ┌─────────────┐           ┌─────────────────────────────────┐      │
//    │   │   MBUF      │           │        CLUSTER (2048 B)         │      │
//    │   │  m_data ────┼──────────▶│                                 │      │
//    │   │  m_ext.buf ─┼──────────▶│        actual data              │      │
//    │   │  M_EXT flag │           │                                 │      │
//    │   └─────────────┘           └─────────────────────────────────┘      │
//    │                                                                       │
//    │   Mbuf chain (large packet spanning multiple mbufs):                  │
//    │   ┌───────┐     ┌───────┐     ┌───────┐                              │
//    │   │ mbuf  │────▶│ mbuf  │────▶│ mbuf  │────▶ NULL                    │
//    │   │ data  │     │ data  │     │ data  │                              │
//    │   └───────┘     └───────┘     └───────┘                              │
//    │   m_next        m_next        m_next                                  │
//    │                                                                       │
//    └───────────────────────────────────────────────────────────────────────┘

/// Simplified mbuf-like structure for Zig
pub const Mbuf = struct {
    next: ?*Mbuf,           // Next mbuf in chain
    next_packet: ?*Mbuf,    // Next packet in queue
    data: [*]u8,            // Pointer to data
    len: u32,               // Length of data in this mbuf
    pkt_len: u32,           // Total packet length (first mbuf only)
    flags: Flags,

    // If external buffer
    ext_buf: ?[]u8,

    // Inline data for small packets
    inline_data: [256]u8,

    pub const Flags = packed struct {
        pkthdr: bool,       // First mbuf of packet
        ext: bool,          // External storage
        _padding: u6 = 0,
    };

    pub fn init() Mbuf {
        var m: Mbuf = undefined;
        m.next = null;
        m.next_packet = null;
        m.len = 0;
        m.pkt_len = 0;
        m.flags = .{ .pkthdr = false, .ext = false };
        m.ext_buf = null;
        m.data = &m.inline_data;
        return m;
    }

    /// Prepend space at beginning (for adding headers)
    pub fn prepend(self: *Mbuf, size: u32) ?[*]u8 {
        const data_start = @intFromPtr(self.data);
        const buf_start = @intFromPtr(&self.inline_data);
        const available = data_start - buf_start;

        if (available < size) return null;

        self.data -= size;
        self.len += size;
        return self.data;
    }

    /// Get contiguous data
    pub fn getData(self: *Mbuf) []u8 {
        return self.data[0..self.len];
    }
};

// =============================================================================
//                    SOCKET LAYER (Chapter 15-16)
// =============================================================================
//
// Socket = Interface antara application dan network stack
//
// =============================================================================

//    ┌───────────────────────────────────────────────────────────────────────┐
//    │                      SOCKET ARCHITECTURE                              │
//    │                                                                       │
//    │   Application                                                         │
//    │       │                                                               │
//    │       │ socket(), bind(), listen(), accept(), connect()               │
//    │       │ send(), recv(), sendto(), recvfrom()                          │
//    │       ▼                                                               │
//    │   ┌─────────────────────────────────────────────────────────────┐    │
//    │   │                     SOCKET LAYER                             │    │
//    │   │                                                              │    │
//    │   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │    │
//    │   │  │  Socket  │ │  Socket  │ │  Socket  │ │  Socket  │       │    │
//    │   │  │  (TCP)   │ │  (UDP)   │ │  (RAW)   │ │  (TCP)   │       │    │
//    │   │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       │    │
//    │   │       │            │            │            │              │    │
//    │   └───────┼────────────┼────────────┼────────────┼──────────────┘    │
//    │           │            │            │            │                    │
//    │   ┌───────┼────────────┼────────────┼────────────┼──────────────┐    │
//    │   │       ▼            ▼            │            ▼              │    │
//    │   │   ┌───────┐    ┌───────┐        │        ┌───────┐         │    │
//    │   │   │  TCP  │    │  UDP  │        │        │  TCP  │         │    │
//    │   │   │Protocol    │Protocol        │        │Protocol         │    │
//    │   │   └───┬───┘    └───┬───┘        │        └───┬───┘         │    │
//    │   │       │            │            │            │              │    │
//    │   │       └────────────┴────────────┼────────────┘              │    │
//    │   │                    │            │                           │    │
//    │   │                    ▼            ▼                           │    │
//    │   │               ┌─────────────────────┐                       │    │
//    │   │               │         IP          │                       │    │
//    │   │               └─────────────────────┘                       │    │
//    │   │                         │                                   │    │
//    │   │               PROTOCOL LAYER                                │    │
//    │   └─────────────────────────────────────────────────────────────┘    │
//    │                                                                       │
//    └───────────────────────────────────────────────────────────────────────┘

pub const Socket = struct {
    type: SocketType,
    protocol: Protocol,
    state: State,

    // Addresses
    local_addr: ?Address,
    remote_addr: ?Address,

    // Buffers
    send_buf: SendBuffer,
    recv_buf: RecvBuffer,

    // Protocol-specific control block
    pcb: ProtocolControlBlock,

    pub const SocketType = enum {
        stream,     // SOCK_STREAM (TCP)
        dgram,      // SOCK_DGRAM (UDP)
        raw,        // SOCK_RAW
    };

    pub const Protocol = enum {
        tcp,
        udp,
        icmp,
        raw,
    };

    pub const State = enum {
        unconnected,
        bound,
        listening,
        connecting,
        connected,
        disconnecting,
        closed,
    };

    pub const Address = struct {
        ip: u32,
        port: u16,
    };

    pub const SendBuffer = struct {
        data: std.ArrayList(u8),
        high_water: usize,      // Max size
        low_water: usize,       // Wake up writer when below this

        pub fn init(allocator: Allocator) SendBuffer {
            return .{
                .data = std.ArrayList(u8).init(allocator),
                .high_water = 65536,
                .low_water = 2048,
            };
        }
    };

    pub const RecvBuffer = struct {
        data: std.ArrayList(u8),
        high_water: usize,
        low_water: usize,

        pub fn init(allocator: Allocator) RecvBuffer {
            return .{
                .data = std.ArrayList(u8).init(allocator),
                .high_water = 65536,
                .low_water = 1,
            };
        }
    };

    pub const ProtocolControlBlock = union {
        tcp: *TCPControlBlock,
        udp: *UDPControlBlock,
        none: void,
    };
};

// =============================================================================
//                    TCP CONTROL BLOCK (Chapter 24-30)
// =============================================================================
//
// Setiap TCP connection punya "tcpcb" yang menyimpan semua state
//
// =============================================================================

pub const TCPControlBlock = struct {
    // Connection state
    state: TCPState,

    // Send sequence variables
    snd_una: u32,       // Oldest unacknowledged seq
    snd_nxt: u32,       // Next seq to send
    snd_wnd: u32,       // Send window
    snd_wl1: u32,       // Seq of last window update
    snd_wl2: u32,       // Ack of last window update
    iss: u32,           // Initial send seq

    // Receive sequence variables
    rcv_nxt: u32,       // Next seq expected
    rcv_wnd: u32,       // Receive window
    irs: u32,           // Initial receive seq

    // Timing
    rtt_estimator: RTTEstimator,
    idle_time: i64,
    rxtcur: u32,        // Current retransmit timeout

    // Congestion control
    snd_cwnd: u32,      // Congestion window
    snd_ssthresh: u32,  // Slow start threshold

    // Flags
    flags: Flags,

    // Retransmission queue
    // retransmit_queue: ...,

    // Out-of-order segments
    // ooo_queue: ...,

    pub const TCPState = enum {
        closed,
        listen,
        syn_sent,
        syn_received,
        established,
        close_wait,
        fin_wait_1,
        fin_wait_2,
        closing,
        last_ack,
        time_wait,
    };

    pub const Flags = packed struct {
        nodelay: bool,          // Disable Nagle
        keepalive: bool,        // Send keepalives
        fin_sent: bool,
        fin_received: bool,
        _padding: u4 = 0,
    };

    pub const RTTEstimator = struct {
        srtt: i32,          // Smoothed RTT (scaled by 8)
        rttvar: i32,        // RTT variance (scaled by 4)

        pub fn update(self: *RTTEstimator, rtt: i32) void {
            // Jacobson's algorithm
            var delta = rtt - (self.srtt >> 3);
            self.srtt += delta;

            if (delta < 0) delta = -delta;
            delta -= self.rttvar >> 2;
            self.rttvar += delta;
        }

        pub fn getRTO(self: RTTEstimator) u32 {
            // RTO = srtt + 4 * rttvar
            const rto = (self.srtt >> 3) + self.rttvar;
            // Clamp between 200ms and 120s
            return @intCast(@max(200, @min(120000, rto)));
        }
    };
};

pub const UDPControlBlock = struct {
    // UDP is simple - just local/remote addresses
    // No connection state needed!
};

// =============================================================================
//                    PROTOCOL SWITCH TABLE (Chapter 7)
// =============================================================================
//
// BSD menggunakan "protosw" table untuk dispatch ke protocol handlers
//
// =============================================================================

pub const ProtocolSwitch = struct {
    input: *const fn (packet: *Mbuf) void,
    output: *const fn (packet: *Mbuf, dst: Socket.Address) anyerror!void,
    ctlinput: ?*const fn (code: u8, arg: *anyopaque) void,
    ctloutput: ?*const fn (op: u8, socket: *Socket) anyerror!void,
    timer: ?*const fn () void,
    drain: ?*const fn () void,
};

// Protocol switch table
pub const protocol_table = [_]struct {
    protocol: u8,
    switch_fn: ProtocolSwitch,
}{
    .{ .protocol = 6, .switch_fn = tcp_protosw },   // TCP
    .{ .protocol = 17, .switch_fn = udp_protosw },  // UDP
    .{ .protocol = 1, .switch_fn = icmp_protosw },  // ICMP
};

// Placeholder protocol switches
const tcp_protosw = ProtocolSwitch{
    .input = tcpInput,
    .output = tcpOutput,
    .ctlinput = null,
    .ctloutput = null,
    .timer = tcpSlowTimer,
    .drain = null,
};

const udp_protosw = ProtocolSwitch{
    .input = udpInput,
    .output = udpOutput,
    .ctlinput = null,
    .ctloutput = null,
    .timer = null,
    .drain = null,
};

const icmp_protosw = ProtocolSwitch{
    .input = icmpInput,
    .output = icmpOutput,
    .ctlinput = null,
    .ctloutput = null,
    .timer = null,
    .drain = null,
};

// Stub implementations
fn tcpInput(packet: *Mbuf) void { _ = packet; }
fn tcpOutput(packet: *Mbuf, dst: Socket.Address) !void { _ = packet; _ = dst; }
fn tcpSlowTimer() void {}
fn udpInput(packet: *Mbuf) void { _ = packet; }
fn udpOutput(packet: *Mbuf, dst: Socket.Address) !void { _ = packet; _ = dst; }
fn icmpInput(packet: *Mbuf) void { _ = packet; }
fn icmpOutput(packet: *Mbuf, dst: Socket.Address) !void { _ = packet; _ = dst; }

// =============================================================================
//                    ROUTING TABLE (Chapter 18-19)
// =============================================================================
//
// BSD uses radix tree untuk routing lookup (O(address bits))
// Simpler implementation: hash table atau linear search untuk small tables
//
// =============================================================================

pub const RouteEntry = struct {
    destination: u32,       // Network address
    netmask: u32,           // Network mask
    gateway: u32,           // Next hop
    interface: u16,         // Output interface index
    flags: Flags,
    metrics: Metrics,

    pub const Flags = packed struct {
        up: bool,           // Route is usable
        gateway: bool,      // Destination is a gateway
        host: bool,         // Host route (not network)
        reject: bool,       // Reject route
        _padding: u4 = 0,
    };

    pub const Metrics = struct {
        mtu: u16,           // MTU for this route
        hopcount: u8,
        rtt: u32,           // Round trip time estimate
    };

    pub fn matches(self: RouteEntry, dst: u32) bool {
        return (dst & self.netmask) == self.destination;
    }
};

pub const RoutingTable = struct {
    entries: std.ArrayList(RouteEntry),
    default_route: ?RouteEntry,

    pub fn init(allocator: Allocator) RoutingTable {
        return .{
            .entries = std.ArrayList(RouteEntry).init(allocator),
            .default_route = null,
        };
    }

    pub fn lookup(self: *RoutingTable, dst: u32) ?*RouteEntry {
        // Longest prefix match
        var best_match: ?*RouteEntry = null;
        var best_prefix_len: u32 = 0;

        for (self.entries.items) |*entry| {
            if (entry.matches(dst)) {
                const prefix_len = @popCount(entry.netmask);
                if (prefix_len > best_prefix_len) {
                    best_prefix_len = prefix_len;
                    best_match = entry;
                }
            }
        }

        if (best_match) |m| return m;
        if (self.default_route) |*d| return d;
        return null;
    }
};

// =============================================================================
//                    TIMER MANAGEMENT (Chapter 25)
// =============================================================================
//
// BSD has two TCP timers:
// - Fast timer: 200ms (delayed ACK, etc)
// - Slow timer: 500ms (retransmit, keepalive, etc)
//
// =============================================================================

pub const TimerWheel = struct {
    // Simple timer wheel for connection timeouts
    const WHEEL_SIZE = 256;
    const TICK_MS = 100;

    slots: [WHEEL_SIZE]std.ArrayList(*TCPControlBlock),
    current_slot: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator) TimerWheel {
        var tw: TimerWheel = undefined;
        tw.allocator = allocator;
        tw.current_slot = 0;
        for (&tw.slots) |*slot| {
            slot.* = std.ArrayList(*TCPControlBlock).init(allocator);
        }
        return tw;
    }

    pub fn schedule(self: *TimerWheel, tcb: *TCPControlBlock, timeout_ms: u32) void {
        const ticks = timeout_ms / TICK_MS;
        const slot = (self.current_slot + ticks) % WHEEL_SIZE;
        self.slots[slot].append(tcb) catch {};
    }

    pub fn tick(self: *TimerWheel) []const *TCPControlBlock {
        const expired = self.slots[self.current_slot].items;
        self.slots[self.current_slot].clearRetainingCapacity();
        self.current_slot = (self.current_slot + 1) % WHEEL_SIZE;
        return expired;
    }
};

// =============================================================================
//                    INPUT/OUTPUT PROCESSING FLOW
// =============================================================================
//
//    ┌───────────────────────────────────────────────────────────────────────┐
//    │                      PACKET INPUT FLOW                                │
//    │                                                                       │
//    │   Network Interface                                                   │
//    │       │                                                               │
//    │       │ Interrupt / Poll                                              │
//    │       ▼                                                               │
//    │   ┌─────────────────┐                                                │
//    │   │  if_input()     │  Receive frame from hardware                   │
//    │   │  DMA to mbuf    │                                                │
//    │   └────────┬────────┘                                                │
//    │            │                                                          │
//    │            ▼                                                          │
//    │   ┌─────────────────┐                                                │
//    │   │  ether_input()  │  Strip Ethernet header                         │
//    │   │  Check ethertype│  Route to IP/ARP/etc                           │
//    │   └────────┬────────┘                                                │
//    │            │                                                          │
//    │            ▼                                                          │
//    │   ┌─────────────────┐                                                │
//    │   │  ip_input()     │  Validate IP header                            │
//    │   │  Check checksum │  Reassemble fragments                          │
//    │   │  Route lookup   │  Forward or deliver locally                    │
//    │   └────────┬────────┘                                                │
//    │            │                                                          │
//    │            ├─────────────────────┬─────────────────────┐             │
//    │            ▼                     ▼                     ▼             │
//    │   ┌─────────────┐       ┌─────────────┐       ┌─────────────┐       │
//    │   │ tcp_input() │       │ udp_input() │       │icmp_input() │       │
//    │   │             │       │             │       │             │       │
//    │   │ State mach  │       │ Demux port  │       │ Handle msg  │       │
//    │   │ Deliver data│       │ Deliver data│       │             │       │
//    │   └─────────────┘       └─────────────┘       └─────────────┘       │
//    │                                                                       │
//    └───────────────────────────────────────────────────────────────────────┘
//
//    ┌───────────────────────────────────────────────────────────────────────┐
//    │                      PACKET OUTPUT FLOW                               │
//    │                                                                       │
//    │   Application                                                         │
//    │       │                                                               │
//    │       │ send() / write()                                              │
//    │       ▼                                                               │
//    │   ┌─────────────────┐                                                │
//    │   │  sosend()       │  Copy data to socket buffer                    │
//    │   └────────┬────────┘                                                │
//    │            │                                                          │
//    │            ▼                                                          │
//    │   ┌─────────────────┐                                                │
//    │   │  tcp_output()   │  Segment data                                  │
//    │   │  or udp_output()│  Add TCP/UDP header                            │
//    │   └────────┬────────┘                                                │
//    │            │                                                          │
//    │            ▼                                                          │
//    │   ┌─────────────────┐                                                │
//    │   │  ip_output()    │  Add IP header                                 │
//    │   │  Fragment if    │  Route lookup                                  │
//    │   │  needed         │                                                │
//    │   └────────┬────────┘                                                │
//    │            │                                                          │
//    │            ▼                                                          │
//    │   ┌─────────────────┐                                                │
//    │   │  if_output()    │  Add link-layer header                         │
//    │   │  Queue to       │  ARP resolution if needed                      │
//    │   │  interface      │                                                │
//    │   └────────┬────────┘                                                │
//    │            │                                                          │
//    │            ▼                                                          │
//    │   Network Interface (transmit)                                        │
//    │                                                                       │
//    └───────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    IMPLEMENTATION ARCHITECTURE
// =============================================================================
//
//    RECOMMENDED FILE STRUCTURE:
//
//    src/
//    ├── net/
//    │   ├── mbuf.zig          # Buffer management
//    │   ├── socket.zig        # Socket API
//    │   ├── if.zig            # Interface abstraction
//    │   └── route.zig         # Routing table
//    │
//    ├── netinet/
//    │   ├── ip.zig            # IP input/output/fragmentation
//    │   ├── ip_icmp.zig       # ICMP handling
//    │   ├── tcp.zig           # TCP main logic
//    │   ├── tcp_input.zig     # TCP segment processing
//    │   ├── tcp_output.zig    # TCP segment generation
//    │   ├── tcp_timer.zig     # TCP timers
//    │   ├── tcp_subr.zig      # TCP helper functions
//    │   └── udp.zig           # UDP handling
//    │
//    └── main.zig              # Entry point
//
// =============================================================================

pub fn main() void {
    std.debug.print("TCP/IP Illustrated Vol 2 - Implementation Guide\n", .{});
    std.debug.print("Read the source code for data structures!\n", .{});
}
