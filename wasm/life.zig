const max_cells: usize = 1000000;

var width: usize = 0;
var height: usize = 0;

var grid: [max_cells]u8 = [_]u8{0} ** max_cells;
var next: [max_cells]u8 = [_]u8{0} ** max_cells;

export fn set_size(cols: u32, rows: u32) void {
    if (cols == 0 or rows == 0) {
        width = 0;
        height = 0;
        return;
    }

    var w: usize = @intCast(cols);
    var h: usize = @intCast(rows);

    while (w * h > max_cells) {
        if (w > h) {
            w -= 1;
        } else {
            h -= 1;
        }
    }

    width = w;
    height = h;

    const size = width * height;
    var i: usize = 0;
    while (i < size) : (i += 1) {
        grid[i] = 0;
        next[i] = 0;
    }
}

export fn ptr() usize {
    return @intFromPtr(&grid[0]);
}

fn wrap(value: isize, max: usize) usize {
    const m: isize = @intCast(max);
    var v = @mod(value, m);
    if (v < 0) v += m;
    return @intCast(v);
}

export fn splat(x_in: u32, y_in: u32) void {
    if (width == 0 or height == 0) return;

    const w = width;
    const h = height;
    const x: isize = @intCast(x_in);
    const y: isize = @intCast(y_in);

    var dy: isize = -2;
    while (dy <= 2) : (dy += 1) {
        var dx: isize = -2;
        while (dx <= 2) : (dx += 1) {
            const nx = wrap(x + dx, w);
            const ny = wrap(y + dy, h);
            grid[ny * w + nx] = 1;
        }
    }
}

export fn step() void {
    if (width == 0 or height == 0) return;

    const w = width;
    const h = height;
    const size = w * h;

    var y: usize = 0;
    while (y < h) : (y += 1) {
        const y_up = if (y == 0) h - 1 else y - 1;
        const y_down = if (y + 1 == h) 0 else y + 1;
        var x: usize = 0;
        while (x < w) : (x += 1) {
            const x_left = if (x == 0) w - 1 else x - 1;
            const x_right = if (x + 1 == w) 0 else x + 1;

            var count: u8 = 0;
            count += grid[y_up * w + x_left];
            count += grid[y_up * w + x];
            count += grid[y_up * w + x_right];
            count += grid[y * w + x_left];
            count += grid[y * w + x_right];
            count += grid[y_down * w + x_left];
            count += grid[y_down * w + x];
            count += grid[y_down * w + x_right];

            const idx = y * w + x;
            const alive = grid[idx] == 1;
            next[idx] = if (alive) (if (count == 2 or count == 3) 1 else 0) else (if (count == 3) 1 else 0);
        }
    }

    var i: usize = 0;
    while (i < size) : (i += 1) {
        grid[i] = next[i];
    }
}
