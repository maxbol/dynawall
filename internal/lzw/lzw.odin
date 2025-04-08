package lzw

import "core:fmt"
import "core:log"
import "core:slice"

LZW_MAX_ENTRY_EXP :: #config(LZW_MAX_ENTRY_EXP, 12)
LZW_MAX_ENTRIES :: #config(LZW_MAX_ENTRIES, 1 << LZW_MAX_ENTRY_EXP)

PEARSON_TABLE := [?]u8 {
	185,
	93,
	140,
	180,
	191,
	107,
	29,
	203,
	3,
	115,
	171,
	37,
	27,
	57,
	201,
	240,
	177,
	36,
	233,
	178,
	188,
	72,
	202,
	109,
	239,
	32,
	49,
	235,
	164,
	45,
	101,
	129,
	69,
	1,
	125,
	92,
	84,
	128,
	103,
	245,
	210,
	189,
	14,
	9,
	170,
	237,
	243,
	249,
	182,
	221,
	187,
	142,
	132,
	139,
	205,
	50,
	225,
	175,
	85,
	122,
	111,
	181,
	130,
	226,
	227,
	198,
	176,
	51,
	80,
	165,
	98,
	96,
	193,
	39,
	156,
	61,
	62,
	246,
	136,
	146,
	121,
	147,
	116,
	138,
	124,
	145,
	135,
	159,
	79,
	7,
	76,
	250,
	254,
	55,
	56,
	172,
	44,
	154,
	223,
	195,
	204,
	255,
	94,
	212,
	220,
	77,
	4,
	253,
	68,
	74,
	232,
	184,
	71,
	20,
	19,
	224,
	13,
	137,
	160,
	81,
	236,
	53,
	21,
	214,
	228,
	163,
	91,
	117,
	231,
	16,
	34,
	90,
	40,
	192,
	33,
	83,
	219,
	100,
	251,
	216,
	208,
	12,
	86,
	247,
	54,
	113,
	0,
	17,
	73,
	244,
	70,
	123,
	59,
	89,
	46,
	31,
	179,
	15,
	75,
	65,
	106,
	95,
	108,
	42,
	230,
	105,
	119,
	168,
	218,
	104,
	151,
	5,
	112,
	64,
	174,
	110,
	229,
	144,
	67,
	183,
	149,
	134,
	194,
	155,
	6,
	97,
	242,
	87,
	30,
	60,
	238,
	158,
	206,
	63,
	150,
	25,
	222,
	200,
	35,
	22,
	133,
	38,
	186,
	173,
	52,
	252,
	114,
	152,
	23,
	58,
	99,
	196,
	118,
	241,
	47,
	248,
	162,
	2,
	24,
	120,
	41,
	169,
	141,
	207,
	211,
	153,
	143,
	26,
	78,
	43,
	11,
	48,
	209,
	127,
	131,
	234,
	190,
	197,
	102,
	167,
	28,
	8,
	161,
	88,
	148,
	126,
	215,
	199,
	217,
	166,
	18,
	10,
	213,
	157,
	66,
	82,
}

BitReader :: struct {
	type: BitResourceType,
	bits: u32,
	buf:  struct {
		pos:  u32,
		data: []u8,
	},
	pos:  u8,
}

BitResourceType :: enum {
	BIT_FILE,
	BIT_BUFFER,
}

BitWriter :: struct {
	type: BitResourceType,
	bits: u32,
	pos:  u8,
	buf:  [dynamic]u8,
}

CompressError :: enum {
	None,
	BufferOverflow,
	MaxBitWidthExceeded,
}

DecompressError :: enum {
	None,
	NilOutputBuffer,
	TooShortInput,
}

Entry :: struct {
	len:  uint,
	prev: uint,
	code: uint,
	val:  u8,
}

Table :: struct {
	type:        TableType,
	size:        uint,
	initialized: []byte,
	entries:     []Entry,
	n_entries:   uint,
}

TableType :: enum {
	LZW_TABLE_COMPRESS,
	LZW_TABLE_DECOMPRESS,
}

br_create :: proc(type: BitResourceType, src: []u8) -> BitReader {
	r := BitReader{}
	r.type = type
	r.bits = 0
	r.buf.pos = 0
	r.buf.data = src
	r.pos = 0

	return r
}

