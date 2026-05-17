; ============================================================
; Velocity RayLib Bindings v3 — Full 2D + 3D API
; Linux SysV AMD64 / Windows MS-x64
; No duplicate symbols. Clean single-definition file.
; ============================================================

default rel

%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

%ifdef WIN64_TARGET
  %macro VL_CALL 1
    sub  rsp, 32
    call %1
    add  rsp, 32
    ret
  %endmacro
  %macro VL_CALL_F 1
    sub  rsp, 32
    call %1
    add  rsp, 32
    cvtss2sd xmm0, xmm0
    ret
  %endmacro
  %macro VL_CALL_FD 1
    sub  rsp, 32
    call %1
    add  rsp, 32
    ret
  %endmacro
%else
  %macro VL_CALL 1
    sub  rsp, 8
    call %1
    add  rsp, 8
    ret
  %endmacro
  %macro VL_CALL_F 1
    sub  rsp, 8
    call %1
    add  rsp, 8
    cvtss2sd xmm0, xmm0
    ret
  %endmacro
  %macro VL_CALL_FD 1
    sub  rsp, 8
    call %1
    add  rsp, 8
    ret
  %endmacro
%endif

; ---- External raylib symbols ----------------------------------
extern InitWindow
extern CloseWindow
extern WindowShouldClose
extern IsWindowReady
extern IsWindowFullscreen
extern IsWindowHidden
extern IsWindowMinimized
extern IsWindowMaximized
extern IsWindowFocused
extern IsWindowResized
extern SetWindowState
extern ClearWindowState
extern ToggleFullscreen
extern ToggleBorderlessWindowed
extern MaximizeWindow
extern MinimizeWindow
extern RestoreWindow
extern SetWindowTitle
extern SetWindowPosition
extern SetWindowMonitor
extern SetWindowMinSize
extern SetWindowMaxSize
extern SetWindowSize
extern SetWindowOpacity
extern SetWindowFocused
extern GetScreenWidth
extern GetScreenHeight
extern GetRenderWidth
extern GetRenderHeight
extern GetMonitorCount
extern GetCurrentMonitor
extern GetMonitorWidth
extern GetMonitorHeight
extern GetMonitorRefreshRate
extern GetMonitorName
extern SetClipboardText
extern GetClipboardText
extern EnableEventWaiting
extern DisableEventWaiting
extern SetTargetFPS
extern GetFPS
extern GetFrameTime
extern GetTime
extern WaitTime
extern SetConfigFlags
extern SetTraceLogLevel
extern SetExitKey
extern ClearBackground
extern BeginDrawing
extern EndDrawing
extern BeginMode2D
extern EndMode2D
extern BeginMode3D
extern EndMode3D
extern BeginTextureMode
extern EndTextureMode
extern BeginShaderMode
extern EndShaderMode
extern BeginBlendMode
extern EndBlendMode
extern BeginScissorMode
extern EndScissorMode
extern DrawPixel
extern DrawLine
extern DrawLineEx
extern DrawLineBezier
extern DrawCircle
extern DrawCircleSector
extern DrawCircleSectorLines
extern DrawCircleGradient
extern DrawCircleLines
extern DrawEllipse
extern DrawEllipseLines
extern DrawRing
extern DrawRingLines
extern DrawRectangle
extern DrawRectangleGradientV
extern DrawRectangleGradientH
extern DrawRectangleLines
extern DrawRectangleRounded
extern DrawRectangleRoundedLines
extern DrawTriangle
extern DrawTriangleLines
extern DrawPoly
extern DrawPolyLines
extern DrawPolyLinesEx
extern CheckCollisionRecs
extern CheckCollisionCircles
extern CheckCollisionCircleRec
extern CheckCollisionPointRec
extern CheckCollisionPointCircle
extern CheckCollisionPointTriangle
extern CheckCollisionLines
extern CheckCollisionPointLine
extern GetCollisionRec
extern DrawFPS
extern DrawText
extern DrawTextEx
extern DrawTextPro
extern MeasureText
extern MeasureTextEx
extern LoadFont
extern LoadFontEx
extern UnloadFont
extern GetFontDefault
extern SetTextLineSpacing
extern GetGlyphIndex
extern LoadTexture
extern LoadTextureFromImage
extern LoadRenderTexture
extern IsTextureValid
extern UnloadTexture
extern UnloadRenderTexture
extern UpdateTexture
extern DrawTexture
extern DrawTextureV
extern DrawTextureEx
extern DrawTextureRec
extern DrawTexturePro
extern DrawTextureNPatch
extern SetTextureFilter
extern SetTextureWrap
extern GenTextureMipmaps
extern LoadImage
extern LoadImageRaw
extern IsImageValid
extern UnloadImage
extern ExportImage
extern GenImageColor
extern GenImageGradientLinear
extern GenImageGradientRadial
extern GenImageChecked
extern GenImageWhiteNoise
extern ImageResize
extern ImageFlipVertical
extern ImageFlipHorizontal
extern ImageRotateCW
extern ImageRotateCCW
extern ImageColorTint
extern ImageColorInvert
extern ImageColorGrayscale
extern ImageDrawRectangle
extern ImageDrawCircle
extern Fade
extern ColorToInt
extern ColorTint
extern ColorBrightness
extern ColorContrast
extern ColorAlpha
extern ColorAlphaBlend
extern GetColor
extern GetPixelColor
extern DrawLine3D
extern DrawPoint3D
extern DrawCircle3D
extern DrawTriangle3D
extern DrawCube
extern DrawCubeV
extern DrawCubeWires
extern DrawCubeWiresV
extern DrawSphere
extern DrawSphereEx
extern DrawSphereWires
extern DrawCylinder
extern DrawCylinderEx
extern DrawCylinderWires
extern DrawCylinderWiresEx
extern DrawCapsule
extern DrawCapsuleWires
extern DrawPlane
extern DrawRay
extern DrawGrid
extern DrawBoundingBox
extern LoadModel
extern LoadModelFromMesh
extern IsModelValid
extern UnloadModel
extern GetModelBoundingBox
extern DrawModel
extern DrawModelEx
extern DrawModelWires
extern DrawModelWiresEx
extern DrawBillboard
extern DrawBillboardRec
extern UploadMesh
extern UnloadMesh
extern DrawMesh
extern GenMeshPoly
extern GenMeshPlane
extern GenMeshCube
extern GenMeshSphere
extern GenMeshHemiSphere
extern GenMeshCylinder
extern GenMeshCone
extern GenMeshTorus
extern GenMeshKnot
extern GenMeshHeightmap
extern GenMeshCubicmap
extern LoadMaterialDefault
extern UnloadMaterial
extern SetMaterialTexture
extern SetModelMeshMaterial
extern UpdateModelAnimation
;extern UnloadModelAnimation
extern UpdateCamera
extern UpdateCameraPro
extern LoadShader
extern LoadShaderFromMemory
extern IsShaderValid
extern UnloadShader
extern GetShaderLocation
extern SetShaderValue
extern SetShaderValueMatrix
extern SetShaderValueTexture
extern CheckCollisionSpheres
extern CheckCollisionBoxes
extern CheckCollisionBoxSphere
extern GetRayCollisionSphere
extern GetRayCollisionBox
extern GetRayCollisionMesh
extern GetRayCollisionTriangle
extern GetRayCollisionQuad
extern IsKeyPressed
extern IsKeyPressedRepeat
extern IsKeyDown
extern IsKeyReleased
extern IsKeyUp
extern GetKeyPressed
extern GetCharPressed
extern IsMouseButtonPressed
extern IsMouseButtonDown
extern IsMouseButtonReleased
extern IsMouseButtonUp
extern GetMouseX
extern GetMouseY
extern SetMousePosition
extern SetMouseOffset
extern SetMouseScale
extern GetMouseWheelMove
extern SetMouseCursor
extern GetTouchX
extern GetTouchY
extern GetTouchPointCount
extern IsGamepadAvailable
extern IsGamepadButtonPressed
extern IsGamepadButtonDown
extern IsGamepadButtonReleased
extern IsGamepadButtonUp
extern GetGamepadButtonPressed
extern GetGamepadAxisCount
extern GetGamepadAxisMovement
extern SetGamepadVibration
extern InitAudioDevice
extern CloseAudioDevice
extern IsAudioDeviceReady
extern SetMasterVolume
extern GetMasterVolume
extern LoadSound
extern LoadSoundFromWave
extern IsSoundValid
extern UpdateSound
extern UnloadSound
extern PlaySound
extern StopSound
extern PauseSound
extern ResumeSound
extern IsSoundPlaying
extern SetSoundVolume
extern SetSoundPitch
extern SetSoundPan
extern LoadWave
extern IsWaveValid
extern UnloadWave
extern ExportWave
extern LoadMusicStream
extern IsMusicValid
extern UnloadMusicStream
extern PlayMusicStream
extern IsMusicStreamPlaying
extern UpdateMusicStream
extern StopMusicStream
extern PauseMusicStream
extern ResumeMusicStream
extern SeekMusicStream
extern SetMusicVolume
extern SetMusicPitch
extern SetMusicPan
extern GetMusicTimeLength
extern GetMusicTimePlayed
extern GetRandomValue
extern SetRandomSeed
extern TakeScreenshot
extern OpenURL

section .text

