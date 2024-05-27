const std = @import("std");
const iface = @import("interface.zig");

var canvasWidth: u16 = 0;
var canvasHeight: u16 = 0;
var mouseX: u16 = 0;
var mouseY: u16 = 0;
var mouseDown: bool = false;

const title: []const u8 = "Targets Practice!";
var reticleSpin: f64 = 0.0;

var prng: std.rand.DefaultPrng = std.rand.DefaultPrng.init(0);

const targetRadius: u16 = 36;
var targetX: u16 = 0;
var targetY: u16 = 0;

var game: bool = false;
var time: f64 = 0.0;
var score: u32 = 0;
var targetsHit: u8 = 0;
var targetsTarget: u8 = 0;

export fn init(width: u16, height: u16) void {
    iface.setWindowTitle(title.ptr, title.len);
    iface.setTargetFPS(60);
    canvasWidth = width;
    canvasHeight = height;

    // Set the target to a random location
    genTargetPosition();
}

const PI = 3.14159265358979323846264338;

fn genTargetPosition() void {
    targetX = std.rand.uintLessThan(prng.random(), u16, canvasWidth);
    targetY = std.rand.uintLessThan(prng.random(), u16, canvasHeight);
}

fn drawReticle(x_pos: u16, y_pos: u16, spin: f64) void {
    const x: f64 = @floatFromInt(x_pos);
    const y: f64 = @floatFromInt(y_pos);
    iface.setFillColor(255, 128, 128);
    iface.drawCircle(x, y, 5);
    iface.setStrokeColor(255, 128, 128);
    // We want the reticle to spin, so we need
    // to calculate the angle based on the current
    // reticleSpin value.
    for (0..4) |i| {
        const ifloat: f64 = @floatFromInt(i);
        const angle: f64 = (PI / 2.0) * ifloat + spin;
        const innerRadius = 10;
        const outerRadius = 30;
        const x1 = x + (innerRadius * @cos(angle));
        const y1 = y + (innerRadius * @sin(angle));
        const x2 = x + (outerRadius * @cos(angle));
        const y2 = y + (outerRadius * @sin(angle));
        iface.drawLine(x1, y1, x2, y2, 2);
    }
}

fn drawTarget(x: u16, y: u16) void {
    const targetColored = .{255, 50, 50};
    const targetWhite = .{255, 255, 255};
    var color = true;
    var radius = targetRadius - @rem(targetRadius, 6);

    while (radius > 0) {
        if (color) {
            iface.setFillColor(targetColored[0], targetColored[1], targetColored[2]);
        } else {
            iface.setFillColor(targetWhite[0], targetWhite[1], targetWhite[2]);
        }
        iface.drawCircle(@floatFromInt(x), @floatFromInt(y), @floatFromInt(radius));
        radius -= 6;
        color = !color;
    }
}

fn drawScore(x_pos: u16, y_pos: u16) void {
    const x: f64 = @floatFromInt(x_pos);
    const y: f64 = @floatFromInt(y_pos);
    var buffer: [20]u8 = undefined;
    const out1 = std.fmt.bufPrint(&buffer, "Time: {d}", .{@as(u32, @intFromFloat(time))}) catch unreachable;
    iface.drawText(x, y, out1.ptr, out1.len);
    const out2 = std.fmt.bufPrint(&buffer, "Score: {d}", .{score}) catch unreachable;
    iface.drawText(x, y+12, out2.ptr, out2.len);
    const out3 = std.fmt.bufPrint(&buffer, "Remaining: {d}", .{targetsTarget - targetsHit}) catch unreachable;
    iface.drawText(x, y+24, out3.ptr, out3.len);
}

