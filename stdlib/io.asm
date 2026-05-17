; ============================================================
; Velocity Standard Library - I/O Module (io.asm)
; Kashmiri Edition v2 - Windows + Linux portable
;
; Compile with:
;   Linux:   nasm -f elf64
;   Windows: nasm -f win64
;
; Functions:
;   io__chhaap(fmt, ...)       - printf-like (%d %s %c %f %b %%)
;   io__chhaapLine()           - print newline
;   io__chhaapSpace()          - print space
;   io__stdin()                - read line as string
;   io__input()                - read integer from stdin (deprecated)
;   io__open(path, mode)       - open file, mode: 0=read 1=write 2=append
;   io__close(fd_or_handle)    - close file, returns 0 on success
;   io__fopen / io__fclose     - aliases of open/close
; ============================================================

%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

%ifdef WIN64_TARGET
  %define WINDOWS 1
%else
  %define WINDOWS 0
%endif

section .bss
    io_num_buf      resb 32
    io_inp_buf      resb 4096
    io_char_buf     resb 1
    io_fmt_left     resb 1      ; left-align flag (%-s)
    io_fmt_zero     resb 1      ; zero-pad flag (%0d)
    io_fmt_sign     resb 1      ; force-sign flag (%+d)
    io_fmt_width    resq 1      ; saved width before parsing precision
    io_tmp_nbuf     resb 48     ; temp buffer for int/hex formatting
    io_file_buf     resb 1048576 ; 1 MB file read buffer

section .data
    io_newline  db 10
    io_space    db 32
    io_minus    db '-'
    io_dot      db '.'
    io_zero     db '0'
    io_poz_str  db 'poz', 0
    io_apuz_str db 'apuz', 0
    io_fmt_d    db '%d', 0
    io_one_mil  dq 1000000.0
    io_fmt_0x   db '0x'
    io_sci_ten  dq 10.0
    io_sci_one  dq 1.0
    io_sci_zero db "0.000000e+00", 0

section .text
%ifdef WIN64_TARGET
extern GetStdHandle
extern WriteFile
extern ReadFile
extern ExitProcess
extern CreateFileA
extern CloseHandle

; helper: write rax=ptr, rcx=len to stdout
__io_write_win:
    ; rcx = ptr, rdx = len already expected
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    ; 32-byte shadow + 8-byte arg5 + 8-byte written + padding (16-byte aligned)
    sub  rsp, 56
    mov  r12, rcx        ; save ptr
    mov  r13, rdx        ; save len
    ; GetStdHandle(STD_OUTPUT_HANDLE = -11)
    mov  rcx, -11
    call GetStdHandle
    mov  rbx, rax        ; handle
    ; WriteFile(handle, ptr, len, &written, NULL)
    mov  qword [rsp + 40], 0
    mov  rcx, rbx
    mov  rdx, r12
    mov  r8,  r13
    lea  r9,  [rsp + 40]
    mov  qword [rsp + 32], 0   ; lpOverlapped = NULL (5th arg)
    call WriteFile
    add  rsp, 56
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

%else ; Linux
; helper: write rsi=ptr, rdx=len to stdout (fd=1)
__io_write_linux:
    push rbp
    mov  rbp, rsp
    mov  rax, 1
    mov  rdi, 1
    syscall
    pop  rbp
    ret
%endif

; -- io__chhaapLine / io__chhaapln --------------------------
global io__chhaapLine
global io__chhaapln
global chhaapln
io__chhaapLine:
io__chhaapln:
chhaapln:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 64
    mov  rcx, io_newline
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_newline]
    mov  rdx, 1
    call __io_write_linux
%endif
    xor  rax, rax
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__chhaapSpace ----------------------------------------
global io__chhaapSpace
io__chhaapSpace:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 64
    mov  rcx, io_space
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_space]
    mov  rdx, 1
    call __io_write_linux
%endif
    xor  rax, rax
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__putchar(c: adad) -> adad ---------------------------
global io__putchar
io__putchar:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  byte [rel io_char_buf], cl
    sub  rsp, 64
    lea  rcx, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_win
%else
    mov  byte [rel io_char_buf], dil
    lea  rsi, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_linux
%endif
    xor  rax, rax
    mov  rsp, rbp
    pop  rbp
    ret


; -- io__print_str_raw (internal: rdi/rcx=ptr) --------------
__io_print_str_raw:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    ; compute length
%ifdef WIN64_TARGET
    mov  r12, rcx
%else
    mov  r12, rdi
%endif
    xor  rbx, rbx
.len_loop:
    mov  al, [r12 + rbx]
    test al, al
    jz   .len_done
    inc  rbx
    jmp  .len_loop
.len_done:
    test rbx, rbx
    jz   .done
%ifdef WIN64_TARGET
    mov  rcx, r12
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r12
    mov  rdx, rbx
    call __io_write_linux
%endif
.done:
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__print_int (internal: rdi/rcx = i64) ----------------
__io_print_int:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    sub  rsp, 8          ; keep call alignment + scratch slot
%ifdef WIN64_TARGET
    mov  r12, rcx
%else
    mov  r12, rdi
%endif
    lea  r13, [rel io_num_buf + 31]
    mov  byte [r13], 0
    test r12, r12
    jns  .positive
    ; print '-'
    mov  [rsp], r12
%ifdef WIN64_TARGET
    lea  rcx, [rel io_minus]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_minus]
    mov  rdx, 1
    call __io_write_linux
%endif
    mov  r12, [rsp]
    neg  r12
.positive:
    test r12, r12
    jnz  .convert
    dec  r13
    mov  byte [r13], '0'
    jmp  .print
.convert:
    xor  rbx, rbx
.conv_loop:
    test r12, r12
    jz   .print
    mov  rax, r12
    xor  rdx, rdx
    mov  rcx, 10
    div  rcx
    mov  r12, rax
    dec  r13
    add  dl, '0'
    mov  [r13], dl
    inc  rbx
    jmp  .conv_loop
.print:
    ; count length
    lea  rbx, [rel io_num_buf + 31]
    sub  rbx, r13
%ifdef WIN64_TARGET
    mov  rcx, r13
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r13
    mov  rdx, rbx
    call __io_write_linux
%endif
    add  rsp, 8
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__print_int_zpad (internal: value + min digits) --------------
;   Linux:   rdi=value, rsi=min_digits
;   Windows: rcx=value, rdx=min_digits
__io_print_int_zpad:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub  rsp, 8
%ifdef WIN64_TARGET
    mov  r12, rcx
    mov  r10, rdx
%else
    mov  r12, rdi
    mov  r10, rsi
%endif
    cmp  r10, 0
    jg   .zpad_start
%ifdef WIN64_TARGET
    mov  rcx, r12
%else
    mov  rdi, r12
%endif
    call __io_print_int
    jmp  .zpad_done

.zpad_start:
    lea  r13, [rel io_num_buf + 31]
    mov  byte [r13], 0

    test r12, r12
    jns  .zpad_positive
%ifdef WIN64_TARGET
    lea  rcx, [rel io_minus]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_minus]
    mov  rdx, 1
    call __io_write_linux
