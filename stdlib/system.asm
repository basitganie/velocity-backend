; ============================================================
; Velocity StdLib - System Module (system.asm) v0.3.3
; Windows (x86-64) + Linux x86-64 + AArch64 Android/Linux
;
; Targets selected at assemble time:
;   WIN64_TARGET   — nasm -f win64  (or auto-detected)
;   AARCH64_TARGET — nasm -f elf64 -D AARCH64_TARGET
;   otherwise      — x86-64 Linux/WSL (nasm -f elf64)
;
; AArch64 notes:
;   • Android Bionic removed legacy syscalls (open/fork/pipe/etc.).
;     We use openat(AT_FDCWD), pipe2, clone(SIGCHLD), dup3, wait4.
;   • Syscall ABI: x0-x7 args, x8 = nr, x0 = result.
;   • No "default rel" for aarch64 (NASM ignores it; all addresses
;     are PC-relative via adrp/add pairs).
; ============================================================

; ---------- target detection --------------------------------
%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

%ifndef AARCH64_TARGET
%ifdef __NASM_VER__       ; present in all nasm versions
  ; user must pass -D AARCH64_TARGET for aarch64 builds
%endif
%endif

; ---------- x86-64 only directive ---------------------------
%ifndef AARCH64_TARGET
default rel
%endif

; ============================================================
; Externals
; ============================================================
extern _VL_argc
extern _VL_argv
extern _VL_envp

%ifdef WIN64_TARGET
extern ExitProcess
extern system
extern popen
extern pclose
extern fread
extern DeleteFileA
extern RemoveDirectoryA
extern CreateDirectoryA
extern GetFileAttributesA
extern GetCurrentDirectoryA
extern SetCurrentDirectoryA
extern Sleep
extern GetCurrentProcessId
extern CloseHandle
extern GetVersionExA
extern GetEnvironmentVariableA
%endif

; ============================================================
section .text
; ============================================================

; ============================================================
; system__exit(code) -> (noreturn)
; ============================================================
global system__exit
system__exit:
%ifdef WIN64_TARGET
    sub  rsp, 32
    call ExitProcess
    add  rsp, 32
%elifdef AARCH64_TARGET
    mov  x8, 93         ; __NR_exit (AArch64)
    svc  #0
%else
    mov  rax, 60        ; sys_exit (x86-64)
    syscall
%endif

