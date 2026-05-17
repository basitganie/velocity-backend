; ============================================================
; Velocity SDL2 Bindings v1.0
; ABI-correct: Linux SysV (sub rsp,8) vs Windows MS-x64 (sub rsp,32)
; Links with: -lSDL2 (Linux)  or  -lSDL2main -lSDL2 (Windows)
; ============================================================

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

; ------ external SDL2 symbols ----------------------------------
extern SDL_Init
extern SDL_Quit
extern SDL_GetError
extern SDL_Delay
extern SDL_GetTicks
extern SDL_CreateWindow
extern SDL_DestroyWindow
extern SDL_GetWindowID
extern SDL_SetWindowTitle
extern SDL_ShowWindow
extern SDL_HideWindow
extern SDL_CreateRenderer
extern SDL_DestroyRenderer
extern SDL_RenderClear
extern SDL_RenderPresent
extern SDL_SetRenderDrawColor
extern SDL_RenderFillRect
extern SDL_RenderDrawRect
extern SDL_RenderDrawLine
extern SDL_RenderDrawPoint
extern SDL_RenderCopy
extern SDL_RenderCopyEx
extern SDL_SetRenderDrawBlendMode
extern SDL_PollEvent
extern SDL_WaitEvent
extern SDL_GetKeyboardState
extern SDL_GetMouseState
extern SDL_GetMousePosition
extern SDL_ShowCursor
extern SDL_LoadBMP_RW
extern SDL_CreateTextureFromSurface
extern SDL_DestroyTexture
extern SDL_FreeSurface
extern SDL_QueryTexture
extern SDL_RenderSetLogicalSize
extern SDL_RenderSetScale
extern SDL_GetRendererOutputSize
extern SDL_SetTextureAlphaMod
extern SDL_SetTextureColorMod
extern SDL_SetTextureBlendMode

section .text

; ---- Core ----------------------------------------------------
global sdl2__init
sdl2__init:                   VL_CALL SDL_Init

global sdl2__quit
sdl2__quit:                   VL_CALL SDL_Quit

global sdl2__get_error
sdl2__get_error:              VL_CALL SDL_GetError

global sdl2__delay
sdl2__delay:                  VL_CALL SDL_Delay

global sdl2__get_ticks
sdl2__get_ticks:              VL_CALL SDL_GetTicks

; ---- Window --------------------------------------------------
global sdl2__create_window
sdl2__create_window:          VL_CALL SDL_CreateWindow

global sdl2__destroy_window
sdl2__destroy_window:         VL_CALL SDL_DestroyWindow

global sdl2__set_window_title
sdl2__set_window_title:       VL_CALL SDL_SetWindowTitle

global sdl2__show_window
sdl2__show_window:            VL_CALL SDL_ShowWindow

global sdl2__hide_window
sdl2__hide_window:            VL_CALL SDL_HideWindow

; ---- Renderer ------------------------------------------------
global sdl2__create_renderer
sdl2__create_renderer:        VL_CALL SDL_CreateRenderer

global sdl2__destroy_renderer
sdl2__destroy_renderer:       VL_CALL SDL_DestroyRenderer

global sdl2__render_clear
sdl2__render_clear:           VL_CALL SDL_RenderClear

global sdl2__render_present
sdl2__render_present:         VL_CALL SDL_RenderPresent

global sdl2__set_render_draw_color
sdl2__set_render_draw_color:  VL_CALL SDL_SetRenderDrawColor

global sdl2__set_draw_color
sdl2__set_draw_color:         VL_CALL SDL_SetRenderDrawColor

