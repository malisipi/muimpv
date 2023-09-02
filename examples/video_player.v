import malisipi.mui
import malisipi.muimpv
import gg

fn init_fn(event_details mui.EventDetails, mut app &mui.Window, mut app_data voidptr){
	mut video := muimpv.get_video(mut app, "video")
	video.init(mut app)
}

fn open_file(event_details mui.EventDetails, mut app &mui.Window, mut app_data voidptr){
	mut video := muimpv.get_video(mut app, "video")
	video.load_media(mui.openfiledialog("Video Player"))
}

fn play_pause(event_details mui.EventDetails, mut app &mui.Window, mut app_data voidptr){
	mut video := muimpv.get_video(mut app, "video")
	if video.video_paused {
		video.play()
	} else {
		video.pause()
	}
}

fn video_event_handler(event_details mui.EventDetails, mut app &mui.Window, mut app_data voidptr){
	if event_details.event == "time_pos_update" {
		app.get_object_by_id("time_slider")[0]["val"].num=event_details.value.int()
	} else if event_details.event == "duration_update" {
		app.get_object_by_id("time_slider")[0]["vlMax"].num=event_details.value.int()
	}
}

fn seek_time(event_details mui.EventDetails, mut app &mui.Window, mut app_data voidptr){
	mut video := muimpv.get_video(mut app, "video")
	if event_details.event == "unclick" {
		video.seek(event_details.value.int())
		video.play()
	} else if event_details.event == "click" {
		video.pause()
	}
}

fn fullscreen(event_details mui.EventDetails, mut app &mui.Window, mut app_data voidptr){
	gg.toggle_fullscreen()
}

fn map_play_time(the_time int) string{
    return "${the_time/60:02}:${the_time%60:02}"
}

fn main() {
	mut app:=mui.create(title:"Video Player", init_fn: &init_fn, draw_mode:.system_native)
	muimpv.load_into_app(mut app)
	app.button(id:"open_file_button", x:0, y:"# 0", width:30, height:30, text:"📂", icon:true, onclick:open_file)
	app.button(id:"play_button", x:30, y:"# 0", width:30, height:30, text:"⏸️", icon:true, onclick:play_pause)
	app.slider(id:"time_slider", x:60, y:"# 0", width:"100%x -150", height:30, onclick:seek_time, onunclick:seek_time, onchange:seek_time, value_map:map_play_time )
	app.button(id:"fullscreen_button", x:"# 0", y:"# 0", width:30, height:30, text:"↔️", icon:true, onclick:fullscreen)
	muimpv.new(mut app, video_event_handler, id:"video", x:0, y:0, width:"100%x", height:"100%y -30")
	app.run()
}
