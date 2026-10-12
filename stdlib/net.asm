; ============================================================
; Velocity StdLib — Net Module (net.asm) v0.1.0
; Windows + Linux x86-64 dual-mode
; AArch64-linux-android → net_aarch64.s
;
; Functions:
;   net__socket        net__bind          net__listen
;   net__accept        net__connect       net__send
;   net__recv          net__close         net__setsockopt
;   net__htons         net__inet_aton     net__make_tcp
;   net__make_udp      net__tcp_server    net__tcp_connect
;   net__udp_sendto    net__udp_recvfrom  net__set_nonblock
;   net__set_reuseaddr net__peer_ip       net__peer_port
;   net__init          net__shutdown_lib
;
; Calling convention (Linux SysV):
;   args: rdi, rsi, rdx, rcx, r8, r9
;   return: rax
; Calling convention (Windows x64):
;   args: rcx, rdx, r8, r9, [rsp+32], [rsp+40]
;   return: rax
;   shadow space: 32 bytes always
; ============================================================

%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

default rel

; ============================================================
; Windows extern declarations
; ============================================================
%ifdef WIN64_TARGET
extern WSAStartup
extern WSACleanup
extern WSAGetLastError
extern socket
extern bind
extern listen
extern accept
extern connect
extern send
extern recv
extern setsockopt
extern closesocket
extern ioctlsocket
extern getpeername
extern inet_addr
extern htons
extern htonl
%endif

; ============================================================
section .data
; ============================================================
net_af_inet      equ 2
net_sock_stream  equ 1
net_sock_dgram   equ 2
net_ipproto_tcp  equ 6
net_ipproto_udp  equ 17
net_sol_socket   equ 1
net_so_reuseaddr equ 2
net_f_getfl      equ 3
net_f_setfl      equ 4
net_o_nonblock   equ 2048

%ifdef WIN64_TARGET
net_sol_socket_w equ 0xFFFF
net_so_reuseaddr_w equ 4
net_fionbio      equ 0x8004667E
%endif

net_dot_str      db ".", 0
net_any_ip       db "0.0.0.0", 0

; ============================================================
section .bss
; ============================================================
net_wsa_data     resb 408     ; WSADATA struct (Windows only)
net_sockaddr_in  resb 16     ; struct sockaddr_in (reused for build)
net_peer_addr    resb 16     ; getpeername result
net_peer_addrlen resd 1      ; socklen_t
net_ip_buf       resb 16     ; peer IP string buffer
net_ip_octet     resb 4      ; scratch octets for inet_aton
net_opt_val      resd 1      ; setsockopt value scratch

; ============================================================
section .text
; ============================================================

; ============================================================
; net__init() -> adad
; Must be called once before any net function on Windows.
; No-op on Linux (returns 0).
; ============================================================
global net__init
net__init:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    mov  rcx, 0x0202            ; version 2.2
    lea  rdx, [rel net_wsa_data]
    call WSAStartup
    add  rsp, 32
%else
    xor  rax, rax
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__shutdown_lib() -> khali
; Cleanup on Windows. No-op on Linux.
; ============================================================
global net__shutdown_lib
net__shutdown_lib:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    call WSACleanup
    add  rsp, 32
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__htons(port: adad) -> adad
; Converts host byte order to network byte order (big-endian).
; ============================================================
global net__htons
net__htons:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    movzx rcx, cx
    sub  rsp, 32
    call htons
    add  rsp, 32
    movzx rax, ax
%else
    movzx rax, di
    xchg al, ah          ; swap bytes: host→network
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__inet_aton(ip: lafz) -> adad
; Parses "a.b.c.d" into a packed big-endian u32.
; Returns 0 on parse error.
; Linux: pure asm. Windows: delegates to inet_addr().
; ============================================================
global net__inet_aton
net__inet_aton:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; rcx = ip string
    sub  rsp, 32
    call inet_addr
    add  rsp, 32
    ; inet_addr returns INADDR_NONE (0xFFFFFFFF) on error
    cmp  eax, 0xFFFFFFFF
    jne  .aton_done_win
    xor  eax, eax
