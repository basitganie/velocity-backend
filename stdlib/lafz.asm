; ============================================================
; Velocity StdLib - Lafz (String) Module (lafz.asm) v0.3.0
; Pure x86-64 -- no syscalls, fully portable Win64+Linux
;
; Uses a simple bump allocator (no free).
; Functions:
;   lafz__len         lafz__eq          lafz__concat      lafz__slice
;   lafz__from_adad   lafz__from_ashari
;   lafz__to_adad     lafz__to_ashari
;   lafz__find        lafz__contains    lafz__starts_with  lafz__ends_with
;   lafz__trim        lafz__upper       lafz__lower        lafz__replace
; ============================================================

%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

%define LAFZ_HEAP_SIZE 262144

section .bss
    lafz_heap resb LAFZ_HEAP_SIZE
    lafz_hp   resq 1
    lf_num_buf resb 64

section .data
    lf_minus  db '-'
    lf_dot    db '.'
    lf_millf  dq 1000000.0
    lf_ten    dq 10.0

section .text

; -- heap init ----------------------------------------------------
lafz_init:
    mov  rax, [rel lafz_hp]
    test rax, rax
    jne  .ok
    lea  rax, [rel lafz_heap]
    mov  [rel lafz_hp], rax
.ok:
    ret

; lafz_alloc(n) -> ptr   (rdi = bytes needed, excludes null terminator)
lafz_alloc:
    call lafz_init
    mov  rax, [rel lafz_hp]
    inc  rdi                  ; +1 for null terminator
    add  [rel lafz_hp], rdi
    ; safety: don't overflow heap
    lea  rcx, [rel lafz_heap + LAFZ_HEAP_SIZE]
    mov  rdx, [rel lafz_hp]
    cmp  rdx, rcx
    jbe  .ok
    ; reset pointer on overflow (best-effort)
    lea  rdx, [rel lafz_heap]
    mov  [rel lafz_hp], rdx
.ok:
    ret

; internal: length of string at rdi -> rax (clobbers rcx)
lafz_strlen:
    xor  rax, rax
.loop:
    cmp  byte [rdi + rax], 0
    je   .done
    inc  rax
    jmp  .loop
.done:
    ret

; -- lafz__len(s) -> adad ------------------------------------------
global lafz__len
lafz__len:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    test rdi, rdi
    jz   .zero
    call lafz_strlen
    ret
.zero:
    xor  rax, rax
    ret

; -- lafz__eq(a, b) -> adad ----------------------------------------
global lafz__eq
lafz__eq:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    push rbx
.cmp:
    mov  al, [rdi]
    mov  bl, [rsi]
    cmp  al, bl
    jne  .neq
    test al, al
    jz   .eq
    inc  rdi
    inc  rsi
    jmp  .cmp
.eq:
    mov  rax, 1
    pop  rbx
    ret
.neq:
    xor  rax, rax
    pop  rbx
    ret

; -- lafz__concat(a, b) -> lafz ------------------------------------
global lafz__concat
lafz__concat:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    push rbx
    push r12
    push r13
    mov  r12, rdi
    mov  r13, rsi

    ; len(a)
    call lafz_strlen
    mov  rbx, rax

    ; len(b)
    mov  rdi, r13
    call lafz_strlen
    add  rbx, rax         ; total length

    ; alloc rbx bytes
    mov  rdi, rbx
    call lafz_alloc
    push rax              ; dest ptr

    ; copy a
    mov  rdi, rax
    mov  rsi, r12
.cpa:
    mov  al, [rsi]
    test al, al
    jz   .cpa_done
    mov  [rdi], al
    inc  rdi
    inc  rsi
    jmp  .cpa
.cpa_done:
    ; copy b
    mov  rsi, r13
.cpb:
    mov  al, [rsi]
    mov  [rdi], al
    test al, al
    jz   .cpb_done
    inc  rdi
    inc  rsi
    jmp  .cpb
.cpb_done:
    pop  rax
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__slice(s, start, len) -> lafz ----------------------------
global lafz__slice
lafz__slice:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
    mov  rdx, r8
%endif
    push rbx
    push r12
    push r13
    mov  r12, rdi           ; s
    mov  r13, rsi           ; start
    mov  rbx, rdx           ; len

    ; alloc len bytes
    mov  rdi, rbx
    call lafz_alloc
    push rax

    ; copy
    mov  rdi, rax
    mov  rsi, r12
    add  rsi, r13           ; s + start
    mov  rcx, rbx
.sl_loop:
    test rcx, rcx
    jz   .sl_done
    mov  al, [rsi]
    test al, al
    jz   .sl_done
    mov  [rdi], al
    inc  rdi
    inc  rsi
    dec  rcx
    jmp  .sl_loop
.sl_done:
    mov  byte [rdi], 0
    pop  rax
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__from_adad(n: adad) -> lafz ------------------------------
global lafz__from_adad
lafz__from_adad:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    push rbx
    push r12
    mov  r12, rdi           ; save n

    lea  rbx, [rel lf_num_buf]
    mov  byte [rbx+31], 0
    mov  rdi, 30
    mov  rsi, r12
    test rsi, rsi
    jns  .pos
    neg  rsi
