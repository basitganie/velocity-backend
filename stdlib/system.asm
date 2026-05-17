; ============================================================
; Velocity StdLib - System Module (system.asm) v0.3.2
; Windows + Linux dual-mode
; Functions: system__exit  system__argc  system__argv
;            system__getenv  system__cmd  system__run
;
; system__cmd on Linux uses pure syscalls (pipe/fork/execve/read)
; to avoid glibc malloc dependency (Velocity skips __libc_start_main).
; ============================================================

%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

default rel

extern _VL_argc
extern _VL_argv
extern _VL_envp

%ifdef WIN64_TARGET
extern ExitProcess
extern system
extern _popen
extern _pclose
extern fread
%endif

; ================================================================
section .text
; ================================================================

; ---- system__exit(code: adad) -> khali -------------------------
global system__exit
system__exit:
%ifdef WIN64_TARGET
    sub  rsp, 32
    call ExitProcess
    add  rsp, 32
%else
    mov  rax, 60
    syscall
%endif

; ---- system__argc() -> adad ------------------------------------
global system__argc
system__argc:
    mov  rax, [rel _VL_argc]
    ret

; ---- system__argv(i: adad) -> lafz? ----------------------------
global system__argv
system__argv:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    mov  rax, [rel _VL_argc]
    cmp  rdi, rax
    jae  .oor
    mov  rbx, [rel _VL_argv]
    mov  rax, [rbx + rdi*8]
    ret
.oor:
    xor  rax, rax
    ret

; ---- system__getenv(key: lafz) -> lafz? ------------------------
; Scans envp for "key=value", returns pointer to the value.
global system__getenv
system__getenv:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
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

; ---- system__getenv_safe(key: lafz) -> lafz --------------------
; Returns "" (non-null) when key is missing.
global system__getenv_safe
system__getenv_safe:
%ifdef WIN64_TARGET
    ; rcx = key
    sub  rsp, 32
    call system__getenv
    add  rsp, 32
%else
    ; rdi = key
    call system__getenv
%endif
    test rax, rax
    jnz  .ges_ok
    lea  rax, [rel sys_empty_str]
.ges_ok:
    ret

; ---- system__sh(command: lafz) -> lafz -------------------------
; Alias for system__cmd (capture stdout).
global system__sh
system__sh:
    jmp system__cmd

; ---- system__ok(command: lafz) -> adad -------------------------
; Returns 1 if exit code is 0, else 0.
global system__ok
system__ok:
%ifdef WIN64_TARGET
    ; rcx already holds command
    sub  rsp, 32
    call system__run
    add  rsp, 32
%else
    call system__run
%endif
    test rax, rax
    jnz  .ok_no
    mov  rax, 1
    ret
.ok_no:
    xor  rax, rax
    ret

; ---- system__run(cmd: lafz) -> adad ----------------------------
; Runs cmd via /bin/sh -c. Returns decoded exit status (0=success).
; stdout/stderr pass through to terminal — not captured.
global system__run
system__run:
%ifdef WIN64_TARGET
    ; rcx = cmd; use Win32 system()
    sub  rsp, 32
    call system
    add  rsp, 32
    ret
%else
    ; rdi = cmd; use libc system() — this is safe to call (no heap init needed
    ; for system() itself on Linux, as glibc only uses malloc for popen-style)
    push rbp
    mov  rbp, rsp
    push r12
    push r13
    push r14
    push r15

    ; fork + exec + wait approach to avoid any libc heap use
    ; fork()
    mov  rax, 57
    syscall
    test rax, rax
    js   .run_fail
    jz   .run_child

    ; parent: wait4(pid, &status, 0, 0)
    mov  r12, rax    ; save child pid
    mov  rax, 61
    mov  rdi, r12
    lea  rsi, [rel sys_run_wstat]
    xor  rdx, rdx
    xor  r10, r10
    syscall

    ; decode WEXITSTATUS(status): (status >> 8) & 0xFF
    movzx eax, byte [rel sys_run_wstat + 1]
    movsx rax, eax
    jmp  .run_ret

.run_child:
    ; execve("/bin/sh", ["/bin/sh","-c",cmd,NULL], envp)
    sub  rsp, 32
    lea  rax, [rel sys_sh_path]
    mov  [rsp +  0], rax
    lea  rax, [rel sys_sh_flag]
    mov  [rsp +  8], rax
    ; rdi still = cmd (saved before fork)
    mov  [rsp + 16], rdi
    mov  qword [rsp + 24], 0

    mov  rax, 59
    lea  rdi, [rel sys_sh_path]
    mov  rsi, rsp
    mov  rdx, [rel _VL_envp]
    syscall

    ; execve failed
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

