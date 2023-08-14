# Using a base image with VNC and Ubuntu with Xfce
FROM consol/ubuntu-xfce-vnc

# Set environment variables for user and password
ENV USER=orange \
    PASSWORD=orange \
    HOME=/home/${USER} \
    CONDA_DIR=/home/${USER}/.conda \
    PYTHON_VERSION=3.8 \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1920x1080 \
    VNC_PW=orange

# Switch to root user to install necessary packages
USER root

# Switch to root user to install necessary packages
USER root

# Install Python dependencies, Bzip2, and other required tools
RUN apt-get update && \
    apt-get install -y python3-pip python3-dev python-virtualenv bzip2 g++ git sudo xfce4-terminal software-properties-common python-numpy firefox && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


# Create user and set up permissions
RUN useradd -m -s /bin/bash ${USER} && \
    echo "${USER}:${PASSWORD}" | chpasswd && \
    gpasswd -a ${USER} sudo

# Switch to orange user
USER orange
WORKDIR ${HOME}

# Install Anaconda and Orange-related packages
RUN wget -q -O anaconda.sh https://repo.anaconda.com/archive/Anaconda3-2023.07-2-Linux-x86_64.sh && \
    echo "589fb34fe73bc303379abbceba50f3131254e85ce4e7cd819ba4276ba29cad16 anaconda.sh" | sha256sum --check && \
    bash anaconda.sh -b -p $CONDA_DIR && \
    rm anaconda.sh && \
    $CONDA_DIR/bin/conda create python=$PYTHON_VERSION --name orange3 && \
    bash -c "source $CONDA_DIR/bin/activate orange3 && $CONDA_DIR/bin/conda install pyqt=5.12.* orange3 Orange3-Text Orange3-ImageAnalytics -c conda-forge" && \
    echo "export PATH=$CONDA_DIR/bin:\$PATH" >> $HOME/.bashrc && \
    bash -c "source $CONDA_DIR/bin/activate orange3"

# Add icons, desktop files, and other configurations
ADD ./icons/orange.png /usr/share/backgrounds/images/orange.png
ADD ./icons/orange.png $CONDA_DIR/share/orange3/orange.png
ADD ./orange/orange-canvas.desktop Desktop/orange-canvas.desktop
ADD ./config/xfce4 .config/xfce4
ADD ./install/chromium-wrapper install/chromium-wrapper

# Change ownership of the files and add geometry script
USER root
RUN chown -R orange:orange .config Desktop install
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