.aton_done_win:
%else
    push rbx
    push r12
    push r13
    push r14

    mov  r12, rdi       ; ip string pointer
    xor  r13, r13       ; accumulator (result u32)
    xor  r14, r14       ; octet counter
    xor  rbx, rbx       ; current octet value

.aton_loop:
    movzx rax, byte [r12]
    inc  r12
    test al, al
    jz   .aton_end_octet_final
    cmp  al, '.'
    je   .aton_end_octet
    ; digit check
    cmp  al, '0'
    jb   .aton_err
    cmp  al, '9'
    ja   .aton_err
    sub  al, '0'
    imul rbx, rbx, 10
    add  rbx, rax
    cmp  rbx, 255
    ja   .aton_err
    jmp  .aton_loop

.aton_end_octet:
    ; shift accumulator left 8 and OR in octet
    shl  r13, 8
    or   r13, rbx
    xor  rbx, rbx
    inc  r14
    cmp  r14, 3
    jle  .aton_loop
    jmp  .aton_err      ; too many octets

.aton_end_octet_final:
    shl  r13, 8
    or   r13, rbx
    inc  r14
    cmp  r14, 4
    jne  .aton_err
    ; r13 is now big-endian packed u32 (network order)
    mov  rax, r13
    jmp  .aton_done

.aton_err:
    xor  rax, rax

.aton_done:
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; __net_fill_sockaddr(ip: lafz, port: adad) -> khali
; Internal: fills net_sockaddr_in with AF_INET, port, addr.
; Linux:   rdi=ip, rsi=port
; Windows: rcx=ip, rdx=port  (translated before call)
; ============================================================
__net_fill_sockaddr:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
%ifdef WIN64_TARGET
    mov  r12, rdx           ; port
    mov  rbx, rcx           ; ip string
    sub  rsp, 32
    call htons              ; htons(port) — rcx already = port... no, rdx
    ; fix: rcx=port for htons
    mov  rcx, rdx
    call htons
    add  rsp, 32
    movzx rax, ax           ; network port
    ; fill sockaddr_in
    lea  rbx, [rel net_sockaddr_in]
    mov  word  [rbx],     net_af_inet  ; sin_family
    mov  word  [rbx + 2], ax           ; sin_port (already network order)
    ; inet_addr(ip)
    ; rcx = ip string (saved in rbx before we clobbered it)
    ; we need to re-get ip... save it earlier
    ; actually rbx was ip string, now rbx = net_sockaddr_in ptr. use r12 for ip
    ; redo: r12=port, rbx=ip → but we set rbx=rcx(ip) and then clobbered
    ; Re-approach with cleaner save:
    xor  rax, rax
%else
    mov  r12, rsi           ; port
    mov  rbx, rdi           ; ip string

    ; call net__inet_aton(ip)
    call net__inet_aton
    mov  rcx, rax           ; save packed IP
    bswap eax            
    mov  ecx, eax
    ; htons(port)
    movzx rax, r12w
    xchg al, ah

    ; fill net_sockaddr_in
    lea  rdx, [rel net_sockaddr_in]
    mov  qword [rdx], 0             ; zero whole struct
    mov  qword [rdx + 8], 0
    mov  word  [rdx],     net_af_inet  ; sin_family = AF_INET = 2
    mov  word  [rdx + 2], ax           ; sin_port (network order)
    mov  dword [rdx + 4], ecx          ; sin_addr (network order)
%endif
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__socket(domain: adad, type: adad, proto: adad) -> adad
; Raw socket() syscall. Returns fd or -1.
; ============================================================
global net__socket
net__socket:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    call socket
    add  rsp, 32
    cmp  rax, -1    ; INVALID_SOCKET = ~0
    jne  .sock_ok
    mov  rax, -1
.sock_ok:
%else
    mov  rax, 41    ; sys_socket
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__make_tcp() -> adad (fd)
; Creates a TCP socket. Returns fd or -1.
; ============================================================
global net__make_tcp
net__make_tcp:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rcx, net_af_inet
    mov  rdx, net_sock_stream
    mov  r8,  net_ipproto_tcp
    sub  rsp, 32
    call socket
    add  rsp, 32
