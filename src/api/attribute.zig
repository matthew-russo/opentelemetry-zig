pub const AttributePrimitive = union(enum) {
    const Self = @This();

    string: []const u8,
    boolean: bool,
    double: f64,
    int: i64,
};

pub const AttributeValue = union(enum) {
    const Self = @This();

    primitive: AttributePrimitive,
    array: []AttributePrimitive,
};