; sdl2__render_fill_rect(ren, x, y, w, h)
; rdi=ren, rsi=x, rdx=y, rcx=w, r8=h
global sdl2__render_fill_rect
sdl2__render_fill_rect:
    push rbp
    mov  rbp, rsp
    sub  rsp, 8
    and  rsp, -16
    ; save renderer
    push rdi
    ; build rect: make_rect(x, y, w, h) -> rdi=x, rsi=y, rdx=w, rcx=h
    mov  rdi, rsi
    mov  rsi, rdx
    mov  rdx, rcx
    mov  rcx, r8
    call sdl2__make_rect
    ; rax = rect ptr
    pop  rdi          ; restore renderer
    mov  rsi, rax     ; rect ptr
    call SDL_RenderFillRect
    mov  rsp, rbp
    pop  rbp
    ret

; sdl2__render_draw_rect(ren, x, y, w, h)
; rdi=ren, rsi=x, rdx=y, rcx=w, r8=h
global sdl2__render_draw_rect
sdl2__render_draw_rect:
    push rbp
    mov  rbp, rsp
    sub  rsp, 8
    and  rsp, -16
    push rdi
    mov  rdi, rsi
    mov  rsi, rdx
    mov  rdx, rcx
    mov  rcx, r8
    call sdl2__make_rect
    pop  rdi
    mov  rsi, rax
    call SDL_RenderDrawRect
    mov  rsp, rbp
    pop  rbp
    ret

global sdl2__render_draw_line
sdl2__render_draw_line:       VL_CALL SDL_RenderDrawLine

global sdl2__render_draw_point
sdl2__render_draw_point:      VL_CALL SDL_RenderDrawPoint

global sdl2__render_copy
sdl2__render_copy:            VL_CALL SDL_RenderCopy

global sdl2__render_set_logical_size
sdl2__render_set_logical_size: VL_CALL SDL_RenderSetLogicalSize

global sdl2__render_set_scale
sdl2__render_set_scale:       VL_CALL SDL_RenderSetScale

global sdl2__get_renderer_output_size
sdl2__get_renderer_output_size: VL_CALL SDL_GetRendererOutputSize

global sdl2__set_render_blend_mode
sdl2__set_render_blend_mode:  VL_CALL SDL_SetRenderDrawBlendMode

; ---- Events --------------------------------------------------
global sdl2__poll_event_raw
sdl2__poll_event_raw:         VL_CALL SDL_PollEvent

; sdl2__poll_event: zero-arg, uses static buffer (what main generates calls to)
global sdl2__poll_event
sdl2__poll_event:
    jmp  sdl2__poll_event_auto

global sdl2__wait_event
sdl2__wait_event:             VL_CALL SDL_WaitEvent

; ---- Input ---------------------------------------------------
global sdl2__get_keyboard_state
sdl2__get_keyboard_state:
    push rbp
    mov  rbp, rsp
    sub  rsp, 8
    and  rsp, -16
%ifdef WIN64_TARGET
    xor  rcx, rcx
    call SDL_GetKeyboardState
%else
    xor  rdi, rdi
    call SDL_GetKeyboardState
%endif
    mov  rsp, rbp
    pop  rbp
    ret

global sdl2__get_mouse_state
sdl2__get_mouse_state:        VL_CALL SDL_GetMouseState

global sdl2__show_cursor
sdl2__show_cursor:            VL_CALL SDL_ShowCursor

; ---- Textures ------------------------------------------------
extern SDL_RWFromFile

global sdl2__load_bmp
sdl2__load_bmp:
%ifdef WIN64_TARGET
    sub  rsp, 32
    lea  rdx, [rel .rb]
    call SDL_RWFromFile
    add  rsp, 32
    test rax, rax
    jz   .done
    sub  rsp, 32
    mov  rcx, rax
    mov  rdx, 1
    call SDL_LoadBMP_RW
    add  rsp, 32
%else
    sub  rsp, 8
    mov  rsi, rdi
    lea  rdi, [rel .rb]
    xchg rdi, rsi
    call SDL_RWFromFile
    add  rsp, 8
    test rax, rax
    jz   .done
    sub  rsp, 8
    mov  rdi, rax
    mov  rsi, 1
    call SDL_LoadBMP_RW
    add  rsp, 8
%endif
.done:
    ret
section .data
.rb: db "rb", 0
section .text

