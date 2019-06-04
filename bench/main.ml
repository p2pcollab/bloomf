open Bechamel
open Toolkit
module BF = Bloomf.Make (String)

let () = Random.self_init ()

let random_char () = char_of_int (Random.int 256)

let random_string n = String.init n (fun _i -> random_char ())

let create size = Staged.stage (fun () -> BF.create size)

let add size =
  let bf = BF.create size in
  let r = random_string 1024 in
  Staged.stage (fun () -> BF.add bf r)

let fill_bf bf n =
  let rec loop i =
    if i = 0 then ()
    else
      let r = random_string 1024 in
      let () = BF.add bf r in
      loop (i - 1)
  in
  loop n

let find_absent size =
  let bf = BF.create size in
  let () = fill_bf bf (size / 3) in
  let r = random_string 1024 in
  Staged.stage (fun () -> ignore (BF.mem bf r))

let find_present size =
  let bf = BF.create size in
  let () = fill_bf bf (size / 3) in
  let r = random_string 1024 in
  let () = BF.add bf r in
  Staged.stage (fun () -> ignore (BF.mem bf r))

let test =
  Test.make_grouped ~name:"bloomf"
    [ Test.make_indexed ~name:"create" ~fmt:"%s %d"
        ~args:[ 10_000; 100_000; 1_000_000 ]
        create;
      Test.make_indexed ~name:"add" ~fmt:"%s %d"
        ~args:[ 10_000; 100_000; 1_000_000 ]
        add;
      Test.make_indexed ~name:"find (absent)" ~fmt:"%s %d"
        ~args:[ 10_000; 100_000; 1_000_000 ]
        find_absent;
      Test.make_indexed ~name:"find (present)" ~fmt:"%s %d"
        ~args:[ 10_000; 100_000; 1_000_000 ]
        find_present
    ]

let benchmark () =
  let ols =
    Analyze.ols ~bootstrap:0 ~r_square:true ~predictors:Measure.[| run |]
  in
  let instances =
    Instance.[ minor_allocated; major_allocated; monotonic_clock ]
  in
  let raw_results =
    Benchmark.all ~run:3000 ~quota:Benchmark.(s 1.) instances test
  in
  List.map (fun instance -> Analyze.all ols instance raw_results) instances
  |> Analyze.merge ols instances

let () = Bechamel_notty.Unit.add Instance.monotonic_clock "ns"

let () = Bechamel_notty.Unit.add Instance.minor_allocated "w"

let () = Bechamel_notty.Unit.add Instance.major_allocated "mw"

let img (window, results) =
  Bechamel_notty.Multiple.image_of_ols_results ~rect:window
    ~predictor:Measure.run results

type rect = Bechamel_notty.rect = { w : int; h : int }

let rect w h = { w; h }

let () =
  let window =
    match Notty_unix.winsize Unix.stdout with
    | Some (_, _) -> { w = 80; h = 1 }
    | None -> { w = 80; h = 1 }
  in
  img (window, benchmark ()) |> Notty_unix.eol |> Notty_unix.output_image
