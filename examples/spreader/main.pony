use "collections"

actor Spreader
  let _env: (Env | None)
  let _count: U64
  let _fanout: U64
  let _parent: (Spreader | None)

  var _result: U64 = 0
  var _received: U64 = 0

  new create(env: Env) =>
    _env = env
    _count = try env.args(1).u64() else 10 end
    _fanout = try env.args(2).u64() else 2 end
    _parent = None

    if _count > 1 then
      for i in Range[U64](0, _fanout) do
        spawn_child()
      end
    else
      env.out.print("1 actor")
    end

  new spread(parent: Spreader, fanout:U64, count: U64) =>
    _env = None
    _fanout = fanout
    _count = count
    _parent = parent

    if count == 1 then
      parent.result(1)
    else
      for i in Range[U64](0, _fanout) do
        spawn_child()
      end
    end

  fun ref spawn_child() =>
    Spreader.spread(this, _fanout, _count - 1)

  be result(i: U64) =>
    _received = _received + 1
    _result = _result + i

    if _received == _fanout then
      match (_parent, _env)
      | (let p: Spreader, _) =>
        p.result(_result + 1)
      | (None, let e: Env) =>
        e.out.print((_result + 1).string() + " actors")
      end
    end

actor Main
  new create(env: Env) =>
    Spreader(env)