/// Draws a button immediately to the screen and
/// returns true if the button is clicked.
fn immediateModeButton(x_pos: u16, y_pos: u16, text: []const u8) bool {
    const x: f64 = @floatFromInt(x_pos);
    const y: f64 = @floatFromInt(y_pos);
    const buttonWidth: f64 = 150;
    const buttonHeight: f64 = 50;
    iface.setFillColor(255, 255, 255);
    iface.drawRect(x, y, buttonWidth, buttonHeight);

    var result = false;

    const mx: f64 = @floatFromInt(mouseX);
    const my: f64 = @floatFromInt(mouseY);
    const dx: f64 = mx - x;
    const dy: f64 = my - y;
    if (dx >= 0 and dx <= buttonWidth and dy >= 0 and dy <= buttonHeight) {
        iface.setFillColor(200, 200, 200);
        iface.drawRect(x, y, buttonWidth, buttonHeight);
        result = mouseDown;
    }

    iface.setFillColor(0, 0, 0);
    iface.drawText(x + 20, y + 20, text.ptr, text.len);

    return result;
}

fn drawMainMenu() void {
    const titleX = (canvasWidth) / 4;
    const titleY = 100;

    drawTarget(titleX - 60, titleY );
    drawReticle(titleX - 30, titleY - 20, 0.5*reticleSpin);

    iface.setFillColor(255, 90, 60);
    iface.drawText(@floatFromInt(titleX), @floatFromInt(titleY), title.ptr, title.len);
    if (time > 0) {
        const lastgame_offset = 170;
        const lastgame: []const u8 = "Last Game";
        iface.drawText(@floatFromInt(titleX + lastgame_offset), @floatFromInt(titleY+24), lastgame.ptr, lastgame.len);
        var buffer: [20]u8 = undefined;
        const out = std.fmt.bufPrint(&buffer, "Target: {d}", .{targetsTarget}) catch unreachable;
        iface.drawText(@floatFromInt(titleX + lastgame_offset), @floatFromInt(titleY+36), out.ptr, out.len);
        drawScore(titleX + lastgame_offset, titleY+48);
    }

    const buttonX = titleX;
    const buttonY = titleY+20;
    if (immediateModeButton(buttonX, buttonY, "To Five")) {
        game = true;
        time = 0.0;
        score = 0;
        targetsHit = 0;
        targetsTarget = 5;
        prng.seed(@bitCast(reticleSpin));
        genTargetPosition();
    } else if (immediateModeButton(buttonX, buttonY+60, "To Twenty")) {
        game = true;
        time = 0.0;
        score = 0;
        targetsHit = 0;
        targetsTarget = 20;
        prng.seed(@bitCast(reticleSpin));
        genTargetPosition();
    } else if (immediateModeButton(buttonX, buttonY + 120, "Quit")) {
        iface.halt();
    }
}

export fn draw(deltaTimeSeconds: f64) void {
    iface.clear();

    if (!game) {
        // Main menu
        drawMainMenu();
    } else {
        // Game
        drawScore(10,12);
        drawTarget(targetX, targetY);
        updateTargetHit();
        drawReticle(mouseX, mouseY, reticleSpin);
        time += deltaTimeSeconds;
        if (targetsHit >= targetsTarget) {
            game = false;
        }
    }
    mouseDown = false;

    reticleSpin += deltaTimeSeconds*2.0;
    reticleSpin = @rem(reticleSpin, PI);
}

fn updateTargetHit() void {
    if (mouseDown) {
        // Left mouse button
        const x: f64 = @floatFromInt(mouseX);
        const y: f64 = @floatFromInt(mouseY);
        const tx: f64 = @floatFromInt(targetX);
        const ty: f64 = @floatFromInt(targetY);
        const dx: f64 = x - tx;
        const dy: f64 = y - ty;
        const distance: f64 = @sqrt(dx * dx + dy * dy);
        if (distance < targetRadius) {
            score += @intFromFloat(100 - (distance / targetRadius * 100));
            targetsHit += 1;
            genTargetPosition();
        }
    }
}

export fn mousemove(x: u16, y: u16) void {
    mouseX = x;
    mouseY = y;
}

export fn mousedown(button: u8) void {
    if (button == 0) {
        mouseDown = true;

        if (game) {
        }
    }
}