%endif
    neg  r12

.zpad_positive:
    xor  rbx, rbx          ; digit count
    test r12, r12
    jnz  .zpad_convert
    dec  r13
    mov  byte [r13], '0'
    mov  rbx, 1
    jmp  .zpad_pad

.zpad_convert:
.zpad_loop:
    test r12, r12
    jz   .zpad_pad
    mov  rax, r12
    xor  rdx, rdx
    mov  rcx, 10
    div  rcx
    mov  r12, rax
    dec  r13
    add  dl, '0'
    mov  [r13], dl
    inc  rbx
    jmp  .zpad_loop

.zpad_pad:
    mov  r14, r10
    sub  r14, rbx
    jle  .zpad_print
.zpad_zeros:
%ifdef WIN64_TARGET
    lea  rcx, [rel io_zero]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_zero]
    mov  rdx, 1
    call __io_write_linux
%endif
    dec  r14
    jnz  .zpad_zeros

.zpad_print:
%ifdef WIN64_TARGET
    mov  rcx, r13
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r13
    mov  rdx, rbx
    call __io_write_linux
%endif

.zpad_done:
    add  rsp, 8
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__print_float (internal: xmm0 = f64) -----------------
__io_print_float:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    sub  rsp, 40         ; keep call alignment + scratch space
    ; check negative
    xorpd xmm1, xmm1
    ucomisd xmm0, xmm1
    jae  .pos_f
    ; print minus
    movsd [rsp + 32], xmm0
%ifdef WIN64_TARGET
    lea  rcx, [rel io_minus]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_minus]
    mov  rdx, 1
    call __io_write_linux
%endif
    movsd xmm0, [rsp + 32]
    ; negate
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movapd xmm0, xmm1
.pos_f:
    ; extract integer part
    cvttsd2si rax, xmm0
    mov  r12, rax
    ; print integer part
%ifdef WIN64_TARGET
    mov  rcx, r12
%else
    mov  rdi, r12
%endif
    call __io_print_int
    ; print '.'
%ifdef WIN64_TARGET
    lea  rcx, [rel io_dot]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_dot]
    mov  rdx, 1
    call __io_write_linux
%endif
    ; print 6 decimal digits
    cvtsi2sd xmm1, r12
    subsd xmm0, xmm1
    mulsd xmm0, [rel io_one_mil]
    cvttsd2si rax, xmm0
    test rax, rax
    jns  .frac_ok
    neg  rax
.frac_ok:
    ; pad to 6 digits
    lea  r13, [rel io_num_buf + 31]
    mov  byte [r13], 0
    mov  rcx, 6
.frac_loop:
    xor  rdx, rdx
    mov  rbx, 10
    div  rbx
    dec  r13
    add  dl, '0'
    mov  [r13], dl
    loop .frac_loop
    lea  rbx, [rel io_num_buf + 31]
    sub  rbx, r13
%ifdef WIN64_TARGET
    mov  rcx, r13
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r13
    mov  rdx, rbx
    call __io_write_linux
%endif
    add  rsp, 40
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- __io_float_to_tmpbuf(value, precision) -> rax=ptr, rdx=len ----
;    Linux:   xmm0=value, rdi=precision
;    Windows: xmm0=value, rcx=precision
__io_float_to_tmpbuf:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 16
%ifdef WIN64_TARGET
    mov  r12, rcx
%else
    mov  r12, rdi
%endif
    cmp  r12, 0
    jge  .ftb_prec_ok
    xor  r12, r12
.ftb_prec_ok:
    cmp  r12, 18
    jle  .ftb_prec_clamped
    mov  r12, 18
.ftb_prec_clamped:
    lea  r13, [rel io_tmp_nbuf]
    xorpd xmm1, xmm1
    ucomisd xmm0, xmm1
    jae  .ftb_notneg
    mov  byte [r13], '-'
    inc  r13
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movapd xmm0, xmm1
.ftb_notneg:
    movsd [rsp], xmm0
    cvttsd2si r14, xmm0
    mov  [rsp + 8], r14
    lea  r15, [rel io_num_buf + 31]
    mov  byte [r15], 0
    test r14, r14
    jnz  .ftb_int_loop
    dec  r15
    mov  byte [r15], '0'
    jmp  .ftb_copy_int
.ftb_int_loop:
    mov  rax, r14
    xor  rdx, rdx
    mov  rbx, 10
    div  rbx
    mov  r14, rax
    dec  r15
    add  dl, '0'
    mov  [r15], dl
    test r14, r14
    jnz  .ftb_int_loop
.ftb_copy_int:
    mov  al, [r15]
    test al, al
    jz   .ftb_after_int
    mov  [r13], al
    inc  r13
    inc  r15
    jmp  .ftb_copy_int
.ftb_after_int:
    test r12, r12
    jz   .ftb_done
    mov  byte [r13], '.'
    inc  r13
    movsd xmm0, [rsp]
    mov  rax, [rsp + 8]
    cvtsi2sd xmm1, rax
    subsd xmm0, xmm1
.ftb_frac_loop:
    test r12, r12
    jz   .ftb_done
    mulsd xmm0, [rel io_sci_ten]
    cvttsd2si rax, xmm0
    add  al, '0'
    mov  [r13], al
    inc  r13
    sub  al, '0'
    movzx rbx, al
    cvtsi2sd xmm1, rbx
    subsd xmm0, xmm1
    dec  r12
    jmp  .ftb_frac_loop
.ftb_done:
    mov  byte [r13], 0
    lea  rax, [rel io_tmp_nbuf]
    mov  rdx, r13
    sub  rdx, rax
    add  rsp, 16
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ============================================================
; NEW HELPER FUNCTIONS
; ============================================================

; -- __io_write_n_char(count, char) → void
;    Linux:   rdi=count, rsi=char(byte)
;    Windows: rcx=count, rdx=char(byte)
__io_write_n_char:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
%ifdef WIN64_TARGET
    mov  rbx, rcx
    movzx r12, dl
%else
    mov  rbx, rdi
    movzx r12, sil
%endif
    test rbx, rbx
    jle  .wnc_done
    mov  byte [rel io_char_buf], r12b
.wnc_loop:
%ifdef WIN64_TARGET
    lea  rcx, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_linux
%endif
    dec  rbx
    jnz  .wnc_loop
.wnc_done:
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- __io_strlen(ptr) → rax (length, not including null)
;    Linux: rdi=ptr   Windows: rcx=ptr
__io_strlen:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    xor  rax, rax
.slen_loop:
    cmp  byte [rdi + rax], 0
    je   .slen_done
    inc  rax
    jmp  .slen_loop
.slen_done:
    mov  rsp, rbp
    pop  rbp
    ret

; -- __io_int_to_tmpbuf(value) → rax=ptr, rdx=len
;    Linux: rdi=value   Windows: rcx=value
;    Formats signed integer into io_tmp_nbuf (48 bytes).
;    Respects io_fmt_sign flag for '+' prefix.
__io_int_to_tmpbuf:
    push rbp
    mov  rbp, rsp
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  r12, rcx
%else
    mov  r12, rdi
