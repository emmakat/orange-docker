FROM debian:bookworm-20210816-slim

# Set build-time arguments for user and password
ARG USER=orange
ARG PASSWORD=orange
ARG HOME=/home/${USER}
ARG CONDA_DIR=${HOME}/.conda
ARG PYTHON_VERSION=3.8

# Set environment variables for VNC settings
ENV VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1920x1080 \
    VNC_PW=orange

# Install Python dependencies, Bzip2, and other required tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip python3-dev python-virtualenv bzip2 g++ git sudo xfce4-terminal software-properties-common python-numpy firefox && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    python3 --version && \
    firefox --version

# Create user and set up permissions
RUN useradd -m -s /bin/bash ${USER} && \
    echo "${USER}:${PASSWORD}" | chpasswd && \
    gpasswd -a ${USER} sudo

# Switch to orange user
USER orange
WORKDIR ${HOME}

# Use multi-stage build to install Anaconda and Orange-related packages in a separate stage
FROM ubuntu-minimal:20.04 as build-stage

# Copy the build-time arguments from the previous stage
ARG USER
ARG PASSWORD
ARG HOME
ARG CONDA_DIR
ARG PYTHON_VERSION

# Install wget and bzip2 for downloading and extracting Anaconda
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget bzip2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch to orange user and working directory
USER orange
WORKDIR ${HOME}

# Download and install Anaconda and Orange-related packages using conda and pip
RUN wget -q -O anaconda.sh https://repo.anaconda.com/archive/Anaconda3-2023.07-2-Linux-x86_64.sh && \
    echo "589fb34fe73bc303379abbceba50f3131254e85ce4e7cd819ba4276ba29cad16 anaconda.sh" | sha256sum --check && \
    bash anaconda.sh -b -p $CONDA_DIR && \
    rm anaconda.sh && \
    $CONDA_DIR/bin/conda create python=$PYTHON_VERSION --name orange3 && \
    bash -c "source $CONDA_DIR/bin/activate orange3 && $CONDA_DIR/bin/conda install pyqt=5.12.* orange3 -c conda-forge && \
    pip install git+https://github.com/biolab/orange3-text.git" && \
    echo "export PATH=$CONDA_DIR/bin:\$PATH" >> $HOME/.bashrc

# Start a new stage for the final image
FROM ubuntu-minimal:20.04

# Copy the run-time arguments from the previous stage
ARG USER
ARG PASSWORD
ARG HOME

# Copy the environment variables from the previous stage
ENV VNC_COL_DEPTH=${VNC_COL_DEPTH} \
    VNC_RESOLUTION=${VNC_RESOLUTION} \
    VNC_PW=${VNC_PW}

# Install Python dependencies, Bzip2, and other required tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip python3-dev python-virtualenv bzip2 g++ git sudo xfce4-terminal software-properties-common python-numpy firefox && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    python3 --version && \
    firefox --version

# Create user and set up permissions
RUN useradd -m -s /bin/bash ${USER} && \
    echo "${USER}:${PASSWORD}" | chpasswd && \
    gpasswd -a ${USER} sudo

# Switch to orange user and working directory
USER orange
WORKDIR ${HOME}

# Copy the conda directory from the build stage to the final image
COPY --from=build-stage --chown=orange:orange ${CONDA_DIR} ${CONDA_DIR}

# Copy the bashrc file from the build stage to the final image
COPY --from=build-stage --chown=orange:orange ${HOME}/.bashrc ${HOME}/.bashrc

# Add icons, desktop files, and other configurations from local context using COPY instead of ADD
COPY ./icons/orange.png /usr/share/backgrounds/images/orange.png
COPY ./icons/orange.png $CONDA_DIR/share/orange3/orange.png
COPY ./orange/orange-canvas.desktop Desktop/orange-canvas.desktop
COPY ./config/xfce4 .config/xfce4
COPY ./install/chromium-wrapper install/chromium-wrapper

# Add geometry script and change permissions
USER root
ADD ./install/add-geometry.sh /dockerstartup/add-resolution.sh
RUN chmod a+x /dockerstartup/add-resolution.sh

# Prepare for external settings volume
USER orange
RUN mkdir .config/biolab.si

# Copy startup script
RUN cp /headless/wm_startup.sh ${HOME}

# Set entrypoint and command
ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--tail-log"]
