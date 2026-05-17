; ============================================================
; Velocity StdLib - Time Module (time.asm) v0.3.0
; Windows + Linux dual-mode
;
; Functions:
;   time__now       -> adad (Unix seconds)
;   time__now_ms    -> adad (milliseconds)
;   time__now_ns    -> adad (nanoseconds)
;   time__sleep(ms) -> adad
;   time__ctime()   -> lafz  "YYYY-MM-DD HH:MM:SS" (UTC)
; ============================================================

%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

section .bss
    time_ts      resq 2     ; {sec, nsec}
    time_ctime   resb 32
    sleep_ts     resq 2

section .data
    time_mdays   db 31,28,31,30,31,30,31,31,30,31,30,31
    time_unix_epoch_100ns dq 116444736000000000

section .text

; -------------------------------------------------------
; time__now() -> adad (seconds since epoch)
; -------------------------------------------------------
global time__now
time__now:
%ifdef WIN64_TARGET
    sub  rsp, 40
    lea  rcx, [rel time_ts]
    call GetSystemTimeAsFileTime
    add  rsp, 40
    mov  rax, [rel time_ts]
    mov  r10, [rel time_unix_epoch_100ns]
    sub  rax, r10
    mov  rcx, 10000000
    xor  rdx, rdx
    div  rcx
    ret
%else
    mov  rax, 228               ; clock_gettime
    xor  rdi, rdi               ; CLOCK_REALTIME = 0
    lea  rsi, [rel time_ts]
    syscall
    mov  rax, [rel time_ts]     ; seconds
    ret
%endif

; -------------------------------------------------------
; time__now_ms() -> adad (milliseconds since epoch)
; -------------------------------------------------------
global time__now_ms
time__now_ms:
%ifdef WIN64_TARGET
    sub  rsp, 40
    lea  rcx, [rel time_ts]
    call GetSystemTimeAsFileTime
    add  rsp, 40
    mov  rax, [rel time_ts]
    mov  r10, [rel time_unix_epoch_100ns]
    sub  rax, r10
    mov  rcx, 10000
    xor  rdx, rdx
    div  rcx
    ret
%else
    mov  rax, 228
    xor  rdi, rdi
    lea  rsi, [rel time_ts]
    syscall
    mov  rax, [rel time_ts]
    mov  rbx, 1000
    mul  rbx
    mov  rcx, rax
    mov  rax, [rel time_ts + 8]
    mov  rbx, 1000000
    xor  rdx, rdx
    div  rbx
    add  rax, rcx
    ret
%endif

; -------------------------------------------------------
; time__now_ns() -> adad (nanoseconds since epoch)
; -------------------------------------------------------
global time__now_ns
time__now_ns:
%ifdef WIN64_TARGET
    sub  rsp, 40
    lea  rcx, [rel time_ts]
    call GetSystemTimeAsFileTime
    add  rsp, 40
    mov  rax, [rel time_ts]
    mov  r10, [rel time_unix_epoch_100ns]
    sub  rax, r10
    mov  rcx, 100
    mul  rcx
    ret
%else
    mov  rax, 228
    xor  rdi, rdi
    lea  rsi, [rel time_ts]
    syscall
    mov  rax, [rel time_ts]
    mov  rbx, 1000000000
    mul  rbx
    add  rax, [rel time_ts + 8]
    ret
%endif

; -------------------------------------------------------
; time__sleep(ms: adad) -> adad
; -------------------------------------------------------
global time__sleep
time__sleep:
%ifdef WIN64_TARGET
    sub  rsp, 40
    call Sleep
    add  rsp, 40
    xor  rax, rax
    ret
%else
    push rbp
    mov  rbp, rsp
    mov  rax, rdi
    xor  rdx, rdx
    mov  rcx, 1000
    div  rcx                  ; rax=sec, rdx=remainder ms
    mov  [rel sleep_ts],     rax
    imul rdx, rdx, 1000000
    mov  [rel sleep_ts + 8], rdx
    mov  rax, 35              ; sys_nanosleep
    lea  rdi, [rel sleep_ts]
    xor  rsi, rsi
    syscall
    xor  rax, rax
    pop  rbp
    ret