%endif
    lea  r13, [rel io_tmp_nbuf + 47]
    mov  byte [r13], 0          ; null terminator
    mov  byte [rel io_tmp_nbuf], 0  ; sign slot (0 = no sign)
    test r12, r12
    jns  .itb_pos
    neg  r12
    mov  byte [rel io_tmp_nbuf], '-'
    jmp  .itb_digits
.itb_pos:
    cmp  byte [rel io_fmt_sign], 1
    jne  .itb_digits
    mov  byte [rel io_tmp_nbuf], '+'
.itb_digits:
    test r12, r12
    jnz  .itb_loop
    dec  r13
    mov  byte [r13], '0'
    jmp  .itb_measure
.itb_loop:
    test r12, r12
    jz   .itb_measure
    mov  rax, r12
    xor  rdx, rdx
    mov  rcx, 10
    div  rcx
    mov  r12, rax
    dec  r13
    add  dl, '0'
    mov  [r13], dl
    jmp  .itb_loop
.itb_measure:
    cmp  byte [rel io_tmp_nbuf], 0
    je   .itb_nosign
    dec  r13
    mov  al, [rel io_tmp_nbuf]
    mov  [r13], al
.itb_nosign:
    lea  rax, [rel io_tmp_nbuf + 47]
    sub  rax, r13               ; total length
    mov  rdx, rax
    mov  rax, r13               ; ptr to start
    pop  r13
    pop  r12
    mov  rsp, rbp
    pop  rbp
    ret

; -- __io_print_sci(xmm0 = f64): print in scientific notation (1.234567e+08)
__io_print_sci:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    sub  rsp, 16    ; local space: [rsp]=xmm0 save, [rsp+8]=padding
    ; handle negative: negate first, then print '-'
    xorpd xmm1, xmm1
    ucomisd xmm0, xmm1
    jae  .sci_notneg
    ; negate xmm0 (positive value now in xmm0)
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movapd xmm0, xmm1
    movsd [rsp], xmm0   ; save before write call (Windows may clobber XMM0)
%ifdef WIN64_TARGET
    lea  rcx, [rel io_minus]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_minus]
    mov  rdx, 1
    call __io_write_linux
%endif
    movsd xmm0, [rsp]   ; restore (needed on Windows)
.sci_notneg:
    xorpd xmm1, xmm1
    ucomisd xmm0, xmm1
    jne  .sci_nonzero
%ifdef WIN64_TARGET
    lea  rcx, [rel io_sci_zero]
    call __io_print_str_raw
%else
    lea  rdi, [rel io_sci_zero]
    call __io_print_str_raw
%endif
    jmp  .sci_done
.sci_nonzero:
    xor  r12, r12
    movsd xmm2, [rel io_sci_ten]
    movsd xmm3, [rel io_sci_one]
.sci_div_loop:
    ucomisd xmm0, xmm2
    jb   .sci_mul_check
    divsd xmm0, xmm2
    inc  r12
    jmp  .sci_div_loop
.sci_mul_check:
.sci_mul_loop:
    ucomisd xmm0, xmm3
    jae  .sci_got_mant
    mulsd xmm0, xmm2
    dec  r12
    jmp  .sci_mul_loop
.sci_got_mant:
    call __io_print_float
    mov  byte [rel io_char_buf], 'e'
%ifdef WIN64_TARGET
    lea  rcx, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_linux
%endif
    test r12, r12
    jns  .sci_exp_pos
    neg  r12
    mov  byte [rel io_char_buf], '-'
    jmp  .sci_exp_sign
.sci_exp_pos:
    mov  byte [rel io_char_buf], '+'
.sci_exp_sign:
%ifdef WIN64_TARGET
    lea  rcx, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_linux
%endif
%ifdef WIN64_TARGET
    mov  rcx, r12
    mov  rdx, 2
%else
    mov  rdi, r12
    mov  rsi, 2
%endif
    call __io_print_int_zpad
.sci_done:
    add  rsp, 16
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__chhaap (fmt, ...) ----------------------------------
; Linux  SysV: rdi=fmt  rsi=arg1  rdx=arg2  rcx=arg3  r8=arg4  r9=arg5
; Windows MS:  rcx=fmt  rdx=arg1  r8=arg2   r9=arg3
global io__chhaap
io__chhaap:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    sub  rsp, 72        ; args spill area (+ alignment so call sites are ABI-correct)
%ifdef WIN64_TARGET
    mov  r12, rcx       ; fmt
    mov  [rsp + 0],  rdx
    mov  [rsp + 8],  r8
    mov  [rsp + 16], r9
    mov  qword [rsp + 24], 0
    mov  qword [rsp + 32], 0
%else
    mov  r12, rdi       ; fmt
    mov  [rsp + 0],  rsi
    mov  [rsp + 8],  rdx
    mov  [rsp + 16], rcx
    mov  [rsp + 24], r8
    mov  [rsp + 32], r9
%endif
    xor  r13, r13       ; arg index

.loop:
    mov  al, [r12]
    test al, al
    jz   .done
    inc  r12
    cmp  al, '%'
    jne  .print_char

    ; --- parse flags and optional width/precision ---
    mov  byte [rel io_fmt_left], 0
    mov  byte [rel io_fmt_zero], 0
    mov  byte [rel io_fmt_sign], 0
    xor  r15, r15           ; width accumulator

.fmt_nextc:
    ; Read next char WITHOUT consuming yet
    mov  al, [r12]
    test al, al
    jz   .done
    ; If we already have width digits, only more digits or specifier
    test r15, r15
    jnz  .fmt_wdigit_check
    ; r15==0: check flag chars first
    cmp  al, '-'
    jne  .fnc_notminus
    inc  r12
    mov  byte [rel io_fmt_left], 1
    jmp  .fmt_nextc
.fnc_notminus:
    cmp  al, '+'
    jne  .fnc_notplus
    inc  r12
    mov  byte [rel io_fmt_sign], 1
    jmp  .fmt_nextc
.fnc_notplus:
    cmp  al, '0'
    jne  .fnc_notzero
    inc  r12
    mov  byte [rel io_fmt_zero], 1
    jmp  .fmt_nextc     ; continue — next may be width digit or specifier
.fnc_notzero:
    cmp  al, '1'
    jb   .fmt_consume_spec  ; < '1': it's the specifier
    cmp  al, '9'
    ja   .fmt_consume_spec  ; > '9': it's the specifier
    ; digit '1'-'9': start of width
    inc  r12
    sub  al, '0'
    movzx r15, al
    jmp  .fmt_nextc

.fmt_wdigit_check:
    ; r15 > 0: only digits continue width
    cmp  al, '0'
    jb   .fmt_consume_spec
    cmp  al, '9'
    ja   .fmt_consume_spec
    inc  r12
    imul r15, r15, 10
    sub  al, '0'
    movzx rax, al
    add  r15, rax
    jmp  .fmt_nextc

.fmt_consume_spec:
    inc  r12                ; consume the specifier character
