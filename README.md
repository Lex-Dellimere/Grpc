# grpc

gRPC clients and servers for Mettle, in pure Mettle.

Status: design stage. The code lands once the `http` package (HTTP/2) is
ready. See [PLAN.md](PLAN.md) for the layout and build order.

Planned:

- Client and server stubs generated from `.proto` files (on top of Codec's
  protobuf compiler)
- Unary, server streaming, client streaming and bidirectional streaming calls
- Deadlines, cancellation, metadata, status codes and rich error details
- Compression (gzip and deflate through Press)
- Interceptors, retries and hedging from the service config
- Keepalive, the health and reflection services
- TLS and mutual TLS through mtls

Follows the [gRPC over HTTP/2 protocol](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md).

## License

Apache-2.0. See [LICENSE](LICENSE).
