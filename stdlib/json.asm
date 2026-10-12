; ================================================================
; Velocity StdLib -- JSON Module (json.asm) v1.0
; Linux x86-64 + Windows x64 + AArch64 Android/Linux
;
; Provides a full recursive-descent JSON parser returning a
; heap-allocated node tree (JsonNode).
;
; ── JsonNode layout (64 bytes, all 8-byte fields) ─────────────
;   [+0]  type:        adad  (1=string 2=number 3=bool 4=null
;                              5=array  6=object)
;   [+8]  sval:        adad  (lafz ptr: string/number/bool text)
;   [+16] children:    adad  (adad* array of child JsonNode ptrs)
;   [+24] child_count: adad
;   [+32] child_cap:   adad
;   [+40] keys:        adad  (lafz* array, parallel to children,
;                              used by objects for key names)
;   [+48] key_count:   adad
;   [+56] _pad:        adad
;
; ── DOM API ───────────────────────────────────────────────────
;   json__parse(src)          -> adad  (JsonNode* root or 0)
;   json__free(node)          -> adad  (free entire tree)
;   json__type(node)          -> adad  (1-6)
;   json__str(node)           -> lafz  (sval or "")
;   json__get(node, key)      -> adad  (child by key, or 0)
;   json__item(node, i)       -> adad  (array/object child by index)
;   json__len(node)           -> adad  (child count)
;   json__key(node, i)        -> lafz  (i-th key name)
;   json__is_str(node)        -> adad
;   json__is_num(node)        -> adad
;   json__is_bool(node)       -> adad
;   json__is_null(node)       -> adad
;   json__is_array(node)      -> adad
;   json__is_object(node)     -> adad
;   json__stringify(node)     -> lafz  (node -> JSON string, static 64KB buf)
; ================================================================

%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

%ifndef AARCH64_TARGET
default rel
%endif

; ── calling convention aliases ───────────────────────────────
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

; ── JsonNode field offsets ────────────────────────────────────
%define JN_TYPE        0
%define JN_SVAL        8
%define JN_CHILDREN    16
%define JN_CHILD_COUNT 24
%define JN_CHILD_CAP   32
%define JN_KEYS        40
%define JN_KEY_COUNT   48
%define JN_SIZE        64

; ── JSON types ────────────────────────────────────────────────
%define JT_STRING  1
%define JT_NUMBER  2
%define JT_BOOL    3
%define JT_NULL    4
%define JT_ARRAY   5
%define JT_OBJECT  6

; ── Initial capacities ────────────────────────────────────────
%define JN_INIT_CAP 4

; ================================================================
; Externals
; ================================================================
extern malloc
extern calloc
extern realloc
extern free
extern memory__strlen
extern memory__strcpy
extern memory__strcmp

; ================================================================
section .data
; ================================================================
json_empty_str  db 0
json_true_str   db "true", 0
json_false_str  db "false", 0
json_null_str   db "null", 0

; stringify literals
json_s_quote    db 0x22, 0          ; "
json_s_comma    db ",", 0
json_s_colon    db ":", 0
json_s_lbrace   db "{", 0
json_s_rbrace   db "}", 0
json_s_lbracket db "[", 0
json_s_rbracket db "]", 0
json_s_true     db "true", 0
json_s_false    db "false", 0
json_s_null     db "null", 0
json_s_bs_n     db "\\n", 0
json_s_bs_t     db "\\t", 0
json_s_bs_r     db "\\r", 0
json_s_bs_bs    db "\\\\", 0
json_s_bs_q     db "\\", 0x22, 0

; ================================================================
section .bss
; ================================================================
; parser state
json_ps_src     resq 1
json_ps_pos     resq 1
json_ps_err     resb 1

; stringify buffer
json_str_buf    resb 65536
json_str_ptr    resq 1

; ================================================================
section .text
; ================================================================

; ──────────────────────────────────────────────────────────────
; INTERNAL HELPERS
; ──────────────────────────────────────────────────────────────

; json_strdup(src: ARG1) -> rax
json_strdup:
    push rbp
    mov  rbp, rsp
    push rbx
%ifdef WIN64_TARGET
    mov  rbx, rcx
%else
    mov  rbx, rdi
%endif
    test rbx, rbx
    jz   .sd_null
%ifdef WIN64_TARGET
    mov  rcx, rbx
    sub  rsp, 32
    call memory__strlen
    add  rsp, 32
%else
    mov  rdi, rbx
    call memory__strlen
%endif
    inc  rax
