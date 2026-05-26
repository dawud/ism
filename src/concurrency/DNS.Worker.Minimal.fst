module DNS.Worker.Minimal

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open Steel.Memory
open Steel.ST.Util
open DNS.QUIC.StreamMapping
module EPR = DNS.Protocol.Parser.EverParseRuntime
module CAST = FStar.Int.Cast

let noerror_response_flags_hi (request_flags_hi:FStar.UInt8.t) : FStar.UInt8.t =
  FStar.UInt8.logor 0x80uy (FStar.UInt8.logand request_flags_hi 0x79uy)

let noerror_response_flags_lo (request_flags_lo:FStar.UInt8.t) : FStar.UInt8.t =
  FStar.UInt8.logand request_flags_lo 0x10uy

val scan_uncompressed_qname_length :
  request_buffer:buffer FStar.UInt8.t ->
  request_len:FStar.UInt32.t ->
  pos:FStar.UInt32.t ->
  consumed:FStar.UInt32.t ->
  Stack (n:FStar.UInt32.t{FStar.UInt32.v n <= 255})
    (requires (fun h0 ->
      live h0 request_buffer /\
      FStar.UInt32.v request_len <= LowStar.Buffer.length request_buffer /\
      FStar.UInt32.v request_len <= 271 /\
      FStar.UInt32.v pos <= FStar.UInt32.v request_len /\
      FStar.UInt32.v consumed <= 255))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))
    (decreases (FStar.UInt32.v request_len - FStar.UInt32.v pos))

let rec scan_uncompressed_qname_length request_buffer request_len pos consumed =
  if FStar.UInt32.gte pos request_len then
    0ul
  else
    begin
      assert (FStar.UInt32.v pos < LowStar.Buffer.length request_buffer);
      let label_len_byte = LowStar.Buffer.index request_buffer pos in
      let label_len = CAST.uint8_to_uint32 label_len_byte in
      if FStar.UInt32.eq label_len 0ul then
        if FStar.UInt32.lt consumed 255ul then
          begin
            assert (FStar.UInt32.v consumed + 1 < 4294967296);
            FStar.UInt32.add consumed 1ul
          end
        else
          0ul
      else if FStar.UInt32.gt label_len 63ul then
        0ul
      else
        begin
          assert (FStar.UInt32.v label_len <= 63);
          assert (FStar.UInt32.v pos <= FStar.UInt32.v request_len);
          assert (FStar.UInt32.v request_len <= 271);
          assert (FStar.UInt32.v pos + 1 + FStar.UInt32.v label_len < 4294967296);
          assert (FStar.UInt32.v consumed + 1 + FStar.UInt32.v label_len < 4294967296);
          let step = FStar.UInt32.add 1ul label_len in
          let next_pos = FStar.UInt32.add pos step in
          let next_consumed = FStar.UInt32.add consumed step in
          if FStar.UInt32.gt next_pos request_len ||
             FStar.UInt32.gt next_consumed 255ul then
            0ul
          else
            begin
              assert (FStar.UInt32.v next_pos <= FStar.UInt32.v request_len);
              assert (FStar.UInt32.v next_pos > FStar.UInt32.v pos);
              assert (FStar.UInt32.v next_consumed <= 255);
              scan_uncompressed_qname_length
                request_buffer
                request_len
                next_pos
                next_consumed
            end
        end
    end

