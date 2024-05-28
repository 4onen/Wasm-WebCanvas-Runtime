const std = @import("std");
const iface = @import("interface.zig");

var canvasWidth: u16 = 0;
var canvasHeight: u16 = 0;
var mouseX: u16 = 0;
var mouseY: u16 = 0;
var mouseDownThisFrame: bool = false;
var mouseDown: bool = false;

const title: []const u8 = "Life";

var updateTimer: f64 = 0;
var updateRate: f64 = 0.5;

const UI_CHANNEL: u8 = 0;

export fn mousemove(x: u16, y: u16) void {
    mouseX = x;
    mouseY = y;
}

export fn mousedown() void {
    mouseDownThisFrame = true;
    mouseDown = true;
}

export fn mouseup() void {
    mouseDown = false;
}

var buttonHovered: ?[*]const u8 = null;

const ButtonOptions = struct {
    width: f64 = 150,
    height: f64 = 50,
    forceHoverVisual: bool = false,
};

/// Draws a button immediately to the screen and
/// returns true if the button is clicked.
fn immediateModeButton(x_pos: u16, y_pos: u16, text: []const u8, options: ButtonOptions) bool {
    const x: f64 = @floatFromInt(x_pos);
    const y: f64 = @floatFromInt(y_pos);
    const buttonWidth: f64 = options.width;
    const buttonHeight: f64 = options.height;

    const mx: f64 = @floatFromInt(mouseX);
    const my: f64 = @floatFromInt(mouseY);
    const dx: f64 = mx - x;
    const dy: f64 = my - y;

    const mouse_inside = dx >= 0 and dx <= buttonWidth and dy >= 0 and dy <= buttonHeight;
    if (options.forceHoverVisual or mouse_inside) {
        iface.setFillColor(200, 200, 200);
    } else {
        iface.setFillColor(255, 255, 255);
    }
    iface.drawRect(x, y, buttonWidth, buttonHeight);

    var result = false;

    if (mouse_inside) {
        if (buttonHovered != text.ptr) {
            iface.playFrequencyChirp(UI_CHANNEL, 120, 20, 0.3);
            buttonHovered = text.ptr;
        }
        if (mouseDownThisFrame) {
            result = true;
            iface.playFrequencyChirp(UI_CHANNEL, 180, 10, 0.3);
        }
    } else if (buttonHovered == text.ptr) {
        buttonHovered = null;
    }

    iface.setFillColor(0, 0, 0);
    iface.drawTextString(x + 20, y + 20, text);

    return result;
}

const BOARD_SIDELENGTH = 150;
var board: [BOARD_SIDELENGTH][BOARD_SIDELENGTH]u1 = [_][BOARD_SIDELENGTH]u1{ [_]u1{0}**BOARD_SIDELENGTH } ** BOARD_SIDELENGTH;

fn tileBoardWith(comptime inputWidth: usize, comptime inputHeight: usize, input: [inputWidth][inputHeight]u1) void {
    // We want to tile the board with the input pattern
    // If the input pattern is larger than the board, just place it once in the upper left
    // Otherwise, repeat as many times as fit
    var repeatX = BOARD_SIDELENGTH / inputWidth;
    if (repeatX == 0) {
        repeatX = 1;
    }
    var repeatY = BOARD_SIDELENGTH / inputHeight;
    if (repeatY == 0) {
        repeatY = 1;
    }
    for (0..repeatX) |x| {
        for (0..repeatY) |y| {
            for (0..inputWidth) |i| {
                for (0..inputHeight) |j| {
                    board[x * inputWidth + i][y * inputHeight + j] = input[i][j];
                }
            }
        }
    }
}