.fmt_dispatch:
    cmp  al, '.'
    je   .fmt_prec
    cmp  al, '%'
    je   .print_pct
    cmp  al, 'd'
    je   .fmt_d_w
    cmp  al, 'i'
    je   .fmt_d_w
    cmp  al, 's'
    je   .fmt_s_w
    cmp  al, 'c'
    je   .fmt_c
    cmp  al, 'f'
    je   .fmt_f
    cmp  al, 'b'
    je   .fmt_b
    cmp  al, 'x'
    je   .fmt_x_w
    cmp  al, 'X'
    je   .fmt_X_w
    cmp  al, 'u'
    je   .fmt_u
    cmp  al, 'p'
    je   .fmt_p
    cmp  al, 'l'
    je   .fmt_l_prefix
    cmp  al, 'L'
    je   .fmt_l_prefix
    cmp  al, 'o'
    je   .fmt_o
    cmp  al, 'e'
    je   .fmt_e
    cmp  al, 'E'
    je   .fmt_e
    cmp  al, 'g'
    je   .fmt_f
    cmp  al, 'G'
    je   .fmt_f
    cmp  al, 'n'
    je   .loop
    jmp  .loop

; ===== WIDTH/FLAG-AWARE HANDLERS (inside io__chhaap) =====

.fmt_d_w:
    mov  rbx, [rsp + r13*8]
    inc  r13
    test r15, r15
    jnz  .fdw_do_width
    cmp  byte [rel io_fmt_sign], 0
    je   .fdw_fast
.fdw_do_width:
    cmp  byte [rel io_fmt_zero], 1
    jne  .fdw_space
%ifdef WIN64_TARGET
    mov  rcx, rbx
    mov  rdx, r15
%else
    mov  rdi, rbx
    mov  rsi, r15
%endif
    call __io_print_int_zpad
    jmp  .loop
.fdw_space:
%ifdef WIN64_TARGET
    mov  rcx, rbx
%else
    mov  rdi, rbx
%endif
    call __io_int_to_tmpbuf     ; rax=ptr, rdx=len
    mov  r14, rax
    mov  rbx, rdx               ; rbx = len
    mov  rax, r15
    sub  rax, rbx               ; rax = pad
    jle  .fdw_nopad
    cmp  byte [rel io_fmt_left], 1
    je   .fdw_left
    mov  r15, rax
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, ' '
%else
    mov  rdi, r15
    mov  rsi, ' '
%endif
    call __io_write_n_char
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop
.fdw_left:
    mov  r15, rax
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, ' '
%else
    mov  rdi, r15
    mov  rsi, ' '
%endif
    call __io_write_n_char
    jmp  .loop
.fdw_nopad:
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop
.fdw_fast:
%ifdef WIN64_TARGET
    mov  rcx, rbx
%else
    mov  rdi, rbx
%endif
    call __io_print_int
    jmp  .loop

.fmt_s_w:
    mov  r14, [rsp + r13*8]
    inc  r13
    test r14, r14
    jz   .loop
    test r15, r15
    jz   .fsw_fast
%ifdef WIN64_TARGET
    mov  rcx, r14
%else
    mov  rdi, r14
%endif
    call __io_strlen            ; rax = length
    mov  rbx, r15               ; rbx = width
    sub  rbx, rax               ; rbx = pad
    jle  .fsw_fast
    cmp  byte [rel io_fmt_left], 1
    je   .fsw_left
    mov  r15, rbx
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, ' '
%else
    mov  rdi, r15
    mov  rsi, ' '
%endif
    call __io_write_n_char
%ifdef WIN64_TARGET
    mov  rcx, r14
%else
    mov  rdi, r14
%endif
    call __io_print_str_raw
    jmp  .loop
.fsw_left:
    mov  r15, rbx
%ifdef WIN64_TARGET
    mov  rcx, r14
%else
    mov  rdi, r14
%endif
    call __io_print_str_raw
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, ' '
%else
    mov  rdi, r15
    mov  rsi, ' '
%endif
    call __io_write_n_char
    jmp  .loop
.fsw_fast:
%ifdef WIN64_TARGET
    mov  rcx, r14
%else
    mov  rdi, r14
%endif
    call __io_print_str_raw
    jmp  .loop

.fmt_x_w:
    mov  rbx, [rsp + r13*8]
    inc  r13
    lea  r14, [rel io_tmp_nbuf + 47]
    mov  byte [r14], 0
    mov  rax, rbx
    test rax, rax
    jnz  .fxw_conv
    dec  r14
    mov  byte [r14], '0'
    jmp  .fxw_measure
.fxw_conv:
.fxw_loop:
    test rax, rax
    jz   .fxw_measure
    mov  rdx, rax
    and  rdx, 0xF
    cmp  dl, 10
    jl   .fxw_dig
    add  dl, 'a' - 10
    jmp  .fxw_st
.fxw_dig:
    add  dl, '0'
.fxw_st:
    dec  r14
    mov  [r14], dl
    shr  rax, 4
    jmp  .fxw_loop
.fxw_measure:
    lea  rax, [rel io_tmp_nbuf + 47]
    sub  rax, r14
    mov  rbx, rax               ; rbx = len
    test r15, r15
    jz   .fxw_nopad
    sub  r15, rbx
    jle  .fxw_nopad
    cmp  byte [rel io_fmt_left], 1
    je   .fxw_left
    cmp  byte [rel io_fmt_zero], 1
    je   .fxw_zpad
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, ' '
%else
    mov  rdi, r15
    mov  rsi, ' '
%endif
    call __io_write_n_char
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop
.fxw_zpad:
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, '0'
%else
    mov  rdi, r15
    mov  rsi, '0'
%endif
    call __io_write_n_char
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop
.fxw_left:
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, ' '
%else
    mov  rdi, r15
    mov  rsi, ' '
%endif
    call __io_write_n_char
    jmp  .loop
.fxw_nopad:
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop

.fmt_X_w:
    mov  rbx, [rsp + r13*8]
    inc  r13
    lea  r14, [rel io_tmp_nbuf + 47]
    mov  byte [r14], 0
    mov  rax, rbx
    test rax, rax
    jnz  .fXw_conv
    dec  r14
    mov  byte [r14], '0'
    jmp  .fXw_measure
.fXw_conv:
.fXw_loop:
    test rax, rax
    jz   .fXw_measure
    mov  rdx, rax
    and  rdx, 0xF
    cmp  dl, 10
    jl   .fXw_dig
    add  dl, 'A' - 10
    jmp  .fXw_st
.fXw_dig:
    add  dl, '0'
.fXw_st:
    dec  r14
    mov  [r14], dl
    shr  rax, 4
    jmp  .fXw_loop
.fXw_measure:
    lea  rax, [rel io_tmp_nbuf + 47]
    sub  rax, r14
    mov  rbx, rax
    test r15, r15
    jz   .fXw_nopad
    sub  r15, rbx
    jle  .fXw_nopad
    cmp  byte [rel io_fmt_left], 1
    je   .fXw_left
    cmp  byte [rel io_fmt_zero], 1
    je   .fXw_zpad
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, ' '
%else
    mov  rdi, r15
    mov  rsi, ' '
