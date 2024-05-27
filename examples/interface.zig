// Debug interface
pub extern fn debugMessage(message_ptr: [*]const u8, message_len: usize) void;
pub extern fn debugError(message_ptr: [*]const u8, message_len: usize) void;

// Rendering interface
pub extern fn setWindowTitle(title_ptr: [*]const u8, title_len: usize) void;
pub extern fn setTargetFPS(fps: u8) void;
pub extern fn halt() void;

// Drawing interface
pub extern fn clear() void;
pub extern fn setFillColor(r: u8, g: u8, b: u8) void;
pub extern fn setStrokeColor(r: u8, g: u8, b: u8) void;
pub extern fn drawRect(x: f64, y: f64, width: f64, height: f64) void;
pub extern fn drawCircle(x: f64, y: f64, radius: f64) void;
pub extern fn drawLine(x1: f64, y1: f64, x2: f64, y2: f64, thickness: f64) void;
pub extern fn drawText(x: f64, y: f64, text_ptr: [*]const u8, text_len: usize) void;

pub fn print(message: []const u8) void {
    debugMessage(message.ptr, message.len);
}