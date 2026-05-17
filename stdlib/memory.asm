; ================================================================
; Velocity stdlib — memory module
; Low-level memory primitives for self-hosting + systems programming
; ================================================================

%ifdef WIN64_TARGET
  %define ARG1 rcx
  %define ARG2 rdx
  %define ARG3 r8
  %define ARG4 r9
%else
  %define ARG1 rdi
  %define ARG2 rsi
  %define ARG3 rdx
  %define ARG4 rcx
%endif

section .text

; ----------------------------------------------------------------
; Public Velocity module symbol aliases
;
; The Velocity compiler emits calls like `memory__malloc` for `memory.malloc(...)`.
; This file historically exported `_vel_mem__malloc` style names.
; Keep both for compatibility.
; ----------------------------------------------------------------

global memory__malloc
memory__malloc: jmp _vel_mem__malloc
global memory__calloc
memory__calloc: jmp _vel_mem__calloc
global memory__realloc
memory__realloc: jmp _vel_mem__realloc
global memory__free
memory__free: jmp _vel_mem__free
global memory__memcpy
memory__memcpy: jmp _vel_mem__memcpy
global memory__memmove
memory__memmove: jmp _vel_mem__memmove
global memory__memset
memory__memset: jmp _vel_mem__memset
global memory__memcmp
memory__memcmp: jmp _vel_mem__memcmp
global memory__strlen
memory__strlen: jmp _vel_mem__strlen
global memory__strcmp
memory__strcmp: jmp _vel_mem__strcmp
global memory__strcpy
memory__strcpy: jmp _vel_mem__strcpy
global memory__strncpy
memory__strncpy: jmp _vel_mem__strncpy
global memory__strcat
memory__strcat: jmp _vel_mem__strcat
global memory__strncat
memory__strncat: jmp _vel_mem__strncat
global memory__strdup
memory__strdup: jmp _vel_mem__strdup
global memory__load64
memory__load64: jmp _vel_mem__load64
global memory__store64
memory__store64: jmp _vel_mem__store64
global memory__load8
memory__load8: jmp _vel_mem__load8
global memory__store8
memory__store8: jmp _vel_mem__store8

global memory__ptr_add
memory__ptr_add:
    mov  rax, ARG1
    add  rax, ARG2
    ret

global memory__ptr_diff
memory__ptr_diff:
    mov  rax, ARG1
    sub  rax, ARG2
    ret

global memory__as_ptr
memory__as_ptr:
    mov  rax, ARG1
    ret

; -- _vel_mem__malloc(size: adad) -> *adad
global _vel_mem__malloc
_vel_mem__malloc:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call malloc
    add  rsp, 40
%else
    call malloc
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__calloc(n: adad, size: adad) -> *adad
global _vel_mem__calloc
_vel_mem__calloc:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call calloc
    add  rsp, 40
%else
    call calloc
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__realloc(ptr: *adad, size: adad) -> *adad
global _vel_mem__realloc
_vel_mem__realloc:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call realloc
    add  rsp, 40
%else
    call realloc
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__free(ptr: *adad) -> adad
global _vel_mem__free
_vel_mem__free:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call free
    add  rsp, 40
%else
    call free
%endif
    xor  rax, rax
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__memcpy(dst, src: *adad, n: adad) -> *adad
global _vel_mem__memcpy
_vel_mem__memcpy:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call memcpy
    add  rsp, 40
%else
    push rdi           ; save dst (return value)
    call memcpy
    pop  rax
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__memmove(dst, src: *adad, n: adad) -> *adad
global _vel_mem__memmove
_vel_mem__memmove:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call memmove
    add  rsp, 40
%else
    push rdi
    call memmove
    pop  rax
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__memset(ptr: *adad, val: adad, n: adad) -> *adad
global _vel_mem__memset
_vel_mem__memset:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call memset
    add  rsp, 40
%else
    push rdi
    ; rsi=val(int), rdx=n  → C memset(ptr, val, n) same regs
    call memset
    pop  rax
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__memcmp(a, b: *adad, n: adad) -> adad
global _vel_mem__memcmp
_vel_mem__memcmp:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call memcmp
    add  rsp, 40
%else
    call memcmp
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__strlen(ptr: *adad) -> adad
global _vel_mem__strlen
_vel_mem__strlen:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call strlen
    add  rsp, 40
%else
    call strlen
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__strcmp(a, b: *adad) -> adad
global _vel_mem__strcmp
_vel_mem__strcmp:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call strcmp
    add  rsp, 40
%else
    call strcmp
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__strcpy(dst, src: *adad) -> *adad
global _vel_mem__strcpy
_vel_mem__strcpy:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call strcpy
    add  rsp, 40
%else
    push rdi
    call strcpy
    pop  rax
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__strncpy(dst, src: *adad, n: adad) -> *adad
global _vel_mem__strncpy
_vel_mem__strncpy:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call strncpy
    add  rsp, 40
%else
    push rdi
    call strncpy
    pop  rax
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__strcat(dst, src: *adad) -> *adad
global _vel_mem__strcat
_vel_mem__strcat:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call strcat
    add  rsp, 40
%else
    push rdi
    call strcat
    pop  rax
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__strncat(dst, src: *adad, n: adad) -> *adad
global _vel_mem__strncat
_vel_mem__strncat:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call strncat
    add  rsp, 40
%else
    push rdi
    call strncat
    pop  rax
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__strdup(src: *adad) -> *adad
global _vel_mem__strdup
_vel_mem__strdup:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 40
    call _strdup
    add  rsp, 40
%else
    call strdup
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- _vel_mem__load64(ptr: *adad) -> adad   — read 64-bit word at ptr
global _vel_mem__load64
_vel_mem__load64:
    mov  rax, [ARG1]
    ret

; -- _vel_mem__store64(ptr: *adad, val: adad) -> adad — write 64-bit word
global _vel_mem__store64
_vel_mem__store64:
    mov  [ARG1], ARG2
    xor  rax, rax
    ret

; -- _vel_mem__load8(ptr: *adad) -> adad   — read byte at ptr (zero-extended)
global _vel_mem__load8
_vel_mem__load8:
    movzx rax, byte [ARG1]
    ret

; -- _vel_mem__store8(ptr: *adad, val: adad) -> adad — write byte
global _vel_mem__store8
_vel_mem__store8:
    %ifdef WIN64_TARGET
    mov  byte [rcx], dl
%else
    mov  byte [rdi], sil
%endif
    xor  rax, rax
    ret

section .data
    ; externals (libc)
    extern malloc
    extern calloc
    extern realloc
    extern free
    extern memcpy
    extern memmove
    extern memset
    extern memcmp
    extern strlen
    extern strcmp
    extern strcpy
    extern strncpy
    extern strcat
    extern strncat
    extern strdup