global sdl2__create_texture_from_surface
sdl2__create_texture_from_surface: VL_CALL SDL_CreateTextureFromSurface

global sdl2__destroy_texture
sdl2__destroy_texture:        VL_CALL SDL_DestroyTexture

global sdl2__free_surface
sdl2__free_surface:           VL_CALL SDL_FreeSurface

global sdl2__query_texture
sdl2__query_texture:          VL_CALL SDL_QueryTexture

global sdl2__set_texture_alpha
sdl2__set_texture_alpha:      VL_CALL SDL_SetTextureAlphaMod

global sdl2__set_texture_color
sdl2__set_texture_color:      VL_CALL SDL_SetTextureColorMod

global sdl2__set_texture_blend
sdl2__set_texture_blend:      VL_CALL SDL_SetTextureBlendMode

; ---- Inline helpers ------------------------------------------

; sdl2__make_rect(x, y, w, h: adad) -> adad*
; Writes a 16-byte SDL_Rect {x,y,w,h} (4 x i32) into a static buf,
; returns pointer. Call is NOT thread-safe.
section .bss
    sdl2_rect_buf  resb 16
    sdl2_event_buf resb 56     ; SDL_Event is 56 bytes

section .text
global sdl2__make_rect
sdl2__make_rect:
%ifdef WIN64_TARGET
    ; rcx=x, rdx=y, r8=w, r9=h
    lea  rax, [rel sdl2_rect_buf]
    mov  dword [rax + 0],  ecx
    mov  dword [rax + 4],  edx
    mov  dword [rax + 8],  r8d
    mov  dword [rax + 12], r9d
%else
    ; rdi=x, rsi=y, rdx=w, rcx=h
    lea  rax, [rel sdl2_rect_buf]
    mov  dword [rax + 0],  edi
    mov  dword [rax + 4],  esi
    mov  dword [rax + 8],  edx
    mov  dword [rax + 12], ecx
%endif
    ret

; sdl2__event_type(event_ptr: adad) -> adad
; SDL_Event first 4 bytes are the Uint32 type field.
global sdl2__event_type
sdl2__event_type:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    test rdi, rdi
    jz   .et_zero
    mov  eax, dword [rdi]
    ret
.et_zero:
    xor  rax, rax
    ret

; sdl2__event_key_sym(event_ptr: adad) -> adad
; SDL_KeyboardEvent layout:
;   0: type, 4: timestamp, 8: windowID, 12: state, 13: repeat, 14-15: padding
;   16: SDL_Keysym { scancode(4), sym(4), mod(2), unused(4) }
;   sym is at offset 20
global sdl2__event_key_sym
sdl2__event_key_sym:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    test rdi, rdi
    jz   .eks_zero
    movsx rax, dword [rdi + 20]
    ret
.eks_zero:
    xor  rax, rax
    ret

; sdl2__event_key_scancode(event_ptr: adad) -> adad
; SDL_Keysym.scancode is at offset 16 (Uint32)
global sdl2__event_key_scancode
sdl2__event_key_scancode:
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    test rdi, rdi
    jz   .esc_zero
    mov  eax, dword [rdi + 16]
    ret
.esc_zero:
    xor  rax, rax
    ret

; sdl2__poll_event_auto() -> adad
; Calls SDL_PollEvent with a static 56-byte buffer.
; Returns pointer to buffer if event available, 0 if no event.
global sdl2__poll_event_auto
sdl2__poll_event_auto:
%ifdef WIN64_TARGET
    lea  rcx, [rel sdl2_event_buf]
    sub  rsp, 32
    call SDL_PollEvent
    add  rsp, 32
%else
    lea  rdi, [rel sdl2_event_buf]
    sub  rsp, 8
    call SDL_PollEvent
    add  rsp, 8
%endif
    test eax, eax
    jz   .no_event
    lea  rax, [rel sdl2_event_buf]
    ret
.no_event:
    xor  rax, rax
    ret