%ifdef WIN64_TARGET
    mov  rcx, rax
    sub  rsp, 32
    call malloc
    add  rsp, 32
%else
    mov  rdi, rax
    call malloc
%endif
    test rax, rax
    jz   .sd_ret
    push rax
%ifdef WIN64_TARGET
    mov  rcx, rax
    mov  rdx, rbx
    sub  rsp, 32
    call memory__strcpy
    add  rsp, 32
%else
    mov  rdi, rax
    mov  rsi, rbx
    call memory__strcpy
%endif
    pop  rax
    jmp  .sd_ret
.sd_null:
    xor  rax, rax
.sd_ret:
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; json_alloc_node() -> rax  (zeroed JN_SIZE bytes)
json_alloc_node:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    mov  rcx, 1
    mov  rdx, JN_SIZE
    call calloc
    add  rsp, 32
%else
    mov  rdi, 1
    mov  rsi, JN_SIZE
    call calloc
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; json_node_add_child(parent: rdi/rcx, child: rsi/rdx)
json_node_add_child:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
%ifdef WIN64_TARGET
    mov  rbx, rcx
    mov  r12, rdx
%else
    mov  rbx, rdi
    mov  r12, rsi
%endif
    mov  rax, [rbx + JN_CHILD_COUNT]
    mov  rcx, [rbx + JN_CHILD_CAP]
    cmp  rax, rcx
    jl   .nac_store
    test rcx, rcx
    jnz  .nac_grow
    mov  rcx, JN_INIT_CAP
    jmp  .nac_alloc
.nac_grow:
    shl  rcx, 1
.nac_alloc:
    mov  [rbx + JN_CHILD_CAP], rcx
    mov  rdx, rcx
    shl  rdx, 3
%ifdef WIN64_TARGET
    mov  rcx, [rbx + JN_CHILDREN]
    sub  rsp, 32
    call realloc
    add  rsp, 32
%else
    mov  rdi, [rbx + JN_CHILDREN]
    mov  rsi, rdx
    call realloc
%endif
    test rax, rax
    jz   .nac_ret
    mov  [rbx + JN_CHILDREN], rax
.nac_store:
    mov  rax, [rbx + JN_CHILDREN]
    mov  rcx, [rbx + JN_CHILD_COUNT]
    mov  [rax + rcx*8], r12
    inc  qword [rbx + JN_CHILD_COUNT]
.nac_ret:
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; json_node_add_key(parent: rdi/rcx, key: rsi/rdx)
; appends a strdup'd key string to the keys array (parallel to children)
json_node_add_key:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
%ifdef WIN64_TARGET
    mov  rbx, rcx
    mov  r12, rdx
%else
    mov  rbx, rdi
    mov  r12, rsi
%endif
    mov  rax, [rbx + JN_KEY_COUNT]
    inc  rax
    mov  rcx, rax
    shl  rcx, 3
%ifdef WIN64_TARGET
    mov  rdx, rcx
    mov  rcx, [rbx + JN_KEYS]
    sub  rsp, 32
    call realloc
    add  rsp, 32
%else
    mov  rdi, [rbx + JN_KEYS]
    mov  rsi, rcx
    call realloc
%endif
    test rax, rax
    jz   .nak_ret
    mov  [rbx + JN_KEYS], rax
    ; strdup the key
    push rax
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call json_strdup
    add  rsp, 32
%else
    mov  rdi, r12
    call json_strdup
%endif
    pop  rcx                   ; keys array ptr
    mov  rdx, [rbx + JN_KEY_COUNT]
    mov  [rcx + rdx*8], rax
    inc  qword [rbx + JN_KEY_COUNT]
.nak_ret:
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ──────────────────────────────────────────────────────────────
; PARSER
; ──────────────────────────────────────────────────────────────

json_peek:
    mov  rax, [rel json_ps_pos]
    movzx rax, byte [rax]
    ret

json_advance:
    inc  qword [rel json_ps_pos]
    ret

json_skip_ws:
    push rbx
    mov  rbx, [rel json_ps_pos]
.sw_loop:
    movzx rax, byte [rbx]
    cmp  al, ' '
    je   .sw_adv
    cmp  al, 9
    je   .sw_adv
    cmp  al, 10
    je   .sw_adv
    cmp  al, 13
    je   .sw_adv
    jmp  .sw_done
.sw_adv:
    inc  rbx
    jmp  .sw_loop
.sw_done:
    mov  [rel json_ps_pos], rbx
    pop  rbx
    ret