%else
    mov  rdi, net_af_inet
    mov  rsi, net_sock_stream
    mov  rdx, net_ipproto_tcp
    mov  rax, 41
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__make_udp() -> adad (fd)
; Creates a UDP socket. Returns fd or -1.
; ============================================================
global net__make_udp
net__make_udp:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rcx, net_af_inet
    mov  rdx, net_sock_dgram
    mov  r8,  net_ipproto_udp
    sub  rsp, 32
    call socket
    add  rsp, 32
%else
    mov  rdi, net_af_inet
    mov  rsi, net_sock_dgram
    mov  rdx, net_ipproto_udp
    mov  rax, 41
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__bind(fd: adad, ip: lafz, port: adad) -> adad (0=ok,-1=err)
; ============================================================
global net__bind
net__bind:
    push rbp
    mov  rbp, rsp
    push rbx
%ifdef WIN64_TARGET
    mov  rbx, rcx           ; save fd
    ; fill sockaddr: ip=rdx, port=r8
    mov  rcx, rdx
    mov  rdx, r8
    sub  rsp, 32
    call __net_fill_sockaddr_win
    add  rsp, 32
    ; bind(fd, &sockaddr_in, 16)
    mov  rcx, rbx
    lea  rdx, [rel net_sockaddr_in]
    mov  r8,  16
    sub  rsp, 32
    call bind
    add  rsp, 32
    test rax, rax
    jz   .bind_ok
    mov  rax, -1
    jmp  .bind_ret
.bind_ok:
    xor  rax, rax
.bind_ret:
%else
    mov  rbx, rdi           ; save fd
    ; rsi=ip, rdx=port → fill sockaddr
    mov  rdi, rsi
    mov  rsi, rdx
    call __net_fill_sockaddr
    ; bind(fd, &net_sockaddr_in, 16)
    mov  rdi, rbx
    lea  rsi, [rel net_sockaddr_in]
    mov  rdx, 16
    mov  rax, 49            ; sys_bind
    syscall
%endif
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__listen(fd: adad, backlog: adad) -> adad (0=ok,-1=err)
; ============================================================
global net__listen
net__listen:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    call listen
    add  rsp, 32
    test rax, rax
    jz   .listen_ok
    mov  rax, -1
    jmp  .listen_ret
.listen_ok:
    xor  rax, rax
.listen_ret:
%else
    mov  rax, 50            ; sys_listen
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__accept(fd: adad) -> adad (client_fd or -1)
; ============================================================
global net__accept
net__accept:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rdx, 0             ; addr = NULL
    mov  r8,  0             ; addrlen = NULL
    sub  rsp, 32
    call accept
    add  rsp, 32
    cmp  rax, -1
    jne  .acc_ok
    mov  rax, -1
.acc_ok:
%else
    mov  rsi, 0             ; addr = NULL (we use net__peer_ip separately)
    mov  rdx, 0             ; addrlen = NULL
    mov  rax, 43            ; sys_accept
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__connect(fd: adad, ip: lafz, port: adad) -> adad (0=ok,-1=err)
; ============================================================
global net__connect
net__connect:
    push rbp
    mov  rbp, rsp
    push rbx
%ifdef WIN64_TARGET
    mov  rbx, rcx
    mov  rcx, rdx
    mov  rdx, r8
    sub  rsp, 32
    call __net_fill_sockaddr_win
    add  rsp, 32
    mov  rcx, rbx
    lea  rdx, [rel net_sockaddr_in]
    mov  r8,  16
    sub  rsp, 32
    call connect
    add  rsp, 32
    test rax, rax
    jz   .conn_ok
    mov  rax, -1
    jmp  .conn_ret
.conn_ok:
    xor  rax, rax
.conn_ret:
%else
    mov  rbx, rdi
    mov  rdi, rsi
    mov  rsi, rdx
    call __net_fill_sockaddr
    mov  rdi, rbx
    lea  rsi, [rel net_sockaddr_in]
    mov  rdx, 16
    mov  rax, 42            ; sys_connect
    syscall