val validate_minimal_uncompressed_question_request :
  request_buffer:buffer FStar.UInt8.t ->
  request_len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 request_buffer /\
      FStar.UInt32.v request_len <= LowStar.Buffer.length request_buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_minimal_uncompressed_question_request request_buffer request_len =
  if FStar.UInt32.lt request_len 17ul ||
     FStar.UInt32.lt 271ul request_len then
    false
  else
    begin
      assert (FStar.UInt32.v request_len >= 17);
      assert (11 < LowStar.Buffer.length request_buffer);
      let qd_hi = LowStar.Buffer.index request_buffer 4ul in
      let qd_lo = LowStar.Buffer.index request_buffer 5ul in
      let an_hi = LowStar.Buffer.index request_buffer 6ul in
      let an_lo = LowStar.Buffer.index request_buffer 7ul in
      let ns_hi = LowStar.Buffer.index request_buffer 8ul in
      let ns_lo = LowStar.Buffer.index request_buffer 9ul in
      let ar_hi = LowStar.Buffer.index request_buffer 10ul in
      let ar_lo = LowStar.Buffer.index request_buffer 11ul in
      if FStar.UInt8.eq qd_hi 0x00uy &&
         FStar.UInt8.eq qd_lo 0x01uy &&
         FStar.UInt8.eq an_hi 0x00uy &&
         FStar.UInt8.eq an_lo 0x00uy &&
         FStar.UInt8.eq ns_hi 0x00uy &&
         FStar.UInt8.eq ns_lo 0x00uy &&
         FStar.UInt8.eq ar_hi 0x00uy &&
         FStar.UInt8.eq ar_lo 0x00uy then
        let qname_length =
          scan_uncompressed_qname_length request_buffer request_len 12ul 0ul in
        assert (FStar.UInt32.v qname_length <= 255);
        assert (FStar.UInt32.v qname_length + 16 < 4294967296);
        let expected_request_len = FStar.UInt32.add qname_length 16ul in
        if FStar.UInt32.eq qname_length 0ul ||
           not (FStar.UInt32.eq expected_request_len request_len) then
          false
        else
          begin
            assert (FStar.UInt32.v qname_length > 0);
            assert (FStar.UInt32.v qname_length <= 255);
            assert (12 <= LowStar.Buffer.length request_buffer);
            assert (12 <= FStar.UInt32.v request_len);
            let question_len = FStar.UInt32.sub request_len 12ul in
            let question = LowStar.Buffer.offset request_buffer 12ul in
            let validation_code =
              EPR.check_dns_uncompressed_question_code
                qname_length
                question
                question_len in
            not (FStar.UInt8.eq validation_code 0uy)
          end
      else
        false
    end

val prepare_worker_minimal_error_response_send :
  ctx_ptr:buffer stream_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  request_len:FStar.UInt32.t ->
  ST FStar.UInt32.t
    (requires (fun h0 ->
      live h0 ctx_ptr /\
      LowStar.Buffer.length ctx_ptr >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       live h0 ctx.sc_buf /\
       FStar.UInt32.v request_len <= LowStar.Buffer.length ctx.sc_buf)))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let prepare_worker_minimal_error_response_send
  ctx_ptr
  response_buffer
  response_capacity
  request_len =
  let s = LowStar.Buffer.index ctx_ptr 0ul in
  if FStar.UInt32.lt request_len 12ul ||
     FStar.UInt32.lt response_capacity 12ul then
    0ul
  else
    begin
      assert (FStar.UInt32.v request_len <= LowStar.Buffer.length s.sc_buf);
      assert (12 <= LowStar.Buffer.length response_buffer);
      assert (1 < LowStar.Buffer.length s.sc_buf);
      assert (0 < LowStar.Buffer.length response_buffer);
      assert (1 < LowStar.Buffer.length response_buffer);
      assert (2 < LowStar.Buffer.length response_buffer);
      assert (3 < LowStar.Buffer.length response_buffer);
      assert (4 < LowStar.Buffer.length response_buffer);
      assert (5 < LowStar.Buffer.length response_buffer);
      assert (6 < LowStar.Buffer.length response_buffer);
      assert (7 < LowStar.Buffer.length response_buffer);
      assert (8 < LowStar.Buffer.length response_buffer);
      assert (9 < LowStar.Buffer.length response_buffer);
      assert (10 < LowStar.Buffer.length response_buffer);
      assert (11 < LowStar.Buffer.length response_buffer);
      let id_hi = LowStar.Buffer.index s.sc_buf 0ul in
      let id_lo = LowStar.Buffer.index s.sc_buf 1ul in
      LowStar.Buffer.upd response_buffer 0ul id_hi;
      LowStar.Buffer.upd response_buffer 1ul id_lo;
      LowStar.Buffer.upd response_buffer 2ul 0x81uy;
      LowStar.Buffer.upd response_buffer 3ul 0x03uy;
      LowStar.Buffer.upd response_buffer 4ul 0x00uy;
      LowStar.Buffer.upd response_buffer 5ul 0x00uy;
      LowStar.Buffer.upd response_buffer 6ul 0x00uy;
      LowStar.Buffer.upd response_buffer 7ul 0x00uy;
      LowStar.Buffer.upd response_buffer 8ul 0x00uy;
      LowStar.Buffer.upd response_buffer 9ul 0x00uy;
      LowStar.Buffer.upd response_buffer 10ul 0x00uy;
      LowStar.Buffer.upd response_buffer 11ul 0x00uy;
      12ul
    end

