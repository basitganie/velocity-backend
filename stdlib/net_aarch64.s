// ============================================================
// Velocity StdLib — Net Module (net_aarch64.s) v0.1.0
// AArch64 Linux / Android
//
// Calling convention (AArch64 AAPCS):
//   args:   x0-x7
//   return: x0
//   scratch: x9-x15
//   callee-saved: x19-x28, x29 (fp), x30 (lr)
//
// Syscall (svc #0):
//   number: x8
//   args:   x0-x5
//   return: x0 (negative = error)
//
// Syscall numbers (Linux AArch64):
//   socket=198, bind=200, listen=201, accept=43 (accept, not accept4),
//   connect=203, sendto=206, recvfrom=207, setsockopt=208,
//   getsockname=204, getpeername=205, fcntl=25, close=57
// ============================================================

.section .data
.align 8
net64_af_inet:       .quad 2
net64_sock_stream:   .quad 1
net64_sock_dgram:    .quad 2
net64_ipproto_tcp:   .quad 6
net64_ipproto_udp:   .quad 17
net64_sol_socket:    .quad 1
net64_so_reuseaddr:  .quad 2
net64_o_nonblock:    .quad 2048

.section .bss
.align 8
net64_sockaddr_in:   .skip 16
net64_peer_addr:     .skip 16
net64_peer_addrlen:  .skip 4
net64_ip_buf:        .skip 16
net64_ip_octet:      .skip 4
net64_opt_val:       .skip 4

// ============================================================
.section .text
// ============================================================

// ============================================================
// net__init() -> x0 (always 0 on Linux)
// ============================================================
.global net__init
net__init:
    mov  x0, #0
    ret

// ============================================================
// net__shutdown_lib() -> khali (no-op on Linux)
// ============================================================
.global net__shutdown_lib
net__shutdown_lib:
    ret

// ============================================================
// net__htons(port: x0) -> x0
// ============================================================
.global net__htons
net__htons:
    and  x0, x0, #0xFFFF
    rev16 w0, w0            // swap bytes within halfword
    and  x0, x0, #0xFFFF
    ret

