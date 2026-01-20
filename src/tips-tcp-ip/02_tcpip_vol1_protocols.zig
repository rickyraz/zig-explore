// =============================================================================
//              TCP/IP ILLUSTRATED VOL 1: THE PROTOCOLS
//                    Key Concepts untuk Implementation
// =============================================================================
//
// Buku: "TCP/IP Illustrated, Volume 1: The Protocols" - W. Richard Stevens
//
// Volume 1 fokus pada PROTOCOL SPECIFICATIONS dan BEHAVIOR.
// Ini yang perlu kamu pahami sebelum coding.
//
// =============================================================================

const std = @import("std");

// =============================================================================
//                    LAYER MODEL (Chapter 1-2)
// =============================================================================
//
//    ┌─────────────────────────────────────────────────────────────────────────┐
//    │                    TCP/IP vs OSI MODEL                                  │
//    │                                                                         │
//    │     OSI 7 Layer              TCP/IP 4 Layer          Data Unit         │
//    │    ─────────────            ───────────────         ──────────         │
//    │                                                                         │
//    │    ┌───────────┐                                                       │
//    │    │Application│                                                       │
//    │    ├───────────┤            ┌───────────┐                              │
//    │    │Presentation            │Application│          Message/Stream     │
//    │    ├───────────┤            │   Layer   │                              │
//    │    │  Session  │            └─────┬─────┘                              │
//    │    └─────┬─────┘                  │                                    │
//    │          │                        │                                    │
//    │    ┌─────┴─────┐            ┌─────┴─────┐                              │
//    │    │ Transport │────────────│ Transport │          Segment (TCP)      │
//    │    │   (TCP)   │            │   Layer   │          Datagram (UDP)     │
//    │    └─────┬─────┘            └─────┬─────┘                              │
//    │          │                        │                                    │
//    │    ┌─────┴─────┐            ┌─────┴─────┐                              │
//    │    │  Network  │────────────│  Internet │          Packet             │
//    │    │   (IP)    │            │   Layer   │          (Datagram)         │
//    │    └─────┬─────┘            └─────┬─────┘                              │
//    │          │                        │                                    │
//    │    ┌─────┴─────┐                  │                                    │
//    │    │ Data Link │            ┌─────┴─────┐                              │
//    │    ├───────────┤            │  Network  │          Frame              │
//    │    │ Physical  │────────────│  Access   │                              │
//    │    └───────────┘            └───────────┘                              │
//    │                                                                         │
//    └─────────────────────────────────────────────────────────────────────────┘
//
//    ENCAPSULATION:
//    ┌─────────────────────────────────────────────────────────────────────────┐
//    │                                                                         │
//    │  Application Data                                                       │
//    │  ┌─────────────────────────────────────────────────────────┐           │
//    │  │                        DATA                              │           │
//    │  └─────────────────────────────────────────────────────────┘           │
//    │                           │                                             │
//    │                           ▼                                             │
//    │  TCP Segment                                                            │
//    │  ┌──────────┬─────────────────────────────────────────────┐           │
//    │  │TCP Header│                   DATA                       │           │
//    │  │ (20+ B)  │                                              │           │
//    │  └──────────┴─────────────────────────────────────────────┘           │
//    │                           │                                             │
//    │                           ▼                                             │
//    │  IP Packet                                                              │
//    │  ┌──────────┬──────────┬──────────────────────────────────┐           │
//    │  │IP Header │TCP Header│               DATA                │           │
//    │  │ (20+ B)  │ (20+ B)  │                                   │           │
//    │  └──────────┴──────────┴──────────────────────────────────┘           │
//    │                           │                                             │
//    │                           ▼                                             │
//    │  Ethernet Frame                                                         │
//    │  ┌───────┬──────────┬──────────┬──────────────────────┬────┐          │
//    │  │ETH Hdr│IP Header │TCP Header│        DATA          │FCS │          │
//    │  │(14 B) │ (20+ B)  │ (20+ B)  │                      │(4B)│          │
//    │  └───────┴──────────┴──────────┴──────────────────────┴────┘          │
//    │                                                                         │
//    └─────────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    IP - INTERNET PROTOCOL (Chapter 3-8)
// =============================================================================
//
// KEY CONCEPTS:
// 1. Connectionless, unreliable, best-effort delivery
// 2. Fragmentation dan Reassembly
// 3. TTL (Time To Live) - hop count
// 4. Routing decisions at each hop
//
// =============================================================================