br_peek :: proc(r: ^BitReader, n_bits: u8, result: ^uint) -> bool {
	copy: BitReader

	if r == nil {
		return false
	}
	if result == nil {
		return false
	}
	copy = r^
	return br_read(&copy, n_bits, result)
}

br_read :: proc(r: ^BitReader, n_bits: u8, result: ^uint) -> bool {
	if r == nil || result == nil {
		return false
	}

	for r.pos < n_bits {
		tmp: u32
		if r.buf.pos >= u32(len(r.buf.data)) {
			return false
		}
		tmp = u32(r.buf.data[r.buf.pos])
		r.buf.pos += 1
		r.bits |= (tmp & gen_mask(8)) << r.pos
		r.pos += 8
	}
	result^ = uint(r.bits) & uint(gen_mask(uint(n_bits)))
	r.pos -= n_bits
	r.bits = (r.bits >> n_bits) & gen_mask(uint(r.pos))
	return true
}

bw_create :: proc(type: BitResourceType, dst: rawptr) -> BitWriter {
	b := BitWriter{}
	b.type = type
	b.bits = 0
	b.pos = 0
	b.buf = make([dynamic]u8, 0, 1024)
	return b
}

bw_deinit :: proc(b: ^BitWriter) {
	delete(b.buf)
}

bw_pack :: proc(b: ^BitWriter, n_bits: u8, bits: uint) {
	mask: u32

	if (b == nil) {
		return
	}

	mask = gen_mask(uint(n_bits))
	mask <<= b.pos
	b.bits |= u32(bits << b.pos) & mask
	b.pos += n_bits
	for b.pos >= 8 {
		append(&b.buf, u8(b.bits & 0xff))
		b.pos -= 8
		b.bits = (b.bits >> 8) & gen_mask(uint(b.pos))
	}
}

bw_result :: proc(b: ^BitWriter) -> [dynamic]u8 {
	if b == nil {
		return nil
	}

	if b.pos != 0 {
		append(&b.buf, u8(b.bits & gen_mask(uint(b.pos))))
	}

	return b.buf
}

compress :: proc(bit_size: byte, src: []byte, gif_format: bool) -> (CompressError, [dynamic]u8) {
	bit_width := bit_size + 1

	b := bw_create(.BIT_BUFFER, nil)

	ctable := table_create(.LZW_TABLE_COMPRESS, bit_size)
	defer table_deinit(&ctable)

	if gif_format {
		bw_pack(&b, bit_width, 1 << bit_size)
	}

	size := len(src)
	i: uint = 0

	for {
		code: uint = 0
		e := Entry {
			len = 0,
		}

		for {
			e.val = src[i]
			i += 1
			e.prev = code
			e.len += 1
			size -= 1

			if size == 0 {
				bw_pack(&b, bit_width, code)
				i -= 1
				code = uint(src[i])
				break
			}

			if table_lookup_entry(&ctable, &e, &code) == false {
				break
			}
		}

		table_add(&ctable, &e)
		bw_pack(&b, bit_width, code)

		if ctable.n_entries >= LZW_MAX_ENTRIES {
			// Emit clear code
			bw_pack(&b, bit_width, 1 << bit_size)

			// Reset bit width
			bit_width = bit_size + 1

			// Reset table
			table_deinit(&ctable)
			ctable = table_create(.LZW_TABLE_COMPRESS, bit_size)
		} else if ctable.n_entries > (1 << bit_width) {
			bit_width += 1
		}

		if size == 0 {
			break
		}

		size += 1
		i -= 1
	}

	if gif_format {
		bw_pack(&b, bit_width, (1 << bit_size) + 1)
	}

	return nil, bw_result(&b)
}

