FROM emscripten/emsdk:2.0.24

RUN apt update
RUN apt-get install -y autotools-dev automake libtool pkg-config ninja-build lsb-release libclang1
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain none
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup install 1.61.0
RUN rustup target add wasm32-unknown-emscripten
RUN git config --global --add safe.directory '*'