%endif
    call __io_write_n_char
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop
.fXw_zpad:
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, '0'
%else
    mov  rdi, r15
    mov  rsi, '0'
%endif
    call __io_write_n_char
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop
.fXw_left:
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, ' '
%else
    mov  rdi, r15
    mov  rsi, ' '
%endif
    call __io_write_n_char
    jmp  .loop
.fXw_nopad:
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop

.fmt_e:
    mov  rax, [rsp + r13*8]
    inc  r13
    movq xmm0, rax
    call __io_print_sci
    jmp  .loop

.fmt_prec:
    mov  [rel io_fmt_width], r15
    xor  r15, r15
.fmt_prec_digits:
    mov  al, [r12]
    test al, al
    jz   .done
    cmp  al, '0'
    jb   .fmt_prec_spec
    cmp  al, '9'
    ja   .fmt_prec_spec
    imul r15, r15, 10
    sub  al, '0'
    movzx rax, al
    add  r15, rax
    inc  r12
    jmp  .fmt_prec_digits

.fmt_prec_spec:
    mov  al, [r12]
    test al, al
    jz   .done
    inc  r12
    cmp  al, 'd'
    je   .fmt_d_prec
    cmp  al, 'i'
    je   .fmt_d_prec
    cmp  al, 'f'
    je   .fmt_f_prec
    cmp  al, 'g'
    je   .fmt_f_prec
    cmp  al, 'G'
    je   .fmt_f_prec
    jmp  .loop

.fmt_d_prec:
    mov  rbx, [rsp + r13*8]
    inc  r13
%ifdef WIN64_TARGET
    mov  rcx, rbx
    mov  rdx, r15
%else
    mov  rdi, rbx
    mov  rsi, r15
%endif
    call __io_print_int_zpad
    jmp  .loop

.fmt_f_prec:
    mov  rax, [rsp + r13*8]
    inc  r13
    movq xmm0, rax
%ifdef WIN64_TARGET
    mov  rcx, r15
%else
    mov  rdi, r15
%endif
    call __io_float_to_tmpbuf
    mov  r14, rax
    mov  r15, rdx
    mov  r10, [rel io_fmt_width]
    test r10, r10
    jz   .fmt_f_prec_print
    mov  rbx, r10
    sub  rbx, r15
    jle  .fmt_f_prec_print
    cmp  byte [rel io_fmt_left], 1
    je   .fmt_f_prec_left
    cmp  byte [rel io_fmt_zero], 1
    je   .fmt_f_prec_zero
%ifdef WIN64_TARGET
    mov  rcx, rbx
    mov  rdx, ' '
%else
    mov  rdi, rbx
    mov  rsi, ' '
%endif
    call __io_write_n_char
    jmp  .fmt_f_prec_print
.fmt_f_prec_zero:
%ifdef WIN64_TARGET
    mov  rcx, rbx
    mov  rdx, '0'
%else
    mov  rdi, rbx
    mov  rsi, '0'
%endif
    call __io_write_n_char
    jmp  .fmt_f_prec_print
.fmt_f_prec_left:
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, r15
    call __io_write_win
    mov  rcx, rbx
    mov  rdx, ' '
%else
    mov  rsi, r14
    mov  rdx, r15
    call __io_write_linux
    mov  rdi, rbx
    mov  rsi, ' '
%endif
    call __io_write_n_char
    jmp  .loop
.fmt_f_prec_print:
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, r15
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, r15
    call __io_write_linux
%endif
    jmp  .loop

.print_pct:
    mov  al, '%'
    jmp  .write_char

.fmt_d:
    mov  rbx, [rsp + r13*8]
    inc  r13
%ifdef WIN64_TARGET
    mov  rcx, rbx
%else
    mov  rdi, rbx
%endif
    call __io_print_int
    jmp  .loop

.fmt_s:
    mov  rbx, [rsp + r13*8]
    inc  r13
    test rbx, rbx
    jz   .loop
%ifdef WIN64_TARGET
    mov  rcx, rbx
%else
    mov  rdi, rbx
%endif
    call __io_print_str_raw
    jmp  .loop

.fmt_c:
    mov  rbx, [rsp + r13*8]
    inc  r13
    mov  byte [rel io_char_buf], bl
%ifdef WIN64_TARGET
    lea  rcx, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_linux
%endif
    jmp  .loop

.fmt_f:
    mov  rax, [rsp + r13*8]
    inc  r13
    movq xmm0, rax
    mov  r10, r15
    test r10, r10
    jnz  .fmt_f_width
    call __io_print_float
    jmp  .loop
.fmt_f_width:
%ifdef WIN64_TARGET
    mov  rcx, 6
%else
    mov  rdi, 6
%endif
    call __io_float_to_tmpbuf
    mov  r14, rax
    mov  r15, rdx
    test r10, r10
    jz   .fmt_f_print
    mov  rbx, r10
    sub  rbx, r15
    jle  .fmt_f_print
    cmp  byte [rel io_fmt_left], 1
    je   .fmt_f_left
    cmp  byte [rel io_fmt_zero], 1
    je   .fmt_f_zero
%ifdef WIN64_TARGET
    mov  rcx, rbx
    mov  rdx, ' '
%else
    mov  rdi, rbx
    mov  rsi, ' '
%endif
    call __io_write_n_char
    jmp  .fmt_f_print
.fmt_f_zero:
%ifdef WIN64_TARGET
    mov  rcx, rbx
    mov  rdx, '0'
%else
    mov  rdi, rbx
    mov  rsi, '0'
%endif
    call __io_write_n_char
    jmp  .fmt_f_print
.fmt_f_left:
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, r15
    call __io_write_win
    mov  rcx, rbx
    mov  rdx, ' '
%else
    mov  rsi, r14
    mov  rdx, r15
    call __io_write_linux
    mov  rdi, rbx
    mov  rsi, ' '
%endif
    call __io_write_n_char
    jmp  .loop
.fmt_f_print:
%ifdef WIN64_TARGET
    mov  rcx, r14
    mov  rdx, r15
    call __io_write_win
%else
    mov  rsi, r14
    mov  rdx, r15
    call __io_write_linux
%endif
    jmp  .loop

.fmt_b:
    mov  rbx, [rsp + r13*8]
    inc  r13
    test rbx, rbx
    jz   .fmt_b_false
%ifdef WIN64_TARGET
    lea  rcx, [rel io_poz_str]
%else
    lea  rdi, [rel io_poz_str]
%endif
    call __io_print_str_raw
    jmp  .loop
.fmt_b_false:
%ifdef WIN64_TARGET
    lea  rcx, [rel io_apuz_str]
%else
    lea  rdi, [rel io_apuz_str]
%endif
    call __io_print_str_raw
    jmp  .loop

.print_char:
.write_char:
    mov  [rel io_char_buf], al
%ifdef WIN64_TARGET
    lea  rcx, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_win
%else
    lea  rsi, [rel io_char_buf]
    mov  rdx, 1
    call __io_write_linux
%endif
    jmp  .loop

