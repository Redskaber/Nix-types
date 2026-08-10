# @path: test/cases/result.nix
# @description: Result ADT test cases — Ok, Err, unwrap, map, etc.

let
  fw = import ../framework.nix { };
  m = import ../../lib/default.nix;
  R = m.result;  # namespaced Result helpers
  inherit (m) ok err Result;
in
fw.runAll [
  # === Construction ===
  { name = "result.construct.01-ok-tag";
    test = (ok 42).tag == "Ok"; }
  { name = "result.construct.02-ok-value";
    test = (ok 42).value == 42; }
  { name = "result.construct.03-ok-display";
    test = (ok 42).display == "enum::Result::Ok(42)"; }
  { name = "result.construct.04-err-tag";
    test = (err "fail").tag == "Err"; }
  { name = "result.construct.05-err-value";
    test = (err "fail").value == "fail"; }
  { name = "result.construct.06-err-display";
    test = (err "fail").display == "enum::Result::Err(\"fail\")"; }
  { name = "result.construct.07-ok-with-attrset";
    test = (ok { a = 1; }).value.a == 1; }
  { name = "result.construct.08-err-with-int";
    test = (err 404).value == 404; }
  { name = "result.construct.09-ok-string-interpolation";
    test = "${ok 42}" == "enum::Result::Ok(42)"; }

  # === Predicates ===
  { name = "result.pred.01-isOk-on-ok";
    test = R.isOk (ok 42); }
  { name = "result.pred.02-isOk-on-err";
    test = !R.isOk (err "fail"); }
  { name = "result.pred.03-isErr-on-err";
    test = R.isErr (err "fail"); }
  { name = "result.pred.04-isErr-on-ok";
    test = !R.isErr (ok 42); }

  # === Extractors ===
  { name = "result.extract.01-unwrap-ok";
    test = R.unwrap (ok 42) == 42; }
  { name = "result.extract.02-unwrap-err-throws";
    test = fw.assertThrows "result.extract.02"
      (R.unwrap (err "fail")); }
  { name = "result.extract.03-unwrapErr-err";
    test = R.unwrapErr (err "fail") == "fail"; }
  { name = "result.extract.04-unwrapErr-ok-throws";
    test = fw.assertThrows "result.extract.04"
      (R.unwrapErr (ok 42)); }
  { name = "result.extract.05-unwrapOr-ok";
    test = R.unwrapOr 0 (ok 42) == 42; }
  { name = "result.extract.06-unwrapOr-err";
    test = R.unwrapOr 0 (err "fail") == 0; }
  { name = "result.extract.07-unwrapOrElse-ok";
    test = R.unwrapOrElse (_: 0) (ok 42) == 42; }
  { name = "result.extract.08-unwrapOrElse-err";
    test = R.unwrapOrElse (e: e) (err "fail") == "fail"; }
  { name = "result.extract.09-expect-ok";
    test = R.expect "should be ok" (ok 42) == 42; }
  { name = "result.extract.10-expect-err-throws";
    test = fw.assertThrows "result.extract.10"
      (R.expect "custom message" (err "fail")); }

  # === Transformers ===
  { name = "result.transform.01-map-ok";
    test = R.unwrap (R.map (x: x + 1) (ok 41)) == 42; }
  { name = "result.transform.02-map-err-passes-through";
    test = R.unwrapErr (R.map (x: x + 1) (err "fail")) == "fail"; }
  { name = "result.transform.03-mapErr-err";
    test = R.unwrapErr (R.mapErr (e: e + "!") (err "fail")) == "fail!"; }
  { name = "result.transform.04-mapErr-ok-passes-through";
    test = R.unwrap (R.mapErr (e: e + "!") (ok 42)) == 42; }
  { name = "result.transform.05-andThen-ok";
    test = R.unwrap (R.andThen (x: ok (x + 1)) (ok 41)) == 42; }
  { name = "result.transform.06-andThen-err-passes-through";
    test = R.isErr (R.andThen (x: ok (x + 1)) (err "fail")); }
  { name = "result.transform.07-andThen-returns-err";
    test = R.isErr (R.andThen (_: err "chained") (ok 42)); }
  { name = "result.transform.08-mapOr-ok";
    test = R.mapOr 0 (x: x + 1) (ok 41) == 42; }
  { name = "result.transform.09-mapOr-err";
    test = R.mapOr 99 (x: x + 1) (err "fail") == 99; }

  # === Pattern matching (cases) ===
  { name = "result.match.01-cases-ok";
    test = R.cases (ok 42) { ok = x: x; err = e: -1; } == 42; }
  { name = "result.match.02-cases-err";
    test = R.cases (err "fail") { ok = x: x; err = e: -1; } == -1; }

  # === Type identity ===
  { name = "result.type.01-isInst-on-ok";
    test = m.isInst (ok 42); }
  { name = "result.type.02-isInst-on-err";
    test = m.isInst (err "fail"); }
  { name = "result.type.03-isType-ok-result";
    test = m.isType (ok 42) Result; }
  { name = "result.type.04-isType-err-result";
    test = m.isType (err "fail") Result; }
  { name = "result.type.05-descTp-ok";
    test = m.descTp (ok 42) == "enum::Result::Ok(42)"; }
]