.pos:
    test rsi, rsi
    jnz  .conv
    mov  byte [rbx+rdi], '0'
    dec  rdi
    jmp  .conv_done
.conv:
    xor  rdx, rdx
    mov  rax, rsi
    mov  rcx, 10
    div  rcx
    add  dl, '0'
    mov  [rbx + rdi], dl
    dec  rdi
    mov  rsi, rax
    test rsi, rsi
    jnz  .conv
.conv_done:
    test r12, r12
    jns  .no_minus
    mov  byte [rbx + rdi], '-'
    dec  rdi
.no_minus:
    inc  rdi
    ; rdi = start index in lf_num_buf
    lea  rsi, [rbx + rdi]
    mov  rcx, 31
    sub  rcx, rdi
    push rsi
    push rcx
    mov  rdi, rcx
    call lafz_alloc
    pop  rcx
    pop  rsi
    push rax
    mov  rdi, rax
    rep  movsb
    mov  byte [rdi], 0
    pop  rax
    pop  r12
    pop  rbx
    ret

; -- lafz__from_ashari(f: ashari) -> lafz --------------------------
global lafz__from_ashari
lafz__from_ashari:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12

    movq rbx, xmm0          ; save raw bits

    ; integer part
    cvttsd2si r12, xmm0
    mov  rdi, r12
    call lafz__from_adad
    push rax                 ; int_str

    ; fractional: |frac| * 1e6
    movq xmm0, rbx
    cvttsd2si rax, xmm0
    cvtsi2sd  xmm1, rax
    subsd     xmm0, xmm1
    movsd     xmm1, [rel lf_millf]
    mulsd     xmm0, xmm1
    cvttsd2si rdi, xmm0
    test rdi, rdi
    jns  .fpos
    neg  rdi
.fpos:
    call lafz__from_adad    ; dec_str in rax
    push rax

    ; build dot
    mov  rdi, 1
    call lafz_alloc
    mov  byte [rax],   '.'
    mov  byte [rax+1], 0

    ; concat(int_str, ".")
    pop  r12                 ; dec_str
    pop  rdi                 ; int_str
    mov  rsi, rax            ; dot_str
    call lafz__concat
    ; concat(int_dot, dec_str)
    mov  rdi, rax
    mov  rsi, r12
    call lafz__concat

    pop  r12
    pop  rbx
    pop  rbp
    ret

; -- lafz__to_adad(s: lafz) -> adad --------------------------------
global lafz__to_adad
lafz__to_adad:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    push rbx
    xor  rax, rax
    xor  rbx, rbx
    movzx rcx, byte [rdi]
    cmp  cl, '-'
    jne  .parse
    mov  rbx, 1
    inc  rdi
.parse:
    movzx rcx, byte [rdi]
    test cl, cl
    jz   .done
    cmp  cl, '.'
    je   .done
    sub  cl, '0'
    cmp  cl, 9
    ja   .done
    imul rax, 10
    movzx rcx, cl
    add  rax, rcx
    inc  rdi
    jmp  .parse
.done:
    test rbx, rbx
    jz   .ret
    neg  rax
.ret:
    pop  rbx
    ret

; -- lafz__to_ashari(s: lafz) -> ashari (xmm0) --------------------
global lafz__to_ashari
lafz__to_ashari:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    push rbx
    push r12
    mov  r12, rdi

    call lafz__to_adad
    cvtsi2sd xmm0, rax

    ; find '.'
    mov  rdi, r12
.find_dot:
    movzx rcx, byte [rdi]
    test cl, cl
    jz   .no_frac
    cmp  cl, '.'
    je   .has_frac
    inc  rdi
    jmp  .find_dot
.no_frac:
    pop  r12
    pop  rbx
    ret
.has_frac:
    inc  rdi
    xorpd xmm1, xmm1
    movsd xmm2, [rel lf_ten]
    movsd xmm3, [rel lf_ten]
.frac_loop:
    movzx rcx, byte [rdi]
    test  cl, cl
    jz    .frac_done
    sub   cl, '0'
    cvtsi2sd xmm4, rcx
    divsd    xmm4, xmm3
    addsd    xmm1, xmm4
    mulsd    xmm3, xmm2
    inc  rdi
    jmp  .frac_loop
.frac_done:
    movzx rcx, byte [r12]
    cmp  cl, '-'
    jne  .add_frac
    subsd xmm0, xmm1
    jmp  .done_frac
.add_frac:
    addsd xmm0, xmm1
.done_frac:
    pop  r12
    pop  rbx
    ret

; ================================================================
; NEW IN v0.3.0
; ================================================================

