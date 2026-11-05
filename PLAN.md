# grpc plan

## Specifications

- gRPC over HTTP/2: grpc/grpc doc/PROTOCOL-HTTP2.md
- Status codes: doc/statuscodes.md, doc/http-grpc-status-mapping.md; rich
  errors: google.rpc.Status (google/rpc/status.proto)
- Compression: doc/compression.md
- Service config, retries and hedging: doc/service_config.md, gRFC A6
- Keepalive: doc/keepalive.md, gRFC A8 (client), A9 (server)
- Connection backoff: doc/connection-backoff.md
- Health: doc/health-checking.md (grpc.health.v1)
- Reflection: doc/server-reflection.md (grpc.reflection.v1 and v1alpha)
- Interop tests: doc/interop-test-descriptions.md (grpc.testing)
- HTTP/2: RFC 9113, HPACK: RFC 7541 (both in the standard library)

## Module layout

```
src/grpc.mettle         facade: imports everything
src/status.mettle       codes, GrpcStatus, grpc-message encoding
src/metadata.mettle     keys, values, -bin base64, header lists
src/deadline.mettle     grpc-timeout, deadlines, cancellation, contexts
src/message.mettle      5-byte framing, gzip/deflate via Press, the deframer
src/transport.mettle    the transport table a call runs on
src/memtransport.mettle in-memory transport pair (tests, one-process use)
src/wire.mettle         request/response headers and trailers
src/call.mettle         the call object, interceptors
src/client.mettle       channel, calls, retries, hedging, keepalive, reconnect
src/server.mettle       method table, callback handlers, keepalive enforcement
src/json.mettle         JSON parser for service configs
src/svcconfig.mettle    service config, retry/hedging policy, throttle
src/errors.mettle       rich error details (google.rpc.Status, Any)
src/health.mettle       grpc.health.v1
src/reflection.mettle   grpc.reflection.v1 (+ v1alpha)
src/h2.mettle           HTTP/2 transport on std/h2conn
src/tls.mettle          TLS and mutual TLS through mtls
src/arena.mettle        malloc-backed bump allocator
src/gen/                generated protobuf code (mbuild gen)
tools/grpc_gen/         stub generator on Codec's .proto parser
```

## Build order

1. status, metadata, deadline, framing: done
2. call layer, client and server, against a transport table: done
3. retries, hedging, throttling, service config, keepalive: done
4. stub generator, health, reflection, rich errors: done
5. HTTP/2 transport on std/h2conn: done
6. TLS via mtls (ALPN h2), mutual TLS: done
7. interop: grpc.testing cases against grpc-go v1.80 client and server: done
8. benchmarks against grpc-go: done

## HTTP/2

std/http2 (framing), std/hpack and std/h2conn (the connection: streams,
flow control, GOAWAY, PING, over a NetStream) come from the standard
library. src/h2.mettle maps the GrpcTransport table onto std/h2conn;
src/tls.mettle gives it an mtls stream.