pub const IPLesson = struct {

    // ----- IP ADDRESSING -----
    // Class-based (historical):
    //   Class A: 0.0.0.0 - 127.255.255.255   (/8)
    //   Class B: 128.0.0.0 - 191.255.255.255 (/16)
    //   Class C: 192.0.0.0 - 223.255.255.255 (/24)
    //
    // Modern: CIDR (Classless Inter-Domain Routing)
    //   192.168.1.0/24 = 256 addresses
    //   10.0.0.0/8 = 16M addresses

    pub fn ipToString(ip: u32, buf: []u8) []u8 {
        return std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}", .{
            @as(u8, @truncate(ip >> 24)),
            @as(u8, @truncate(ip >> 16)),
            @as(u8, @truncate(ip >> 8)),
            @as(u8, @truncate(ip)),
        }) catch buf[0..0];
    }

    // ----- FRAGMENTATION -----
    // IP packets bisa di-fragment jika > MTU
    //
    // ┌───────────────────────────────────────────────────────────────┐
    // │  Original Packet (4000 bytes, MTU = 1500)                     │
    // │  ┌─────────────────────────────────────────────────────────┐ │
    // │  │ IP Hdr │              3980 bytes data                    │ │
    // │  └─────────────────────────────────────────────────────────┘ │
    // │                           │                                   │
    // │                           ▼                                   │
    // │  Fragment 1: Offset=0, MF=1 (More Fragments)                  │
    // │  ┌──────────┬───────────────────────────────┐                │
    // │  │ IP Hdr   │        1480 bytes data        │                │
    // │  │ ID=1234  │        (offset 0)             │                │
    // │  └──────────┴───────────────────────────────┘                │
    // │                                                               │
    // │  Fragment 2: Offset=1480, MF=1                                │
    // │  ┌──────────┬───────────────────────────────┐                │
    // │  │ IP Hdr   │        1480 bytes data        │                │
    // │  │ ID=1234  │        (offset 185)           │ ← 1480/8       │
    // │  └──────────┴───────────────────────────────┘                │
    // │                                                               │
    // │  Fragment 3: Offset=2960, MF=0 (Last)                         │
    // │  ┌──────────┬─────────────────────┐                          │
    // │  │ IP Hdr   │   1020 bytes data   │                          │
    // │  │ ID=1234  │   (offset 370)      │                          │
    // │  └──────────┴─────────────────────┘                          │
    // └───────────────────────────────────────────────────────────────┘
    //
    // IMPLEMENTATION TIP:
    // - Perlu reassembly buffer per (src_ip, dst_ip, protocol, id)
    // - Timeout untuk incomplete fragments (biasanya 30-60 detik)
    // - Fragment offset dalam unit 8 bytes!

    pub const FragmentInfo = struct {
        identification: u16,
        offset: u16,       // Dalam bytes (sudah di-multiply 8)
        more_fragments: bool,
        data_len: u16,
    };

    // ----- TTL (Time To Live) -----
    // Setiap router HARUS decrement TTL
    // Jika TTL = 0, kirim ICMP Time Exceeded
    // Mencegah routing loops
    //
    // Typical initial TTL values:
    // - Linux: 64
    // - Windows: 128
    // - Cisco: 255
};

// =============================================================================
//                    ICMP - INTERNET CONTROL MESSAGE PROTOCOL (Chapter 6)
// =============================================================================
//
// ICMP = Error reporting dan diagnostics
// Selalu encapsulated dalam IP packet
//
// =============================================================================

pub const ICMPType = enum(u8) {
    echo_reply = 0,
    destination_unreachable = 3,
    source_quench = 4,          // Deprecated
    redirect = 5,
    echo_request = 8,
    time_exceeded = 11,
    parameter_problem = 12,
    timestamp_request = 13,
    timestamp_reply = 14,
    _,
};

pub const ICMPHeader = packed struct {
    type: u8,
    code: u8,
    checksum: u16,
    // Rest depends on type
};

// Destination Unreachable Codes
pub const DestUnreachableCode = enum(u8) {
    network_unreachable = 0,
    host_unreachable = 1,
    protocol_unreachable = 2,
    port_unreachable = 3,        // UDP: port not listening
    fragmentation_needed = 4,    // DF bit set but fragmentation required
    source_route_failed = 5,
    _,
};

