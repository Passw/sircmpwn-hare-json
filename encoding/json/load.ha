use memio;
use io;
use strings;
use types;

// Options for [[load]].
export type load_option = nestlimit;

// The maximum number of nested objects or arrays that can be entered before
// erroring out.
export type nestlimit = uint;

// Parses a JSON value from the given [[io::handle]], returning the value or an
// error. The return value is allocated on the heap; use [[finish]] to free it
// up when you're done using it.
//
// By default, this function assumes non-antagonistic inputs, and does not limit
// recursion depth or memory usage. You may want to set a custom [[nestlimit]],
// or incorporate an [[io::limitreader]] or similar. Alternatively, you can use
// the JSON lexer ([[lex]]) directly if dealing with potentially malicious
// inputs.
export fn load(src: io::handle, opts: load_option...) (value | nomem | error) = {
	let limit = types::UINT_MAX;
	for (let i = 0z; i < len(opts); i += 1) {
		limit = opts[i]: nestlimit: uint;
	};
	const lex = newlexer(src);
	defer close(&lex);
	return _load(&lex, 0, limit);
};

// Parses a JSON value from the given string, returning the value or an error.
// The return value is allocated on the heap; use [[finish]] to free it up when
// you're done using it.
//
// See the documentation for [[load]] for information on dealing with
// potentially malicious inputs.
export fn loadstr(input: str, opts: load_option...) (value | nomem | error) = {
	let src = memio::fixed(strings::toutf8(input));
	return load(&src, opts...);
};

fn _load(lexer: *lexer, level: uint, limit: uint) (value | nomem | error) = {
	const tok = mustscan(lexer)?;
	match (tok) {
	case _null =>
		return _null;
	case let b: bool =>
		return b;
	case let f: f64 =>
		return f;
	case let s: str =>
		return strings::dup(s)?;
	case arraystart =>
		if (level == limit) {
			return limitreached;
		};
		return _load_array(lexer, level + 1, limit);
	case objstart =>
		if (level == limit) {
			return limitreached;
		};
		return _load_obj(lexer, level + 1, limit);
	case (arrayend | objend | colon | comma) =>
		return lexer.loc: invalid;
	};
};

fn _load_array(lexer: *lexer, level: uint, limit: uint) (value | nomem | error) = {
	let success = false;
	let array: []value = [];
	defer if (!success) finish(array);
	let tok = mustscan(lexer)?;
	match (tok) {
	case arrayend =>
		success = true;
		return array;
	case =>
		unlex(lexer, tok);
	};

	for (true) {
		append(array, _load(lexer, level, limit)?)?;

		tok = mustscan(lexer)?;
		match (tok) {
		case comma => void;
		case arrayend => break;
		case =>
			return lexer.loc: invalid;
		};
	};
	success = true;
	return array;
};

fn _load_obj(lexer: *lexer, level: uint, limit: uint) (value | nomem | error) = {
	let success = false;
	let obj = newobject();
	defer if (!success) finish(obj);
	let tok = mustscan(lexer)?;
	match (tok) {
	case objend =>
		success = true;
		return obj;
	case =>
		unlex(lexer, tok);
	};

	for (true) {
		let tok = mustscan(lexer)?;
		const key = match (tok) {
		case let s: str =>
			yield strings::dup(s)?;
		case =>
			return lexer.loc: invalid;
		};
		defer free(key);

		tok = mustscan(lexer)?;
		if (!(tok is colon)) {
			return lexer.loc: invalid;
		};

		put(&obj, key, _load(lexer, level, limit)?)?;

		tok = mustscan(lexer)?;
		match (tok) {
		case comma => void;
		case objend => break;
		case =>
			return lexer.loc: invalid;
		};
	};

	success = true;
	return obj;
};

fn mustscan(lexer: *lexer) (token | error) = {
	match (lex(lexer)?) {
	case io::EOF =>
		lexer.loc.1 += 1;
		return lexer.loc: invalid;
	case let tok: token =>
		return tok;
	};
};