; -- lafz__find(haystack, needle) -> adad  (-1 if not found) ------
; Linux:   rdi=haystack, rsi=needle
; Windows: rcx=haystack, rdx=needle
global lafz__find
lafz__find:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz   .not_found
    test rsi, rsi
    jz   .not_found

    ; Length of needle
    mov  r14, rsi           ; needle
    push rdi                ; save haystack
    mov  rdi, rsi
    call lafz_strlen
    pop  rdi
    mov  r13, rax           ; needle_len
    test r13, r13
    jz   .empty_needle

    ; Length of haystack
    mov  r12, rdi           ; haystack
    call lafz_strlen
    mov  rbx, rax           ; hay_len

    ; Check if needle can fit
    cmp  r13, rbx
    ja   .not_found

    ; Search
    xor  rax, rax           ; position
.search_loop:
    ; remaining = hay_len - pos
    mov  rcx, rbx
    sub  rcx, rax
    cmp  rcx, r13
    jb   .not_found

    ; Compare needle at haystack[pos]
    lea  rdi, [r12 + rax]   ; hay + pos
    mov  rsi, r14            ; needle
    mov  rcx, r13            ; needle_len
    push rax
    repe cmpsb
    pop  rax
    je   .found             ; all bytes matched
    inc  rax
    jmp  .search_loop

.found:
    ; rax already = position
    jmp  .done_find
.empty_needle:
    xor  rax, rax
    jmp  .done_find
.not_found:
    mov  rax, -1
.done_find:
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__contains(haystack, needle) -> bool ----------------------
global lafz__contains
lafz__contains:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    call lafz__find
    cmp  rax, -1
    jne  .yes
    xor  rax, rax
    ret
.yes:
    mov  rax, 1
    ret

; -- lafz__starts_with(s, prefix) -> bool --------------------------
global lafz__starts_with
lafz__starts_with:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    push rbx
    push r12
    push r13
    mov  r12, rdi           ; s
    mov  r13, rsi           ; prefix

    test r13, r13
    jz   .sw_true           ; empty prefix always matches

    ; len(prefix)
    mov  rdi, r13
    call lafz_strlen
    mov  rbx, rax           ; prefix_len

    ; len(s)
    mov  rdi, r12
    call lafz_strlen
    cmp  rbx, rax
    ja   .sw_false          ; prefix longer than s

    ; compare first prefix_len bytes
    mov  rdi, r12
    mov  rsi, r13
    mov  rcx, rbx
    repe cmpsb
    je   .sw_true
.sw_false:
    xor  rax, rax
    jmp  .sw_done
.sw_true:
    mov  rax, 1
.sw_done:
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__ends_with(s, suffix) -> bool ----------------------------
global lafz__ends_with
lafz__ends_with:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    push rbx
    push r12
    push r13
    mov  r12, rdi           ; s
    mov  r13, rsi           ; suffix

    test r13, r13
    jz   .ew_true

    mov  rdi, r13
    call lafz_strlen
    mov  rbx, rax           ; suffix_len

    mov  rdi, r12
    call lafz_strlen        ; s_len in rax
    cmp  rbx, rax
    ja   .ew_false

    ; offset = s_len - suffix_len
    sub  rax, rbx
    lea  rdi, [r12 + rax]   ; s + offset
    mov  rsi, r13
    mov  rcx, rbx
    repe cmpsb
    je   .ew_true
.ew_false:
    xor  rax, rax
    jmp  .ew_done
.ew_true:
    mov  rax, 1
.ew_done:
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__trim(s) -> lafz  (remove leading+trailing whitespace) ---
global lafz__trim
lafz__trim:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    push rbx
    push r12
    push r13

    test rdi, rdi
    jz   .trim_null

    mov  r12, rdi           ; s

    ; skip leading whitespace
.skip_lead:
    movzx rax, byte [r12]
    test  al, al
    jz    .all_ws
    cmp   al, ' '
    je    .lead_adv
    cmp   al, 9             ; \t
    je    .lead_adv
    cmp   al, 10            ; \n
    je    .lead_adv
    cmp   al, 13            ; \r
    je    .lead_adv
    jmp   .find_end
.lead_adv:
    inc   r12
    jmp   .skip_lead

.find_end:
    ; find end of string
    mov   rdi, r12
    call  lafz_strlen
    ; rax = length from r12 onwards
    ; find trailing whitespace
    lea   r13, [r12 + rax - 1]  ; last char
.skip_trail:
    cmp   r13, r12
    jb    .trim_done
    movzx rbx, byte [r13]
    cmp   bl, ' '
    je    .trail_adv
    cmp   bl, 9
    je    .trail_adv
    cmp   bl, 10
    je    .trail_adv
    cmp   bl, 13
    je    .trail_adv
    jmp   .trim_done
.trail_adv:
    dec   r13
    jmp   .skip_trail

.trim_done:
    ; r12 = start, r13 = last valid char
    ; length = r13 - r12 + 1
    mov   rax, r13
    sub   rax, r12
    inc   rax
    test  rax, rax
    jle   .all_ws
    ; allocate and copy
    mov   rdi, rax
    push  rax
    push  r12
    call  lafz_alloc
    pop   r12
    pop   rcx
    push  rax
    mov   rdi, rax
    mov   rsi, r12
    rep   movsb
    mov   byte [rdi], 0
    pop   rax
    jmp   .trim_ret