; sdl2__key_held(keys: adad, scancode: adad) -> adad
; keys = pointer returned by SDL_GetKeyboardState
; scancode = SDL scancode integer
; returns 1 if key held, 0 if not
global sdl2__key_held
sdl2__key_held:
%ifdef WIN64_TARGET
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    test rdi, rdi
    jz   .kh_zero
    movzx rax, byte [rdi + rsi]
    ret
.kh_zero:
    xor  rax, rax
    ret

; ============================================================
; SDL2_ttf bindings
; ============================================================
extern TTF_Init
extern TTF_Quit
extern TTF_OpenFont
extern TTF_CloseFont
extern TTF_RenderText_Blended
extern TTF_RenderText_Solid
extern TTF_RenderUTF8_Blended
extern TTF_RenderUTF8_Solid
extern TTF_SizeText
extern TTF_SizeUTF8
extern TTF_FontHeight
extern TTF_FontAscent
extern TTF_FontDescent
extern TTF_FontLineSkip

global sdl2__ttf_init
sdl2__ttf_init:               VL_CALL TTF_Init

global sdl2__ttf_quit
sdl2__ttf_quit:               VL_CALL TTF_Quit

global sdl2__ttf_open_font
sdl2__ttf_open_font:          VL_CALL TTF_OpenFont

global sdl2__ttf_close_font
sdl2__ttf_close_font:         VL_CALL TTF_CloseFont

global sdl2__ttf_render_solid
sdl2__ttf_render_solid:       VL_CALL TTF_RenderUTF8_Solid

global sdl2__ttf_render_blended
sdl2__ttf_render_blended:     VL_CALL TTF_RenderUTF8_Blended

global sdl2__ttf_size_text
sdl2__ttf_size_text:          VL_CALL TTF_SizeUTF8

global sdl2__ttf_font_height
sdl2__ttf_font_height:        VL_CALL TTF_FontHeight

global sdl2__ttf_font_line_skip
sdl2__ttf_font_line_skip:     VL_CALL TTF_FontLineSkip

; ---- Mouse event field accessors ----------------------------
; SDL_MouseButtonEvent: type(4) + timestamp(4) + windowID(4) +
;   which(4) + button(1) + state(1) + clicks(1) + pad(1) + x(4) + y(4)
; offset of x = 20, y = 24  (relative to event base = 0)
; SDL_MouseMotionEvent: type+ts+wid+which+state+x+y+xrel+yrel
; offset of x = 20, y = 24
; SDL_MouseWheelEvent: type+ts+wid+which+x+y
; offset of y (scroll) = 20

extern SDL_GetMouseState

global sdl2__event_mouse_x
sdl2__event_mouse_x:
    ; rdi = event_buf ptr
    mov eax, dword [rdi + 20]
    ret

global sdl2__event_mouse_y
sdl2__event_mouse_y:
    mov eax, dword [rdi + 24]
    ret

global sdl2__event_mouse_button
sdl2__event_mouse_button:
    movzx eax, byte [rdi + 13]
    ret

global sdl2__event_wheel_y
sdl2__event_wheel_y:
    mov eax, dword [rdi + 20]
    ret

global sdl2__event_text_input
sdl2__event_text_input:
    ; SDL_TextInputEvent: type(4)+ts(4)+windowID(4)+text[32]
    ; text starts at offset 12
    lea rax, [rdi + 12]
    ret

; ---- SDL_TEXTINPUT event type constant ----------------------
; SDL_TEXTINPUT = 771 (0x303)

global sdl2__make_color
sdl2__make_color:
    ; rdi=r, rsi=g, rdx=b, rcx=a
    ; pack into rax as r | g<<8 | b<<16 | a<<24
    movzx eax, dil
    movzx esi, sil
    shl esi, 8
    or eax, esi
    movzx edx, dl
    shl edx, 16
    or eax, edx
    movzx ecx, cl
    shl ecx, 24
    or eax, ecx
    ret
