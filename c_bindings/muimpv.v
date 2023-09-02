module main

import malisipi.muimpv
import malisipi.mui

fn video_event_handler(event_details mui.EventDetails, mut app &mui.Window, mut app_data voidptr){}

[export: "muimpv_load"]
fn muimpv_load(mut app &mui.Window){
	muimpv.load_into_app(mut app)
}

[export: "muimpv_new"]
fn muimpv_new(mut app &mui.Window) {
	muimpv.new(mut app, video_event_handler, id:"video", x:0, y:0, width:"100%x", height:"100%y -30")
}

[export: "muimpv_init"]
fn muimpv_init(mut app &mui.Window) {
	mut video := muimpv.get_video(mut app, "video")
	video.init(mut app)
}