.all_ws:
    ; return empty string
    mov  rdi, 0
    call lafz_alloc
    mov  byte [rax], 0
    jmp  .trim_ret

.trim_null:
    xor  rax, rax
.trim_ret:
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__upper(s) -> lafz  (ASCII uppercase) ---------------------
global lafz__upper
lafz__upper:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    push rbx
    push r12

    test rdi, rdi
    jz   .up_null

    mov  r12, rdi
    call lafz_strlen
    mov  rbx, rax           ; length

    ; alloc
    mov  rdi, rbx
    call lafz_alloc
    push rax

    ; copy and uppercase
    mov  rdi, rax
    mov  rsi, r12
    mov  rcx, rbx
.up_loop:
    test rcx, rcx
    jz   .up_done
    movzx rax, byte [rsi]
    cmp  al, 'a'
    jb   .up_copy
    cmp  al, 'z'
    ja   .up_copy
    sub  al, 32
.up_copy:
    mov  [rdi], al
    inc  rdi
    inc  rsi
    dec  rcx
    jmp  .up_loop
.up_done:
    mov  byte [rdi], 0
    pop  rax
    jmp  .up_ret
.up_null:
    xor  rax, rax
.up_ret:
    pop  r12
    pop  rbx
    ret

; -- lafz__lower(s) -> lafz  (ASCII lowercase) ---------------------
global lafz__lower
lafz__lower:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    push rbx
    push r12

    test rdi, rdi
    jz   .lo_null

    mov  r12, rdi
    call lafz_strlen
    mov  rbx, rax

    mov  rdi, rbx
    call lafz_alloc
    push rax

    mov  rdi, rax
    mov  rsi, r12
    mov  rcx, rbx
.lo_loop:
    test rcx, rcx
    jz   .lo_done
    movzx rax, byte [rsi]
    cmp  al, 'A'
    jb   .lo_copy
    cmp  al, 'Z'
    ja   .lo_copy
    add  al, 32
.lo_copy:
    mov  [rdi], al
    inc  rdi
    inc  rsi
    dec  rcx
    jmp  .lo_loop
.lo_done:
    mov  byte [rdi], 0
    pop  rax
    jmp  .lo_ret
.lo_null:
    xor  rax, rax
.lo_ret:
    pop  r12
    pop  rbx
    ret

; -- lafz__replace(s, old_char, new_char) -> lafz ------------------
; Replace all occurrences of old_char (u8) with new_char (u8)
; Linux:   rdi=s, rsi=old_char, rdx=new_char
; Windows: rcx=s, rdx=old_char, r8=new_char
global lafz__replace
lafz__replace:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
    mov  rdx, r8
%endif
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz   .repl_null

    mov  r12, rdi           ; s
    movzx r13, sil          ; old_char
    movzx r14, dl           ; new_char

    call lafz_strlen
    mov  rbx, rax           ; length

    ; alloc copy
    mov  rdi, rbx
    call lafz_alloc
    push rax

    ; copy + replace
    mov  rdi, rax
    mov  rsi, r12
    mov  rcx, rbx
.repl_loop:
    test rcx, rcx
    jz   .repl_done
    movzx rax, byte [rsi]
    cmp  rax, r13
    jne  .repl_copy
    mov  rax, r14
.repl_copy:
    mov  [rdi], al
    inc  rdi
    inc  rsi
    dec  rcx
    jmp  .repl_loop
.repl_done:
    mov  byte [rdi], 0
    pop  rax
    jmp  .repl_ret
.repl_null:
    xor  rax, rax
.repl_ret:
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    ret

; ================================================================
; New functions added in v0.3.0
; ================================================================

; -- lafz__format(fmt, arg1..arg5) -> lafz ------------------------
; sprintf-like: formats into a 8192-byte static buffer and returns ptr.
; Supports: %d %i %u %x %X %o %s %c %% and %l/%ll prefix.
; NOTE: successive calls OVERWRITE the same buffer (single-threaded use).
global lafz__format
lafz__format:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 72          ; spill area for up to 5 extra args

%ifdef WIN64_TARGET
    mov  r12, rcx         ; fmt
    mov  [rsp + 0],  rdx  ; arg1
    mov  [rsp + 8],  r8   ; arg2
    mov  [rsp + 16], r9   ; arg3
    mov  qword [rsp + 24], 0
    mov  qword [rsp + 32], 0
%else
    mov  r12, rdi         ; fmt
    mov  [rsp + 0],  rsi  ; arg1
    mov  [rsp + 8],  rdx  ; arg2
    mov  [rsp + 16], rcx  ; arg3
    mov  [rsp + 24], r8   ; arg4
    mov  [rsp + 32], r9   ; arg5