; ==== WINDOW ====
global rl_init_window
rl_init_window:                   VL_CALL InitWindow
global rl_close_window
rl_close_window:                  VL_CALL CloseWindow
global rl_window_should_close
rl_window_should_close:           VL_CALL WindowShouldClose
global rl_is_window_ready
rl_is_window_ready:               VL_CALL IsWindowReady
global rl_is_window_fullscreen
rl_is_window_fullscreen:          VL_CALL IsWindowFullscreen
global rl_is_window_hidden
rl_is_window_hidden:              VL_CALL IsWindowHidden
global rl_is_window_minimized
rl_is_window_minimized:           VL_CALL IsWindowMinimized
global rl_is_window_maximized
rl_is_window_maximized:           VL_CALL IsWindowMaximized
global rl_is_window_focused
rl_is_window_focused:             VL_CALL IsWindowFocused
global rl_is_window_resized
rl_is_window_resized:             VL_CALL IsWindowResized
global rl_set_window_state
rl_set_window_state:              VL_CALL SetWindowState
global rl_clear_window_state
rl_clear_window_state:            VL_CALL ClearWindowState
global rl_toggle_fullscreen
rl_toggle_fullscreen:             VL_CALL ToggleFullscreen
global rl_toggle_borderless_windowed
rl_toggle_borderless_windowed:    VL_CALL ToggleBorderlessWindowed
global rl_maximize_window
rl_maximize_window:               VL_CALL MaximizeWindow
global rl_minimize_window
rl_minimize_window:               VL_CALL MinimizeWindow
global rl_restore_window
rl_restore_window:                VL_CALL RestoreWindow
global rl_set_window_title
rl_set_window_title:              VL_CALL SetWindowTitle
global rl_set_window_position
rl_set_window_position:           VL_CALL SetWindowPosition
global rl_set_window_monitor
rl_set_window_monitor:            VL_CALL SetWindowMonitor
global rl_set_window_min_size
rl_set_window_min_size:           VL_CALL SetWindowMinSize
global rl_set_window_max_size
rl_set_window_max_size:           VL_CALL SetWindowMaxSize
global rl_set_window_size
rl_set_window_size:               VL_CALL SetWindowSize
; SetWindowOpacity(float opacity) — Velocity passes double bits in rdi
global rl_set_window_opacity
rl_set_window_opacity:
    movq    xmm0, rdi
    cvtsd2ss xmm0, xmm0
%ifdef WIN64_TARGET
    sub     rsp, 32
    call    SetWindowOpacity
    add     rsp, 32
%else
    sub     rsp, 8
    call    SetWindowOpacity
    add     rsp, 8
%endif
    ret
global rl_set_window_focused
rl_set_window_focused:            VL_CALL SetWindowFocused
global rl_get_screen_width
rl_get_screen_width:              VL_CALL GetScreenWidth
global rl_get_screen_height
rl_get_screen_height:             VL_CALL GetScreenHeight
global rl_get_render_width
rl_get_render_width:              VL_CALL GetRenderWidth
global rl_get_render_height
rl_get_render_height:             VL_CALL GetRenderHeight
global rl_get_monitor_count
rl_get_monitor_count:             VL_CALL GetMonitorCount
global rl_get_current_monitor
rl_get_current_monitor:           VL_CALL GetCurrentMonitor
global rl_get_monitor_width
rl_get_monitor_width:             VL_CALL GetMonitorWidth
global rl_get_monitor_height
rl_get_monitor_height:            VL_CALL GetMonitorHeight
global rl_get_monitor_refresh_rate
rl_get_monitor_refresh_rate:      VL_CALL GetMonitorRefreshRate
global rl_get_monitor_name
rl_get_monitor_name:              VL_CALL GetMonitorName
global rl_set_clipboard_text
rl_set_clipboard_text:            VL_CALL SetClipboardText
global rl_get_clipboard_text
rl_get_clipboard_text:            VL_CALL GetClipboardText
global rl_enable_event_waiting
rl_enable_event_waiting:          VL_CALL EnableEventWaiting
global rl_disable_event_waiting
rl_disable_event_waiting:         VL_CALL DisableEventWaiting

; ==== TIMING ====
global rl_set_target_fps
rl_set_target_fps:                VL_CALL SetTargetFPS
global rl_get_fps
rl_get_fps:                       VL_CALL GetFPS
global rl_get_frame_time
rl_get_frame_time:                VL_CALL_F GetFrameTime
global rl_get_time
rl_get_time:                      VL_CALL_FD GetTime
; WaitTime(double seconds) — Velocity passes double bits in rdi
global rl_wait_time
rl_wait_time:
    movq    xmm0, rdi
%ifdef WIN64_TARGET
    sub     rsp, 32
    call    WaitTime
    add     rsp, 32
%else
    sub     rsp, 8
    call    WaitTime
    add     rsp, 8
%endif
    ret

; ==== CONFIG ====
global rl_set_config_flags
rl_set_config_flags:              VL_CALL SetConfigFlags
global rl_set_trace_log_level
rl_set_trace_log_level:           VL_CALL SetTraceLogLevel
global rl_set_exit_key
rl_set_exit_key:                  VL_CALL SetExitKey

; ==== DRAWING PIPELINE ====
global rl_clear_background
rl_clear_background:              VL_CALL ClearBackground
global rl_begin_drawing
rl_begin_drawing:                 VL_CALL BeginDrawing
global rl_end_drawing
rl_end_drawing:                   VL_CALL EndDrawing
global rl_begin_mode2d
rl_begin_mode2d:                  VL_CALL BeginMode2D
global rl_end_mode2d
rl_end_mode2d:                    VL_CALL EndMode2D
global rl_begin_mode3d
rl_begin_mode3d:                  VL_CALL BeginMode3D
global rl_end_mode3d
rl_end_mode3d:                    VL_CALL EndMode3D
global rl_begin_texture_mode
rl_begin_texture_mode:            VL_CALL BeginTextureMode
global rl_end_texture_mode
rl_end_texture_mode:              VL_CALL EndTextureMode
global rl_begin_shader_mode
rl_begin_shader_mode:             VL_CALL BeginShaderMode
global rl_end_shader_mode
rl_end_shader_mode:               VL_CALL EndShaderMode
global rl_begin_blend_mode
rl_begin_blend_mode:              VL_CALL BeginBlendMode
global rl_end_blend_mode
rl_end_blend_mode:                VL_CALL EndBlendMode
global rl_begin_scissor_mode
rl_begin_scissor_mode:            VL_CALL BeginScissorMode
global rl_end_scissor_mode
rl_end_scissor_mode:              VL_CALL EndScissorMode

; ==== 2D SHAPES ====
; NOTE: Velocity passes ALL args in integer registers (rdi,rsi,rdx,rcx,r8,r9).
; Functions with float params need manual wrappers to move args into xmm registers.
; Pattern: cvtsi2ss converts int-register float bits into xmm for raylib's ABI.

global rl_draw_pixel
rl_draw_pixel:                    VL_CALL DrawPixel

; DrawLine(int x1, int y1, int x2, int y2, Color color)
; all ints + color — no float fixup needed
global rl_draw_line
rl_draw_line:                     VL_CALL DrawLine

; DrawLineEx(Vector2 start, Vector2 end, float thick, Color color)
; Vector2 args make this complex — passthrough, may not render correctly
global rl_draw_line_ex
rl_draw_line_ex:                  VL_CALL DrawLineEx

; DrawLineBezier(Vector2 start, Vector2 end, float thick, Color color)
; same as above
global rl_draw_line_bezier
rl_draw_line_bezier:              VL_CALL DrawLineBezier

; DrawCircle(int centerX, int centerY, float radius, Color color)
; Velocity codegen puts in registers:
;   rdi = int x (already converted from double via cvttsd2si) 
;   rsi = int y (already converted from double via cvttsd2si)
;   rdx = DOUBLE bits of radius (e.g. 20 → cvtsi2sd → 0x4034000000000000)
;   rcx = color (packed int)
; Raylib wants: rdi=int x, rsi=int y, xmm0=float radius, rdx=color
global rl_draw_circle
rl_draw_circle:
    movq    xmm0, rdx           ; load double bits of radius
    cvtsd2ss xmm0, xmm0         ; convert double → float
    mov     edx, ecx            ; color → rdx
%ifdef WIN64_TARGET
    sub     rsp, 32
    call    DrawCircle
    add     rsp, 32
%else
    sub     rsp, 8
    call    DrawCircle
    add     rsp, 8
%endif
    ret

; DrawCircleSector(Vector2 center, float radius, float startAngle, float endAngle, int segments, Color color)
; complex Vector2 struct args — passthrough
global rl_draw_circle_sector
rl_draw_circle_sector:            VL_CALL DrawCircleSector
global rl_draw_circle_sector_lines
rl_draw_circle_sector_lines:      VL_CALL DrawCircleSectorLines

; DrawCircleGradient(int x, int y, float radius, Color inner, Color outer)
; rdi=int x, rsi=int y, rdx=double bits radius, rcx=color1, r8=color2
global rl_draw_circle_gradient
rl_draw_circle_gradient:
    movq    xmm0, rdx
    cvtsd2ss xmm0, xmm0
    mov     edx, ecx
    mov     ecx, r8d
%ifdef WIN64_TARGET
    sub     rsp, 32
    call    DrawCircleGradient
    add     rsp, 32
%else
    sub     rsp, 8
    call    DrawCircleGradient
    add     rsp, 8
%endif
    ret

; DrawCircleLines(int centerX, int centerY, float radius, Color color)
; same pattern as DrawCircle
global rl_draw_circle_lines
rl_draw_circle_lines:
    movq    xmm0, rdx
    cvtsd2ss xmm0, xmm0
    mov     edx, ecx
