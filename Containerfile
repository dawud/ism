FROM fedora:44

ARG USER_NAME=ism
ARG USER_ID=1000
ARG GROUP_ID=1000

# 1. Install System Dependencies
RUN dnf install -y \
    gcc gcc-c++ make cmake git curl wget patch unzip \
    gmp-devel libunwind-devel libffi-devel opam python3 which time \
    && dnf clean all

# 2. Set Environment Variables
ENV FSTAR_HOME=/opt/fstar/fstar
ENV KRML_HOME=/opt/karamel
ENV EVERPARSE_HOME=/opt/everparse
ENV MSQUIC_HOME=/opt/msquic
ENV PATH="${FSTAR_HOME}/bin:${KRML_HOME}:${EVERPARSE_HOME}:${PATH}"

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

# 4. Create the unprivileged development user and writable tool directories.
RUN groupadd --gid ${GROUP_ID} ${USER_NAME} \
    && useradd --uid ${USER_ID} --gid ${GROUP_ID} --create-home --shell /bin/bash ${USER_NAME} \
    && mkdir -p ${KRML_HOME} ${EVERPARSE_HOME} ${MSQUIC_HOME} /workspace \
    && chown -R ${USER_NAME}:${USER_NAME} ${KRML_HOME} ${EVERPARSE_HOME} ${MSQUIC_HOME} /workspace

USER ${USER_NAME}
ENV HOME=/home/${USER_NAME}
WORKDIR ${HOME}

# 5. Install KaRaMeL (from Source via OPAM)
RUN opam init --disable-sandboxing -y \
    && eval $(opam env) \
    && opam install -y ocamlfind batteries zarith stdint yojson visitors menhir fix process ctypes ctypes-foreign uucp ppx_deriving_yojson sedlex wasm pprint \
    && git clone https://github.com/FStarLang/karamel.git ${KRML_HOME} \
    && cd ${KRML_HOME} \
    && export FSTAR_HOME=${FSTAR_HOME} \
    && export PATH="${FSTAR_HOME}/bin:${PATH}" \
    && make \
    && echo 'eval $(opam env)' >> ${HOME}/.bashrc

# 6. Install EverParse/3D tooling from the standalone binary package.
RUN EVERPARSE_VERSION=v2026.03.21 \
    && EVERPARSE_ARCHIVE=everparse_${EVERPARSE_VERSION}_Linux_x86_64.tar.gz \
    && EVERPARSE_SHA256=467d391c819dbc513173bdb4bb71aa0073e497fe50acfe116099b4ff27b7ebd8 \
    && EVERPARSE_URL=https://github.com/project-everest/everparse/releases/download/${EVERPARSE_VERSION}/${EVERPARSE_ARCHIVE} \
    && echo "Downloading EverParse ${EVERPARSE_VERSION} from ${EVERPARSE_URL}" \
    && wget "${EVERPARSE_URL}" -O /tmp/everparse.tar.gz \
    && echo "${EVERPARSE_SHA256}  /tmp/everparse.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/everparse.tar.gz -C /opt \
    && rm /tmp/everparse.tar.gz \
    && test -x ${EVERPARSE_HOME}/everparse.sh

# 7. Install pinned upstream MsQuic headers for real callback API checks.
RUN MSQUIC_VERSION=v2.5.9 \
    && MSQUIC_HEADER_SHA256=c9abfdd02c45910649dd335d6bd82718e4ddd2fdb35fe550567c78f032551e0c \
    && MSQUIC_POSIX_HEADER_SHA256=b285fa66b9c9bdc886c30ef92910da472692b25f5c6192416fb40f08f64e22ec \
    && MSQUIC_SAL_STUB_HEADER_SHA256=9b13328d9aec8807a754b2bc391b31b5d09b1c5f6cec064012051683ed169055 \
    && MSQUIC_BASE_URL=https://raw.githubusercontent.com/microsoft/msquic/${MSQUIC_VERSION}/src/inc \
    && mkdir -p ${MSQUIC_HOME}/include \
    && echo "Downloading MsQuic headers ${MSQUIC_VERSION} from ${MSQUIC_BASE_URL}" \
    && wget "${MSQUIC_BASE_URL}/msquic.h" -O ${MSQUIC_HOME}/include/msquic.h \
    && wget "${MSQUIC_BASE_URL}/msquic_posix.h" -O ${MSQUIC_HOME}/include/msquic_posix.h \
    && wget "${MSQUIC_BASE_URL}/quic_sal_stub.h" -O ${MSQUIC_HOME}/include/quic_sal_stub.h \
    && echo "${MSQUIC_HEADER_SHA256}  ${MSQUIC_HOME}/include/msquic.h" | sha256sum -c - \
    && echo "${MSQUIC_POSIX_HEADER_SHA256}  ${MSQUIC_HOME}/include/msquic_posix.h" | sha256sum -c - \
    && echo "${MSQUIC_SAL_STUB_HEADER_SHA256}  ${MSQUIC_HOME}/include/quic_sal_stub.h" | sha256sum -c -

# 8. Set up the Project Workspace
WORKDIR /workspace
COPY --chown=${USER_NAME}:${USER_NAME} . /workspace

# Default command: Verify the protocol
CMD ["bash", "-lc", "eval $(opam env) && make verify"]
