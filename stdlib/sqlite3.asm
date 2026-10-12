; =============================================================================
; Velocity Standard Library — SQLite3 Native Bindings (sqlite3.asm)
; Kashmiri Edition v2 - Cross-platform (Linux ELF64 + Windows Win64)
;
; Complete re-entrant bindings for SQLite3 embedded relational database engine.
; =============================================================================

default rel

%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

%ifdef WIN64_TARGET
  %macro VL_CALL 1
    push rbp
    mov  rbp, rsp
    sub  rsp, 8
    and  rsp, -16
    sub  rsp, 32
    call %1
    mov  rsp, rbp
    pop  rbp
    ret
  %endmacro
%else
  %macro VL_CALL 1
    push rbp
    mov  rbp, rsp
    sub  rsp, 8
    and  rsp, -16
    call %1
    mov  rsp, rbp
    pop  rbp
    ret
  %endmacro
%endif

extern sqlite3_open
extern sqlite3_open_v2
extern sqlite3_close
extern sqlite3_close_v2
extern sqlite3_exec
extern sqlite3_prepare_v2
extern sqlite3_step
extern sqlite3_reset
extern sqlite3_finalize
extern sqlite3_column_count
extern sqlite3_column_name
extern sqlite3_column_type
extern sqlite3_column_int64
extern sqlite3_column_text
extern sqlite3_column_double
extern sqlite3_column_bytes
extern sqlite3_bind_int64
extern sqlite3_bind_text
extern sqlite3_bind_double
extern sqlite3_bind_null
extern sqlite3_clear_bindings
extern sqlite3_errmsg
extern sqlite3_errcode
extern sqlite3_changes
extern sqlite3_total_changes
extern sqlite3_last_insert_rowid
extern sqlite3_libversion

section .text

; ---- Database Connection ----

global sqlite3__open
sqlite3__open:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    sub  rsp, 48
    mov  qword [rbp - 8], 0
    lea  rdx, [rbp - 8]      ; rdx = &ppDb
    call sqlite3_open
    test eax, eax
    jnz  .open_err_win
    mov  rax, [rbp - 8]
    leave
    ret
.open_err_win:
    xor  rax, rax
    leave
    ret
%else
    push rbp
    mov  rbp, rsp
    sub  rsp, 16
    mov  qword [rsp], 0      ; *ppDb = NULL
    lea  rsi, [rsp]          ; rsi = &ppDb
    call sqlite3_open
    test eax, eax
    jnz  .open_err_sysv
    mov  rax, [rsp]          ; return sqlite3* pointer
    leave
    ret
.open_err_sysv:
    xor  rax, rax
    leave
    ret
%endif

global sqlite3__open_v2
sqlite3__open_v2:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    sub  rsp, 48
    mov  qword [rbp - 8], 0
    mov  r8, rdx
    lea  rdx, [rbp - 8]
    mov  qword [rsp + 32], 0
    call sqlite3_open_v2
    test eax, eax
    jnz  .open_v2_err_win
    mov  rax, [rbp - 8]
    leave
    ret
.open_v2_err_win:
    xor  rax, rax
    leave
    ret
%else
    push rbp
    mov  rbp, rsp
    sub  rsp, 16
    mov  qword [rsp], 0
    mov  rdx, rsi
    lea  rsi, [rsp]
    xor  rcx, rcx
    call sqlite3_open_v2
    test eax, eax
    jnz  .open_v2_err_sysv
    mov  rax, [rsp]
    leave
    ret
.open_v2_err_sysv:
    xor  rax, rax
    leave
    ret
%endif

global sqlite3__close
sqlite3__close:               VL_CALL sqlite3_close

global sqlite3__close_v2
sqlite3__close_v2:            VL_CALL sqlite3_close_v2

; ---- Statement Execution ----

global sqlite3__exec
sqlite3__exec:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    sub  rsp, 48
    xor  r8,  r8             ; callback = NULL
    xor  r9,  r9             ; callback arg = NULL
    mov  qword [rsp + 32], 0 ; errmsg = NULL
    call sqlite3_exec
    leave
    ret