// =============================================================================
//                    UDP - USER DATAGRAM PROTOCOL (Chapter 11)
// =============================================================================
//
// SIMPLE! Hanya:
// - Source Port (16 bit)
// - Destination Port (16 bit)
// - Length (16 bit)
// - Checksum (16 bit, optional di IPv4)
//
// CHARACTERISTICS:
// - Connectionless
// - Unreliable (no acknowledgment)
// - No ordering guarantees
// - No flow control
// - No congestion control
// - Low overhead (8 bytes header)
//
// USE CASES:
// - DNS (query-response, small messages)
// - DHCP
// - Streaming media (tolerate loss)
// - Gaming (low latency > reliability)
// - VoIP
//
// =============================================================================

pub const UDPLesson = struct {
    //
    //    UDP "Connection" (actually just address binding)
    //    ┌─────────────────────────────────────────────────────────────┐
    //    │                                                             │
    //    │   Application                      Application              │
    //    │      │                                  │                   │
    //    │      │ sendto(dst_ip, dst_port, data)  │                   │
    //    │      ▼                                  │                   │
    //    │   ┌──────┐                          ┌──────┐               │
    //    │   │ UDP  │                          │ UDP  │               │
    //    │   │Socket│                          │Socket│               │
    //    │   │:1234 │                          │:5678 │               │
    //    │   └──┬───┘                          └──┬───┘               │
    //    │      │                                  │                   │
    //    │      │      UDP Datagram                │                   │
    //    │      │   ┌────────┬──────────┐         │                   │
    //    │      └──▶│UDP Hdr │   Data   │────────▶│                   │
    //    │          │ 8 bytes│          │         │                   │
    //    │          └────────┴──────────┘         │                   │
    //    │                                         │                   │
    //    │   No handshake, no connection state!    ▼                   │
    //    │                                      recvfrom()             │
    //    │                                                             │
    //    └─────────────────────────────────────────────────────────────┘
    //
    //    IMPLEMENTATION CHECKLIST:
    //    □ Bind to local port
    //    □ Calculate/verify checksum (pseudo-header!)
    //    □ Handle "port unreachable" ICMP
    //    □ No state machine needed!
    //

    pub const UDPPseudoHeader = packed struct {
        src_addr: u32,
        dst_addr: u32,
        zero: u8 = 0,
        protocol: u8 = 17,  // UDP
        udp_length: u16,
    };
};

// =============================================================================
//                    TCP - TRANSMISSION CONTROL PROTOCOL (Chapter 17-24)
// =============================================================================
//
// TCP adalah bagian PALING KOMPLEKS dari TCP/IP stack!
// Buku Vol 1 menghabiskan 8 chapter untuk TCP.
//
// =============================================================================

