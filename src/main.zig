//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {}

const TM = struct {
    clouses: []Clause,
};

const Clause = struct {
    features_num: isize,
    include_weights: []Weight, // Думаю, что такого диапазона хватит
    exclude_weights: []Weight,
    max_depth: u8, // Не должна перешагивать через диапазон

    const Weight = i8;

    pub fn new(allocator: Allocator, features_num: isize, max_depth: u4) !Clause {
        const include_weights = try allocator.alloc(Weight, features_num);
        const exclude_weights = try allocator.alloc(Weight, features_num);

        return .{
            .features_num = features_num,
            .include_weights = include_weights,
            .exclude_weights = exclude_weights,
            .max_depth = max_depth,
        };
    }

    pub fn predict(clause: *Clause, patterns: []const bool) bool {
        const include_res = processWeights(clause.include_weights, patterns);

        if (include_res) { // Так я реализовал более эффективный and
            return processWeights(clause.exclude_weights, patterns);
        } else {
            return false;
        }
    }

    fn processWeights(weights: []const Weight, patterns: []const bool) bool {
        for (weights, patterns) |weight, pattern| {
            if (!isActive(weight)) continue;
            if (pattern == true) continue;

            if (pattern == false) {
                return false;
            }
        }

        return true;
    }

    fn isActive(weight: Weight) bool {
        return weight >= 0;
    }
};
