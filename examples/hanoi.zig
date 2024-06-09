const std = @import("std");
const iface = @import("interface.zig");

const MUSIC_CHANNEL = 0;
const UI_CHANNEL = 1;
const SFX_CHANNEL = 2;
const AUDIO_CHANNEL_COUNT = 3;

const title: []const u8 = "Hanoi";

const TOWER_HEIGHT: u8 = 5;
const TOWER_COUNT: u8 = 4;
const TARGET_FPS = 60;

const Brick = struct { x: f64, y: f64, depth: f64, width: u8, tower: u1 };

const Board = [TOWER_COUNT][TOWER_HEIGHT]?Brick;

const Game = struct {
    towers: Board,
    moves: u32 = 0,
    hover_mark_x: f64,
    selected_tower: ?u8,
};

var canvasWidth: u16 = 0;
var canvasHeight: u16 = 0;
var mouseX: u16 = 0;
var mouseY: u16 = 0;
var mouseDown: bool = false;
var brick_scale: u8 = 30;
var tower_colors = [2][3]u8{ [3]u8{ 255, 0, 0 }, [3]u8{ 0, 0, 255 } };
var game_base_height: f64 = 0;
var game: ?Game = null;

fn setCanvasWidthHeight(width: u16, height: u16) void {
    canvasWidth = width;
    canvasHeight = height;
    const width_scale = width / (2 * TOWER_COUNT * TOWER_HEIGHT);
    const height_scale = height / 3 / (TOWER_HEIGHT + (1 + TOWER_HEIGHT) >> 1);
    if (height_scale < width_scale) {
        brick_scale = @intCast(height_scale);
    } else {
        brick_scale = @intCast(width_scale);
    }
}

export fn init(width: u16, height: u16) void {
    setCanvasWidthHeight(width, height);
    iface.setTargetFPS(TARGET_FPS);
    iface.setAudioChannelCount(AUDIO_CHANNEL_COUNT);
    setStrokePureWhite();
    new_game();
}

export fn mousemove(x: u16, y: u16) void {
    mouseX = x;
    mouseY = y;
}

export fn mousedown(button: u8) void {
    if (button == 0) {
        mouseDown = true;
    }
}

fn new_game() void {
    var towers: Board = undefined;
    const initial_y: f64 = -2 * @as(f64, @floatFromInt(canvasHeight));
    const initial_x: f64 = @floatFromInt(canvasWidth >> 1);
    for (&towers[0], 0..) |*brick, height| {
        brick.* = Brick{ .x = initial_x, .y = initial_y, .depth = 0, .width = @intCast(height + 1), .tower = 1 };
    }
    for (towers[1 .. towers.len - 1]) |*tower| {
        for (tower) |*brick| {
            brick.* = null;
        }
    }
    for (&towers[towers.len - 1], 0..) |*brick, height| {
        brick.* = Brick{ .x = initial_x, .y = initial_y, .depth = 0, .width = @intCast(height + 1), .tower = 0 };
    }
    game = Game{ .moves = 0, .towers = towers, .hover_mark_x = initial_x, .selected_tower = null };
}

export fn draw(deltaTimeSeconds: f64) void {
    drawGameBG(deltaTimeSeconds);
    if (game) |*game_data| {
        drawGame(deltaTimeSeconds, game_data);
    } else {
        drawMainMenu(deltaTimeSeconds);
    }
    drawGameBase(deltaTimeSeconds, game != null);

    mouseDown = false;
}

fn drawDiamondBottomHalf(x: f64, y: f64, radius: f64, thickness: f64) void {
    iface.drawLine(x - radius, y, x, y + radius, thickness);
    iface.drawLine(x + radius, y, x, y + radius, thickness);
}

fn drawDiamond(x: f64, y: f64, radius: f64, thickness: f64) void {
    iface.drawLine(x - radius, y, x, y - radius, thickness);
    iface.drawLine(x + radius, y, x, y - radius, thickness);
    drawDiamondBottomHalf(x, y, radius, thickness);
}

