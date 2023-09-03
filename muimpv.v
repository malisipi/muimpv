module muimpv

import malisipi.mui
import gg
import sync
import sokol.gfx

const (
	c_win_width     = 640
	c_win_height    = 360
)

[heap]
pub struct MPVPlayer {
mut:
	handle  &MPVHandle        = unsafe { nil }
	context &MPVRenderContext = unsafe { nil }

	should_draw bool

	pixels  [c_win_height][c_win_width]u32
	texture &gg.Image = unsafe { nil }

	@lock &sync.Mutex = sync.new_mutex()
pub mut:
	video_duration f64
	video_position f64
	video_paused   bool = true
	video_path     string
pub:
	event_handler  mui.OnEvent
}

pub fn (mut mpv MPVPlayer) init(mut app &mui.Window) {
	mpv.handle = C.mpv_create()
	if C.mpv_initialize(mpv.handle) < 0 {
		panic('MPVPlayer: Init failed!')
	}

	temp_adv_control_hack := int(0)

	params := [
		MPVRenderParameter{C.MPV_RENDER_PARAM_API_TYPE, 'sw'.str},
		MPVRenderParameter{C.MPV_RENDER_PARAM_ADVANCED_CONTROL, &temp_adv_control_hack},
		MPVRenderParameter{0, &voidptr(0)},
	]

	if C.mpv_render_context_create(&mpv.context, mpv.handle, params.data) < 0 {
		panic('MPVPlayer: Failed to init mpv sw context.')
	}

	on_mpv_events := fn [mut mpv, mut app] (_ voidptr) {
		spawn mpv.on_mpv_events(mut app)
	}

	C.mpv_set_wakeup_callback(mpv.handle, on_mpv_events, 0)

	C.mpv_observe_property(mpv.handle, 0, 'duration'.str, C.MPV_FORMAT_DOUBLE)
	C.mpv_observe_property(mpv.handle, 0, 'time-pos'.str, C.MPV_FORMAT_DOUBLE)

	$if !offscreen_rendering? {
		texture_id := app.gg.new_streaming_image(c_win_width, c_win_height, 4, pixel_format: .rgba8)
		mpv.texture = app.gg.get_cached_image_by_idx(texture_id)
	}
}

pub fn (mut mpv MPVPlayer) load_media(path string) {
	mpv.video_path = path
	mpv.play()
	C.mpv_command_async(mpv.handle, 0, [&char('loadfile'.str), &char(mpv.video_path.str), &char(0)].data)
}

pub fn (mut mpv MPVPlayer) on_mpv_events(mut app mui.Window) { // https://mpv.io/manual/master/#property-list
	for {
		event := C.mpv_wait_event(mpv.handle, 0)

		if event.event_id == C.MPV_EVENT_NONE {
			break
		}

		if event.event_id == C.MPV_EVENT_PROPERTY_CHANGE {
			prop := event.data
			mpv.@lock.@lock()

			if unsafe { cstring_to_vstring(prop.name) } == 'time-pos' {
				if prop.format == C.MPV_FORMAT_DOUBLE {
					time_pos := unsafe { *(&f64(prop.data)) }
					mpv.video_position = time_pos
					mpv.event_handler(mui.EventDetails{event:"time_pos_update", value:"${int(time_pos)}"}, mut app, mut app.app_data)
				} else {
					if unsafe { voidptr(prop.data) } == unsafe { nil } {
						mpv.video_paused = true
					}
					mpv.event_handler(mui.EventDetails{event:"duration_update", value:"0"}, mut app, mut app.app_data)
				}
			} else if unsafe { cstring_to_vstring(prop.name) } == 'duration' {
				if prop.format == C.MPV_FORMAT_DOUBLE {
					duration := unsafe { *(&f64(prop.data)) }
					mpv.video_duration = duration
					mpv.event_handler(mui.EventDetails{event:"duration_update", value:"${int(duration)}"}, mut app, mut app.app_data)
				}
			}
			mpv.@lock.unlock()
		}
	}
}