; json_read_string() -> rax  (heap string, null on error)
; called with pos ON the opening "
json_read_string:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13

    ; skip opening "
    call json_advance

    ; first pass: compute length
    mov  r12, [rel json_ps_pos]   ; start
    mov  rbx, r12
    xor  r13, r13                 ; length counter
.rs_len:
    movzx rax, byte [rbx]
    test al, al
    jz   .rs_len_done
    cmp  al, 0x22                 ; closing "
    je   .rs_len_done
    cmp  al, 0x5c                 ; backslash
    jne  .rs_len_plain
    inc  rbx                      ; skip escape char
    movzx rax, byte [rbx]
    test al, al
    jz   .rs_len_done
.rs_len_plain:
    inc  rbx
    inc  r13
    jmp  .rs_len

.rs_len_done:
    ; malloc(len + 1)
%ifdef WIN64_TARGET
    mov  rcx, r13
    inc  rcx
    sub  rsp, 32
    call malloc
    add  rsp, 32
%else
    mov  rdi, r13
    inc  rdi
    call malloc
%endif
    test rax, rax
    jz   .rs_oom

    ; second pass: copy with escape decoding
    push rax
    mov  rdi, rax                 ; dst
    mov  rsi, r12                 ; src (back to start)
.rs_copy:
    movzx rax, byte [rsi]
    test al, al
    jz   .rs_copy_done
    cmp  al, 0x22
    je   .rs_copy_done
    cmp  al, 0x5c
    jne  .rs_literal
    ; escape sequence
    inc  rsi
    movzx rax, byte [rsi]
    cmp  al, 'n'
    je   .rs_esc_n
    cmp  al, 't'
    je   .rs_esc_t
    cmp  al, 'r'
    je   .rs_esc_r
    cmp  al, '"'
    je   .rs_esc_q
    cmp  al, '\\'
    je   .rs_esc_bs
    ; unknown escape: copy literally
    mov  [rdi], al
    inc  rdi
    inc  rsi
    jmp  .rs_copy
.rs_esc_n:
    mov  byte [rdi], 10
    inc  rdi
    inc  rsi
    jmp  .rs_copy
.rs_esc_t:
    mov  byte [rdi], 9
    inc  rdi
    inc  rsi
    jmp  .rs_copy
.rs_esc_r:
    mov  byte [rdi], 13
    inc  rdi
    inc  rsi
    jmp  .rs_copy
.rs_esc_q:
    mov  byte [rdi], 0x22
    inc  rdi
    inc  rsi
    jmp  .rs_copy
.rs_esc_bs:
    mov  byte [rdi], 0x5c
    inc  rdi
    inc  rsi
    jmp  .rs_copy
.rs_literal:
    mov  [rdi], al
    inc  rdi
    inc  rsi
    jmp  .rs_copy
.rs_copy_done:
    mov  byte [rdi], 0
    ; advance ps_pos past the closing "
    mov  [rel json_ps_pos], rsi
    call json_peek
    cmp  al, 0x22
    jne  .rs_done
    call json_advance
.rs_done:
    pop  rax
    jmp  .rs_ret
.rs_oom:
    xor  rax, rax
.rs_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; json_read_literal(expected, len, type) -> rax (JsonNode* or 0)
; reads a bare literal (true/false/null) matching expected string
json_read_literal:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
%ifdef WIN64_TARGET
    mov  rbx, rcx   ; expected string
    mov  r12, rdx   ; len
    mov  r13, r8    ; type
%else
    mov  rbx, rdi
    mov  r12, rsi
    mov  r13, rdx
%endif
    ; verify chars
    mov  rax, [rel json_ps_pos]
    mov  r14, rax
    xor  rcx, rcx
.rl_check:
    cmp  rcx, r12
    jge  .rl_match
    movzx rax, byte [r14 + rcx]
    movzx rdx, byte [rbx + rcx]
    cmp  al, dl
    jne  .rl_nomatch
    inc  rcx
    jmp  .rl_check
.rl_match:
    ; advance pos by len
    add  qword [rel json_ps_pos], r12
    ; allocate node
    call json_alloc_node
    test rax, rax
    jz   .rl_ret
    mov  [rax + JN_TYPE], r13
    ; set sval
    cmp  r13, JT_BOOL
    je   .rl_bool
    cmp  r13, JT_NULL
    je   .rl_null
    jmp  .rl_ret
.rl_bool:
    ; check if true or false
    movzx rdx, byte [r14]
    cmp  dl, 't'
    jne  .rl_false
    lea  rcx, [rel json_true_str]
    mov  [rax + JN_SVAL], rcx
    jmp  .rl_ret
