# grpc plan

## Specifications

- gRPC over HTTP/2: grpc/grpc doc/PROTOCOL-HTTP2.md
- Status codes: doc/statuscodes.md; rich errors: google.rpc.Status (google/rpc/status.proto)
- Compression: doc/compression.md
- Service config, retries and hedging: doc/service_config.md, gRFC A6
- Keepalive: doc/keepalive.md, gRFC A8 (client), A9 (server)
- Health: doc/health-checking.md (grpc.health.v1)
- Reflection: grpc.reflection.v1 (gRFC A15 for v1 alpha history)
- Interop tests: doc/interop-test-descriptions.md (grpc.testing)
- HTTP/2: RFC 9113, HPACK: RFC 7541

References studied: grpc-go, tonic, grpc-java, grpc-dotnet. Notes on what
came from where go in docs/references.md.

## Module layout

```
src/grpc.mettle              facade, imports the rest
src/grpc/status.mettle       codes, GrpcStatus, google.rpc.Status details,
                             grpc-status-details-bin, percent-encoded grpc-message
src/grpc/metadata.mettle     ASCII and -bin keys (base64), reserved names
src/grpc/deadline.mettle     grpc-timeout, deadline propagation, cancel tokens
src/grpc/codec.mettle        message framing (5-byte prefix), size limits
src/grpc/compress.mettle     grpc-encoding / grpc-accept-encoding via Press
src/grpc/call.mettle         one call: state machine shared by client and server
src/grpc/channel.mettle      client: connection, name resolution, call start
src/grpc/client.mettle       unary and the three streaming client call types
src/grpc/server.mettle       server: method table, dispatch, streaming handlers
src/grpc/intercept.mettle    client and server interceptor chains
src/grpc/svcconfig.mettle    service config JSON, method config, retry, hedging,
                             retry throttling
src/grpc/keepalive.mettle    PING timing, GOAWAY too_many_pings policy
src/grpc/tls.mettle          mtls glue: ALPN h2, mutual TLS, per-call credentials
src/grpc/health.mettle       grpc.health.v1 service (Check, Watch)
src/grpc/reflection.mettle   grpc.reflection.v1 service
tools/grpc_gen.mettle        stub generator (see below)
tests/                       unit tests, fuzz, interop client and server
examples/                    greeter, route guide (all four call types)
docs/                        api.md, references.md, guide
```

## Stub generation

Codec's `codec_protoc` already parses services and emits per-method
`_PATH`, `_frame_request`, `_read_response` and server-side helpers. The plan
is to ask the Codec session for a plugin hook (descriptor out, or a
`--grpc` mode) and keep the stub templates here in `tools/grpc_gen.mettle`, so
gRPC changes do not need Codec releases. Generated per service:

- Client: a typed struct over a channel, one function per method,
  shaped by call type (unary, server stream reader, client stream writer,
  bidi pair).
- Server: a handler struct (function pointers) and a register function that
  adds the methods to a server's table.

## Build order

1. status, metadata, deadline, codec (message framing): no network, tested alone
2. call state machine on top of `http` HTTP/2 streams
3. client and server for unary calls, over plain TCP (h2c, prior knowledge)
4. the three streaming types, flow control and cancellation (RST_STREAM CANCEL)
5. stub generator; greeter and route guide examples
6. compression via Press
7. TLS via mtls (ALPN h2), mutual TLS
8. interceptors, metadata in both directions, rich error details
9. service config, retries, hedging, retry throttling
10. keepalive, GOAWAY handling, max connection age
11. health and reflection services
12. interop: run grpc.testing cases against grpc-go and grpc-java servers and
    clients; fuzz frame and header parsing; benchmark against grpc-go

## What grpc needs from `http`

Framing and HPACK already exist (std/http2, std/hpack). What is missing is
the connection layer:

- An HTTP/2 connection, client and server, that owns stream state, flow
  control (connection and stream windows, WINDOW_UPDATE), SETTINGS exchange
  and CONTINUATION joining.
- Streams as a handle: send HEADERS (with or without END_STREAM), send DATA in
  pieces with back pressure, send trailers (HEADERS + END_STREAM after DATA),
  read headers, DATA and trailers as separate events.
- Trailers on both sides, and trailers-only responses (one HEADERS frame with
  END_STREAM).
- RST_STREAM in both directions with the error code exposed (CANCEL maps to
  gRPC CANCELLED), and a callback or event when the peer resets.
- GOAWAY sent and received, with last-stream-id, so calls not processed can be
  retried transparently.
- PING sent on demand, with the ACK round-trip reported (keepalive and BDP).
- Many concurrent streams per connection, honoring MAX_CONCURRENT_STREAMS,
  and a way to wait for a free slot.
- h2c with prior knowledge (no Upgrade) and h2 over a caller-supplied
  transport so mtls can be plugged in (ALPN "h2").
- A non-blocking or event-driven API (alph) as well as a blocking one, so a
  server can hold many long-lived streams.
- Settable limits: max frame size, initial window sizes, header list size.
- `te: trailers` passes through; header names lowercase; no connection-
  specific headers.
