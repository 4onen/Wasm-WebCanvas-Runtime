const std = @import("std");

const iface = @import("interface.zig");
const print = iface.print;

var frameCount: u32 = 0;
var canvasWidth: u16 = 0;
var canvasHeight: u16 = 0;

export fn init(width: u16, height: u16) void {
    const title: []const u8 = "Hello, World!";
    iface.setWindowTitle(title.ptr, title.len);
    iface.setTargetFPS(50);
    canvasWidth = width;
    canvasHeight = height;
}

export fn draw(deltaTimeSeconds: f64) void {
    iface.clear();
    iface.setFillColor(255, 0, 0);
    iface.drawRect(100.0, 100.0, 100.0*deltaTimeSeconds, 100.0);
    iface.drawRect(100.0, 200.0, 100.0*deltaTimeSeconds, 100.0);
    frameCount += 1;
    if (frameCount % 3 == 0 and frameCount % 5 == 0) {
        print("FizzBuzz");
    } else if (frameCount % 3 == 0) {
        print("Fizz");
    } else if (frameCount % 5 == 0) {
        print("Buzz");
    } else {
        var buffer: [3]u8 = undefined;
        const number = std.fmt.bufPrint(&buffer, "{d}", .{frameCount}) catch unreachable;
        print(number);
    }
    if (frameCount > 500) {
        iface.halt();
    }
}