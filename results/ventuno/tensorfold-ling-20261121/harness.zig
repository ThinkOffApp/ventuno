//! Private measurement harness: separate pp512/tg128, borrowed Session.step, no argmax/EOS.
const std = @import("std");
const cpu = @import("ling_cpu");
pub fn main(init: std.process.Init) !void {
 const args = try init.minimal.args.toSlice(init.arena.allocator());
 const trace = args.len > 2 and (std.mem.eql(u8, args[2], "trace") or std.mem.eql(u8,args[2],"trace-prefill"));
 const optimized_prefill = args.len > 2 and (std.mem.eql(u8, args[2], "prefill") or std.mem.eql(u8,args[2],"trace-prefill"));
 var outbuf: [4096]u8 = undefined;
 var out = std.Io.File.stdout().writerStreaming(init.io, &outbuf);
 const w = &out.interface;
 var file = try cpu.gguf.File.open(init.gpa, init.io, args[1]);
 defer file.close(init.io);
 try file.enableFastMode();
 const c = try file.config();
 var session = try cpu.Gguf.Session.init(init.gpa, &file, c, 512, 4);
 defer session.deinit();
 var ids: [512]u32 = undefined;
 var rng: u64 = 1;
 for (&ids) |*id| { rng = rng *% 6364136223846793005 +% 1; id.* = @intCast((rng >> 32) % c.vocab); }
 for ([_][]const u8{"pp512", "tg128"}) |phase| {
  const pp = std.mem.eql(u8, phase, "pp512");
  const n: usize = if (pp) 512 else 128;
  const chunk: usize = if (pp) 8 else 1;
  for (0..@as(usize, if (trace) 1 else 4)) |rep| {
   session.reset();
   try w.print("BEGIN {s} {d}\n", .{phase,rep}); try w.flush();
   const started = std.Io.Clock.awake.now(init.io);
   var at: usize = 0;
   while (at < n) : (at += chunk) { const end = @min(n,at+chunk);
    const view = if (@hasDecl(cpu.Gguf.Session, "prefillChunk")) view: {
     if (pp and optimized_prefill) break :view try session.prefillChunk(ids[at..end], end == n);
     break :view try session.step(ids[at..end]);
    } else try session.step(ids[at..end]);
    if (trace) stateTrace(phase, at, view.logits, &session); }
   const ns = started.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
   try w.print("END {s} {d} ns={d} tps={d:.6}\n", .{phase,rep,ns,@as(f64,@floatFromInt(n))*1e9/@as(f64,@floatFromInt(ns))}); try w.flush();
  }
 }
}

fn stateTrace(phase: []const u8, step: usize, logits: []const f32, session: anytype) void {
    const H = std.crypto.hash.sha2.Sha256;
    var logits_hash: [32]u8 = undefined;
    H.hash(std.mem.sliceAsBytes(logits), &logits_hash, .{});
    var last_hash: [32]u8 = undefined;
    H.hash(std.mem.sliceAsBytes(logits[logits.len - @min(logits.len, session.config.vocab)..]), &last_hash, .{});
    var state_hash = H.init(.{});
    state_hash.update(std.mem.asBytes(&session.state.position));
    for (session.state.layers) |layer| switch (layer) {
        .kda => |k| {
            state_hash.update(std.mem.sliceAsBytes(k.matrix));
            state_hash.update(std.mem.sliceAsBytes(k.history));
        },
        .mla => |m| {
            state_hash.update(std.mem.asBytes(&m.position));
            state_hash.update(std.mem.sliceAsBytes(m.k_nope[0 .. m.k_nope.len / m.capacity * m.position]));
            state_hash.update(std.mem.sliceAsBytes(m.value[0 .. m.value.len / m.capacity * m.position]));
            state_hash.update(std.mem.sliceAsBytes(m.rope[0 .. m.rope.len / m.capacity * m.position]));
        },
    };
    var state_bytes: [32]u8 = undefined;
    state_hash.final(&state_bytes);
    std.debug.print("STATE_TRACE {s} {d} logits={s} state={s} last={s}\n", .{ phase, step, std.fmt.bytesToHex(logits_hash, .lower), std.fmt.bytesToHex(state_bytes, .lower), std.fmt.bytesToHex(last_hash, .lower) });
}