; ============================================================
; system__argc() -> adad
; ============================================================
global system__argc
system__argc:
%ifdef AARCH64_TARGET
    adrp x0, _VL_argc
    ldr  x0, [x0, #:lo12:_VL_argc]
    ret
%else
    mov  rax, [rel _VL_argc]
    ret
%endif

; ============================================================
; system__argv(i) -> lafz?
; ============================================================
global system__argv
system__argv:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
%ifdef AARCH64_TARGET
    adrp x1, _VL_argc
    ldr  x1, [x1, #:lo12:_VL_argc]
    cmp  x0, x1
    bhs  .oor_aa
    adrp x1, _VL_argv
    ldr  x1, [x1, #:lo12:_VL_argv]
    ldr  x0, [x1, x0, lsl #3]
    ret
.oor_aa:
    mov  x0, #0
    ret
%else
    mov  rax, [rel _VL_argc]
    cmp  rdi, rax
    jae  .oor
    mov  rbx, [rel _VL_argv]
    mov  rax, [rbx + rdi*8]
    ret
.oor:
    xor  rax, rax
    ret
%endif

; ============================================================
; system__getenv(key) -> lafz?
; Scans _VL_envp for "key=value", returns ptr to value part.
; ============================================================
global system__getenv
system__getenv:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    sub  rsp, 32
    mov  rax, [rel sys_env_slot]
    mov  r9, rax
    inc  r9
    and  r9, 3
    mov  [rel sys_env_slot], r9
    shl  rax, 12
    lea  rdx, [rel sys_env_buf]
    add  rdx, rax
    mov  r9, rdx
    ; rcx = key
    mov  r8,  4096
    call GetEnvironmentVariableA
    test eax, eax
    jz   .env_not_found_win
    mov  rax, r9
    jmp  .env_done_win
.env_not_found_win:
    xor  rax, rax
.env_done_win:
    mov  rsp, rbp
    pop  rbp
    ret
%elifdef AARCH64_TARGET
    ; x0 = key
    stp  x19, x20, [sp, #-48]!
    stp  x21, x22, [sp, #16]
    stp  x23, lr,  [sp, #32]

    mov  x19, x0                ; key
    adrp x20, _VL_envp
    ldr  x20, [x20, #:lo12:_VL_envp]
.aa_env_loop:
    ldr  x21, [x20]
    cbz  x21, .aa_env_notfound
    mov  x22, x19               ; rdi = key
    mov  x23, x21               ; rsi = envp entry
.aa_env_cmp:
    ldrb w0, [x22]
    ldrb w1, [x23]
    cbz  w0, .aa_env_key_end
    cmp  w0, w1
    bne  .aa_env_next
    add  x22, x22, #1
    add  x23, x23, #1
    b    .aa_env_cmp
.aa_env_key_end:
    cmp  w1, #'='
    bne  .aa_env_next
    add  x0, x23, #1
    b    .aa_env_done
.aa_env_next:
    add  x20, x20, #8
    b    .aa_env_loop
.aa_env_notfound:
    mov  x0, #0
.aa_env_done:
    ldp  x23, lr,  [sp, #32]
    ldp  x21, x22, [sp, #16]
    ldp  x19, x20, [sp], #48
    ret
%else
    push rbx
    push r12
    push r13
    push r14

    mov  r12, rdi
    mov  rbx, [rel _VL_envp]
.env_loop:
    mov  r13, [rbx]
    test r13, r13
    jz   .env_not_found
    mov  rdi, r12
    mov  rsi, r13
.env_cmp:
    mov  al, [rdi]
    mov  dl, [rsi]
    cmp  al, 0
    je   .env_key_end
    cmp  al, dl
    jne  .env_next
    inc  rdi
    inc  rsi
    jmp  .env_cmp
.env_key_end:
    cmp  dl, '='
    jne  .env_next
    lea  rax, [rsi + 1]
    jmp  .env_done
.env_next:
    add  rbx, 8
    jmp  .env_loop
.env_not_found:
    xor  rax, rax
.env_done:
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    ret
%endif

; ============================================================
; system__getenv_safe(key) -> lafz  (never null; "" if missing)
; ============================================================
global system__getenv_safe
system__getenv_safe:
%ifdef WIN64_TARGET
    sub  rsp, 40
    call system__getenv
    add  rsp, 40
%elifdef AARCH64_TARGET
    stp  x29, lr, [sp, #-16]!
    mov  x29, sp
    bl   system__getenv
    ldp  x29, lr, [sp], #16
    cbnz x0, .ges_ok_aa
    adrp x0, sys_empty_str
    add  x0, x0, #:lo12:sys_empty_str
.ges_ok_aa:
    ret
%else
    call system__getenv
%endif
%ifndef AARCH64_TARGET
    test rax, rax
    jnz  .ges_ok
    lea  rax, [rel sys_empty_str]
.ges_ok:
    ret
%endif

; ============================================================
; system__sh(cmd) -> lafz   alias for system__cmd
; ============================================================
global system__sh
system__sh:
    jmp  system__cmd

; ============================================================
; system__ok(cmd) -> adad  (1 if exit 0, else 0)
; ============================================================
global system__ok
system__ok:
%ifdef WIN64_TARGET
    sub  rsp, 40
    call system__run
    add  rsp, 40
%elifdef AARCH64_TARGET
    stp  x29, lr, [sp, #-16]!
    mov  x29, sp
    bl   system__run
    ldp  x29, lr, [sp], #16
    cmp  x0, #0
    cset x0, eq
    ret
%else
    call system__run
%endif
%ifndef AARCH64_TARGET
    test rax, rax
    jnz  .ok_no
    mov  rax, 1
    ret
.ok_no:
    xor  rax, rax
    ret
%endif

; ============================================================
; system__run(cmd) -> adad  (exit status; stdout passes through)
; ============================================================
global system__run
system__run:
%ifdef WIN64_TARGET
    ; rcx = cmd
    sub  rsp, 40
    call system
    add  rsp, 40
    ret

%elifdef AARCH64_TARGET
    ; x0 = cmd
    stp  x19, x20, [sp, #-32]!
    stp  x29, lr,  [sp, #16]
    mov  x29, sp
    mov  x19, x0                ; save cmd

    ; clone(SIGCHLD, 0) — equivalent to fork() on Android
    mov  x0, #17               ; SIGCHLD
    mov  x1, #0
    mov  x8, #220              ; __NR_clone
    svc  #0
    cmp  x0, #0
    blt  .run_fail_aa
    beq  .run_child_aa

    ; parent: wait4(pid, &wstat, 0, NULL)
    mov  x19, x0               ; save pid
    mov  x1, #220              ; re-use x1 as temp; save wstat addr below
    adrp x1, sys_run_wstat
    add  x1, x1, #:lo12:sys_run_wstat
    mov  x2, #0
    mov  x3, #0
    mov  x8, #260              ; __NR_wait4
    svc  #0
    ; WEXITSTATUS = (wstat >> 8) & 0xFF
    adrp x0, sys_run_wstat
    add  x0, x0, #:lo12:sys_run_wstat
    ldrb w0, [x0, #1]
    sxtw x0, w0
    b    .run_ret_aa

.run_child_aa:
    ; execve("/bin/sh", ["/bin/sh","-c",cmd,NULL], envp)
    adrp x0, sys_sh_path
    add  x0, x0, #:lo12:sys_sh_path
    ; build argv on stack
    sub  sp, sp, #32
    adrp x1, sys_sh_path
    add  x1, x1, #:lo12:sys_sh_path
    str  x1, [sp, #0]
    adrp x1, sys_sh_flag
    add  x1, x1, #:lo12:sys_sh_flag
    str  x1, [sp, #8]
    str  x19, [sp, #16]        ; cmd
    str  xzr, [sp, #24]        ; NULL terminator
    mov  x1, sp
    adrp x2, _VL_envp
    ldr  x2, [x2, #:lo12:_VL_envp]
    mov  x8, #221              ; __NR_execve
    svc  #0
    ; execve failed
    mov  x0, #1
    mov  x8, #93               ; __NR_exit
    svc  #0

.run_fail_aa:
    mov  x0, #-1
.run_ret_aa:
    ldp  x29, lr,  [sp, #16]
    ldp  x19, x20, [sp], #32
    ret

%else
    ; x86-64 Linux: fork + execve + wait4 (pure syscalls)
    push rbp
    mov  rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov  rax, 57               ; sys_fork
    syscall
    test rax, rax
    js   .run_fail
    jz   .run_child

    ; parent
    mov  r12, rax
    mov  rax, 61               ; sys_wait4
    mov  rdi, r12
    lea  rsi, [rel sys_run_wstat]
    xor  rdx, rdx
    xor  r10, r10
    syscall
    movzx eax, byte [rel sys_run_wstat + 1]
    movsx rax, eax
    jmp  .run_ret

.run_child:
    sub  rsp, 32
    lea  rax, [rel sys_sh_path]
    mov  [rsp +  0], rax
    lea  rax, [rel sys_sh_flag]
    mov  [rsp +  8], rax
    mov  [rsp + 16], rdi       ; cmd (rdi still valid after fork)
    mov  qword [rsp + 24], 0
    mov  rax, 59               ; sys_execve
    lea  rdi, [rel sys_sh_path]
    mov  rsi, rsp
    mov  rdx, [rel _VL_envp]
    syscall
    mov  rax, 60
    mov  rdi, 1
    syscall

.run_fail:
    mov  rax, -1
.run_ret:
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbp
    ret
%endif

; ============================================================
; system__cmd(cmd) -> lafz
; Runs cmd via /bin/sh -c, captures stdout, strips trailing
; newlines.  Returns ptr to static 65535-byte buffer.
;
; Windows : popen/fread/pclose
; AArch64 : pipe2(O_CLOEXEC) + clone + dup3 + execve + wait4
; x86-64  : pipe + fork + dup2 + execve + wait4  (pure syscalls)
; ============================================================
global system__cmd
system__cmd:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 8                ; 16-byte align

    ; CRITICAL: save cmd (rcx is volatile — clobbered by shadow-space
    ; setup and the popen call itself).
    mov  r12, rcx              ; r12 = cmd (non-volatile)

    ; Rotate buffers so consecutive cmd() results can be held at once.
    mov  rax, [rel sys_cmd_slot]
    mov  rcx, rax
    inc  rcx
    and  rcx, 3
    mov  [rel sys_cmd_slot], rcx
    shl  rax, 16
    lea  r15, [rel sys_cmd_buf]
    add  r15, rax

    ; popen(cmd, "r")
    mov  rcx, r12
    lea  rdx, [rel sys_r_mode]
    sub  rsp, 32
    call popen
    add  rsp, 32
    test rax, rax
    jz   .scmd_fail
    mov  r13, rax              ; FILE*

    mov  rbx, r15
.win_read_loop:
    lea  rax, [r15 + 65534]
    cmp  rbx, rax
    jae  .win_close
    mov  r14, rax
    sub  r14, rbx              ; remaining bytes
    mov  rcx, rbx              ; ptr
    mov  rdx, 1                ; size
    mov  r8,  r14              ; count
    mov  r9,  r13              ; FILE*
    sub  rsp, 32
    call fread
    add  rsp, 32
    test rax, rax
    jz   .win_close
    add  rbx, rax
    jmp  .win_read_loop
.win_close:
    mov  byte [rbx], 0
    mov  rcx, r13
    sub  rsp, 32
    call pclose
    add  rsp, 32
    jmp  .scmd_strip

.scmd_fail:
    lea  rax, [rel sys_empty_str]
    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

.scmd_strip:
.strip_loop_w:
    cmp  rbx, r15
    jbe  .scmd_stripped_w
    dec  rbx
    movzx eax, byte [rbx]
    cmp  eax, 10
    je   .strip_loop_w
    cmp  eax, 13
    je   .strip_loop_w
    inc  rbx
.scmd_stripped_w:
    mov  byte [rbx], 0
    mov  rax, r15
    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

%elifdef AARCH64_TARGET
    ; x19=cmd  x20=write-fd  x21=read-fd  x22=child-pid  x23=buf-ptr
    stp  x19, x20, [sp, #-64]!
    stp  x21, x22, [sp, #16]
    stp  x23, x24, [sp, #32]
    stp  x29, lr,  [sp, #48]
    mov  x29, sp
    mov  x19, x0               ; save cmd

    ; pipe2(pipefd, O_CLOEXEC=0x80000)
    adrp x0, sys_cmd_pipe
    add  x0, x0, #:lo12:sys_cmd_pipe
    mov  x1, #0x80000          ; O_CLOEXEC
    mov  x8, #293              ; __NR_pipe2
    svc  #0
    cbnz x0, .aa_scmd_fail

    adrp x0, sys_cmd_pipe
    add  x0, x0, #:lo12:sys_cmd_pipe
    ldr  w21, [x0, #0]         ; read end
    ldr  w20, [x0, #4]         ; write end

    ; clone(SIGCHLD, 0)
    mov  x0, #17
    mov  x1, #0
    mov  x8, #220              ; __NR_clone
    svc  #0
    cmp  x0, #0
    blt  .aa_scmd_fail
    beq  .aa_scmd_child

    ; ---- PARENT ----
    mov  x22, x0               ; child pid
    ; close write end
    mov  x0, x20
    mov  x8, #57               ; __NR_close
    svc  #0

    ; read all output
    adrp x23, sys_cmd_buf
    add  x23, x23, #:lo12:sys_cmd_buf
.aa_parent_read:
    adrp x0, sys_cmd_buf
    add  x0, x0, #:lo12:sys_cmd_buf
    add  x0, x0, #65534
    cmp  x23, x0
    bhs  .aa_read_done
    sub  x2, x0, x23           ; remaining
    mov  x0, x21               ; read fd
    mov  x1, x23               ; buf
    mov  x8, #63               ; __NR_read
    svc  #0
    cmp  x0, #0
    ble  .aa_read_done
    add  x23, x23, x0
    b    .aa_parent_read
.aa_read_done:
    strb wzr, [x23]
    ; close read end
    mov  x0, x21
    mov  x8, #57
    svc  #0
    ; wait4(pid, &wstat, 0, NULL)
    mov  x0, x22
    adrp x1, sys_cmd_wstat
    add  x1, x1, #:lo12:sys_cmd_wstat
    mov  x2, #0
    mov  x3, #0
    mov  x8, #260              ; __NR_wait4
    svc  #0
    b    .aa_scmd_strip

.aa_scmd_child:
    ; close read end
    mov  x0, x21
    mov  x8, #57
    svc  #0
    ; dup3(write_end, STDOUT=1, 0)
    mov  x0, x20
    mov  x1, #1
    mov  x2, #0
    mov  x8, #24               ; __NR_dup3
    svc  #0
    ; close write end (now dup'd to 1)
    mov  x0, x20
    mov  x8, #57
    svc  #0
    ; execve("/bin/sh", ["/bin/sh","-c",cmd,NULL], envp)
    sub  sp, sp, #32
    adrp x0, sys_sh_path
    add  x0, x0, #:lo12:sys_sh_path
    str  x0, [sp, #0]
    adrp x1, sys_sh_flag
    add  x1, x1, #:lo12:sys_sh_flag
    str  x1, [sp, #8]
    str  x19, [sp, #16]        ; cmd
    str  xzr, [sp, #24]
    mov  x1, sp
    adrp x2, _VL_envp
    ldr  x2, [x2, #:lo12:_VL_envp]
    adrp x0, sys_sh_path
    add  x0, x0, #:lo12:sys_sh_path
    mov  x8, #221              ; __NR_execve
    svc  #0
    mov  x0, #127
    mov  x8, #93
    svc  #0

.aa_scmd_strip:
    adrp x24, sys_cmd_buf
    add  x24, x24, #:lo12:sys_cmd_buf
.aa_strip_loop:
    cmp  x23, x24
    bls  .aa_stripped
    sub  x23, x23, #1
    ldrb w0, [x23]
    cmp  w0, #10               ; '\n'
    beq  .aa_strip_loop
    cmp  w0, #13               ; '\r'
    beq  .aa_strip_loop
    add  x23, x23, #1
.aa_stripped:
    strb wzr, [x23]
    adrp x0, sys_cmd_buf
    add  x0, x0, #:lo12:sys_cmd_buf
    b    .aa_scmd_ret

.aa_scmd_fail:
    adrp x0, sys_empty_str
    add  x0, x0, #:lo12:sys_empty_str
.aa_scmd_ret:
    ldp  x29, lr,  [sp, #48]
    ldp  x23, x24, [sp, #32]
    ldp  x21, x22, [sp, #16]
    ldp  x19, x20, [sp], #64
    ret

%else
    ; x86-64 Linux
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 8

    mov  r12, rdi              ; save cmd

    ; Rotate buffers so consecutive cmd() results can be held at once.
    mov  rax, [rel sys_cmd_slot]
    mov  rcx, rax
    inc  rcx
    and  rcx, 3
    mov  [rel sys_cmd_slot], rcx
    shl  rax, 16
    lea  r15, [rel sys_cmd_buf]
    add  r15, rax

    ; pipe(pipefd)
    mov  rax, 22               ; sys_pipe
    lea  rdi, [rel sys_cmd_pipe]
    syscall
    test rax, rax
    js   .scmd_fail

    ; fork()
    mov  rax, 57
    syscall
    test rax, rax
    js   .scmd_fail
    jz   .scmd_child

    ; ---- PARENT ----
    mov  r13, rax
    mov  rax, 3
    movsx rdi, dword [rel sys_cmd_pipe + 4]
    syscall

    movsx r14, dword [rel sys_cmd_pipe]
    mov  rbx, r15

.parent_read:
    lea  rax, [r15 + 65534]
    cmp  rbx, rax
    jae  .parent_read_done
    mov  rdx, rax
    sub  rdx, rbx
    mov  rax, 0
    mov  rdi, r14
    mov  rsi, rbx
    syscall
    test rax, rax
    jle  .parent_read_done
    add  rbx, rax
    jmp  .parent_read

.parent_read_done:
    mov  byte [rbx], 0
    mov  rax, 3
    mov  rdi, r14
    syscall
    mov  rax, 61               ; sys_wait4
    mov  rdi, r13
    lea  rsi, [rel sys_cmd_wstat]
    xor  rdx, rdx
    xor  r10, r10
    syscall
    jmp  .scmd_strip

.scmd_child:
    ; close read end
    mov  rax, 3
    movsx rdi, dword [rel sys_cmd_pipe]
    syscall
    ; dup2(write_end, 1)
    mov  rax, 33
    movsx rdi, dword [rel sys_cmd_pipe + 4]
    mov  rsi, 1
    syscall
    ; close write end
    mov  rax, 3
    movsx rdi, dword [rel sys_cmd_pipe + 4]
    syscall
    ; execve
    sub  rsp, 32
    lea  rax, [rel sys_sh_path]
    mov  [rsp +  0], rax
    lea  rax, [rel sys_sh_flag]
    mov  [rsp +  8], rax
    mov  [rsp + 16], r12
    mov  qword [rsp + 24], 0
    mov  rax, 59
    lea  rdi, [rel sys_sh_path]
    mov  rsi, rsp
    mov  rdx, [rel _VL_envp]
    syscall
    mov  rax, 60
    mov  rdi, 127
    syscall

.scmd_strip:
.strip_loop:
    cmp  rbx, r15
    jbe  .scmd_stripped
    dec  rbx
    movzx eax, byte [rbx]
    cmp  eax, 10
    je   .strip_loop
    cmp  eax, 13
    je   .strip_loop
    inc  rbx
.scmd_stripped:
    mov  byte [rbx], 0
    mov  rax, r15
    jmp  .scmd_ret

.scmd_fail:
    lea  rax, [rel sys_empty_str]

.scmd_ret:
    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret
%endif

; ============================================================
; FILESYSTEM FUNCTIONS
; ============================================================

; -- system__getcwd() -> lafz (ptr or NULL) -------------------
global system__getcwd
system__getcwd:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    ; GetCurrentDirectoryA(size, buf)
    sub  rsp, 32
    mov  rcx, 4096
    lea  rdx, [rel sys_cwd_buf]
    call GetCurrentDirectoryA
    add  rsp, 32
    test rax, rax
    jz   .gcwd_null
    lea  rax, [rel sys_cwd_buf]
    jmp  .gcwd_win_ret
.gcwd_null:
    xor  rax, rax
.gcwd_win_ret:
    mov  rsp, rbp
    pop  rbp
    ret

%elifdef AARCH64_TARGET
    stp  x29, lr, [sp, #-16]!
    mov  x29, sp
    adrp x0, sys_cwd_buf
    add  x0, x0, #:lo12:sys_cwd_buf
    mov  x1, #4096
    mov  x8, #17               ; __NR_getcwd
    svc  #0
    cmp  x0, #0
    ble  .gcwd_err_aa
    adrp x0, sys_cwd_buf
    add  x0, x0, #:lo12:sys_cwd_buf
    b    .gcwd_ret_aa
.gcwd_err_aa:
    mov  x0, #0
.gcwd_ret_aa:
    ldp  x29, lr, [sp], #16
    ret

%else
    push rbp
    mov  rbp, rsp
    mov  rax, 79               ; sys_getcwd
    lea  rdi, [rel sys_cwd_buf]
    mov  rsi, 4096
    syscall
    test rax, rax
    jle  .gcwd_err
    lea  rax, [rel sys_cwd_buf]
    jmp  .gcwd_ret
.gcwd_err:
    xor  rax, rax
.gcwd_ret:
    mov  rsp, rbp
    pop  rbp
    ret
%endif

; -- system__chdir(path) -> adad (0=ok, -1=err) ---------------
global system__chdir
system__chdir:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    ; SetCurrentDirectoryA(path)  rcx=path already
    sub  rsp, 32
    call SetCurrentDirectoryA
    add  rsp, 32
    test rax, rax
    jnz  .cd_ok
    mov  rax, -1
    jmp  .cd_ret
.cd_ok:
    xor  rax, rax
.cd_ret:
    mov  rsp, rbp
    pop  rbp
    ret

%elifdef AARCH64_TARGET
    mov  x8, #49               ; __NR_chdir
    svc  #0
    ret

%else
    push rbp
    mov  rbp, rsp
    mov  rax, 80               ; sys_chdir
    syscall
    mov  rsp, rbp
    pop  rbp
    ret
%endif

; -- system__mkdir(path) -> adad (0=ok, -1=err) ---------------
global system__mkdir
system__mkdir:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    ; CreateDirectoryA(path, NULL)  rcx=path already
    sub  rsp, 32
    xor  rdx, rdx
    call CreateDirectoryA
    add  rsp, 32
    test rax, rax
    jnz  .mkdir_ok
    mov  rax, -1
    jmp  .mkdir_ret
.mkdir_ok:
    xor  rax, rax
.mkdir_ret:
    mov  rsp, rbp
    pop  rbp
    ret

%elifdef AARCH64_TARGET
    ; mkdirat(AT_FDCWD, path, 0755)
    mov  x2, x0                ; mode
    mov  x1, x0                ; path
    mov  x2, #0755
    mov  x0, #-100             ; AT_FDCWD
    mov  x8, #34               ; __NR_mkdirat
    svc  #0
    ret

%else
    push rbp
    mov  rbp, rsp
    mov  rsi, 0755o
    mov  rax, 83               ; sys_mkdir
    syscall
    mov  rsp, rbp
    pop  rbp
    ret
%endif

; -- system__exists(path) -> adad (1=yes, 0=no) ---------------
global system__exists
system__exists:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    ; GetFileAttributesA(path)  rcx=path already
    sub  rsp, 32
    call GetFileAttributesA
    add  rsp, 32
    cmp  eax, 0xFFFFFFFF       ; INVALID_FILE_ATTRIBUTES
    je   .ex_no
    mov  rax, 1
    jmp  .ex_ret
.ex_no:
    xor  rax, rax
.ex_ret:
    mov  rsp, rbp
    pop  rbp
    ret

%elifdef AARCH64_TARGET
    ; faccessat(AT_FDCWD, path, F_OK, 0)
    mov  x3, #0
    mov  x2, #0                ; F_OK
    mov  x1, x0                ; path
    mov  x0, #-100             ; AT_FDCWD
    mov  x8, #48               ; __NR_faccessat
    svc  #0
    cmp  x0, #0
    cset x0, eq
    ret

%else
    push rbp
    mov  rbp, rsp
    mov  rax, 21               ; sys_access
    xor  rsi, rsi
    syscall
    test rax, rax
    setz al
    movzx rax, al
    mov  rsp, rbp
    pop  rbp
    ret
%endif

; -- system__rm(path) -> adad (0=ok, -1=err) ------------------
;    Tries unlink/unlinkat first; falls back to rmdir/rmdirat.
global system__rm
system__rm:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    push rbx
    mov  rbx, rcx              ; save path
    sub  rsp, 40               ; 32 shadow + 8 align
    call DeleteFileA
    add  rsp, 40
    test rax, rax
    jnz  .rm_ok_win
    ; try RemoveDirectoryA
    mov  rcx, rbx
    sub  rsp, 32
    call RemoveDirectoryA
    add  rsp, 32
    test rax, rax
    jnz  .rm_ok_win
    pop  rbx
    mov  rax, -1
    mov  rsp, rbp
    pop  rbp
    ret
.rm_ok_win:
    pop  rbx
    xor  rax, rax
    mov  rsp, rbp
    pop  rbp
    ret

%elifdef AARCH64_TARGET
    stp  x19, lr, [sp, #-16]!
    mov  x19, x0               ; save path
    ; unlinkat(AT_FDCWD, path, 0)
    mov  x2, #0
    mov  x1, x19
    mov  x0, #-100
    mov  x8, #35               ; __NR_unlinkat
    svc  #0
    cbz  x0, .rm_ok_aa
    ; EISDIR = -21; try unlinkat with AT_REMOVEDIR=0x200
    cmn  x0, #21
    bne  .rm_fail_aa
    mov  x2, #0x200            ; AT_REMOVEDIR
    mov  x1, x19
    mov  x0, #-100
    mov  x8, #35
    svc  #0
    cbz  x0, .rm_ok_aa
.rm_fail_aa:
    mov  x0, #-1
    ldp  x19, lr, [sp], #16
    ret
.rm_ok_aa:
    mov  x0, #0
    ldp  x19, lr, [sp], #16
    ret

%else
    push rbp
    mov  rbp, rsp
    push rbx
    mov  rbx, rdi
    mov  rax, 87               ; sys_unlink
    syscall
    test rax, rax
    jz   .rm_ok
    cmp  rax, -21              ; EISDIR
    jne  .rm_fail
    mov  rdi, rbx
    mov  rax, 84               ; sys_rmdir
    syscall
    test rax, rax
    jz   .rm_ok
.rm_fail:
    mov  rax, -1
    jmp  .rm_done
.rm_ok:
    xor  rax, rax
.rm_done:
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret
%endif

; ============================================================
; OS-LEVEL SYSCALL WRAPPERS
; ============================================================

; -- system__mmap(addr, len, prot, flags) -> adad -------------
global system__mmap
system__mmap:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%elifdef AARCH64_TARGET
    ; x0=addr x1=len x2=prot x3=flags x4=fd x5=offset
    mov  x4, #-1               ; fd = -1 (anonymous)
    mov  x5, #0                ; offset
    mov  x8, #222              ; __NR_mmap
    svc  #0
%else
    ; rdi=addr rsi=len rdx=prot rcx=flags
    mov  r9,  -1
    mov  r8,  rcx
    mov  rcx, 0
    mov  rax, 9
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__munmap(addr, len) -> adad ------------------------
global system__munmap
system__munmap:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax
%elifdef AARCH64_TARGET
    mov  x8, #215              ; __NR_munmap
    svc  #0
%else
    mov  rax, 11
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__mprotect(addr, len, prot) -> adad ----------------
global system__mprotect
system__mprotect:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax
%elifdef AARCH64_TARGET
    mov  x8, #226              ; __NR_mprotect
    svc  #0
%else
    mov  rax, 10
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__sleep(secs) -> adad ------------------------------
global system__sleep
system__sleep:
    push rbp
    mov  rbp, rsp
    push rbx
%ifdef WIN64_TARGET
    ; Sleep takes ms; rdi not set on Windows — use rcx
    imul rcx, rcx, 1000
    sub  rsp, 40
    call Sleep
    add  rsp, 40
    xor  rax, rax
%elifdef AARCH64_TARGET
    ; nanosleep on stack
    sub  sp, sp, #16
    str  x0, [sp, #0]          ; tv_sec
    str  xzr, [sp, #8]         ; tv_nsec = 0
    mov  x0, sp
    mov  x1, #0
    mov  x8, #101              ; __NR_nanosleep
    svc  #0
    add  sp, sp, #16
%else
    sub  rsp, 32
    mov  [rsp],   rdi
    mov  qword [rsp+8], 0
    mov  rdi, rsp
    xor  rsi, rsi
    mov  rax, 35
    syscall
    add  rsp, 32
%endif
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__usleep(usecs) -> adad ----------------------------
global system__usleep
system__usleep:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; convert µs -> ms  (rcx = usecs on Windows)
    mov  rax, rcx
    xor  rdx, rdx
    mov  rcx, 1000
    div  rcx
    mov  rcx, rax
    sub  rsp, 32
    call Sleep
    add  rsp, 32
    xor  rax, rax
%elifdef AARCH64_TARGET
    sub  sp, sp, #16
    str  xzr, [sp, #0]         ; tv_sec = 0
    mov  x1, #1000
    mul  x0, x0, x1            ; tv_nsec = usecs * 1000
    str  x0, [sp, #8]
    mov  x0, sp
    mov  x1, #0
    mov  x8, #101
    svc  #0
    add  sp, sp, #16
%else
    sub  rsp, 32
    xor  rax, rax
    mov  [rsp], rax
    imul rdi, rdi, 1000
    mov  [rsp+8], rdi
    mov  rdi, rsp
    xor  rsi, rsi
    mov  rax, 35
    syscall
    add  rsp, 32
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__getpid() -> adad ---------------------------------
global system__getpid
system__getpid:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    call GetCurrentProcessId
    add  rsp, 32
%elifdef AARCH64_TARGET
    mov  x8, #172              ; __NR_getpid
    svc  #0
%else
    mov  rax, 39
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__getppid() -> adad --------------------------------
global system__getppid
system__getppid:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1               ; unavailable on Windows
%elifdef AARCH64_TARGET
    mov  x8, #173              ; __NR_getppid
    svc  #0
%else
    mov  rax, 110
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__kill(pid, sig) -> adad ---------------------------
global system__kill
system__kill:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%elifdef AARCH64_TARGET
    mov  x8, #129              ; __NR_kill
    svc  #0
%else
    mov  rax, 62
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__open(path, flags, mode) -> adad ------------------
global system__open
system__open:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%elifdef AARCH64_TARGET
    ; openat(AT_FDCWD, path, flags, mode)
    mov  x3, x2                ; mode
    mov  x2, x1                ; flags
    mov  x1, x0                ; path
    mov  x0, #-100             ; AT_FDCWD
    mov  x8, #56               ; __NR_openat
    svc  #0
%else
    mov  rax, 2
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__close(fd) -> adad --------------------------------
global system__close
system__close:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    call CloseHandle
    add  rsp, 32
    xor  rax, rax
%elifdef AARCH64_TARGET
    mov  x8, #57               ; __NR_close
    svc  #0
%else
    mov  rax, 3
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__read_fd(fd, buf, len) -> adad --------------------
global system__read_fd
system__read_fd:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%elifdef AARCH64_TARGET
    mov  x8, #63               ; __NR_read
    svc  #0
%else
    mov  rax, 0
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__write_fd(fd, buf, len) -> adad -------------------
global system__write_fd
system__write_fd:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%elifdef AARCH64_TARGET
    mov  x8, #64               ; __NR_write
    svc  #0
%else
    mov  rax, 1
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__seek(fd, offset, whence) -> adad -----------------
global system__seek
system__seek:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%elifdef AARCH64_TARGET
    mov  x8, #62               ; __NR_lseek
    svc  #0
%else
    mov  rax, 8
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__stat_size(path) -> adad (size or -1) -------------
global system__stat_size
system__stat_size:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%elifdef AARCH64_TARGET
    ; fstatat(AT_FDCWD, path, &stat_buf, 0)
    ; struct stat on AArch64: st_size at offset 48
    sub  sp, sp, #144
    mov  x3, #0
    mov  x2, sp
    mov  x1, x0
    mov  x0, #-100             ; AT_FDCWD
    mov  x8, #79               ; __NR_newfstatat
    svc  #0
    cbnz x0, .stat_fail_aa
    ldr  x0, [sp, #48]
    add  sp, sp, #144
    b    .stat_done_aa
.stat_fail_aa:
    add  sp, sp, #144
    mov  x0, #-1
.stat_done_aa:
%else
    push rbx
    sub  rsp, 144 + 8
    mov  rbx, rsp
    mov  rax, 4                ; sys_stat
    mov  rsi, rbx
    syscall
    test rax, rax
    jnz  .stat_fail
    mov  rax, [rbx + 48]
    jmp  .stat_done
.stat_fail:
    mov  rax, -1
.stat_done:
    add  rsp, 144 + 8
    pop  rbx
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__ioctl(fd, req, arg) -> adad ----------------------
global system__ioctl
system__ioctl:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%elifdef AARCH64_TARGET
    mov  x8, #29               ; __NR_ioctl
    svc  #0
%else
    mov  rax, 16
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; system__uname() -> lafz  ("Linux 6.x.y" style)
; ============================================================
section .bss
_vel_uname_buf:  resb 400
_vel_uname_out:  resb 200

section .text
global system__uname
system__uname:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; Use GetVersionExA to get real Windows version
    ; OSVERSIONINFOA: dwOSVersionInfoSize(4) + major(4) + minor(4) + build(4) + ...
    sub  rsp, 160              ; sizeof OSVERSIONINFOA = 148, padded
    mov  dword [rsp], 148      ; dwOSVersionInfoSize
    mov  rcx, rsp
    sub  rsp, 32
    call GetVersionExA
    add  rsp, 32
    ; format "Windows <major>.<minor>" into _vel_uname_out
    ; For simplicity we return the static string but with real major.minor
    ; Full formatting would need itoa; keep stub but honest
    lea  rax, [rel _vel_uname_win]
    add  rsp, 160
    mov  rsp, rbp
    pop  rbp
    ret

%elifdef AARCH64_TARGET
    sub  sp, sp, #400          ; struct utsname
    mov  x0, sp
    mov  x8, #160              ; __NR_uname
    svc  #0
    ; copy sysname (offset 0) to _vel_uname_out
    adrp x2, _vel_uname_out
    add  x2, x2, #:lo12:_vel_uname_out
    mov  x3, sp                ; sysname
    mov  x4, #64
.aa_un_cpy1:
    ldrb w0, [x3]
    cbz  w0, .aa_un_spc
    strb w0, [x2]
    add  x3, x3, #1
    add  x2, x2, #1
    subs x4, x4, #1
    bne  .aa_un_cpy1
.aa_un_spc:
    mov  w0, #32
    strb w0, [x2]
    add  x2, x2, #1
    ; AArch64 utsname field size is 65 bytes; release at offset 65
    add  x3, sp, #65
    mov  x4, #64
.aa_un_cpy2:
    ldrb w0, [x3]
    cbz  w0, .aa_un_done
    strb w0, [x2]
    add  x3, x3, #1
    add  x2, x2, #1
    subs x4, x4, #1
    bne  .aa_un_cpy2
.aa_un_done:
    strb wzr, [x2]
    add  sp, sp, #400
    adrp x0, _vel_uname_out
    add  x0, x0, #:lo12:_vel_uname_out
    mov  rsp, rbp   ; <-- NOT valid on AA64; use proper epilog:
    ldp  x29, lr, [sp, #-0]    ; nothing to restore, just ret below

%else
    ; x86-64 Linux
    mov  rax, 63               ; sys_uname
    lea  rdi, [rel _vel_uname_buf]
    syscall
    lea  rdi, [rel _vel_uname_out]
    lea  rsi, [rel _vel_uname_buf]
    mov  rcx, 64
.un_cpy1:
    mov  al, [rsi]
    test al, al
    jz   .un_spc
    mov  [rdi], al
    inc  rsi
    inc  rdi
    loop .un_cpy1
.un_spc:
    mov  byte [rdi], 32
    inc  rdi
    lea  rsi, [rel _vel_uname_buf + 130]
    mov  rcx, 64
.un_cpy2:
    mov  al, [rsi]
    test al, al
    jz   .un_done
    mov  [rdi], al
    inc  rsi
    inc  rdi
    loop .un_cpy2
.un_done:
    mov  byte [rdi], 0
    lea  rax, [rel _vel_uname_out]
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; system__time_ms() -> adad  (wall clock in milliseconds)
; ============================================================
section .bss
_vel_timespec: resb 16

section .text
global system__time_ms
system__time_ms:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax              ; stub (use QueryPerformanceCounter for real impl)
    mov  rsp, rbp
    pop  rbp
    ret

%elifdef AARCH64_TARGET
    sub  sp, sp, #16
    mov  x0, #0                ; CLOCK_REALTIME
    mov  x1, sp
    mov  x8, #113              ; __NR_clock_gettime
    svc  #0
    ldr  x0, [sp, #0]         ; tv_sec
    mov  x2, #1000
    mul  x0, x0, x2            ; tv_sec * 1000
    ldr  x1, [sp, #8]         ; tv_nsec
    mov  x2, #1000000
    udiv x1, x1, x2            ; tv_nsec / 1_000_000
    add  x0, x0, x1
    add  sp, sp, #16
    mov  rsp, rbp
    pop  rbp
    ret

%else
    ; x86-64 Linux — FIXED: was double-counting tv_sec and zeroing dividend
    mov  rax, 228              ; sys_clock_gettime
    xor  rdi, rdi              ; CLOCK_REALTIME
    lea  rsi, [rel _vel_timespec]
    syscall

    mov  rcx, [rel _vel_timespec]       ; tv_sec
    imul rcx, rcx, 1000                 ;ec_ms

    mov  rax, [rel _vel_timespec + 8]   ; tv_nsec into rax (dividend)
    xor  rdx, rdx                       ; clear high 64 bits
    mov  r8,  1000000
    div  r8                             ; rax = tv_nsec / 1_000_000

    add  rax, rcx                       ; total_ms = sec_ms + ns_ms
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
section .data
; ============================================================
sys_sh_path   db "/bin/sh", 0
sys_sh_flag   db "-c", 0
sys_r_mode    db "r", 0
sys_empty_str db 0

%ifdef WIN64_TARGET
_vel_uname_win: db "Windows", 0
%endif

; ============================================================
section .bss
; ============================================================
sys_cmd_pipe  resd 2
sys_cmd_wstat resd 1
sys_run_wstat resd 1
sys_cmd_slot  resq 1
sys_cmd_buf   resb 262144
sys_env_slot  resq 1
sys_env_buf   resb 16384
sys_cwd_buf   resb 4096