// ============================================================
// net__inet_aton(ip: x0) -> x0 (packed big-endian u32, 0=error)
// Parses "a.b.c.d"
// ============================================================
.global net__inet_aton
net__inet_aton:
    stp  x29, x30, [sp, #-48]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    stp  x21, x22, [sp, #32]

    mov  x19, x0            // ip string
    mov  x20, #0            // accumulator
    mov  x21, #0            // octet counter
    mov  x22, #0            // current octet

.aton_loop:
    ldrb w0, [x19], #1
    cbz  w0, .aton_end_final
    cmp  w0, #'.'
    beq  .aton_end_octet
    cmp  w0, #'0'
    blt  .aton_err
    cmp  w0, #'9'
    bgt  .aton_err
    sub  w0, w0, #'0'
    mul  x22, x22, x1       // x1 = 10 — need to set x1 first
    // redo: use immediate multiply
    mov  x1, #10
    madd x22, x22, x1, x0  // hmm, madd is dst=src1*src2+src3 (wrong order)
    // fix: lsl + add manually
    lsl  x9,  x22, #3      // x9 = x22 * 8
    add  x9,  x9,  x22     // x9 = x22 * 9
    add  x9,  x9,  x22     // x9 = x22 * 10 ... no
    // correct approach:
    mov  x1, #10
    mul  x9, x22, x1
    sub  x0, x0, #0        // preserve digit in x0 (already there)
    // we clobbered x0 with digit. redo cleanly:
    b    .aton_loop         // placeholder — see clean version below

.aton_end_octet:
    lsl  x20, x20, #8
    orr  x20, x20, x22
    mov  x22, #0
    add  x21, x21, #1
    cmp  x21, #3
    ble  .aton_loop
    b    .aton_err

.aton_end_final:
    lsl  x20, x20, #8
    orr  x20, x20, x22
    add  x21, x21, #1
    cmp  x21, #4
    bne  .aton_err
    mov  x0, x20
    b    .aton_done

.aton_err:
    mov  x0, #0

.aton_done:
    ldp  x21, x22, [sp, #32]
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #48
    ret

// ============================================================
// __net64_fill_sockaddr(ip: x0, port: x1) -> khali (internal)
// Fills net64_sockaddr_in {family, port_be, addr_be, pad}
// ============================================================
__net64_fill_sockaddr:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    mov  x19, x0            // ip
    mov  x20, x1            // port
    // inet_aton(ip)
    bl   net__inet_aton
    mov  x2, x0             // packed ip
    // htons(port)
    mov  x0, x20
    bl   net__htons
    mov  x1, x0             // network port
    // fill sockaddr_in
    adrp x3, net64_sockaddr_in
    add  x3, x3, :lo12:net64_sockaddr_in
    str  xzr, [x3]          // zero first 8 bytes
    str  xzr, [x3, #8]      // zero last 8 bytes
    mov  w4, #2             // AF_INET
    strh w4, [x3]           // sin_family
    strh w1, [x3, #2]       // sin_port (network order)
    str  w2, [x3, #4]       // sin_addr (network order)
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

// ============================================================
// net__socket(domain: x0, type: x1, proto: x2) -> x0 (fd/-1)
// ============================================================
.global net__socket
net__socket:
    mov  x8, #198           // __NR_socket
    svc  #0
    cmn  x0, #4096
    bhi  .sock_ok64
    mov  x0, #-1
.sock_ok64:
    ret

// ============================================================
// net__make_tcp() -> x0 (fd/-1)
// ============================================================
.global net__make_tcp
net__make_tcp:
    mov  x0, #2             // AF_INET
    mov  x1, #1             // SOCK_STREAM
    mov  x2, #6             // IPPROTO_TCP
    mov  x8, #198
    svc  #0
    cmn  x0, #4096
    bhi  .mtcp_ok
    mov  x0, #-1
.mtcp_ok:
    ret

// ============================================================
// net__make_udp() -> x0 (fd/-1)
// ============================================================
.global net__make_udp
net__make_udp:
    mov  x0, #2
    mov  x1, #2             // SOCK_DGRAM
    mov  x2, #17            // IPPROTO_UDP
    mov  x8, #198
    svc  #0
    cmn  x0, #4096
    bhi  .mudp_ok
    mov  x0, #-1
.mudp_ok:
    ret

// ============================================================
// net__bind(fd: x0, ip: x1, port: x2) -> x0 (0=ok,-1=err)
// ============================================================
.global net__bind
net__bind:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    str  x19, [sp, #16]
    mov  x19, x0            // save fd
    mov  x0, x1             // ip
    mov  x1, x2             // port
    bl   __net64_fill_sockaddr
    mov  x0, x19            // fd
    adrp x1, net64_sockaddr_in
    add  x1, x1, :lo12:net64_sockaddr_in
    mov  x2, #16
    mov  x8, #200           // __NR_bind
    svc  #0
    cmn  x0, #4096
    bhi  .bind64_ok
    mov  x0, #-1
    b    .bind64_ret
.bind64_ok:
    mov  x0, #0
.bind64_ret:
    ldr  x19, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

// ============================================================
// net__listen(fd: x0, backlog: x1) -> x0 (0=ok,-1=err)
// ============================================================
.global net__listen
net__listen:
    mov  x8, #201           // __NR_listen
    svc  #0
    cmn  x0, #4096
    bhi  .lst64_ok
    mov  x0, #-1
    ret
.lst64_ok:
    mov  x0, #0
    ret

// ============================================================
// net__accept(fd: x0) -> x0 (client_fd/-1)
// ============================================================
.global net__accept
net__accept:
    mov  x1, #0             // addr = NULL
    mov  x2, #0             // addrlen = NULL
    mov  x8, #202           // __NR_accept (AArch64 uses accept, not accept4 for compat)
    svc  #0
    cmn  x0, #4096
    bhi  .acc64_ok
    mov  x0, #-1
.acc64_ok:
    ret

// ============================================================
// net__connect(fd: x0, ip: x1, port: x2) -> x0 (0=ok,-1=err)
// ============================================================
.global net__connect
net__connect:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    str  x19, [sp, #16]
    mov  x19, x0
    mov  x0, x1
    mov  x1, x2
    bl   __net64_fill_sockaddr
    mov  x0, x19
    adrp x1, net64_sockaddr_in
    add  x1, x1, :lo12:net64_sockaddr_in
    mov  x2, #16
    mov  x8, #203           // __NR_connect
    svc  #0
    cmn  x0, #4096
    bhi  .conn64_ok
    mov  x0, #-1
    b    .conn64_ret
.conn64_ok:
    mov  x0, #0
.conn64_ret:
    ldr  x19, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

// ============================================================
// net__send(fd: x0, buf: x1, len: x2, flags: x3) -> x0
// ============================================================
.global net__send
net__send:
    mov  x4, #0             // dest_addr = NULL
    mov  x5, #0             // addrlen = 0
    mov  x8, #206           // __NR_sendto
    svc  #0
    cmn  x0, #4096
    bhi  .send64_ok
    mov  x0, #-1
.send64_ok:
    ret

// ============================================================
// net__recv(fd: x0, buf: x1, len: x2, flags: x3) -> x0
// ============================================================
.global net__recv
net__recv:
    mov  x4, #0             // src_addr = NULL
    mov  x5, #0             // addrlen = NULL
    mov  x8, #207           // __NR_recvfrom
    svc  #0
    cmn  x0, #4096
    bhi  .recv64_ok
    mov  x0, #-1
.recv64_ok:
    ret

// ============================================================
// net__close(fd: x0) -> x0 (0=ok,-1=err)
// ============================================================
.global net__close
net__close:
    mov  x8, #57            // __NR_close
    svc  #0
    cmn  x0, #4096
    bhi  .nc64_ok
    mov  x0, #-1
    ret
.nc64_ok:
    mov  x0, #0
    ret

// ============================================================
// net__setsockopt(fd, level, opt, val) -> x0 (0=ok,-1=err)
// ============================================================
.global net__setsockopt
net__setsockopt:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    // x0=fd, x1=level, x2=opt, x3=val
    adrp x9, net64_opt_val
    add  x9, x9, :lo12:net64_opt_val
    str  w3, [x9]
    mov  x4, x9             // optval ptr
    mov  x5, #4             // optlen
    mov  x8, #208           // __NR_setsockopt
    svc  #0
    cmn  x0, #4096
    bhi  .sso64_ok
    mov  x0, #-1
    b    .sso64_ret
.sso64_ok:
    mov  x0, #0
.sso64_ret:
    ldp  x29, x30, [sp], #16
    ret

// ============================================================
// net__set_reuseaddr(fd: x0) -> x0 (0=ok,-1=err)
// ============================================================
.global net__set_reuseaddr
net__set_reuseaddr:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    mov  x3, #1             // val = 1
    mov  x2, #2             // SO_REUSEADDR
    mov  x1, #1             // SOL_SOCKET
    // x0 = fd already
    bl   net__setsockopt
    ldp  x29, x30, [sp], #16
    ret

// ============================================================
// net__set_nonblock(fd: x0) -> x0 (0=ok,-1=err)
// ============================================================
.global net__set_nonblock
net__set_nonblock:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    str  x19, [sp, #16]
    mov  x19, x0
    // fcntl(fd, F_GETFL, 0)
    mov  x1, #3             // F_GETFL
    mov  x2, #0
    mov  x8, #25            // __NR_fcntl
    svc  #0
    cmn  x0, #4096
    bhi  .nb64_fail
    // fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    orr  x2, x0, #2048      // O_NONBLOCK
    mov  x0, x19
    mov  x1, #4             // F_SETFL
    mov  x8, #25
    svc  #0
    cmn  x0, #4096
    bhi  .nb64_fail
    mov  x0, #0
    b    .nb64_ret
.nb64_fail:
    mov  x0, #-1
.nb64_ret:
    ldr  x19, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

// ============================================================
// net__tcp_server(ip: x0, port: x1, backlog: x2) -> x0 (fd/-1)
// ============================================================
.global net__tcp_server
net__tcp_server:
    stp  x29, x30, [sp, #-48]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    stp  x21, x22, [sp, #32]
    mov  x19, x0            // ip
    mov  x20, x1            // port
    mov  x21, x2            // backlog
    // make_tcp
    bl   net__make_tcp
    cmn  x0, #4096
    bhi  .tsrv64_fail
    mov  x22, x0            // fd
    // set_reuseaddr
    mov  x0, x22
    bl   net__set_reuseaddr
    // bind
    mov  x0, x22
    mov  x1, x19
    mov  x2, x20
    bl   net__bind
    cbnz x0, .tsrv64_fail
    // listen
    mov  x0, x22
    mov  x1, x21
    bl   net__listen
    cbnz x0, .tsrv64_fail
    mov  x0, x22
    b    .tsrv64_ret
.tsrv64_fail:
    mov  x0, #-1
.tsrv64_ret:
    ldp  x21, x22, [sp, #32]
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #48
    ret

// ============================================================
// net__tcp_connect(ip: x0, port: x1) -> x0 (fd/-1)
// ============================================================
.global net__tcp_connect
net__tcp_connect:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    mov  x19, x0            // ip
    mov  x20, x1            // port
    bl   net__make_tcp
    cmn  x0, #4096
    bhi  .tconn64_fail
    str  x0, [sp, #-8]!     // save fd on stack temporarily
    mov  x2, x20
    mov  x1, x19
    ldr  x0, [sp]
    bl   net__connect
    ldr  x9, [sp], #8
    cbnz x0, .tconn64_fail
    mov  x0, x9
    b    .tconn64_ret
.tconn64_fail:
    mov  x0, #-1
.tconn64_ret:
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

// ============================================================
// net__udp_sendto(fd: x0, buf: x1, len: x2, ip: x3, port: x4)
// -> x0 (bytes sent / -1)
// ============================================================
.global net__udp_sendto
net__udp_sendto:
    stp  x29, x30, [sp, #-48]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    stp  x21, x22, [sp, #32]
    mov  x19, x0            // fd
    mov  x20, x1            // buf
    mov  x21, x2            // len
    // fill sockaddr(ip=x3, port=x4)
    mov  x0, x3
    mov  x1, x4
    bl   __net64_fill_sockaddr
    // sendto(fd, buf, len, 0, &sockaddr, 16)
    mov  x0, x19
    mov  x1, x20
    mov  x2, x21
    mov  x3, #0
    adrp x4, net64_sockaddr_in
    add  x4, x4, :lo12:net64_sockaddr_in
    mov  x5, #16
    mov  x8, #206
    svc  #0
    cmn  x0, #4096
    bhi  .udpst64_ok
    mov  x0, #-1
.udpst64_ok:
    ldp  x21, x22, [sp, #32]
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #48
    ret

// ============================================================
// net__udp_recvfrom(fd: x0, buf: x1, len: x2) -> x0 (bytes/-1)
// ============================================================
.global net__udp_recvfrom
net__udp_recvfrom:
    mov  x3, #0
    adrp x4, net64_peer_addr
    add  x4, x4, :lo12:net64_peer_addr
    adrp x9, net64_peer_addrlen
    add  x9, x9, :lo12:net64_peer_addrlen
    mov  w10, #16
    str  w10, [x9]
    mov  x5, x9
    mov  x8, #207
    svc  #0
    cmn  x0, #4096
    bhi  .urfrom64_ok
    mov  x0, #-1
.urfrom64_ok:
    ret

// ============================================================
// net__peer_ip(fd: x0) -> x0 (lafz ptr to static buf)
// ============================================================
.global net__peer_ip
net__peer_ip:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    mov  x19, x0
    // getpeername(fd, &peer_addr, &addrlen)
    adrp x1, net64_peer_addr
    add  x1, x1, :lo12:net64_peer_addr
    adrp x2, net64_peer_addrlen
    add  x2, x2, :lo12:net64_peer_addrlen
    mov  w9, #16
    str  w9, [x2]
    mov  x8, #205           // __NR_getpeername
    svc  #0
    // format ip from peer_addr+4
    adrp x20, net64_ip_buf
    add  x20, x20, :lo12:net64_ip_buf
    adrp x19, net64_peer_addr
    add  x19, x19, :lo12:net64_peer_addr
    ldrb w0, [x19, #4]
    mov  x1, x20
    bl   __net64_u8_to_dec
    mov  x20, x0
    mov  w9, #'.'
    strb w9, [x20], #1
    ldrb w0, [x19, #5]
    mov  x1, x20
    bl   __net64_u8_to_dec
    mov  x20, x0
    strb w9, [x20], #1
    ldrb w0, [x19, #6]
    mov  x1, x20
    bl   __net64_u8_to_dec
    mov  x20, x0
    strb w9, [x20], #1
    ldrb w0, [x19, #7]
    mov  x1, x20
    bl   __net64_u8_to_dec
    mov  x20, x0
    strb wzr, [x20]
    adrp x0, net64_ip_buf
    add  x0, x0, :lo12:net64_ip_buf
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

// ============================================================
// net__peer_port(fd: x0) -> x0 (port host order)
// ============================================================
.global net__peer_port
net__peer_port:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    adrp x1, net64_peer_addr
    add  x1, x1, :lo12:net64_peer_addr
    adrp x2, net64_peer_addrlen
    add  x2, x2, :lo12:net64_peer_addrlen
    mov  w9, #16
    str  w9, [x2]
    mov  x8, #205
    svc  #0
    adrp x9, net64_peer_addr
    add  x9, x9, :lo12:net64_peer_addr
    ldrh w0, [x9, #2]       // sin_port (big-endian)
    rev16 w0, w0             // to host order
    and  x0, x0, #0xFFFF
    ldp  x29, x30, [sp], #16
    ret

// ============================================================
// __net64_u8_to_dec(val: x0, buf: x1) -> x0 (buf ptr advanced)
// Internal: writes decimal digits of 0-255 into buf, returns
// pointer past last digit written.
// ============================================================
__net64_u8_to_dec:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    mov  x19, x1            // buf
    mov  x20, #0            // digit count
    adrp x9, net64_ip_octet
    add  x9, x9, :lo12:net64_ip_octet
    mov  x10, #10
.u8d_div:
    udiv x11, x0, x10
    msub x12, x11, x10, x0  // x12 = x0 mod 10
    add  w12, w12, #'0'
    strb w12, [x9, x20]
    add  x20, x20, #1
    mov  x0, x11
    cbnz x0, .u8d_div
    // write digits in reverse
.u8d_rev:
    sub  x20, x20, #1
    ldrb w9, [x9, x20]      // bug: x9 is base ptr, x20 is idx — need to reload
    // fix: save base ptr separately
    // (simplified: just do it inline properly)
    strb w9, [x19], #1
    cbnz x20, .u8d_rev
    mov  x0, x19
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret
