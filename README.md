# grpc

gRPC clients and servers for Mettle, in pure Mettle.

- All four call kinds: unary, server streaming, client streaming, bidirectional
- Stubs generated from `.proto` files (`grpc_gen`, built on Codec's protobuf compiler)
- Deadlines (`grpc-timeout`), cancellation, deadline propagation to child calls
- Metadata in both directions, binary (`-bin`) values, status codes,
  rich error details (`google.rpc.Status` with `ErrorInfo`, `RetryInfo`...)
- gzip and deflate message compression (through Press)
- Client and server interceptors
- Service config: per-method timeouts, size limits, wait-for-ready,
  retries and hedging with retry throttling and server pushback (gRFC A6)
- Keepalive pings and server enforcement, connection idle and age limits (gRFC A8, A9)
- Health (`grpc.health.v1`) and reflection (`grpc.reflection.v1`, `v1alpha`) services
- TLS and mutual TLS (h2 over ALPN) through mtls

Follows the [gRPC over HTTP/2 protocol](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md).
HTTP/2 itself comes from the standard library's `std/http2`.

Transports: HTTP/2 over TCP (std/h2conn), TLS and mutual TLS through
[mtls](https://github.com/Lex-Dellimere/mtls), and an in-memory pair.

## Use

```mettle
// mbuild.mettle
fn deps() {
  mb_dep_path("grpc", "../grpc");
  mb_dep_path("codec", "../codec");
  mb_dep_path("press", "../press");
  mb_dep_path("mtls", "../mtls");        // for grpc/tls
  mb_dep_path("crypto", "../cryptex");
}
```

Generate code from a `.proto` file:

```bash
mbuild build grpc_gen
build/linux/debug/grpc_gen -I proto --out src/gen helloworld.proto
```

That writes `helloworld_pb.mettle` (messages) and `helloworld_grpc.mettle`
(stubs). A server:

```mettle
import "grpc/grpc";
import "gen/helloworld_grpc";

fn say_hello(u: rawptr, c: GrpcCall*, req: HelloRequest*, resp: HelloReply*) -> GrpcStatus {
  resp->message = "Hello " + req->name;
  return grpc_status(GRPC_OK, "");
}

var h: Greeter_Handlers;
h.SayHello = &say_hello;
var srv: GrpcServer;
var opts: GrpcServerOptions;
grpc_server_init(&srv, &opts);
Greeter_register(&srv, &h);
// then grpc_server_conn_init(&conn, &srv, transport) and grpc_server_conn_serve(&conn)
```

A client:

```mettle
var ch: GrpcChannel;
var copts: GrpcChannelOptions;
grpc_channel_init(&ch, transport, &copts);
var req: HelloRequest;
HelloRequest_init(&req);
req.name = "world";
var resp: HelloReply;
HelloReply_init(&resp);
var buf: GrpcBytes;
var o: GrpcCallOptions = grpc_call_options();
o.timeout_ns = 1000000000;
var st: GrpcStatus = Greeter_SayHello(&ch, &req, &resp, &buf, &o);
```

[examples/greeter](examples/greeter) runs both in one process.

## Docs

- [docs/api.md](docs/api.md): the library API
- [docs/codegen.md](docs/codegen.md): what `grpc_gen` generates
- [docs/references.md](docs/references.md): standards followed and what came from where

## Tests

```bash
mbuild test
mbuild test -r
```

The tests cover every call kind, metadata, deadlines, cancellation,
compression and limits, interceptors, retries, hedging, the generated
stubs, health, reflection, rich errors, and fuzzing of the header parsers
and of the client and server against random events. `mbuild gen`
regenerates `src/gen` and `tests/gen` (it needs `../codec`).

## License

Apache-2.0. See [LICENSE](LICENSE). The files in `proto/` come from
grpc/grpc-proto and googleapis (Apache-2.0) and protocolbuffers/protobuf
(BSD-3-Clause); their own headers say so.
