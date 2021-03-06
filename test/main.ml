let () = Random.self_init ()

let random_char () = char_of_int (Random.int 256)

let random_string n = String.init n (fun _i -> random_char ())

module StringSet = Set.Make (String)

let expected_error_rate = 0.001

let create_and_fill size =
  let bf = Bloomf.create ~error_rate:expected_error_rate size in
  let rec loop i acc =
    if i = 0 then acc
    else
      let r = random_string 1024 in
      let () = Bloomf.add bf r in
      loop (i - 1) (StringSet.add r acc)
  in
  let elts = loop size StringSet.empty in
  (bf, elts)

let bf, elts = create_and_fill 10_000

(* The tests *)
let test_mem () =
  StringSet.iter
    (fun r -> Alcotest.(check bool) "mem (present)" true (Bloomf.mem bf r))
    elts

let test_mem_create () =
  let bf = Bloomf.create 10_000 in
  StringSet.iter
    (fun r -> Alcotest.(check bool) "mem (empty)" false (Bloomf.mem bf r))
    elts

let test_errors () =
  let attempts = 100_000 in
  let rec loop i count =
    if i = 0 then count
    else
      let r = random_string 1024 in
      if StringSet.mem r elts then loop i count
      else loop (i - 1) (if Bloomf.mem bf r then count + 1 else count)
  in
  let count = loop attempts 0 in
  let error_rate = float_of_int count /. float_of_int attempts in
  if error_rate > 1.15 *. expected_error_rate then
    Alcotest.failf "error_rate: expecting@\n%f, got@\n%f" expected_error_rate
      error_rate
  else ()

let test_size () =
  let sizes = [ 1_000; 10_000; 100_000 ] in
  List.iter
    (fun i ->
      let bf, _ = create_and_fill i in
      let len = Bloomf.size_estimate bf in
      if abs (len - i) > int_of_float (0.15 *. float_of_int i) then
        Alcotest.failf "size_estimate: expecting@\n%d, got@\n%d" i len )
    sizes

let test_bits () =
  let r = random_string 1000 in
  let a = Bloomf.create 10 in
  let () = Bloomf.add a r in
  let ab = Bloomf.bits a in
  let b = Bloomf.create ~bits:ab 10 in
  let bb = Bloomf.bits b in
  let axb = Bitv.bw_xor ab bb in
  if 0 <> Bitv.pop axb then
    Alcotest.fail "Bloomf.bits are not the same after import";
  if not (Bloomf.mem b r) then
    Alcotest.fail "(Bloomf.mem b r) is not true";
  try
    let _ = Bloomf.create ~bits:(Bloomf.bits b) 100 in
    Alcotest.fail "Bloomf.create succeeded with invalid [bits] length"
  with Invalid_argument _ -> ()

let test_set =
  [ ("Mem returns true when element was added", `Quick, test_mem);
    ("Mem returns false when filter is empty", `Quick, test_mem_create);
    ( "False positive rate is as specified (15% error allowed)",
      `Slow,
      test_errors );
    ("Size estimate is correct", `Slow, test_size);
    ("Creating with bits is correct", `Quick, test_bits)
  ]

(* Run it *)
let () = Alcotest.run "Bloomf" [ ("bloomf", test_set) ]
