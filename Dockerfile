# Use debian:11.1-slim as base image for a compatible and minimal image
FROM debian:11.1-slim as build-stage

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

# Install Python dependencies, Bzip2, Firefox ESR, and other required tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip bzip2 g++ git sudo xfce4 xfce4-terminal firefox-esr && \
    # Clean up the apt cache and remove unnecessary files to reduce the image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    python3 --version && \
    firefox-esr --version

# Create user and set up permissions
RUN adduser --disabled-password --gecos "" ${USER} && \
    echo "${USER}:${PASSWORD}" | chpasswd && \
    adduser ${USER} sudo

# Switch to orange user
USER orange
WORKDIR ${HOME}

# Download and install Anaconda and Orange-related packages using conda and pip
RUN curl -s -o anaconda.sh https://repo.anaconda.com/archive/Anaconda3-2023.07-2-Linux-x86_64.sh && \
    echo "589fb34fe73bc303379abbceba50f3131254e85ce4e7cd819ba4276ba29cad16 anaconda.sh" | sha256sum --check && \
    bash anaconda.sh -b -p $CONDA_DIR && \
    rm anaconda.sh && \
    $CONDA_DIR/bin/conda create python=$PYTHON_VERSION --name orange3 && \
    bash -c "source $CONDA_DIR/bin/activate orange3 && $CONDA_DIR/bin/conda install pyqt=5.12.* orange3 -c conda-forge" && \
    # Install Orange3-Text and its dependencies using conda and pip
    bash -c "source $CONDA_DIR/bin/activate orange3 && $CONDA_DIR/bin/conda install biopython gensim nltk scipy scikit-learn pandas requests beautifulsoup4 lxml wikipedia simhash -c conda-forge" && \
    bash -c "source $CONDA_DIR/bin/activate orange3 && pip install git+https://github.com/biolab/orange3-text.git" && \
    # Fetch and merge the pull request from GitHub using git
    bash -c "source $CONDA_DIR/bin/activate orange3 && cd $CONDA_DIR/lib/python$PYTHON_VERSION/site-packages/orangecontrib/text/ && git fetch origin pull/994/head:pr-994" && \
    bash -c "source $CONDA_DIR/bin/activate orange3 && cd $CONDA_DIR/lib/python$PYTHON_VERSION/site-packages/orangecontrib/text/ && git merge pr-994" && \
    echo "export PATH=$CONDA_DIR/bin:\$PATH" >> $HOME/.bashrc

# Start a new stage for the final image
FROM debian:11.1-slim

# Copy the build-time arguments from the build stage
ARG USER
ARG PASSWORD
ARG HOME
ARG CONDA_DIR

# Copy the environment variables from the build stage
ENV VNC_COL_DEPTH=${VNC_COL_DEPTH} \
    VNC_RESOLUTION=${VNC_RESOLUTION} \
    VNC_PW=${VNC_PW}

# Install Firefox ESR, Chromium, XFCE, VNC server, and other required tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip bzip2 g++ git xfce4 xfce4-terminal firefox-esr chromium x11vnc xvfb && \
    # Clean up the apt cache and remove unnecessary files to reduce the image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    python3 --version && \
    firefox-esr --version

# Create user and set up permissions
RUN adduser --disabled-password --gecos "" ${USER} && \
    echo "${USER}:${PASSWORD}" | chpasswd && \
    adduser ${USER} sudo

# Switch to orange user and working directory
USER orange
WORKDIR ${HOME}

# Copy the conda directory from the build stage to the final image
COPY --from=build-stage --chown=orange:orange ${CONDA_DIR} ${CONDA_DIR}

# Copy the bashrc file from the build stage to the final image
COPY --from=build-stage --chown=orange:orange ${HOME}/.bashrc ${HOME/.bashrc

# Copy files from local context using COPY instead of ADD
COPY ./icons/orange.png /usr/share/backgrounds/images/orange.png
COPY ./icons/orange.png $CONDA_DIR/share/orange3/orange.png
COPY ./orange/orange-canvas.desktop Desktop/orange-canvas.desktop
COPY ./config/xfce4 .config/xfce4

# Copy files for Orange3-Text from local context using COPY instead of ADD
COPY ./icons/orange-text.png /usr/share/backgrounds/images/orange-text.png
COPY ./icons/orange-text.png $CONDA_DIR/share/orange3-text/orange-text.png
COPY ./orange/orange-text.desktop Desktop/orange-text.desktop
COPY ./config/orange3-text .config/orange3-text

# Copy vnc_startup.sh script from local context and make it executable without switching to root user using sudo instead of su
COPY ./vnc_startup.sh /dockerstartup/vnc_startup.sh
RUN sudo chmod +x /dockerstartup/vnc_startup.sh

# Prepare for external settings volume
RUN mkdir .config/biolab.si

# Set entrypoint and command
ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--tail-log"]