%ifdef WIN64_TARGET
    sub     rsp, 32
    call    DrawCircleLines
    add     rsp, 32
%else
    sub     rsp, 8
    call    DrawCircleLines
    add     rsp, 8
%endif
    ret

; DrawEllipse(int centerX, int centerY, float radiusH, float radiusV, Color color)
; rdi=int x, rsi=int y, rdx=double bits radiusH, rcx=double bits radiusV, r8=color
global rl_draw_ellipse
rl_draw_ellipse:
    movq    xmm0, rdx
    cvtsd2ss xmm0, xmm0
    movq    xmm1, rcx
    cvtsd2ss xmm1, xmm1
    mov     edx, r8d
%ifdef WIN64_TARGET
    sub     rsp, 32
    call    DrawEllipse
    add     rsp, 32
%else
    sub     rsp, 8
    call    DrawEllipse
    add     rsp, 8
%endif
    ret

; DrawEllipseLines(int centerX, int centerY, float radiusH, float radiusV, Color color)
; same pattern as DrawEllipse
global rl_draw_ellipse_lines
rl_draw_ellipse_lines:
    movq    xmm0, rdx
    cvtsd2ss xmm0, xmm0
    movq    xmm1, rcx
    cvtsd2ss xmm1, xmm1
    mov     edx, r8d
%ifdef WIN64_TARGET
    sub     rsp, 32
    call    DrawEllipseLines
    add     rsp, 32
%else
    sub     rsp, 8
    call    DrawEllipseLines
    add     rsp, 8
%endif
    ret

; DrawRing / DrawRingLines — Vector2 center + multiple floats, complex
global rl_draw_ring
rl_draw_ring:                     VL_CALL DrawRing
global rl_draw_ring_lines
rl_draw_ring_lines:               VL_CALL DrawRingLines

; DrawRectangle(int x, int y, int width, int height, Color color)
; all ints + color — no float fixup needed
global rl_draw_rectangle
rl_draw_rectangle:                VL_CALL DrawRectangle

; DrawRectangleGradientV/H(int x, int y, int width, int height, Color color1, Color color2)
; all ints + 2 colors — no float fixup needed
global rl_draw_rectangle_gradient_v
rl_draw_rectangle_gradient_v:     VL_CALL DrawRectangleGradientV
global rl_draw_rectangle_gradient_h
rl_draw_rectangle_gradient_h:     VL_CALL DrawRectangleGradientH

; DrawRectangleLines(int x, int y, int width, int height, Color color)
; all ints — no float fixup needed
global rl_draw_rectangle_lines
rl_draw_rectangle_lines:          VL_CALL DrawRectangleLines

; DrawRectangleRounded(Rectangle rec, float roundness, int segments, Color color)
; Rectangle is a struct — complex
global rl_draw_rectangle_rounded
rl_draw_rectangle_rounded:        VL_CALL DrawRectangleRounded
global rl_draw_rectangle_rounded_lines
rl_draw_rectangle_rounded_lines:  VL_CALL DrawRectangleRoundedLines

; DrawTriangle(Vector2 v1, Vector2 v2, Vector2 v3, Color color) — Vector2 args, complex
global rl_draw_triangle
rl_draw_triangle:                 VL_CALL DrawTriangle
global rl_draw_triangle_lines
rl_draw_triangle_lines:           VL_CALL DrawTriangleLines

; DrawPoly(Vector2 center, int sides, float radius, float rotation, Color color)
; complex Vector2 + floats
global rl_draw_poly
rl_draw_poly:                     VL_CALL DrawPoly
global rl_draw_poly_lines
rl_draw_poly_lines:               VL_CALL DrawPolyLines
global rl_draw_poly_lines_ex
rl_draw_poly_lines_ex:            VL_CALL DrawPolyLinesEx

; ==== COLLISION 2D ====
global rl_check_collision_recs
rl_check_collision_recs:          VL_CALL CheckCollisionRecs
global rl_check_collision_circles
rl_check_collision_circles:       VL_CALL CheckCollisionCircles
global rl_check_collision_circle_rec
rl_check_collision_circle_rec:    VL_CALL CheckCollisionCircleRec
global rl_check_collision_point_rec
rl_check_collision_point_rec:     VL_CALL CheckCollisionPointRec
global rl_check_collision_point_circle
rl_check_collision_point_circle:  VL_CALL CheckCollisionPointCircle
global rl_check_collision_point_triangle
rl_check_collision_point_triangle: VL_CALL CheckCollisionPointTriangle
global rl_check_collision_lines
rl_check_collision_lines:         VL_CALL CheckCollisionLines
global rl_check_collision_point_line
rl_check_collision_point_line:    VL_CALL CheckCollisionPointLine
global rl_get_collision_rec
rl_get_collision_rec:             VL_CALL GetCollisionRec

; ==== TEXT ====
global rl_draw_fps
rl_draw_fps:                      VL_CALL DrawFPS
global rl_draw_text
rl_draw_text:                     VL_CALL DrawText
global rl_draw_text_ex
rl_draw_text_ex:                  VL_CALL DrawTextEx
global rl_draw_text_pro
rl_draw_text_pro:                 VL_CALL DrawTextPro
global rl_measure_text
rl_measure_text:                  VL_CALL MeasureText
global rl_measure_text_ex
rl_measure_text_ex:               VL_CALL MeasureTextEx
global rl_load_font
rl_load_font:                     VL_CALL LoadFont
global rl_load_font_ex
rl_load_font_ex:                  VL_CALL LoadFontEx
global rl_unload_font
rl_unload_font:                   VL_CALL UnloadFont
global rl_get_font_default
rl_get_font_default:              VL_CALL GetFontDefault
global rl_set_text_line_spacing
rl_set_text_line_spacing:         VL_CALL SetTextLineSpacing
global rl_get_glyph_index
rl_get_glyph_index:               VL_CALL GetGlyphIndex

; ==== TEXTURES ====
global rl_load_texture
rl_load_texture:                  VL_CALL LoadTexture
global rl_load_texture_from_image
rl_load_texture_from_image:       VL_CALL LoadTextureFromImage
global rl_load_render_texture
rl_load_render_texture:           VL_CALL LoadRenderTexture
global rl_is_texture_ready
rl_is_texture_ready:              VL_CALL IsTextureValid
global rl_unload_texture
rl_unload_texture:                VL_CALL UnloadTexture
global rl_unload_render_texture
rl_unload_render_texture:         VL_CALL UnloadRenderTexture
global rl_update_texture
rl_update_texture:                VL_CALL UpdateTexture
global rl_draw_texture
rl_draw_texture:                  VL_CALL DrawTexture
global rl_draw_texture_v
rl_draw_texture_v:                VL_CALL DrawTextureV
global rl_draw_texture_ex
rl_draw_texture_ex:               VL_CALL DrawTextureEx
global rl_draw_texture_rec
rl_draw_texture_rec:              VL_CALL DrawTextureRec
global rl_draw_texture_pro
rl_draw_texture_pro:              VL_CALL DrawTexturePro
global rl_draw_texture_npatch
rl_draw_texture_npatch:           VL_CALL DrawTextureNPatch
global rl_set_texture_filter
rl_set_texture_filter:            VL_CALL SetTextureFilter
global rl_set_texture_wrap
rl_set_texture_wrap:              VL_CALL SetTextureWrap
global rl_gen_texture_mipmaps
rl_gen_texture_mipmaps:           VL_CALL GenTextureMipmaps

; ==== IMAGES ====
global rl_load_image
rl_load_image:                    VL_CALL LoadImage
global rl_load_image_raw
rl_load_image_raw:                VL_CALL LoadImageRaw
global rl_is_image_ready
rl_is_image_ready:                VL_CALL IsImageValid
global rl_unload_image
rl_unload_image:                  VL_CALL UnloadImage
global rl_export_image
rl_export_image:                  VL_CALL ExportImage
global rl_gen_image_color
rl_gen_image_color:               VL_CALL GenImageColor
global rl_gen_image_gradient_linear
rl_gen_image_gradient_linear:     VL_CALL GenImageGradientLinear
global rl_gen_image_gradient_radial
rl_gen_image_gradient_radial:     VL_CALL GenImageGradientRadial
global rl_gen_image_checked
rl_gen_image_checked:             VL_CALL GenImageChecked
global rl_gen_image_white_noise
rl_gen_image_white_noise:         VL_CALL GenImageWhiteNoise
global rl_image_resize
rl_image_resize:                  VL_CALL ImageResize
global rl_image_flip_vertical
rl_image_flip_vertical:           VL_CALL ImageFlipVertical
global rl_image_flip_horizontal
rl_image_flip_horizontal:         VL_CALL ImageFlipHorizontal
global rl_image_rotate_cw
rl_image_rotate_cw:               VL_CALL ImageRotateCW
global rl_image_rotate_ccw
rl_image_rotate_ccw:              VL_CALL ImageRotateCCW
global rl_image_color_tint
rl_image_color_tint:              VL_CALL ImageColorTint
global rl_image_color_invert
rl_image_color_invert:            VL_CALL ImageColorInvert
global rl_image_color_grayscale
rl_image_color_grayscale:         VL_CALL ImageColorGrayscale
global rl_image_draw_rectangle
rl_image_draw_rectangle:          VL_CALL ImageDrawRectangle
global rl_image_draw_circle
rl_image_draw_circle:             VL_CALL ImageDrawCircle