%endif

; -------------------------------------------------------
; time__ctime() -> lafz  "YYYY-MM-DD HH:MM:SS" UTC
;
; Clean implementation using Howard Hinnant's civil_from_days.
; All values pinned in registers — no mid-algorithm stack thrash.
;
; Register map (callee-saved pinned throughout):
;   r12 = hour
;   r13 = minute
;   r14 = second
;   r15 = era  →  year (after final adjustment)
;
; Scratch (caller-saved, stable since we make only one call at top):
;   r8  = days_since_epoch (input to date calc)
;   r9  = doe  (day-of-era)
;   r10 = yoe  (year-of-era)
;   r11 = doy  (day-of-year, March-based)
;   rbx = mp   →  month (1-12)
;   rcx = day  (1-31)
;   rdi = write pointer into time_ctime buffer
;
; Stack usage: 1 push/pop for the bracket sub-expression only.
; -------------------------------------------------------
global time__ctime
time__ctime:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 8         ; align: 6 regs × 8 + 8 = 56 bytes pushed → RSP 16-aligned

    call time__now      ; rax = Unix seconds (UTC)

    ; ---- time-of-day decomposition ----
    ; days = rax / 86400,  sec_of_day = rax % 86400
    xor  rdx, rdx
    mov  rcx, 86400
    div  rcx            ; rax = days_since_epoch, rdx = sec_of_day
    mov  r8, rax        ; r8 = days_since_epoch

    ; hour = sec_of_day / 3600
    mov  rax, rdx
    xor  rdx, rdx
    mov  rcx, 3600
    div  rcx            ; rax = hour, rdx = hrem
    mov  r12, rax       ; r12 = hour

    ; minute = hrem / 60,  second = hrem % 60
    mov  rax, rdx
    xor  rdx, rdx
    mov  rcx, 60
    div  rcx            ; rax = minute, rdx = second
    mov  r13, rax       ; r13 = minute
    mov  r14, rdx       ; r14 = second

    ; ---- Hinnant civil_from_days ----
    ; z = days + 719468
    mov  rax, r8
    add  rax, 719468

    ; era = z / 146097,  doe = z % 146097
    xor  rdx, rdx
    mov  rcx, 146097
    div  rcx
    mov  r15, rax       ; r15 = era
    mov  r9,  rdx       ; r9  = doe

    ; yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365
    mov  rax, r9
    xor  rdx, rdx
    mov  rcx, 1460
    div  rcx
    mov  r10, r9
    sub  r10, rax       ; doe - doe/1460

    mov  rax, r9
    xor  rdx, rdx
    mov  rcx, 36524
    div  rcx
    add  r10, rax       ; + doe/36524

    mov  rax, r9
    xor  rdx, rdx
    mov  rcx, 146096
    div  rcx
    sub  r10, rax       ; - doe/146096

    mov  rax, r10
    xor  rdx, rdx
    mov  rcx, 365
    div  rcx
    mov  r10, rax       ; r10 = yoe

    ; bracket = 365*yoe + yoe/4 - yoe/100
    mov  rax, r10
    imul rax, 365       ; 365*yoe
    mov  rcx, r10
    shr  rcx, 2
    add  rax, rcx       ; + yoe/4
    push rax            ; save partial (only push in body)
    mov  rax, r10
    xor  rdx, rdx
    mov  rcx, 100
    div  rcx            ; rax = yoe/100
    pop  r11            ; r11 = 365*yoe + yoe/4
    sub  r11, rax       ; r11 = bracket

    ; doy = doe - bracket  (r9 = doe, r11 = bracket)
    mov  rax, r9
    sub  rax, r11
    mov  r11, rax       ; r11 = doy

    ; mp = (5*doy + 2) / 153
    mov  rax, r11
    imul rax, 5
    add  rax, 2
    xor  rdx, rdx
    mov  rcx, 153
    div  rcx
    mov  rbx, rax       ; rbx = mp

    ; day = doy - (153*mp+2)/5 + 1
    mov  rax, rbx
    imul rax, 153
    add  rax, 2
    xor  rdx, rdx
    mov  rcx, 5
    div  rcx            ; rax = (153*mp+2)/5
    mov  rcx, r11
    sub  rcx, rax
    inc  rcx            ; rcx = day (1-based)

    ; month = mp < 10 ? mp+3 : mp-9
    mov  rax, rbx       ; rax = mp
    cmp  rax, 10
    jl   .mp_lt10
    sub  rax, 9
    jmp  .mp_done