%endif
    xor  r13, r13         ; arg index
    lea  r14, [rel lafz_fmt_buf]       ; write pointer
    lea  r15, [rel lafz_fmt_buf + 8188] ; buffer end (leave room for null)

.lfmt_loop:
    mov  al, [r12]
    test al, al
    jz   .lfmt_done
    inc  r12
    cmp  al, '%'
    jne  .lfmt_char

    ; read specifier (or modifier)
    mov  al, [r12]
    test al, al
    jz   .lfmt_done
    inc  r12

    ; %l / %ll prefix skip
    cmp  al, 'l'
    jne  .lfmt_no_l
    mov  al, [r12]
    test al, al
    jz   .lfmt_done
    cmp  al, 'l'
    jne  .lfmt_dispatch   ; single 'l' — al = specifier already
    inc  r12              ; skip second 'l'
    mov  al, [r12]
    test al, al
    jz   .lfmt_done
    inc  r12
    jmp  .lfmt_dispatch
.lfmt_no_l:

.lfmt_dispatch:
    cmp  al, '%'
    je   .lfmt_pct
    cmp  al, 'd'
    je   .lfmt_d
    cmp  al, 'i'
    je   .lfmt_d
    cmp  al, 'u'
    je   .lfmt_u
    cmp  al, 'x'
    je   .lfmt_x
    cmp  al, 'X'
    je   .lfmt_x
    cmp  al, 'o'
    je   .lfmt_o
    cmp  al, 's'
    je   .lfmt_s
    cmp  al, 'c'
    je   .lfmt_c
    jmp  .lfmt_loop

.lfmt_pct:
    cmp  r14, r15
    jae  .lfmt_done
    mov  byte [r14], '%'
    inc  r14
    jmp  .lfmt_loop

.lfmt_char:
    cmp  r14, r15
    jae  .lfmt_done
    mov  [r14], al
    inc  r14
    jmp  .lfmt_loop

; ---- integer to temp buf, then copy to output ------------------
.lfmt_d:
    mov  rbx, [rsp + r13*8]
    inc  r13
    test rbx, rbx
    jns  .lfmt_d_pos
    cmp  r14, r15
    jae  .lfmt_done
    mov  byte [r14], '-'
    inc  r14
    neg  rbx
.lfmt_d_pos:
    lea  rcx, [rel lafz_fmt_tmp + 31]
    mov  byte [rcx], 0
    mov  rax, rbx
    test rax, rax
    jnz  .lfmt_d_cvt
    dec  rcx
    mov  byte [rcx], '0'
    jmp  .lfmt_copy_tmp
.lfmt_d_cvt:
    xor  rdx, rdx
    mov  rbx, 10
    div  rbx
    dec  rcx
    add  dl, '0'
    mov  [rcx], dl
    test rax, rax
    jnz  .lfmt_d_cvt
    jmp  .lfmt_copy_tmp

.lfmt_u:
    mov  rax, [rsp + r13*8]
    inc  r13
    lea  rcx, [rel lafz_fmt_tmp + 31]
    mov  byte [rcx], 0
    test rax, rax
    jnz  .lfmt_u_cvt
    dec  rcx
    mov  byte [rcx], '0'
    jmp  .lfmt_copy_tmp
.lfmt_u_cvt:
    xor  rdx, rdx
    mov  rbx, 10
    div  rbx
    dec  rcx
    add  dl, '0'
    mov  [rcx], dl
    test rax, rax
    jnz  .lfmt_u_cvt
    jmp  .lfmt_copy_tmp

.lfmt_x:
    mov  rax, [rsp + r13*8]
    inc  r13
    lea  rcx, [rel lafz_fmt_tmp + 31]
    mov  byte [rcx], 0
    test rax, rax
    jnz  .lfmt_x_cvt
    dec  rcx
    mov  byte [rcx], '0'
    jmp  .lfmt_copy_tmp
.lfmt_x_cvt:
    mov  rdx, rax
    and  rdx, 0xF
    cmp  dl, 10
    jl   .lfmt_x_dig
    add  dl, 'a' - 10
    jmp  .lfmt_x_st
.lfmt_x_dig:
    add  dl, '0'
.lfmt_x_st:
    dec  rcx
    mov  [rcx], dl
    shr  rax, 4
    test rax, rax
    jnz  .lfmt_x_cvt
    jmp  .lfmt_copy_tmp

.lfmt_o:
    mov  rax, [rsp + r13*8]
    inc  r13
    lea  rcx, [rel lafz_fmt_tmp + 31]
    mov  byte [rcx], 0
    test rax, rax
    jnz  .lfmt_o_cvt
    dec  rcx
    mov  byte [rcx], '0'
    jmp  .lfmt_copy_tmp
.lfmt_o_cvt:
    xor  rdx, rdx
    mov  rbx, 8
    div  rbx
    dec  rcx
    add  dl, '0'
    mov  [rcx], dl
    test rax, rax
    jnz  .lfmt_o_cvt
    jmp  .lfmt_copy_tmp