; ==== COLORS ====
global rl_fade
rl_fade:                          VL_CALL Fade
global rl_color_to_int
rl_color_to_int:                  VL_CALL ColorToInt
global rl_color_tint
rl_color_tint:                    VL_CALL ColorTint
global rl_color_brightness
rl_color_brightness:              VL_CALL ColorBrightness
global rl_color_contrast
rl_color_contrast:                VL_CALL ColorContrast
global rl_color_alpha
rl_color_alpha:                   VL_CALL ColorAlpha
global rl_color_alpha_blend
rl_color_alpha_blend:             VL_CALL ColorAlphaBlend
global rl_get_color
rl_get_color:                     VL_CALL GetColor
global rl_get_pixel_color
rl_get_pixel_color:               VL_CALL GetPixelColor

; ==== 3D DRAWING ====
global rl_draw_line3d
rl_draw_line3d:                   VL_CALL DrawLine3D
global rl_draw_point3d
rl_draw_point3d:                  VL_CALL DrawPoint3D
global rl_draw_circle3d
rl_draw_circle3d:                 VL_CALL DrawCircle3D
global rl_draw_triangle3d
rl_draw_triangle3d:               VL_CALL DrawTriangle3D
global rl_draw_cube
rl_draw_cube:                     VL_CALL DrawCube
global rl_draw_cube_v
rl_draw_cube_v:                   VL_CALL DrawCubeV
global rl_draw_cube_wires
rl_draw_cube_wires:               VL_CALL DrawCubeWires
global rl_draw_cube_wires_v
rl_draw_cube_wires_v:             VL_CALL DrawCubeWiresV
global rl_draw_sphere
rl_draw_sphere:                   VL_CALL DrawSphere
global rl_draw_sphere_ex
rl_draw_sphere_ex:                VL_CALL DrawSphereEx
global rl_draw_sphere_wires
rl_draw_sphere_wires:             VL_CALL DrawSphereWires
global rl_draw_cylinder
rl_draw_cylinder:                 VL_CALL DrawCylinder
global rl_draw_cylinder_ex
rl_draw_cylinder_ex:              VL_CALL DrawCylinderEx
global rl_draw_cylinder_wires
rl_draw_cylinder_wires:           VL_CALL DrawCylinderWires
global rl_draw_cylinder_wires_ex
rl_draw_cylinder_wires_ex:        VL_CALL DrawCylinderWiresEx
global rl_draw_capsule
rl_draw_capsule:                  VL_CALL DrawCapsule
global rl_draw_capsule_wires
rl_draw_capsule_wires:            VL_CALL DrawCapsuleWires
global rl_draw_plane
rl_draw_plane:                    VL_CALL DrawPlane
global rl_draw_ray
rl_draw_ray:                      VL_CALL DrawRay
global rl_draw_grid
rl_draw_grid:                     VL_CALL DrawGrid
global rl_draw_bounding_box
rl_draw_bounding_box:             VL_CALL DrawBoundingBox

; ==== MODEL / MESH ====
global rl_load_model
rl_load_model:                    VL_CALL LoadModel
global rl_load_model_from_mesh
rl_load_model_from_mesh:          VL_CALL LoadModelFromMesh
global rl_is_model_ready
rl_is_model_ready:                VL_CALL IsModelValid
global rl_unload_model
rl_unload_model:                  VL_CALL UnloadModel
global rl_get_model_bounding_box
rl_get_model_bounding_box:        VL_CALL GetModelBoundingBox
global rl_draw_model
rl_draw_model:                    VL_CALL DrawModel
global rl_draw_model_ex
rl_draw_model_ex:                 VL_CALL DrawModelEx
global rl_draw_model_wires
rl_draw_model_wires:              VL_CALL DrawModelWires
global rl_draw_model_wires_ex
rl_draw_model_wires_ex:           VL_CALL DrawModelWiresEx
global rl_draw_billboard
rl_draw_billboard:                VL_CALL DrawBillboard
global rl_draw_billboard_rec
rl_draw_billboard_rec:            VL_CALL DrawBillboardRec
global rl_upload_mesh
rl_upload_mesh:                   VL_CALL UploadMesh
global rl_unload_mesh
rl_unload_mesh:                   VL_CALL UnloadMesh
global rl_draw_mesh
rl_draw_mesh:                     VL_CALL DrawMesh
global rl_gen_mesh_poly
rl_gen_mesh_poly:                 VL_CALL GenMeshPoly
global rl_gen_mesh_plane
rl_gen_mesh_plane:                VL_CALL GenMeshPlane
global rl_gen_mesh_cube
rl_gen_mesh_cube:                 VL_CALL GenMeshCube
global rl_gen_mesh_sphere
rl_gen_mesh_sphere:               VL_CALL GenMeshSphere
global rl_gen_mesh_hemi_sphere
rl_gen_mesh_hemi_sphere:          VL_CALL GenMeshHemiSphere
global rl_gen_mesh_cylinder
rl_gen_mesh_cylinder:             VL_CALL GenMeshCylinder
global rl_gen_mesh_cone
rl_gen_mesh_cone:                 VL_CALL GenMeshCone
global rl_gen_mesh_torus
rl_gen_mesh_torus:                VL_CALL GenMeshTorus
global rl_gen_mesh_knot
rl_gen_mesh_knot:                 VL_CALL GenMeshKnot
global rl_gen_mesh_heightmap
rl_gen_mesh_heightmap:            VL_CALL GenMeshHeightmap
global rl_gen_mesh_cubicmap
rl_gen_mesh_cubicmap:             VL_CALL GenMeshCubicmap
global rl_load_material_default
rl_load_material_default:         VL_CALL LoadMaterialDefault
global rl_unload_material
rl_unload_material:               VL_CALL UnloadMaterial
global rl_set_material_texture
rl_set_material_texture:          VL_CALL SetMaterialTexture
global rl_set_model_mesh_material
rl_set_model_mesh_material:       VL_CALL SetModelMeshMaterial
global rl_update_model_animation
rl_update_model_animation:        VL_CALL UpdateModelAnimation
;global rl_unload_model_animation
;rl_unload_model_animation:        VL_CALL UnloadModelAnimation

; ==== CAMERA ====
global rl_update_camera
rl_update_camera:                 VL_CALL UpdateCamera
global rl_update_camera_pro
rl_update_camera_pro:             VL_CALL UpdateCameraPro

; ==== SHADERS ====
global rl_load_shader
rl_load_shader:                   VL_CALL LoadShader
global rl_load_shader_from_memory
rl_load_shader_from_memory:       VL_CALL LoadShaderFromMemory
global rl_is_shader_ready
rl_is_shader_ready:               VL_CALL IsShaderValid
global rl_unload_shader
rl_unload_shader:                 VL_CALL UnloadShader
global rl_get_shader_location
rl_get_shader_location:           VL_CALL GetShaderLocation
global rl_set_shader_value
rl_set_shader_value:              VL_CALL SetShaderValue
global rl_set_shader_value_matrix
rl_set_shader_value_matrix:       VL_CALL SetShaderValueMatrix
global rl_set_shader_value_texture
rl_set_shader_value_texture:      VL_CALL SetShaderValueTexture

; ==== COLLISION 3D ====
global rl_check_collision_spheres
rl_check_collision_spheres:       VL_CALL CheckCollisionSpheres
global rl_check_collision_boxes
rl_check_collision_boxes:         VL_CALL CheckCollisionBoxes
global rl_check_collision_box_sphere
rl_check_collision_box_sphere:    VL_CALL CheckCollisionBoxSphere
global rl_get_ray_collision_sphere
rl_get_ray_collision_sphere:      VL_CALL GetRayCollisionSphere
global rl_get_ray_collision_box
rl_get_ray_collision_box:         VL_CALL GetRayCollisionBox
global rl_get_ray_collision_mesh
rl_get_ray_collision_mesh:        VL_CALL GetRayCollisionMesh
global rl_get_ray_collision_triangle
rl_get_ray_collision_triangle:    VL_CALL GetRayCollisionTriangle
global rl_get_ray_collision_quad
rl_get_ray_collision_quad:        VL_CALL GetRayCollisionQuad

; ==== INPUT: KEYBOARD ====
global rl_is_key_pressed
rl_is_key_pressed:                VL_CALL IsKeyPressed
global rl_is_key_pressed_repeat
rl_is_key_pressed_repeat:         VL_CALL IsKeyPressedRepeat
global rl_is_key_down
rl_is_key_down:                   VL_CALL IsKeyDown
global rl_key_held
rl_key_held:                      VL_CALL IsKeyDown
global rl_is_key_released
rl_is_key_released:               VL_CALL IsKeyReleased
global rl_is_key_up
rl_is_key_up:                     VL_CALL IsKeyUp
global rl_get_key_pressed
rl_get_key_pressed:               VL_CALL GetKeyPressed
global rl_get_char_pressed
rl_get_char_pressed:              VL_CALL GetCharPressed

; ==== INPUT: MOUSE ====
global rl_is_mouse_button_pressed
rl_is_mouse_button_pressed:       VL_CALL IsMouseButtonPressed
global rl_is_mouse_button_down
rl_is_mouse_button_down:          VL_CALL IsMouseButtonDown
global rl_is_mouse_button_released
rl_is_mouse_button_released:      VL_CALL IsMouseButtonReleased
global rl_is_mouse_button_up
rl_is_mouse_button_up:            VL_CALL IsMouseButtonUp
global rl_get_mouse_x
rl_get_mouse_x:                   VL_CALL GetMouseX
global rl_get_mouse_y
rl_get_mouse_y:                   VL_CALL GetMouseY
global rl_get_mouse_wheel_move
rl_get_mouse_wheel_move:          VL_CALL_F GetMouseWheelMove
global rl_set_mouse_position
rl_set_mouse_position:            VL_CALL SetMousePosition
global rl_set_mouse_offset
rl_set_mouse_offset:              VL_CALL SetMouseOffset
global rl_set_mouse_scale
rl_set_mouse_scale:               VL_CALL SetMouseScale
global rl_set_mouse_cursor
rl_set_mouse_cursor:              VL_CALL SetMouseCursor
global rl_get_touch_x
rl_get_touch_x:                   VL_CALL GetTouchX
global rl_get_touch_y
rl_get_touch_y:                   VL_CALL GetTouchY
global rl_get_touch_point_count
rl_get_touch_point_count:         VL_CALL GetTouchPointCount