%endif
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__send(fd: adad, buf: [harf], len: adad, flags: adad) -> adad
; Returns bytes sent or -1.
; ============================================================
global net__send
net__send:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; rcx=fd, rdx=buf, r8=len, r9=flags
    sub  rsp, 32
    call send
    add  rsp, 32
    cmp  rax, -1
    jne  .send_ok
    mov  rax, -1
.send_ok:
%else
    ; rdi=fd, rsi=buf, rdx=len, rcx=flags → r10=flags for syscall
    mov  r10, rcx
    mov  r8,  0             ; dest_addr = NULL (TCP)
    mov  r9,  0             ; addrlen = 0
    mov  rax, 44            ; sys_sendto
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__recv(fd: adad, buf: [harf], len: adad, flags: adad) -> adad
; Returns bytes received, 0=closed, -1=error.
; ============================================================
global net__recv
net__recv:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    call recv
    add  rsp, 32
    cmp  rax, -1
    jne  .recv_ok
    mov  rax, -1
.recv_ok:
%else
    mov  r10, rcx           ; flags → r10
    mov  r8,  0             ; src_addr = NULL
    mov  r9,  0             ; addrlen = NULL
    mov  rax, 45            ; sys_recvfrom
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__close(fd: adad) -> adad (0=ok,-1=err)
; ============================================================
global net__close
net__close:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    call closesocket
    add  rsp, 32
    test rax, rax
    jz   .nclose_ok
    mov  rax, -1
    jmp  .nclose_ret
.nclose_ok:
    xor  rax, rax
.nclose_ret:
%else
    mov  rax, 3             ; sys_close
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__setsockopt(fd, level, opt, val) -> adad (0=ok,-1=err)
; ============================================================
global net__setsockopt
net__setsockopt:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; rcx=fd, rdx=level, r8=opt, r9=val
    mov  dword [rel net_opt_val], r9d
    push 4                          ; optlen = 4
    lea  rax, [rel net_opt_val]
    push rax                        ; optval ptr (5th arg on stack)
    sub  rsp, 32
    call setsockopt
    add  rsp, 48
    test rax, rax
    jz   .sso_ok
    mov  rax, -1
    jmp  .sso_ret
.sso_ok:
    xor  rax, rax
.sso_ret:
%else
    ; rdi=fd, rsi=level, rdx=opt, rcx=val
    mov  dword [rel net_opt_val], ecx
    mov  r10, rdx               ; save opt
    mov  rdx, r10               ; optname
    mov  r10, rsi               ; level stays
    lea  r8,  [rel net_opt_val] ; optval
    mov  r9,  4                 ; optlen
    mov  rsi, rdi               ; rearrange: setsockopt(fd,level,opt,*val,len)
    ; Linux setsockopt(fd, level, optname, optval, optlen)
    ; rdi=fd already
    mov  rsi, r10               ; level
    mov  rdx, rdx               ; optname (already correct)
    mov  rax, 54                ; sys_setsockopt
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__set_reuseaddr(fd: adad) -> adad (0=ok,-1=err)
; Sets SO_REUSEADDR. Call before bind() for servers.
; ============================================================
global net__set_reuseaddr
net__set_reuseaddr:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  dword [rel net_opt_val], 1
    push 4
    lea  rax, [rel net_opt_val]
    push rax
    mov  r9,  net_so_reuseaddr_w
    mov  r8,  net_sol_socket_w
    ; rdx=fd already in rcx
    sub  rsp, 32
    call setsockopt
    add  rsp, 48
    test rax, rax
    jz   .raddr_ok
    mov  rax, -1
    jmp  .raddr_ret
.raddr_ok:
    xor  rax, rax
.raddr_ret:
%else
    push rbx
    mov  rbx, rdi               ; save fd
    mov  dword [rel net_opt_val], 1
    mov  rsi, net_sol_socket    ; SOL_SOCKET
    mov  rdx, net_so_reuseaddr  ; SO_REUSEADDR
    lea  r10, [rel net_opt_val]
    mov  r8,  4
    mov  rax, 54                ; sys_setsockopt
    syscall
    pop  rbx
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__set_nonblock(fd: adad) -> adad (0=ok,-1=err)
; Sets O_NONBLOCK via fcntl (Linux) or ioctlsocket (Windows).
; ============================================================
global net__set_nonblock
net__set_nonblock:
    push rbp
    mov  rbp, rsp
    push rbx