val prepare_worker_empty_noerror_response_send :
  ctx_ptr:buffer stream_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  request_len:FStar.UInt32.t ->
  ST FStar.UInt32.t
    (requires (fun h0 ->
      live h0 ctx_ptr /\
      LowStar.Buffer.length ctx_ptr >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       live h0 ctx.sc_buf /\
       FStar.UInt32.v request_len <= LowStar.Buffer.length ctx.sc_buf)))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let prepare_worker_empty_noerror_response_send
  ctx_ptr
  response_buffer
  response_capacity
  request_len =
  let s = LowStar.Buffer.index ctx_ptr 0ul in
  if FStar.UInt32.lt request_len 12ul ||
     FStar.UInt32.lt response_capacity 12ul then
    0ul
  else
    begin
      assert (FStar.UInt32.v request_len <= LowStar.Buffer.length s.sc_buf);
      assert (12 <= LowStar.Buffer.length response_buffer);
      assert (3 < LowStar.Buffer.length s.sc_buf);
      assert (0 < LowStar.Buffer.length response_buffer);
      assert (1 < LowStar.Buffer.length response_buffer);
      assert (2 < LowStar.Buffer.length response_buffer);
      assert (3 < LowStar.Buffer.length response_buffer);
      assert (4 < LowStar.Buffer.length response_buffer);
      assert (5 < LowStar.Buffer.length response_buffer);
      assert (6 < LowStar.Buffer.length response_buffer);
      assert (7 < LowStar.Buffer.length response_buffer);
      assert (8 < LowStar.Buffer.length response_buffer);
      assert (9 < LowStar.Buffer.length response_buffer);
      assert (10 < LowStar.Buffer.length response_buffer);
      assert (11 < LowStar.Buffer.length response_buffer);
      let id_hi = LowStar.Buffer.index s.sc_buf 0ul in
      let id_lo = LowStar.Buffer.index s.sc_buf 1ul in
      let request_flags_hi = LowStar.Buffer.index s.sc_buf 2ul in
      let request_flags_lo = LowStar.Buffer.index s.sc_buf 3ul in
      LowStar.Buffer.upd response_buffer 0ul id_hi;
      LowStar.Buffer.upd response_buffer 1ul id_lo;
      LowStar.Buffer.upd response_buffer 2ul (noerror_response_flags_hi request_flags_hi);
      LowStar.Buffer.upd response_buffer 3ul (noerror_response_flags_lo request_flags_lo);
      LowStar.Buffer.upd response_buffer 4ul 0x00uy;
      LowStar.Buffer.upd response_buffer 5ul 0x00uy;
      LowStar.Buffer.upd response_buffer 6ul 0x00uy;
      LowStar.Buffer.upd response_buffer 7ul 0x00uy;
      LowStar.Buffer.upd response_buffer 8ul 0x00uy;
      LowStar.Buffer.upd response_buffer 9ul 0x00uy;
      LowStar.Buffer.upd response_buffer 10ul 0x00uy;
      LowStar.Buffer.upd response_buffer 11ul 0x00uy;
      12ul
    end

val prepare_worker_validated_minimal_response_send :
  ctx_ptr:buffer stream_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  request_len:FStar.UInt32.t ->
  ST FStar.UInt32.t
    (requires (fun h0 ->
      live h0 ctx_ptr /\
      LowStar.Buffer.length ctx_ptr >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       live h0 ctx.sc_buf /\
       FStar.UInt32.v request_len <= LowStar.Buffer.length ctx.sc_buf)))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let prepare_worker_validated_minimal_response_send
  ctx_ptr
  response_buffer
  response_capacity
  request_len =
  let s = LowStar.Buffer.index ctx_ptr 0ul in
  let valid =
    validate_minimal_uncompressed_question_request s.sc_buf request_len in
  if valid then
    prepare_worker_empty_noerror_response_send
      ctx_ptr
      response_buffer
      response_capacity
      request_len
  else
    prepare_worker_minimal_error_response_send
      ctx_ptr
      response_buffer
      response_capacity
      request_len