pub const TCPLesson = struct {

    // ----- TCP CONNECTION ESTABLISHMENT (3-Way Handshake) -----
    //
    //    ┌────────────────────────────────────────────────────────────────┐
    //    │                    3-WAY HANDSHAKE                             │
    //    │                                                                │
    //    │     Client                              Server                 │
    //    │        │                                   │                   │
    //    │        │                                   │ LISTEN            │
    //    │        │                                   │                   │
    //    │        │──────── SYN (seq=x) ────────────▶│                   │
    //    │        │         ISN = x                   │ SYN_RCVD          │
    //    │  SYN_  │                                   │                   │
    //    │  SENT  │◀─── SYN+ACK (seq=y, ack=x+1) ────│                   │
    //    │        │                                   │                   │
    //    │        │──────── ACK (ack=y+1) ──────────▶│                   │
    //    │        │                                   │                   │
    //    │  ESTAB │                                   │ ESTABLISHED       │
    //    │        │◀─────── Data Transfer ──────────▶│                   │
    //    │        │                                   │                   │
    //    └────────────────────────────────────────────────────────────────┘
    //
    //    IMPLEMENTATION NOTES:
    //    - ISN (Initial Sequence Number) harus RANDOM untuk security
    //    - SYN consumes 1 sequence number
    //    - Store state: ISN sent, ISN received, current seq/ack

    // ----- TCP CONNECTION TERMINATION (4-Way Handshake) -----
    //
    //    ┌────────────────────────────────────────────────────────────────┐
    //    │                    CONNECTION CLOSE                            │
    //    │                                                                │
    //    │     Active Close                        Passive Close          │
    //    │     (Client)                            (Server)               │
    //    │        │                                   │                   │
    //    │  ESTAB │                                   │ ESTABLISHED       │
    //    │        │                                   │                   │
    //    │        │──────── FIN (seq=u) ────────────▶│                   │
    //    │  FIN_  │                                   │ CLOSE_WAIT        │
    //    │  WAIT1 │◀─────── ACK (ack=u+1) ───────────│                   │
    //    │        │                                   │                   │
    //    │  FIN_  │                                   │ (App closes)      │
    //    │  WAIT2 │◀─────── FIN (seq=v) ─────────────│ LAST_ACK          │
    //    │        │                                   │                   │
    //    │  TIME_ │──────── ACK (ack=v+1) ──────────▶│                   │
    //    │  WAIT  │                                   │ CLOSED            │
    //    │        │                                   │                   │
    //    │   2MSL │                                                       │
    //    │  wait  │                                                       │
    //    │        │                                                       │
    //    │ CLOSED │                                                       │
    //    └────────────────────────────────────────────────────────────────┘
    //
    //    TIME_WAIT:
    //    - Wait for 2 * MSL (Maximum Segment Lifetime)
    //    - MSL typically 30 seconds to 2 minutes
    //    - Ensures all packets from old connection are gone
    //    - Allows retransmission of final ACK if lost

    // ----- TCP SLIDING WINDOW -----
    //
    //    ┌────────────────────────────────────────────────────────────────┐
    //    │                    SLIDING WINDOW                              │
    //    │                                                                │
    //    │    Sequence Space:                                             │
    //    │                                                                │
    //    │    ◀──── Sent & ACKed ────▶◀─ Sent, not ACKed ─▶◀── Can Send ─▶│
    //    │    │                       │                    │              │
    //    │    ├───────────────────────┼────────────────────┼──────────────┤
    //    │    1       ...           100  101  102  103  104  105  ...     │
    //    │                            ▲                    ▲              │
    //    │                         SND.UNA              SND.NXT           │
    //    │                      (oldest unacked)     (next to send)       │
    //    │                                                                │
    //    │    Window Size = SND.UNA + SND.WND - SND.NXT                   │
    //    │    (how many more bytes we can send)                           │
    //    │                                                                │
    //    │    RECEIVER SIDE:                                              │
    //    │                                                                │
    //    │    ◀──── Received & ACKed ─▶◀─── Receive Window ──▶            │
    //    │    │                        │                     │            │
    //    │    ├────────────────────────┼─────────────────────┤            │
    //    │    1       ...            100  101  ...         200            │
    //    │                             ▲                                  │
    //    │                          RCV.NXT                               │
    //    │                       (next expected)                          │
    //    │                                                                │
    //    └────────────────────────────────────────────────────────────────┘

    pub const SendWindow = struct {
        una: u32,       // Oldest unacknowledged sequence number
        nxt: u32,       // Next sequence number to send
        wnd: u32,       // Send window size (from receiver)
        iss: u32,       // Initial send sequence number

        pub fn availableWindow(self: SendWindow) u32 {
            const in_flight = self.nxt -% self.una;
            if (in_flight >= self.wnd) return 0;
            return self.wnd - in_flight;
        }
    };

    pub const RecvWindow = struct {
        nxt: u32,       // Next expected sequence number
        wnd: u32,       // Receive window size (to advertise)
        irs: u32,       // Initial receive sequence number

        pub fn isInWindow(self: RecvWindow, seq: u32, len: u32) bool {
            // Check if segment falls within receive window
            const window_end = self.nxt +% self.wnd;
            // Sequence number arithmetic (handles wraparound)
            const rel_seq = seq -% self.nxt;
            const rel_end = window_end -% self.nxt;
            return rel_seq < rel_end and (rel_seq + len) <= rel_end;
        }
    };

    // ----- TCP RETRANSMISSION -----
    //
    //    Sender maintains RETRANSMISSION QUEUE:
    //    ┌───────────────────────────────────────────────────────────────┐
    //    │  Retransmission Queue                                         │
    //    │                                                               │
    //    │  ┌─────────┬─────────┬─────────┬─────────┐                   │
    //    │  │ Seg 100 │ Seg 200 │ Seg 300 │ Seg 400 │                   │
    //    │  │ Timer=2s│ Timer=3s│ Timer=5s│ Timer=1s│                   │
    //    │  └─────────┴─────────┴─────────┴─────────┘                   │
    //    │       │                                                       │
    //    │       ▼                                                       │
    //    │  When ACK received → remove from queue                        │
    //    │  When timer expires → retransmit & double timeout             │
    //    │                                                               │
    //    │  FAST RETRANSMIT:                                             │
    //    │  3 duplicate ACKs → retransmit immediately                    │
    //    │  (don't wait for timer)                                       │
    //    │                                                               │
    //    └───────────────────────────────────────────────────────────────┘

    // ----- CONGESTION CONTROL -----
    //
    //    ┌───────────────────────────────────────────────────────────────┐
    //    │                    CONGESTION CONTROL                         │
    //    │                                                               │
    //    │     cwnd                                                      │
    //    │      ▲                                                        │
    //    │      │                    Congestion                          │
    //    │      │                    Avoidance                           │
    //    │      │                   /                                    │
    //    │      │                  /                                     │
    //    │      │                 /                                      │
    //    │      │     Slow      /                                        │
    //    │      │     Start    /                                         │
    //    │      │            /                                           │
    //    │      │          /  ← ssthresh                                 │
    //    │      │        /                                               │
    //    │      │      /                                                 │
    //    │      │    /                                                   │
    //    │      │  /                                                     │
    //    │      │/                                                       │
    //    │      └─────────────────────────────────────────▶ time         │
    //    │                                                               │
    //    │  SLOW START: cwnd doubles every RTT (exponential)             │
    //    │  CONGESTION AVOIDANCE: cwnd += 1 MSS per RTT (linear)         │
    //    │  ON LOSS: ssthresh = cwnd/2, cwnd = 1 MSS                     │
    //    │                                                               │
    //    └───────────────────────────────────────────────────────────────┘

    pub const CongestionControl = struct {
        cwnd: u32,          // Congestion window
        ssthresh: u32,      // Slow start threshold
        mss: u32,           // Maximum Segment Size

        pub fn init(mss: u32) CongestionControl {
            return .{
                .cwnd = mss,                    // Start with 1 MSS
                .ssthresh = 65535,              // Large initial threshold
                .mss = mss,
            };
        }

        pub fn onAck(self: *CongestionControl) void {
            if (self.cwnd < self.ssthresh) {
                // Slow start: double cwnd
                self.cwnd += self.mss;
            } else {
                // Congestion avoidance: linear increase
                self.cwnd += self.mss * self.mss / self.cwnd;
            }
        }

        pub fn onLoss(self: *CongestionControl) void {
            // Multiplicative decrease
            self.ssthresh = @max(self.cwnd / 2, 2 * self.mss);
            self.cwnd = self.mss; // Reset to 1 MSS
        }

        pub fn effectiveWindow(self: CongestionControl, advertised: u32) u32 {
            // Send window = min(cwnd, receiver's advertised window)
            return @min(self.cwnd, advertised);
        }
    };
};