.lfmt_copy_tmp:
    ; copy null-terminated string at rcx → r14
    mov  al, [rcx]
    test al, al
    jz   .lfmt_loop
    cmp  r14, r15
    jae  .lfmt_done
    mov  [r14], al
    inc  r14
    inc  rcx
    jmp  .lfmt_copy_tmp

.lfmt_s:
    mov  rbx, [rsp + r13*8]
    inc  r13
    test rbx, rbx
    jz   .lfmt_loop
.lfmt_s_copy:
    mov  al, [rbx]
    test al, al
    jz   .lfmt_loop
    cmp  r14, r15
    jae  .lfmt_done
    mov  [r14], al
    inc  r14
    inc  rbx
    jmp  .lfmt_s_copy

.lfmt_c:
    mov  rbx, [rsp + r13*8]
    inc  r13
    cmp  r14, r15
    jae  .lfmt_done
    mov  [r14], bl
    inc  r14
    jmp  .lfmt_loop

.lfmt_done:
    mov  byte [r14], 0
    lea  rax, [rel lafz_fmt_buf]
    add  rsp, 72
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- lafz__repeat(s, n) -> lafz ------------------------------------
; Returns s repeated n times (allocated on heap).
; Linux:   rdi=s, rsi=n
; Windows: rcx=s, rdx=n
global lafz__repeat
lafz__repeat:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz   .rep_null
    test rsi, rsi
    jle  .rep_empty

    mov  r12, rdi     ; s
    mov  r13, rsi     ; n

    ; get string length
    mov  rbx, rdi
.rep_len:
    cmp  byte [rbx], 0
    je   .rep_len_done
    inc  rbx
    jmp  .rep_len
.rep_len_done:
    sub  rbx, r12     ; rbx = len(s)

    ; alloc len*n + 1
    mov  r14, rbx
    imul r14, r13
    mov  rdi, r14
    call lafz_alloc   ; rax = dst
    push rax

    mov  r14, rax     ; write ptr
    mov  rcx, r13
.rep_outer:
    test rcx, rcx
    jz   .rep_outer_done
    push rcx
    mov  rsi, r12     ; src
    mov  rdx, rbx     ; len
.rep_inner:
    test rdx, rdx
    jz   .rep_inner_done
    mov  al, [rsi]
    mov  [r14], al
    inc  rsi
    inc  r14
    dec  rdx
    jmp  .rep_inner
.rep_inner_done:
    pop  rcx
    dec  rcx
    jmp  .rep_outer
.rep_outer_done:
    mov  byte [r14], 0
    pop  rax
    jmp  .rep_ret

.rep_empty:
    ; alloc 1 byte (empty string)
    mov  rdi, 1
    call lafz_alloc
    mov  byte [rax], 0
    jmp  .rep_ret

.rep_null:
    xor  rax, rax
.rep_ret:
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__count(s, needle) -> adad --------------------------------
; Count non-overlapping occurrences of needle in s.
; Linux:   rdi=s, rsi=needle
; Windows: rcx=s, rdx=needle
global lafz__count
lafz__count:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz   .cnt_zero
    test rsi, rsi
    jz   .cnt_zero

    mov  r12, rdi     ; haystack
    mov  r13, rsi     ; needle
    xor  r14, r14     ; count

    ; needle length
    mov  rbx, r13
.cnt_nlen:
    cmp  byte [rbx], 0
    je   .cnt_nlen_done
    inc  rbx
    jmp  .cnt_nlen
.cnt_nlen_done:
    sub  rbx, r13     ; rbx = needle_len
    test rbx, rbx
    jz   .cnt_zero

.cnt_loop:
    cmp  byte [r12], 0
    je   .cnt_done

    ; compare needle at r12
    mov  r15, r12
    mov  r8,  r13
    mov  rcx, rbx
.cnt_cmp:
    test rcx, rcx
    jz   .cnt_match
    mov  al,  [r15]
    mov  dl,  [r8]
    cmp  al, dl
    jne  .cnt_nomatch
    inc  r15
    inc  r8
    dec  rcx
    jmp  .cnt_cmp
.cnt_match:
    inc  r14
    add  r12, rbx     ; skip past matched needle
    jmp  .cnt_loop
.cnt_nomatch:
    inc  r12
    jmp  .cnt_loop

.cnt_done:
    mov  rax, r14
    jmp  .cnt_ret
.cnt_zero:
    xor  rax, rax
.cnt_ret:
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__pad_left(s, width, ch) -> lafz --------------------------
; Returns s left-padded to width using character ch (adad, low byte).
; Linux:   rdi=s, rsi=width, rdx=ch
; Windows: rcx=s, rdx=width, r8=ch
global lafz__pad_left
lafz__pad_left:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
    mov  rdx, r8
%endif
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz   .padl_null

    mov  r12, rdi     ; s
    movzx r13, dl     ; ch byte
    mov  r14, rsi     ; width

    ; get strlen
    mov  rbx, r12