debug_print_table :: proc(table: ^Table) {
	EntryWithIndex :: struct {
		entry: Entry,
		index: int,
	}
	table_entries_sorted := make([dynamic]EntryWithIndex, 0, table.n_entries)
	defer delete(table_entries_sorted)
	for e, i in table.entries {
		if table.type == .LZW_TABLE_DECOMPRESS || table.initialized[i] != 0 {
			entry_with_index: EntryWithIndex = {
				entry = e,
				index = i,
			}
			append(&table_entries_sorted, entry_with_index)
		}
	}

	sort_ctable_entries :: proc(i, j: EntryWithIndex) -> bool {
		return i.entry.code < j.entry.code
	}

	slice.sort_by(table_entries_sorted[:], sort_ctable_entries)

	for ei in table_entries_sorted {
		fmt.printfln(
			"Table entry %d: %s (%i), code = %i, len = %i, prev = %i",
			ei.index,
			string([]u8{ei.entry.val}),
			ei.entry.val,
			ei.entry.code,
			ei.entry.len,
			ei.entry.prev,
		)
	}
}


compress_gif :: proc(bit_size: u8, src: []u8) -> (CompressError, [dynamic]u8) {
	return compress(bit_size, src, true)
}

decompress :: proc(bit_size: u8, src: []byte) -> (DecompressError, [dynamic]u8) {
	bit_width := bit_size + 1
	code: uint

	output := make([dynamic]u8, 0, 4096)

	dtable := table_create(.LZW_TABLE_DECOMPRESS, bit_size)
	defer table_deinit(&dtable)

	b := br_create(.BIT_BUFFER, src)

	for br_read(&b, bit_width, &code) == true {
		cur: Entry

		if code == (1 << bit_size) {
			bit_width = bit_size + 1
			dtable.n_entries = (1 << bit_size) + 2
			continue
		}

		if code == (1 << bit_size) + 1 {
			break
		}

		if table_lookup_code(&dtable, code, &cur) == true {
			next_code: uint
			i: u32
			buf: [dynamic]u8
			new, next: Entry

			table_str(&dtable, code, &buf)
			for i := len(buf); i > 0; i -= 1 {
				append(&output, buf[i - 1])
			}
			delete(buf)
			if (dtable.n_entries + 1 > (1 << bit_width)) && (bit_width < LZW_MAX_ENTRY_EXP) {
				bit_width += 1
			}
			if br_peek(&b, bit_width, &next_code) == false {
				continue
			}
			new.len = cur.len + 1
			if table_lookup_code(&dtable, next_code, &next) {
				new.val = entry_head(&dtable, &next)
			} else {
				new.val = entry_head(&dtable, &cur)
			}
			new.prev = code
			table_add(&dtable, &new)
		}
	}

	return nil, output
}

entry_head :: proc(t: ^Table, e: ^Entry) -> u8 {
	result: u8
	len: u32
	tmp: Entry

	if t == nil {
		return 0
	}
	if e == nil {
		return 0
	}
	tmp = e^
	len = u32(tmp.len)
	for len > 0 {
		result = tmp.val
		table_lookup_code(t, tmp.prev, &tmp)
		len -= 1
	}
	return result
}

gen_mask :: proc(len: uint) -> u32 {
	mask: u32

	switch (len) {
	case 0:
		mask = 0x0000
	case 1:
		mask = 0x0001
	case 2:
		mask = 0x0003
	case 3:
		mask = 0x0007
	case 4:
		mask = 0x000f
	case 5:
		mask = 0x001f
	case 6:
		mask = 0x003f
	case 7:
		mask = 0x007f
	case 8:
		mask = 0x00ff
	case 9:
		mask = 0x01ff
	case 10:
		mask = 0x03ff
	case 11:
		mask = 0x07ff
	case 12:
		mask = 0x0fff
	case 13:
		mask = 0x1fff
	case 14:
		mask = 0x3fff
	case 15:
		mask = 0x7fff
	case 16:
		mask = 0xffff
	case 17:
		mask = 0x0001ffff
	case 18:
		mask = 0x0003ffff
	case 19:
		mask = 0x0007ffff
	case 20:
		mask = 0x000fffff
	case 21:
		mask = 0x001fffff
	case 22:
		mask = 0x003fffff
	case 23:
		mask = 0x007fffff
	case 24:
		mask = 0x00ffffff
	case 25:
		mask = 0x01ffffff
	case 26:
		mask = 0x03ffffff
	case 27:
		mask = 0x07ffffff
	case 28:
		mask = 0x0fffffff
	case 29:
		mask = 0x1fffffff
	case 30:
		mask = 0x3fffffff
	case 31:
		mask = 0x7fffffff
	case 32:
		mask = 0xffffffff
	case:
		mask = 0x0000
	}

	return mask
}

