# Use Fedora 44 as the base image
FROM fedora:44

# 1. Install System Dependencies
RUN dnf install -y \
    gcc gcc-c++ make cmake git curl wget patch unzip \
    gmp-devel libunwind-devel libffi-devel opam python3 which time \
    && dnf clean all

# 2. Set Environment Variables
ENV FSTAR_HOME=/opt/fstar/fstar
ENV KRML_HOME=/opt/karamel
ENV PATH="${FSTAR_HOME}/bin:${KRML_HOME}:${PATH}"

# 3. Install F* (Specific stable version for Low*)
# We use v2026.03.24 as it is the last version before the major Low* removal.
WORKDIR /tmp
RUN FSTAR_VERSION=v2026.03.24 \
    && FSTAR_URL=https://github.com/FStarLang/FStar/releases/download/${FSTAR_VERSION}/fstar-${FSTAR_VERSION}-Linux-x86_64.tar.gz \
    && echo "Downloading F* ${FSTAR_VERSION} from ${FSTAR_URL}" \
    && wget "${FSTAR_URL}" -O fstar.tar.gz \
    && mkdir -p /opt/fstar \
    && tar -xzf fstar.tar.gz -C /opt/fstar \
    && chmod +x ${FSTAR_HOME}/bin/fstar.exe \
    && rm fstar.tar.gz

# 4. Install KaRaMeL (from Source via OPAM)
RUN opam init --disable-sandboxing -y \
    && eval $(opam env) \
    && opam install -y ocamlfind batteries zarith stdint yojson visitors menhir fix process ctypes ctypes-foreign uucp ppx_deriving_yojson sedlex wasm pprint \
    && git clone https://github.com/FStarLang/karamel.git ${KRML_HOME} \
    && cd ${KRML_HOME} \
    && export FSTAR_HOME=${FSTAR_HOME} \
    && export PATH="${FSTAR_HOME}/bin:${PATH}" \
    && make \
    && echo 'eval $(opam env)' >> /root/.bashrc

# 5. Set up the Project Workspace
WORKDIR /workspace
COPY . /workspace

# Default command: Verify the protocol
CMD ["bash", "-c", "eval $(opam env) && make verify"]