[direct_array_access]
pub fn (mut mpv MPVPlayer) update_texture() {
	$if !offscreen_rendering? {
		resolution := [c_win_width, c_win_height]
		pitch := int(c_win_width*4)
		rend_params := [
			C.mpv_render_param{C.MPV_RENDER_PARAM_SW_SIZE, resolution.data},
			C.mpv_render_param{C.MPV_RENDER_PARAM_SW_FORMAT, 'rgb0'.str},
			C.mpv_render_param{C.MPV_RENDER_PARAM_SW_STRIDE, &pitch},
			C.mpv_render_param{C.MPV_RENDER_PARAM_SW_POINTER, &mpv.pixels},
			C.mpv_render_param{0, &voidptr(0)},
		]
		r := C.mpv_render_context_render(mpv.context, rend_params.data)
		if r < 0 {
			unsafe {
				panic('MPVPlayer: Crash -> ${cstring_to_vstring(C.mpv_error_string(r))} | ${r}')
			}
		}
		for y in 0 .. c_win_height { // 0XBB_GG_RR => 0xAA_BB_GG_RR
			for x in 0 .. c_win_width {
				mpv.pixels[y][x] = mpv.pixels[y][x] | (255 << 24)
			}
		}
		
		//mpv.texture.update_pixel_data(&mpv.pixels)
		mut data := gfx.ImageData{}
		data.subimage[0][0].ptr = &mpv.pixels
		data.subimage[0][0].size = usize(mpv.texture.width * mpv.texture.height * mpv.texture.nr_channels)
		gfx.update_image(mpv.texture.simg, &data)
	}
}

pub fn get_video(mut app &mui.Window, id string) &MPVPlayer {
	unsafe {
		return &MPVPlayer(app.get_object_by_id(id)[0]["vdptr"].vpt)
	}
}

pub fn (mut mpv MPVPlayer) pause(){
	mpv.video_paused = true
	C.mpv_set_property_string(mpv.handle, "pause".str, "yes".str)
}

pub fn (mut mpv MPVPlayer) play(){
	mpv.video_paused = false
	C.mpv_set_property_string(mpv.handle, "pause".str, "no".str)
}

pub fn (mut mpv MPVPlayer) seek(the_time int){
	C.mpv_set_property_string(mpv.handle, "time-pos".str, "${the_time}".str)
}
// ui code

[heap]
pub fn new(mut app mui.Window, func mui.OnEvent, args mui.Widget) {
    app.objects << {
        "type": mui.WindowData{str: "muimpv"},
        "id":   mui.WindowData{str: args.id},
        "x":    mui.WindowData{num: 0},
        "y":    mui.WindowData{num: 0},
        "w":    mui.WindowData{num: 0},
        "h":    mui.WindowData{num: 0},
		"x_raw":mui.WindowData{str: match args.x{ int{ args.x.str() } string{ args.x } } },
		"y_raw":mui.WindowData{str: match args.y{ int{ args.y.str() } string{ args.y } } },
		"w_raw":mui.WindowData{str: match args.width{ int{ args.width.str() } string{ args.width } } },
		"h_raw":mui.WindowData{str: match args.height{ int{ args.height.str() } string{ args.height } } },
        "hi":	mui.WindowData{bol: args.hidden},
		"vdptr":mui.WindowData{vpt: &muimpv.MPVPlayer{event_handler: func}}
    }
}

[unsafe]
fn draw_muimpv(app &mui.Window, object map[string]mui.WindowData){
	$if !offscreen_rendering? {
		unsafe {
			mpv := &MPVPlayer(object["vdptr"].vpt)
			mpv.update_texture()
			app.gg.draw_image(object["x"].num, object["y"].num, object["w"].num, object["h"].num, mpv.texture)
		}
	}
}

pub fn load_into_app(mut app &mui.Window){
    app.custom_widgets << mui.CustomWidget{typ:"muimpv",
            draw_fn:draw_muimpv
    }
}
