import AppKit
import OpenGL.GL3
import CLibMPV

private func getProcAddress(_ ctx: UnsafeMutableRawPointer?, _ name: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    guard let name else { return nil }
    let bundle = CFBundleGetBundleWithIdentifier("com.apple.opengl" as CFString)
    return CFBundleGetFunctionPointerForName(bundle, String(cString: name) as CFString)
}

public final class MPVVideoView: NSOpenGLView {
    private let player: MPVPlayer
    private var render: OpaquePointer?

    public init(player: MPVPlayer) {
        self.player = player
        let attrs: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFADoubleBuffer), UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core), 0,
        ]
        super.init(frame: .zero, pixelFormat: NSOpenGLPixelFormat(attributes: attrs))!
        wantsBestResolutionOpenGLSurface = true
        openGLContext?.setValues([1], for: .swapInterval)
        openGLContext?.makeCurrentContext()

        let ok: Bool = "opengl".withCString { api in
            var initParams = mpv_opengl_init_params(get_proc_address: getProcAddress, get_proc_address_ctx: nil)
            return withUnsafeMutablePointer(to: &initParams) { ip in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: UnsafeMutableRawPointer(mutating: api)),
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: ip),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
                ]
                return mpv_render_context_create(&render, player.handle, &params) >= 0
            }
        }
        guard ok, let render else { return }
        mpv_render_context_set_update_callback(render, { ctx in
            let v = Unmanaged<MPVVideoView>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { v.needsDisplay = true }
        }, Unmanaged.passUnretained(self).toOpaque())
        player.onTeardown = { [weak self] in self?.shutdown() }
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func draw(_ dirtyRect: NSRect) {
        guard let render else { return }
        openGLContext?.makeCurrentContext()
        var fbo: GLint = 0
        glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &fbo)
        let size = convertToBacking(bounds).size
        var data = mpv_opengl_fbo(fbo: Int32(fbo), w: Int32(size.width), h: Int32(size.height), internal_format: 0)
        var flip: Int32 = 1
        withUnsafeMutablePointer(to: &data) { d in
            withUnsafeMutablePointer(to: &flip) { f in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: d),
                    mpv_render_param(type: MPV_RENDER_PARAM_FLIP_Y, data: f),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
                ]
                mpv_render_context_render(render, &params)
            }
        }
        glFlush()
        openGLContext?.flushBuffer()
    }

    public func shutdown() {
        guard let r = render else { return }
        render = nil
        openGLContext?.makeCurrentContext()
        mpv_render_context_set_update_callback(r, nil, nil)
        mpv_render_context_free(r)
    }
}
