// Debug interface
pub extern fn debugMessage(message_ptr: [*]const u8, message_len: usize) void;
pub extern fn debugError(message_ptr: [*]const u8, message_len: usize) void;

pub fn print(message: []const u8) void {
    debugMessage(message.ptr, message.len);
}

// Rendering interface
pub extern fn setWindowTitle(title_ptr: [*]const u8, title_len: usize) void;
pub extern fn setTargetFPS(fps: u8) void;
pub extern fn halt() void;

// Drawing interface
pub extern fn clear() void;
pub extern fn setFillColor(r: u8, g: u8, b: u8) void;
pub extern fn setAlpha(alpha: f64) void;
pub extern fn setStrokeColor(r: u8, g: u8, b: u8) void;
pub extern fn drawRect(x: f64, y: f64, width: f64, height: f64) void;
pub extern fn drawCircle(x: f64, y: f64, radius: f64) void;
pub extern fn drawLine(x1: f64, y1: f64, x2: f64, y2: f64, thickness: f64) void;
pub extern fn drawText(x: f64, y: f64, text_ptr: [*]const u8, text_len: usize) void;

pub fn drawTextString(x: f64, y: f64, text: []const u8) void {
    drawText(x, y, text.ptr, text.len);
}

// Audio interface
pub extern fn setAudioChannelCount(channel_count: u8) void;
pub const AudioChannelType = enum(u8) {
    Sine = 0,
    Square = 1,
    Sawtooth = 2,
    Triangle = 3,
};
pub extern fn setAudioChannelType(channel: u8, channel_type: AudioChannelType) void;
pub extern fn playFrequencyChirp(channel: u8, start_freq: u32, end_freq: u32, duration: f64) void;
pub extern fn playFrequencyTone(channel: u8, freq: u32) void;