.rl_false:
    lea  rcx, [rel json_false_str]
    mov  [rax + JN_SVAL], rcx
    jmp  .rl_ret
.rl_null:
    lea  rcx, [rel json_null_str]
    mov  [rax + JN_SVAL], rcx
    jmp  .rl_ret
.rl_nomatch:
    mov  byte [rel json_ps_err], 1
    xor  rax, rax
.rl_ret:
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; json_read_number() -> rax (JsonNode*)
; reads digits, optionally with sign, decimal, exponent
json_read_number:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13

    mov  r12, [rel json_ps_pos]   ; start
    mov  rbx, r12
    ; optional sign
    movzx rax, byte [rbx]
    cmp  al, '-'
    jne  .rnum_digits
    inc  rbx
.rnum_digits:
    movzx rax, byte [rbx]
    cmp  al, '0'
    jl   .rnum_done
    cmp  al, '9'
    jg   .rnum_done
    inc  rbx
    jmp  .rnum_digits
.rnum_done:
    ; optional decimal
    movzx rax, byte [rbx]
    cmp  al, '.'
    jne  .rnum_exp
    inc  rbx
.rnum_frac:
    movzx rax, byte [rbx]
    cmp  al, '0'
    jl   .rnum_exp
    cmp  al, '9'
    jg   .rnum_exp
    inc  rbx
    jmp  .rnum_frac
.rnum_exp:
    movzx rax, byte [rbx]
    cmp  al, 'e'
    je   .rnum_do_exp
    cmp  al, 'E'
    jne  .rnum_end
.rnum_do_exp:
    inc  rbx
    movzx rax, byte [rbx]
    cmp  al, '+'
    je   .rnum_exp_sign
    cmp  al, '-'
    jne  .rnum_exp_digits
.rnum_exp_sign:
    inc  rbx
.rnum_exp_digits:
    movzx rax, byte [rbx]
    cmp  al, '0'
    jl   .rnum_end
    cmp  al, '9'
    jg   .rnum_end
    inc  rbx
    jmp  .rnum_exp_digits
.rnum_end:
    mov  [rel json_ps_pos], rbx
    ; length
    mov  r13, rbx
    sub  r13, r12
    test r13, r13
    jz   .rnum_err
    ; malloc string
%ifdef WIN64_TARGET
    mov  rcx, r13
    inc  rcx
    sub  rsp, 32
    call malloc
    add  rsp, 32
%else
    mov  rdi, r13
    inc  rdi
    call malloc
%endif
    test rax, rax
    jz   .rnum_err
    ; copy digits
    push rax
    mov  rdi, rax
    mov  rsi, r12
    mov  rcx, r13