// =============================================================================
//                    KEY IMPLEMENTATION CHECKLIST
// =============================================================================
//
//    IP Layer:
//    □ Parse/create IP headers
//    □ Validate header checksum
//    □ Fragment reassembly (with timeout)
//    □ TTL decrement and ICMP generation
//    □ Routing table lookup
//
//    ICMP:
//    □ Echo request/reply (ping)
//    □ Destination unreachable
//    □ Time exceeded
//
//    UDP:
//    □ Parse/create UDP headers
//    □ Port demultiplexing
//    □ Checksum (with pseudo-header)
//    □ Socket binding
//
//    TCP:
//    □ Parse/create TCP headers
//    □ Connection state machine (11 states!)
//    □ 3-way handshake
//    □ 4-way close
//    □ Sliding window (send & receive)
//    □ Sequence number tracking
//    □ Retransmission with timeout
//    □ Fast retransmit (3 dup ACKs)
//    □ Congestion control
//    □ RTT estimation
//    □ Delayed ACK
//    □ Nagle algorithm (optional)
//    □ Keep-alive (optional)
//    □ Out-of-order segment handling
//    □ SACK (Selective ACK, optional)
//
// =============================================================================

pub fn main() void {
    std.debug.print("TCP/IP Illustrated Vol 1 - Study Guide\n", .{});
    std.debug.print("Read the source code for protocol diagrams!\n", .{});
}