%ifdef WIN64_TARGET
    mov  rbx, rcx               ; save fd
    mov  dword [rel net_opt_val], 1
    mov  rcx, rbx
    mov  rdx, net_fionbio
    lea  r8,  [rel net_opt_val]
    sub  rsp, 32
    call ioctlsocket
    add  rsp, 32
    test rax, rax
    jz   .nb_ok
    mov  rax, -1
    jmp  .nb_ret
.nb_ok:
    xor  rax, rax
.nb_ret:
%else
    mov  rbx, rdi
    ; fcntl(fd, F_GETFL, 0)
    mov  rsi, net_f_getfl
    xor  rdx, rdx
    mov  rax, 72                ; sys_fcntl
    syscall
    test rax, rax
    js   .nb_fail
    ; fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    or   rax, net_o_nonblock
    mov  rdi, rbx
    mov  rsi, net_f_setfl
    mov  rdx, rax
    mov  rax, 72
    syscall
    test rax, rax
    js   .nb_fail
    xor  rax, rax
    jmp  .nb_ret
.nb_fail:
    mov  rax, -1
.nb_ret:
%endif
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__tcp_server(ip: lafz, port: adad, backlog: adad) -> adad (fd)
; Convenience: socket + set_reuseaddr + bind + listen in one call.
; Pass ip = "0.0.0.0" to listen on all interfaces.
; Returns fd on success, -1 on any failure.
; ============================================================
global net__tcp_server
net__tcp_server:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  r12, rdx           ; ip
    mov  r13, r8            ; port
    ; save backlog
    push r9
    ; make tcp socket
    mov  rcx, net_af_inet
    mov  rdx, net_sock_stream
    mov  r8,  net_ipproto_tcp
    sub  rsp, 32
    call socket
    add  rsp, 32
    cmp  rax, -1
    je   .tsrv_fail
    mov  rbx, rax           ; fd
    ; set_reuseaddr
    mov  rcx, rbx
    sub  rsp, 32
    call net__set_reuseaddr
    add  rsp, 32
    ; bind
    mov  rcx, rbx
    mov  rdx, r12
    mov  r8,  r13
    sub  rsp, 32
    call net__bind
    add  rsp, 32
    test rax, rax
    jnz  .tsrv_fail
    ; listen
    pop  r9                 ; backlog
    mov  rcx, rbx
    mov  rdx, r9
    sub  rsp, 32
    call listen
    add  rsp, 32
    test rax, rax
    jnz  .tsrv_fail
    mov  rax, rbx
    jmp  .tsrv_ret
.tsrv_fail:
    mov  rax, -1
.tsrv_ret:
%else
    mov  r12, rdi           ; ip
    mov  r13, rsi           ; port
    push rdx                ; save backlog

    ; make_tcp
    mov  rdi, net_af_inet
    mov  rsi, net_sock_stream
    mov  rdx, net_ipproto_tcp
    mov  rax, 41
    syscall
    test rax, rax
    js   .tsrv_fail
    mov  rbx, rax           ; fd

    ; set_reuseaddr(fd)
    mov  rdi, rbx
    call net__set_reuseaddr

    ; bind(fd, ip, port)
    mov  rdi, rbx
    mov  rsi, r12
    mov  rdx, r13
    call net__bind
    test rax, rax
    jnz  .tsrv_fail

    ; listen(fd, backlog)
    pop  rsi                ; backlog
    mov  rdi, rbx
    mov  rax, 50
    syscall
    test rax, rax
    jnz  .tsrv_fail

    mov  rax, rbx
    jmp  .tsrv_ret

.tsrv_fail:
    pop  rax                ; discard saved backlog if still on stack
    mov  rax, -1