.mp_lt10:
    add  rax, 3
.mp_done:
    ; rax = month (1-12)

    ; year = era*400 + yoe + (mp >= 10 ? 1 : 0)
    ; Temporarily save month and day so we can compute year
    push rcx            ; save day
    push rax            ; save month
    mov  rax, r15       ; era
    imul rax, 400
    add  rax, r10       ; + yoe
    cmp  rbx, 10        ; mp >= 10 means Jan or Feb → +1 year
    jl   .no_year_adj
    inc  rax
.no_year_adj:
    mov  r15, rax       ; r15 = year
    pop  rbx            ; rbx = month
    pop  rcx            ; rcx = day

    ; ---- Format "YYYY-MM-DD HH:MM:SS\0" into time_ctime ----
    lea  rdi, [rel time_ctime]

    ; Year (4 digits) from r15
    mov  rax, r15
    xor  rdx, rdx
    mov  r9, 1000
    div  r9
    add  al, '0'
    mov  [rdi], al
    inc  rdi

    mov  rax, rdx
    xor  rdx, rdx
    mov  r9, 100
    div  r9
    add  al, '0'
    mov  [rdi], al
    inc  rdi

    mov  rax, rdx
    xor  rdx, rdx
    mov  r9, 10
    div  r9
    add  al, '0'
    mov  [rdi], al
    inc  rdi
    add  dl, '0'
    mov  [rdi], dl
    inc  rdi

    mov  byte [rdi], '-'
    inc  rdi

    ; Month (2 digits) from rbx
    mov  rax, rbx
    xor  rdx, rdx
    mov  r9, 10
    div  r9
    add  al, '0'
    mov  [rdi], al
    inc  rdi
    add  dl, '0'
    mov  [rdi], dl
    inc  rdi

    mov  byte [rdi], '-'
    inc  rdi

    ; Day (2 digits) from rcx
    mov  rax, rcx
    xor  rdx, rdx
    mov  r9, 10
    div  r9
    add  al, '0'
    mov  [rdi], al
    inc  rdi
    add  dl, '0'
    mov  [rdi], dl
    inc  rdi

    mov  byte [rdi], ' '
    inc  rdi

    ; Hour (2 digits) from r12
    mov  rax, r12
    xor  rdx, rdx
    mov  r9, 10
    div  r9
    add  al, '0'
    mov  [rdi], al
    inc  rdi
    add  dl, '0'
    mov  [rdi], dl
    inc  rdi

    mov  byte [rdi], ':'
    inc  rdi

    ; Minute (2 digits) from r13
    mov  rax, r13
    xor  rdx, rdx
    mov  r9, 10
    div  r9
    add  al, '0'
    mov  [rdi], al
    inc  rdi
    add  dl, '0'
    mov  [rdi], dl
    inc  rdi

    mov  byte [rdi], ':'
    inc  rdi

    ; Second (2 digits) from r14
    mov  rax, r14
    xor  rdx, rdx
    mov  r9, 10
    div  r9
    add  al, '0'
    mov  [rdi], al
    inc  rdi
    add  dl, '0'
    mov  [rdi], dl
    inc  rdi

    mov  byte [rdi], 0  ; null terminator

    lea  rax, [rel time_ctime]

    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    ret

%ifdef WIN64_TARGET
extern GetSystemTimeAsFileTime
extern Sleep
%endif
