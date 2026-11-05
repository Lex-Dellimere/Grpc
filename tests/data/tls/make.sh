#!/bin/sh
# Test certificates for tests/tls_test.mettle: a P-256 CA, a server for
# localhost / 127.0.0.1 and a client, valid for 100 years. Run in this
# directory to remake them.
set -e
openssl ecparam -name prime256v1 -genkey -noout -out ca.key
openssl req -x509 -new -key ca.key -subj "/CN=grpc test CA" -days 36500 \
  -addext "basicConstraints=critical,CA:true" -addext "keyUsage=critical,keyCertSign" -out ca.pem
for who in server client; do
  openssl ecparam -name prime256v1 -genkey -noout -out $who.k
  openssl pkcs8 -topk8 -nocrypt -in $who.k -out $who.key
  rm $who.k
  openssl req -new -key $who.key -subj "/CN=$who.test" -out $who.csr
  if [ $who = server ]; then eku=serverAuth; else eku=clientAuth; fi
  printf "subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=$eku\n" > $who.ext
  openssl x509 -req -in $who.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 36500 -extfile $who.ext -out $who.pem
  rm $who.csr $who.ext
done
rm -f ca.key ca.srl
