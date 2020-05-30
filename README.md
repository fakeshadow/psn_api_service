### Http service manage PSN API calls with high concurrency

### Requirement:
- `Rust 1.43 stable` and above

### Caution:
- ssl must be set if you expose service directly to internet.         

### Start with docker:
1. rename `.env_example` to `.env` and make changes to match your environment.
2. `docker build -t <image name> .`
3. `docker run -d --name <contianer name> -p <port you want to expose from host>:<PORT in .env> <image name>`

### Start with cargo:
1. rename `.env_example` to `.env` and make changes to match your environment.
2. `cargo build --release` and run `./target/release/psn_api_service`.
   
     `.env` must be in the same working dir where you start `psn_api_service`

### Endpoints:
- See the [showcase](https://psn.blackheart.top) for example of APIs