; ==== INPUT: GAMEPAD ====
global rl_is_gamepad_available
rl_is_gamepad_available:          VL_CALL IsGamepadAvailable
global rl_is_gamepad_button_pressed
rl_is_gamepad_button_pressed:     VL_CALL IsGamepadButtonPressed
global rl_is_gamepad_button_down
rl_is_gamepad_button_down:        VL_CALL IsGamepadButtonDown
global rl_is_gamepad_button_released
rl_is_gamepad_button_released:    VL_CALL IsGamepadButtonReleased
global rl_is_gamepad_button_up
rl_is_gamepad_button_up:          VL_CALL IsGamepadButtonUp
global rl_get_gamepad_button_pressed
rl_get_gamepad_button_pressed:    VL_CALL GetGamepadButtonPressed
global rl_get_gamepad_axis_count
rl_get_gamepad_axis_count:        VL_CALL GetGamepadAxisCount
global rl_get_gamepad_axis_movement
rl_get_gamepad_axis_movement:     VL_CALL_F GetGamepadAxisMovement
global rl_set_gamepad_vibration
rl_set_gamepad_vibration:         VL_CALL SetGamepadVibration

; ==== AUDIO ====
global rl_init_audio_device
rl_init_audio_device:             VL_CALL InitAudioDevice
global rl_close_audio_device
rl_close_audio_device:            VL_CALL CloseAudioDevice
global rl_is_audio_device_ready
rl_is_audio_device_ready:         VL_CALL IsAudioDeviceReady
global rl_set_master_volume
rl_set_master_volume:             VL_CALL SetMasterVolume
global rl_get_master_volume
rl_get_master_volume:             VL_CALL_F GetMasterVolume
global rl_load_sound
rl_load_sound:                    VL_CALL LoadSound
global rl_load_sound_from_wave
rl_load_sound_from_wave:          VL_CALL LoadSoundFromWave
global rl_is_sound_ready
rl_is_sound_ready:                VL_CALL IsSoundValid
global rl_update_sound
rl_update_sound:                  VL_CALL UpdateSound
global rl_unload_sound
rl_unload_sound:                  VL_CALL UnloadSound
global rl_play_sound
rl_play_sound:                    VL_CALL PlaySound
global rl_stop_sound
rl_stop_sound:                    VL_CALL StopSound
global rl_pause_sound
rl_pause_sound:                   VL_CALL PauseSound
global rl_resume_sound
rl_resume_sound:                  VL_CALL ResumeSound
global rl_is_sound_playing
rl_is_sound_playing:              VL_CALL IsSoundPlaying
global rl_set_sound_volume
rl_set_sound_volume:              VL_CALL SetSoundVolume
global rl_set_sound_pitch
rl_set_sound_pitch:               VL_CALL SetSoundPitch
global rl_set_sound_pan
rl_set_sound_pan:                 VL_CALL SetSoundPan
global rl_load_wave
rl_load_wave:                     VL_CALL LoadWave
global rl_is_wave_ready
rl_is_wave_ready:                 VL_CALL IsWaveValid
global rl_unload_wave
rl_unload_wave:                   VL_CALL UnloadWave
global rl_export_wave
rl_export_wave:                   VL_CALL ExportWave
global rl_load_music_stream
rl_load_music_stream:             VL_CALL LoadMusicStream
global rl_is_music_ready
rl_is_music_ready:                VL_CALL IsMusicValid
global rl_unload_music_stream
rl_unload_music_stream:           VL_CALL UnloadMusicStream
global rl_play_music_stream
rl_play_music_stream:             VL_CALL PlayMusicStream
global rl_is_music_stream_playing
rl_is_music_stream_playing:       VL_CALL IsMusicStreamPlaying
global rl_update_music_stream
rl_update_music_stream:           VL_CALL UpdateMusicStream
global rl_stop_music_stream
rl_stop_music_stream:             VL_CALL StopMusicStream
global rl_pause_music_stream
rl_pause_music_stream:            VL_CALL PauseMusicStream
global rl_resume_music_stream
rl_resume_music_stream:           VL_CALL ResumeMusicStream
global rl_seek_music_stream
rl_seek_music_stream:             VL_CALL SeekMusicStream
global rl_set_music_volume
rl_set_music_volume:              VL_CALL SetMusicVolume
global rl_set_music_pitch
rl_set_music_pitch:               VL_CALL SetMusicPitch
global rl_set_music_pan
rl_set_music_pan:                 VL_CALL SetMusicPan
global rl_get_music_time_length
rl_get_music_time_length:         VL_CALL_FD GetMusicTimeLength
global rl_get_music_time_played
rl_get_music_time_played:         VL_CALL_FD GetMusicTimePlayed

; ==== UTILITY ====
global rl_get_random_value
rl_get_random_value:              VL_CALL GetRandomValue
global rl_set_random_seed
rl_set_random_seed:               VL_CALL SetRandomSeed
global rl_take_screenshot
rl_take_screenshot:               VL_CALL TakeScreenshot
global rl_open_url
rl_open_url:                      VL_CALL OpenURL

; ==== COLOR PACK HELPERS (pure asm) ====
; Velocity color = packed adad: r | g<<8 | b<<16 | a<<24
global rl_color_rgba
rl_color_rgba:
%ifdef WIN64_TARGET
    movzx rax, cl
    movzx rcx, dl
    shl   rcx, 8
    or    rax, rcx
    movzx r8,  r8b
    shl   r8,  16
    or    rax, r8
    movzx r9,  r9b
    shl   r9,  24
    or    rax, r9
%else
    movzx rax, dil
    movzx rsi, sil
    shl   rsi, 8
    or    rax, rsi
    movzx rdx, dl
    shl   rdx, 16
    or    rax, rdx
    movzx rcx, cl
    shl   rcx, 24
    or    rax, rcx
%endif
    ret

global rl_color_black
rl_color_black:       mov eax, 0xFF000000
                      ret
global rl_color_white
rl_color_white:       mov eax, 0xFFFFFFFF
                      ret
global rl_color_red
rl_color_red:         mov eax, 0xFF0000FF
                      ret
global rl_color_green
rl_color_green:       mov eax, 0xFF00FF00
                      ret
global rl_color_blue
rl_color_blue:        mov eax, 0xFFFF0000
                      ret
global rl_color_yellow
rl_color_yellow:      mov eax, 0xFF00FFFF
                      ret
global rl_color_orange
rl_color_orange:      mov eax, 0xFF00A5FF
                      ret
global rl_color_purple
rl_color_purple:      mov eax, 0xFF800080
                      ret
global rl_color_magenta
rl_color_magenta:     mov eax, 0xFFFF00FF
                      ret
global rl_color_gray
rl_color_gray:        mov eax, 0xFF808080
                      ret
global rl_color_darkgray
rl_color_darkgray:    mov eax, 0xFF404040
                      ret
global rl_color_lightgray
rl_color_lightgray:   mov eax, 0xFFC8C8C8
                      ret
global rl_color_skyblue
rl_color_skyblue:     mov eax, 0xFFEBCE66
                      ret
global rl_color_lime
rl_color_lime:        mov eax, 0xFF00FF00
                      ret
global rl_color_gold
rl_color_gold:        mov eax, 0xFF00D7FF
                      ret
global rl_color_pink
rl_color_pink:        mov eax, 0xFFC8AFFF
                      ret
global rl_color_maroon
rl_color_maroon:      mov eax, 0xFF000080
                      ret
global rl_color_beige
rl_color_beige:       mov eax, 0xFFDCF5F5
                      ret
global rl_color_brown
rl_color_brown:       mov eax, 0xFF2A527D
                      ret
global rl_color_darkbrown
rl_color_darkbrown:   mov eax, 0xFF1A3076
                      ret
global rl_color_darkblue
rl_color_darkblue:    mov eax, 0xFF8B0000
                      ret
global rl_color_darkgreen
rl_color_darkgreen:   mov eax, 0xFF006400
                      ret
global rl_color_darkpurple
rl_color_darkpurple:  mov eax, 0xFF701112
                      ret
global rl_color_violet
rl_color_violet:      mov eax, 0xFFFF00EE
                      ret
global rl_color_transparent
rl_color_transparent: xor eax, eax
                      ret