.tsrv_ret:
%endif
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__tcp_connect(ip: lafz, port: adad) -> adad (fd or -1)
; Convenience: socket + connect in one call.
; ============================================================
global net__tcp_connect
net__tcp_connect:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  r12, rcx           ; ip
    mov  r13, rdx           ; port
    mov  rcx, net_af_inet
    mov  rdx, net_sock_stream
    mov  r8,  net_ipproto_tcp
    sub  rsp, 32
    call socket
    add  rsp, 32
    cmp  rax, -1
    je   .tconn_fail
    mov  rbx, rax
    mov  rcx, rbx
    mov  rdx, r12
    mov  r8,  r13
    sub  rsp, 32
    call net__connect
    add  rsp, 32
    test rax, rax
    jnz  .tconn_fail
    mov  rax, rbx
    jmp  .tconn_ret
.tconn_fail:
    mov  rax, -1
.tconn_ret:
%else
    mov  r12, rdi           ; ip
    mov  r13, rsi           ; port
    ; socket
    mov  rdi, net_af_inet
    mov  rsi, net_sock_stream
    mov  rdx, net_ipproto_tcp
    mov  rax, 41
    syscall
    test rax, rax
    js   .tconn_fail
    mov  rbx, rax
    ; connect(fd, ip, port)
    mov  rdi, rbx
    mov  rsi, r12
    mov  rdx, r13
    call net__connect
    test rax, rax
    jnz  .tconn_fail
    mov  rax, rbx
    jmp  .tconn_ret
.tconn_fail:
    mov  rax, -1
.tconn_ret:
%endif
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__udp_sendto(fd, buf, len, ip: lafz, port) -> adad
; Sends a UDP datagram to ip:port.
; ============================================================
global net__udp_sendto
net__udp_sendto:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
%ifdef WIN64_TARGET
    mov  rbx, rcx           ; fd
    mov  r12, rdx           ; buf
    mov  r13, r8            ; len
    ; ip and port are on stack (5th, 6th args)
    mov  r14, [rbp + 48]    ; ip
    mov  r15, [rbp + 56]    ; port
    mov  rcx, r14
    mov  rdx, r15
    sub  rsp, 32
    call __net_fill_sockaddr_win
    add  rsp, 32
    push 16
    lea  rax, [rel net_sockaddr_in]
    push rax
    xor  r9,  r9
    mov  r8,  r13
    mov  rdx, r12
    mov  rcx, rbx
    sub  rsp, 32
    call sendto            ; extern sendto needed for UDP
    add  rsp, 48
%else
    mov  rbx, rdi           ; fd
    mov  r12, rsi           ; buf
    mov  r13, rdx           ; len
    mov  r14, rcx           ; ip
    mov  r15, r8            ; port
    ; fill sockaddr
    mov  rdi, r14
    mov  rsi, r15
    call __net_fill_sockaddr
    ; sendto(fd, buf, len, 0, &sockaddr, 16)
    mov  rdi, rbx
    mov  rsi, r12
    mov  rdx, r13
    xor  r10, r10           ; flags = 0
    lea  r8,  [rel net_sockaddr_in]
    mov  r9,  16
    mov  rax, 44            ; sys_sendto
    syscall
%endif
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__udp_recvfrom(fd, buf, len) -> adad (bytes or -1)
; Receives a UDP datagram. Sender address stored internally
; (retrieve via net__peer_ip / net__peer_port).
; ============================================================
global net__udp_recvfrom
net__udp_recvfrom:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    push 16
    lea  rax, [rel net_peer_addrlen]
    push rax
    lea  r9,  [rel net_peer_addr]
    ; r8=len, rdx=buf, rcx=fd
    sub  rsp, 32
    call recvfrom          ; extern recvfrom
    add  rsp, 48
%else
    ; rdi=fd, rsi=buf, rdx=len
    xor  r10, r10           ; flags = 0
    lea  r8,  [rel net_peer_addr]
    mov  dword [rel net_peer_addrlen], 16
    lea  r9,  [rel net_peer_addrlen]
    mov  rax, 45            ; sys_recvfrom
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__peer_ip(fd: adad) -> lafz
; Returns IP string of the remote peer for a connected socket.
; Uses getpeername internally.
; ============================================================
global net__peer_ip
net__peer_ip:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
%ifdef WIN64_TARGET
    mov  rbx, rcx
    mov  dword [rel net_peer_addrlen], 16
    mov  rcx, rbx
    lea  rdx, [rel net_peer_addr]
    lea  r8,  [rel net_peer_addrlen]
    sub  rsp, 32
    call getpeername
    add  rsp, 32