.padl_slen:
    cmp  byte [rbx], 0
    je   .padl_slen_done
    inc  rbx
    jmp  .padl_slen
.padl_slen_done:
    sub  rbx, r12     ; rbx = slen

    ; if slen >= width, return copy
    cmp  rbx, r14
    jge  .padl_just_copy

    ; pad = width - slen
    mov  rdi, r14     ; alloc width bytes
    call lafz_alloc
    push rax

    ; write (width - slen) pad chars
    mov  rdi, rax
    mov  rcx, r14
    sub  rcx, rbx
.padl_fill:
    test rcx, rcx
    jz   .padl_fill_done
    mov  [rdi], r13b
    inc  rdi
    dec  rcx
    jmp  .padl_fill
.padl_fill_done:
    ; copy original string
    mov  rsi, r12
    mov  rcx, rbx
.padl_copy:
    test rcx, rcx
    jz   .padl_copy_done
    mov  al, [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    dec  rcx
    jmp  .padl_copy
.padl_copy_done:
    mov  byte [rdi], 0
    pop  rax
    jmp  .padl_ret

.padl_just_copy:
    mov  rdi, rbx
    call lafz_alloc
    push rax
    mov  rdi, rax
    mov  rsi, r12
    mov  rcx, rbx
.padl_just_loop:
    test rcx, rcx
    jz   .padl_just_done
    mov  al, [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    dec  rcx
    jmp  .padl_just_loop
.padl_just_done:
    mov  byte [rdi], 0
    pop  rax
    jmp  .padl_ret

.padl_null:
    xor  rax, rax
.padl_ret:
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__pad_right(s, width, ch) -> lafz -------------------------
; Returns s right-padded to width using character ch.
; Linux:   rdi=s, rsi=width, rdx=ch
; Windows: rcx=s, rdx=width, r8=ch
global lafz__pad_right
lafz__pad_right:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
    mov  rdx, r8
%endif
    push rbx
    push r12
    push r13
    push r14

    test rdi, rdi
    jz   .padr_null

    mov  r12, rdi     ; s
    movzx r13, dl     ; ch byte
    mov  r14, rsi     ; width

    ; strlen
    mov  rbx, r12
.padr_slen:
    cmp  byte [rbx], 0
    je   .padr_slen_done
    inc  rbx
    jmp  .padr_slen
.padr_slen_done:
    sub  rbx, r12     ; rbx = slen

    ; if slen >= width, return copy
    cmp  rbx, r14
    jge  .padr_just_copy

    mov  rdi, r14
    call lafz_alloc
    push rax

    ; copy original string
    mov  rdi, rax
    mov  rsi, r12
    mov  rcx, rbx
.padr_copy:
    test rcx, rcx
    jz   .padr_copy_done
    mov  al, [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    dec  rcx
    jmp  .padr_copy
.padr_copy_done:
    ; write padding
    mov  rcx, r14
    sub  rcx, rbx
.padr_fill:
    test rcx, rcx
    jz   .padr_fill_done
    mov  [rdi], r13b
    inc  rdi
    dec  rcx
    jmp  .padr_fill
.padr_fill_done:
    mov  byte [rdi], 0
    pop  rax
    jmp  .padr_ret

.padr_just_copy:
    mov  rdi, rbx
    call lafz_alloc
    push rax
    mov  rdi, rax
    mov  rsi, r12
    mov  rcx, rbx
.padr_jl:
    test rcx, rcx
    jz   .padr_jd
    mov  al, [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    dec  rcx
    jmp  .padr_jl
.padr_jd:
    mov  byte [rdi], 0
    pop  rax
    jmp  .padr_ret

.padr_null:
    xor  rax, rax
.padr_ret:
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    ret

; -- lafz__char_at(s, i) -> adad -----------------------------------
; Returns the character byte at index i, or 0 if out of bounds.
; Linux:   rdi=s, rsi=i
; Windows: rcx=s, rdx=i
global lafz__char_at
lafz__char_at:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    test rdi, rdi
    jz   .chat_zero
    test rsi, rsi
    js   .chat_zero

    ; walk to index
    mov  rcx, rsi
.chat_loop:
    cmp  byte [rdi], 0
    je   .chat_zero     ; index past end
    test rcx, rcx
    jz   .chat_found
    inc  rdi
    dec  rcx
    jmp  .chat_loop
.chat_found:
    movzx rax, byte [rdi]
    ret
.chat_zero:
    xor  rax, rax
    ret

; -- lafz__set_char(s, i, ch) -> khali ----------------------------
; In-place: set character at index i to ch (dangerous but fast).
; Linux:   rdi=s, rsi=i, rdx=ch
; Windows: rcx=s, rdx=i, r8=ch
global lafz__set_char
lafz__set_char:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
    mov  rdx, r8
%endif
    test rdi, rdi
    jz   .schar_ret
    test rsi, rsi
    js   .schar_ret
    mov  rcx, rsi
.schar_loop:
    cmp  byte [rdi], 0
    je   .schar_ret
    test rcx, rcx
    jz   .schar_set
    inc  rdi
    dec  rcx
    jmp  .schar_loop
.schar_set:
    mov  [rdi], dl
.schar_ret:
    xor  rax, rax
    ret

; ============================================================
; NEW FUNCTIONS: split, join, from_harf
; ============================================================

; -- lafz__split(s: lafz, delim: adad) → [lafz]
;    Linux: rdi=s, rsi=delim   Windows: rcx=s, rdx=delim
;    Returns dynamic-array pointer (header at [ret-16]: len, cap).
;    Uses static buffers (not re-entrant, but fine for VPM).
global lafz__split
lafz__split:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
%ifdef WIN64_TARGET
    mov  r12, rcx           ; r12 = s
    movzx r13, dl           ; r13 = delim char (byte)
%else
    mov  r12, rdi           ; r12 = s
    movzx r13, sil          ; r13 = delim char
%endif
    lea  r14, [rel lafz_split_strbuf]   ; r14 = strbuf write ptr
    xor  r15, r15                        ; r15 = segment count
    lea  rbx, [rel lafz_split_ptrs + 16] ; rbx = array data ptr

    ; mark start of segment 0
    mov  [rbx], r14
.spl_loop:
    movzx rax, byte [r12]
    test al, al
    jz   .spl_eos
    cmp  al, r13b
    je   .spl_delim
    ; regular char: copy to strbuf
    mov  [r14], al
    inc  r12
    inc  r14
    jmp  .spl_loop
.spl_delim:
    mov  byte [r14], 0      ; null-terminate segment
    inc  r14
    inc  r12                ; skip delimiter
    inc  r15                ; segment done
    cmp  r15, 511
    jge  .spl_eos           ; cap at 511 segments
    ; mark start of next segment
    lea  rax, [rbx + r15*8]
    mov  [rax], r14
    jmp  .spl_loop
.spl_eos:
    mov  byte [r14], 0      ; null-terminate last segment
    inc  r15                ; total count

    ; write header so that [data - 8] = len  (Velocity array convention)
    ; layout: [+0]=cap(unused), [+8]=len, [+16..]=data ptrs
    lea  rax, [rel lafz_split_ptrs]
    mov  qword [rax],     512   ; cap at [data - 16]
    mov  [rax + 8], r15         ; len at [data - 8]  ← used by join/codegen

    ; return data ptr (past 16-byte header)
    lea  rax, [rel lafz_split_ptrs + 16]
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- lafz__join(arr: [lafz], delim: lafz) → lafz
;    Linux: rdi=arr, rsi=delim   Windows: rcx=arr, rdx=delim
;    arr[-8] = length (dynamic array format).
global lafz__join
lafz__join:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
%ifdef WIN64_TARGET
    mov  r12, rcx           ; r12 = arr ptr (data)
    mov  r13, rdx           ; r13 = delim ptr
%else
    mov  r12, rdi
    mov  r13, rsi
%endif
    mov  r14, [r12 - 8]    ; r14 = array length
    lea  rbx, [rel lafz_join_buf]  ; rbx = output write ptr
    xor  r15, r15           ; r15 = index
.join_loop:
    cmp  r15, r14
    jge  .join_done
    mov  rax, [r12 + r15*8]  ; ptr to string
    test rax, rax
    jz   .join_next
.join_copy:
    mov  cl, [rax]
    test cl, cl
    jz   .join_after_elem
    mov  [rbx], cl
    inc  rax
    inc  rbx
    jmp  .join_copy
.join_after_elem:
    inc  r15
    cmp  r15, r14
    jge  .join_loop         ; last element: no delimiter
    ; copy delimiter
    mov  rax, r13
    test rax, rax
    jz   .join_loop
.join_delim:
    mov  cl, [rax]
    test cl, cl
    jz   .join_loop
    mov  [rbx], cl
    inc  rax
    inc  rbx
    jmp  .join_delim
.join_next:
    inc  r15
    jmp  .join_loop
.join_done:
    mov  byte [rbx], 0
    lea  rax, [rel lafz_join_buf]
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- lafz__from_harf(c: adad) → lafz (single-char string)
;    Linux: rdi=c   Windows: rcx=c
global lafz__from_harf
lafz__from_harf:
%ifdef WIN64_TARGET
    mov  byte [rel lafz_harf_buf], cl
%else
    mov  byte [rel lafz_harf_buf], dil
%endif
    mov  byte [rel lafz_harf_buf + 1], 0
    lea  rax, [rel lafz_harf_buf]
    ret

section .bss
    lafz_fmt_buf      resb 8192
    lafz_fmt_tmp      resb 64
    lafz_split_strbuf resb 65536   ; string storage for split results
    lafz_split_ptrs   resb 4112    ; 16-byte header + 512 * 8-byte ptrs
    lafz_join_buf     resb 65536   ; output buffer for join
    lafz_harf_buf     resb 2       ; single-char buffer for from_harf
