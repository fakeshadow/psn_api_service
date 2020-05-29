FROM rust:1.43.1 AS build

WORKDIR /usr/src/psn_api_service
COPY . .

RUN cargo clean
RUN RUSTFLAGS="-C target-cpu=native" cargo build --release

FROM gcr.io/distroless/cc-debian10

COPY --from=build /usr/src/psn_api_service/target/release/psn_api_service /usr/local/bin/psn_api_service
COPY --from=build /usr/src/psn_api_service/.env .env

# remove comment for copy ssl key and cert
# COPY --from=build /usr/src/psn_api_service/private /private/

CMD ["psn_api_service"]