%else
    push rbp
    mov  rbp, rsp
    sub  rsp, 16
    xor  rdx, rdx            ; callback = NULL
    xor  rcx, rcx            ; callback arg = NULL
    xor  r8,  r8             ; errmsg = NULL
    call sqlite3_exec
    leave
    ret
%endif

; ---- Prepared Statements ----

global sqlite3__prepare
sqlite3__prepare:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    sub  rsp, 48
    mov  qword [rbp - 8], 0
    mov  r8, -1              ; nByte = -1
    lea  r9, [rbp - 8]       ; ppStmt = &stmt
    mov  qword [rsp + 32], 0
    call sqlite3_prepare_v2
    test eax, eax
    jnz  .prep_err_win
    mov  rax, [rbp - 8]
    leave
    ret
.prep_err_win:
    xor  rax, rax
    leave
    ret
%else
    push rbp
    mov  rbp, rsp
    sub  rsp, 16
    mov  qword [rsp], 0
    mov  rdx, -1             ; nByte = -1
    lea  rcx, [rsp]          ; ppStmt = &stmt
    xor  r8,  r8
    call sqlite3_prepare_v2
    test eax, eax
    jnz  .prep_err_sysv
    mov  rax, [rsp]
    leave
    ret
.prep_err_sysv:
    xor  rax, rax
    leave
    ret
%endif

global sqlite3__step
sqlite3__step:                VL_CALL sqlite3_step

global sqlite3__reset
sqlite3__reset:               VL_CALL sqlite3_reset

global sqlite3__finalize
sqlite3__finalize:            VL_CALL sqlite3_finalize

; ---- Column Accessors ----

global sqlite3__column_count
sqlite3__column_count:        VL_CALL sqlite3_column_count

global sqlite3__column_name
sqlite3__column_name:         VL_CALL sqlite3_column_name

global sqlite3__column_type
sqlite3__column_type:         VL_CALL sqlite3_column_type

global sqlite3__column_int
sqlite3__column_int:          VL_CALL sqlite3_column_int64

global sqlite3__column_text
sqlite3__column_text:         VL_CALL sqlite3_column_text

global sqlite3__column_float
sqlite3__column_float:        VL_CALL sqlite3_column_double

global sqlite3__column_bytes
sqlite3__column_bytes:        VL_CALL sqlite3_column_bytes

; ---- Parameter Binding ----

global sqlite3__bind_int
sqlite3__bind_int:            VL_CALL sqlite3_bind_int64

global sqlite3__bind_text
sqlite3__bind_text:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    sub  rsp, 48
    mov  r9, -1
    mov  qword [rsp + 32], -1 ; SQLITE_TRANSIENT = -1
    call sqlite3_bind_text
    leave
    ret
%else
    push rbp
    mov  rbp, rsp
    sub  rsp, 16
    mov  rcx, -1
    mov  r8,  -1             ; SQLITE_TRANSIENT = -1
    call sqlite3_bind_text
    leave
    ret
%endif

global sqlite3__bind_float
sqlite3__bind_float:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    sub  rsp, 32
    movq xmm2, r8
    call sqlite3_bind_double
    leave
    ret
%else
    push rbp
    mov  rbp, rsp
    sub  rsp, 16
    movq xmm0, rdx
    call sqlite3_bind_double
    leave
    ret
%endif

global sqlite3__bind_null
sqlite3__bind_null:           VL_CALL sqlite3_bind_null

global sqlite3__clear_bindings
sqlite3__clear_bindings:      VL_CALL sqlite3_clear_bindings

; ---- Metadata & Status ----

global sqlite3__errmsg
sqlite3__errmsg:              VL_CALL sqlite3_errmsg

global sqlite3__errcode
sqlite3__errcode:             VL_CALL sqlite3_errcode

global sqlite3__changes
sqlite3__changes:             VL_CALL sqlite3_changes

global sqlite3__total_changes
sqlite3__total_changes:       VL_CALL sqlite3_total_changes

global sqlite3__last_insert_rowid
sqlite3__last_insert_rowid:   VL_CALL sqlite3_last_insert_rowid

global sqlite3__libversion
sqlite3__libversion:          VL_CALL sqlite3_libversion