fn drawCrissCross(x: f64, y: f64, radius: f64, thickness: f64) void {
    iface.drawLine(x - radius, y - radius, x + radius, y + radius, thickness);
    iface.drawLine(x - radius, y + radius, x + radius, y - radius, thickness);
}

fn drawBrick(brick: Brick) void {
    const color = tower_colors[brick.tower];
    const width_scaled = @as(f64, @floatFromInt(brick.width)) * @as(f64, @floatFromInt(brick_scale));
    const left = brick.x - width_scaled;
    const width = 2 * width_scaled;
    const top = brick.y - @as(f64, @floatFromInt(brick_scale));
    iface.setFillColor(color[0] >> 1, color[1] >> 1, color[2] >> 1);
    iface.drawRect(left, top, width, @floatFromInt(brick_scale));
    const reduction = @as(f64, @floatFromInt(brick_scale)) * brick.depth / 5;
    iface.setFillColor(color[0], color[1], color[2]);
    iface.drawRect(left + reduction, top + reduction, width - reduction * 2, @as(f64, @floatFromInt(brick_scale)) - reduction * 2);
}

fn drawGameBG(deltaTimeSeconds: f64) void {
    iface.setAlpha(@min(1, 3 * deltaTimeSeconds));
    iface.setFillColor(0, 0, 0);
    iface.drawRect(0, 0, @floatFromInt(canvasWidth), @floatFromInt(canvasHeight));
    iface.setAlpha(1.0);
}

fn drawGameBase(deltaTimeSeconds: f64, game_on: bool) void {
    var height_target: f64 = 1.0;
    if (game_on) {
        height_target = @as(f64, @floatFromInt(canvasHeight)) / 3;
    }
    const height_delta = height_target - game_base_height;
    game_base_height += height_delta * @min(deltaTimeSeconds, 1);
    iface.setFillColor(50, 50, 50);
    iface.drawRect(0, @as(f64, @floatFromInt(canvasHeight)) - game_base_height, @floatFromInt(canvasWidth), game_base_height);
}

fn drawMainMenu(deltaTimeSeconds: f64) void {
    iface.drawRect(100, 100, deltaTimeSeconds * 100, 100);
}

fn drawGame(deltaTimeSeconds: f64, game_data: *Game) void {
    updateUI(deltaTimeSeconds, game_data);
    for (&game_data.towers, 0..) |*tower, tower_idx| {
        for (tower, 0..) |*brick_place, height| {
            if (brick_place.*) |*brick| {
                updateBrick(deltaTimeSeconds, brick, @intCast(tower_idx), @intCast(height));
                drawBrick(brick.*);
            }
        }
    }
}

fn towerX(tower: u8) f64 {
    const center: f64 = @floatFromInt(canvasWidth >> 1);
    const offset_x: f64 = @floatFromInt((1 + 2 * @as(u16, @intCast(tower))) * TOWER_HEIGHT * brick_scale);
    const max_x: f64 = @floatFromInt((2 * @as(u16, @intCast(TOWER_COUNT))) * TOWER_HEIGHT * brick_scale);
    return offset_x - (max_x / 2) + center;
}

fn towerTopBrickPosition(tower_data: [TOWER_HEIGHT]?Brick) ?u8 {
    for (tower_data, 0..) |brick, i| {
        if (brick != null) {
            return @intCast(i);
        }
    }
    return null;
}

fn setStrokePureWhite() void {
    iface.setStrokeColor(255, 255, 255);
}

fn setStrokeWhiteBrightness(brightness: f64) void {
    const v: u8 = @intFromFloat(std.math.clamp(brightness * 255, 0, 255));
    iface.setStrokeColor(v, v, v);
}

