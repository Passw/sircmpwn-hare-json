// License: MPL-2.0
// (c) 2022 Drew DeVault <sir@cmpwn.com>

@test fn object() void = {
	let obj = newobject();
	defer finish(obj);

	set(&obj, "hello", "world")!;
	set(&obj, "foo", "bar")!;
	set(&obj, "the answer", 42.0)!;

	// XXX: Match overhaul?
	assert(*(get(&obj, "hello") as *value) as str == "world");
	assert(*(get(&obj, "foo") as *value) as str == "bar");
	assert(*(get(&obj, "the answer") as *value) as f64 == 42.0);
	assert(get(&obj, "nonexistent") is void);

	del(&obj, "hello");
	assert(get(&obj, "hello") is void);
};

@test fn iterator() void = {
	let obj = newobject();
	defer finish(obj);

	set(&obj, "hello", "world")!;
	set(&obj, "foo", "bar")!;
	set(&obj, "the answer", 42.0)!;

	let it = iter(&obj);
	assert(next(&it) is (const str, const *value));
	assert(next(&it) is (const str, const *value));
	assert(next(&it) is (const str, const *value));
	assert(next(&it) is done);
};

@test fn equal() void = {
	let a = newobject();
	defer finish(a);
	set(&a, "a", 42.0)!;
	set(&a, "A", "hello")!;

	let b = newobject();
	defer finish(b);
	set(&b, "A", "hello")!;
	set(&b, "a", 42.0)!;

	assert(equal(a, b));
};