.fmt_x:
    mov  r14, [rsp + r13*8]
    inc  r13
    lea  r15, [rel io_num_buf + 31]
    mov  byte [r15], 0
    mov  rax, r14
    test rax, rax
    jnz  .hex_conv
    dec  r15
    mov  byte [r15], '0'
    jmp  .hex_print
.hex_conv:
    xor  rcx, rcx
.hex_loop:
    test rax, rax
    jz   .hex_print
    mov  rdx, rax
    and  rdx, 0xF
    cmp  dl, 10
    jl   .hex_is_digit
    add  dl, 'a' - 10
    jmp  .hex_store
.hex_is_digit:
    add  dl, '0'
.hex_store:
    dec  r15
    mov  [r15], dl
    shr  rax, 4
    jmp  .hex_loop
.hex_print:
    lea  rbx, [rel io_num_buf + 31]
    sub  rbx, r15
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r15
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop

.fmt_u:
    mov  r14, [rsp + r13*8]
    inc  r13
    lea  r15, [rel io_num_buf + 31]
    mov  byte [r15], 0
    mov  rax, r14
    test rax, rax
    jnz  .uint_conv
    dec  r15
    mov  byte [r15], '0'
    jmp  .uint_print
.uint_conv:
    mov  rcx, 10
.uint_loop:
    test rax, rax
    jz   .uint_print
    xor  rdx, rdx
    div  rcx
    dec  r15
    add  dl, '0'
    mov  [r15], dl
    jmp  .uint_loop
.uint_print:
    lea  rbx, [rel io_num_buf + 31]
    sub  rbx, r15
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r15
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop

.fmt_p:
    mov  r14, [rsp + r13*8]
    inc  r13
    ; print "0x" prefix
    push r14
%ifdef WIN64_TARGET
    lea  rcx, [rel io_fmt_0x]
    mov  rdx, 2
    call __io_write_win
%else
    lea  rsi, [rel io_fmt_0x]
    mov  rdx, 2
    call __io_write_linux
%endif
    pop  rax
    lea  r15, [rel io_num_buf + 31]
    mov  byte [r15], 0
    test rax, rax
    jnz  .ptr_conv
    dec  r15
    mov  byte [r15], '0'
    jmp  .ptr_print
.ptr_conv:
    xor  rcx, rcx
.ptr_loop:
    test rax, rax
    jz   .ptr_print
    mov  rdx, rax
    and  rdx, 0xF
    cmp  dl, 10
    jl   .ptr_is_digit
    add  dl, 'a' - 10
    jmp  .ptr_store
.ptr_is_digit:
    add  dl, '0'
.ptr_store:
    dec  r15
    mov  [r15], dl
    shr  rax, 4
    jmp  .ptr_loop
.ptr_print:
    lea  rbx, [rel io_num_buf + 31]
    sub  rbx, r15
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r15
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop

; -- %l / %L prefix: skip 'l'/'ll', then dispatch specifier -------
.fmt_l_prefix:
    mov  al, [r12]
    test al, al
    jz   .done
    inc  r12
    cmp  al, 'l'        ; second 'l' in 'll'?
    jne  .fmt_l_dispatch
    mov  al, [r12]
    test al, al
    jz   .done
    inc  r12
.fmt_l_dispatch:
    cmp  al, 'd'
    je   .fmt_d
    cmp  al, 'i'
    je   .fmt_d
    cmp  al, 'u'
    je   .fmt_u
    cmp  al, 'x'
    je   .fmt_x
    cmp  al, 'X'
    je   .fmt_x
    cmp  al, 'o'
    je   .fmt_o
    jmp  .loop

; -- %o: octal format ---------------------------------------------
.fmt_o:
    mov  r14, [rsp + r13*8]
    inc  r13
    lea  r15, [rel io_num_buf + 31]
    mov  byte [r15], 0
    mov  rax, r14
    test rax, rax
    jnz  .oct_conv
    dec  r15
    mov  byte [r15], '0'
    jmp  .oct_print
.oct_conv:
.oct_loop:
    xor  rdx, rdx
    mov  rcx, 8
    div  rcx
    dec  r15
    add  dl, '0'
    mov  [r15], dl
    test rax, rax
    jnz  .oct_loop
.oct_print:
    lea  rbx, [rel io_num_buf + 31]
    sub  rbx, r15
%ifdef WIN64_TARGET
    mov  rcx, r15
    mov  rdx, rbx
    call __io_write_win
%else
    mov  rsi, r15
    mov  rdx, rbx
    call __io_write_linux
%endif
    jmp  .loop

.done:
    xor  rax, rax
    add  rsp, 72
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__stdin (read line -> lafz pointer) -----------------
global io__stdin
io__stdin:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; ReadFile(stdin_handle, buf, len-1, &read, NULL)
    sub  rsp, 64
    push rbx
    push r12
    mov  rcx, -10        ; STD_INPUT_HANDLE
    call GetStdHandle
    mov  rbx, rax
    lea  r12, [rel io_inp_buf]
    sub  rsp, 8
    mov  qword [rsp], 0
    mov  rcx, rbx
    mov  rdx, r12
    mov  r8,  4095
    lea  r9,  [rsp]
    push qword 0
    call ReadFile
    mov  rax, [rsp + 8]  ; bytes read
    add  rsp, 16
    ; null-terminate, strip 


    lea  rbx, [rel io_inp_buf]
    mov  rcx, rax
    test rcx, rcx
    jz   .stdin_done_win
    dec  rcx
    mov  al, [rbx + rcx]
    cmp  al, 10
    je   .strip_lf_win
    inc  rcx
    jmp  .null_win
.strip_lf_win:
    test rcx, rcx
    jz   .null_win
    dec  rcx
    mov  al, [rbx + rcx]
    cmp  al, 13
    jne  .null_win_inc
    jmp  .null_win
.null_win_inc:
    inc  rcx
.null_win:
    mov  byte [rbx + rcx], 0
.stdin_done_win:
    lea  rax, [rel io_inp_buf]
    pop  r12
    pop  rbx
    add  rsp, 64
%else
    ; Linux: sys_read(0, buf, 4095)
    mov  rax, 0
    mov  rdi, 0
    lea  rsi, [rel io_inp_buf]
    mov  rdx, 4095
    syscall
    ; strip trailing 


    test rax, rax
    jle  .stdin_empty
    dec  rax
    lea  rdx, [rel io_inp_buf]
    mov  byte [rdx + rax], 0
.stdin_empty:
    lea  rax, [rel io_inp_buf]
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__input (deprecated: read integer) ------------------
global io__input
io__input:
    push rbp
    mov  rbp, rsp
    call io__stdin
    ; convert string to integer (simple atoi)
    mov  rbx, rax
    xor  rax, rax
    xor  rcx, rcx
    mov  cl, [rbx]
    test cl, cl
    jz   .inp_done
.inp_loop:
    mov  cl, [rbx]
    test cl, cl
    jz   .inp_done
    cmp  cl, '0'
    jl   .inp_done
    cmp  cl, '9'
    jg   .inp_done
    imul rax, rax, 10
    sub  cl, '0'
    add  rax, rcx
    inc  rbx
    jmp  .inp_loop
