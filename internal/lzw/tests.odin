package lzw

import "core:log"
import "core:testing"

@(test)
compress_simple_string :: proc(t: ^testing.T) {
	input: []u8 = {'a', 'b', 'a', 'b', '-', 'a', 'b', 'a', 'b'}
	err, out := compress(8, input, false)
	testing.expect(t, err == nil, "Error compressing data")
	defer delete(out)
	log.info("input", input)
	log.info("out", out)

	decompr_err, decompr := decompress(8, out[:])
	testing.expect(t, decompr_err == nil, "Error compressing data")
	defer delete(decompr)

	log.info("decompr", decompr)

	testing.expect_value(t, len(out), 8)

	// for b, i in slice {
	// 	switch i {
	// 	case 0:
	// 		testing.expect(t, b == '0')
	// 	}
	//
	// }
	//
}