fn makeMoveOnTower(game_data: *Game, tower: u8) bool {
    if (game_data.selected_tower) |selected_tower_index| {
        const source_tower = &game_data.towers[selected_tower_index];
        const target_tower = &game_data.towers[tower];
        game_data.selected_tower = null;
        if (towerTopBrickPosition(source_tower.*)) |source_brick_height| {
            const source_brick = &source_tower[source_brick_height];
            if (towerTopBrickPosition(target_tower.*)) |target_brick_below_height| {
                const target_brick_below = target_tower[target_brick_below_height];
                if (source_brick.*.?.width < target_brick_below.?.width) {
                    const target_brick = &target_tower[target_brick_below_height - 1];
                    target_brick.* = source_brick.*;
                    source_brick.* = null;
                    return true;
                }
            } else {
                // Target tower is empty -- insert into its bottom position
                target_tower.*[target_tower.*.len - 1] = source_brick.*;
                source_brick.* = null;
                return true;
            }
        }
        return false;
    } else {
        if (towerTopBrickPosition(game_data.towers[@intCast(tower)])) |_| {
            game_data.selected_tower = tower;
        } else {
            return false;
        }
        return true;
    }
}

fn updateUI(deltaTimeSeconds: f64, game_data: *Game) void {
    const ui_centerline_screen_fraction = 6;
    const ui_centerline_y: f64 = @as(f64, @floatFromInt(canvasHeight)) / ui_centerline_screen_fraction;
    const brick_scale_float: f64 = @floatFromInt(brick_scale);
    var hovered_tower: ?u8 = null;
    if (mouseX > 0 and mouseY > 0) {
        if (mouseY > canvasHeight / 6 and mouseY < canvasHeight * 2 / 3) {
            const the_hovered_tower: u8 = @intCast(mouseX * TOWER_COUNT / canvasWidth);
            hovered_tower = the_hovered_tower;
            if (mouseDown) {
                mouseDown = false;
                if (makeMoveOnTower(game_data, the_hovered_tower)) {
                    drawDiamond(towerX(the_hovered_tower), ui_centerline_y, brick_scale_float, 4);
                } else {
                    drawCrissCross(towerX(the_hovered_tower), ui_centerline_y - brick_scale_float, brick_scale_float, 4);
                }
            }
        }
    }
    if (game_data.selected_tower) |tower| {
        const target_x = towerX(tower);
        setStrokePureWhite();
        drawDiamond(target_x, ui_centerline_y, brick_scale_float, 4);
    }
    if (hovered_tower) |tower| {
        const screen_fraction_to_jump_to = 8;
        const canvas_width_float = @as(f64, @floatFromInt(canvasWidth));
        const target_x = towerX(tower);
        const target_y: f64 = ui_centerline_y + brick_scale_float;
        for (0..4) |_| {
            const delta_x = target_x - game_data.hover_mark_x;
            if (@abs(delta_x) < canvas_width_float / screen_fraction_to_jump_to) {
                game_data.hover_mark_x += delta_x * @min(4 * deltaTimeSeconds, 1);
                setStrokeWhiteBrightness(1 - screen_fraction_to_jump_to * @abs(delta_x) / canvas_width_float);
                drawDiamondBottomHalf(game_data.hover_mark_x, target_y, @floatFromInt(brick_scale), 2);
            } else {
                const movement_frac = delta_x * (screen_fraction_to_jump_to - 1) / screen_fraction_to_jump_to;
                game_data.hover_mark_x += movement_frac;
            }
        }
    }
}

fn updateBrick(deltaTimeSeconds: f64, brick: *Brick, tower: u8, height: u8) void {
    const target_x = towerX(tower);
    const target_y = @as(f64, @floatFromInt(canvasHeight)) * 2 / 3 - @as(f64, @floatFromInt((3 * @as(u16, @intCast(TOWER_HEIGHT - height))) * brick_scale)) / 2;
    const distance = @abs(target_x - brick.x) + @abs(target_y - brick.y);
    var depth_target: f64 = 1.0;
    if (distance > 10) {
        depth_target = 0.0;
    }
    const depth_delta = depth_target - brick.depth;
    const position_delta_ratio = @min(deltaTimeSeconds * 2 * (1.0 - depth_delta), 1);
    brick.x += (target_x - brick.x) * position_delta_ratio;
    brick.y += (target_y - brick.y) * position_delta_ratio;
    brick.depth += depth_delta * @min(deltaTimeSeconds * 2, 1);
}