; ---- system__cmd(cmd: lafz) -> lafz ----------------------------
; Runs cmd via /bin/sh -c and captures ALL stdout.
; Returns pointer to a static 65535-byte buffer with the output.
; Trailing newlines are stripped. Empty string returned on error.
;
; Linux: pure syscalls (pipe/fork/dup2/execve/read/wait4)
;        — no glibc heap dependency.
; Windows: _popen/_pclose/fread (MSVCRT, CRT already init'd on Windows).
global system__cmd
system__cmd:
    push rbp
    mov  rbp, rsp
    push rbx        ; write pointer into sys_cmd_buf
    push r12        ; cmd / read-fd / FILE* (Win)
    push r13        ; child pid (Linux) / FILE* (Win)
    push r14        ; spare
    push r15        ; base of sys_cmd_buf for strip comparison
    sub  rsp, 8     ; 16-byte align

%ifdef WIN64_TARGET
    ; Windows: _popen(cmd, "r")
    ; rcx = cmd already
    lea  rdx, [rel sys_r_mode]
    sub  rsp, 32
    call _popen
    add  rsp, 32
    test rax, rax
    jz   .scmd_fail
    mov  r13, rax               ; FILE*

    lea  rbx, [rel sys_cmd_buf]
.win_read_loop:
    lea  rax, [rel sys_cmd_buf + 65534]
    cmp  rbx, rax
    jae  .win_close
    mov  r14, rax
    sub  r14, rbx               ; remaining bytes
    mov  rcx, rbx
    mov  rdx, 1
    mov  r8,  r14
    mov  r9,  r13
    sub  rsp, 32
    call fread
    add  rsp, 32
    test rax, rax
    jz   .win_close
    add  rbx, rax
    jmp  .win_read_loop
.win_close:
    mov  byte [rbx], 0

    ; pclose
    mov  rcx, r13
    sub  rsp, 32
    call _pclose
    add  rsp, 32
    jmp  .scmd_strip

%else
    ; Linux: pure syscalls
    mov  r12, rdi   ; save cmd

    ; pipe(pipefd) — sys_cmd_pipe is int[2] = 8 bytes
    mov  rax, 22    ; sys_pipe
    lea  rdi, [rel sys_cmd_pipe]
    syscall
    test rax, rax
    js   .scmd_fail

    ; fork()
    mov  rax, 57    ; sys_fork
    syscall
    test rax, rax
    js   .scmd_fail
    jz   .scmd_child

    ; ---- PARENT ----
    mov  r13, rax   ; child pid

    ; close write end: pipefd[1]
    mov  rax, 3     ; sys_close
    movsx rdi, dword [rel sys_cmd_pipe + 4]
    syscall

    ; read end: pipefd[0]
    movsx r14, dword [rel sys_cmd_pipe]

    lea  rbx, [rel sys_cmd_buf]

.parent_read:
    lea  rax, [rel sys_cmd_buf + 65534]
    cmp  rbx, rax
    jae  .parent_read_done
    mov  rdx, rax
    sub  rdx, rbx   ; remaining bytes

    mov  rax, 0     ; sys_read
    mov  rdi, r14   ; read fd
    mov  rsi, rbx   ; buffer
    syscall

    test rax, rax
    jle  .parent_read_done   ; EOF or error
    add  rbx, rax
    jmp  .parent_read

.parent_read_done:
    mov  byte [rbx], 0

    ; close read end
    mov  rax, 3
    mov  rdi, r14
    syscall

    ; wait4(pid, &wstat, 0, 0)
    mov  rax, 61
    mov  rdi, r13
    lea  rsi, [rel sys_cmd_wstat]
    xor  rdx, rdx
    xor  r10, r10
    syscall

    jmp  .scmd_strip

.scmd_child:
    ; ---- CHILD ----
    ; close read end: pipefd[0]
    mov  rax, 3
    movsx rdi, dword [rel sys_cmd_pipe]
    syscall

    ; dup2(pipefd[1], STDOUT_FILENO=1): redirect stdout → pipe write end
    mov  rax, 33    ; sys_dup2
    movsx rdi, dword [rel sys_cmd_pipe + 4]
    mov  rsi, 1
    syscall

    ; close write end (now duplicated to fd 1)
    mov  rax, 3
    movsx rdi, dword [rel sys_cmd_pipe + 4]
    syscall

    ; execve("/bin/sh", ["/bin/sh", "-c", cmd, NULL], envp)
    sub  rsp, 32
    lea  rax, [rel sys_sh_path]
    mov  [rsp +  0], rax
    lea  rax, [rel sys_sh_flag]
    mov  [rsp +  8], rax
    mov  [rsp + 16], r12    ; cmd
    mov  qword [rsp + 24], 0

    mov  rax, 59    ; sys_execve
    lea  rdi, [rel sys_sh_path]
    mov  rsi, rsp
    mov  rdx, [rel _VL_envp]
    syscall

    ; execve failed → exit child with code 127
    mov  rax, 60
    mov  rdi, 127
    syscall

%endif

.scmd_strip:
    ; Strip trailing \n and \r from rbx downward
    lea  r15, [rel sys_cmd_buf]
.strip_loop:
    cmp  rbx, r15
    jbe  .scmd_stripped     ; at or before buffer start
    dec  rbx
    movzx eax, byte [rbx]
    cmp  eax, 10            ; '\n'
    je   .strip_loop
    cmp  eax, 13            ; '\r'
    je   .strip_loop
    inc  rbx                ; restore past last non-newline char

.scmd_stripped:
    mov  byte [rbx], 0
    lea  rax, [rel sys_cmd_buf]
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

; ================================================================
; NEW FILESYSTEM FUNCTIONS
; ================================================================

; -- system__getcwd() → lafz (ptr to static buf, or NULL on error)
global system__getcwd
system__getcwd:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax           ; TODO: Windows getcwd
%else
    mov  rax, 79            ; sys_getcwd
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
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__chdir(path: lafz) → adad (0=ok, -1=error)
global system__chdir
system__chdir:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax
%else
    mov  rax, 80            ; sys_chdir (rdi=path already set by caller)
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__mkdir(path: lafz) → adad (0=ok, -1=error)
global system__mkdir
system__mkdir:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax
%else
    mov  rsi, 0755o         ; mode = rwxr-xr-x
    mov  rax, 83            ; sys_mkdir
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__exists(path: lafz) → adad (1=exists, 0=not found)
global system__exists
system__exists:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax
%else
    mov  rax, 21            ; sys_access
    xor  rsi, rsi           ; F_OK = 0
    syscall
    test rax, rax
    setz al
    movzx rax, al
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__rm(path: lafz) → adad (0=ok, -1=error)
;    Tries unlink first; if EISDIR (-21) falls back to rmdir.
global system__rm
system__rm:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call DeleteFileA
    add  rsp, 40
    test rax, rax
    jnz  .rm_ok_win
    mov  rax, -1
    jmp  .rm_ret_win
.rm_ok_win:
    xor  rax, rax
.rm_ret_win:
%else
    push rbx
    mov  rbx, rdi           ; save path
    mov  rax, 87            ; sys_unlink
    syscall
    test rax, rax
    jz   .rm_ok
    cmp  rax, -21           ; EISDIR?
    jne  .rm_fail
    mov  rdi, rbx           ; restore path
    mov  rax, 84            ; sys_rmdir
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
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ================================================================
section .data
; ================================================================
sys_sh_path   db "/bin/sh", 0
sys_sh_flag   db "-c", 0
sys_r_mode    db "r", 0
sys_empty_str db 0

; ================================================================
section .bss
; ================================================================
sys_cmd_pipe  resd 2        ; int[2] pipefd from sys_pipe
sys_cmd_wstat resd 1        ; waitpid status
sys_run_wstat resd 1        ; waitpid status for system__run
sys_cmd_buf   resb 65536    ; captured output buffer
sys_cwd_buf   resb 4096     ; getcwd buffer

; ================================================================
section .text
; ================================================================

; ================================================================
; OS-level syscall wrappers  (Linux only; stubs on Windows)
; ================================================================

; -- system__mmap(addr, len, prot, flags) -> adad (ptr or -1)
global system__mmap
system__mmap:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%else
    ; args: rdi=addr, rsi=len, rdx=prot, rcx=flags
    mov  r9,  -1        ; fd = -1
    mov  r8,  rcx       ; flags
    mov  rcx, 0         ; offset = 0
    mov  rax, 9         ; sys_mmap
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__munmap(addr, len) -> adad (0=ok)
global system__munmap
system__munmap:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax
%else
    mov  rax, 11        ; sys_munmap
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__mprotect(addr, len, prot) -> adad
global system__mprotect
system__mprotect:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax
%else
    mov  rax, 10        ; sys_mprotect
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__sleep(secs: adad) -> adad
global system__sleep
system__sleep:
    push rbp
    mov  rbp, rsp
    push rbx
%ifdef WIN64_TARGET
    ; Sleep(ms)
    imul rcx, rdi, 1000
    call Sleep
    xor  rax, rax
%else
    ; nanosleep with stack-allocated timespec
    sub  rsp, 32
    mov  [rsp],    rdi  ; tv_sec
    mov  qword [rsp+8], 0  ; tv_nsec
    mov  rdi, rsp
    xor  rsi, rsi
    mov  rax, 35        ; sys_nanosleep
    syscall
    add  rsp, 32
%endif
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__usleep(usecs: adad) -> adad
global system__usleep
system__usleep:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; convert µs → ms (truncate)
    mov  rax, rdi
    xor  rdx, rdx
    mov  rcx, 1000
    div  rcx
    mov  rcx, rax
    call Sleep
    xor  rax, rax
%else
    sub  rsp, 32
    xor  rax, rax
    mov  [rsp], rax         ; tv_sec = 0
    ; tv_nsec = usecs * 1000
    imul rdi, rdi, 1000
    mov  [rsp+8], rdi
    mov  rdi, rsp
    xor  rsi, rsi
    mov  rax, 35            ; sys_nanosleep
    syscall
    add  rsp, 32
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__getpid() -> adad
global system__getpid
system__getpid:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    call GetCurrentProcessId
%else
    mov  rax, 39            ; sys_getpid
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__getppid() -> adad
global system__getppid
system__getppid:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1            ; unavailable on Windows
%else
    mov  rax, 110           ; sys_getppid
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__kill(pid: adad, sig: adad) -> adad
global system__kill
system__kill:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%else
    mov  rax, 62            ; sys_kill
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__open(path: lafz, flags: adad, mode: adad) -> adad (fd or -1)
global system__open
system__open:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%else
    mov  rax, 2             ; sys_open
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__close(fd: adad) -> adad
global system__close
system__close:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    call CloseHandle
    xor  rax, rax
%else
    mov  rax, 3             ; sys_close
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__read_fd(fd: adad, buf: adad, len: adad) -> adad (bytes read)
global system__read_fd
system__read_fd:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%else
    mov  rax, 0             ; sys_read
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__write_fd(fd: adad, buf: adad, len: adad) -> adad (bytes written)
global system__write_fd
system__write_fd:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%else
    mov  rax, 1             ; sys_write
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__seek(fd: adad, offset: adad, whence: adad) -> adad
global system__seek
system__seek:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%else
    mov  rax, 8             ; sys_lseek
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- system__stat_size(path: lafz) -> adad (file size or -1)
global system__stat_size
system__stat_size:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%else
    push rbx
    sub  rsp, 144 + 8       ; struct stat is 144 bytes; +8 for alignment
    mov  rbx, rsp
    mov  rax, 4             ; sys_stat
    mov  rsi, rbx
    syscall
    test rax, rax
    jnz  .stat_fail
    mov  rax, [rbx + 48]   ; st_size offset in Linux x86-64 stat
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

; -- system__ioctl(fd: adad, req: adad, arg: adad) -> adad
global system__ioctl
system__ioctl:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, -1
%else
    mov  rax, 16            ; sys_ioctl
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ---------------------------------------------------------------
; system__uname() -> lafz
; Returns a string like "Linux 6.x.y-aarch64" (sysname + release)
; Uses sys_uname (63) on Linux.
; ---------------------------------------------------------------
section .bss
_vel_uname_buf:  resb 400      ; struct utsname (6 * 65 bytes)
_vel_uname_out:  resb 200      ; "sysname release\0"

section .text
global system__uname
system__uname:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; Windows: return stub
    lea  rax, [rel _vel_uname_win]
    mov  rsp, rbp
    pop  rbp
    ret
%else
    ; sys_uname(63), arg = &_vel_uname_buf
    mov  rax, 63
    lea  rdi, [rel _vel_uname_buf]
    syscall
    ; copy sysname (offset 0, max 64 bytes) to _vel_uname_out
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
    mov  byte [rdi], 32    ; space
    inc  rdi
    ; copy release (offset 65*2 = 130)
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

; ---------------------------------------------------------------
; system__time_ms() -> adad
; Returns wall-clock time in milliseconds (CLOCK_REALTIME).
; Uses sys_clock_gettime (228) on Linux.
; ---------------------------------------------------------------
section .bss
_vel_timespec: resb 16   ; {tv_sec: 8, tv_nsec: 8}

section .text
global system__time_ms
system__time_ms:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    xor  rax, rax
    mov  rsp, rbp
    pop  rbp
    ret
%else
    mov  rax, 228          ; sys_clock_gettime
    xor  rdi, rdi          ; CLOCK_REALTIME = 0
    lea  rsi, [rel _vel_timespec]
    syscall
    mov  rax, [rel _vel_timespec]      ; tv_sec
    imul rax, rax, 1000                ; * 1000 -> ms
    mov  rcx, [rel _vel_timespec + 8]  ; tv_nsec
    mov  rdx, 1000000
    xor  rdx, rdx
    mov  rdx, rcx
    mov  rcx, 1000000
    xor  rdx, rdx
    div  rcx                           ; rdx:rax / 1000000
    ; rax = tv_nsec / 1000000 (ms from nanoseconds)
    mov  rcx, [rel _vel_timespec]
    imul rcx, rcx, 1000
    add  rax, rcx
%endif
    mov  rsp, rbp
    pop  rbp
    ret

%ifdef WIN64_TARGET
section .data
_vel_uname_win: db "Windows 0.0", 0
%endif