.rnum_copy:
    test rcx, rcx
    jz   .rnum_copy_done
    mov  al, [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    dec  rcx
    jmp  .rnum_copy
.rnum_copy_done:
    mov  byte [rdi], 0
    pop  r12                      ; r12 = sval string
    ; allocate node
    call json_alloc_node
    test rax, rax
    jz   .rnum_err
    mov  qword [rax + JN_TYPE], JT_NUMBER
    mov  [rax + JN_SVAL], r12
    jmp  .rnum_ret
.rnum_err:
    xor  rax, rax
.rnum_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; json_parse_value() -> rax (JsonNode* or 0)
json_parse_value:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13

    call json_skip_ws
    call json_peek
    test al, al
    jz   .pv_eof

    ; string
    cmp  al, 0x22
    jne  .pv_try_obj
    call json_read_string
    test rax, rax
    jz   .pv_err
    push rax
    call json_alloc_node
    test rax, rax
    jz   .pv_err
    mov  qword [rax + JN_TYPE], JT_STRING
    pop  rcx
    mov  [rax + JN_SVAL], rcx
    jmp  .pv_ret

.pv_try_obj:
    cmp  al, '{'
    jne  .pv_try_arr
    call json_advance
    call json_alloc_node
    test rax, rax
    jz   .pv_err
    mov  rbx, rax
    mov  qword [rbx + JN_TYPE], JT_OBJECT
.pv_obj_loop:
    call json_skip_ws
    call json_peek
    test al, al
    jz   .pv_obj_done
    cmp  al, '}'
    je   .pv_obj_close
    ; skip comma between pairs
    cmp  al, ','
    jne  .pv_obj_key
    call json_advance
    call json_skip_ws
    call json_peek
    cmp  al, '}'
    je   .pv_obj_close
.pv_obj_key:
    ; read key string
    cmp  al, 0x22
    jne  .pv_obj_done   ; malformed
    call json_read_string
    test rax, rax
    jz   .pv_obj_done
    mov  r12, rax       ; r12 = key string
    call json_skip_ws
    ; expect :
    call json_peek
    cmp  al, ':'
    jne  .pv_obj_done
    call json_advance
    call json_skip_ws
    ; read value
    call json_parse_value
    test rax, rax
    jz   .pv_obj_key_free
    ; add child and key
    mov  r13, rax       ; r13 = value node
%ifdef WIN64_TARGET
    mov  rcx, rbx
    mov  rdx, r13
    sub  rsp, 32
    call json_node_add_child
    add  rsp, 32
    mov  rcx, rbx
    mov  rdx, r12
    sub  rsp, 32
    call json_node_add_key
    add  rsp, 32
%else
    mov  rdi, rbx
    mov  rsi, r13
    call json_node_add_child
    mov  rdi, rbx
    mov  rsi, r12
    call json_node_add_key
%endif
    ; free the key string (strdup'd inside add_key)
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif
    jmp  .pv_obj_loop
.pv_obj_key_free:
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif
.pv_obj_done:
    mov  rax, rbx
    jmp  .pv_ret
.pv_obj_close:
    call json_advance
    mov  rax, rbx
    jmp  .pv_ret

.pv_try_arr:
    cmp  al, '['
    jne  .pv_try_true
    call json_advance
    call json_alloc_node
    test rax, rax
    jz   .pv_err
    mov  rbx, rax
    mov  qword [rbx + JN_TYPE], JT_ARRAY
.pv_arr_loop:
    call json_skip_ws
    call json_peek
    test al, al
    jz   .pv_arr_done
    cmp  al, ']'
    je   .pv_arr_close
    cmp  al, ','
    jne  .pv_arr_elem
    call json_advance
    call json_skip_ws
    call json_peek
    cmp  al, ']'
    je   .pv_arr_close
.pv_arr_elem:
    call json_parse_value
    test rax, rax
    jz   .pv_arr_done
%ifdef WIN64_TARGET
    push rax
    mov  rcx, rbx
    pop  rdx
    sub  rsp, 32
    call json_node_add_child
    add  rsp, 32
%else
    push rax
    mov  rdi, rbx
    pop  rsi
    call json_node_add_child
%endif
    jmp  .pv_arr_loop
.pv_arr_close:
    call json_advance
.pv_arr_done:
    mov  rax, rbx
    jmp  .pv_ret

.pv_try_true:
    cmp  al, 't'
    jne  .pv_try_false
%ifdef WIN64_TARGET
    lea  rcx, [rel json_true_str]
    mov  rdx, 4
    mov  r8,  JT_BOOL
    sub  rsp, 32
    call json_read_literal
    add  rsp, 32
%else
    lea  rdi, [rel json_true_str]
    mov  rsi, 4
    mov  rdx, JT_BOOL
    call json_read_literal
%endif
    jmp  .pv_ret

.pv_try_false:
    cmp  al, 'f'
    jne  .pv_try_null
%ifdef WIN64_TARGET
    lea  rcx, [rel json_false_str]
    mov  rdx, 5
    mov  r8,  JT_BOOL
    sub  rsp, 32
    call json_read_literal
    add  rsp, 32
%else
    lea  rdi, [rel json_false_str]
    mov  rsi, 5
    mov  rdx, JT_BOOL
    call json_read_literal
%endif
    jmp  .pv_ret

.pv_try_null:
    cmp  al, 'n'
    jne  .pv_try_num
%ifdef WIN64_TARGET
    lea  rcx, [rel json_null_str]
    mov  rdx, 4
    mov  r8,  JT_NULL
    sub  rsp, 32
    call json_read_literal
    add  rsp, 32
%else
    lea  rdi, [rel json_null_str]
    mov  rsi, 4
    mov  rdx, JT_NULL
    call json_read_literal
%endif
    jmp  .pv_ret

.pv_try_num:
    cmp  al, '-'
    je   .pv_do_num
    cmp  al, '0'
    jl   .pv_err
    cmp  al, '9'
    jg   .pv_err
.pv_do_num:
    call json_read_number
    jmp  .pv_ret

.pv_err:
    mov  byte [rel json_ps_err], 1
.pv_eof:
    xor  rax, rax
.pv_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ──────────────────────────────────────────────────────────────
; PUBLIC API
; ──────────────────────────────────────────────────────────────

; json__parse(src) -> adad
global json__parse
json__parse:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, rcx
%else
    mov  rax, rdi
%endif
    test rax, rax
    jz   .jp_null
    mov  [rel json_ps_src], rax
    mov  [rel json_ps_pos], rax
    mov  byte [rel json_ps_err], 0
    call json_parse_value
    jmp  .jp_ret
.jp_null:
    xor  rax, rax
.jp_ret:
    mov  rsp, rbp
    pop  rbp
    ret

; json__free(node) -> adad
global json__free
json__free:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  rbx, rcx
%else
    mov  rbx, rdi
%endif
    test rbx, rbx
    jz   .jf_ret

    ; free sval if type is string or number (heap alloc'd)
    mov  r12, [rbx + JN_TYPE]
    cmp  r12, JT_STRING
    je   .jf_free_sval
    cmp  r12, JT_NUMBER
    jne  .jf_children
.jf_free_sval:
    mov  r12, [rbx + JN_SVAL]
    test r12, r12
    jz   .jf_children
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif

.jf_children:
    ; free keys array
    mov  r12, [rbx + JN_KEYS]
    test r12, r12
    jz   .jf_no_keys
    mov  r13, [rbx + JN_KEY_COUNT]
    xor  rcx, rcx
.jf_key_loop:
    cmp  rcx, r13
    jge  .jf_free_keys_arr
    push rcx
    mov  rdi, [r12 + rcx*8]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call free
    add  rsp, 32
    pop  rcx
%else
    call free
    pop  rcx
%endif
    inc  rcx
    jmp  .jf_key_loop
.jf_free_keys_arr:
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif
.jf_no_keys:

    ; recurse children
    mov  r12, [rbx + JN_CHILDREN]
    test r12, r12
    jz   .jf_self
    mov  r13, [rbx + JN_CHILD_COUNT]
    xor  rcx, rcx
.jf_child_loop:
    cmp  rcx, r13
    jge  .jf_free_children_arr
    push rcx
    mov  rdi, [r12 + rcx*8]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json__free
    add  rsp, 32
    pop  rcx
%else
    call json__free
    pop  rcx
%endif
    inc  rcx
    jmp  .jf_child_loop
.jf_free_children_arr:
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif

.jf_self:
%ifdef WIN64_TARGET
    mov  rcx, rbx
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, rbx
    call free
%endif
    xor  rax, rax
.jf_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; json__type(node) -> adad
global json__type
json__type:
%ifdef WIN64_TARGET
    mov  rax, [rcx + JN_TYPE]
%else
    mov  rax, [rdi + JN_TYPE]
%endif
    ret

; json__str(node) -> lafz
global json__str
json__str:
%ifdef WIN64_TARGET
    mov  rax, [rcx + JN_SVAL]
%else
    mov  rax, [rdi + JN_SVAL]
%endif
    test rax, rax
    jnz  .js_ret
    lea  rax, [rel json_empty_str]
.js_ret:
    ret

; json__len(node) -> adad
global json__len
json__len:
%ifdef WIN64_TARGET
    mov  rax, [rcx + JN_CHILD_COUNT]
%else
    mov  rax, [rdi + JN_CHILD_COUNT]
%endif
    ret

; json__item(node, i) -> adad
global json__item
json__item:
%ifdef WIN64_TARGET
    mov  rax, rcx
    mov  rcx, rdx
%else
    mov  rax, rdi
    mov  rcx, rsi
%endif
    cmp  rcx, [rax + JN_CHILD_COUNT]
    jge  .ji_oob
    mov  rax, [rax + JN_CHILDREN]
    mov  rax, [rax + rcx*8]
    ret
.ji_oob:
    xor  rax, rax
    ret

; json__get(node, key) -> adad
global json__get
json__get:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  rbx, rcx
    mov  r12, rdx
%else
    mov  rbx, rdi
    mov  r12, rsi
%endif
    mov  r13, [rbx + JN_KEY_COUNT]
    mov  rbx, rbx
    xor  rcx, rcx
.jg_loop:
    cmp  rcx, r13
    jge  .jg_notfound
    push rcx
    mov  rax, [rbx + JN_KEYS]
    pop  rcx
    push rcx
    mov  rdi, [rax + rcx*8]
%ifdef WIN64_TARGET
    push rbx
    mov  rcx, rdi
    mov  rdx, r12
    sub  rsp, 32
    call memory__strcmp
    add  rsp, 32
    pop  rbx
    pop  rcx
%else
    mov  rsi, r12
    call memory__strcmp
    pop  rcx
%endif
    test rax, rax
    jnz  .jg_next
    ; found: return children[i]
    mov  rax, [rbx + JN_CHILDREN]
    mov  rax, [rax + rcx*8]
    jmp  .jg_ret
.jg_next:
    inc  rcx
    jmp  .jg_loop
.jg_notfound:
    xor  rax, rax
.jg_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; json__key(node, i) -> lafz
global json__key
json__key:
%ifdef WIN64_TARGET
    mov  rax, rcx
    mov  rcx, rdx
%else
    mov  rax, rdi
    mov  rcx, rsi
%endif
    cmp  rcx, [rax + JN_KEY_COUNT]
    jge  .jk_oob
    mov  rax, [rax + JN_KEYS]
    mov  rax, [rax + rcx*8]
    test rax, rax
    jnz  .jk_ret
.jk_oob:
    lea  rax, [rel json_empty_str]
.jk_ret:
    ret

; type checks
global json__is_str
json__is_str:
%ifdef WIN64_TARGET
    cmp  qword [rcx + JN_TYPE], JT_STRING
%else
    cmp  qword [rdi + JN_TYPE], JT_STRING
%endif
    sete al
    movzx rax, al
    ret

global json__is_num
json__is_num:
%ifdef WIN64_TARGET
    cmp  qword [rcx + JN_TYPE], JT_NUMBER
%else
    cmp  qword [rdi + JN_TYPE], JT_NUMBER
%endif
    sete al
    movzx rax, al
    ret

global json__is_bool
json__is_bool:
%ifdef WIN64_TARGET
    cmp  qword [rcx + JN_TYPE], JT_BOOL
%else
    cmp  qword [rdi + JN_TYPE], JT_BOOL
%endif
    sete al
    movzx rax, al
    ret

global json__is_null
json__is_null:
%ifdef WIN64_TARGET
    cmp  qword [rcx + JN_TYPE], JT_NULL
%else
    cmp  qword [rdi + JN_TYPE], JT_NULL
%endif
    sete al
    movzx rax, al
    ret

global json__is_array
json__is_array:
%ifdef WIN64_TARGET
    cmp  qword [rcx + JN_TYPE], JT_ARRAY
%else
    cmp  qword [rdi + JN_TYPE], JT_ARRAY
%endif
    sete al
    movzx rax, al
    ret

global json__is_object
json__is_object:
%ifdef WIN64_TARGET
    cmp  qword [rcx + JN_TYPE], JT_OBJECT
%else
    cmp  qword [rdi + JN_TYPE], JT_OBJECT
%endif
    sete al
    movzx rax, al
    ret

; ──────────────────────────────────────────────────────────────
; STRINGIFY
; ──────────────────────────────────────────────────────────────

; json__stringify(node) -> lafz  (static 64KB buffer, not re-entrant)
global json__stringify
json__stringify:
    push rbp
    mov  rbp, rsp
    push rbx
%ifdef WIN64_TARGET
    mov  rbx, rcx
%else
    mov  rbx, rdi
%endif
    lea  rax, [rel json_str_buf]
    mov  [rel json_str_ptr], rax
%ifdef WIN64_TARGET
    mov  rcx, rbx
    sub  rsp, 32
    call json_stringify_node
    add  rsp, 32
%else
    mov  rdi, rbx
    call json_stringify_node
%endif
    mov  rax, [rel json_str_ptr]
    mov  byte [rax], 0
    lea  rax, [rel json_str_buf]
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; json_str_write(s: rdi/rcx)  -- appends a raw string to the buffer
json_str_write:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    test rdi, rdi
    jz   .jsw_ret
    mov  rax, [rel json_str_ptr]
.jsw_loop:
    mov  cl, [rdi]
    test cl, cl
    jz   .jsw_done
    mov  [rax], cl
    inc  rax
    inc  rdi
    jmp  .jsw_loop
.jsw_done:
    mov  [rel json_str_ptr], rax
.jsw_ret:
    ret

; json_str_write_quoted(s) -- writes "s" with JSON escaping
json_str_write_quoted:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    ; opening quote
    push rdi
    lea  rdi, [rel json_s_quote]
    call json_str_write
    pop  rdi
    ; escaped content
    test rdi, rdi
    jz   .jswq_close
.jswq_loop:
    movzx rax, byte [rdi]
    test al, al
    jz   .jswq_close
    push rdi
    cmp  al, 10
    je   .jswq_n
    cmp  al, 9
    je   .jswq_t
    cmp  al, 13
    je   .jswq_r
    cmp  al, 0x5c
    je   .jswq_bs
    cmp  al, 0x22
    je   .jswq_q
    ; regular char
    mov  rax, [rel json_str_ptr]
    movzx rcx, byte [rdi]
    mov  [rax], cl
    inc  qword [rel json_str_ptr]
    pop  rdi
    inc  rdi
    jmp  .jswq_loop
.jswq_n:
    lea  rdi, [rel json_s_bs_n]
    call json_str_write
    pop  rdi
    inc  rdi
    jmp  .jswq_loop
.jswq_t:
    lea  rdi, [rel json_s_bs_t]
    call json_str_write
    pop  rdi
    inc  rdi
    jmp  .jswq_loop
.jswq_r:
    lea  rdi, [rel json_s_bs_r]
    call json_str_write
    pop  rdi
    inc  rdi
    jmp  .jswq_loop
.jswq_bs:
    lea  rdi, [rel json_s_bs_bs]
    call json_str_write
    pop  rdi
    inc  rdi
    jmp  .jswq_loop
.jswq_q:
    lea  rdi, [rel json_s_bs_q]
    call json_str_write
    pop  rdi
    inc  rdi
    jmp  .jswq_loop
.jswq_close:
    lea  rdi, [rel json_s_quote]
    call json_str_write
    ret

; json_stringify_node(node: rdi/rcx)  -- recursive
json_stringify_node:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  rbx, rcx
%else
    mov  rbx, rdi
%endif
    test rbx, rbx
    jz   .sn_ret

    mov  r12, [rbx + JN_TYPE]

    cmp  r12, JT_STRING
    jne  .sn_try_num
    ; string: write quoted sval
    mov  rdi, [rbx + JN_SVAL]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write_quoted
    add  rsp, 32
%else
    call json_str_write_quoted
%endif
    jmp  .sn_ret

.sn_try_num:
    cmp  r12, JT_NUMBER
    jne  .sn_try_bool
    ; number: write raw
    mov  rdi, [rbx + JN_SVAL]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif
    jmp  .sn_ret

.sn_try_bool:
    cmp  r12, JT_BOOL
    jne  .sn_try_null
    mov  rdi, [rbx + JN_SVAL]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif
    jmp  .sn_ret

.sn_try_null:
    cmp  r12, JT_NULL
    jne  .sn_try_arr
    lea  rdi, [rel json_s_null]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif
    jmp  .sn_ret

.sn_try_arr:
    cmp  r12, JT_ARRAY
    jne  .sn_try_obj
    lea  rdi, [rel json_s_lbracket]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif
    mov  r13, [rbx + JN_CHILD_COUNT]
    xor  rcx, rcx
.sn_arr_loop:
    cmp  rcx, r13
    jge  .sn_arr_done
    push rcx
    mov  rax, [rbx + JN_CHILDREN]
    pop  rcx
    push rcx
    mov  rdi, [rax + rcx*8]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_stringify_node
    add  rsp, 32
    pop  rcx
%else
    call json_stringify_node
    pop  rcx
%endif
    inc  rcx
    cmp  rcx, r13
    jge  .sn_arr_loop
    ; comma between elements (not after last)
    lea  rdi, [rel json_s_comma]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif
    jmp  .sn_arr_loop
.sn_arr_done:
    lea  rdi, [rel json_s_rbracket]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif
    jmp  .sn_ret

.sn_try_obj:
    cmp  r12, JT_OBJECT
    jne  .sn_ret
    lea  rdi, [rel json_s_lbrace]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif
    mov  r13, [rbx + JN_CHILD_COUNT]
    xor  rcx, rcx
.sn_obj_loop:
    cmp  rcx, r13
    jge  .sn_obj_done
    push rcx
    ; write key
    mov  rax, [rbx + JN_KEYS]
    pop  rcx
    push rcx
    mov  rdi, [rax + rcx*8]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write_quoted
    add  rsp, 32
%else
    call json_str_write_quoted
%endif
    lea  rdi, [rel json_s_colon]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif
    ; write value
    pop  rcx
    push rcx
    mov  rax, [rbx + JN_CHILDREN]
    pop  rcx
    push rcx
    mov  rdi, [rax + rcx*8]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_stringify_node
    add  rsp, 32
    pop  rcx
%else
    call json_stringify_node
    pop  rcx
%endif
    inc  rcx
    cmp  rcx, r13
    jge  .sn_obj_loop
    lea  rdi, [rel json_s_comma]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif
    jmp  .sn_obj_loop
.sn_obj_done:
    lea  rdi, [rel json_s_rbrace]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call json_str_write
    add  rsp, 32
%else
    call json_str_write
%endif

.sn_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret
