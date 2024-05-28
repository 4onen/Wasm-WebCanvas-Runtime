const std = @import("std");
const iface = @import("interface.zig");

var canvasWidth: u16 = 0;
var canvasHeight: u16 = 0;
var mouseX: u16 = 0;
var mouseY: u16 = 0;
var mouseDown: bool = false;

const MUSIC_CHANNEL = 0;
const UI_CHANNEL = 1;
const SFX_CHANNEL = 2;

const title: []const u8 = "Targets Practice!";
var reticleSpin: f64 = 0.0;
var screenFlash: f64 = 0.0;

var screenShakeIntensity: f64 = 0.0;
var screenShakeOffsetX: f64 = 0.0;
var screenShakeOffsetY: f64 = 0.0;

fn drawRectShake(x: f64, y: f64, width: f64, height: f64) void {
    iface.drawRect(x + screenShakeOffsetX, y + screenShakeOffsetY, width, height);
}

fn drawCircleShake(x: f64, y: f64, radius: f64) void {
    iface.drawCircle(x + screenShakeOffsetX, y + screenShakeOffsetY, radius);
}

fn drawLineShake(x1: f64, y1: f64, x2: f64, y2: f64, thickness: f64) void {
    iface.drawLine(x1 + screenShakeOffsetX, y1 + screenShakeOffsetY, x2 + screenShakeOffsetX, y2 + screenShakeOffsetY, thickness);
}

fn drawTextShake(x: f64, y: f64, text: []const u8) void {
    iface.drawTextString(x + screenShakeOffsetX, y + screenShakeOffsetY, text);
}

fn updateShake(deltaTimeSeconds: f64) void {
    screenShakeIntensity *= (1.0 - deltaTimeSeconds * 15.0);
    screenShakeOffsetX = prng.random().floatNorm(f64) * screenShakeIntensity;
    screenShakeOffsetY = prng.random().floatNorm(f64) * screenShakeIntensity;
}

var prng: std.rand.DefaultPrng = std.rand.DefaultPrng.init(0);

const targetRadius: u16 = 36;
var targetX: f64 = 0;
var targetY: f64 = 0;
var targetTargetX: u16 = 0;
var targetTargetY: u16 = 0;

var game: bool = false;
var time: f64 = 0.0;
var score: u32 = 0;
var targetsHit: u8 = 0;
var targetsTarget: u8 = 0;


export fn init(width: u16, height: u16) void {
    iface.setWindowTitle(title.ptr, title.len);
    iface.setTargetFPS(60);
    iface.setAudioChannelCount(3);
    iface.setAudioChannelType(SFX_CHANNEL, iface.AudioChannelType.Sawtooth);
    canvasWidth = width;
    canvasHeight = height;
    screenShakeIntensity = 20.0;
    screenFlash = 1.0;

    genTargetPosition();
    targetX = @floatFromInt(targetTargetX);
    targetY = @floatFromInt(targetTargetY);
}

export fn mousemove(x: u16, y: u16) void {
    mouseX = x;
    mouseY = y;
    const movement: f64 = @floatFromInt(x+y);
    screenShakeIntensity += movement/10000.0;
}

export fn mousedown(button: u8) void {
    if (button == 0) {
        mouseDown = true;

        if (game) {
        }
    }
}

const PI = 3.14159265358979323846264338;

fn genTargetPosition() void {
    const padding = 50;
    targetTargetX = std.rand.uintLessThan(prng.random(), u16, canvasWidth-2*padding)+padding;
    targetTargetY = std.rand.uintLessThan(prng.random(), u16, canvasHeight-2*padding)+padding;
}

fn drawReticle(x_pos: u16, y_pos: u16, spin: f64) void {
    const x: f64 = @floatFromInt(x_pos);
    const y: f64 = @floatFromInt(y_pos);
    iface.setFillColor(255, 128, 128);
    drawCircleShake(x, y, 5);
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
        drawLineShake(x1, y1, x2, y2, 2);
    }
}

fn drawScreenFlash(deltaTimeSeconds: f64) void {
    iface.setFillColor(255, 255, 255);
    iface.setAlpha(screenFlash);
    drawRectShake(0, 0, @floatFromInt(canvasWidth), @floatFromInt(canvasHeight));
    iface.setAlpha(1.0);
    screenFlash *= @max(0.0,1.0 - deltaTimeSeconds * 5.0);
}

fn drawTarget(x: u16, y: u16) void {
    drawTargetFloat(@floatFromInt(x), @floatFromInt(y));
}

fn drawTargetFloat(x: f64, y: f64) void {
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
        drawCircleShake(x, y, @floatFromInt(radius));
        radius -= 6;
        color = !color;
    }
}

fn drawScore(x_pos: u16, y_pos: u16) void {
    const x: f64 = @floatFromInt(x_pos);
    const y: f64 = @floatFromInt(y_pos);
    var buffer: [20]u8 = undefined;
    drawTextShake(x, y, std.fmt.bufPrint(&buffer, "Time: {d}", .{@as(u32, @intFromFloat(time))}) catch unreachable);
    drawTextShake(x, y+12, std.fmt.bufPrint(&buffer, "Score: {d}", .{score}) catch unreachable);
    drawTextShake(x, y+24, std.fmt.bufPrint(&buffer, "Remaining: {d}", .{targetsTarget - targetsHit}) catch unreachable);
}

var buttonHovered: ?[*]const u8 = null;

const ButtonOptions = struct {
    width: f64 = 150,
    height: f64 = 50,
};

/// Draws a button immediately to the screen and
/// returns true if the button is clicked.
fn immediateModeButton(x_pos: u16, y_pos: u16, text: []const u8, options: ButtonOptions) bool {
    const x: f64 = @floatFromInt(x_pos);
    const y: f64 = @floatFromInt(y_pos);
    const buttonWidth: f64 = options.width;
    const buttonHeight: f64 = options.height;
    iface.setFillColor(255, 255, 255);
    drawRectShake(x, y, buttonWidth, buttonHeight);

    var result = false;

    const mx: f64 = @floatFromInt(mouseX);
    const my: f64 = @floatFromInt(mouseY);
    const dx: f64 = mx - x;
    const dy: f64 = my - y;
    if (dx >= 0 and dx <= buttonWidth and dy >= 0 and dy <= buttonHeight) {
        iface.setFillColor(200, 200, 200);
        drawRectShake(x, y, buttonWidth, buttonHeight);
        if (buttonHovered != text.ptr) {
            iface.playFrequencyChirp(UI_CHANNEL, 120, 20, 0.3);
            buttonHovered = text.ptr;
        }
        if (mouseDown) {
            result = true;
            iface.playFrequencyChirp(UI_CHANNEL, 180, 10, 0.3);
        }
    } else if (buttonHovered == text.ptr) {
        buttonHovered = null;
    }

    iface.setFillColor(0, 0, 0);
    drawTextShake(x + 20, y + 20, text);

    return result;
}

fn drawMainMenu() void {
    const titleX = (canvasWidth) / 4;
    const titleY = 100;

    drawTarget(titleX - 60, titleY );
    drawReticle(titleX - 30, titleY - 20, 0.5*reticleSpin);

    iface.setFillColor(255, 90, 60);
    drawTextShake(@floatFromInt(titleX), @floatFromInt(titleY), title);
    if (time > 0) {
        const lastgame_offset = 170;
        const lastgame: []const u8 = "Last Game";
        drawTextShake(@floatFromInt(titleX + lastgame_offset), @floatFromInt(titleY+24), lastgame);
        var buffer: [20]u8 = undefined;
        drawTextShake(
            @floatFromInt(titleX + lastgame_offset),
            @floatFromInt(titleY+36),
            std.fmt.bufPrint(&buffer, "Target: {d}", .{targetsTarget}) catch unreachable
        );
        drawScore(titleX + lastgame_offset, titleY+48);
    }

    const buttonX = titleX;
    const buttonY = titleY+20;
    if (immediateModeButton(buttonX, buttonY, "To Five", .{})) {
        game = true;
        time = 0.0;
        score = 0;
        targetsHit = 0;
        targetsTarget = 5;
        prng.seed(@bitCast(reticleSpin));
        genTargetPosition();
    } else if (immediateModeButton(buttonX, buttonY+60, "To Twenty", .{})) {
        game = true;
        time = 0.0;
        score = 0;
        targetsHit = 0;
        targetsTarget = 20;
        prng.seed(@bitCast(reticleSpin));
        genTargetPosition();
    } else if (immediateModeButton(buttonX, buttonY + 120, "Quit", .{})) {
        iface.halt();
    }
}

export fn draw(deltaTimeSeconds: f64) void {
    iface.clear();

    updateShake(deltaTimeSeconds);
    drawScreenFlash(deltaTimeSeconds);
    updateMusic(deltaTimeSeconds);
    if (!game) {
        // Main menu
        drawMainMenu();
    } else {
        // Game
        updateTargetHit(deltaTimeSeconds);
        drawTargetFloat(targetX, targetY);
        drawReticle(mouseX, mouseY, reticleSpin);
        drawScore(10,20);
        time += deltaTimeSeconds;
        if (targetsHit >= targetsTarget) {
            game = false;
        }
    }
    mouseDown = false;

    reticleSpin += deltaTimeSeconds*2.0;
    reticleSpin = @rem(reticleSpin, PI);
}

fn updateTargetHit(deltaTimeSeconds: f64) void {
    targetX += (@as(f64,@floatFromInt(targetTargetX)) - targetX) * deltaTimeSeconds * 10.0;
    targetY += (@as(f64,@floatFromInt(targetTargetY)) - targetY) * deltaTimeSeconds * 10.0;

    if (mouseDown) {
        // Left mouse button
        const x: f64 = @floatFromInt(mouseX);
        const y: f64 = @floatFromInt(mouseY);
        const dx: f64 = x - targetX;
        const dy: f64 = y - targetY;
        const distance: f64 = @sqrt(dx * dx + dy * dy);
        if (distance < targetRadius) {
            iface.playFrequencyChirp(SFX_CHANNEL, 440+prng.random().uintLessThan(u16, 100), 20, 0.5);
            score += @intFromFloat(100 - (distance / targetRadius * 100));
            screenShakeIntensity = 20.0;
            screenFlash = 1.0;
            targetsHit += 1;
            genTargetPosition();
        }
    }
}

var musicPlaying: bool = true;
var musicTime: f64 = 0.0;
var playedNote: usize = 0;
const NOTE_COUNT = 24;
const musicTimings: [NOTE_COUNT]f64 = [_]f64{
    0.0, 0.25, 0.5, 0.75, 1.0, 1.25,
    1.5, 1.75, 2.0, 2.25, 2.5, 2.75,
    3.0, 3.25, 3.5, 3.75, 4.0, 4.25,
    4.5, 4.75, 5.0, 5.25, 5.5, 5.75,
};
const musicDurations: [NOTE_COUNT]f64 = [_]f64{
    0.1, 0.25, 0.1, 0.25,
    0.1, 0.25, 0.1, 0.25,
    0.1, 0.25, 0.1, 0.25,
    0.1, 0.25, 0.1, 0.25,
    0.1, 0.25, 0.1, 0.25,
    0.1, 0.25, 0.1, 0.25,
};
const musicNotes: [NOTE_COUNT]u32 = [_]u32{
    440, 440, 440, 440, 560, 440, 560, 440,
    660, 660, 660, 660, 560, 660, 560, 660,
    770, 770, 770, 770, 880, 770, 880, 770,
};
const musicLength = 6.0;

fn updateMusic(deltaTimeSeconds: f64) void {
    if (immediateModeButton(0, canvasHeight-30, "Music", .{.width=90, .height=30})) {
        musicPlaying = !musicPlaying;
    }
    if (!musicPlaying) {
        return;
    }
    musicTime += deltaTimeSeconds;
    if (musicTime > musicLength) {
        musicTime = 0;
        playedNote = 0;
    }
    if (playedNote < NOTE_COUNT and musicTime > musicTimings[playedNote]) {
        iface.playFrequencyChirp(
            MUSIC_CHANNEL,
            musicNotes[playedNote],
            musicNotes[playedNote],
            musicDurations[playedNote]
        );
        playedNote += 1;
    }
}