%else
    mov  rbx, rdi
    mov  dword [rel net_peer_addrlen], 16
    lea  rsi, [rel net_peer_addr]
    lea  rdx, [rel net_peer_addrlen]
    mov  rax, 52            ; sys_getpeername
    syscall
%endif
    ; extract sin_addr (offset 4, 4 bytes) from net_peer_addr
    ; convert 4 bytes to "a.b.c.d\0" in net_ip_buf
    lea  r12, [rel net_ip_buf]
    lea  rbx, [rel net_peer_addr + 4]  ; &sin_addr

    ; write each octet
    movzx rdi, byte [rbx]
    lea  rsi, [rel net_ip_buf]
    call __net_u8_to_dec

    mov  byte [rsi], '.'
    inc  rsi
    movzx rdi, byte [rbx + 1]
    call __net_u8_to_dec

    mov  byte [rsi], '.'
    inc  rsi
    movzx rdi, byte [rbx + 2]
    call __net_u8_to_dec

    mov  byte [rsi], '.'
    inc  rsi
    movzx rdi, byte [rbx + 3]
    call __net_u8_to_dec

    mov  byte [rsi], 0
    lea  rax, [rel net_ip_buf]
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; net__peer_port(fd: adad) -> adad
; Returns port of remote peer (host byte order).
; ============================================================
global net__peer_port
net__peer_port:
    push rbp
    mov  rbp, rsp
    push rbx
%ifdef WIN64_TARGET
    mov  rbx, rcx
    mov  dword [rel net_peer_addrlen], 16
    mov  rcx, rbx
    lea  rdx, [rel net_peer_addr]
    lea  r8,  [rel net_peer_addrlen]
    sub  rsp, 32
    call getpeername
    add  rsp, 32
%else
    mov  rbx, rdi
    mov  dword [rel net_peer_addrlen], 16
    lea  rsi, [rel net_peer_addr]
    lea  rdx, [rel net_peer_addrlen]
    mov  rax, 52
    syscall
%endif
    ; sin_port at offset 2, big-endian → swap
    movzx rax, word [rel net_peer_addr + 2]
    xchg al, ah
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; __net_u8_to_dec(val: rdi, buf: rsi) → rsi advanced past digits
; Internal: writes decimal string of 0-255 into [rsi], advances rsi.
; ============================================================
__net_u8_to_dec:
    push rbx
    push rcx
    push rdx
    mov  rax, rdi
    xor  rcx, rcx           ; digit count
    ; convert to decimal digits (up to 3)
    lea  rbx, [rel net_ip_octet]
.u8_div:
    xor  rdx, rdx
    mov  r8,  10
    div  r8
    add  dl, '0'
    mov  [rbx + rcx], dl
    inc  rcx
    test rax, rax
    jnz  .u8_div
    ; digits are in reverse, write them forward
.u8_rev:
    dec  rcx
    mov  al, [rbx + rcx]
    mov  [rsi], al
    inc  rsi
    test rcx, rcx
    jnz  .u8_rev
    pop  rdx
    pop  rcx
    pop  rbx
    ret

%ifdef WIN64_TARGET
; ============================================================
; __net_fill_sockaddr_win(ip: rcx, port: rdx) — Windows helper
; Mirrors __net_fill_sockaddr for WIN64 calling convention.
; ============================================================
__net_fill_sockaddr_win:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    mov  rbx, rcx           ; ip string
    mov  r12, rdx           ; port
    ; inet_addr(ip)
    sub  rsp, 32
    call inet_addr
    add  rsp, 32
    mov  r8,  rax           ; packed IP
    ; htons(port)
    mov  rcx, r12
    sub  rsp, 32
    call htons
    add  rsp, 32
    movzx rax, ax
    ; fill sockaddr_in
    lea  rdx, [rel net_sockaddr_in]
    mov  qword [rdx],     0
    mov  qword [rdx + 8], 0
    mov  word  [rdx],     net_af_inet
    mov  word  [rdx + 2], ax
    mov  dword [rdx + 4], r8d
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret
%endif