fn updateBoard(deltaTimeSeconds: f64) void {
    updateTimer += deltaTimeSeconds;
    if (updateTimer < updateRate) {
        return;
    } else {
        updateTimer = 0;
    }
    var newBoard: [BOARD_SIDELENGTH][BOARD_SIDELENGTH]u1 = undefined;
    for (0..BOARD_SIDELENGTH) |x| {
        for (0..BOARD_SIDELENGTH) |y| {
            var neighbors: u4 = 0;
            for (@as([3]i16,.{-1,0,1})) |dx| {
                for (@as([3]i16,.{-1,0,1})) |dy| {
                    if (dx == 0 and dy == 0) {
                        continue;
                    }
                    const nx: i16 = @as(i16,@intCast(x)) + dx;
                    const ny: i16 = @as(i16,@intCast(y)) + dy;
                    if (nx < 0 or nx >= BOARD_SIDELENGTH or ny < 0 or ny >= BOARD_SIDELENGTH) {
                        continue;
                    }
                    neighbors += board[@as(usize,@intCast(nx))][@as(usize,@intCast(ny))];
                }
            }
            if (board[x][y] == 1) {
                if (neighbors < 2 or neighbors > 3) {
                    newBoard[x][y] = 0;
                } else {
                    newBoard[x][y] = 1;
                }
            } else {
                if (neighbors == 3) {
                    newBoard[x][y] = 1;
                } else {
                    newBoard[x][y] = 0;
                }
            }
        }
    }
    board = newBoard;
}

export fn init(width: u16, height: u16) void {
    canvasWidth = width;
    canvasHeight = height;
    iface.setTargetFPS(60);
    iface.setAudioChannelCount(1);
}

const glider = [_][5]u1{
    [_]u1{ 0, 0, 0, 0, 0 },
    [_]u1{ 0, 0, 1, 0, 0},
    [_]u1{ 0, 0, 0, 1, 0},
    [_]u1{ 0, 1, 1, 1, 0},
    [_]u1{ 0, 0, 0, 0, 0},
};

export fn draw(deltaTimeSeconds: f64) void {
    iface.clear();
    const cellSize = if(canvasHeight > canvasWidth) canvasWidth/BOARD_SIDELENGTH else canvasHeight/BOARD_SIDELENGTH;
    const boardSize = BOARD_SIDELENGTH * cellSize;
    const boardX = (canvasWidth - boardSize) / 2;
    const boardY = (canvasHeight - boardSize) / 2;
    for (0..BOARD_SIDELENGTH) |x| {
        for (0..BOARD_SIDELENGTH) |y| {
            if (board[x][y] == 1) {
                const cellX = boardX + x * cellSize;
                const cellY = boardY + y * cellSize;
                iface.setFillColor(255, 255, 255);
                iface.drawRect(@floatFromInt(cellX), @floatFromInt(cellY), @floatFromInt(cellSize), @floatFromInt(cellSize));
            }
        }
    }
    drawMenu();
    updateBoard(deltaTimeSeconds);
    mouseDownThisFrame = false;
}

var menuVisible: bool = true;

fn drawMenu() void {
    if (!menuVisible) {
        if (immediateModeButton(0, 0, "V", .{.width=20, .height=20})) {
            menuVisible = true;
        }
    } else {
        const buttonWidth = 100;
        const buttonHeight = 40;
        if (immediateModeButton(0, 0, "^", .{.width=20, .height=20})) {
            menuVisible = false;
        } else if (immediateModeButton(0, buttonHeight, "Glider", .{.width=buttonWidth, .height=buttonHeight})) {
            tileBoardWith(glider.len, glider[0].len, glider);
        } else if (immediateModeButton(0, 2*buttonHeight, "Clear", .{.width=buttonWidth, .height=buttonHeight})) {
            board = [_][BOARD_SIDELENGTH]u1{ [_]u1{0}**BOARD_SIDELENGTH } ** BOARD_SIDELENGTH;
        } else if (immediateModeButton(0, 3*buttonHeight, "Update", .{.width=buttonWidth, .height=buttonHeight})) {
            updateBoard(999.0);
        } else if (immediateModeButton(0, 4*buttonHeight, "Pause", .{.width=buttonWidth, .height=buttonHeight})) {
            updateRate = 999.0;
        } else if (immediateModeButton(0, 5*buttonHeight, "1 FPS", .{.width=buttonWidth, .height=buttonHeight})) {
            updateRate = 1.0;
        } else if (immediateModeButton(0, 6*buttonHeight, "2 FPS", .{.width=buttonWidth, .height=buttonHeight})) {
            updateRate = 0.5;
        } else if (immediateModeButton(0, 7*buttonHeight, "10 FPS", .{.width=buttonWidth, .height=buttonHeight})) {
            updateRate = 0.1;
        } else if (immediateModeButton(0, 8*buttonHeight, "60 FPS", .{.width=buttonWidth, .height=buttonHeight})) {
            updateRate = 1.0/60.0;
        }
    }
}