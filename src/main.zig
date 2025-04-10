//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const root = @import("root.zig");

const Coin = root.coin.Coin;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn main() !void {}

pub const TM = struct {
    input_len: usize,
    coin: Coin,

    pro_clauses: []Clause,
    contra_clauses: []Clause,

    res: bool,

    arena: std.heap.ArenaAllocator,

    pub fn init(clauses_num: usize, len: usize, prob: u8, allocator: Allocator) !TM {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const arena_allocator = arena.allocator();

        const pro_clauses = try arena_allocator.alloc(Clause, clauses_num);
        const contra_clauses = try arena_allocator.alloc(Clause, clauses_num);

        for (pro_clauses) |*clause| {
            clause.* = try Clause.init(len, arena_allocator);
        }

        for (contra_clauses) |*clause| {
            clause.* = try Clause.init(len, arena_allocator);
        }

        return .{
            .input_len = len,
            .coin = Coin.init(prob),
            .pro_clauses = pro_clauses,
            .contra_clauses = contra_clauses,
            .res = false,
            .arena = arena,
        };
    }

    pub fn deinit(self: *TM) void {
        self.arena.deinit();
    }

    pub fn predict(self: *TM, vector: []const bool) !bool {
        if (vector.len != self.input_len) return TMError.InvalidInputLen;

        const pro_count = try clausesPredict(self.pro_clauses, vector);
        const contra_count = try clausesPredict(self.contra_clauses, vector);

        self.res = pro_count >= contra_count;

        return self.res;
    }

    pub fn trainStep(self: *TM, vector: []const bool, right: bool) void {
        // Если правильный ответ - истина, мы должны взять те из про-клавишь, которые не голосовали,
        // и поучить их голосовать.
        // А те из контра-клавишь, которые голосовали против, нужно взять, и поучить их не
        // голосовать.

        // Если правильный ответ - ложь, мы должны взять те из про-клавишь, которые голосовали, и
        // поучить их не голосовать.
        // А те из контра-клавишь, которые не голосовали, нужно приучать голосовать

        const coin = &self.coin;

        if (right) {
            for (self.pro_clauses) |*clause| {
                if (!clause.res) {
                    clause.enforse(vector, coin);
                }
            }

            for (self.contra_clauses) |*clause| {
                if (clause.res) {
                    clause.disforse(vector, coin);
                }
            }
        } else {
            for (self.pro_clauses) |*clause| {
                if (clause.res) {
                    clause.disforse(vector, coin);
                }
            }
            for (self.contra_clauses) |*clause| {
                if (!clause.res) {
                    clause.enforse(vector, coin);
                }
            }
        }
    }

    pub fn train(self: *TM, dataset: [][]bool) !void {
        for (dataset) |label| {
            const vector = label[0..(label.len - 1)];
            const right = label[label.len - 1];

            _ = try self.predict(vector);
            self.trainStep(vector, right);
        }
    }
};

const TMError = error{
    InvalidInputLen,
};

pub const Clause = struct {
    res: bool,
    pos: []Weight,
    neg: []Weight,

    pub fn init(len: usize, allocator: Allocator) !Clause {
        const pos_array = try allocator.alloc(Weight, len);
        const neg_array = try allocator.alloc(Weight, len);

        return .{
            .res = false,
            .pos = pos_array,
            .neg = neg_array,
        };
    }

    pub fn predict(self: *Clause, vector: []const bool) !bool {
        if (vector.len != self.pos.len) return TMError.InvalidInputLen;

        const pos_res = weightsPredict(self.pos, vector, false);
        const neg_res = weightsPredict(self.neg, vector, true);

        self.res = pos_res and neg_res;

        return self.res;
    }

    // Побуждает клаузу голосовать за.
    pub fn enforse(self: *Clause, vector: []const bool, coin: *Coin) void {
        for (self.pos, vector) |*weight, val| {
            if (isActive(weight.*) == val) {
                if (coin.throw()) enforceWeight(weight);
            } else {
                if (coin.throw()) disforceWeight(weight);
            }
        }

        for (self.neg, vector) |*weight, val| {
            if (isActive(weight.*) == !val) {
                if (coin.throw()) enforceWeight(weight);
            } else {
                if (coin.throw()) disforceWeight(weight);
            }
        }
    }

    // Побуждает клаузу голосовать против.
    pub fn disforse(self: *Clause, vector: []const bool, coin: *Coin) void {
        for (self.pos, vector) |*weight, val| {
            if (isActive(weight.*) == val) {
                if (coin.throw()) disforceWeight(weight);
            } else {
                if (coin.throw()) enforceWeight(weight);
            }
        }

        for (self.neg, vector) |*weight, val| {
            if (isActive(weight.*) == !val) {
                if (coin.throw()) disforceWeight(weight);
            } else {
                if (coin.throw()) enforceWeight(weight);
            }
        }
    }
};

const Weight = i8;

fn weightsPredict(weights: []Weight, vector: []const bool, isInvert: bool) bool {
    for (weights, vector) |weight, val| {
        if (isActive(weight) and xor(val, isInvert)) {
            continue;
        } else {
            return false;
        }
    }
    return true;
}

fn clausesPredict(clauses: []Clause, vector: []const bool) !usize {
    var count: usize = 0;
    for (clauses) |*clause| {
        const res = try clause.predict(vector);
        if (res) count += 1;
    }
    return count;
}

fn encourageClauses(clauses: []Clause, vector: []const bool, right: bool, s: u8) void {
    for (clauses) |*clause| {
        clause.train(vector, right, s);
    }
}

fn isActive(weight: Weight) bool {
    return weight >= 0;
}

fn enforceWeight(weight: *Weight) void {
    weight.* += 1;
}

fn disforceWeight(weight: *Weight) void {
    weight.* -= 1;
}

fn xor(a: bool, b: bool) bool {
    return (a or b) and !(a and b);
}

test "TM.init" {
    const allocator = std.testing.allocator;
    var tm = try TM.init(5, 5, 40, allocator);
    defer tm.deinit();
}

test "TM.predict" {
    const allocator = std.testing.allocator;
    var tm = try TM.init(5, 2, 50, allocator);
    defer tm.deinit();

    const vec = [2]bool{ true, true };

    _ = try tm.predict(&vec);
}

test "TM.train" {
    const allocator = std.testing.allocator;
    var tm = try TM.init(20, 2, 50, allocator);
    defer tm.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    const arena_allocator = arena.allocator();
    defer arena.deinit();

    const data = &[_][]const bool{
        &[_]bool{ false, false, false },
        &[_]bool{ false, true, true },
        &[_]bool{ true, false, true },
        &[_]bool{ true, true, false },
    };

    var dataset = try arena_allocator.alloc([]bool, data.len);
    for (data, 0..data.len) |rec, i| {
        dataset[i] = try arena_allocator.dupe(bool, rec);
    }

    for (0..200) |_| {
        try tm.train(dataset);
    }

    for (dataset) |rec| {
        const res = try tm.predict(rec[0..(rec.len - 1)]);
        assert(res == rec[rec.len - 1]);
    }
}
