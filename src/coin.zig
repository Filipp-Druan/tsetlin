const std = @import("std");

pub const Coin = struct {
    probability: u8, // Вероятность в процентах
    random: std.Random,

    pub fn init(prob: u8) Coin {
        std.debug.assert(prob <= 100);

        return .{
            .probability = prob,
            .random = std.crypto.random,
        };
    }

    pub fn throw(self: *Coin) bool {
        const num = self.random.intRangeLessThan(u8, 0, 101);
        std.debug.assert(num <= 100);

        return num <= self.probability;
    }
};