; ==== VELOCITY COMPILER ALIASES (raylib__* -> rl_*) ====
global raylib__init_window
raylib__init_window equ rl_init_window
global raylib__close_window
raylib__close_window equ rl_close_window
global raylib__window_should_close
raylib__window_should_close equ rl_window_should_close
global raylib__is_window_ready
raylib__is_window_ready equ rl_is_window_ready
global raylib__is_window_fullscreen
raylib__is_window_fullscreen equ rl_is_window_fullscreen
global raylib__is_window_hidden
raylib__is_window_hidden equ rl_is_window_hidden
global raylib__is_window_minimized
raylib__is_window_minimized equ rl_is_window_minimized
global raylib__is_window_maximized
raylib__is_window_maximized equ rl_is_window_maximized
global raylib__is_window_focused
raylib__is_window_focused equ rl_is_window_focused
global raylib__is_window_resized
raylib__is_window_resized equ rl_is_window_resized
global raylib__set_window_state
raylib__set_window_state equ rl_set_window_state
global raylib__clear_window_state
raylib__clear_window_state equ rl_clear_window_state
global raylib__toggle_fullscreen
raylib__toggle_fullscreen equ rl_toggle_fullscreen
global raylib__toggle_borderless_windowed
raylib__toggle_borderless_windowed equ rl_toggle_borderless_windowed
global raylib__maximize_window
raylib__maximize_window equ rl_maximize_window
global raylib__minimize_window
raylib__minimize_window equ rl_minimize_window
global raylib__restore_window
raylib__restore_window equ rl_restore_window
global raylib__set_window_title
raylib__set_window_title equ rl_set_window_title
global raylib__set_window_position
raylib__set_window_position equ rl_set_window_position
global raylib__set_window_monitor
raylib__set_window_monitor equ rl_set_window_monitor
global raylib__set_window_min_size
raylib__set_window_min_size equ rl_set_window_min_size
global raylib__set_window_max_size
raylib__set_window_max_size equ rl_set_window_max_size
global raylib__set_window_size
raylib__set_window_size equ rl_set_window_size
global raylib__set_window_opacity
raylib__set_window_opacity equ rl_set_window_opacity
global raylib__set_window_focused
raylib__set_window_focused equ rl_set_window_focused
global raylib__get_screen_width
raylib__get_screen_width equ rl_get_screen_width
global raylib__get_screen_height
raylib__get_screen_height equ rl_get_screen_height
global raylib__get_render_width
raylib__get_render_width equ rl_get_render_width
global raylib__get_render_height
raylib__get_render_height equ rl_get_render_height
global raylib__get_monitor_count
raylib__get_monitor_count equ rl_get_monitor_count
global raylib__get_current_monitor
raylib__get_current_monitor equ rl_get_current_monitor
global raylib__get_monitor_width
raylib__get_monitor_width equ rl_get_monitor_width
global raylib__get_monitor_height
raylib__get_monitor_height equ rl_get_monitor_height
global raylib__get_monitor_refresh_rate
raylib__get_monitor_refresh_rate equ rl_get_monitor_refresh_rate
global raylib__get_monitor_name
raylib__get_monitor_name equ rl_get_monitor_name
global raylib__set_clipboard_text
raylib__set_clipboard_text equ rl_set_clipboard_text
global raylib__get_clipboard_text
raylib__get_clipboard_text equ rl_get_clipboard_text
global raylib__enable_event_waiting
raylib__enable_event_waiting equ rl_enable_event_waiting
global raylib__disable_event_waiting
raylib__disable_event_waiting equ rl_disable_event_waiting
global raylib__set_target_fps
raylib__set_target_fps equ rl_set_target_fps
global raylib__get_fps
raylib__get_fps equ rl_get_fps
global raylib__get_frame_time
raylib__get_frame_time equ rl_get_frame_time
global raylib__get_time
raylib__get_time equ rl_get_time
global raylib__wait_time
raylib__wait_time equ rl_wait_time
global raylib__set_config_flags
raylib__set_config_flags equ rl_set_config_flags
global raylib__set_trace_log_level
raylib__set_trace_log_level equ rl_set_trace_log_level
global raylib__set_exit_key
raylib__set_exit_key equ rl_set_exit_key
global raylib__clear_background
raylib__clear_background equ rl_clear_background
global raylib__begin_drawing
raylib__begin_drawing equ rl_begin_drawing
global raylib__end_drawing
raylib__end_drawing equ rl_end_drawing
global raylib__begin_mode2d
raylib__begin_mode2d equ rl_begin_mode2d
global raylib__end_mode2d
raylib__end_mode2d equ rl_end_mode2d
global raylib__begin_mode3d
raylib__begin_mode3d equ rl_begin_mode3d
global raylib__end_mode3d
raylib__end_mode3d equ rl_end_mode3d
global raylib__begin_texture_mode
raylib__begin_texture_mode equ rl_begin_texture_mode
global raylib__end_texture_mode
raylib__end_texture_mode equ rl_end_texture_mode
global raylib__begin_shader_mode
raylib__begin_shader_mode equ rl_begin_shader_mode
global raylib__end_shader_mode
raylib__end_shader_mode equ rl_end_shader_mode
global raylib__begin_blend_mode
raylib__begin_blend_mode equ rl_begin_blend_mode
global raylib__end_blend_mode
raylib__end_blend_mode equ rl_end_blend_mode
global raylib__begin_scissor_mode
raylib__begin_scissor_mode equ rl_begin_scissor_mode
global raylib__end_scissor_mode
raylib__end_scissor_mode equ rl_end_scissor_mode
global raylib__draw_pixel
raylib__draw_pixel equ rl_draw_pixel
global raylib__draw_line
raylib__draw_line equ rl_draw_line
global raylib__draw_line_ex
raylib__draw_line_ex equ rl_draw_line_ex
global raylib__draw_line_bezier
raylib__draw_line_bezier equ rl_draw_line_bezier
global raylib__draw_circle
raylib__draw_circle equ rl_draw_circle
global raylib__draw_circle_sector
raylib__draw_circle_sector equ rl_draw_circle_sector
global raylib__draw_circle_sector_lines
raylib__draw_circle_sector_lines equ rl_draw_circle_sector_lines
global raylib__draw_circle_gradient
raylib__draw_circle_gradient equ rl_draw_circle_gradient
global raylib__draw_circle_lines
raylib__draw_circle_lines equ rl_draw_circle_lines
global raylib__draw_ellipse
raylib__draw_ellipse equ rl_draw_ellipse
global raylib__draw_ellipse_lines
raylib__draw_ellipse_lines equ rl_draw_ellipse_lines
global raylib__draw_ring
raylib__draw_ring equ rl_draw_ring
global raylib__draw_ring_lines
raylib__draw_ring_lines equ rl_draw_ring_lines
global raylib__draw_rectangle
raylib__draw_rectangle equ rl_draw_rectangle
global raylib__draw_rectangle_gradient_v
raylib__draw_rectangle_gradient_v equ rl_draw_rectangle_gradient_v
global raylib__draw_rectangle_gradient_h
raylib__draw_rectangle_gradient_h equ rl_draw_rectangle_gradient_h
global raylib__draw_rectangle_lines
raylib__draw_rectangle_lines equ rl_draw_rectangle_lines
global raylib__draw_rectangle_rounded
raylib__draw_rectangle_rounded equ rl_draw_rectangle_rounded
global raylib__draw_rectangle_rounded_lines
raylib__draw_rectangle_rounded_lines equ rl_draw_rectangle_rounded_lines
global raylib__draw_triangle
raylib__draw_triangle equ rl_draw_triangle
global raylib__draw_triangle_lines
raylib__draw_triangle_lines equ rl_draw_triangle_lines
global raylib__draw_poly
raylib__draw_poly equ rl_draw_poly
global raylib__draw_poly_lines
raylib__draw_poly_lines equ rl_draw_poly_lines
global raylib__draw_poly_lines_ex
raylib__draw_poly_lines_ex equ rl_draw_poly_lines_ex
global raylib__check_collision_recs
raylib__check_collision_recs equ rl_check_collision_recs
global raylib__check_collision_circles
raylib__check_collision_circles equ rl_check_collision_circles
global raylib__check_collision_circle_rec
raylib__check_collision_circle_rec equ rl_check_collision_circle_rec
global raylib__check_collision_point_rec
raylib__check_collision_point_rec equ rl_check_collision_point_rec
global raylib__check_collision_point_circle
raylib__check_collision_point_circle equ rl_check_collision_point_circle
global raylib__check_collision_point_triangle
raylib__check_collision_point_triangle equ rl_check_collision_point_triangle
global raylib__check_collision_lines
raylib__check_collision_lines equ rl_check_collision_lines
global raylib__check_collision_point_line
raylib__check_collision_point_line equ rl_check_collision_point_line
global raylib__get_collision_rec
raylib__get_collision_rec equ rl_get_collision_rec
global raylib__draw_fps
raylib__draw_fps equ rl_draw_fps
global raylib__draw_text
raylib__draw_text equ rl_draw_text
global raylib__draw_text_ex
raylib__draw_text_ex equ rl_draw_text_ex
global raylib__draw_text_pro
raylib__draw_text_pro equ rl_draw_text_pro
global raylib__measure_text
raylib__measure_text equ rl_measure_text
global raylib__measure_text_ex
raylib__measure_text_ex equ rl_measure_text_ex
global raylib__load_font
raylib__load_font equ rl_load_font
global raylib__load_font_ex
raylib__load_font_ex equ rl_load_font_ex
global raylib__unload_font
raylib__unload_font equ rl_unload_font
global raylib__get_font_default
raylib__get_font_default equ rl_get_font_default
global raylib__set_text_line_spacing
raylib__set_text_line_spacing equ rl_set_text_line_spacing
global raylib__get_glyph_index
raylib__get_glyph_index equ rl_get_glyph_index
global raylib__load_texture
raylib__load_texture equ rl_load_texture
global raylib__load_texture_from_image
raylib__load_texture_from_image equ rl_load_texture_from_image
global raylib__load_render_texture
raylib__load_render_texture equ rl_load_render_texture
global raylib__is_texture_ready
raylib__is_texture_ready equ rl_is_texture_ready
global raylib__unload_texture
raylib__unload_texture equ rl_unload_texture
global raylib__unload_render_texture
raylib__unload_render_texture equ rl_unload_render_texture
global raylib__update_texture
raylib__update_texture equ rl_update_texture
global raylib__draw_texture
raylib__draw_texture equ rl_draw_texture
global raylib__draw_texture_v
raylib__draw_texture_v equ rl_draw_texture_v
global raylib__draw_texture_ex
raylib__draw_texture_ex equ rl_draw_texture_ex
global raylib__draw_texture_rec
raylib__draw_texture_rec equ rl_draw_texture_rec
global raylib__draw_texture_pro
raylib__draw_texture_pro equ rl_draw_texture_pro
global raylib__draw_texture_npatch
raylib__draw_texture_npatch equ rl_draw_texture_npatch
global raylib__set_texture_filter
raylib__set_texture_filter equ rl_set_texture_filter
global raylib__set_texture_wrap
raylib__set_texture_wrap equ rl_set_texture_wrap
global raylib__gen_texture_mipmaps
raylib__gen_texture_mipmaps equ rl_gen_texture_mipmaps
global raylib__load_image
raylib__load_image equ rl_load_image
global raylib__load_image_raw
raylib__load_image_raw equ rl_load_image_raw
global raylib__is_image_ready
raylib__is_image_ready equ rl_is_image_ready
global raylib__unload_image
raylib__unload_image equ rl_unload_image
global raylib__export_image
raylib__export_image equ rl_export_image
global raylib__gen_image_color
raylib__gen_image_color equ rl_gen_image_color
global raylib__gen_image_gradient_linear
raylib__gen_image_gradient_linear equ rl_gen_image_gradient_linear
global raylib__gen_image_gradient_radial
raylib__gen_image_gradient_radial equ rl_gen_image_gradient_radial
global raylib__gen_image_checked
raylib__gen_image_checked equ rl_gen_image_checked
global raylib__gen_image_white_noise
raylib__gen_image_white_noise equ rl_gen_image_white_noise
global raylib__image_resize
raylib__image_resize equ rl_image_resize
global raylib__image_flip_vertical
raylib__image_flip_vertical equ rl_image_flip_vertical
global raylib__image_flip_horizontal
raylib__image_flip_horizontal equ rl_image_flip_horizontal
global raylib__image_rotate_cw
raylib__image_rotate_cw equ rl_image_rotate_cw
global raylib__image_rotate_ccw
raylib__image_rotate_ccw equ rl_image_rotate_ccw
global raylib__image_color_tint
raylib__image_color_tint equ rl_image_color_tint
global raylib__image_color_invert
raylib__image_color_invert equ rl_image_color_invert
global raylib__image_color_grayscale
raylib__image_color_grayscale equ rl_image_color_grayscale
global raylib__image_draw_rectangle
raylib__image_draw_rectangle equ rl_image_draw_rectangle
global raylib__image_draw_circle
raylib__image_draw_circle equ rl_image_draw_circle
global raylib__fade
raylib__fade equ rl_fade
global raylib__color_to_int
raylib__color_to_int equ rl_color_to_int
global raylib__color_tint
raylib__color_tint equ rl_color_tint
global raylib__color_brightness
raylib__color_brightness equ rl_color_brightness
global raylib__color_contrast
raylib__color_contrast equ rl_color_contrast
global raylib__color_alpha
raylib__color_alpha equ rl_color_alpha
global raylib__color_alpha_blend
raylib__color_alpha_blend equ rl_color_alpha_blend
global raylib__get_color
raylib__get_color equ rl_get_color
global raylib__get_pixel_color
raylib__get_pixel_color equ rl_get_pixel_color
global raylib__draw_line3d
raylib__draw_line3d equ rl_draw_line3d
global raylib__draw_point3d
raylib__draw_point3d equ rl_draw_point3d
global raylib__draw_circle3d
raylib__draw_circle3d equ rl_draw_circle3d
global raylib__draw_triangle3d
raylib__draw_triangle3d equ rl_draw_triangle3d
global raylib__draw_cube
raylib__draw_cube equ rl_draw_cube
global raylib__draw_cube_v
raylib__draw_cube_v equ rl_draw_cube_v
global raylib__draw_cube_wires
raylib__draw_cube_wires equ rl_draw_cube_wires
global raylib__draw_cube_wires_v
raylib__draw_cube_wires_v equ rl_draw_cube_wires_v
global raylib__draw_sphere
raylib__draw_sphere equ rl_draw_sphere
global raylib__draw_sphere_ex
raylib__draw_sphere_ex equ rl_draw_sphere_ex
global raylib__draw_sphere_wires
raylib__draw_sphere_wires equ rl_draw_sphere_wires
global raylib__draw_cylinder
raylib__draw_cylinder equ rl_draw_cylinder
global raylib__draw_cylinder_ex
raylib__draw_cylinder_ex equ rl_draw_cylinder_ex
global raylib__draw_cylinder_wires
raylib__draw_cylinder_wires equ rl_draw_cylinder_wires
global raylib__draw_cylinder_wires_ex
raylib__draw_cylinder_wires_ex equ rl_draw_cylinder_wires_ex
global raylib__draw_capsule
raylib__draw_capsule equ rl_draw_capsule
global raylib__draw_capsule_wires
raylib__draw_capsule_wires equ rl_draw_capsule_wires
global raylib__draw_plane
raylib__draw_plane equ rl_draw_plane
global raylib__draw_ray
raylib__draw_ray equ rl_draw_ray
global raylib__draw_grid
raylib__draw_grid equ rl_draw_grid
global raylib__draw_bounding_box
raylib__draw_bounding_box equ rl_draw_bounding_box
global raylib__load_model
raylib__load_model equ rl_load_model
global raylib__load_model_from_mesh
raylib__load_model_from_mesh equ rl_load_model_from_mesh
global raylib__is_model_ready
raylib__is_model_ready equ rl_is_model_ready
global raylib__unload_model
raylib__unload_model equ rl_unload_model
global raylib__get_model_bounding_box
raylib__get_model_bounding_box equ rl_get_model_bounding_box
global raylib__draw_model
raylib__draw_model equ rl_draw_model
global raylib__draw_model_ex
raylib__draw_model_ex equ rl_draw_model_ex
global raylib__draw_model_wires
raylib__draw_model_wires equ rl_draw_model_wires
global raylib__draw_model_wires_ex
raylib__draw_model_wires_ex equ rl_draw_model_wires_ex
global raylib__draw_billboard
raylib__draw_billboard equ rl_draw_billboard
global raylib__draw_billboard_rec
raylib__draw_billboard_rec equ rl_draw_billboard_rec
global raylib__upload_mesh
raylib__upload_mesh equ rl_upload_mesh
global raylib__unload_mesh
raylib__unload_mesh equ rl_unload_mesh
global raylib__draw_mesh
raylib__draw_mesh equ rl_draw_mesh
global raylib__gen_mesh_poly
raylib__gen_mesh_poly equ rl_gen_mesh_poly
global raylib__gen_mesh_plane
raylib__gen_mesh_plane equ rl_gen_mesh_plane
global raylib__gen_mesh_cube
raylib__gen_mesh_cube equ rl_gen_mesh_cube
global raylib__gen_mesh_sphere
raylib__gen_mesh_sphere equ rl_gen_mesh_sphere
global raylib__gen_mesh_hemi_sphere
raylib__gen_mesh_hemi_sphere equ rl_gen_mesh_hemi_sphere
global raylib__gen_mesh_cylinder
raylib__gen_mesh_cylinder equ rl_gen_mesh_cylinder
global raylib__gen_mesh_cone
raylib__gen_mesh_cone equ rl_gen_mesh_cone
global raylib__gen_mesh_torus
raylib__gen_mesh_torus equ rl_gen_mesh_torus
global raylib__gen_mesh_knot
raylib__gen_mesh_knot equ rl_gen_mesh_knot
global raylib__gen_mesh_heightmap
raylib__gen_mesh_heightmap equ rl_gen_mesh_heightmap
global raylib__gen_mesh_cubicmap
raylib__gen_mesh_cubicmap equ rl_gen_mesh_cubicmap
global raylib__load_material_default
raylib__load_material_default equ rl_load_material_default
global raylib__unload_material
raylib__unload_material equ rl_unload_material
global raylib__set_material_texture
raylib__set_material_texture equ rl_set_material_texture
global raylib__set_model_mesh_material
raylib__set_model_mesh_material equ rl_set_model_mesh_material
global raylib__update_model_animation
raylib__update_model_animation equ rl_update_model_animation
global raylib__update_camera
raylib__update_camera equ rl_update_camera
global raylib__update_camera_pro
raylib__update_camera_pro equ rl_update_camera_pro
global raylib__load_shader
raylib__load_shader equ rl_load_shader
global raylib__load_shader_from_memory
raylib__load_shader_from_memory equ rl_load_shader_from_memory
global raylib__is_shader_ready
raylib__is_shader_ready equ rl_is_shader_ready
global raylib__unload_shader
raylib__unload_shader equ rl_unload_shader
global raylib__get_shader_location
raylib__get_shader_location equ rl_get_shader_location
global raylib__set_shader_value
raylib__set_shader_value equ rl_set_shader_value
global raylib__set_shader_value_matrix
raylib__set_shader_value_matrix equ rl_set_shader_value_matrix
global raylib__set_shader_value_texture
raylib__set_shader_value_texture equ rl_set_shader_value_texture
global raylib__check_collision_spheres
raylib__check_collision_spheres equ rl_check_collision_spheres
global raylib__check_collision_boxes
raylib__check_collision_boxes equ rl_check_collision_boxes
global raylib__check_collision_box_sphere
raylib__check_collision_box_sphere equ rl_check_collision_box_sphere
global raylib__get_ray_collision_sphere
raylib__get_ray_collision_sphere equ rl_get_ray_collision_sphere
global raylib__get_ray_collision_box
raylib__get_ray_collision_box equ rl_get_ray_collision_box
global raylib__get_ray_collision_mesh
raylib__get_ray_collision_mesh equ rl_get_ray_collision_mesh
global raylib__get_ray_collision_triangle
raylib__get_ray_collision_triangle equ rl_get_ray_collision_triangle
global raylib__get_ray_collision_quad
raylib__get_ray_collision_quad equ rl_get_ray_collision_quad
global raylib__is_key_pressed
raylib__is_key_pressed equ rl_is_key_pressed
global raylib__is_key_pressed_repeat
raylib__is_key_pressed_repeat equ rl_is_key_pressed_repeat
global raylib__is_key_down
raylib__is_key_down equ rl_is_key_down
global raylib__key_held
raylib__key_held equ rl_key_held
global raylib__is_key_released
raylib__is_key_released equ rl_is_key_released
global raylib__is_key_up
raylib__is_key_up equ rl_is_key_up
global raylib__get_key_pressed
raylib__get_key_pressed equ rl_get_key_pressed
global raylib__get_char_pressed
raylib__get_char_pressed equ rl_get_char_pressed
global raylib__is_mouse_button_pressed
raylib__is_mouse_button_pressed equ rl_is_mouse_button_pressed
global raylib__is_mouse_button_down
raylib__is_mouse_button_down equ rl_is_mouse_button_down
global raylib__is_mouse_button_released
raylib__is_mouse_button_released equ rl_is_mouse_button_released
global raylib__is_mouse_button_up
raylib__is_mouse_button_up equ rl_is_mouse_button_up
global raylib__get_mouse_x
raylib__get_mouse_x equ rl_get_mouse_x
global raylib__get_mouse_y
raylib__get_mouse_y equ rl_get_mouse_y
global raylib__get_mouse_wheel_move
raylib__get_mouse_wheel_move equ rl_get_mouse_wheel_move
global raylib__set_mouse_position
raylib__set_mouse_position equ rl_set_mouse_position
global raylib__set_mouse_offset
raylib__set_mouse_offset equ rl_set_mouse_offset
global raylib__set_mouse_scale
raylib__set_mouse_scale equ rl_set_mouse_scale
global raylib__set_mouse_cursor
raylib__set_mouse_cursor equ rl_set_mouse_cursor
global raylib__get_touch_x
raylib__get_touch_x equ rl_get_touch_x
global raylib__get_touch_y
raylib__get_touch_y equ rl_get_touch_y
global raylib__get_touch_point_count
raylib__get_touch_point_count equ rl_get_touch_point_count
global raylib__is_gamepad_available
raylib__is_gamepad_available equ rl_is_gamepad_available
global raylib__is_gamepad_button_pressed
raylib__is_gamepad_button_pressed equ rl_is_gamepad_button_pressed
global raylib__is_gamepad_button_down
raylib__is_gamepad_button_down equ rl_is_gamepad_button_down
global raylib__is_gamepad_button_released
raylib__is_gamepad_button_released equ rl_is_gamepad_button_released
global raylib__is_gamepad_button_up
raylib__is_gamepad_button_up equ rl_is_gamepad_button_up
global raylib__get_gamepad_button_pressed
raylib__get_gamepad_button_pressed equ rl_get_gamepad_button_pressed
global raylib__get_gamepad_axis_count
raylib__get_gamepad_axis_count equ rl_get_gamepad_axis_count
global raylib__get_gamepad_axis_movement
raylib__get_gamepad_axis_movement equ rl_get_gamepad_axis_movement
global raylib__set_gamepad_vibration
raylib__set_gamepad_vibration equ rl_set_gamepad_vibration
global raylib__init_audio_device
raylib__init_audio_device equ rl_init_audio_device
global raylib__close_audio_device
raylib__close_audio_device equ rl_close_audio_device
global raylib__is_audio_device_ready
raylib__is_audio_device_ready equ rl_is_audio_device_ready
global raylib__set_master_volume
raylib__set_master_volume equ rl_set_master_volume
global raylib__get_master_volume
raylib__get_master_volume equ rl_get_master_volume
global raylib__load_sound
raylib__load_sound equ rl_load_sound
global raylib__load_sound_from_wave
raylib__load_sound_from_wave equ rl_load_sound_from_wave
global raylib__is_sound_ready
raylib__is_sound_ready equ rl_is_sound_ready
global raylib__update_sound
raylib__update_sound equ rl_update_sound
global raylib__unload_sound
raylib__unload_sound equ rl_unload_sound
global raylib__play_sound
raylib__play_sound equ rl_play_sound
global raylib__stop_sound
raylib__stop_sound equ rl_stop_sound
global raylib__pause_sound
raylib__pause_sound equ rl_pause_sound
global raylib__resume_sound
raylib__resume_sound equ rl_resume_sound
global raylib__is_sound_playing
raylib__is_sound_playing equ rl_is_sound_playing
global raylib__set_sound_volume
raylib__set_sound_volume equ rl_set_sound_volume
global raylib__set_sound_pitch
raylib__set_sound_pitch equ rl_set_sound_pitch
global raylib__set_sound_pan
raylib__set_sound_pan equ rl_set_sound_pan
global raylib__load_wave
raylib__load_wave equ rl_load_wave
global raylib__is_wave_ready
raylib__is_wave_ready equ rl_is_wave_ready
global raylib__unload_wave
raylib__unload_wave equ rl_unload_wave
global raylib__export_wave
raylib__export_wave equ rl_export_wave
global raylib__load_music_stream
raylib__load_music_stream equ rl_load_music_stream
global raylib__is_music_ready
raylib__is_music_ready equ rl_is_music_ready
global raylib__unload_music_stream
raylib__unload_music_stream equ rl_unload_music_stream
global raylib__play_music_stream
raylib__play_music_stream equ rl_play_music_stream
global raylib__is_music_stream_playing
raylib__is_music_stream_playing equ rl_is_music_stream_playing
global raylib__update_music_stream
raylib__update_music_stream equ rl_update_music_stream
global raylib__stop_music_stream
raylib__stop_music_stream equ rl_stop_music_stream
global raylib__pause_music_stream
raylib__pause_music_stream equ rl_pause_music_stream
global raylib__resume_music_stream
raylib__resume_music_stream equ rl_resume_music_stream
global raylib__seek_music_stream
raylib__seek_music_stream equ rl_seek_music_stream
global raylib__set_music_volume
raylib__set_music_volume equ rl_set_music_volume
global raylib__set_music_pitch
raylib__set_music_pitch equ rl_set_music_pitch
global raylib__set_music_pan
raylib__set_music_pan equ rl_set_music_pan
global raylib__get_music_time_length
raylib__get_music_time_length equ rl_get_music_time_length
global raylib__get_music_time_played
raylib__get_music_time_played equ rl_get_music_time_played
global raylib__get_random_value
raylib__get_random_value equ rl_get_random_value
global raylib__set_random_seed
raylib__set_random_seed equ rl_set_random_seed
global raylib__take_screenshot
raylib__take_screenshot equ rl_take_screenshot
global raylib__open_url
raylib__open_url equ rl_open_url
global raylib__color_rgba
raylib__color_rgba equ rl_color_rgba
global raylib__color_black
raylib__color_black equ rl_color_black
global raylib__color_white
raylib__color_white equ rl_color_white
global raylib__color_red
raylib__color_red equ rl_color_red
global raylib__color_green
raylib__color_green equ rl_color_green
global raylib__color_blue
raylib__color_blue equ rl_color_blue
global raylib__color_yellow
raylib__color_yellow equ rl_color_yellow
global raylib__color_orange
raylib__color_orange equ rl_color_orange
global raylib__color_purple
raylib__color_purple equ rl_color_purple
global raylib__color_magenta
raylib__color_magenta equ rl_color_magenta
global raylib__color_gray
raylib__color_gray equ rl_color_gray
global raylib__color_darkgray
raylib__color_darkgray equ rl_color_darkgray
global raylib__color_lightgray
raylib__color_lightgray equ rl_color_lightgray
global raylib__color_skyblue
raylib__color_skyblue equ rl_color_skyblue
global raylib__color_lime
raylib__color_lime equ rl_color_lime
global raylib__color_gold
raylib__color_gold equ rl_color_gold
global raylib__color_pink
raylib__color_pink equ rl_color_pink
global raylib__color_maroon
raylib__color_maroon equ rl_color_maroon
global raylib__color_beige
raylib__color_beige equ rl_color_beige
global raylib__color_brown
raylib__color_brown equ rl_color_brown
global raylib__color_darkbrown
raylib__color_darkbrown equ rl_color_darkbrown
global raylib__color_darkblue
raylib__color_darkblue equ rl_color_darkblue
global raylib__color_darkgreen
raylib__color_darkgreen equ rl_color_darkgreen
global raylib__color_darkpurple
raylib__color_darkpurple equ rl_color_darkpurple
global raylib__color_violet
raylib__color_violet equ rl_color_violet
global raylib__color_transparent
raylib__color_transparent equ rl_color_transparent