.inp_done:
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__open(path: lafz, mode: adad) -> adad ---------------
; mode:
;   0 = read
;   1 = write (create/truncate)
;   2 = append (create if missing)
global io__open
io__open:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; rcx = path, rdx = mode
    mov  r10, 0x80000000   ; GENERIC_READ
    mov  r11, 3            ; OPEN_EXISTING
    cmp  rdx, 1
    jne  .open_mode2_win
    mov  r10, 0x40000000   ; GENERIC_WRITE
    mov  r11, 2            ; CREATE_ALWAYS
    jmp  .open_cfg_done_win
.open_mode2_win:
    cmp  rdx, 2
    jne  .open_cfg_done_win
    mov  r10, 0x00000004   ; FILE_APPEND_DATA
    mov  r11, 4            ; OPEN_ALWAYS
.open_cfg_done_win:
    sub  rsp, 56
    mov  [rsp + 32], r11          ; dwCreationDisposition
    mov  qword [rsp + 40], 0x80   ; FILE_ATTRIBUTE_NORMAL
    mov  qword [rsp + 48], 0      ; hTemplateFile
    mov  rdx, r10                 ; dwDesiredAccess
    mov  r8,  3                   ; FILE_SHARE_READ | FILE_SHARE_WRITE
    xor  r9,  r9                  ; lpSecurityAttributes = NULL
    call CreateFileA
    add  rsp, 56
    cmp  rax, -1                  ; INVALID_HANDLE_VALUE
    jne  .open_done
    mov  rax, -1
%else
    ; rdi = path, rsi = mode
    ; Linux flags:
    ;   read   = 0
    ;   write  = O_WRONLY|O_CREAT|O_TRUNC  = 577
    ;   append = O_WRONLY|O_CREAT|O_APPEND = 1089
    cmp  rsi, 1
    jne  .open_mode2_linux
    mov  rsi, 577
    jmp  .open_linux_do
.open_mode2_linux:
    cmp  rsi, 2
    jne  .open_mode0_linux
    mov  rsi, 1089
    jmp  .open_linux_do
.open_mode0_linux:
    xor  rsi, rsi
.open_linux_do:
    mov  rax, 2            ; sys_open
    mov  rdx, 420          ; 0644
    syscall
%endif
.open_done:
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__close(fd_or_handle: adad) -> adad ------------------
global io__close
io__close:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; rcx = HANDLE
    sub  rsp, 32
    call CloseHandle
    add  rsp, 32
    test rax, rax
    jnz  .close_ok_win
    mov  rax, -1
    jmp  .close_done
.close_ok_win:
    xor  rax, rax
%else
    ; rdi = fd
    mov  rax, 3            ; sys_close
    syscall                ; returns 0 or -errno
%endif
.close_done:
    mov  rsp, rbp
    pop  rbp
    ret

global io__fopen
io__fopen:
    jmp  io__open

global io__fclose
io__fclose:
    jmp  io__close

; -- io__read(fd_or_handle: adad, buf: lafz, len: adad) -> adad
; Reads up to len bytes from fd into buf. Returns bytes read, or -1 on error.
global io__read
io__read:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; rcx=HANDLE, rdx=buf, r8=len
    sub  rsp, 48
    ; ReadFile(hFile, lpBuffer, nNumberOfBytesToRead, lpNumberOfBytesRead, NULL)
    ; We'll use r9 as the &bytesRead slot on the stack
    lea  r9, [rbp - 16]         ; lpNumberOfBytesRead
    mov  qword [rbp - 16], 0
    xor  rax, rax
    push rax                    ; NULL for lpOverlapped (5th arg via stack)
    call ReadFile
    add  rsp, 8
    add  rsp, 48
    test rax, rax
    jz   .read_err_win
    mov  rax, [rbp - 16]        ; bytes actually read
    jmp  .read_done
.read_err_win:
    mov  rax, -1
%else
    ; rdi=fd, rsi=buf, rdx=len
    mov  rax, 0                 ; sys_read
    syscall
%endif
.read_done:
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__write(fd_or_handle: adad, buf: lafz, len: adad) -> adad
; Writes len bytes from buf to fd. Returns bytes written, or -1 on error.
global io__write
io__write:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    ; rcx=HANDLE, rdx=buf, r8=len
    sub  rsp, 48
    lea  r9, [rbp - 16]
    mov  qword [rbp - 16], 0
    xor  rax, rax
    push rax
    call WriteFile
    add  rsp, 8
    add  rsp, 48
    test rax, rax
    jz   .write_err_win
    mov  rax, [rbp - 16]
    jmp  .write_done
.write_err_win:
    mov  rax, -1
%else
    ; rdi=fd, rsi=buf, rdx=len
    mov  rax, 1                 ; sys_write
    syscall
%endif
.write_done:
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__getchar() → adad (reads one byte from stdin, -1 on EOF) -----
global io__getchar
io__getchar:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 64
    push rbx
    push r12
    mov  rcx, -10        ; STD_INPUT_HANDLE
    call GetStdHandle
    mov  rbx, rax
    lea  r12, [rel io_char_buf]
    sub  rsp, 8
    mov  qword [rsp], 0
    mov  rcx, rbx
    mov  rdx, r12
    mov  r8,  1
    lea  r9,  [rsp]
    push qword 0
    call ReadFile
    mov  rax, [rsp + 8]
    add  rsp, 16
    test rax, rax
    jz   .gc_eof_win
    movzx rax, byte [r12]
    pop  r12
    pop  rbx
    add  rsp, 64
    mov  rsp, rbp
    pop  rbp
    ret
.gc_eof_win:
    mov  rax, -1
    pop  r12
    pop  rbx
    add  rsp, 64
%else
    lea  rsi, [rel io_char_buf]
    mov  rax, 0            ; sys_read
    mov  rdi, 0            ; stdin
    mov  rdx, 1
    syscall
    test rax, rax
    jle  .gc_eof
    movzx rax, byte [rel io_char_buf]
    mov  rsp, rbp
    pop  rbp
    ret
.gc_eof:
    mov  rax, -1
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__file_read(path: lafz) → lafz (contents in static buf, or "" on error)
global io__file_read
io__file_read:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
%ifdef WIN64_TARGET
    mov  r12, rcx           ; path
    sub  rsp, 56
    mov  rcx, r12
    mov  rdx, 0x80000000   ; GENERIC_READ
    mov  r8,  1             ; FILE_SHARE_READ
    xor  r9,  r9
    mov  qword [rsp + 32], 3   ; OPEN_EXISTING
    mov  qword [rsp + 40], 0x80
    mov  qword [rsp + 48], 0
    call CreateFileA
    add  rsp, 56
    cmp  rax, -1
    je   .fr_err_win
    mov  rbx, rax           ; rbx = handle
    sub  rsp, 24
    mov  qword [rsp], 0
    mov  rcx, rbx
    lea  rdx, [rel io_file_buf]
    mov  r8,  1048575
    lea  r9,  [rsp]
    push qword 0
    call ReadFile
    mov  r12, [rsp + 8]     ; bytes read
    add  rsp, 16
    mov  byte [rel io_file_buf + r12], 0
    mov  rcx, rbx
    call CloseHandle
    lea  rax, [rel io_file_buf]
    jmp  .fr_done_win