hash16 :: proc(e: ^Entry) -> uint {
	c: [5]u8
	result: [5]u8

	if (e == nil) {
		return 0
	}

	c[0] = u8(e.len & 0xff)
	c[1] = u8((e.len >> 8) & 0xff)
	c[2] = u8(e.len & 0xff)
	c[3] = u8((e.prev >> 8) & 0xff)
	c[4] = e.val

	result[0] = PEARSON_TABLE[0 ~ c[0]]
	result[1] = PEARSON_TABLE[result[0] ~ c[1]]
	result[2] = PEARSON_TABLE[result[1] ~ c[2]]
	result[3] = PEARSON_TABLE[result[2] ~ c[3]]
	result[4] = PEARSON_TABLE[result[3] ~ c[4]]

	hash := (uint(result[0]) << 8) | uint(result[1])
	hash ~= (uint(result[2]) << 8) | uint(result[3])
	hash ~= (uint(result[4]) << 8) | uint(result[4])

	return hash
}

table_add :: proc(t: ^Table, e: ^Entry) {
	if (t == nil || e == nil) {
		return
	}

	if t.n_entries >= LZW_MAX_ENTRIES {
		fmt.println(
			"Warning: t.entries length is greater than or equal to LZW_MAX_ENTRIES, not adding to table",
		)
		return
	}

	if t.type == .LZW_TABLE_COMPRESS {
		i: uint
		i = hash16(e) % t.size
		for t.initialized[i] != 0 {
			i = (i + 1) % t.size
		}
		e.code = t.n_entries
		t.entries[i] = e^
		t.initialized[i] = 1
		t.n_entries += 1
	} else {
		e.code = t.n_entries
		t.entries[t.n_entries] = e^
		t.n_entries += 1
	}
}

table_create :: proc(type: TableType, bit_size: u8) -> Table {
	len: uint = 1 << bit_size
	t := Table{}
	t.type = type
	if t.type == .LZW_TABLE_COMPRESS {
		t.size = LZW_MAX_ENTRIES * 4 / 3
		t.entries = make([]Entry, t.size)
		t.initialized = make([]byte, t.size)
		slice.fill(t.initialized, 0)
	} else {
		t.entries = make([]Entry, LZW_MAX_ENTRIES)
	}
	for i: uint = 0; i < len + 2; i += 1 {
		e := Entry{}
		e.len = 1
		e.prev = 0
		e.code = i
		e.val = byte(i)
		table_add(&t, &e)
	}


	return t
}

table_deinit :: proc(t: ^Table) {
	if t == nil {
		return
	}

	if t.type == .LZW_TABLE_COMPRESS {
		delete(t.initialized)
	}

	delete(t.entries)
}


table_lookup_code :: proc(t: ^Table, code: uint, out_e: ^Entry) -> bool {
	if t == nil {
		return false
	}

	if code < t.n_entries {
		out_e^ = t.entries[code]
		return true
	}

	return false
}

table_lookup_entry :: proc(t: ^Table, e: ^Entry, out_code: ^uint) -> bool {
	if t == nil || e == nil || out_code == nil {
		return false
	}

	for i: uint = hash16(e) % t.size; t.initialized[i] != 0; i = (i + 1) % t.size {
		if t.entries[i].len == e.len {
			if t.entries[i].prev == e.prev && t.entries[i].val == e.val {
				out_code^ = t.entries[i].code
				return true
			}
		}
	}

	return false
}

table_str :: proc(t: ^Table, code: uint, out_buf: ^[dynamic]u8) {
	i, size: u32
	e: Entry

	if t == nil {
		return
	}
	if out_buf == nil {
		return
	}
	if code > t.n_entries {
		return
	}
	if table_lookup_code(t, code, &e) == false {
		return
	}

	size = u32(e.len)
	out_buf^ = make([dynamic]u8, size)

	for i: u32 = 0; i < size; i += 1 {
		out_buf[i] = e.val
		table_lookup_code(t, e.prev, &e)
	}
}