.fr_err_win:
    lea  rax, [rel io_file_buf]
    mov  byte [rax], 0
.fr_done_win:
    add  rsp, 8
%else
    mov  r12, rdi           ; path
    mov  rax, 2             ; sys_open
    mov  rdi, r12
    xor  rsi, rsi           ; O_RDONLY
    xor  rdx, rdx
    syscall
    test rax, rax
    js   .fr_err
    mov  rbx, rax           ; fd
    mov  rax, 0             ; sys_read
    mov  rdi, rbx
    lea  rsi, [rel io_file_buf]
    mov  rdx, 1048575
    syscall
    mov  r12, rax
    test r12, r12
    js   .fr_read_err
    mov  byte [rel io_file_buf + r12], 0
    mov  rax, 3             ; sys_close
    mov  rdi, rbx
    syscall
    lea  rax, [rel io_file_buf]
    jmp  .fr_done
.fr_read_err:
    mov  rax, 3
    mov  rdi, rbx
    syscall
.fr_err:
    lea  rax, [rel io_file_buf]
    mov  byte [rax], 0
.fr_done:
%endif
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__file_write(path: lafz, content: lafz) → adad (0=ok, -1=error)
global io__file_write
io__file_write:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  r12, rcx           ; path
    mov  r13, rdx           ; content
    sub  rsp, 56
    mov  rcx, r12
    mov  rdx, 0x40000000   ; GENERIC_WRITE
    mov  r8,  0
    xor  r9,  r9
    mov  qword [rsp + 32], 2  ; CREATE_ALWAYS
    mov  qword [rsp + 40], 0x80
    mov  qword [rsp + 48], 0
    call CreateFileA
    add  rsp, 56
    cmp  rax, -1
    je   .fw_err_win
    mov  rbx, rax
    ; measure content length
    mov  rcx, r13
    call __io_strlen
    mov  r12, rax           ; length
    sub  rsp, 24
    mov  qword [rsp], 0
    mov  rcx, rbx
    mov  rdx, r13
    mov  r8,  r12
    lea  r9,  [rsp]
    push qword 0
    call WriteFile
    add  rsp, 16
    mov  rcx, rbx
    call CloseHandle
    xor  rax, rax
    jmp  .fw_done_win
.fw_err_win:
    mov  rax, -1
.fw_done_win:
    add  rsp, 8
%else
    mov  r12, rdi           ; path
    mov  r13, rsi           ; content
    mov  rax, 2             ; sys_open
    mov  rdi, r12
    mov  rsi, 577           ; O_WRONLY|O_CREAT|O_TRUNC
    mov  rdx, 420           ; 0644
    syscall
    test rax, rax
    js   .fw_err
    mov  rbx, rax           ; fd
    mov  rdi, r13
    call __io_strlen        ; rax = content length
    mov  r12, rax
    mov  rax, 1             ; sys_write
    mov  rdi, rbx
    mov  rsi, r13
    mov  rdx, r12
    syscall
    push rax
    mov  rax, 3             ; sys_close
    mov  rdi, rbx
    syscall
    pop  rax
    test rax, rax
    js   .fw_err
    xor  rax, rax
    jmp  .fw_done
.fw_err:
    mov  rax, -1
.fw_done:
%endif
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__file_exists(path: lafz) → adad (1=exists, 0=not)
global io__file_exists
io__file_exists:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 56
    mov  rdx, 0x80000000
    mov  r8,  1
    xor  r9,  r9
    mov  qword [rsp + 32], 3   ; OPEN_EXISTING
    mov  qword [rsp + 40], 0x80
    mov  qword [rsp + 48], 0
    call CreateFileA
    add  rsp, 56
    cmp  rax, -1
    je   .fex_no
    push rax
    mov  rcx, rax
    call CloseHandle
    pop  rax
    mov  rax, 1
    jmp  .fex_done
.fex_no:
    xor  rax, rax
.fex_done:
%else
    mov  rax, 21            ; sys_access
    xor  rsi, rsi           ; F_OK
    syscall
    test rax, rax
    setz al
    movzx rax, al
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__file_delete(path: lafz) → adad (0=ok, -1=error)
global io__file_delete
io__file_delete:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    call DeleteFileA
    xor  rdx, rdx
    test rax, rax
    setz dl
    lea  rax, [rdx - 1]    ; 0→-1 if failed, else 0
    not  rax
    and  rax, rdx
    ; simpler: if DeleteFileA returns nonzero → success(0), else -1
    mov  rax, rcx           ; was already clobbered, redo
    sub  rsp, 40
    call DeleteFileA
    add  rsp, 40
    test rax, rax
    jnz  .fdel_ok
    mov  rax, -1
    jmp  .fdel_done
.fdel_ok:
    xor  rax, rax
.fdel_done:
%else
    mov  rax, 87            ; sys_unlink
    syscall
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; -- io__file_append(path: lafz, content: lafz) → adad (0=ok, -1=error)
global io__file_append
io__file_append:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  r12, rcx
    mov  r13, rdx
    sub  rsp, 56
    mov  rcx, r12
    mov  rdx, 0x00100004   ; FILE_APPEND_DATA
    mov  r8,  1
    xor  r9,  r9
    mov  qword [rsp + 32], 4   ; OPEN_ALWAYS
    mov  qword [rsp + 40], 0x80
    mov  qword [rsp + 48], 0
    call CreateFileA
    add  rsp, 56
    cmp  rax, -1
    je   .fa_err_win
    mov  rbx, rax
    mov  rcx, r13
    call __io_strlen
    mov  r12, rax
    sub  rsp, 24
    mov  qword [rsp], 0
    mov  rcx, rbx
    mov  rdx, r13
    mov  r8,  r12
    lea  r9,  [rsp]
    push qword 0
    call WriteFile
    add  rsp, 16
    mov  rcx, rbx
    call CloseHandle
    xor  rax, rax
    jmp  .fa_done_win
.fa_err_win:
    mov  rax, -1
.fa_done_win:
    add  rsp, 8
%else
    mov  r12, rdi
    mov  r13, rsi
    mov  rax, 2             ; sys_open
    mov  rdi, r12
    mov  rsi, 1089          ; O_WRONLY|O_CREAT|O_APPEND
    mov  rdx, 420           ; 0644
    syscall
    test rax, rax
    js   .fa_err
    mov  rbx, rax
    mov  rdi, r13
    call __io_strlen
    mov  r12, rax
    mov  rax, 1             ; sys_write
    mov  rdi, rbx
    mov  rsi, r13
    mov  rdx, r12
    syscall
    push rax
    mov  rax, 3
    mov  rdi, rbx
    syscall
    pop  rax
    test rax, rax
    js   .fa_err
    xor  rax, rax
    jmp  .fa_done
.fa_err:
    mov  rax, -1
.fa_done:
%endif
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret
